#!/usr/bin/env bash
set -euo pipefail

# Gera catalogo_fontes.json a partir de um conjunto de CSVs remotos.
# Requisitos:
# - bash
# - curl
# - python3
#
# Uso:
#   bash gerar_catalogo_fontes.sh
#
# Saída:
#   ./catalogo_fontes.json

OUT_FILE="${1:-catalogo_fontes.json}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

declare -A URLS=(
  [td_territorio]="https://raw.githubusercontent.com/labx-ia-br/bd_geral/refs/heads/main/td_territorio.csv"
  [td_populacao_ripsa_ano_2025]="https://raw.githubusercontent.com/labx-ia-br/bd_geral/refs/heads/main/td_populacao_ripsa_ano_2025.csv"
  [td_bdsus_mapa_atributos]="https://raw.githubusercontent.com/labx-ia-br/bd_geral/refs/heads/main/td_bdsus_mapa_atributos.csv"
  [tb_procedimento]="https://raw.githubusercontent.com/labx-ia-br/bd_sigtap/refs/heads/main/tb_procedimento.csv"
  [tb_grupo]="https://raw.githubusercontent.com/labx-ia-br/bd_sigtap/refs/heads/main/tb_grupo.csv"
  [tb_sub_grupo]="https://raw.githubusercontent.com/labx-ia-br/bd_sigtap/refs/heads/main/tb_sub_grupo.csv"
  [tb_forma_organizacao]="https://raw.githubusercontent.com/labx-ia-br/bd_sigtap/refs/heads/main/tb_forma_organizacao.csv"
)

cat > "$TMP_DIR/analisar_csv.py" <<'PY'
import csv
import json
import os
import re
import sys
from collections import Counter

dataset_id = sys.argv[1]
csv_path = sys.argv[2]
origem_url = sys.argv[3]

def infer_categoria(name: str) -> str:
    if name == "td_bdsus_mapa_atributos":
        return "metadado_mapeamento"
    if "territorio" in name:
        return "dimensao_territorial"
    if "populacao" in name:
        return "dimensao_populacional"
    if name in {"tb_procedimento", "tb_grupo", "tb_sub_grupo", "tb_forma_organizacao"}:
        return "sigtap_dimensao"
    return "fonte_csv"

def infer_descricao(name: str) -> str:
    descricoes = {
        "td_territorio": "Base territorial de apoio para chaves geográficas e recortes espaciais.",
        "td_populacao_ripsa_ano_2025": "Base populacional de referência para denominadores, taxas e análises territoriais.",
        "td_bdsus_mapa_atributos": "Mapa de atributos para compatibilização semântica entre schemas, tabelas e campos.",
        "tb_procedimento": "Catálogo SIGTAP de procedimentos.",
        "tb_grupo": "Catálogo SIGTAP de grupos de procedimentos.",
        "tb_sub_grupo": "Catálogo SIGTAP de subgrupos de procedimentos.",
        "tb_forma_organizacao": "Catálogo SIGTAP de formas de organização."
    }
    return descricoes.get(name, f"Fonte CSV {name}.")

def infer_papel(name: str):
    papeis = {
        "td_territorio": ["lookup", "enriquecimento_semantico", "apoio_territorial"],
        "td_populacao_ripsa_ano_2025": ["lookup", "denominador", "apoio_demografico"],
        "td_bdsus_mapa_atributos": ["metadado", "compatibilizacao", "catalogo_semantico"],
        "tb_procedimento": ["lookup", "classificacao", "enriquecimento_semantico"],
        "tb_grupo": ["lookup", "classificacao", "hierarquia_sigtap"],
        "tb_sub_grupo": ["lookup", "classificacao", "hierarquia_sigtap"],
        "tb_forma_organizacao": ["lookup", "classificacao", "hierarquia_sigtap"],
    }
    return papeis.get(name, ["lookup"])

def infer_granularidade(name: str) -> str:
    granularidades = {
        "td_territorio": "1 linha por unidade territorial, conforme chave disponível no arquivo.",
        "td_populacao_ripsa_ano_2025": "1 linha por recorte territorial e estrato disponível no arquivo.",
        "td_bdsus_mapa_atributos": "1 linha por atributo mapeado.",
        "tb_procedimento": "1 linha por procedimento.",
        "tb_grupo": "1 linha por grupo.",
        "tb_sub_grupo": "1 linha por subgrupo.",
        "tb_forma_organizacao": "1 linha por forma de organização.",
    }
    return granularidades.get(name, "Granularidade a validar.")

def normalize_header(header):
    return [h.strip() for h in header]

def guess_type(values):
    vals = [v.strip() for v in values if v is not None and str(v).strip() != ""]
    if not vals:
        return "desconhecido"

    def is_int(x):
        return re.fullmatch(r"[+-]?\d+", x) is not None

    def is_float(x):
        return re.fullmatch(r"[+-]?\d+([.,]\d+)?", x) is not None

    def is_date(x):
        patterns = [
            r"\d{4}-\d{2}-\d{2}",
            r"\d{2}/\d{2}/\d{4}",
            r"\d{6}",
            r"\d{4}-\d{2}",
        ]
        return any(re.fullmatch(p, x) for p in patterns)

    if all(is_int(v) for v in vals):
        return "inteiro"
    if all(is_float(v) for v in vals):
        return "numerico"
    if all(is_date(v) for v in vals):
        return "data_ou_periodo"
    if max(len(v) for v in vals) <= 2 and len(set(vals)) <= 100:
        return "codigo_curto"
    return "texto"

def infer_papeis_campo(nome):
    n = nome.lower()
    papeis = []

    if any(k in n for k in ["id_", "_id", "cpf", "cns", "cns", "uuid"]):
        papeis.append("identificador")
    if any(k in n for k in ["dt_", "data", "ano", "mes", "periodo", "competencia", "mvm"]):
        papeis.append("tempo")
    if any(k in n for k in ["uf", "municip", "ibge", "regiao", "territ", "bairro"]):
        papeis.append("territorio")
    if "proced" in n:
        papeis.append("procedimento")
    if any(k in n for k in ["diag", "cid"]):
        papeis.append("diagnostico")
    if any(k in n for k in ["valor", "qtd", "quant", "total", "vl_", "qt_"]):
        papeis.append("medida")
    if any(k in n for k in ["numerador", "num_"]):
        papeis.append("numerador")
    if any(k in n for k in ["denominador", "den_"]):
        papeis.append("denominador")
    if any(k in n for k in ["nome", "descricao", "desc", "no_"]):
        papeis.append("rotulo")

    if not papeis:
        papeis.append("atributo")
    return sorted(set(papeis))

def infer_chaves(cabecalho):
    lower = [c.lower() for c in cabecalho]
    candidatas = []

    prioridades = [
        "id", "id_", "_id", "codigo", "cod_", "co_", "cnes", "ibge",
        "proced", "grupo", "sub_grupo", "forma", "cid"
    ]

    for col in cabecalho:
        lcol = col.lower()
        if any(p in lcol for p in prioridades):
            candidatas.append(col)

    # remove duplicadas preservando ordem
    seen = set()
    out = []
    for c in candidatas:
        if c not in seen:
            seen.add(c)
            out.append(c)
    return out[:5]

with open(csv_path, "r", encoding="utf-8-sig", newline="") as f:
    sample = f.read(8192)
    f.seek(0)
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=";,|\t")
        delimiter = dialect.delimiter
    except Exception:
        delimiter = ","

    reader = csv.DictReader(f, delimiter=delimiter)
    fieldnames = normalize_header(reader.fieldnames or [])
    rows = []
    for i, row in enumerate(reader):
        rows.append(row)
        if i >= 199:
            break

amostras_por_campo = {k: [] for k in fieldnames}
for row in rows:
    for k in fieldnames:
        amostras_por_campo[k].append(row.get(k, ""))

campos = []
for nome in fieldnames:
    valores = amostras_por_campo[nome]
    exemplos = []
    for v in valores:
        v = "" if v is None else str(v).strip()
        if v != "" and v not in exemplos:
            exemplos.append(v)
        if len(exemplos) >= 3:
            break

    campos.append({
        "nome": nome,
        "tipo_logico_inferido": guess_type(valores),
        "papeis_inferidos": infer_papeis_campo(nome),
        "nullable_amostral": any((v is None or str(v).strip() == "") for v in valores),
        "exemplos": exemplos
    })

catalogo = {
    "dataset_id": dataset_id,
    "origem_url": origem_url,
    "arquivo": os.path.basename(csv_path),
    "categoria": infer_categoria(dataset_id),
    "descricao": infer_descricao(dataset_id),
    "granularidade": infer_granularidade(dataset_id),
    "papel_no_ecossistema": infer_papel(dataset_id),
    "delimitador_inferido": delimiter,
    "n_colunas": len(fieldnames),
    "n_linhas_amostradas": len(rows),
    "chaves_candidatas": infer_chaves(fieldnames),
    "campos": campos,
    "observacoes": [
        "Metadados inferidos automaticamente a partir do cabeçalho e de amostra do CSV.",
        "Tipos e chaves devem ser revisados manualmente antes de uso definitivo."
    ]
}

print(json.dumps(catalogo, ensure_ascii=False, indent=2))
PY

json_files=()

for dataset_id in "${!URLS[@]}"; do
  url="${URLS[$dataset_id]}"
  csv_file="$TMP_DIR/${dataset_id}.csv"
  json_file="$TMP_DIR/${dataset_id}.json"

  echo "Baixando: $dataset_id"
  curl -fsSL "$url" -o "$csv_file"

  echo "Analisando: $dataset_id"
  python3 "$TMP_DIR/analisar_csv.py" "$dataset_id" "$csv_file" "$url" > "$json_file"

  json_files+=("$json_file")
done

python3 - "$OUT_FILE" "${json_files[@]}" <<'PY'
import json
import sys

out_file = sys.argv[1]
files = sys.argv[2:]

catalogo = {
    "projeto": "ecossistema_analitico_sus",
    "tipo": "catalogo_fontes",
    "versao": "0.1.0",
    "fontes": []
}

for path in sorted(files):
    with open(path, "r", encoding="utf-8") as f:
        catalogo["fontes"].append(json.load(f))

with open(out_file, "w", encoding="utf-8") as f:
    json.dump(catalogo, f, ensure_ascii=False, indent=2)

print(out_file)
PY

echo "Gerado: $OUT_FILE"

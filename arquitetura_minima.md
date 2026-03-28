# Arquitetura mínima — Ecossistema analítico modular para exploração de subsistemas do SUS

## Objetivo

Construir um ecossistema modular e incremental em **R/Shiny** para exploração analítica de subsistemas do SUS, orientado por **metadados** e por uma **especificação analítica formal em JSON**, capaz de:

- listar schemas, tabelas e atributos relevantes no PostgreSQL;
- orientar a seleção de campos compatíveis para análise;
- gerar SQL conforme o objetivo analítico;
- executar consultas no PostgreSQL;
- apresentar resultados em tabelas, gráficos e scripts R reutilizáveis;
- gerar relatórios em **Markdown/Quarto**;
- sustentar dois modos de uso sobre a mesma espinha dorsal:
  - **navegador base** (exploratório);
  - **navegador de indicadores** (guiado por fichas declarativas em md).

O projeto deve permitir evolução incremental: cada iteração acrescenta ou melhora um módulo sem exigir reescrita do restante do sistema.

---

## Módulos

Estrutura sugerida do projeto:

```text
01_metadados
02_especificacao_analitica
03_validacao
04_query_builder
05_execucao_sql
06_navegador_base
07_modulos_analiticos
08_navegador_indicadores
09_relatorios
10_utilitarios
```

Estrutura interna dos módulos analíticos:

```text
07_modulos_analiticos/
  pareto/
  kaplan_meier/
  qui_quadrado/
  piramide_etaria/
  mapa_arvore/
```

Cada módulo analítico deve seguir um contrato comum:

```r
validate_input()
prepare_data()
run_analysis()
build_outputs()
```

### Papel de cada módulo

- **01_metadados**  
  Carrega e padroniza catálogos, fichas de indicadores, dicionário estrutural e mapeamento semântico dos campos.

- **02_especificacao_analitica**  
  Define e manipula o objeto central JSON que representa a intenção analítica.

- **03_validacao**  
  Verifica consistência da especificação, compatibilidade entre campos e pré-condições para análise.

- **04_query_builder**  
  Gera SQL a partir da especificação e do catálogo de metadados.

- **05_execucao_sql**  
  Executa SQL no PostgreSQL, devolve `data.frame` e registra parâmetros e consulta executada.

- **06_navegador_base**  
  Interface exploratória em que o usuário escolhe schema, tabela, campos, filtros e tipo de análise.

- **07_modulos_analiticos**  
  Implementa análises estatísticas e gráficas modulares, reutilizando o mesmo contrato de entrada e saída.

- **08_navegador_indicadores**  
  Interface guiada por fichas declarativas de indicadores em md/YAML.

- **09_relatorios**  
  Gera saída em Markdown/Quarto com query, tabelas, gráficos, parâmetros e interpretação.

- **10_utilitarios**  
  Funções auxiliares compartilhadas (nomes, datas, rótulos, logging, parsing, helpers de UI, etc.).

---

## Objeto central

O coração do sistema é uma **especificação analítica formal em JSON**. Tudo deve convergir para esse objeto:

- a **UI** gera isso;
- a **ficha md** gera isso;
- o **indicador** gera isso;
- o **query builder** consome isso;
- o **módulo analítico** consome isso.

Essa especificação precisa ser estável, explícita e extensível.

### Exemplo de estrutura mínima

```json
{
  "contexto": {
    "subsistema": "SIA",
    "schema": "dm_cid_11_artrite_rea",
    "tabela": "tf_sia_am"
  },
  "papeis": {
    "identificador": "ap_cnspcn",
    "procedimento": "ap_pripal",
    "tempo": "ap_mvm",
    "territorio": null,
    "diagnostico": null,
    "medida": null,
    "numerador": null,
    "denominador": null
  },
  "campos_exibicao": [
    "ap_cnspcn",
    "ap_pripal",
    "ap_mvm"
  ],
  "filtros": {
    "periodo_inicio": "202201",
    "periodo_fim": "202312",
    "excluir_valores": [
      "99999999",
      "IGN"
    ]
  },
  "analise": {
    "tipo": "pareto",
    "alvo": "procedimento",
    "parametros": {
      "top_n": 20
    }
  },
  "saida": {
    "mostrar_query": true,
    "mostrar_tabela": true,
    "mostrar_script_r": true,
    "gerar_relatorio": true,
    "formato_relatorio": "qmd"
  }
}
```

### Requisitos do objeto central

- representar tanto uso exploratório quanto indicadores pré-definidos;
- separar claramente **contexto**, **papéis semânticos**, **filtros**, **análise** e **saída**;
- permitir extensão futura sem quebrar contratos antigos;
- ser fácil de serializar, versionar, validar e registrar.

---

## Fluxo de dados

### Visão geral

```text
CSV GitHub / fichas md / dicionário estrutural
            ↓
      01_metadados
            ↓
 catálogo normalizado + mapeamento semântico
            ↓
 interface do usuário OU ficha de indicador
            ↓
 02_especificacao_analitica
            ↓
   objeto central JSON (analysis spec)
            ↓
        03_validacao
            ↓
        04_query_builder
            ↓
             SQL
            ↓
        05_execucao_sql
            ↓
         data.frame
            ↓
 07_modulos_analiticos / 06_navegador_base / 08_navegador_indicadores
            ↓
 09_relatorios / datatable / gráficos / script R
```

### Fluxo detalhado por camada

#### Camada 1 — Metadados

Responsável por descrever o mundo.

**Objetos:**

- catálogos CSV no GitHub;
- fichas md de indicadores;
- dicionário dos schemas/tabelas/campos;
- mapeamento semântico dos campos.

**Funções:**

- carregar catálogos;
- validar consistência;
- normalizar nomes;
- classificar campos por papel:
  - identificador;
  - tempo;
  - território;
  - procedimento;
  - diagnóstico;
  - medida;
  - denominador;
  - numerador.

**Saída esperada:**

um catálogo padronizado que descreva estrutura e semântica dos campos, servindo de base para validação, compatibilização e geração de SQL.

#### Camada 2 — Especificação analítica

Responsável por transformar escolhas do usuário em um objeto formal JSON.

Tudo deve convergir para isso:

- UI gera isso;
- ficha md gera isso;
- indicador gera isso;
- query builder consome isso;
- módulo analítico consome isso.

Esse objeto é o coração do sistema.

**Saída esperada:**

uma especificação única, validável, reutilizável e auditável para qualquer análise.

#### Camada 3 — Execução

Responsável por:

- gerar SQL;
- consultar PostgreSQL;
- devolver `data.frame`;
- registrar query e parâmetros.

Aqui convém separar:

```r
build_sql(spec, catalog)
run_sql(sql, conn)
validate_spec(spec, catalog)
```

**Saída esperada:**

consulta executável, rastreável e desacoplada da interface.

#### Camada 4 — Apresentação

Responsável por:

- `datatable`;
- gráficos;
- scripts R de visualização;
- relatório Markdown/Quarto.

Aqui entram:

- navegador base;
- navegador de indicadores;
- exportação.

**Saída esperada:**

uma camada de consumo final que reaproveita a mesma especificação e o mesmo resultado tabular para múltiplas visualizações.

---

## Navegador base vs navegador de indicadores

Os dois devem compartilhar a mesma espinha dorsal: **catálogo padronizado + objeto central + validação + query builder + execução + apresentação**.

### Navegador base

Mais livre, exploratório.  
O usuário escolhe:

- `schema`;
- `tabela`;
- `campos`;
- `filtros`;
- `tipo de análise`.

Esse modo é voltado ao analista experiente que deseja formular explorações ad hoc.

### Navegador de indicadores

Mais guiado.  
O usuário escolhe:

- ficha do indicador;
- filtros complementares;
- visualizações adicionais.

Esse modo é voltado a indicadores formalizados, com menor liberdade estrutural e maior reprodutibilidade.

### Regra de desenho

A ficha md do indicador deve ser uma **especificação declarativa**, não texto solto.

Sugestão de estrutura para a ficha:

```md
---
id: proporcao_internacoes_artrite
titulo: Proporção de internações por artrite
schema: dm_cid_11_artrite_rea
tabela: tf_sih_rd
papeis:
  tempo: dt_competencia
  territorio: municipio_residencia
  numerador: total_internacoes_artrite
  denominador: total_internacoes
analises_adicionais:
  - pareto_procedimentos
  - piramide_etaria
  - qui_quadrado_sexo
query_base: |
  select ...
---

## Definição
...

## Interpretação
...
```

Preferência: **YAML front matter + corpo md**, com possibilidade de geração posterior em **Quarto (`.qmd`)**.

---

## Regras de interação com o ChatGPT

O ChatGPT deve ser usado como copiloto de projeto modular, e não como gerador monolítico de “sistema completo”.

### Regra principal

Em cada iteração, trabalhar **apenas no módulo solicitado**, preservando compatibilidade futura com os demais.

### Instrução padrão para reutilizar em todas as iterações

```md
Este projeto é modular e incremental.
Trabalhe apenas no módulo solicitado.
Considere compatibilidade futura com os demais módulos, mas não implemente outros módulos.
Quando precisar tocar interfaces externas, defina contratos, stubs e pontos de extensão.
Prefira soluções simples, testáveis e desacopladas.
Explique explicitamente entradas, saídas, dependências e riscos de integração.
```

### Estrutura recomendada de prompt por iteração

```md
Contexto:
[resumo curto do projeto e da arquitetura]

Módulo alvo:
[nome do módulo da vez]

Objetivo:
[o que deve ser produzido nesta iteração]

Restrições:
[o que está fora de escopo]

Entrega:
[formato exato esperado: funções, objeto, exemplo, teste, stub, etc.]
```

### Regras operacionais

- não pedir implementação total do sistema em uma única iteração;
- começar por contratos, metadados e objeto central antes de UI e gráficos;
- registrar decisões arquiteturais em arquivos `.md` curtos e cumulativos;
- preferir exemplos mínimos executáveis;
- manter separação entre:
  - metadados;
  - especificação analítica;
  - validação;
  - query;
  - execução;
  - apresentação.

### Ordem sugerida de evolução incremental

1. modelo conceitual do ecossistema;
2. objeto central JSON;
3. catálogo de metadados;
4. regras de compatibilidade entre campos;
5. query builder;
6. executor SQL;
7. navegador base;
8. fichas de indicadores;
9. módulos analíticos;
10. relatórios Quarto;
11. testes;
12. refatoração.

---

## Decisão arquitetural central

A base do ecossistema deve ser:

- **R/Shiny** para interface;
- **PostgreSQL** para consulta;
- **catálogo semântico de campos** para compatibilização;
- **objeto central JSON** para transportar a intenção analítica;
- **fichas declarativas em md/YAML** para indicadores;
- **Quarto (`.qmd`)** como padrão preferencial de relatório.

Essa combinação reduz acoplamento, facilita evolução incremental e permite que novos módulos analíticos sejam adicionados sem redesenhar o sistema inteiro.


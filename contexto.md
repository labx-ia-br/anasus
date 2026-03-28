# Contexto do Projeto — Ecossistema Analítico SUS

## 1. Visão Geral

Este projeto define um ecossistema modular para exploração analítica de dados dos sistemas de informação do SUS, com foco em:

- integração de múltiplos sistemas (SIA, SIH, SIM, SINAN, CNES, etc.)
- padronização semântica via metadados
- geração dinâmica de queries
- exploração interativa via R/Shiny
- suporte a indicadores e análises avançadas

O sistema é orientado por três princípios centrais:

1. **Separação de camadas (origem → staging → analítico → metadado/domínio)**
2. **Uso de um objeto central de especificação analítica (`analysis_spec`)**
3. **Execução incremental e modular com suporte ao ChatGPT como copiloto**

Este documento complementa:

- `arquitetura_minima.md`
- `catalogo_camadas_fontes.json`
- `catalogo_regras_join.json`
- `catalogo_papeis_semanticos.json`

---

## 2. Camadas de Dados

Definidas formalmente em `catalogo_camadas_fontes.json`.

### 2.1 Primária
- Origem oficial externa (DATASUS FTP, APIs, etc.)
- Unidade: sistema/subsistema
- Exemplo: SIA, SIH, SIM

### 2.2 Staging
- Persistência técnica intermediária
- Repositórios:
  - `bureta` (histórico < 2020)
  - `pipeta` (>= 2020)
- Unidade: `schema.table`
- Exemplo: `cnes_200508_dc.dcac0508`

### 2.3 Analítica
- Datamarts (`dm_`) e visões (`vw_`, `mv_`)
- Cubos conceituais:
  - condição de saúde
  - território
  - procedimento

### 2.4 Metadado
- Governança e semântica
- Exemplos:
  - `td_bdsus_mapa_atributos`
  - `td_diretriz_cuidado`
  - `td_dicionario_sistema`

### 2.5 Domínio
- Tabelas externas de referência
- Exemplos:
  - `td_territorio`
  - `td_populacao`
  - SIGTAP (`tb_procedimento`, etc.)
  - CID (`td_doenca_cid10`)

---

## 3. Arquitetura

Baseada em `arquitetura_minima.md`.

### Camadas funcionais

1. Metadados
2. Especificação analítica
3. Validação
4. Query builder
5. Execução SQL
6. Apresentação

### Princípios

- desacoplamento entre módulos
- contratos explícitos
- reutilização via objetos padronizados
- separação entre semântica e execução

---

## 4. Objeto Central — `analysis_spec`

O `analysis_spec` é o núcleo do sistema.

### Função

Representar qualquer análise de forma estruturada, independente da origem.

### Estrutura resumida

```json
{
  "contexto": {
    "sistema": "SIA",
    "subsistema": "PA",
    "schema": "dm_exemplo",
    "tabela": "tf_exemplo"
  },
  "papeis": {
    "territorio": "campo_x",
    "procedimento": "campo_y",
    "tempo": "campo_z"
  },
  "filtros": {},
  "analise": {
    "tipo": "pareto"
  },
  "saida": {}
}
```

### Regras

- todo fluxo converge para este objeto
- deve ser validado antes da execução
- deve ser independente da interface

---

## 5. Integração dos Catálogos

### 5.1 `catalogo_camadas_fontes.json`
Define a origem e classificação das fontes.

### 5.2 `catalogo_papeis_semanticos.json`
Define:
- significado dos campos
- tipo esperado
- dimensão associada

### 5.3 `catalogo_regras_join.json`
Define:
- como conectar dados
- normalizações
- joins e hierarquias

### Integração

Fluxo:

```text
analysis_spec
 → validação (papeis)
 → resolução semântica (mapa_atributos)
 → aplicação de regras_join
 → geração SQL
```

---

## 6. Regras de Interação com ChatGPT

### Regra principal

Trabalhar de forma modular e incremental.

### Instrução padrão

```
Este projeto é modular.
Trabalhe apenas no módulo solicitado.
Não implemente o sistema completo.
Defina contratos e interfaces.
```

### Estrutura de prompt

- Contexto
- Módulo alvo
- Objetivo
- Restrições
- Entrega esperada

---

## 7. Fluxo Incremental de Desenvolvimento

Ordem recomendada:

1. Metadados
2. Papeis semânticos
3. Regras de join
4. analysis_spec
5. Query builder
6. Execução
7. UI
8. Indicadores
9. Relatórios

Ciclo:

```text
Definir → Implementar → Testar → Ajustar
```

---

## 8. Padrões de Implementação

### 8.1 Nomeação

- `co_` código
- `no_` nome
- `qt_` quantidade
- `vl_` valor

### 8.2 Tipos

- códigos como texto
- datas normalizadas
- evitar ambiguidade numérica

### 8.3 Separação

- metadado ≠ domínio
- staging ≠ analítico
- semântica ≠ execução

### 8.4 Funções padrão

- `validate_spec()`
- `build_sql()`
- `run_sql()`

---


### 8.5 Padrões Visuais (Paleta de Cores)

O sistema deve utilizar uma paleta padronizada baseada na identidade LabX.

#### Tipos de paleta

1. Monocromática (intensidade)
- `mono_azul`
- `mono_laranja`

Uso:
- mapas de calor
- valores contínuos
- intensidade

2. Divergente (contraste)
- azul → branco → laranja

Uso:
- desvios
- comparações em torno de um centro (ex: 0)

3. Binária (comparação direta)
- azul vs laranja

Uso:
- pirâmide etária
- comparações entre dois grupos

#### Regras

- cores devem refletir o papel da variável (não estética)
- evitar paletas arbitrárias (ex: arco-íris)
- preservar consistência entre módulos

#### Integração com analysis_spec

A paleta pode ser definida no objeto:

```json
"saida": {
  "paleta": "mono_azul",
  "modo_cor": "continua"
}

## 9. Papel deste Documento

Este arquivo (`contexto.md`) é:

- referência arquitetural
- base para prompts do ChatGPT
- contrato conceitual do sistema

Não contém:

- implementação completa
- queries finais
- lógica específica de UI

---

## 10. Próximos Passos

- detalhar `analysis_spec`
- implementar `validate_spec`
- implementar `query_builder`
- conectar com metadados
- evoluir módulos analíticos

---

Fim


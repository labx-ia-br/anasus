# anaSUS

Ecossistema modular em **R/Shiny** para exploração analítica de dados dos sistemas de informação do SUS, orientado por **metadados**, **papéis semânticos** e **geração dinâmica de SQL**.

O projeto combina:

- navegação exploratória sobre datamarts `dm_`
- seleção de tabelas fato `tf_`
- detecção de campos semânticos
- geração explícita da query SQL
- execução da consulta
- exibição tabular dos resultados
- documentação arquitetural e catálogos auxiliares em `.md` e `.json`

---

## Objetivo

O `anasus` foi desenhado para servir como base de um ambiente analítico voltado a sanitaristas, cientistas de dados e analistas de informação em saúde, permitindo:

- explorar bases analíticas por condição de saúde, território e procedimento
- mapear e reutilizar campos semânticos entre sistemas distintos
- construir indicadores e consultas reproduzíveis
- evoluir o sistema de forma incremental, sem reescrever tudo a cada etapa

---

## Estrutura do projeto

```text
anasus/
├── app.R
├── R/
│   ├── exec_sql.R
│   ├── metadados.R
│   ├── paleta.R
│   ├── query_builder.R
│   ├── ui_helpers.R
│   └── validate_spec.R
├── arquitetura_minima.md
├── arquivos_base.txt
├── catalogo_camadas_fontes.json
├── catalogo_fontes.json
├── catalogo_fontes.sh
├── catalogo_papeis_semanticos.json
├── catalogo_regras_join.json
├── contexto.md
├── instrucoes_iniciais.md
├── instrucoes_modelo.md
└── tarefa_geradorQuery.md
````

---

## Visão geral dos arquivos

# 1. Arquivo principal da aplicação

## `app.R`

É o ponto de entrada do app Shiny.

Responsabilidades:

* montar a interface do navegador base
* conectar ao banco via funções auxiliares
* carregar catálogo de `dm_` e `tf_`
* detectar campos semânticos
* permitir filtros por:

  * diagnóstico
  * procedimento
  * território
  * período
  * usuário (CNS)
  * sexo
  * idade
  * raça/cor
* gerar e exibir a query SQL completa
* executar a query
* mostrar tabela de resultado
* mostrar o `analysis_spec`

---

# 2. Scripts R auxiliares

Todos os arquivos abaixo ficam em `R/` e são carregados pelo `app.R`.

## `R/metadados.R`

Responsável por:

* configuração de conexão com PostgreSQL
* leitura das variáveis de ambiente:

  * `PNRF_DB_PORT`
  * `PNRF_DB_USER`
  * `PNRF_DB_PASS`
* definição de `srv_config`
* abertura da conexão
* descoberta de metadados no banco
* construção do catálogo de tabelas e colunas

Funções típicas:

* `connect_db()`
* `get_all_tables()`
* `get_dm_schemas_from_catalog()`
* `get_fact_tables_from_catalog()`
* `get_table_columns_from_catalog()`

Esse arquivo cuida da camada de descoberta estrutural do banco.

---

## `R/ui_helpers.R`

Responsável por utilidades de interface e parsing.

Exemplos:

* operador `%||%`
* escolha do primeiro item de um vetor
* parsing do nome da tabela `tf_*`
* detecção de campos semânticos por padrão de nome

Funções típicas:

* `first_or_empty()`
* `parse_table_name()`
* `detect_candidates()`
* `detect_semantic_fields()`
* `first_candidate()`

Esse arquivo ajuda a converter nomes físicos de colunas em papéis semânticos candidatos.

---

## `R/query_builder.R`

Responsável por:

* montar o objeto `analysis_spec`
* transformar filtros e papéis semânticos em cláusulas SQL
* gerar a query final
* descobrir mínimo e máximo do período para o slider

Funções típicas:

* `build_analysis_spec()`
* `build_where_clauses()`
* `build_select_sql()`
* `get_period_bounds_from_table()`
* `period_expr_sql()`

Esse é o núcleo da camada de geração de consulta.

---

## `R/validate_spec.R`

Responsável por validar o `analysis_spec` antes da execução.

Verifica:

* servidor
* schema
* tabela
* colunas selecionadas
* coerência entre papéis semânticos e colunas disponíveis
* limite de linhas

Função principal:

* `validate_spec()`

Esse arquivo protege o app de consultas inválidas e ajuda a depurar erros antes da execução.

---

## `R/exec_sql.R`

Responsável por executar SQL no banco.

Função principal:

* `run_sql()`

É propositalmente pequeno, para manter separação clara entre:

* montar SQL
* executar SQL

---

## `R/paleta.R`

Responsável pela padronização visual do projeto.

Define:

* cores-base
* gradientes monocromáticos
* gradiente divergente
* paleta binária
* helpers para uso em gráficos

Uso pretendido:

* Shiny
* ggplot2
* relatórios
* módulos analíticos futuros

Esse arquivo concentra o padrão visual do projeto.

---

# 3. Documentação arquitetural

## `arquitetura_minima.md`

Documento de arquitetura resumida do ecossistema.

Contém:

* objetivo do projeto
* módulos
* objeto central
* fluxo de dados
* regras de interação com o ChatGPT
* separação entre navegador base e navegador de indicadores

É a referência arquitetural curta do sistema.

---

## `contexto.md`

Documento principal de contexto do projeto.

Contém:

* visão geral
* camadas de dados
* arquitetura
* papel do `analysis_spec`
* integração dos catálogos
* regras de interação com o ChatGPT
* fluxo incremental de desenvolvimento
* padrões de implementação
* padrão visual

É o documento-base que orienta evolução do projeto e o uso do ChatGPT como copiloto.

---

## `tarefa_geradorQuery.md`

Documento de escopo específico para o módulo de geração de query.

Serve para:

* delimitar escopo
* registrar decisões de modelagem
* orientar implementação incremental do query builder

É um artefato tático de desenvolvimento.

---

## `instrucoes_iniciais.md`

Arquivo de apoio para abertura de novos chats ou novas interações no projeto.

Tipicamente contém:

* resumo do projeto
* regras de trabalho
* como o modelo deve responder
* arquivos-base a considerar

Serve como prompt-base de continuidade.

---

## `instrucoes_modelo.md`

Arquivo de apoio para orientar o comportamento esperado do modelo durante o desenvolvimento.

Pode conter:

* diretrizes de resposta
* estilo de alteração de arquivos
* restrições de escopo
* prioridades arquiteturais

É um artefato auxiliar de governança do uso do modelo.

---

# 4. Catálogos JSON

## `catalogo_camadas_fontes.json`

Descreve as camadas de fontes do ecossistema.

Camadas previstas:

* `primaria`
* `staging`
* `analitica`
* `metadado`
* `dominio`

Também documenta:

* taxonomia das camadas
* convenções de nomenclatura
* relações entre camadas
* recomendações de governança

Esse arquivo organiza a proveniência e o papel das fontes no sistema.

---

## `catalogo_fontes.json`

Catálogo de fontes e datasets auxiliares conhecidos no projeto.

Pode incluir:

* tabelas de território
* população
* SIGTAP
* mapas de atributos
* outros datasets auxiliares

É um catálogo de datasets já identificados e descritos.

---

## `catalogo_papeis_semanticos.json`

Define os principais papéis semânticos usados no projeto.

Exemplos:

* `territorio`
* `municipio_residencia`
* `municipio_estabelecimento`
* `procedimento`
* `diagnostico`
* `tempo`
* `quantidade`
* `valor`

Para cada papel, o catálogo tende a registrar:

* definição
* tipo esperado
* dimensão preferencial
* drill disponível
* exemplos de campos físicos

Esse arquivo é central para compatibilização semântica entre sistemas diferentes.

---

## `catalogo_regras_join.json`

Catálogo de regras de join e normalização.

Define:

* joins sugeridos
* regras por papel semântico
* normalizações necessárias
* drills territoriais
* drills de procedimento
* ligações com tabelas de domínio

É a base para um query builder semântico mais avançado.

---

# 5. Scripts auxiliares

## `catalogo_fontes.sh`

Script Bash para gerar ou atualizar `catalogo_fontes.json`.

Objetivo:

* automatizar leitura de fontes CSV
* inferir metadados iniciais
* facilitar a manutenção do catálogo de fontes

---

## `arquivos_base.txt`

Arquivo simples de apoio, usado para registrar arquivos-base do projeto.

Pode servir para:

* checklist
* organização de bootstrap
* conferência do conjunto mínimo do projeto

---

# 6. Conceitos principais do projeto

## Navegador base

É o app Shiny atual.

Permite:

* escolher servidor
* escolher schema `dm_`
* escolher tabela `tf_`
* escolher colunas
* usar filtros semânticos
* gerar SQL
* executar consulta
* ver resultado

É a base operacional do ecossistema.

---

## Navegador de indicadores

Ainda conceitual ou futuro.

Será uma camada mais guiada, baseada em fichas declarativas de indicadores, provavelmente em `md` com front matter YAML.

Diferença principal:

* navegador base = exploratório
* navegador de indicadores = guiado

---

## `analysis_spec`

É o objeto central do sistema.

Representa a intenção analítica de forma estruturada.

Contém:

* contexto
* papéis semânticos
* colunas selecionadas
* filtros
* tipo de análise
* parâmetros de saída

Toda evolução futura deve convergir para esse objeto.

---

# 7. Convenções de nomenclatura

## Objetos

* `td_`: tabela de domínio
* `tf_`: tabela de fatos
* `tb_`: tabela OLTP
* `vw_`: view
* `mv_`: materialized view
* `bd_`: base de dados ou schema geral
* `dm_`: datamart
* `tm_`: tabela ou schema temporário
* `st_`: staging

## Atributos

* `co_`: código
* `sg_`: sigla
* `no_`: nome
* `ds_`: descrição
* `nu_`: número discreto
* `qt_`: quantidade
* `vl_`: valor
* `st_`: status

Essas convenções ajudam tanto a organizar o banco quanto a inferir semântica no app.

---

# 8. Banco e configuração

O app usa variáveis de ambiente para conexão:

* `PNRF_DB_PORT`
* `PNRF_DB_USER`
* `PNRF_DB_PASS`

As definições de servidores ficam em `R/metadados.R`, em `srv_config`.

Exemplo:

* `bureta`
* `pipeta`

As credenciais **não devem** ser versionadas no repositório.

---

# 9. Fluxo de desenvolvimento

## Desenvolvimento local

Pode ser feito fora do servidor, por exemplo em outra máquina.

## Sincronização para ambiente de desenvolvimento

Via `rsync` para:

```text
/srv/shiny-server/anasus_dev/
```

## Produção

Publicação em:

```text
/srv/shiny-server/anasus/
```

## Recomendação

* desenvolver e testar em `anasus_dev`
* promover versão estável para `anasus`

---

# 10. Fluxo com Git

Estratégia sugerida:

* `dev` → desenvolvimento
* `main` → produção

Fluxo:

1. editar e testar
2. commitar em `dev`
3. quando estiver estável, promover para `main`
4. fazer deploy da produção

---

# 11. Próximas evoluções previstas

Entre os próximos passos possíveis:

* enriquecer o query builder com `catalogo_regras_join.json`
* usar `catalogo_papeis_semanticos.json` para melhorar detecção de campos
* criar navegador de indicadores
* gerar relatórios em Markdown/Quarto
* incluir módulos analíticos:

  * pareto
  * Kaplan-Meier
  * qui-quadrado
  * pirâmide etária
  * mapa de árvore
* adicionar validações mais fortes
* incorporar joins semânticos automáticos

---

# 12. Estado atual

No estado atual, o projeto já consegue:

* conectar ao banco
* listar `dm_`
* listar `tf_`
* listar colunas
* detectar campos semânticos
* permitir filtros básicos
* gerar SQL
* executar consulta
* mostrar tabela
* mostrar `analysis_spec`

---

# 13. Observações finais

Este repositório não é apenas um app Shiny. Ele reúne:

* código executável
* arquitetura
* catálogos semânticos
* documentação de modelagem
* convenções de desenvolvimento
* base para evolução analítica incremental

A separação entre `.R`, `.md` e `.json` é intencional:

* `.R` → implementação
* `.md` → documentação e contratos
* `.json` → catálogos estruturados e reutilizáveis
* `.sh` → automação e manutenção

---

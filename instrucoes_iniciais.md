Este projeto se chama **anasus** e é modular, incremental e orientado por metadados.

## Arquivos-base já disponíveis no projeto
- `contexto.md`
- `arquitetura_minima.md`
- `catalogo_camadas_fontes.json`
- `catalogo_fontes.json`
- `catalogo_papeis_semanticos.json`
- `catalogo_regras_join.json`
- `tarefa_geradorQuery.md`
- `app.R`
- `R/metadados.R`
- `R/ui_helpers.R`
- `R/query_builder.R`
- `R/validate_spec.R`
- `R/exec_sql.R`
- `R/paleta.R`

## Regras de trabalho
- Trabalhe apenas no módulo solicitado.
- Não tente reescrever o sistema inteiro.
- Preserve compatibilidade com os arquivos existentes.
- Antes de propor mudanças, considere o estado atual do projeto.
- Prefira alterações pequenas, explícitas e testáveis.
- Quando alterar código, diga exatamente quais arquivos devem ser modificados.
- Sempre manter separação entre:
  - metadados
  - semântica
  - geração de SQL
  - execução
  - apresentação

## Arquitetura resumida
O projeto possui:
- fontes primárias
- staging
- camada analítica (`dm_`, `tf_`)
- camada de metadado
- camada de domínio

O app base é um navegador Shiny para explorar datamarts `dm_` e tabelas `tf_`, com:
- seleção de servidor
- seleção de schema
- seleção de tabela
- seleção de colunas
- controles semânticos:
  - diagnóstico
  - procedimento
  - território
  - período
  - usuário (CNS)
  - sexo
  - idade
  - raça/cor
- exibição da query SQL completa
- exibição da tabela resultante
- exibição do `analysis_spec`

## Convenções importantes
- `td_`: domínio
- `tf_`: fato
- `tb_`: tabela OLTP
- `vw_`: view
- `mv_`: materialized view
- `dm_`: datamart
- `st_`: staging

Atributos:
- `co_`: código
- `sg_`: sigla
- `no_`: nome
- `ds_`: descrição
- `nu_`: número discreto
- `qt_`: quantidade
- `vl_`: valor
- `st_`: status

## Padrão visual
Usar `R/paleta.R` como padrão único de cores do projeto.

## Forma de resposta esperada
Quando eu pedir uma mudança:
1. diga quais arquivos serão alterados
2. explique brevemente a lógica
3. gere o conteúdo completo dos arquivos modificados
4. mantenha compatibilidade com o estado atual do projeto

## Estado atual
O app base já:
- conecta ao banco
- lista schemas `dm_`
- lista tabelas `tf_`
- lista colunas
- detecta campos semânticos
- monta query SQL
- executa query
- mostra tabela e `analysis_spec`

A partir de agora, quero evoluir o projeto incrementalmente, sem perder o que já funciona.

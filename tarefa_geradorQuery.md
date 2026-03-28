# Tarefa da iteração

## Módulo alvo
Gerador de query

## Escopo desta iteração
Implementar apenas a lógica que recebe:
- schema
- tabela
- campos selecionados
- filtros simples
- tipo de análise

e devolve:
- SQL gerado
- metadados da consulta
- mensagens de validação

## Fora de escopo
- UI Shiny completa
- execução no banco
- gráficos
- exportação de relatório
- navegador de indicadores

## Requisitos de compatibilidade
O resultado deve ser compatível com:
- navegador base
- executor de consulta
- módulos futuros de análise estatística
- fichas md de indicadores

## Entrega esperada
- proposta de estrutura de funções
- assinaturas
- objeto de retorno
- exemplo mínimo em R
- pontos de extensão para análises futuras

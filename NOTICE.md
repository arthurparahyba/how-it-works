# NOTICE

Este projeto inclui conhecimento derivado de software de terceiros.

## CodeGraph

O arquivo `skills/*/scripts/lib/node-kinds.tsv` — a tabela de tipos de nó do
tree-sitter por linguagem — foi **destilado** dos extratores por linguagem do
projeto CodeGraph:

- Projeto: CodeGraph — https://github.com/colbymchenry/codegraph
- Arquivos de origem: `src/extraction/languages/*.ts`
- Licença: MIT

Nenhum código-fonte do CodeGraph foi copiado verbatim; apenas os mapeamentos
factuais de papel → tipo de nó (ex.: em C#, `invocation_expression` = chamada)
foram reorganizados em formato tabular. A licença MIT do CodeGraph permite esse
uso mediante preservação do aviso de copyright, feita aqui.

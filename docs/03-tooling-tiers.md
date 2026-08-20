# 03 — Ferramental e tiers

Duas ferramentas cobrem todas as 7 linguagens, e ambas são determinísticas.

## ast-grep (camada estrutural)

Busca/extração estrutural sobre AST (tree-sitter). Um binário cobre Go, Java,
Python, C#, JS(X), TS(X) e Kotlin — ou seja, .NET, Java, Kotlin, Go, Python,
Angular e React. Escrito em Rust, multi-core, com padrões isomórficos ao código.
Usado para localizar a fatia e achar call sites.

## SCIP (camada de precisão)

Índices de code intelligence do Sourcegraph. Indexadores:
`scip-java` (Java, Scala, Kotlin), `scip-typescript` (TS/JS → Angular/React),
`scip-python`, `scip-dotnet` (C#), `scip-go`. O `scip-io` orquestra instalação e
merge multi-linguagem. Dá find-references / go-to-definition / find-implementations
precisos — o raio de impacto real. Exige o repo **buildável**.

## As três camadas (tiers)

| Tier | Ferramenta | Precisão | Custo |
|---|---|---|---|
| 0 | git + ripgrep | textual, ruidoso | nulo |
| 1 | ast-grep | estrutural, aproximado | baixo (binário) |
| 2 | SCIP | exato (find-references) | alto (build + índice) |

Universais e agnósticos: git (blame/log/pickaxe) e ripgrep. Piso garantido:
ast-grep (sem build). Teto quando o ambiente permite: SCIP.

Ver [decisions/0001-deterministic-first-llm-last.md](decisions/0001-deterministic-first-llm-last.md).

## Precisão da extração: tabela de node-kinds

A camada 1 (ast-grep) casa definições e chamadas por tipo de nó do tree-sitter,
não por regex. O mapa linguagem → kind vive em `scripts/lib/node-kinds.tsv`,
destilado dos extratores do CodeGraph (MIT; ver `NOTICE.md`). Isso torna
`symbol_defined`, a localização e a expansão precisas sem nenhuma dependência
nova.

O ganho medido: `LongCountAsync` e `ToListAsync`, que o eShop apenas **chama**
por serem do EF Core, eram dados como definidos ali pela heurística textual. Com
casamento por kind restrito ao campo do nome, deixam de aparecer — sem perder as
definições reais.

Cuidado operacional: em Linux, `/usr/bin/sg` é o utilitário setgroup, não o
ast-grep. A skill só aceita `sg` se `sg --version` confirmar que é o ast-grep —
prefira ter `ast-grep` no PATH.

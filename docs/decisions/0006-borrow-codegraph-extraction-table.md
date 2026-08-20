# 0006 — Emprestar a tabela de extração do CodeGraph, não a máquinaria

- **Status**: aceito
- **Data**: 2026-08-20

## Contexto

O CodeGraph resolve, de forma madura, a camada determinística de recuperação que
desenhamos: pré-indexa símbolos/arestas num SQLite e serve via MCP, com ganhos
medidos de tokens/tempo. Mas ele adiciona infraestrutura (engine nativo, índice
SQLite, servidor MCP) que conflita com nosso objetivo de simplicidade — e a
expectativa de que agentes/IDEs tragam esse tipo de índice nativamente no futuro.

## Opções consideradas

- Adotar o CodeGraph como engine (MCP): mais rápido/barato na recuperação, mas
  adiciona dependência pesada e foge da simplicidade.
- Ignorar o CodeGraph: mantém simples, mas perde conhecimento de extração testado
  (nossos padrões eram regex frágil).
- Emprestar só o conhecimento de extração: destilar a tabela de tipos de nó
  (tree-sitter) por linguagem, sem nenhuma máquinaria.

## Decisão

Emprestar apenas a tabela de extração. Distilamos `node-kinds.tsv` dos extratores
por linguagem do CodeGraph (MIT, com atribuição em `NOTICE.md`) e passamos a casar
definições/chamadas por kind do tree-sitter via ast-grep — preciso, sem SQLite,
sem MCP, sem índice persistente. Fallback textual quando ast-grep falta.

## Consequências

- Extração precisa nas 7 linguagens sem nova dependência pesada (só ast-grep, que
  já assumíamos). Regex frágil vira exceção, não regra.
- Corrigimos de quebra a colisão do nome `sg` (setgroup vs ast-grep), que podia
  rodar o binário errado silenciosamente.
- Não ganhamos o índice persistente/sub-ms do CodeGraph; aceitamos isso em nome
  da simplicidade, apostando que o índice nativo virá dos agentes/IDEs.
- Se um dia quisermos precisão de referências cruzadas ou resolução de frameworks
  (DI/Spring), o CodeGraph (dirs `resolution/frameworks`, e os design docs de
  dispatch dinâmico) fica como referência.

## Medido na aplicação

A regra como especificada tinha duas armadilhas silenciosas, ambas encontradas
testando contra repositórios reais (petclinic em Java, eShop em C#) — nenhuma
das duas produz erro, só resultado errado:

1. Regex entre **aspas duplas** no YAML: o `\b` é consumido como *backspace*
   antes de o ast-grep ver o padrão, e nenhuma regra casa. Aspas simples resolvem.
2. `has: { regex: … }` casa **qualquer descendente** do nó — o corpo inteiro do
   método. Assim `LongCountAsync`, que o eShop apenas chama (é do EF Core), era
   dado como "definido aqui": exatamente o falso positivo que a mudança vinha
   corrigir. `has: { field: name, regex: '^Nome$' }` restringe ao identificador
   da declaração.

Depois da correção, com ast-grep presente:

| símbolo | por kind | textual (antigo) |
|---|---|---|
| `LongCountAsync` (só chamado) | não achou ✓ | ACHOU ✗ |
| `ToListAsync` (só chamado) | não achou ✓ | ACHOU ✗ |
| `CatalogAI` (definido) | ACHOU ✓ | ACHOU ✓ |
| `GetItemsBySemanticRelevance` | ACHOU ✓ | ACHOU ✓ |

# Tabela de node-kinds (tree-sitter) por linguagem

Arquivo de dados: `scripts/lib/node-kinds.tsv`. Mapeia, para cada linguagem, os
tipos de nó do tree-sitter que representam cada papel (classe, função, método,
chamada, import). É o que permite à skill achar **definições** e **chamadas** de
forma precisa — casando por estrutura (kind), não por regex frágil.

## Como é usado

Os scripts preferem casamento por kind via ast-grep quando ele está no PATH:

    ast-grep scan --inline-rules "id: d
    language: csharp
    rule:
      kind: method_declaration
      has: { field: name, regex: '^ApplyDiscount$' }" src/

Quando ast-grep está ausente (ou a linguagem não está na tabela), cai para busca
textual na árvore de trabalho. Degradação graciosa, como no resto da skill.

## Duas armadilhas, ambas silenciosas

Nenhuma das duas produz erro — só resultado errado. Custaram uma bateria de
testes contra repositórios reais para aparecer.

**O regex vai em aspas simples.** Entre aspas duplas, o YAML interpreta `\b` como
*backspace* antes de o ast-grep ver o padrão, e a regra nunca casa.

**`has: { regex: … }` casa qualquer descendente do nó**, ou seja, o corpo inteiro
do método. No eShop isso fazia `LongCountAsync` — que o projeto só *chama*, por
ser do EF Core — aparecer como definido ali. `field: name` restringe ao
identificador da declaração, e ancorar com `^…$` evita que `Catalog` case com
`CatalogAI`.

## Onde é usado no pipeline

| Script | O que ganha |
|---|---|
| `locate_slice.sh` | a **definição** do símbolo vai para o topo das sementes |
| `expand_impact.sh` | arestas rotuladas: `[definicao]`, `[chamada]`, `[referencia]` |
| `check_anchors.sh` | qual declaração contém uma linha, pelo parser em vez de regex |
| `validate_proposal.sh` (fase 2) | "este símbolo existe?" sem falso positivo |

## Cobertura

As 7 linguagens-alvo (.NET/C#, Java, Kotlin, Go, Python, TypeScript/Angular,
JavaScript/React). Verificadas em execução: **C# e Java**, contra eShop e
spring-petclinic. As outras cinco vêm da tabela do CodeGraph e ainda não foram
exercitadas aqui.

## Atenção: colisão do nome `sg`

Em Linux, `/usr/bin/sg` é o utilitário *setgroup*, não o ast-grep. A skill só
aceita `sg` como ast-grep se `sg --version` confirmar. Prefira ter `ast-grep` no
PATH para evitar ambiguidade.

## Procedência

A tabela foi destilada dos extratores por linguagem do CodeGraph
(`src/extraction/languages/*.ts`) — ver `NOTICE.md` na raiz do repositório para a
atribuição de licença.

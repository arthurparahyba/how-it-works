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

## Três armadilhas, todas silenciosas

Nenhuma delas chega ao usuário como erro — só como resultado errado (a terceira
até produz erro, mas em um stderr que o pipeline descarta). Custaram uma bateria
de testes contra repositórios reais para aparecer.

**O regex vai em aspas simples.** Entre aspas duplas, o YAML interpreta `\b` como
*backspace* antes de o ast-grep ver o padrão, e a regra nunca casa.

**`has: { regex: … }` casa qualquer descendente do nó**, ou seja, o corpo inteiro
do método. No eShop isso fazia `LongCountAsync` — que o projeto só *chama*, por
ser do EF Core — aparecer como definido ali. `field: name` restringe ao
identificador da declaração, e ancorar com `^…$` evita que `Catalog` case com
`CatalogAI`.

**A gramática pode não ter campo nenhum.** Em Kotlin, `class_declaration`,
`function_declaration` e `call_expression` não expõem `name` nem `function`: o
nome é um filho sem campo (`simple_identifier`; `type_identifier` na classe). E o
modo de falha é traiçoeiro — a regra com um `field:` inexistente **não deixa de
casar, ela deixa de parsear**, e como o stderr do ast-grep é descartado, o
pipeline caía para busca textual sem avisar. Kotlin rodou como tier0 se dizendo
tier1 até isso aparecer. Por isso os matchers são escolhidos **por linguagem** em
`_ag_matchers_for`, e a chamada `obj.metodo()` do Kotlin precisa de uma regra que
desce até `navigation_suffix` — o filho direto da chamada é o receptor.

## Onde é usado no pipeline

| Script | O que ganha |
|---|---|
| `locate_slice.sh` | a **definição** do símbolo vai para o topo das sementes |
| `expand_impact.sh` | arestas rotuladas: `[definicao]`, `[chamada]`, `[referencia]` |
| `check_anchors.sh` | qual declaração contém uma linha, pelo parser em vez de regex |
| `validate_proposal.sh` (fase 2) | "este símbolo existe?" sem falso positivo |

## Cobertura

As 7 linguagens-alvo (.NET/C#, Java, Kotlin, Go, Python, TypeScript/Angular,
JavaScript/React). Verificadas em execução: **C#, Java e Kotlin** — eShop,
spring-petclinic e spring-petclinic-kotlin. Go, Python, TypeScript e JavaScript
vêm da tabela do CodeGraph e só foram exercitadas em fixtures mínimas
(definição + chamada), não contra repositório real.

## Atenção: colisão do nome `sg`

Em Linux, `/usr/bin/sg` é o utilitário *setgroup*, não o ast-grep. A skill só
aceita `sg` como ast-grep se `sg --version` confirmar. Prefira ter `ast-grep` no
PATH para evitar ambiguidade.

## Procedência

A tabela foi destilada dos extratores por linguagem do CodeGraph
(`src/extraction/languages/*.ts`) — ver `NOTICE.md` na raiz do repositório para a
atribuição de licença.

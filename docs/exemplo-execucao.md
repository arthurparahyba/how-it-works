# Exemplo de execução — passo a passo, com entrada e saída reais

Este documento acompanha **uma execução real** do pipeline da skill
`how-it-works`, um estágio por vez, registrando exatamente o que entra e o que
sai de cada script. Não é a skill rodando de ponta a ponta: é a dissecação dela.

Serve para responder, sem adivinhação, a pergunta que sempre aparece quando
alguém vai mexer no pipeline: *"o que este estágio recebe, o que ele devolve, e
de onde vem cada campo da saída?"*

## O cenário

| | |
|---|---|
| **Pergunta do desenvolvedor** | "quero melhorar a busca de owners por sobrenome" |
| **Repositório-alvo** | [spring-petclinic](https://github.com/spring-projects/spring-petclinic) |
| **Commit pinado** | `88e37c15cf6fc8490b01bc3e8e2c800cec1ac272` |
| **Por que este caso** | é o eval nº 1 (`evals/evals.json`): fatia pequena, mas com um símbolo sem implementação no código, comportamento que só existe no schema SQL e commits que explicam o não-óbvio |
| **Máquina** | macOS, com `ast-grep` 0.45.1, `ripgrep` 15.1.0 e `gh` 2.94.0 no PATH; **sem** `scip` |

O commit é pinado de propósito. Sem isso, qualquer número de linha registrado
aqui apodrece na primeira vez que o upstream mexer no arquivo.

---

## Passo 1 — Detectar capacidades

> `scripts/detect_capabilities.sh [caminho_do_repo]`

O primeiro estágio não olha o código e **não olha a pergunta do desenvolvedor**.
Ele responde só: *"o que esta máquina consegue fazer neste repositório?"* — e
disso decide o teto de precisão do resto do pipeline.

A ordem importa: só faz sentido escolher a estratégia de busca depois de saber
quais ferramentas existem. Descobrir no meio do caminho que falta `ast-grep`
obrigaria a refazer o estágio anterior.

### Entrada

Um argumento, opcional:

```bash
scripts/detect_capabilities.sh /caminho/do/petclinic
```

Sem argumento, ele usa `git rev-parse --show-toplevel` (a raiz do repositório
onde você está) e, se nem isso funcionar, o diretório atual.

Repare no que **não** é entrada: a frase "quero melhorar a busca de owners por
sobrenome" não chega aqui. Nenhum termo de busca, nenhum símbolo. Este passo é
independente do pedido — a mesma máquina e o mesmo repositório dão sempre a
mesma resposta, seja qual for a pergunta.

### Saída (stdout) — o que realmente saiu

```json
{
  "root": ".../scratchpad/petclinic",
  "languages": ["java"],
  "tools": {
    "ast_grep": true,
    "ripgrep": true,
    "scip_cli": false,
    "gh": true
  },
  "scip_index": { "present": false, "path": "", "freshness": "unknown" },
  "design_map": { "present": false, "path": "" },
  "buildable": true,
  "precision_tier": "tier1",
  "upgrade_hint": "Sem indice SCIP: as arestas sao estruturais mas locais. Um indice construido no caminho frio (CI) daria find-references reais. Ver docs/05-performance.md."
}
```

### Saída (stderr) — o diário de bordo

```
  detectando capacidades em: .../scratchpad/petclinic
  tier de precisao: tier1 | linguagens:  java
```

A separação é deliberada: **stdout é o dado, stderr é a narração.** Por isso um
`detect_capabilities.sh > caps.json` produz um JSON válido, sem sujeira de log
no meio. Todo script do pipeline segue essa convenção, definida nos helpers
`log()` e `warn()` em [`scripts/lib/common.sh`](../skills/how-it-works/scripts/lib/common.sh).

**Custo medido:** 0,34 s.

---

### De onde veio cada campo

Isto é o que torna o passo auditável: nenhum campo é palpite, cada um sai de uma
sonda que você pode repetir na mão.

#### `languages: ["java"]`

O script testa uma lista fixa de extensões com `git ls-files`. Rodando as sondas
individualmente no petclinic:

| extensão | arquivos rastreados |
|---|---|
| `.java` | **49** |
| `.cs`, `.kt`, `.go`, `.py`, `.ts`, `.tsx`, `.js`, `.jsx` | 0 |

Daí `["java"]`. Uma linguagem entra na lista no **primeiro** arquivo encontrado —
o script não conta, só verifica existência, o que mantém o custo baixo em repo
grande.

#### `tools`

Um `command -v` para cada ferramenta:

```
ast-grep  /opt/homebrew/bin/ast-grep    -> true
rg        /opt/homebrew/bin/rg          -> true
gh        /opt/homebrew/bin/gh          -> true
scip      AUSENTE                       -> false
```

Detalhe que já causou estrago e está comentado no código: o `ast-grep` também se
expõe como `sg`, mas em Linux `/usr/bin/sg` é o utilitário *setgroup*, coisa
completamente diferente. Por isso `astgrep_bin()` só aceita `sg` depois de
confirmar, pelo `--version`, que é mesmo o ast-grep.

#### `scip_index: present false`

Procura um índice já construído em quatro lugares conhecidos. Nenhum existe:

```
index.scip                   nao
.scip/index.scip             nao
build/index.scip             nao
.cache/scip/index.scip       nao
```

O campo `freshness` fica `"unknown"` porque só é calculado quando há índice *e*
o CLI `scip` está presente — aí ele compara o mtime do índice com a data do
último commit para decidir entre `fresh` e `stale`.

**Ele nunca constrói o índice.** Construir é trabalho frio, de CI; aqui é
caminho quente e só se lê cache.

#### `design_map: present false`

Mesma ideia — cinco candidatos, nenhum presente no petclinic:

```
docs/design-map.md, ARCHITECTURE.md, docs/architecture.md,
openspec/specs/README.md, .claude/design-map.md
```

Consequência prática para os passos seguintes: sem mapa de design, o passo 3 não
tem um *prior* de onde procurar e busca no repositório inteiro. Funciona, só sai
mais largo. A `SKILL.md` manda sugerir ao usuário criar um mapa no fim da
explicação.

#### `buildable: true`

Heurística barata: existe algum marcador de projeto rastreado? No petclinic o
laço encontra `pom.xml` (e `build.gradle`) e para no primeiro.

```
*.sln            (nada)
*.csproj         (nada)
pom.xml          pom.xml       <- encontrou aqui, parou
```

"Buildable" aqui significa *aparenta ser construível*. O script não roda build
nenhum.

#### `precision_tier: "tier1"` — a decisão que governa o resto

Toda a regra são três linhas:

- **`tier2`** — há índice SCIP presente **e** fresco **e** o CLI `scip` no PATH.
- **`tier0`** — não há `ast-grep`.
- **`tier1`** — o caso restante, e é onde este ambiente caiu: `ast-grep` sim,
  SCIP não.

Traduzindo para o que o desenvolvedor vai receber lá na frente: as arestas de
"quem chama quem" serão **estruturais** (casadas por tipo de nó da árvore
sintática, distinguindo definição de chamada de referência), mas **locais** —
não são um *find references* real de compilador.

#### `upgrade_hint`

O campo existe por uma razão explicada no comentário do próprio script: dizer só
"tier1" não ajuda ninguém, porque quem lê não sabe que dá para melhorar nem
como. Então o script informa o caminho — e **não instala nada**. Instalar
software é decisão do dono da máquina, o gerenciador varia por sistema, e rodar
em tier mais baixo é comportamento previsto, não defeito.

Neste caso a dica é sobre o índice SCIP. Numa máquina sem `ast-grep`, o tier
seria `tier0` e a dica traria os três comandos possíveis (`brew`, `npm`,
`cargo`) para o usuário escolher.

---

### Modos de falha (testados)

| Situação | Saída | Exit |
|---|---|---|
| Caminho inexistente | `{"error":"repo inacessivel"}` | `1` |
| Diretório que não é repositório git | JSON normal, com `languages: []` e `buildable: false` | `0` |

O segundo caso é a armadilha silenciosa: **não dá erro**. Ele degrada, e cabe a
quem chama perceber que uma lista de linguagens vazia num repositório de verdade
significa algo errado.

### Uma consequência que vale conhecer: só o que o git rastreia é visto

Tudo que depende de `git ls-files` enxerga apenas arquivo rastreado. Demonstrado
com um arquivo `.py` novo dentro do petclinic:

```bash
# arquivo criado, ainda não adicionado
"languages": ["java"]

# depois de um git add
"languages": ["java","python"]
```

Ou seja: código novo, ainda não commitado nem adicionado ao índice, é **invisível**
ao passo 1 — e, pelo mesmo motivo, à coleta de configuração e à busca por testes
mais adiante. Não é bug, é o preço de usar o git como fonte da lista de arquivos
(que é o que dá a ele o filtro gratuito de `node_modules`, `target`, `build` e
companhia).

---

### Resumo do passo 1

- **Recebe:** um caminho de repositório. Só isso — não recebe a pergunta.
- **Devolve:** um JSON de capacidades no stdout, narração no stderr.
- **Decide:** o `precision_tier`, que é o teto de confiança de tudo que vem depois.
- **Nunca:** constrói índice, instala ferramenta, roda build ou lê código-fonte.
- **Custou:** 0,34 s.

Neste ambiente e neste repositório: **tier1**, java, com `ast-grep` e sem SCIP.
É com essa restrição que os próximos passos vão trabalhar.

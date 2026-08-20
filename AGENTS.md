# AGENTS.md — o que é este repositório

## Em uma frase

Uma skill de Claude Code que **explica a fatia de código relevante a uma mudança,
antes de a mudança existir** — de forma concisa, precisa e didática, escopada ao
que o desenvolvedor perguntou.

Não documenta o repositório inteiro. Não propõe solução. Responde *"como isso
funciona hoje?"* para que o dev e o agente discutam a mudança sobre fatos.

## O princípio que governa tudo

**Ferramentas determinísticas coletam os fatos; o LLM só julga e redige.**

Fatos — estrutura, referências, histórico, configuração — não devem passar pelo
modelo. São coletados por scripts bash e entregues mastigados num dossiê. O
modelo entra em dois pontos apenas: no começo, traduzindo o pedido em
identificadores de busca, e no fim, escrevendo a explicação.

Isso corta tokens, acelera e reduz alucinação. Se você for mexer aqui, **não
inverta essa ordem**: coletar antes, raciocinar depois.

O racional completo está em `docs/decisions/0001-deterministic-first-llm-last.md`.

## Onde está o quê

```
skills/how-it-works/          A SKILL. É isto que o projeto entrega.
  SKILL.md                    o que o modelo lê ao ser invocado
  scripts/                    o pipeline determinístico (bash)
  references/synthesis-prompt.md  como escrever a explicação — leia antes de mexer na saída
  references/dossier-schema.md    o formato do dossiê
  references/tiers-and-degradation.md  os níveis de precisão
  evals/                      casos de teste + gabarito (nunca lido em runtime)

skills/propose-implementation/  FASE 2, em revisão. Ver "Decisões em aberto".
docs/                         definição viva do design + ADRs numerados
install.sh                    symlink das skills para ~/.claude/skills/
```

## O pipeline

Oito estágios; seis são bash. `build_dossier.sh` é o orquestrador e executa
todos os outros por dentro — **rodá-los avulsos antes dele paga tudo duas vezes**.

| Estágio | Script | O que faz |
|---|---|---|
| P0 | — | procura mapa de design (`docs/design-map.md`, `ARCHITECTURE.md`) |
| P1 | `detect_capabilities.sh` | decide o `precision_tier` pelo que há no PATH |
| P2 | **modelo** | traduz o pedido em identificadores de busca |
| P3 | `locate_slice.sh` | acha as sementes, ranqueadas por raridade do termo |
| P4 | `expand_impact.sh` | quem chama / é chamado pelo símbolo central |
| P4b | `collect_config.sh` | schema, migrations e config de aplicação |
| P4c | `enrich_provenance.sh` | commits e PRs — a camada do "porquê" |
| P5 | `build_dossier.sh` | une tudo, trunca, emite markdown |
| P6 | **modelo** | escreve a explicação |
| P7 | `check_anchors.sh` | confere se cada `arquivo:linha` aponta para o que o texto diz |

Os tiers de precisão: `tier2` (índice SCIP fresco, referências exatas), `tier1`
(ast-grep, estrutural aproximado), `tier0` (texto, ruidoso). O caminho quente
**nunca constrói** índice — só lê cache.

## Coisas que já custaram caro e não devem ser reintroduzidas

Cada uma abaixo saiu de uma falha observada em execução real, não de revisão.

**`rg` sem caminho de busca lê o stdin.** Se a chamada estiver dentro de um
`while read ... done < arquivo`, o ripgrep lê o arquivo do laço em vez do
repositório *e* consome o stdin, matando o laço na primeira iteração. Sempre
passe `.` e `</dev/null`.

**`declare -A` não existe no bash 3.2**, que é o que o macOS entrega. O projeto
tem de rodar em Linux, macOS e Git Bash. Também fora: `xargs -r`, `sed -i` sem
sufixo, `readlink -f`.

**Classes de caractere acentuadas (`[aã]`, `[cç]`) com `grep -i` estouram o
ugrep**, que é o grep padrão em algumas máquinas — e ele falha em silêncio, o
que faz uma checagem quebrada parecer um resultado ruim. Use `.` no lugar.

**Casar nome de arquivo contra o caminho inteiro** faz um diretório chamado
`owner/` transformar todo arquivo dentro dele em "teste de Owner". Case sempre
contra o basename.

**Cap que corta por ordem de linha descarta a informação mais específica.** O
`locate_slice.sh` ranqueia por raridade do termo antes de cortar: termo raro é
termo específico.

**Detecção de símbolo por regex é frágil.** A tabela `scripts/lib/node-kinds.tsv`
(destilada do CodeGraph, MIT — ver `NOTICE.md`) mapeia linguagem → tipo de nó do
tree-sitter, e o casamento por kind via ast-grep substitui o palpite textual. Duas
armadilhas silenciosas na regra YAML, que não dão erro e só produzem resultado
errado: o regex precisa ir em **aspas simples** (entre aspas duplas o YAML come o
`\b` como backspace), e precisa de `field: name` (sem isso, `has: {regex}` casa o
corpo inteiro do método e um símbolo apenas *chamado* passa por *definido*).

**Comportamento vive fora do código.** No petclinic, a busca só é insensível a
maiúsculas por causa de `VARCHAR_IGNORECASE` no schema do H2. No eShop, a busca
semântica só existe se a configuração registrar um gerador de embeddings. Nenhum
`.java`/`.cs` diz isso. É por isso que `collect_config.sh` existe e converte
nomenclatura entre camadas (`lastName` → `last_name` → `last-name`).

**Seção vazia do dossiê precisa falar.** Um raio de impacto vazio quase sempre
significa símbolo errado, não ausência de dependências. O dossiê emite o
diagnóstico em vez de um campo em branco.

## Como testar

O eval não roda sozinho: ele grada uma explicação que já existe.

```bash
# 1. dispare um subagente de contexto limpo apontando para skills/how-it-works/SKILL.md,
#    com o prompt do caso e um caminho de saída
# 2. grade a saída:
skills/how-it-works/evals/check_assertions.sh <nome-do-caso> <arquivo-gerado>
```

Casos em `evals/evals.json`, todos com **commit pinado** (sem isso o gabarito
apodrece quando o upstream mexe nas linhas).

Estado da cobertura: 3 casos, 2 linguagens (Java/Spring no petclinic, .NET no
eShop), **todos em `tier0`**. O README promete sete linguagens. `tier1` e `tier2`
nunca foram exercitados.

Ao escrever asserção: **teste o conceito, não o vocabulário**. Uma asserção que
exigia a palavra "fallback" reprovou uma explicação que dizia "busca comum por
nome" — media estilo, não conteúdo. E rode o eval contra uma saída que você
*sabe* que é boa: é assim que se descobre que o eval está errado.

## Onde vai o tempo (medido, não estimado)

```
pipeline determinístico    ~5 s      dos quais ~80% é `gh pr list` em série
modelo (laço agêntico)   ~155 s
```

O gargalo nunca esteve nos scripts. Está no número de idas e voltas: cada
chamada de ferramenta faz o modelo reprocessar todo o contexto acumulado. Por
isso a `SKILL.md` manda agrupar chamadas independentes e usar o orquestrador.

Otimizações já aplicadas e medidas: dossiê em markdown em vez de JSON com base64
(−55% de tokens de leitura), leituras obrigatórias de 5 arquivos para 2.

## Decisões em aberto

**A fase 2 (`propose-implementation`) provavelmente vai encolher.** Ela gera
`proposal.md`/`design.md`/`tasks.md` e materializa `openspec/changes/<id>/` —
que é o que o `propose` do OpenSpec já faz. O que ela tem de próprio e não
duplica: `validate_proposal.sh` (os símbolos citados existem?) e
`proposal_impact.sh` (o que quebra, quais testes cobrem). A direção é virar uma
camada de verificação sobre a proposta que o OpenSpec gerou, não uma
concorrente. Nunca rodou de ponta a ponta.

**O disparo automático pela `description` nunca foi testado** — as skills não
estão instaladas em `~/.claude/skills/`, e os testes sempre apontaram direto
para o `SKILL.md`.

## Convenções

- Documentação e comentários em **português**; nomes de arquivo, símbolos e
  mensagens de commit técnicas em inglês quando for o idioma do domínio.
- Comentário de script explica **por que**, não o que — e cita a falha que
  motivou a linha quando houver.
- ADRs numerados em `docs/decisions/`, template em `adr-template.md`.
- Mensagem de commit descreve a falha observada, não só a mudança.

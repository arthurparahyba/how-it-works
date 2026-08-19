# Feature Explainer

Skills que **explicam a fatia de código relevante a uma mudança antes de
implementá-la** — de forma objetiva, concisa e no nível de detalhe certo, para o
desenvolvedor e o agente discutirem a solução antes de defini-la.

Não documenta o repositório inteiro. Foca na funcionalidade em questão, é rápida
mesmo em bases grandes e barata em tokens (o LLM entra só no fim).

Funciona em **.NET, Java, Kotlin, Go, Python, Angular e React**.

## Status

- **Fase 1 — "como é hoje"** (`skills/explain-current-state/`): implementada.
- **Fase 2 — "proposta"** (`skills/propose-implementation/`): implementada.

As duas fases são separadas por um checkpoint humano: o desenvolvedor valida o
entendimento do código (fase 1) antes de o agente propor abordagens, e escolhe
entre 2–3 abordagens (fase 2) antes do plano detalhado. A fase 2 valida a
proposta de forma determinística (símbolos existem? raio de impacto real?) e
emite os artefatos do `openspec propose`.

## Princípio

Ferramentas determinísticas (git, ast-grep, SCIP) coletam os fatos e os entregam
num dossiê compacto; o LLM só julga e redige, uma única vez. Menos tokens, mais
rápido, mais assertivo. Detalhe abundante em `docs/`.

## Estrutura

```
claude-feature-explainer/
├── skills/
│   ├── explain-current-state/     # fase 1 — investigar e explicar
│   │   ├── SKILL.md
│   │   ├── scripts/               # pipeline determinístico (bash)
│   │   ├── references/            # schema, prompt de síntese, tiers
│   │   └── assets/                # template da explicação
│   └── propose-implementation/    # fase 2 — abordagens, validação, handoff
│       ├── SKILL.md
│       ├── scripts/               # validação + impacto + emissão OpenSpec
│       ├── references/            # prompt de proposta, artefatos, checagens
│       └── assets/                # templates de proposta e OpenSpec
├── docs/                          # definição viva do design + ADRs
└── install.sh                     # instala a skill no Claude Code
```

## Instalação (Claude Code)

Coloque este repositório em `~/.claude/` e rode o instalador:

```bash
mv claude-feature-explainer ~/.claude/          # se ainda não estiver lá
cd ~/.claude/claude-feature-explainer
./install.sh
```

O instalador cria um symlink de `skills/explain-current-state` para
`~/.claude/skills/`, onde o Claude Code descobre skills pessoais. Depois é só
pedir, num repositório de código: *"explique como funciona X antes de eu mexer"*.

## Ferramentas recomendadas no PATH (opcionais)

- `ast-grep` (`sg`) — camada estrutural (recomendado; cobre as 7 linguagens).
- `ripgrep` (`rg`) — busca textual rápida.
- `scip` + indexadores (`scip-java`, `scip-typescript`, `scip-dotnet`, …) —
  precisão de impacto (tier2). O orquestrador `scip-io` facilita.
- `gh` — recupera PRs na camada do "porquê".

Nenhuma é obrigatória: a skill detecta o que existe e degrada graciosamente.

## Compatibilidade

Alvo primário Claude Code; Cursor e Devin CLI planejados (ver
`docs/08-cross-tool-compat.md`). Integra com OpenSpec como passo pré-`propose`
(ver `docs/07-openspec-integration.md`).

## Licença

MIT.

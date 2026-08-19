# 07 — Integração com OpenSpec

## O ponto de encaixe

O OpenSpec recomenda explorar antes de propor ("Explore First", comando
`/opsx:explore`), mas trata esse passo de forma rasa. Esta solução **enriquece
esse slot**: substitui o "o agente pensa um pouco" por um estudo estruturado e
escopado que produz uma explicação clara e discutível antes do `propose`.

Não briga com o fluxo do OpenSpec — preenche o buraco que ele mesmo aponta.

## Fluxo integrado

```
descrição da mudança
  → [fase 1: explain-current-state]  ← esta skill
  → explicação clara ("como é hoje")
  → dev comenta / ajusta               ← checkpoint humano
  → [fase 2: proposta]                 ← futura
  → openspec propose                   ← já fundamentado
  → apply → archive
```

## Onde salvar o handoff

O OpenSpec organiza mudanças em `openspec/changes/<id>/` com `proposal.md`,
`design.md`, `tasks.md` e delta specs. Salve o resultado da fase 1 ao lado:

- `openspec/changes/<id>/current-state.md` — a explicação validada.
- `openspec/changes/<id>/current-state.dossier.json` — o dossiê (para a fase 2
  reusar sem reinvestigar).

Assim o `openspec propose` parte de um entendimento já destilado e aprovado, em
vez de disparar às cegas. A investigação nunca se perde entre etapas.

## Realimentação

As explicações de "como é hoje" podem realimentar o mapa de design vivo e os
`openspec/specs/` (fonte de verdade do comportamento atual) — um ciclo virtuoso
onde investigar mantém o mapa fresco.

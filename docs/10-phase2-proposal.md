# 10 — Fase 2: proposta de implementação

## O que é

Depois de entender *como é hoje* (fase 1), a fase 2 define *o que fazer*. É a
skill `propose-implementation`. Natureza diferente da fase 1: aqui o trabalho é
de julgamento (gerar opções e trade-offs), então o LLM tem papel maior — mas
**cercado por validação determinística**.

## O fluxo

```
dossiê validado (fase 1)
  → gerar 2–3 abordagens com trade-offs (LLM)
  → [CHECKPOINT] dev escolhe/ajusta
  → validar a escolha (determinístico): símbolos existem? raio de impacto real?
  → elaborar plano (LLM, informado pela validação)
  → quebrar em tarefas revisáveis
  → emitir proposal.md / design.md / tasks.md → openspec propose
```

## Por que abordagens, não um monólogo

O erro comum de propostas de IA é apresentar uma única abordagem como óbvia. A
fase 2 gera 2–3 abordagens distintas (desfechos diferentes, não tons), cada uma
com o que prioriza e o que sacrifica. O desenvolvedor decide. Só colapsa para
uma quando a mudança é trivial. Inspiração: a fase Plan do Spec Kit/OpenSpec e o
padrão de múltiplas estratégias.

## A camada de validação (o diferencial)

Duas checagens determinísticas cercam o LLM e pegam o erro clássico de propor
código que não fecha com a realidade:

- **`validate_proposal.sh`** — os símbolos/arquivos citados existem (ou são
  novos sem colisão)? Bloqueia com `needs_fix` se a proposta alucinar uma API.
- **`proposal_impact.sh`** — qual o raio de impacto real dos pontos tocados
  (o que quebra) e quais testes cobrem? Para o dev não ser surpreendido.

Isto é o "trust-but-verify" aplicado à própria proposta. Ver
`skills/propose-implementation/references/validation-checks.md`.

## O checkpoint humano

Entre gerar as abordagens e elaborar o plano há uma parada obrigatória: o dev
escolhe/ajusta. Isso evita elaborar em profundidade uma abordagem errada — a
razão de separarmos as duas fases desde o início (ver
`decisions/0005-two-step-with-validation.md`).

## Handoff

`emit_openspec_change.sh` materializa `openspec/changes/<id>/` com
proposal/design/tasks, copia junto o current-state da fase 1, e roda
`openspec validate` se o CLI existir. Daí em diante, o fluxo normal do OpenSpec
(propose → apply → archive) segue já fundamentado.

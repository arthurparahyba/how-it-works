# 0005 — Duas etapas com checkpoint e validação da proposta

- **Status**: aceito
- **Data**: 2026-08-19

## Contexto

A explicação do estado atual (fase 1) e a proposta (fase 2) têm naturezas
diferentes: investigação pura vs geração de opções. Além disso, propostas de IA
tendem a (a) apresentar uma única abordagem como óbvia e (b) referenciar APIs que
não existem.

## Opções consideradas

- **Uma passada só** (entender + propor juntos): mais rápido, mas arrisca
  elaborar uma proposta em cima de entendimento errado, sem ponto de revisão.
- **Duas etapas com checkpoint humano**: o dev valida o entendimento antes de o
  agente propor; e escolhe entre abordagens antes de o agente detalhar o plano.

## Decisão

Duas etapas separadas com checkpoint humano entre elas. A fase 2 gera 2–3
abordagens com trade-offs (não um monólogo) e, após a escolha, valida a proposta
de forma determinística (`validate_proposal.sh`, `proposal_impact.sh`) antes de
elaborar o plano final.

## Consequências

- O dev revisa o entendimento do código antes da proposta, e escolhe a direção
  antes do detalhamento — menos retrabalho.
- Propostas não referenciam APIs inexistentes (validação bloqueia `needs_fix`).
- Custo: um passo humano a mais e scripts de validação adicionais. Aceito — é o
  que torna a proposta confiável o suficiente para decidir em cima dela.

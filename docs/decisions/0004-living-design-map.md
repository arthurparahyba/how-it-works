# 0004 — Mapa de design vivo como prior

- **Status**: aceito
- **Data**: 2026-08-19

## Contexto

Localizar a fatia certa é o passo mais caro e mais propenso a erro. Uma
documentação básica e viva do design pode orientar essa localização e dar ao LLM
a intenção que a análise estática não infere.

## Opções consideradas

- **Sem mapa**: pipeline funciona, mas localização parte do zero a cada vez.
- **Mapa 100% à mão**: apodrece (o "monstro de markdown").
- **Mapa híbrido**: estrutura gerada automaticamente, intenção curada à mão.

## Decisão

Adotar um mapa de design vivo híbrido como **terceiro insumo** (junto com fatos
determinísticos e LLM). Camada estrutural gerada/atualizada de rotina (CI, com PR
na deriva); camada de intenção pequena e curada. Trust-but-verify: a camada
determinística valida o mapa contra a realidade.

## Consequências

- Localização mais rápida, precisa e objetiva; LLM recebe intenção de design.
- Superfície de manutenção adicional; um mapa errado engana — por isso a
  validação e o sinal de deriva são obrigatórios.
- Encaixa com `openspec/specs/` (comportamento) e ADRs (arquitetura).

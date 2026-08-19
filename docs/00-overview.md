# 00 — Visão geral

## O que é

Uma solução que, **antes de implementar** um bug/feature/melhoria, gera uma
explicação clara e objetiva sobre o código — no nível de detalhe certo — para o
desenvolvedor e o próprio agente discutirem a solução antes de defini-la.

Não explica o repositório inteiro: foca na **fatia relevante** à mudança. E é
projetada para ser **rápida mesmo em bases grandes** e **barata em tokens**.

## Duas fases

1. **Como é hoje** (esta entrega): investiga e explica a implementação atual da
   fatia. É a fase 1.
2. **Proposta** (fase 2, futura): define o que fazer, com trade-offs. Alimenta o
   `openspec propose`.

Entre as fases há um **checkpoint humano**: o dev valida o entendimento do
código antes de o agente propor qualquer abordagem. Isso evita propostas
elegantes construídas sobre entendimento errado.

## Princípio central

**Determinístico coleta os fatos; o LLM só julga e redige.** Estrutura,
referências e histórico vêm de ferramentas que não alucinam (ast-grep, SCIP,
git). O modelo entra uma única vez, no fim, recebendo um dossiê denso em vez de
código cru. Menos tokens, mais rápido, mais assertivo.

## Inspiração

O pipeline vem do PocketFlow (identificar peças → mapear relações → sequenciar →
explicar, com "visão da águia" antes do "mergulho"), mas **escopado a uma
mudança** e com a coleta de fatos trocada de LLM por scripts determinísticos.
Camadas emprestadas de: DeepWiki (saída estrutural + diagrama), Aider (ranquear
por referências), Greptile (grafo de impacto), Unblocked (a camada do "porquê"),
Spec Kit/OpenSpec (fases revisáveis antes do código).

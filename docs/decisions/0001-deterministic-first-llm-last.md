# 0001 — Determinístico primeiro, LLM por último

- **Status**: aceito
- **Data**: 2026-08-19

## Contexto

Explicações geradas puramente por LLM sobre código cru são caras em tokens,
lentas e propensas a alucinar arestas (chamadores, dependências). O PocketFlow,
inspiração do pipeline, é quase todo LLM e não escala para repos grandes.

## Opções consideradas

- **Tudo LLM** (PocketFlow puro): simples, mas caro, lento e menos assertivo.
- **Tudo determinístico**: barato e rápido, mas incapaz de julgar intenção,
  preencher lacunas ou redigir bem.
- **Híbrido — fatos determinísticos, julgamento do LLM**: mais partes móveis,
  mas ataca custo, velocidade e assertividade juntos.

## Decisão

Híbrido. Ferramentas determinísticas (git, ast-grep, SCIP) coletam os fatos e os
entregam num dossiê compacto. O LLM entra uma única vez, no fim, para julgar e
redigir. Fatos nunca passam pelo modelo para serem "descobertos".

## Consequências

- Menos tokens (dossiê denso, não código cru), mais rápido, mais assertivo.
- O LLM continua sendo o único que interpreta o mapa, preenche lacunas da análise
  estática e sinaliza incerteza.
- Custo: mais componentes para manter (scripts + degradação). Aceito.

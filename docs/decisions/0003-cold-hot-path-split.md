# 0003 — Separar caminho frio e quente

- **Status**: aceito
- **Data**: 2026-08-19

## Contexto

A precisão máxima do raio de impacto vem do SCIP, que é whole-repo e exige build
— caro. Mas cada explicação precisa ser rápida.

## Opções consideradas

- **Construir o índice a cada explicação**: preciso, mas mata a performance.
- **Nunca usar SCIP**: rápido, mas perde precisão de impacto.
- **Amortizar o índice**: construir frio, ler quente.

## Decisão

Separar. O build do índice SCIP (e o refresh da camada estrutural do mapa) roda
no **caminho frio** (CI/background), keyed por commit e incremental. O **caminho
quente** (por pedido) apenas lê os caches; nunca constrói nada caro.

## Consequências

- O custo caro sai do caminho quente e vira infra. Tempo quente dominado só pela
  chamada de LLM.
- Requer infra de CI/cache. Quando ausente, degrada para ast-grep (tier1) sem
  quebrar.
- Índice stale é usado com aviso de incerteza, não descartado.

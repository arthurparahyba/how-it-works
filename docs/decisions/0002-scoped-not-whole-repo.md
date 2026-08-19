# 0002 — Escopado à fatia, não ao repo inteiro

- **Status**: aceito
- **Data**: 2026-08-19

## Contexto

O objetivo é explicar a **funcionalidade em questão** antes de mexer nela, não
documentar a aplicação inteira. E deve ser rápido mesmo em bases grandes.

## Opções consideradas

- **Whole-repo** (estilo DeepWiki/PocketFlow): ótimo para onboarding, mas caro,
  lento e desalinhado com o objetivo (excesso de contexto irrelevante).
- **Escopado à mudança**: localiza a fatia e expande um raio limitado.

## Decisão

Escopado. O pipeline localiza a semente da fatia (a partir da descrição da
mudança) e expande 1 salto, com cap no top-N. O conjunto de trabalho fica pequeno
independentemente do tamanho do repo.

## Consequências

- Tempo ~constante em base grande; explicação focada no que importa.
- O passo de **localização** vira o mais crítico (errar aqui contamina tudo) —
  daí o valor do mapa de design vivo como prior (ver 0004).
- A única análise que "quer ver o repo inteiro" é o find-references preciso
  (SCIP), tratado como trabalho frio amortizado (ver 0003).

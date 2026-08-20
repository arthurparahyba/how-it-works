# 04 — Fluxo de execução

## Caminho frio (infra, amortizado)

- **Build do índice SCIP**: quando o repo compila. Keyed por commit, incremental.
- **Refresh do mapa de design**: regenera só a camada estrutural; faz diff contra
  o commitado; abre PR quando a estrutura derivou.

Saída: caches (índice SCIP, mapa de design) que o caminho quente apenas lê.

## Caminho quente (por pedido "explique esta funcionalidade")

| Estágio | Determinístico? | Ferramenta | Saída |
|---|---|---|---|
| 0. Ler pedido + mapa | — | leitura do mapa | escopo candidato |
| 1. Detectar capacidades | sim | `detect_capabilities.sh` | tier + flags |
| 2. Termos de busca | julgamento leve | — | termos + módulos |
| 3. Localizar fatia | sim | ast-grep/ripgrep (escopado) | sementes |
| 4. Expandir impacto | sim | SCIP (fallback ast-grep) | chamadores/chamados |
| 5. Enriquecer + dossiê | sim | git blame/log + gh | FeatureDossier |
| 6. Sintetizar | **LLM** | — | explicação + handoff |

## Degradação

Cada estágio degrada em vez de falhar: SCIP fresco → preciso; SCIP stale → usa +
marca; sem SCIP/sem build → ast-grep; sem ast-grep → textual. Ver
[03-tooling-tiers.md](03-tooling-tiers.md).

## Contrato de dados

O `FeatureDossier` (schema em `skills/how-it-works/references/dossier-schema.md`)
é o único input de fatos do LLM e o insumo da fase 2 / OpenSpec.

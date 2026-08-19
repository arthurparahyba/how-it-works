# 09 — Roadmap

## v0.1 — fase 1 "como é hoje" (esta entrega)

- [x] Pipeline determinístico escopado (detect → locate → expand → enrich → dossiê).
- [x] Síntese LLM com profundidade condicional (prompt PocketFlow-style).
- [x] Degradação graciosa por tiers (SCIP → ast-grep → textual).
- [x] Skill do Claude Code + install por symlink.
- [x] Documentação de design.

## Próximos passos

- [ ] **Fase 2 — proposta**: skill `propose-implementation` que consome o dossiê
      validado e gera opções com trade-offs, alimentando o `openspec propose`.
- [ ] **Camada fria**: job de CI para build/refresh do índice SCIP e do mapa de
      design (o trabalho amortizado).
- [ ] **Gerador do mapa de design vivo**: script que deriva a camada estrutural.
- [ ] **Diagramas mais ricos**: call graph em Mermaid direto do índice SCIP.
- [ ] **Compat Cursor e Devin CLI**: cascas de invocação sobre os mesmos scripts.
- [ ] **Evals**: casos de teste (via skill-creator) medindo qualidade da
      explicação e custo em tokens.
- [ ] **SCIP real**: fechar a integração com `scip print`/`scip snapshot`
      conforme o formato da versão instalada.

## Débitos conhecidos

- `expand_impact.sh` no tier2 trata a saída do `scip` de forma tolerante; ajustar
  ao formato exato do indexador usado.
- Detecção de "buildável" é heurística (presença de arquivos de build), não build
  real.

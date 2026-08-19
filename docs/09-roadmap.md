# 09 — Roadmap

## v0.1 — fase 1 "como é hoje"

- [x] Pipeline determinístico escopado (detect → locate → expand → enrich → dossiê).
- [x] Síntese LLM com profundidade condicional (prompt PocketFlow-style).
- [x] Degradação graciosa por tiers (SCIP → ast-grep → textual).
- [x] Skill do Claude Code + install por symlink.
- [x] Documentação de design.

## v0.2 — fase 2 "proposta"

- [x] Geração de 2–3 abordagens com trade-offs (não um monólogo).
- [x] Checkpoint humano entre abordagens e plano detalhado.
- [x] Validação determinística da proposta (`validate_proposal.sh`) — anti-alucinação.
- [x] Raio de impacto da proposta + testes afetados (`proposal_impact.sh`).
- [x] Emissão do pacote OpenSpec (`emit_openspec_change.sh`) + validate.
- [x] Templates de proposal.md / design.md / tasks.md.

## Próximos passos

- [ ] **Camada fria**: job de CI para build/refresh do índice SCIP e do mapa de
      design (o trabalho amortizado).
- [ ] **Gerador do mapa de design vivo**: script que deriva a camada estrutural.
- [ ] **Diagramas mais ricos**: call graph em Mermaid direto do índice SCIP.
- [ ] **Compat Cursor e Devin CLI**: cascas de invocação sobre os mesmos scripts.
- [ ] **Evals**: casos de teste (via skill-creator) medindo qualidade da
      explicação/proposta e custo em tokens.
- [ ] **SCIP real**: fechar a integração com `scip print`/`scip snapshot`
      conforme o formato da versão instalada.
- [ ] **Extração de claims assistida**: derivar o arquivo de claims da proposta
      automaticamente, reduzindo trabalho manual antes do `validate_proposal.sh`.

## Débitos conhecidos

- `expand_impact.sh` / `proposal_impact.sh` no tier2 tratam a saída do `scip` de
  forma tolerante; ajustar ao formato exato do indexador usado.
- Detecção de "buildável" é heurística (presença de arquivos de build), não build
  real.
- `validate_proposal.sh`: símbolos resolvidos por reflexão/DI podem gerar
  `missing` falso; confirmar à mão nesses casos.

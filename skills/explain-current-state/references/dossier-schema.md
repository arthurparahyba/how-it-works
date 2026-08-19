# FeatureDossier — schema

O `build_dossier.sh` emite este JSON. É o **único** input de fatos que o LLM
recebe na síntese. Campos com sufixo `_b64` são base64 de blocos de texto
(evitam quebrar o JSON com aspas/quebras). Decodifique com `base64 -d`.

```jsonc
{
  "change_description": "texto livre: a mudança que o dev quer fazer",
  "precision_tier": "tier2 | tier1 | tier0",   // teto de precisão disponível
  "scope": {
    "modules": ["dir/a", "dir/b"],             // escopo (do mapa de design)
    "search_terms": "termo1|termo2",           // alternativas de busca
    "symbol": "NomeDoSimboloCentral"           // âncora da expansão de impacto
  },
  "seed_files_b64":   "…",  // arquivos-semente (um por linha)
  "seed_hits_b64":    "…",  // ocorrências arquivo:linha:trecho
  "blast_radius_b64": "…",  // chamadores/chamados (arestas do impacto)
  "provenance_b64":   "…",  // commits + PRs por arquivo (o "porquê")
  "tests_b64":        "…",  // testes que tocam a fatia (rede de segurança)
  "capabilities": { /* saída completa de detect_capabilities.sh */ },
  "confidence_note": "aviso sobre limites da análise estática neste tier"
}
```

## Como cada campo alimenta a explicação

| Campo | Vira, na explicação… |
|---|---|
| `seed_files` / `seed_hits` | o "onde está" (visão geral + âncoras arquivo:linha) |
| `blast_radius` | o diagrama Mermaid de impacto + "o que a mudança toca" |
| `provenance` | a camada do "porquê" (commits/PRs que explicam decisões) |
| `tests` | a seção "rede de segurança" (o que já cobre / lacunas) |
| `precision_tier` + `confidence_note` | a seção honesta "Pontos a confirmar" |

## Contrato de estabilidade

Este mesmo objeto, depois de validado pelo desenvolvedor, é o insumo da fase 2
(proposta) e do `openspec propose`. Mantenha-o serializável e versionável:
salve em `openspec/changes/<id>/current-state.dossier.json` ao lado da
explicação em markdown.

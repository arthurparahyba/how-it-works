# FeatureDossier — schema

O `build_dossier.sh` emite **dois formatos do mesmo conteúdo**:

- **markdown** (`--md`, o padrão) — o que o LLM lê na síntese. Um `cat` só.
- **JSON** (`--json`) — o formato de **handoff** para a fase 2, que precisa de
  estrutura para salvar em `current-state.dossier.json`. Este documento
  descreve o JSON.

Por que o markdown é o padrão: o JSON carrega os blocos em base64 para não
quebrar as aspas, e isso faz o leitor pagar duas vezes — uma pelo base64
ilegível, outra pelo texto decodificado — além de exigir um `base64 -d` por
campo, cada um custando uma ida e volta. Medido no petclinic: 6.884 tokens em
JSON contra 3.114 em markdown, para exatamente a mesma informação.

Campos com sufixo `_b64` são base64 de blocos de texto. Decodifique com
`base64 -d`.

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
  "config_b64":       "…",  // schema/config que define comportamento
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
| `config` | o comportamento que vive fora do código (tipo de coluna, collation, profile, flag) |
| `precision_tier` + `confidence_note` | a seção honesta "Pontos a confirmar" |

## Por que `config_b64` existe

Análise que olha só `.java`/`.cs` produz explicações corretas e **cegas**. No
petclinic, a busca de owners só é insensível a maiúsculas porque
`db/h2/schema.sql:39` declara `VARCHAR_IGNORECASE`; em `db/postgres/schema.sql:29`
a mesma coluna é `TEXT` e a busca vira sensível. Nenhum arquivo Java diz isso, e
nenhum termo de busca derivado do código casaria com `last_name` sem a conversão
de nomenclatura que o `collect_config.sh` faz.

O campo é ranqueado: schema/migration/config de app primeiro; bundles de i18n e
seeds entram só como amostra rotulada, para não consumirem o orçamento de tokens.

## Contrato de estabilidade

Este mesmo objeto, depois de validado pelo desenvolvedor, é o insumo da fase 2
(proposta) e do `openspec propose`. Mantenha-o serializável e versionável:
salve em `openspec/changes/<id>/current-state.dossier.json` ao lado da
explicação em markdown.

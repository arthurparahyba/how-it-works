#!/usr/bin/env bash
# build_dossier.sh
# Orquestra os passos deterministicos e monta o FeatureDossier compacto que
# sera entregue ao LLM para a sintese. NAO chama o LLM.
#
# Uso: ./build_dossier.sh [--md|--json] "descricao" "termos|de|busca" [simbolo] [modulos...]
#
#   --md   (padrao) markdown legivel direto. E o formato para o LLM ler.
#   --json JSON com os blocos em base64. E o formato de HANDOFF para a fase 2,
#          que precisa de estrutura para salvar em current-state.dossier.json.
#
# Por que o markdown e o padrao: o JSON carrega os blocos em base64 para nao
# quebrar as aspas, mas isso faz o leitor pagar DUAS vezes — uma pelo base64
# ilegivel e outra pelo texto decodificado — e ainda exige um `base64 -d` por
# campo, cada um custando uma ida e volta. Medido no petclinic: 5.539 tokens em
# JSON contra 2.260 no markdown, para o mesmo conteudo.
#
# Este script e deliberadamente conservador: cada secao degrada em vez de falhar.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

FORMAT="md"
case "${1:-}" in
  --md)   FORMAT="md";   shift ;;
  --json) FORMAT="json"; shift ;;
  --format=*) FORMAT="${1#--format=}"; shift ;;
esac
[ "$FORMAT" = "md" ] || [ "$FORMAT" = "json" ] || { warn "formato desconhecido: $FORMAT (use --md ou --json)"; exit 1; }

CHANGE_DESC="${1:?descreva a mudanca}"
TERMS="${2:?informe termos de busca}"
SYMBOL="${3:-}"
shift 3 2>/dev/null || shift $# 
MODULES=("$@")

ROOT="$(repo_root)"; cd "$ROOT" || exit 1

# 1) capacidades -------------------------------------------------------------
CAPS="$("$DIR/detect_capabilities.sh" "$ROOT" 2>/dev/null)"
TIER="$(printf '%s' "$CAPS" | grep -o '"precision_tier": *"[^"]*"' | cut -d'"' -f4)"
SCIP_PATH="$(printf '%s' "$CAPS" | grep -o '"path": *"[^"]*"' | head -1 | cut -d'"' -f4)"

# 2) localizar a fatia -------------------------------------------------------
SEEDS="$("$DIR/locate_slice.sh" "$TERMS" "${MODULES[@]}" 2>/dev/null)"
SEED_FILES="$(printf '%s\n' "$SEEDS" | cut -d: -f1 | sort -u | grep -v '^$' | head -20)"

# 3) expandir impacto (se houver simbolo) ------------------------------------
IMPACT=""
if [ -n "$SYMBOL" ]; then
  IMPACT="$("$DIR/expand_impact.sh" "$SYMBOL" 1 "$SCIP_PATH" 2>/dev/null | head -40)"
fi

# 4) proveniencia ------------------------------------------------------------
PROV=""
if [ -n "$SEED_FILES" ]; then
  # shellcheck disable=SC2086
  PROV="$("$DIR/enrich_provenance.sh" $SEED_FILES 2>/dev/null | head -60)"
fi

# 4b) configuracao / schema -------------------------------------------------
# Metade do comportamento de um sistema Spring/.NET vive fora do codigo. Sem
# este campo o dossie produz explicacoes corretas e cegas (ver collect_config.sh).
CONFIG="$("$DIR/collect_config.sh" "$TERMS" "$SYMBOL" 2>/dev/null | head -50)"

# 5) testes que tocam a fatia ------------------------------------------------
# Duas fontes, unidas: (a) por NOME — o teste se chama como um arquivo-semente;
# (b) por REFERENCIA — o teste cita o simbolo central. A fonte (b) e a que pega
# casos como `ClinicServiceTests`, que exercita a query real mas nao se chama
# como nenhuma semente; sem ela o campo omitia justamente o teste que importa.
TESTS=""
TEST_FILES="$(git ls-files 2>/dev/null | awk '
  { n = $0; sub(/^.*\//, "", n); ln = tolower(n)
    if (index(ln, "test") || index(ln, "spec")) print }' | head -400)"

# (a) por nome: casa o nome INTEIRO apos remover o afixo test/spec, nao
# substring — senao a semente `Pet` puxa `PetClinicConcurrencyTests`. Prefere
# precisao a recall. Sem `xargs -r` (extensao GNU, ausente no macOS).
BY_NAME=""
if [ -n "$SEED_FILES" ] && [ -n "$TEST_FILES" ]; then
  BASES="$(printf '%s\n' "$SEED_FILES" | sed 's#.*/##; s/\.[^.]*$//' \
           | grep -v '^$' | sort -u | tr '\n' ' ')"
  if [ -n "$BASES" ]; then
    BY_NAME="$(printf '%s\n' "$TEST_FILES" | awk -v bases="$BASES" '
      BEGIN { nb = split(tolower(bases), b, " ") }
      { n = $0; sub(/^.*\//, "", n)
        core = n; sub(/\.[^.]*$/, "", core)
        sub(/^([Tt]ests?|[Ss]pecs?)[_.-]/, "", core)
        sub(/[_.-]?([Tt]ests?|[Ss]pecs?)$/, "", core)
        lc = tolower(core)
        for (i = 1; i <= nb; i++) if (b[i] != "" && lc == b[i]) { print; break } }')"
  fi
fi

# (b) por referencia ao simbolo central. `grep` com arquivo nomeado nao le o
# stdin, entao e seguro dentro do laco (ver o bug corrigido em
# validate_proposal.sh). Portavel: sem xargs -0, sem rg obrigatorio.
BY_REF=""
if [ -n "$SYMBOL" ] && [ -n "$TEST_FILES" ]; then
  BY_REF="$(printf '%s\n' "$TEST_FILES" | while IFS= read -r tf; do
    [ -f "$tf" ] || continue
    grep -qw -- "$SYMBOL" "$tf" 2>/dev/null && printf '%s\n' "$tf"
  done)"
fi

TESTS="$(printf '%s\n%s\n' "$BY_NAME" "$BY_REF" | grep -v '^$' | awk '!seen[$0]++' | head -15)"

# 6) montar o dossie ---------------------------------------------------------
CONF_NOTE="Analise estatica: dispatch dinamico, reflexao, DI e chamadas cross-service podem faltar. O tier '$TIER' define a precisao das arestas."

# Conta linhas nao vazias de um bloco.
nlines() { printf '%s\n' "$1" | grep -c . ; }

if [ "$FORMAT" = "md" ]; then
  # Secao markdown. Bloco vazio vira um aviso EXPLICITO em vez de sumir em
  # silencio: um campo vazio entregue sem alarde ja fez o raio de impacto ser
  # dado como "sem chamadores" quando o simbolo e que estava errado.
  sec() {
    local titulo="$1" corpo="$2" vazio="$3"
    printf '\n## %s' "$titulo"
    if [ -z "$(printf '%s' "$corpo" | tr -d '[:space:]')" ]; then
      printf ' — VAZIO\n\n> %s\n' "$vazio"
    else
      printf ' (%s)\n\n```\n%s\n```\n' "$(nlines "$corpo")" "$corpo"
    fi
  }

  cat << MD
# FeatureDossier — $CHANGE_DESC

- **precision_tier**: $TIER
- **escopo**: ${MODULES[*]:-(repo inteiro)}
- **termos**: $TERMS
- **simbolo central**: ${SYMBOL:-(nenhum informado)}

> $CONF_NOTE
MD
  sec "Arquivos-semente" "$SEED_FILES" \
      "Nenhum arquivo casou os termos. Alargue os termos ou remova o escopo de modulo."
  sec "Ocorrencias (arquivo:linha:trecho)" "$SEEDS" \
      "Sem ocorrencias. Os termos do passo 2 provavelmente nao correspondem ao codigo."
  sec "Raio de impacto" "$IMPACT" \
      "Sem arestas. CONFIRA O SIMBOLO: um nome que nao existe produz exatamente este vazio. Procure o nome real nas Ocorrencias acima e rode expand_impact.sh de novo antes de concluir que nada depende dele."
  sec "Configuracao / schema" "$CONFIG" \
      "Nenhum arquivo de configuracao casou os termos."
  sec "Proveniencia (o porque)" "$PROV" \
      "Sem historico para os arquivos-semente."
  sec "Testes que tocam a fatia" "$TESTS" \
      "Nenhum teste localizado — possivel lacuna de cobertura, ou convencao de nome que a heuristica nao cobre."
  printf '\n## Capacidades do ambiente\n\n```json\n%s\n```\n' "$CAPS"

  log "dossie montado em markdown (tier=$TIER). Use --json para o handoff da fase 2."
else
  b64() { printf '%s' "$1" | base64 | tr -d '\n'; }   # embute blocos texto sem quebrar JSON
  mods_json="["; first=true
  for m in "${MODULES[@]}"; do $first || mods_json+=","; mods_json+="\"$(json_escape "$m")\""; first=false; done
  mods_json+="]"

  cat << JSON
{
  "change_description": "$(json_escape "$CHANGE_DESC")",
  "precision_tier": "$(json_escape "$TIER")",
  "scope": { "modules": $mods_json, "search_terms": "$(json_escape "$TERMS")", "symbol": "$(json_escape "$SYMBOL")" },
  "seed_files_b64": "$(b64 "$SEED_FILES")",
  "seed_hits_b64": "$(b64 "$SEEDS")",
  "blast_radius_b64": "$(b64 "$IMPACT")",
  "provenance_b64": "$(b64 "$PROV")",
  "tests_b64": "$(b64 "$TESTS")",
  "config_b64": "$(b64 "$CONFIG")",
  "capabilities": $CAPS,
  "confidence_note": "$(json_escape "$CONF_NOTE")"
}
JSON

  log "dossie montado em JSON (tier=$TIER). Campos *_b64 sao base64 — decodifique com base64 -d."
fi

#!/usr/bin/env bash
# build_dossier.sh
# Orquestra os passos deterministicos e monta o FeatureDossier compacto que
# sera entregue ao LLM para a sintese. NAO chama o LLM. Emite JSON no stdout.
#
# Uso: ./build_dossier.sh "descricao da mudanca" "termos|de|busca" [simbolo] [modulos...]
#
# Este script e deliberadamente conservador: cada secao degrada em vez de falhar.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

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

# 5) testes que tocam a fatia (heuristica por nome/dir) ----------------------
TESTS=""
if [ -n "$SEED_FILES" ]; then
  base="$(printf '%s\n' "$SEED_FILES" | head -1 | xargs -r basename 2>/dev/null | sed 's/\.[^.]*$//')"
  [ -n "$base" ] && TESTS="$(git ls-files 2>/dev/null | grep -iE "(test|spec).*${base}|${base}.*(test|spec)" | head -10)"
fi

# 6) montar o dossie ---------------------------------------------------------
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
  "capabilities": $CAPS,
  "confidence_note": "Analise estatica: dispatch dinamico, reflexao, DI e chamadas cross-service podem faltar. O tier '$TIER' define a precisao das arestas."
}
JSON

log "dossie montado (tier=$TIER). Campos *_b64 sao base64 de blocos de texto."

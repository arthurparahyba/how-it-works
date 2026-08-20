#!/usr/bin/env bash
# locate_slice.sh
# Localiza a "semente" da fatia relevante a uma mudanca, a partir de termos de
# busca. Escopa a busca aos modulos sugeridos (pelo mapa de design) quando
# fornecidos, para nao varrer o repo inteiro. Prefere ast-grep (estrutural);
# cai para ripgrep e depois git grep (degradacao graciosa).
#
# Uso: ./locate_slice.sh "termo1|termo2" [modulo1 modulo2 ...]
#   - termos: alternativas de busca (nomes de funcao/classe/rota/simbolo)
#   - modulos: subdiretorios para escopar (opcional; vindos do mapa de design)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

TERMS="${1:?informe os termos de busca}"; shift || true
SCOPES=("$@")
[ ${#SCOPES[@]} -eq 0 ] && SCOPES=(".")   # sem mapa: repo inteiro, mas limitado

AG="$(astgrep_bin)"
MAX_HITS=40    # cap global de sementes: mantem o conjunto de trabalho pequeno
PER_FILE=3     # cap por arquivo POR TERMO: impede um arquivo de dominar

log "localizando fatia | termos: $TERMS | escopo: ${SCOPES[*]}"

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t locslice)" || TMPD=""
cleanup() { [ -n "$TMPD" ] && rm -rf "$TMPD"; }
trap cleanup EXIT

# Busca UM termo isolado. Sem cap aqui: o ranqueamento abaixo e que corta.
search_term() {
  local t="$1"
  if have rg; then
    rg --line-number --no-heading -e "$t" "${SCOPES[@]}" </dev/null 2>/dev/null | head -n 500
  else
    git grep -n -E "$t" -- "${SCOPES[@]}" 2>/dev/null | head -n 500
  fi
}

# Quebra a alternancia "a|b|c" nos termos individuais.
TERM_LIST=()
_oifs="$IFS"; IFS='|'
for t in $TERMS; do [ -n "$t" ] && TERM_LIST+=("$t"); done
IFS="$_oifs"
[ ${#TERM_LIST[@]} -eq 0 ] && TERM_LIST=("$TERMS")

have rg || warn "ripgrep ausente; usando git grep"

# --- ranqueamento por raridade ----------------------------------------------
# Um cap aplicado sobre a saida bruta corta por ORDEM DE LINHA, e portanto joga
# fora a linha mais especifica so porque ela vem depois. Ex.: buscar
# "lastName|findByLastNameStartingWith" no OwnerController do petclinic devolvia
# 5 hits de `lastName` e descartava a chamada real ao repositorio, la embaixo.
# Solucao: termo RARO primeiro. Poucos hits = termo especifico = mais sinal.
if [ -n "$TMPD" ]; then
  for t in "${TERM_LIST[@]}"; do
    c="$(search_term "$t" | wc -l | tr -d ' ')"
    printf '%s\t%s\n' "${c:-0}" "$t"
  done | sort -n > "$TMPD/ranked"

  : > "$TMPD/hits"
  while IFS="$(printf '\t')" read -r c t; do
    [ -z "$t" ] && continue
    [ "${c:-0}" -eq 0 ] && { log "termo sem hits: $t"; continue; }
    log "termo '$t' ($c hits) -> ate $PER_FILE por arquivo"
    search_term "$t" | awk -F: -v pf="$PER_FILE" '{ if (++n[$1] <= pf) print }' >> "$TMPD/hits"
  done < "$TMPD/ranked"

  awk '!seen[$0]++' "$TMPD/hits" | head -n "$MAX_HITS"
else
  # sem mktemp (ambiente exotico): degrada para a busca simples de antes
  warn "mktemp indisponivel: sementes sem ranqueamento"
  search_term "$TERMS" | head -n "$MAX_HITS"
fi

[ -n "$AG" ] && log "ast-grep disponivel ($AG) para o passo de expansao" \
             || warn "ast-grep ausente: expansao usara heuristica textual"

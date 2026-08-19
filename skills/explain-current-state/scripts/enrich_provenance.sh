#!/usr/bin/env bash
# enrich_provenance.sh
# Recupera a camada do "porque": para os arquivos-semente, liga trechos ao
# commit que os introduziu e, quando possivel, ao PR/issue correspondente.
# Tudo deterministico e local ao repo (git); PR exige o gh CLI (opcional).
#
# Uso: ./enrich_provenance.sh arquivo1 [arquivo2 ...]

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

[ $# -ge 1 ] || { warn "nenhum arquivo informado"; exit 0; }
MAX_COMMITS=8

log "recuperando proveniencia de $# arquivo(s)"

for f in "$@"; do
  [ -f "$f" ] || continue
  echo "### $f"
  # commits mais relevantes que tocaram o arquivo (intencao no texto do commit)
  git log -n "$MAX_COMMITS" --format='%h | %an | %ad | %s' --date=short -- "$f" 2>/dev/null

  # PRs associados aos commits recentes, se gh estiver autenticado
  if have gh; then
    last_commit="$(git log -1 --format=%H -- "$f" 2>/dev/null)"
    if [ -n "$last_commit" ]; then
      pr="$(gh pr list --search "$last_commit" --state all --json number,title \
            --jq '.[0] | "PR #\(.number): \(.title)"' 2>/dev/null)"
      [ -n "$pr" ] && echo "  -> $pr"
    fi
  fi
  echo
done

have gh || warn "gh ausente: proveniencia limitada a commits (sem PR/issue)."

#!/usr/bin/env bash
# proposal_impact.sh
# Calcula o raio de impacto REAL dos pontos que a proposta vai tocar, para o dev
# nao ser surpreendido. Para cada simbolo/arquivo tocado: quem depende dele (o
# que pode quebrar) e quais testes o cobrem (a rede de seguranca). Deterministico.
#
# Uso: ./proposal_impact.sh "Simbolo1,Simbolo2" "arquivo1,arquivo2" [scip_index]
# Saida: texto estruturado (consumido pela sintese; leve o suficiente p/ ler).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

SYMBOLS="${1:-}"; FILES="${2:-}"; SCIP_INDEX="${3:-}"
cd "$(repo_root)" || exit 1
AG="$(astgrep_bin)"
TOP_N=20

callers_of() {
  local sym="$1"
  if [ -n "$SCIP_INDEX" ] && [ -f "$SCIP_INDEX" ] && have scip; then
    scip print --json "$SCIP_INDEX" 2>/dev/null | grep -i "$sym" | head -n "$TOP_N"
  elif [ -n "$AG" ]; then
    "$AG" run --pattern "${sym}(\$\$\$)" --json=compact 2>/dev/null \
      | grep -oE '"file":"[^"]+"' | sort | uniq -c | sort -rn | head -n "$TOP_N"
  elif have rg; then
    rg --line-number --no-heading -w "$sym" 2>/dev/null | head -n "$TOP_N"
  else
    git grep -n -w "$sym" 2>/dev/null | head -n "$TOP_N"
  fi
}

tests_for_file() {
  local f="$1"
  local base; base="$(basename "$f" | sed 's/\.[^.]*$//')"
  [ -n "$base" ] && git ls-files 2>/dev/null \
    | grep -iE "(test|spec).*${base}|${base}.*(test|spec)" | head -10
}

echo "## Raio de impacto da proposta"
echo
if [ -n "$SYMBOLS" ]; then
  IFS=',' read -ra SYMS <<< "$SYMBOLS"
  for s in "${SYMS[@]}"; do
    s="$(echo "$s" | xargs)"; [ -z "$s" ] && continue
    echo "### Quem depende de \`$s\` (pode quebrar)"
    callers_of "$s" | sed 's/^/  /'
    echo
  done
fi
if [ -n "$FILES" ]; then
  IFS=',' read -ra FS <<< "$FILES"
  echo "### Testes que cobrem os arquivos tocados"
  for f in "${FS[@]}"; do
    f="$(echo "$f" | xargs)"; [ -z "$f" ] && continue
    t="$(tests_for_file "$f")"
    if [ -n "$t" ]; then echo "  $f:"; echo "$t" | sed 's/^/    /'; else echo "  $f: (sem teste localizado — possivel lacuna)"; fi
  done
fi
echo
warn "Arestas por dispatch dinamico/reflexao/DI/cross-service NAO aparecem. Sinalize essas lacunas."

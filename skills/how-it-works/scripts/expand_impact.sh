#!/usr/bin/env bash
# expand_impact.sh
# A partir de um simbolo-semente, expande o raio de impacto: quem chama e o que
# e chamado. Fonte das arestas em ordem de preferencia:
#   tier2: indice SCIP (find-references precisas)  -> exato
#   tier1: ast-grep (call sites estruturais)       -> aproximado
#   tier0: ripgrep/git grep (ocorrencias textuais) -> ruidoso
# Sempre limitado: 1 salto por padrao, top-N por frequencia de referencia.
#
# Uso: ./expand_impact.sh "NomeDoSimbolo" [saltos] [scip_index]

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

SYMBOL="${1:?informe o simbolo-semente}"
HOPS="${2:-1}"
SCIP_INDEX="${3:-}"
TOP_N=20     # cap de chamadores/chamados apos ranquear
AG="$(astgrep_bin)"

log "expandindo impacto | simbolo: $SYMBOL | saltos: $HOPS"

# --- tier2: SCIP -------------------------------------------------------------
expand_scip() {
  [ -n "$SCIP_INDEX" ] && [ -f "$SCIP_INDEX" ] && have scip || return 1
  log "fonte de arestas: SCIP (preciso) -> $SCIP_INDEX"
  # `scip` expoe referencias do indice; o formato exato varia por versao, entao
  # tratamos a saida de forma tolerante e ranqueamos por frequencia de arquivo.
  scip print --json "$SCIP_INDEX" 2>/dev/null \
    | grep -i "$SYMBOL" \
    | sort | uniq -c | sort -rn | head -n "$TOP_N"
}

# --- tier1: ast-grep --------------------------------------------------------
expand_astgrep() {
  [ -n "$AG" ] || return 1
  log "fonte de arestas: ast-grep (estrutural, aproximado)"
  # chamadas ao simbolo: padrao isomorfico ao codigo. $$$ casa argumentos.
  "$AG" run --pattern "${SYMBOL}(\$\$\$)" --json=compact . </dev/null 2>/dev/null \
    | head -c 200000
}

# --- tier0: textual ---------------------------------------------------------
expand_textual() {
  log "fonte de arestas: textual (ruidoso, ultimo recurso)"
  if have rg; then
    rg --line-number --no-heading -w "$SYMBOL" . </dev/null 2>/dev/null | head -n "$TOP_N"
  else
    git grep -n -w "$SYMBOL" </dev/null 2>/dev/null | head -n "$TOP_N"
  fi
}

if expand_scip; then :;
elif expand_astgrep; then :;
else expand_textual; fi

# Aviso honesto sobre os limites da analise estatica.
warn "arestas por dispatch dinamico / reflexao / DI / cross-service NAO aparecem aqui."
warn "o LLM deve sinalizar essas lacunas em vez de assumir completude."

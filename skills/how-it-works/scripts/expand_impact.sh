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

# --- tier1: ast-grep, por tipo de no ----------------------------------------
# A versao anterior usava o padrao `Simbolo($$$)`, que so casa chamada NUA. Em
# Java/C# a maioria das chamadas e `objeto.metodo(...)` — e essas ele nao via.
# Medido no petclinic: 0 chamadas encontradas para
# `owners.findByLastNameStartingWith(...)`, contra 13 casando por kind. O tier
# "estrutural" estava silenciosamente pior que o textual.
expand_astgrep() {
  [ -n "$AG" ] || return 1
  local langs lang found=0 defs calls
  langs="$(repo_langs)"
  [ -z "$langs" ] && return 1
  log "fonte de arestas: ast-grep por tipo de no (estrutural)"
  # O acumulado vai para uma variavel, NAO direto para um pipe: `found=1` dentro
  # de um `for ... | head` roda em subshell e nunca chega aqui — a funcao dava
  # "falhei" mesmo tendo achado tudo, e o chamador rodava a busca textual por
  # cima, duplicando o raio de impacto.
  local acc=""
  for lang in $langs; do
    defs="$(ag_find_defs  "$AG" "$lang" "$SYMBOL" . 2>/dev/null)"
    calls="$(ag_find_calls "$AG" "$lang" "$SYMBOL" . 2>/dev/null)"
    [ -n "$defs" ]  && acc="$acc$(printf '%s\n' "$defs"  | sed 's/$/  [definicao]/')
"
    [ -n "$calls" ] && acc="$acc$(printf '%s\n' "$calls" | sed 's/$/  [chamada]/')
"
  done
  [ -z "$(printf '%s' "$acc" | tr -d '[:space:]')" ] && return 1

  # Casar por kind e preciso mas perde REFERENCIA de metodo: em C# minimal API,
  # `MapGet("/rota", Handler)` passa o metodo como valor — nao e chamada, e o
  # parser corretamente nao conta. So que essa aresta importa: e como a rota
  # existe. Entao acrescentamos as ocorrencias textuais que sobraram, rotuladas
  # e sem duplicar as ja encontradas. Precisao no rotulo, recall no conjunto.
  local seen extra
  seen="$(printf '%s\n' "$acc" | sed 's/  \[.*//' | grep -v '^$')"
  if have rg; then
    extra="$(rg --line-number --no-heading -w "$SYMBOL" . </dev/null 2>/dev/null \
             | sed 's#^\./##' | cut -d: -f1,2)"
  else
    extra="$(git grep -n -w "$SYMBOL" </dev/null 2>/dev/null | cut -d: -f1,2)"
  fi
  extra="$(printf '%s\n' "$extra" | grep -v '^$' | grep -vxF -f <(printf '%s\n' "$seen") 2>/dev/null \
           | sed 's/$/  [referencia]/' | head -8)"

  printf '%s\n%s\n' "$acc" "$extra" | grep -v '^$' | head -n "$TOP_N"
  return 0
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

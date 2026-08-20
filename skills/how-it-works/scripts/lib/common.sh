#!/usr/bin/env bash
# common.sh - utilidades compartilhadas pelos scripts da fase "como e hoje".
# Todas as funcoes sao defensivas: nunca abortam o pipeline, apenas sinalizam
# o que nao foi possivel resolver (degradacao graciosa).

set -o pipefail

# --- deteccao de ferramentas -------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# ast-grep expoe o binario como `ast-grep` e (as vezes) como `sg`. ATENCAO:
# em Linux, /usr/bin/sg e o utilitario setgroup, NAO o ast-grep — por isso so
# aceitamos `sg` se ele realmente for o ast-grep. Evita rodar o binario errado.
astgrep_bin() {
  if have ast-grep; then echo "ast-grep"; return; fi
  if have sg && sg --version 2>/dev/null | grep -qi ast-grep; then echo "sg"; return; fi
  echo ""
}

# --- logging (vai para stderr, nunca contamina o stdout do dossie) -----------
log()  { printf '  %s\n' "$*" >&2; }
warn() { printf '  [!] %s\n' "$*" >&2; }

# --- raiz do repositorio -----------------------------------------------------
repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# --- json helpers (sem jq como dependencia obrigatoria) ----------------------
# Escapa uma string para embutir em JSON.
json_escape() {
  if have python3; then
    python3 - "$1" << 'PY' 2>/dev/null && return 0
import json,sys
print(json.dumps(sys.argv[1])[1:-1], end="")
PY
  fi
  # Fallback sem python: o Git Bash no Windows frequentemente nao traz python3.
  # Escapar \ e " e o minimo para nao produzir JSON invalido (caminhos do
  # Windows chegam como /c/Users/... via MSYS, mas nao ha garantia disso).
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\n\r\t'
}

# jq e opcional; se existir, usamos para montar JSON de forma robusta.
have_jq() { have jq; }


# --- extracao precisa por tipo de no (tree-sitter) ---------------------------
# A tabela em node-kinds.tsv foi destilada do CodeGraph (colbymchenry/codegraph,
# MIT) — ver NOTICE.md. Casar por KIND em vez de regex elimina os falsos
# positivos/negativos que a deteccao textual produz entre linguagens.

# Diretorio desta lib, resolvido AGORA (no source), nao na hora da chamada:
# dentro de uma funcao, ${BASH_SOURCE[0]} nao resolve de forma confiavel entre
# versoes do bash, e node_kinds silenciosamente nao achava a tabela.
_LIB_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# extensao de arquivo -> linguagem (nossas 7 alvo). Vazio se desconhecida.
lang_of_file() {
  case "${1##*.}" in
    cs)        echo csharp ;;
    java)      echo java ;;
    kt|kts)    echo kotlin ;;
    go)        echo go ;;
    py)        echo python ;;
    ts|tsx)    echo typescript ;;
    js|jsx|mjs|cjs) echo javascript ;;
    *)         echo "" ;;
  esac
}

# Tipos de no de uma linguagem para um papel.
# Papel: def_class | def_func | def_method | call | import
node_kinds() {
  local lang="$1" role="$2"
  local KINDS_TSV="${LIB_DIR:-$_LIB_DIR_DEFAULT}/node-kinds.tsv"
  [ -f "$KINDS_TSV" ] || return 1
  awk -F'\t' -v l="$lang" -v r="$role" '$1==l && $2==r {print $3}' "$KINDS_TSV"
}

# Extrai arquivo:linha do --json=stream do ast-grep. A linha vem 0-based no
# JSON; somamos 1. Sem jq: nem todo ambiente tem, e nao vamos exigir.
_ag_stream_to_lines() {
  sed -n 's/.*"start":{"line":\([0-9]*\).*"file":"\([^"]*\)".*/\2 \1/p' \
    | awk '{ printf "%s:%d\n", $1, $2+1 }'
}

# --- onde fica o NOME dentro do no -------------------------------------------
# Isto varia por GRAMATICA, nao por gosto. Java/C#/Go/Python/TS expoem o nome
# como um CAMPO do no (`name`; em C# a chamada usa `function`). A gramatica do
# Kotlin nao expoe campo nenhum nesses nos: o nome e um filho sem campo —
# `simple_identifier` na funcao e na chamada, `type_identifier` na classe.
#
# A falha era silenciosa e cara. Uma regra com `field:` que a gramatica nao tem
# NAO casa zero vezes: ela nem chega a ser parseada ("Relational rule contains
# invalid field name"), e o erro ia para /dev/null. `ag_find_defs` e
# `ag_find_calls` devolviam vazio, o `expand_impact.sh` caia para a busca
# textual, e o Kotlin rodava tier0 se dizendo tier1 — sem uma linha de aviso.
#
# Por isso a lista de matchers e POR LINGUAGEM, em vez de uma cascata que tenta
# tudo em toda linguagem: assim Java e C# pagam exatamente o que pagavam antes,
# e uma linguagem nova que tenha o mesmo problema entra com uma linha aqui.
_ag_matchers_for() {   # $1 = def|call   $2 = linguagem
  case "$2" in
    kotlin)
      case "$1" in
        def)  echo 'child:type_identifier child:simple_identifier' ;;
        call) echo 'child:simple_identifier kt-qualified' ;;
      esac ;;
    *)
      case "$1" in
        def)  echo 'field:name' ;;
        call) echo 'field:name field:function' ;;
      esac ;;
  esac
}

# Emite o bloco `has:` de um matcher. $1 = spec, $2 = regex ja entre aspas
# simples (ver a armadilha das aspas na nota de ag_find_defs).
_ag_matcher_yaml() {
  case "$1" in
    field:*) printf '  has: { field: %s, regex: %s }' "${1#field:}" "$2" ;;
    child:*) printf '  has: { kind: %s, regex: %s }' "${1#child:}" "$2" ;;
    kt-qualified)
      # `owners.findByLastName(...)`: em Kotlin o nome do metodo NAO e filho
      # direto da chamada. A arvore e
      #   call_expression > navigation_expression > navigation_suffix > simple_identifier
      # e o filho direto e o RECEPTOR (`owners`) — casar nele daria a chamada
      # errada. Por isso a regra desce os tres niveis em vez de usar
      # `stopBy: end`, que casaria tambem o nome passado como argumento.
      printf '  has:\n    kind: navigation_expression\n    has:\n      kind: navigation_suffix\n      has: { kind: simple_identifier, regex: %s }' "$2" ;;
  esac
}

# Roda UMA regra (kind + matcher) e devolve arquivo:linha.
_ag_scan_kind() {
  local ag="$1" lang="$2" kind="$3" spec="$4" re="$5"; shift 5
  local body; body="$(_ag_matcher_yaml "$spec" "$re")"
  [ -z "$body" ] && return 1
  "$ag" scan --inline-rules "id: x
language: $lang
rule:
  kind: $kind
$body" "$@" --json=stream </dev/null 2>/dev/null | _ag_stream_to_lines
}

# Onde o simbolo e DEFINIDO. Vazio se nao houver tabela para a linguagem.
#
# Duas armadilhas herdadas, ambas silenciosas — nenhuma da erro, so resultado
# errado:
#   1. O regex vai em aspas SIMPLES no YAML. Entre aspas duplas o YAML
#      interpreta \b como backspace antes de o ast-grep ver o regex, e a regra
#      nunca casa.
#   2. `has: { regex: ... }` solto casa QUALQUER descendente do no — o corpo
#      inteiro do metodo. Assim `LongCountAsync`, que o eShop so CHAMA (e do EF
#      Core), dava "definido aqui". Restringir ao no do nome (por campo ou por
#      kind do filho) e ancorar com ^...$ evita isso e impede `Catalog` de casar
#      com `CatalogAI`.
ag_find_defs() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local kinds k m re out=""
  kinds="$(node_kinds "$lang" def_class; node_kinds "$lang" def_func; node_kinds "$lang" def_method)"
  [ -z "$kinds" ] && return 2
  re="'^$name\$'"
  for k in $kinds; do
    for m in $(_ag_matchers_for def "$lang"); do
      out="$out$(_ag_scan_kind "$ag" "$lang" "$k" "$m" "$re" "${scopes[@]}")
"
    done
  done
  printf '%s\n' "$out" | grep -v '^$' | awk '!seen[$0]++'
}

# Onde o simbolo e CHAMADO. Cobre `foo(...)` e `obj.foo(...)` — o segundo caso e
# a maioria em Java/C#/Kotlin, e era exatamente o que o padrao textual `foo($$$)`
# deixava passar: no petclinic ele achava 0 chamadas de
# `owners.findByLastNameStartingWith(...)`, contra 13 por kind.
#
# O regex aceita o ponto porque em C# o no do campo `function` e a expressao
# inteira (`services.CatalogAI.GetEmbeddingAsync`), nao so o identificador.
# `(^|\.)nome$` cobre chamada nua e chamada em objeto, sem deixar
# `GetEmbedding` casar com `GetEmbeddingsAsync`.
#
# Os matchers sao UNIDOS, nao "para no primeiro que responder": em Kotlin a
# chamada nua e a chamada em objeto vivem em formas diferentes da arvore, e as
# duas contam como chamada.
ag_find_calls() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local kinds k m re out=""
  kinds="$(node_kinds "$lang" call)"
  [ -z "$kinds" ] && return 2
  re="'(^|\.)$name\$'"
  for k in $kinds; do
    for m in $(_ag_matchers_for call "$lang"); do
      out="$out$(_ag_scan_kind "$ag" "$lang" "$k" "$m" "$re" "${scopes[@]}")
"
    done
  done
  printf '%s\n' "$out" | grep -v '^$' | awk '!seen[$0]++'
}

# Responde SIM/NAO: existe definicao deste simbolo? Usado pela validacao da
# fase 2. Retorna 0 se achou, 1 se nao achou, 2 se nao ha tabela para a
# linguagem (o chamador cai para o fallback textual).
ag_defs_by_kind() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local out
  out="$(ag_find_defs "$ag" "$lang" "$name" "${scopes[@]}")" || true
  [ -z "$(node_kinds "$lang" def_class; node_kinds "$lang" def_func; node_kinds "$lang" def_method)" ] && return 2
  [ -n "$out" ] && return 0
  return 1
}

# Linguagens presentes no repositorio, deduzidas das extensoes rastreadas.
repo_langs() {
  git ls-files 2>/dev/null | sed 's/.*\.//' | sort -u \
    | while read -r e; do lang_of_file "x.$e"; done | sort -u | grep -v '^$'
}

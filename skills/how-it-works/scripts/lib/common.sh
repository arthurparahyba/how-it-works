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

# Casa DEFINICOES de um simbolo por kind (preciso).
# Duas armadilhas, ambas silenciosas — nenhuma das duas da erro, so resultado
# errado:
#   1. O regex vai em aspas SIMPLES no YAML. Entre aspas duplas o YAML
#      interpreta \b como backspace antes de o ast-grep ver o regex, e a regra
#      nunca casa.
#   2. `has: { regex: ... }` casa QUALQUER descendente do no — o corpo inteiro
#      do metodo. Assim `LongCountAsync`, que o eShop so CHAMA (e do EF Core),
#      dava "definido aqui", que e o falso positivo que a mudanca vinha corrigir.
#      `field: name` restringe ao identificador da declaracao. Ancorar o regex
#      com ^...$ evita que `Catalog` case com `CatalogAI`. Usa os kinds de classe,
# funcao e metodo da linguagem. Retorna 0 se achou ao menos uma definicao,
# 1 se nao achou, 2 se nao ha tabela para a linguagem (caller usa fallback).
ag_defs_by_kind() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local kinds; kinds="$(node_kinds "$lang" def_class; node_kinds "$lang" def_func; node_kinds "$lang" def_method)"
  [ -z "$kinds" ] && return 2
  local k
  for k in $kinds; do
    if "$ag" scan --inline-rules "id: d
language: $lang
rule:
  kind: $k
  has: { field: name, regex: '^$name$' }" "${scopes[@]}" </dev/null 2>/dev/null | grep -q 'help\[d\]'; then
      return 0
    fi
  done
  return 1
}

# --- localizacao por kind, com saida arquivo:linha ---------------------------
# ag_defs_by_kind responde SIM/NAO. Estas duas devolvem ONDE, no mesmo formato
# que o resto do pipeline usa (arquivo:linha), para alimentar sementes e raio
# de impacto sem inventar um formato novo.

# Extrai arquivo:linha do --json=stream do ast-grep. A linha vem 0-based no
# JSON; somamos 1. Sem jq: nem todo ambiente tem, e nao vamos exigir.
_ag_stream_to_lines() {
  sed -n 's/.*"start":{"line":\([0-9]*\).*"file":"\([^"]*\)".*/\2 \1/p' \
    | awk '{ printf "%s:%d\n", $1, $2+1 }'
}

# Onde o simbolo e DEFINIDO. Vazio se nao houver tabela para a linguagem.
ag_find_defs() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local kinds k
  kinds="$(node_kinds "$lang" def_class; node_kinds "$lang" def_func; node_kinds "$lang" def_method)"
  [ -z "$kinds" ] && return 2
  for k in $kinds; do
    "$ag" scan --inline-rules "id: d
language: $lang
rule:
  kind: $k
  has: { field: name, regex: '^$name$' }" "${scopes[@]}" --json=stream </dev/null 2>/dev/null \
      | _ag_stream_to_lines
  done
}

# Onde o simbolo e CHAMADO. Cobre `foo(...)` e `obj.foo(...)` — o segundo caso e
# a maioria em Java/C#, e era exatamente o que o padrao textual `foo($$$)`
# deixava passar: no petclinic ele achava 0 chamadas de
# `owners.findByLastNameStartingWith(...)`, contra 13 por kind.
ag_find_calls() {
  local ag="$1" lang="$2" name="$3"; shift 3
  local scopes=("$@"); [ ${#scopes[@]} -eq 0 ] && scopes=(".")
  local kinds k fld out
  kinds="$(node_kinds "$lang" call)"
  [ -z "$kinds" ] && return 2
  # O campo que guarda o nome MUDA por linguagem: Java usa `name` no
  # method_invocation, C# usa `function` no invocation_expression. Em vez de
  # modelar isso na tabela, tentamos os candidatos — se a linguagem usar outro
  # nome de campo, a regra simplesmente nao casa e passamos ao proximo.
  #
  # E o regex precisa aceitar o ponto: em C# o no do campo `function` e a
  # expressao inteira (`services.CatalogAI.GetEmbeddingAsync`), nao so o
  # identificador. `(^|\.)nome$` cobre chamada nua e chamada em objeto, sem
  # deixar `GetEmbedding` casar com `GetEmbeddingsAsync`.
  for k in $kinds; do
    for fld in name function; do
      out="$("$ag" scan --inline-rules "id: c
language: $lang
rule:
  kind: $k
  has: { field: $fld, regex: '(^|\.)$name\$' }" "${scopes[@]}" --json=stream </dev/null 2>/dev/null \
        | _ag_stream_to_lines)"
      if [ -n "$out" ]; then printf '%s\n' "$out"; break; fi
    done
  done
}

# Linguagens presentes no repositorio, deduzidas das extensoes rastreadas.
repo_langs() {
  git ls-files 2>/dev/null | sed 's/.*\.//' | sort -u \
    | while read -r e; do lang_of_file "x.$e"; done | sort -u | grep -v '^$'
}

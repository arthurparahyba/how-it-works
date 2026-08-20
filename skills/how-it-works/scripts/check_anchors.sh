#!/usr/bin/env bash
# check_anchors.sh
# Confere as referencias `arquivo:linha` de uma explicacao contra o codigo real.
#
# Por que existe: a ancora e a promessa de que o leitor pode verificar. Uma
# ancora errada nao estraga uma frase — estraga o documento inteiro, porque quem
# confere uma, nao acha, e passa a desconfiar de todas. Ja aconteceu: uma
# explicacao trocou os numeros de "criar" e "atualizar" item e passou em todas as
# checagens de conteudo, porque elas so verificam que a ancora EXISTE no formato
# certo, nunca que ela aponta para o lugar certo.
#
# Este script NAO julga se a afirmacao e verdadeira. Ele reporta o que existe
# naquela linha e deixa o julgamento para quem tem contexto. Tres saidas:
#
#   ok    o nome citado ao lado da ancora aparece na linha ou nas vizinhas
#   ??    nao apareceu — pode ser legitimo (ancora aponta um bloco) ou erro.
#         Imprime a linha real e o metodo que a contem, para o leitor decidir.
#   ERRO  arquivo inexistente, linha alem do fim, ou linha vazia. Sem duvida.
#
# Nunca adivinha: preferir "nao sei" a um alarme falso, porque alarme falso faz
# a checagem ser ignorada.
#
# Uso: ./check_anchors.sh <explicacao.md> [raiz_do_repo]

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

DOC="${1:?informe o arquivo da explicacao}"
[ -f "$DOC" ] || { echo "arquivo nao encontrado: $DOC"; exit 2; }
ROOT="${2:-$(repo_root)}"
cd "$ROOT" || exit 2

WINDOW=6        # quantas linhas para cada lado contam como "por perto"
BACKSCAN=250    # ate onde subir procurando a assinatura do metodo

OK=0; UNK=0; ERR=0

# --- extracao ---------------------------------------------------------------
# Para cada ancora do markdown, emite: ancora <TAB> palavra-afirmada
# A palavra-afirmada e o ultimo identificador entre crases antes da ancora na
# mesma linha. Se nao houver, fica vazia e a checagem cai direto no "??".
extract() {
  awk '
    {
      line = $0
      while (match(line, /[A-Za-z0-9_][-A-Za-z0-9_.\/]*\.[A-Za-z]+:[0-9]+/)) {
        # RSTART/RLENGTH sao globais no awk: o match() do bloco de negrito la
        # embaixo os sobrescreve, e o avanco de `line` no fim do laco passa a
        # usar valores errados — laco infinito. Guardar antes e obrigatorio.
        astart = RSTART; alen = RLENGTH
        anchor = substr(line, astart, alen)
        before = substr(line, 1, astart - 1)
        claim = ""
        # ultimo trecho entre crases no texto que antecede a ancora
        n = split(before, parts, "`")
        for (i = n; i >= 1; i--) {
          cand = parts[i]
          if (cand ~ /^[A-Za-z_][A-Za-z0-9_.]*$/) { claim = cand; break }
        }
        # nome em **negrito** tambem conta: o template usa isso nas pecas
        if (claim == "") {
          tmp = before
          while (match(tmp, /\*\*[A-Za-z_][A-Za-z0-9_.]*\*\*/)) {
            claim = substr(tmp, RSTART + 2, RLENGTH - 4)
            tmp = substr(tmp, RSTART + RLENGTH)
          }
        }
        print anchor "\t" claim
        line = substr(line, astart + alen)
      }
    }
  ' "$1" | sort -u
}

# --- resolucao de caminho ----------------------------------------------------
# A explicacao as vezes cita so o basename ("CatalogApi.cs:237"). Resolve pelo
# repositorio; se houver mais de um candidato, avisa em vez de escolher.
FILE_INDEX=""
resolve() {
  local p="$1"
  [ -z "$FILE_INDEX" ] && FILE_INDEX="$(git ls-files 2>/dev/null)"
  if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
  local base matches n
  # Tenta primeiro o caminho como SUFIXO: `db/h2/schema.sql` e especifico o
  # bastante, e cair direto no basename acharia os tres schema.sql do repo e
  # reportaria ambiguidade que nao existe.
  matches="$(printf '%s\n' "$FILE_INDEX" | grep -F "$p" | head -5)"
  n="$(printf '%s\n' "$matches" | grep -c . | tr -dc '0-9')"
  if [ "${n:-0}" -eq 1 ]; then printf '%s' "$matches"; return 0; fi
  base="$(basename "$p")"
  matches="$(printf '%s\n' "$FILE_INDEX" | grep -F "/$base" | head -5)"
  n="$(printf '%s\n' "$matches" | grep -c . | tr -dc '0-9')"
  if [ "${n:-0}" -eq 1 ]; then printf '%s' "$matches"; return 0; fi
  # Mais de um arquivo com esse nome nao e ancora quebrada — e ancora
  # sub-especificada. O leitor tambem nao saberia qual abrir. Sinaliza como
  # "a conferir", nao como erro.
  if [ "${n:-0}" -gt 1 ]; then printf 'AMBIGUO:%s' "$n"; return 2; fi
  return 1
}

# --- metodo que contem a linha ----------------------------------------------
# Sobe procurando uma assinatura. Funciona bem em C#, Java, Go e TS; pior em
# Python; nao existe em SQL/config — nesses casos devolve vazio, e o chamador
# diz honestamente que nao sabe.
enclosing() {
  local f="$1" ln="$2"
  # Uma passada de awk ate a linha alvo, guardando a ultima assinatura vista.
  # A versao anterior fazia um `sed -n Np` por linha varrida — 250 processos por
  # ancora, ~25 ancoras: o script estourava 2 minutos. Aqui e 1 processo.
  awk -v target="$ln" '
    NR > target { exit }
    /\(/ {
      if ($0 ~ /^[[:space:]]*(if|while|for|foreach|switch|catch|return|using|await|\.)/) next
      if ($0 ~ /(public|private|protected|internal|static|override|func |def |function |void )/) {
        sig = $0; sigline = NR
      }
    }
    END {
      if (sig != "") {
        # O NOME do metodo e a informacao inteira aqui — truncar a assinatura em
        # N caracteres justamente o descarta, porque em C# os generics vem antes
        # dele. Extrai o identificador imediatamente anterior ao parentese.
        head = sig
        sub(/\(.*$/, "", head)
        gsub(/[^A-Za-z0-9_]+$/, "", head)
        if (match(head, /[A-Za-z_][A-Za-z0-9_]*$/)) {
          name = substr(head, RSTART, RLENGTH)
        } else {
          gsub(/^[[:space:]]+/, "", sig); name = substr(sig, 1, 50)
        }
        printf "%s() (linha %d)", name, sigline
      }
    }
  ' "$f"
}

# --- checagem ---------------------------------------------------------------
# A saida e separada por NIVEL DE ATENCAO. Misturar tudo numa lista faz o sinal
# (2 ancoras quebradas) sumir no meio do ruido (30 ancoras validas), e uma
# checagem ruidosa e uma checagem ignorada.
TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t anchors)" || TMPD=""
[ -n "$TMPD" ] || { echo "mktemp indisponivel"; exit 2; }
trap 'rm -rf "$TMPD"' EXIT
: > "$TMPD/erro"; : > "$TMPD/dubio"; : > "$TMPD/mapa"

while IFS="$(printf '\t')" read -r anchor claim; do
  [ -z "$anchor" ] && continue
  path="${anchor%:*}"; line="${anchor##*:}"

  file="$(resolve "$path")"; rc=$?
  if [ "$rc" -eq 2 ]; then
    printf '  %-42s ambiguo: %s arquivos com esse nome — cite o caminho\n' \
      "$anchor" "${file#AMBIGUO:}" >> "$TMPD/dubio"; continue
  elif [ "$rc" -ne 0 ]; then
    printf '  %-42s arquivo nao existe no repositorio\n' "$anchor" >> "$TMPD/erro"; continue
  fi

  total="$(grep -c '' "$file" 2>/dev/null | tr -dc '0-9')"
  if [ "${line:-0}" -gt "${total:-0}" ]; then
    printf '  %-42s alem do fim do arquivo (%s linhas)\n' "$anchor" "$total" >> "$TMPD/erro"; continue
  fi

  content="$(sed -n "${line}p" "$file" 2>/dev/null)"
  if [ -z "$(printf '%s' "$content" | tr -d '[:space:]')" ]; then
    encl="$(enclosing "$file" "$((line+1))")"
    printf '  %-42s LINHA EM BRANCO%s\n' "$anchor" \
      "$(if [ -n "$encl" ]; then printf ' — a proxima declaracao e %s' "$encl"; fi)" >> "$TMPD/erro"
    continue
  fi

  short="$(printf '%s' "$content" | sed 's/^[[:space:]]*//' | cut -c1-56)"
  encl="$(enclosing "$file" "$line")"

  lo=$((line - WINDOW)); [ "$lo" -lt 1 ] && lo=1
  near="$(sed -n "${lo},$((line + WINDOW))p" "$file" 2>/dev/null)"

  if [ -n "$claim" ]; then
    if printf '%s' "$near" | grep -qF -- "${claim##*.}" 2>/dev/null; then
      OK=$((OK+1))
    else
      printf '  %-42s citada como `%s`\n' "$anchor" "$claim" >> "$TMPD/dubio"
      printf '  %-42s   linha real: %s\n' "" "$short" >> "$TMPD/dubio"
      [ -n "$encl" ] && printf '  %-42s   dentro de: %s\n' "" "$encl" >> "$TMPD/dubio"
    fi
  fi
  # Toda ancora valida entra no mapa, com o metodo que a contem. E aqui que se
  # enxerga a troca de numeros: o mapa diz UpdateItem e o texto diz "criado".
  printf '  %-42s %s\n' "$anchor" "${encl:-$short}" >> "$TMPD/mapa"
done < <(extract "$DOC")

ERR="$(grep -c . "$TMPD/erro" | tr -dc '0-9')"
UNK="$(grep -cE '^  [A-Za-z0-9_/.-]+:[0-9]+ +citada|ambiguo' "$TMPD/dubio" | tr -dc '0-9')"
MAP="$(grep -c . "$TMPD/mapa" | tr -dc '0-9')"

if [ "${ERR:-0}" -gt 0 ]; then
  printf 'ANCORAS QUEBRADAS (%s) — corrija antes de entregar\n\n' "$ERR"; cat "$TMPD/erro"; echo
fi
if [ "${UNK:-0}" -gt 0 ]; then
  printf 'A CONFERIR (%s) — o nome citado nao aparece perto da linha\n\n' "$UNK"; cat "$TMPD/dubio"; echo
fi
printf 'MAPA DAS ANCORAS (%s) — cada uma e o que a contem. Compare com o que o\n' "$MAP"
printf 'texto afirma sobre ela: e aqui que numero trocado aparece.\n\n'
sort -u "$TMPD/mapa"

printf '\n  %s verificadas · %s a conferir · %s QUEBRADAS\n' "$OK" "${UNK:-0}" "${ERR:-0}"
[ "${ERR:-0}" -gt 0 ] && warn "ha ancoras quebradas — o leitor vai abrir o arquivo e nao achar o que foi dito."
exit 0

#!/usr/bin/env bash
# validate_proposal.sh
# Verifica, de forma deterministica, as AFIRMACOES que a proposta faz sobre o
# codigo — antes de apresenta-la ao desenvolvedor. Pega o erro classico de IA:
# propor codigo que chama simbolos/arquivos que nao existem, ou criar algo que
# ja existe (colisao). Nao julga a proposta; so confere fatos.
#
# Entrada: um arquivo de "claims", uma por linha, nos formatos:
#   existing-symbol:NomeDoSimbolo     -> deve JA existir no repo
#   existing-file:caminho/do/arquivo  -> deve JA existir
#   new-symbol:NomeDoSimbolo          -> sera CRIADO (nao pode existir ainda)
#   new-file:caminho/do/arquivo       -> sera CRIADO (nao pode existir ainda)
#
# Uso: ./validate_proposal.sh claims.txt
# Saida: JSON com verified / missing / new_ok / collision.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

CLAIMS="${1:?informe o arquivo de claims}"
[ -f "$CLAIMS" ] || { echo '{"error":"claims nao encontrado"}'; exit 1; }
cd "$(repo_root)" || exit 1

AG="$(astgrep_bin)"

# procura a DEFINICAO de um simbolo (nao so ocorrencias). Estrutural se possivel.
symbol_defined() {
  local sym="$1"
  if [ -n "$AG" ]; then
    # tenta padroes de definicao comuns entre linguagens
    for pat in "class $sym" "def $sym" "func $sym" "function $sym" "$sym(\$\$\$) {" "void $sym" "$sym ="; do
      if "$AG" run --pattern "$pat" --json=compact 2>/dev/null | grep -q '"text"'; then return 0; fi
    done
  fi
  # fallback textual: nome apos class/def/func/etc, ou nome seguido de ( ou = .
  # Busca na ARVORE DE TRABALHO (inclui codigo novo ainda nao commitado) para
  # nao gerar falso "missing" durante desenvolvimento ativo. Prefere ripgrep;
  # cai para grep -r; git grep e o ultimo recurso (so ve commitados).
  local re="(class|def|func|function|interface|type)[[:space:]]+$sym\b|\b$sym[[:space:]]*[(=]"
  if have rg; then
    rg -q -e "$re" 2>/dev/null && return 0
  elif grep -rIqE "$re" . 2>/dev/null; then
    return 0
  else
    git grep -qE "$re" 2>/dev/null && return 0
  fi
  return 1
}

verified=(); missing=(); new_ok=(); collision=()

while IFS= read -r line; do
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -z "$line" ] && continue
  kind="${line%%:*}"; val="${line#*:}"
  case "$kind" in
    existing-symbol)
      if symbol_defined "$val"; then verified+=("$val"); else missing+=("$val"); fi ;;
    existing-file)
      if [ -f "$val" ]; then verified+=("$val"); else missing+=("$val"); fi ;;
    new-symbol)
      if symbol_defined "$val"; then collision+=("$val"); else new_ok+=("$val"); fi ;;
    new-file)
      if [ -f "$val" ]; then collision+=("$val"); else new_ok+=("$val"); fi ;;
    *) warn "claim ignorada (formato desconhecido): $line" ;;
  esac
done < "$CLAIMS"

arr() { local IFS=,; local out=""; for x in "$@"; do out+="\"$(json_escape "$x")\","; done; echo "[${out%,}]"; }

cat << JSON
{
  "verified":  $(arr "${verified[@]}"),
  "missing":   $(arr "${missing[@]}"),
  "new_ok":    $(arr "${new_ok[@]}"),
  "collision": $(arr "${collision[@]}"),
  "verdict": "$([ ${#missing[@]} -eq 0 ] && [ ${#collision[@]} -eq 0 ] && echo ok || echo needs_fix)"
}
JSON

[ ${#missing[@]} -gt 0 ]   && warn "SIMBOLOS/ARQUIVOS INEXISTENTES referenciados: ${missing[*]} (risco de alucinacao)"
[ ${#collision[@]} -gt 0 ] && warn "COLISAO: proposta cria algo que ja existe: ${collision[*]}"

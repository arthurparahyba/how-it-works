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
MAX_HITS=40   # cap de sementes: mantem o conjunto de trabalho pequeno

log "localizando fatia | termos: $TERMS | escopo: ${SCOPES[*]}"

emit() { printf '%s\n' "$1"; }   # cada linha: caminho:linha:trecho

hits=0
search_with_ripgrep() {
  have rg || return 1
  rg --line-number --no-heading --max-count 5 -e "$TERMS" "${SCOPES[@]}" 2>/dev/null \
    | head -n "$MAX_HITS"
}
search_with_gitgrep() {
  # ultimo recurso: sempre disponivel num repo git
  git grep -n -E "$TERMS" -- "${SCOPES[@]}" 2>/dev/null | head -n "$MAX_HITS"
}

# ast-grep brilha quando o termo e um identificador estrutural (nome de simbolo).
# Aqui usamos ripgrep para a varredura ampla de sementes por ser mais simples de
# escopar por diretorio; ast-grep entra com forca no expand_impact (call sites).
if have rg; then
  log "usando ripgrep para as sementes"
  search_with_ripgrep
else
  warn "ripgrep ausente; usando git grep"
  search_with_gitgrep
fi

# Nota: se AG estiver disponivel e os termos forem simbolos, o expand_impact
# usara ast-grep para achar definicoes e chamadas com precisao estrutural.
[ -n "$AG" ] && log "ast-grep disponivel ($AG) para o passo de expansao" \
             || warn "ast-grep ausente: expansao usara heuristica textual"

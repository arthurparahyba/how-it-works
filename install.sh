#!/usr/bin/env bash
# install.sh - instala as skills deste repositório no Claude Code (symlink).
# Idempotente. Não requer privilégios.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS="${HOME}/.claude/skills"

mkdir -p "$CLAUDE_SKILLS"

link_skill() {
  local name="$1"
  local src="$REPO_DIR/skills/$name"
  local dst="$CLAUDE_SKILLS/$name"
  [ -d "$src" ] || { echo "  [!] skill não encontrada: $src"; return 1; }
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    echo "  substituindo link existente: $dst"
    rm -rf "$dst"
  fi
  ln -s "$src" "$dst"
  chmod +x "$src"/scripts/*.sh 2>/dev/null || true
  echo "  ok  $name -> $dst"
}

echo "instalando skills do Feature Explainer..."
link_skill "how-it-works"
link_skill "propose-implementation"

echo
echo "Pronto. Ferramentas opcionais — nenhuma e obrigatoria, a skill degrada:"
echo
check() {  # <binario> <o que compra> <como instalar>
  if command -v "$1" >/dev/null 2>&1; then
    printf '  [x] %-9s %s\n' "$1" "$2"
  else
    printf '  [ ] %-9s %s\n      instale com: %s\n' "$1" "$2" "$3"
  fi
}
check ast-grep "casa definicao/chamada por tipo de no — sobe de tier0 para tier1" \
      "brew install ast-grep | npm i -g @ast-grep/cli | cargo install ast-grep"
check rg       "busca textual rapida (usada em todos os tiers)" \
      "brew install ripgrep | apt install ripgrep"
check gh       "recupera o PR de cada commit — a camada do 'porque'" \
      "brew install gh | ver cli.github.com"
check scip     "find-references reais — sobe para tier2 (exige indice em cache)" \
      "ver docs/03-tooling-tiers.md"
echo
echo "Uso: em um repositório de código, peça ao Claude Code:"
echo '  "explique como funciona <funcionalidade> antes de eu implementar a mudança"'

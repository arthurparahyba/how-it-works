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
link_skill "explain-current-state"
link_skill "propose-implementation"

echo
echo "Pronto. Verifique as ferramentas opcionais no PATH:"
for t in ast-grep sg rg scip gh; do
  if command -v "$t" >/dev/null 2>&1; then echo "  [x] $t"; else echo "  [ ] $t (opcional)"; fi
done
echo
echo "Uso: em um repositório de código, peça ao Claude Code:"
echo '  "explique como funciona <funcionalidade> antes de eu implementar a mudança"'

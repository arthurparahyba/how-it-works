#!/usr/bin/env bash
# common.sh - utilidades compartilhadas pelos scripts da fase "como e hoje".
# Todas as funcoes sao defensivas: nunca abortam o pipeline, apenas sinalizam
# o que nao foi possivel resolver (degradacao graciosa).

set -o pipefail

# --- deteccao de ferramentas -------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# ast-grep expoe o binario tanto como `ast-grep` quanto como `sg`.
astgrep_bin() {
  if have ast-grep; then echo "ast-grep";
  elif have sg;       then echo "sg";
  else echo ""; fi
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
  python3 - "$1" << 'PY' 2>/dev/null || printf '%s' "$1"
import json,sys
print(json.dumps(sys.argv[1])[1:-1], end="")
PY
}

# jq e opcional; se existir, usamos para montar JSON de forma robusta.
have_jq() { have jq; }

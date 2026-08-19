#!/usr/bin/env bash
# emit_openspec_change.sh
# Materializa o pacote de mudanca do OpenSpec a partir dos artefatos ja gerados
# e validados. Cria openspec/changes/<id>/ com proposal.md, design.md, tasks.md
# e (opcional) um delta spec. Se o CLI do openspec existir, roda validate.
#
# Uso: ./emit_openspec_change.sh <change-id> <dir_com_artefatos>
#   onde <dir_com_artefatos> contem: proposal.md design.md tasks.md [spec.md]
# Copia tambem o current-state da fase 1, se presente no dir.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/lib/common.sh"

ID="${1:?informe o change-id (ex.: fix-discount-cap)}"
SRC="${2:?informe o diretorio com os artefatos gerados}"
ROOT="$(repo_root)"
DEST="$ROOT/openspec/changes/$ID"

[ -d "$SRC" ] || { warn "diretorio de artefatos inexistente: $SRC"; exit 1; }

mkdir -p "$DEST"
copied=()
for f in proposal.md design.md tasks.md current-state.md current-state.dossier.json; do
  if [ -f "$SRC/$f" ]; then cp "$SRC/$f" "$DEST/$f"; copied+=("$f"); fi
done
# delta specs (arquivos *.spec.md), se houver
for f in "$SRC"/*.spec.md; do
  [ -f "$f" ] || continue
  mkdir -p "$DEST/specs"
  cp "$f" "$DEST/specs/$(basename "$f")"; copied+=("specs/$(basename "$f")")
done

log "pacote de mudanca criado em: openspec/changes/$ID"
log "arquivos: ${copied[*]}"

# validacao opcional pelo proprio OpenSpec
if have openspec; then
  log "rodando: openspec validate $ID --strict"
  ( cd "$ROOT" && openspec validate "$ID" --strict ) || \
    warn "openspec validate apontou problemas — revise antes do propose."
else
  warn "CLI 'openspec' ausente: pulei a validacao. Rode 'openspec validate $ID' quando disponivel."
fi

echo "$DEST"

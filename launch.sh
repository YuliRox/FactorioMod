#!/usr/bin/env bash
# launch.sh — Launch Factorio with this mod directory and a specified save.
#
# Required environment variables:
#   FACTORIO_EXE   Full path to factorio.exe
#   FACTORIO_SAVE  Save name or full path to a .zip save file
#
# Example ~/.bashrc entries:
#   export FACTORIO_EXE="C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
#   export FACTORIO_SAVE="second_engineer_debugbench"

set -euo pipefail

error=0

if [[ -z "${FACTORIO_EXE:-}" ]]; then
  echo "Error: FACTORIO_EXE is not set. Set it to the full path of factorio.exe." >&2
  error=1
elif [[ ! -f "$FACTORIO_EXE" ]]; then
  echo "Error: FACTORIO_EXE does not point to a file: $FACTORIO_EXE" >&2
  error=1
fi

if [[ -z "${FACTORIO_SAVE:-}" ]]; then
  echo "Error: FACTORIO_SAVE is not set. Set it to a save name or path." >&2
  error=1
fi

if [[ $error -ne 0 ]]; then
  exit 1
fi

MOD_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Launching Factorio..."
echo "  Exe:  $FACTORIO_EXE"
echo "  Save: $FACTORIO_SAVE"
echo "  Mods: $MOD_DIR"

"$FACTORIO_EXE" \
  --mod-directory "$MOD_DIR" \
  --load-game    "$FACTORIO_SAVE"

#!/usr/bin/env bash
# launch.codex.sh — Codex-friendly Factorio launcher with auto-detection.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOD_DIR="$ROOT_DIR"

detect_factorio_exe() {
  local candidates=(
    "/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
    "/mnt/c/Program Files/Factorio/bin/x64/factorio.exe"
  )
  local exe
  for exe in "${candidates[@]}"; do
    if [[ -f "$exe" ]]; then
      printf '%s\n' "$exe"
      return 0
    fi
  done
  return 1
}

FACTORIO_EXE="${FACTORIO_EXE:-}"
if [[ -z "$FACTORIO_EXE" ]]; then
  FACTORIO_EXE="$(detect_factorio_exe || true)"
fi

if [[ -z "$FACTORIO_EXE" || ! -f "$FACTORIO_EXE" ]]; then
  echo "Error: factorio.exe not found. Set FACTORIO_EXE explicitly." >&2
  exit 1
fi

cmd=(
  "$FACTORIO_EXE"
  --mod-directory "$MOD_DIR"
)

if [[ -n "${FACTORIO_SAVE:-}" ]]; then
  cmd+=(--load-game "$FACTORIO_SAVE")
fi

if [[ $# -gt 0 ]]; then
  cmd+=("$@")
fi

echo "Launching Factorio:"
echo "  Exe:  $FACTORIO_EXE"
echo "  Mods: $MOD_DIR"
if [[ -n "${FACTORIO_SAVE:-}" ]]; then
  echo "  Save: $FACTORIO_SAVE"
fi

"${cmd[@]}"

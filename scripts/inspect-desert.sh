#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_LOCAL="$ROOT_DIR/.env.local"

if [[ -f "$ENV_LOCAL" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_LOCAL"
fi

is_wsl=0
if grep -qi microsoft /proc/version 2>/dev/null; then
  is_wsl=1
fi

detect_factorio_path() {
  if [[ -n "${FACTORIO_PATH:-}" ]]; then
    printf '%s\n' "$FACTORIO_PATH"
    return 0
  fi

  if [[ -n "${FACTORIO_EXE:-}" ]]; then
    printf '%s\n' "$FACTORIO_EXE"
    return 0
  fi

  local candidates=(
    "/mnt/c/Program Files/Factorio/bin/x64/factorio.exe"
    "/mnt/c/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe"
    "$HOME/.steam/steam/steamapps/common/Factorio/bin/x64/factorio"
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

FACTORIO_BIN="$(detect_factorio_path || true)"
if [[ -z "$FACTORIO_BIN" || ! -f "$FACTORIO_BIN" ]]; then
  echo "Error: Factorio binary not found. Set FACTORIO_PATH in .env.local." >&2
  exit 1
fi

MODE="surface"
SAVE_PATH="$ROOT_DIR/.factorio-test/saves/second_engineer_desert_newgame.zip"
REUSE=0
PREPARE_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --mode=surface)
      MODE="surface"
      ;;
    --mode=perimeter-authoring)
      MODE="perimeter-authoring"
      SAVE_PATH="$ROOT_DIR/.factorio-test/saves/second_engineer_perimeter_authoring.zip"
      ;;
    --reuse)
      REUSE=1
      ;;
    --prepare-only)
      PREPARE_ONLY=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: bash scripts/inspect-desert.sh [--mode=surface|--mode=perimeter-authoring] [--reuse] [--prepare-only]" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$SAVE_PATH")"

tmp_map_gen="$(mktemp)"
trap 'rm -f "$tmp_map_gen"' EXIT
if [[ "$MODE" == "perimeter-authoring" ]]; then
cat > "$tmp_map_gen" <<'JSON'
{
  "peaceful_mode": true,
  "autoplace_controls": {
    "enemy-base": {"frequency": 0, "size": 0, "richness": 0}
  },
  "property_expression_names": {
    "control-setting:moisture:bias": "-3.5",
    "control-setting:aux:bias": "2.5"
  }
}
JSON
else
cat > "$tmp_map_gen" <<'JSON'
{
  "peaceful_mode": true,
  "autoplace_controls": {
    "enemy-base": {"frequency": 0, "size": 0, "richness": 0}
  },
  "property_expression_names": {
    "control-setting:moisture:bias": "-2.5",
    "control-setting:aux:bias": "2.0"
  }
}
JSON
fi

run_factorio() {
  if [[ $is_wsl -eq 1 && "${FACTORIO_BIN##*.}" == "exe" ]]; then
    local win_mod_dir win_save win_map
    win_mod_dir="$(wslpath -w "$ROOT_DIR")"
    win_save="$(wslpath -w "$SAVE_PATH")"
    win_map="$(wslpath -w "$tmp_map_gen")"

    if [[ "$1" == "create" ]]; then
      "$FACTORIO_BIN" --mod-directory "$win_mod_dir" --create "$win_save" --map-gen-settings "$win_map"
      return
    fi

    if [[ "$1" == "load" ]]; then
      "$FACTORIO_BIN" --mod-directory "$win_mod_dir" --load-game "$win_save"
      return
    fi
  fi

  if [[ "$1" == "create" ]]; then
    "$FACTORIO_BIN" --mod-directory "$ROOT_DIR" --create "$SAVE_PATH" --map-gen-settings "$tmp_map_gen"
    return
  fi

  if [[ "$1" == "load" ]]; then
    "$FACTORIO_BIN" --mod-directory "$ROOT_DIR" --load-game "$SAVE_PATH"
    return
  fi
}

if [[ $REUSE -eq 0 ]]; then
  rm -f "$SAVE_PATH"
fi

if [[ ! -f "$SAVE_PATH" ]]; then
  echo "Creating fresh new game ($MODE):"
  echo "  Save: $SAVE_PATH"
  run_factorio create
fi

if [[ $PREPARE_ONLY -eq 1 ]]; then
  echo "Inspection save is ready."
  exit 0
fi

echo "Launching Factorio directly into fresh new game ($MODE)..."
run_factorio load

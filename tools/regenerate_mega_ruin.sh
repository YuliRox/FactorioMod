#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_step() {
  local label="$1"
  shift
  printf '\n[%s]\n' "$label"
  "$@"
}

cd "$ROOT_DIR"

# Design decision: this script is the stable single entrypoint for regenerating
# the current test mega-ruin. It always runs the same ordered pipeline so ruin
# iteration does not depend on ad-hoc manual command sequences.
run_step "Normalize + Merge" node tools/blueprint_normalize_merge.js
run_step "Ruin Template" node tools/blueprint_ruin_template.js
run_step "Wear Profile" node tools/blueprint_wear_profile.js
run_step "Export Lua" node tools/blueprint_export_lua.js

printf '\n[Done]\n'
printf 'Normalized JSON: %s\n' "$ROOT_DIR/tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json"
printf 'Ruin Template:   %s\n' "$ROOT_DIR/tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json"
printf 'Worn Template:   %s\n' "$ROOT_DIR/tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json"
printf 'Lua Export:      %s\n' "$ROOT_DIR/second_engineer/scripts/worldgeneration/generated/merged_rails_solar.lua"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_BP="$ROOT_DIR/tools/central-district-blueprint.txt"
AUTHORED_DIR="$ROOT_DIR/tools/blueprint-authored/central-district"
EXTRACTED_JSON="$AUTHORED_DIR/root-single-blueprint/00-central-district.json"
NORMALIZED_JSON="$ROOT_DIR/tools/blueprint-normalized/authored/central-district.json"
RUIN_JSON="$ROOT_DIR/tools/ruin-templates/authored/central-district.ruin-template.json"
WORN_JSON="$ROOT_DIR/tools/ruin-templates-worn/authored/central-district.worn.json"
OUTPUT_ROOT="$ROOT_DIR/second_engineer/scripts/worldgeneration/generated/core_district"

cd "$ROOT_DIR"

printf '\n[Extract]\n'
node tools/blueprint_extract.js --input "$SOURCE_BP" --output-dir "$AUTHORED_DIR"

printf '\n[Normalize]\n'
node tools/blueprint_normalize_single.js \
  --input "$EXTRACTED_JSON" \
  --output "$NORMALIZED_JSON" \
  --label "Central District"

printf '\n[Ruin Template]\n'
node tools/blueprint_ruin_template.js \
  --input "$NORMALIZED_JSON" \
  --output "$RUIN_JSON" \
  --template-name "se-central-district"

printf '\n[Wear Profile]\n'
node tools/blueprint_wear_profile.js \
  --input "$RUIN_JSON" \
  --output "$WORN_JSON" \
  --profile-name "central-district-v1"

printf '\n[Compile]\n'
rm -rf "$OUTPUT_ROOT"
node tools/blueprint_compile_sectors.js \
  --input "$WORN_JSON" \
  --output-root "$OUTPUT_ROOT"

printf '\n[Done]\n'
printf 'Extracted:   %s\n' "$EXTRACTED_JSON"
printf 'Normalized:  %s\n' "$NORMALIZED_JSON"
printf 'Ruin:        %s\n' "$RUIN_JSON"
printf 'Worn:        %s\n' "$WORN_JSON"
printf 'Generated:   %s\n' "$OUTPUT_ROOT"

# Blueprint To Lua Pipeline

## Current Goal

Turn selected Factorio blueprints into reviewable ruin data and then into a Lua data module that can be consumed by the mod.

The current pipeline is intentionally offline-first. Heavy transformation work happens in `tools/`, not at runtime.

## Current Pipeline

## Stable Regeneration Entry Point

For the current merged rail/solar test ruin, use:

```bash
bash tools/regenerate_mega_ruin.sh
```

or:

```bash
npm run blueprint:regenerate
```

This runs the current transformation chain in a fixed order:

1. normalize + merge
2. ruin-template conversion
3. wear-profile pass
4. Lua export

The point of this script is to avoid ad-hoc partial reruns and keep ruin iteration deterministic.

### 1. Blueprint extraction

Command:

```bash
npm run blueprint:extract
```

Input:

- `tools/blueprint-input.txt`

Output:

- `tools/blueprint-extracted/...`

What it does:

- decodes the Factorio blueprint string
- walks nested blueprint books recursively
- writes one directory per blueprint book
- writes one JSON file per blueprint
- extracts only:
  - `entities[]`: `name`, `position`, `direction`, `type`
  - `tiles[]`: `name`, `position`

### 2. Normalize and merge selected blueprints

Command:

```bash
npm run blueprint:normalize-merge
```

Input:

- `tools/blueprint-extracted/root-modular-train-grid/0-grid-rails/03-rails-barbone-grid.json`
- `tools/blueprint-extracted/root-modular-train-grid/0-grid-rails/11-solar-grid.json`

Output:

- `tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json`

What it does:

- merges those two source blueprints
- chooses one shared anchor
- rewrites all positions relative to that anchor
- computes one merged bounding box
- removes only exact duplicates

### 3. Map the normalized blueprint into ruin-template buckets

Command:

```bash
npm run blueprint:ruin-template
```

Input:

- `tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json`

Output:

- `tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json`

What it does:

- applies first-pass mapping rules by entity type
- groups output into reviewable categories:
  - `convert_to_remnant`
  - `cluster_to_remnants`
  - `collapsed_to_remnants`
  - `preserve_as_damaged`
  - `foundation`

Important current behavior:

- rails are reduced into a sparse skeleton instead of staying 1:1
- solar panels and rail signals map directly to remnant targets
- expensive infrastructure such as substations, poles, accumulators, and roboports stays in a damaged-live bucket

### 4. Apply a deterministic wear profile

Command:

```bash
npm run blueprint:wear-profile
```

Input:

- `tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json`

Output:

- `tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json`

What it does:

- applies deterministic wear based on template name and relative position
- splits data into:
  - `entities.remnant`
  - `entities.damaged_live`
  - `entities.missing`
  - `tiles.foundation_kept`
  - `tiles.foundation_cracked`
  - `tiles.foundation_missing`

This gives a stable ruin state for testing and inspection.

### 5. Export the worn template into Lua

Command:

```bash
npm run blueprint:export-lua
```

Input:

- `tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json`

Output:

- `second_engineer/scripts/worldgeneration/generated/merged_rails_solar.lua`

What it does:

- converts the worn JSON into a plain Lua data module
- preserves the same worn buckets as Lua tables
- keeps the output runtime-readable without JSON parsing

## Current Test Integration

The generated Lua module is currently wired into world generation as a one-off inspection ruin:

- module:
  - `second_engineer/scripts/worldgeneration/generated/merged_rails_solar.lua`
- placement code:
  - `second_engineer/scripts/worldgen.lua`

Current behavior:

- it is placed near the Nauvis spawn area
- it exists only as a temporary inspection scaffold
- this is not the intended final runtime format for multiple large ruins

## Why This Is Temporary

The current Lua export proves the pipeline works, but it is too large to be the long-term runtime representation for many mega-ruins.

The intended next architecture is documented separately in:

- `planning/LargeRuinRuntimeStrategy.md`

That future architecture will sectorize and compile large ruins into smaller runtime packages.

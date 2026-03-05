# Blueprint To Lua Pipeline

## Current Goal

Turn selected Factorio blueprints into reviewable ruin data and compile them into sectorized Lua modules consumed by worldgen.

The current pipeline is intentionally offline-first. Heavy transformation work happens in `tools/`, not at runtime.

## Current Pipeline

## Stable Regeneration Entry Point

For the current authored central district, use:

```bash
bash tools/build_central_district_from_blueprint.sh
```

or:

```bash
npm run blueprint:regenerate
```

This runs the current transformation chain in a fixed order:

1. extract authored blueprint
2. normalize
3. ruin-template conversion
4. wear-profile pass
5. sector compile into one runtime package

The point of this script is to avoid ad-hoc partial reruns and keep ruin iteration deterministic.

### 1. Blueprint extraction

Command used by the central district builder:

```bash
node tools/blueprint_extract.js --input tools/central-district-blueprint.txt --output-dir tools/blueprint-authored/central-district
```

Input:

- `tools/central-district-blueprint.txt`

Output:

- `tools/blueprint-authored/central-district/...`

What it does:

- decodes the Factorio blueprint string
- walks nested blueprint books recursively
- writes one directory per blueprint book
- writes one JSON file per blueprint
- extracts only:
  - `entities[]`: `name`, `position`, `direction`, `type`
  - `tiles[]`: `name`, `position`

### 2. Normalize one authored blueprint

Command used by the central district builder:

```bash
node tools/blueprint_normalize_single.js --input <extracted.json> --output tools/blueprint-normalized/authored/central-district.json
```

Input:

- `tools/blueprint-authored/central-district/root-single-blueprint/00-central-district.json`

Output:

- `tools/blueprint-normalized/authored/central-district.json`

What it does:

- rebases the authored blueprint to a deterministic anchor
- rewrites all positions relative to that anchor
- computes one bounding box
- preserves the authored shape directly

### 3. Map the normalized blueprint into ruin-template buckets

Command:

```bash
node tools/blueprint_ruin_template.js --input tools/blueprint-normalized/authored/central-district.json --output tools/ruin-templates/authored/central-district.ruin-template.json --template-name central-district
```

Input:

- `tools/blueprint-normalized/authored/central-district.json`

Output:

- `tools/ruin-templates/authored/central-district.ruin-template.json`

What it does:

- applies first-pass mapping rules by entity type
- groups output into reviewable categories:
  - `convert_to_remnant`
  - `cluster_to_remnants`
  - `collapsed_to_remnants`
  - `preserve_as_damaged`
  - `foundation`

### 4. Apply a deterministic wear profile

Command:

```bash
node tools/blueprint_wear_profile.js --input tools/ruin-templates/authored/central-district.ruin-template.json --output tools/ruin-templates-worn/authored/central-district.worn.json --profile-name central-district-v1
```

Input:

- `tools/ruin-templates/authored/central-district.ruin-template.json`

Output:

- `tools/ruin-templates-worn/authored/central-district.worn.json`

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

### 5. Compile the worn blueprint into one sectorized runtime package

Command:

```bash
node tools/blueprint_compile_sectors.js --input tools/ruin-templates-worn/authored/central-district.worn.json --output-root second_engineer/scripts/worldgeneration/generated/core_district
```

Input:

- `tools/ruin-templates-worn/authored/central-district.worn.json`

Output:

- `second_engineer/scripts/worldgeneration/generated/core_district/manifest.lua`
- corresponding `sectors/*.lua`

What it does:

- partitions entities and tiles into 32x32 sectors
- writes one manifest module and one Lua module per sector
- keeps runtime memory bounded by loading only needed sector modules

## Current Runtime Integration

The generated sector package is wired into world generation as one authored central district placement:

- modules:
  - `second_engineer/scripts/worldgeneration/generated/core_district/*`
- placement code:
  - `second_engineer/scripts/worldgen.lua`

Current behavior:

- core district is spawned from one authored package near Nauvis spawn
- placement uses the compiled manifest anchor and bounds directly
- the district is debug-tagged in-world for inspection

## Runtime Direction

The sectorized compiler is the baseline runtime path for large ruins. Further improvements are tracked in:

- `planning/LargeRuinRuntimeStrategy.md`

That future architecture will sectorize and compile large ruins into smaller runtime packages.

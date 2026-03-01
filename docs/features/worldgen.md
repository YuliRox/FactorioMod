# World Generation

**Source:** `scripts/worldgen.lua`, `scripts/worldgeneration/`

Custom Nauvis worldgen. Replaces the vanilla random start with an authored starter area, scrubs excess ore to enforce scarcity, and scatters ambient industrial remnants across the map.

---

## Storage keys

| Key | Type | Description |
|-----|------|-------------|
| `storage.worldgen` | `{starter_area_prepared: bool, starter_ruins_placed: bool}` | Tracks one-time setup flags |
| `storage.pending_cutscene_skip` | `{[player_index] = tick}` | Managed in `control.lua`; deferred 1-tick vanilla intro cutscene cancel |

---

## Public functions

| Function | Called from | Purpose |
|----------|-------------|---------|
| `Worldgen.on_init()` | `on_init` | Applies map-gen settings, runs `prepare_starter_area` |
| `Worldgen.on_configuration_changed()` | `on_configuration_changed` | Re-applies map-gen settings; restamps missing starter area or ruin cluster |
| `Worldgen.on_chunk_generated(event)` | `on_chunk_generated` | Trims resources, places starter ruin cluster or band remnant |
| `Worldgen.apply_map_gen_settings()` | init + config changed | Dials down vanilla ore frequency/size/richness on Nauvis |

---

## Map-gen settings

`apply_map_gen_settings` reduces autoplace controls on the Nauvis surface directly (not via map preset). These are the tuned values:

| Resource | Frequency | Size | Richness |
|----------|-----------|------|----------|
| iron-ore | 0.45 | 0.30 | 0.38 |
| copper-ore | 0.42 | 0.28 | 0.36 |
| coal | 0.42 | 0.26 | 0.34 |
| stone | 0.35 | 0.24 | 0.32 |
| uranium-ore | 0.40 | 0.30 | 0.45 |
| crude-oil | 0.55 | 0.45 | 0.60 |

The chunk post-processing layer then applies a harsher per-deposit scarcity pass on top.

---

## Starter area preparation

Runs once on `on_init` (guarded by `starter_area_prepared` flag). Steps:

1. `surface.request_to_generate_chunks({0,0}, 6)` + `force_generate_chunk_requests()` — pre-generate spawn region
2. Clear all vanilla resources inside `STARTER_CLEAR_AREA` (±96 tiles from origin)
3. Stamp 4 hand-authored resource patches with terrain correction (land stamped under patches to prevent lakes erasing them):

| Resource | Position | Radius | Amount |
|----------|----------|--------|--------|
| iron-ore | (-24, -16) | 5 | 900 |
| copper-ore | (24, -16) | 5 | 850 |
| coal | (-22, 20) | 5 | 850 |
| stone | (22, 20) | 5 | 900 |

4. Clear blockers + correct terrain under starter ruin footprint
5. Place starter ruin cluster (`ruins.lua`) at origin (52, -18) with biome-matched tree decorations
6. Place 11 guaranteed fixed remnants at hard-coded positions (`remnants.lua`)
7. `verify_starter_area` — rebuilds any patch or ruin that failed or was overwritten by generation

---

## Resource band trimming

Applied per-chunk on every `on_chunk_generated` event (skips chunks intersecting `STARTER_CLEAR_AREA`).

| Band | Distance (chunks) | Keep chance | Amount scale |
|------|-------------------|-------------|--------------|
| bootstrap | ≤ 7 | 45 % | 28 % |
| marginal | ≤ 18 | 35 % | 22 % |
| contested | ≤ 36 | 55 % | 40 % |
| strategic | > 36 | 75 % | 62 % |

Roll is deterministic: `math.sin(x * 12.9898 + y * 78.233 + salt * 37.719) * 43758.5453` fractional part. Each resource type has a fixed salt (iron=11, copper=17, coal=23, stone=29, uranium=31, oil=37). Amounts are floored at per-resource minimums after scaling so fields feel disappointing rather than deleted.

An extra thinning roll (>0.82 → ×0.55) is applied to marginal-band resources within 18 chunks.

---

## Probabilistic band remnants

On every `on_chunk_generated` for chunks at distance 3–48 from origin: 42 % chance (deterministic roll by chunk position, salt=17) to place one remnant template. Template index is also deterministic (salt=29), picking from the 12 templates in `remnants.lua`.

Blockers (trees, cliffs, simple entities) are cleared in the template footprint before placement; terrain is not retiled so scenes still read as part of the biome.

---

## Data files

| File | Contents |
|------|----------|
| `scripts/worldgeneration/ruins.lua` | Starter ruin cluster: entity list with offsets/health/loot, clear area bounds, decoration point offsets |
| `scripts/worldgeneration/remnants.lua` | 12 ambient remnant templates + 11 guaranteed fixed-position placements |
| `scripts/worldgeneration/abandoned_ruins_set.lua` | Ruin set for `AbandonedRuins_updated_fork` remote API (small/medium/large categories, Nauvis-only) |
| `scripts/abandoned_ruins.lua` | Thin integration: checks mod presence, calls `remote.call("AbandonedRuins", "add_ruin_sets", …)` |

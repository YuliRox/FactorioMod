# second_engineer — Development Milestones

## M1 — Empty Skeleton ✅ *(complete)*
Valid mod that loads in Factorio 2.0. No content.

**Files:**
- `info.json` — mod identity
- `changelog.txt` — version history
- `data.lua` — data stage entry point (empty)
- `control.lua` — runtime entry point (empty)
- `locale/en/second_engineer.cfg` — mod name/description strings

**Verification:**
- Mod appears in the Factorio mod list with correct title and version
- New game starts without Lua errors in the log
- No prototype errors in the loading screen

---

## M2 — Core Items & Recipe Pipeline

**Scope:**
- Custom item group + subgroups for second_engineer content
- Items: `se-scrap`, `se-metal-debris`, `se-electronic-debris`
- Recipe categories for T1–T4 recyclers
- Stub T1 recycling recipe: 10× scrap → 1× metal-debris
- T1–T4 technology stubs in the research tree

**Files to add/modify:**
- `data.lua` — require item/recipe/tech modules
- `prototypes/item-groups.lua`
- `prototypes/items.lua`
- `prototypes/recipe-categories.lua`
- `prototypes/recipes.lua`
- `prototypes/technologies.lua`
- `locale/en/second_engineer.cfg` — item/recipe/tech names

---

## M3 — T1 Recycler Entity

**Scope:**
- `assembling-machine` entity with burner energy source
- Accepts T1 recipe category
- Placeable, fueled by coal
- Placeholder graphics (tinted vanilla sprites)

**Files to add/modify:**
- `prototypes/entities.lua` — T1 recycler entity definition
- `prototypes/items.lua` — T1 recycler item + place result
- `prototypes/recipes.lua` — T1 recycler crafting recipe
- `locale/en/second_engineer.cfg` — entity names/descriptions

---

## M4 — Resource Scarcity (Data Stage)

**Scope:**
- Startup setting: `second-engineer-scarcity` (easy / normal / hard)
- `data-updates.lua` applies ore autoplace multipliers based on setting:
  - easy: ×0.3 frequency, ×0.5 richness
  - normal: ×0.1 frequency, ×0.2 richness
  - hard: ×0.02 frequency, ×0.05 richness (ruins-only viable)

**Files to add:**
- `settings.lua` — startup setting definition
- `data-updates.lua` — ore autoplace mutation logic

---

## M5 — Scrap Drop System (Runtime)

**Scope:**
- `control.lua` event handler: `on_entity_died`
- Destroyed entities spill `se-scrap` proportional to entity cost
- Runtime-global setting: `second-engineer-entropy-factor` (default 0.1)
- Entropy factor scales scrap yield (lower = harsher)

**Files to add/modify:**
- `settings.lua` — runtime-global setting
- `control.lua` — `on_entity_died` handler, cost lookup, spill logic

---

## M6 — Ruins Generator

**Scope:**
- Startup setting: `second-engineer-ruins-enabled`
- `on_chunk_generated` handler on Nachlass surface
- Modular ruin template library (assembler, furnace, belt segment ruins)
- Random health (30–80% of max) and loot tables per template

**Files to add/modify:**
- `settings.lua` — ruins-enabled setting
- `control.lua` — `on_chunk_generated` handler
- `scripts/ruins.lua` — template library and placement logic
- `scripts/loot-tables.lua` — per-template loot definitions

---

## M7 — Planet Prototypes (Space Age)

**Guard:** All planet code wrapped in `if mods["space-age"] then`.

**Scope:**
- `se-nachlass`: depleted start planet, ruin-heavy biome, reduced ore
- `se-abraum`: waste/scrap planet, recycling efficiency bonus
- `se-tiefadern`: deep-vein endgame planet, high-energy extraction
- Space connections between planets

**Files to add:**
- `prototypes/planets.lua`
- `prototypes/space-connections.lua`
- `locale/en/second_engineer.cfg` — planet names/descriptions

---

## M8 — T2–T4 Recycler Entities

**Scope:**
- T2: electric recycler, category separation by material class
- T3: advanced molecular recycler, targeted outputs with byproduct control
- T4: atomic reconstruction matrix, near-lossless (very high energy cost)
- Each tier unlocked by corresponding technology from M2

**Files to add/modify:**
- `prototypes/entities.lua` — T2–T4 entity definitions
- `prototypes/items.lua` — T2–T4 items + place results
- `prototypes/recipes.lua` — T2–T4 crafting recipes and recycling recipes
- `locale/en/second_engineer.cfg` — names/descriptions

---

## M9 — Global Resource Tracker

**Scope:**
- Runtime global tracking primary ore consumption per surface
- Internal-only (no forced UI), feeds planetary instability system
- Remote interface: `remote.call("second_engineer", "get_resource_stats")`

**Files to add/modify:**
- `control.lua` — ore mining event hooks
- `scripts/resource-tracker.lua` — accumulation logic and remote interface

---

## M10 — Story Layer (Emergent)

**Scope:**
- Log entry items found in ruin loot tables (from M6)
- No quest popups — discovery through environment
- Research with moral tradeoffs (better mining efficiency degrades recycling yield)
- Flavor text on items and technologies

**Files to add/modify:**
- `scripts/loot-tables.lua` — add log entries to ruin loot
- `prototypes/items.lua` — log entry item definitions
- `prototypes/technologies.lua` — add tradeoff effects to tech definitions
- `locale/en/second_engineer.cfg` — all flavor text and log content

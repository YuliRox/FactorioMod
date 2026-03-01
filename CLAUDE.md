# second_engineer — Factorio Mod

## Project Overview

Hardcore survival mod for Factorio 2.0. The player arrives as the *second* engineer on a planet already stripped by the first. Progression relies on recycling destroyed entities, salvaging ruins, and circular economics rather than infinite ore extraction.

## Repository Layout

The mod folder is `second_engineer/` during development. When distributed as a `.zip` the folder inside **must** be named `second_engineer_0.1.0/` (name + underscore + version).

```
C:/Code/FactorioMod/
├── CLAUDE.md
├── docs/
│   ├── milestones.md            -- full development roadmap (M1–M10)
│   └── WorldGeneration.md       -- world generation notes and design direction
└── second_engineer/
    ├── info.json                -- required: name, version, title, author, dependencies
    ├── changelog.txt
    ├── thumbnail.png            -- recommended 144×144
    ├── data.lua                 -- entry point: requires prototypes/*
    ├── data-updates.lua         -- patches existing prototypes; AbandonedRuins hook
    ├── data-final-fixes.lua     -- hidden lab animation; dynamic recipe generation
    ├── settings.lua             -- [MISSING] needed for M4 resource scarcity settings
    ├── control.lua              -- thin event dispatcher → scripts/research_assembler
    ├── locale/en/second_engineer.cfg
    ├── graphics/                -- [MISSING] add when custom sprites are created
    │   ├── icons/
    │   └── entities/
    ├── prototypes/              -- split from data.lua by convention (not enforced)
    │   ├── entity/
    │   │   ├── research-assembler.lua  -- assembler entity + item + recipe
    │   │   └── hidden-research-lab.lua -- internal lab entity
    │   ├── item/
    │   │   └── scraps.lua             -- scrap items (7 base + 5 space-age)
    │   ├── recipe/              -- [MISSING] add when custom recipes are extracted here
    │   └── technology/          -- [MISSING] add when tech tree stubs are created (M2)
    └── scripts/                 -- split from control.lua by convention (not enforced)
        ├── research_assembler.lua     -- all assembler runtime logic
        ├── abandoned_ruins.lua        -- AbandonedRuins mod integration; registers ruin set via remote interface
        ├── worldgen.lua               -- Nauvis worldgen: map-gen settings, starter area, chunk resource trimming, band ruins
        └── worldgeneration/
            ├── ruins.lua              -- starter ruin cluster data (entities, loot, clear area, decoration points)
            ├── remnants.lua           -- 12 ambient remnant templates + 11 guaranteed fixed-position placements
            └── abandoned_ruins_set.lua -- ruin set for AbandonedRuins_updated_fork (small/medium/large categories)
```

Data stage load order (across all mods): `settings.lua` → `settings-updates.lua` → `settings-final-fixes.lua` → `data.lua` → `data-updates.lua` → `data-final-fixes.lua`.

## Mod Identity

| Field             | Value                  |
|-------------------|------------------------|
| `name`            | `second_engineer`      |
| `version`         | `0.1.0`                |
| `factorio_version`| `2.0`                  |
| `author`          | Xemrox                 |
| Hard dependency   | `base >= 2.0.0`        |
| Soft dependency   | `space-age >= 2.0.0`   |

Space Age content is always guarded with `if mods["space-age"] then`.

---

## What Is Currently Implemented

### Scrap Items (`prototypes/item/scraps.lua`)

One coloured scrap item per science pack tier (stack 200, subgroup `intermediate-product`).

| Item             | Pack                         |
|------------------|------------------------------|
| `scrap-red`      | automation-science-pack      |
| `scrap-green`    | logistic-science-pack        |
| `scrap-black`    | military-science-pack        |
| `scrap-blue`     | chemical-science-pack        |
| `scrap-purple`   | production-science-pack      |
| `scrap-yellow`   | utility-science-pack         |
| `scrap-white`    | space-science-pack           |
| `scrap-metallurgic` … `scrap-promethium` | Space Age packs (guarded) |

### Research Assembler (`prototypes/entity/research-assembler.lua`)

Assembling-machine that looks like a lab and acts as the core of the science recycling loop.

- Category `se-research-crafting` (exclusive to this machine)
- 2 module slots (`speed`, `consumption`, `pollution` effects)
- `trash_inventory_size = 12`, `ingredient_count = 12`
- Recipe auto-switched by script to match current research; `recipe_locked = true` always
- Set `active = false` when idle (IDLE_RECIPE active, no research running)
- Crafting recipe mirrors the base lab recipe

### Hidden Research Lab (`prototypes/entity/hidden-research-lab.lua`)

Internal `lab` entity spawned co-located with each assembler.

- `collision_mask = {layers = {}}` — no collision
- `energy_source = {type = "void"}`, `researching_speed = 10000`
- 2 module slots (`productivity` effect)
- `hidden = false`, `selectable_in_game = true` — **DEBUG, remove later**
- Animation patched to green-tinted base lab sprite in `data-final-fixes.lua` — **DEBUG**

### Dynamic Recipe Generation (`data-final-fixes.lua`)

Iterates `data.raw.technology` in data-final-fixes stage, collects every unique sorted science-pack combination, and generates one hidden recipe per combo named `se-research-<sorted-pack-shorts>`.

- `localised_name` built from existing `item-name.*` locale keys via nested localised strings (chunks of ≤9 to stay within Factorio's 20-parameter limit)
- `se-research-idle` recipe: no ingredients/results, `energy_required = 60`, used when no research is active

### data-updates.lua

- Sets `trash_inventory_size = 13` on all lab prototypes (12 scrap + 1 spoilage)
- If `AbandonedRuins_updated_fork` is loaded: adds `"second-engineer"` to the `current-ruin-set` string-setting's allowed values (guards against nil category table with `data.raw["string-setting"] and …`)

### Runtime — `scripts/research_assembler.lua`

All assembler logic is in module `M` required by `control.lua`.

**Storage keys:** `storage.assemblers` `{[unit_number] = {asm, lab, last_finished}}`, `storage.asm_index` (array), `storage.asm_rr_pos`.

**Recipe switching sequence** (called from `M.update_recipes`):

| Step | Function | Purpose |
|------|----------|---------|
| 1 | `rescue_in_progress(asm, needed)` | Mid-craft items NOT in new recipe → trash (items in new recipe are auto-returned by engine on `set_recipe`) |
| 2 | `flush_obsolete(asm, lab, needed)` | Input non-needed → trash; all output → trash; hidden lab input → trash |
| 3 | `asm.set_recipe(recipe_name)` | Engine updates input/output filters; auto-returns in-progress matching-recipe items |
| 4 | `recover_from_trash(asm, needed, results)` | Trash → input (ingredients); trash → output (results) |

**Key behaviours discovered:**
- `set_recipe` **deletes** input items not matching the new recipe — must flush first
- `set_recipe` **returns** in-progress items to input only if they match the new recipe — rescue only the rest
- `LuaInventory.get_contents()` returns `ItemCountWithQuality[]` (use `.name`, `.count`)
- `entity.crafting_progress` > 0 means ingredients have been consumed from input

**Event hooks (control.lua):**

| Event | Handler |
|-------|---------|
| `on_init` | ensure globals, scan all surfaces, `worldgen.on_init()`, `abandoned_ruins.register()` |
| `on_load` | `abandoned_ruins.register()` (re-registers remote interface reference) |
| `on_configuration_changed` | rebuild assembler globals, scan surfaces, `worldgen.on_configuration_changed()` |
| `on_built_entity` + robot/script variants | `M.register` |
| `on_player_mined_entity` + robot/die/script variants | `M.remove` |
| `on_research_started/finished/cancelled` | `M.update_recipes(force)` |
| `on_chunk_generated` | `worldgen.on_chunk_generated(event)` |
| `on_cutscene_started` | records `storage.pending_cutscene_skip[player_index] = tick + 1` |
| `on_tick` (every tick) | flush pending cutscene skips (deferred by 1 tick to avoid stuck UI) |
| `on_tick` (every 10t) | `M.tick_scan()` — round-robin, budget 25 |

---

### Runtime — `scripts/worldgen.lua`

**Storage keys:** `storage.worldgen` `{starter_area_prepared: bool, starter_ruins_placed: bool}`

`storage.pending_cutscene_skip` `{[player_index] = tick}` — managed in `control.lua`; skips the vanilla intro cutscene deferred by 1 tick.

**Public functions:**

| Function | Called from | Purpose |
|----------|-------------|---------|
| `Worldgen.on_init()` | `on_init` | Applies map-gen settings, runs `prepare_starter_area` |
| `Worldgen.on_configuration_changed()` | `on_configuration_changed` | Re-applies map-gen settings; restamps missing starter area or ruin cluster |
| `Worldgen.on_chunk_generated(event)` | `on_chunk_generated` | Trims resources, places starter ruin cluster or band remnant |
| `Worldgen.apply_map_gen_settings()` | init + config changed | Dials down vanilla ore frequency/size/richness on Nauvis surface |

**`prepare_starter_area` sequence (runs once on `on_init`):**
1. `surface.request_to_generate_chunks({0,0}, 6)` + `force_generate_chunk_requests()` — pre-generate spawn region
2. Clear all vanilla resources inside `STARTER_CLEAR_AREA` (±96 tiles)
3. Stamp 4 hand-authored resource patches (iron, copper, coal, stone) with terrain correction
4. Clear blockers + correct terrain under starter ruin footprint
5. Place starter ruin cluster (`ruins.lua` entities) + biome-matched decorations
6. Place 11 guaranteed fixed remnants (`remnants.lua`)
7. `verify_starter_area` — rebuild any patch or ruin that failed placement

**Resource band trimming (per chunk on `on_chunk_generated`):**

| Band | Distance (chunks) | Keep chance | Amount scale |
|------|-------------------|-------------|--------------|
| bootstrap | ≤ 7 | 45 % | 28 % |
| marginal | ≤ 18 | 35 % | 22 % |
| contested | ≤ 36 | 55 % | 40 % |
| strategic | > 36 | 75 % | 62 % |

Roll is deterministic (`math.sin` hash of position + per-resource salt). Amounts are floored at per-resource minimums so fields feel disappointing, not deleted.

**Probabilistic band remnants:** 42 % chance per chunk at distance 3–48 chunks; picks one of 12 templates from `remnants.lua` deterministically by chunk position.

---

## Planned Milestones

Full detail in `docs/milestones.md`. Summary:

| Milestone | Description                                      | Status      |
|-----------|--------------------------------------------------|-------------|
| M1        | Empty skeleton, mod loads                        | ✅ Done     |
| —         | Research assembler + scrap system                | ✅ Done     |
| M2        | Core items, recipe categories, tech tree stubs   | pending     |
| M3        | T1 Recycler entity (burner, coal-fueled)         | pending     |
| M4        | Resource scarcity startup setting + ore scaling  | pending     |
| M5        | Scrap drop on entity death                       | pending     |
| M6        | Ruins generator on chunk generation              | pending     |
| M7        | Planet prototypes (Space Age guard)              | pending     |
| M8        | T2–T4 Recycler entities                          | pending     |
| M9        | Global resource tracker + remote interface       | pending     |
| M10       | Story layer: log items in ruin loot              | pending     |

---

## Factorio 2.0 API Notes

- Use `storage.*` for persistent runtime state (`global` was renamed in 2.0).
- `data:extend({...})` in data stage only; never in control stage.
- `collision_mask = {layers = {}}` — empty layers table makes entity non-collidable.
- `hidden` is a standalone boolean field on prototypes, **not** an entity flag.
- `entity.destructible = false` prevents damage; entity can still be `.destroy()`ed by script.
- `surface.spill_item_stack(pos, stack, enable_looted, force, allow_belts)` — pass `false` as fifth arg to prevent items landing on belts.
- `LuaInventory.get_contents()` returns `ItemCountWithQuality[]` array, not `{[name]=count}`.
- `entity.get_inventory(defines.inventory.lab_input)` — lab input slot.
- `entity.get_inventory(defines.inventory.crafter_input/output/trash)` — assembler slots.
- Localised string tables have a **20-parameter limit**; nest sub-tables for longer strings.
- `data.raw["some-type"]` can be `nil` if no prototype of that type exists yet — guard with `and` before indexing.

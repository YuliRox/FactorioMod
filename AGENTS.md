# second_engineer — Factorio Mod

## Project Overview

Hardcore survival mod for Factorio 2.0. The player arrives as the *second* engineer on a planet already stripped by the first. Progression relies on recycling destroyed entities, salvaging ruins, and circular economics rather than infinite ore extraction.

## Repository Layout

```
C:/Code/FactorioMod/
├── CLAUDE.md                    -- this file
├── docs/
│   └── milestones.md            -- full development roadmap (M1–M10)
└── second_engineer/             -- the mod root (this is what Factorio loads)
    ├── info.json
    ├── changelog.txt
    ├── data.lua                 -- data stage entry point
    ├── control.lua              -- runtime script entry point
    └── locale/
        └── en/
            └── second_engineer.cfg
```

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

### data.lua — Science Pack Scrap Items

Seven coloured scrap items, one per science pack tier. Each reuses the corresponding pack's icon.

| Item name      | Source pack                  | Stack size |
|----------------|------------------------------|------------|
| `scrap-red`    | automation-science-pack      | 200        |
| `scrap-green`  | logistic-science-pack        | 200        |
| `scrap-black`  | military-science-pack        | 200        |
| `scrap-blue`   | chemical-science-pack        | 200        |
| `scrap-purple` | production-science-pack      | 200        |
| `scrap-yellow` | utility-science-pack         | 200        |
| `scrap-white`  | space-science-pack           | 200        |

All items use subgroup `intermediate-product`, order `z[scrap]-<name>`.

**`lab-scrap-output` container entity** — an invisible, indestructible, collision-free container (48 slots) spawned at each lab's position. Used as the output buffer for scrap produced by that lab. Flags: `placeable-off-grid`, `not-on-map`, `not-blueprintable`, `not-deconstructable`, `hidden`. `selectable_in_game = true` for debug purposes.

### control.lua — Lab Scrap System

Labs consume science packs. This system detects how many packs were consumed each scan cycle and produces coloured scrap into the lab's output container.

**Constants:**

| Name            | Value | Purpose                              |
|-----------------|-------|--------------------------------------|
| `SCAN_INTERVAL` | 10    | Ticks between scan cycles            |
| `SCAN_BUDGET`   | 25    | Max labs processed per scan cycle    |

**Scrap yield per pack consumed (`SCRAP_PER_PACK`):**

| Pack                     | Scrap per consumed pack |
|--------------------------|-------------------------|
| automation / logistic    | 1                       |
| military / chemical      | 2                       |
| production / utility     | 3                       |
| space                    | 4                       |

**Global state (`global.*`):**

| Key          | Type                      | Description                                      |
|--------------|---------------------------|--------------------------------------------------|
| `labs`       | `{[unit_number] = entry}` | Map from lab unit_number to tracking entry       |
| `lab_index`  | `number[]`                | Ordered array of unit_numbers for round-robin    |
| `rr_pos`     | `number`                  | Current position in `lab_index`                  |

Each entry: `{ lab = LuaEntity, out = LuaEntity, last = {pack_name -> count} }`

**Key functions:**

- `ensure_globals()` — initialises global tables if missing (called at every entry point)
- `register_lab(lab)` — adds a lab to tracking; spawns its `lab-scrap-output` entity
- `remove_lab_by_unit(unit_number)` — removes lab from tracking; spills output buffer contents; destroys output entity
- `snapshot_lab_input(lab)` — returns `{pack_name -> current_count}` for all tracked pack types
- `process_lab(entry)` — diffs current vs last inventory, computes scrap, inserts into output buffer (spills on overflow); returns `false` if lab is gone
- `safe_insert_or_spill(surface, pos, force, out_entity, name, count)` — inserts into output entity, spills remainder on ground

**Event hooks:**

| Event                       | Handler       | Purpose                        |
|-----------------------------|---------------|--------------------------------|
| `on_init`                   | —             | Scan all surfaces for labs     |
| `on_configuration_changed`  | —             | Full rescan after mod update   |
| `on_built_entity`           | `on_built`    | Register newly placed labs     |
| `on_robot_built_entity`     | `on_built`    | Register robot-placed labs     |
| `script_raised_built`       | `on_built`    | Register script-placed labs    |
| `script_raised_revive`      | `on_built`    | Register revived labs          |
| `on_player_mined_entity`    | `on_removed`  | Deregister mined labs          |
| `on_robot_mined_entity`     | `on_removed`  | Deregister robot-mined labs    |
| `on_entity_died`            | `on_removed`  | Deregister destroyed labs      |
| `script_raised_destroy`     | `on_removed`  | Deregister script-destroyed    |
| `on_tick`                   | round-robin   | Scan up to 25 labs every 10t   |

---

## Planned Milestones

Full detail in `docs/milestones.md`. Summary:

| Milestone | Description                                      | Status      |
|-----------|--------------------------------------------------|-------------|
| M1        | Empty skeleton, mod loads                        | ✅ Done     |
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

- Use `storage.*` for persistent runtime state (serialised with the save). `storage` was renamed to `storage` in Factorio 2.0.
- `data:extend({...})` in data stage; never in control stage.
- `surface.spill_item_stack(pos, stack, enable_looted, force, allow_belts)` — fifth arg `false` prevents items landing on belts.
- `entity.get_inventory(defines.inventory.lab_input)` — lab input slot.
- `entity.get_inventory(defines.inventory.chest)` — generic container slot.
- `collision_mask = {}` makes an entity non-collidable with everything.
- Entity flags `"not-on-map"`, `"not-blueprintable"`, `"not-deconstructable"` keep internal entities invisible to the player. `hidden` is a standalone boolean field on the prototype in 2.0, not a flag.
- `out.destructible = false` prevents damage but entity can still be `.destroy()`ed by script.

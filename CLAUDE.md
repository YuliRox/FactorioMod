# second_engineer — Factorio Mod

## Project Overview

Hardcore survival mod for Factorio 2.0. The player arrives as the *second* engineer on a planet already stripped by the first. Progression relies on recycling destroyed entities, salvaging ruins, and circular economics rather than infinite ore extraction.

## Repository Layout

The mod folder is `second_engineer/` during development. When distributed as a `.zip` the folder inside **must** be named `second_engineer_0.1.0/` (name + underscore + version).

Data stage load order: `settings.lua` → `settings-updates.lua` → `settings-final-fixes.lua` → `data.lua` → `data-updates.lua` → `data-final-fixes.lua`.

```
CLAUDE.md
second_engineer/                       -- the mod itself
  info.json                            -- required: name, version, author, dependencies
  changelog.txt
  thumbnail.png
  data.lua                             -- data stage entry point
  data-updates.lua                     -- patches existing prototypes; AbandonedRuins hook
  data-final-fixes.lua                 -- hidden lab animation; dynamic recipe generation
  settings.lua                         -- [MISSING] M4 resource scarcity settings
  control.lua                          -- thin event dispatcher
  locale/en/second_engineer.cfg
  graphics/icons/scrap/                -- 12 scrap item icons (64×64 png)
  prototypes/
    entity/
      research-assembler.lua           -- assembler entity + item + recipe
      hidden-research-lab.lua          -- internal lab entity
    item/
      scraps.lua                       -- scrap items (7 base + 5 space-age)
    recipe/                            -- [MISSING] M2
    technology/                        -- [MISSING] M2
  scripts/
    research_assembler.lua             -- assembler runtime logic
    abandoned_ruins.lua                -- AbandonedRuins mod integration
    worldgen.lua                       -- Nauvis worldgen
    worldgeneration/
      ruins.lua                        -- starter ruin cluster data
      remnants.lua                     -- ambient remnant templates
      abandoned_ruins_set.lua          -- ruin set for AbandonedRuins_updated_fork

docs/
  identity.md                          -- mod name, version, author, dependencies
  hooks.md                             -- control.lua event hook registrations
  planned.md                           -- milestone status + full detail
  features/
    scrap-items.md
    research-assembler.md
    worldgen.md
  brainstorming/                       -- unstructured design notes, not authoritative
  Agenten/                             -- unstructured NPC/character research notes, not authoritative
```


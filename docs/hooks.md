# Event Hooks — `control.lua`

All runtime events are registered in `control.lua`, which delegates to the relevant script modules.

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

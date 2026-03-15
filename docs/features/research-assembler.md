# Research Assembler

The core of the science recycling loop. Each placed assembler is paired with a hidden lab entity that does the actual research; the assembler handles the crafting interface and item flow.

---

## Prototype — Research Assembler

**Source:** `prototypes/entity/research-assembler.lua`

Assembling-machine entity that looks like a lab.

- Crafting category: `se-research-crafting` (exclusive to this machine)
- 2 module slots — allowed effects: `speed`, `consumption`, `pollution`
- `trash_inventory_size = 12`, `ingredient_count = 12`
- `recipe_locked = true` always — recipe is controlled entirely by script
- Set `active = false` when idle (IDLE_RECIPE set, no research running)
- Crafting recipe mirrors the base lab recipe

---

## Prototype — Hidden Research Lab

**Source:** `prototypes/entity/hidden-research-lab.lua`

Internal `lab` entity spawned co-located with each assembler. Does the actual research.

- `collision_mask = {layers = {}}` — no collision with anything
- `energy_source = {type = "void"}` — no power draw
- `researching_speed = 10000` — completes research instantly relative to the assembler craft cycle
- 2 module slots — allowed effects: `productivity`
- `hidden = false`, `selectable_in_game = true` — **DEBUG, remove before release**
- Animation patched to green-tinted base lab sprite in `data-final-fixes.lua` — **DEBUG**

---

## Dynamic Recipe Generation

**Source:** `data-final-fixes.lua`

Runs at data-final-fixes stage. Iterates `data.raw.technology`, collects every unique sorted science-pack combination used across all technologies, and generates one hidden recipe per combination.

- Recipe names follow the pattern `se-research-<sorted-pack-shorts>` (e.g. `se-research-red-green`)
- `localised_name` is built from `item-name.*` locale keys via nested localised strings, chunked to ≤9 entries per sub-table to stay within Factorio's 20-parameter limit
- `se-research-idle`: no ingredients/results, `energy_required = 60` — used when no research is active

---

## data-updates.lua patches

- Sets `trash_inventory_size = 13` on all lab prototypes (12 scrap slots + 1 spoilage slot)
- If `AbandonedRuins_updated_fork` is loaded: appends `"second-engineer"` to the `current-ruin-set` string-setting's allowed values. Guards against nil with `data.raw["string-setting"] and …`

---

## Runtime — `scripts/research_assembler.lua`

All assembler logic lives in module `M`, required by `control.lua`.

### Storage keys

| Key | Type | Description |
|-----|------|-------------|
| `storage.assemblers` | `{[unit_number] = {asm, lab, last_finished}}` | Registered assembler–lab pairs |
| `storage.asm_index` | array of unit_numbers | Ordered list for round-robin scan |
| `storage.asm_rr_pos` | number | Current round-robin position in `asm_index` |

### Recipe switching sequence

Called from `M.update_recipes(force)` whenever research starts, finishes, or is cancelled.

| Step | Function | Purpose |
|------|----------|---------|
| 1 | `rescue_in_progress(asm, needed)` | Mid-craft items **not** in the new recipe → trash. Items matching the new recipe are auto-returned by the engine on `set_recipe` and do not need rescuing. |
| 2 | `flush_obsolete(asm, lab, needed)` | Non-needed items from input → trash; all output → trash; hidden lab input → trash |
| 3 | `asm.set_recipe(recipe_name)` | Engine updates input/output filters and auto-returns any in-progress items that match the new recipe |
| 4 | `recover_from_trash(asm, needed, results)` | Trash → input (ingredients); trash → output (results) |

### Key behaviours

- `set_recipe` **deletes** input items not matching the new recipe — flush before calling
- `set_recipe` **returns** in-progress items to input only if they match the new recipe — rescue only the rest beforehand
- `LuaInventory.get_contents()` returns `ItemCountWithQuality[]` — use `.name` and `.count`, not string keys
- `entity.crafting_progress > 0` means ingredients have already been consumed from input

-- scripts/research_assembler.lua
-- Tracks se-research-assembler entities, manages their hidden internal lab,
-- switches recipes when research changes, and feeds consumed packs to the lab.
-- Also manages a hidden speed beacon per assembler that mirrors the force's
-- accumulated laboratory-speed technology bonus.

local M = {}

-- ── Constants ────────────────────────────────────────────────────────────────

local PACK_TO_SCRAP = require("shared.pack_to_scrap")

local SCAN_BUDGET          = 25
local IDLE_RECIPE          = "se-research-idle"
local BEACON_NAME          = "se-research-speed-beacon"
local SPEED_MODULE_NAME    = "se-research-speed-module"
local BEACON_SYNC_INTERVAL = 600  -- tick_scan calls between full beacon syncs (~100 s)

-- ── Storage ───────────────────────────────────────────────────────────────────

function M.ensure_globals()
  storage.assemblers            = storage.assemblers            or {}
  storage.asm_index             = storage.asm_index             or {}
  storage.asm_rr_pos            = storage.asm_rr_pos            or 1
  storage.beacon_sync_countdown = storage.beacon_sync_countdown or BEACON_SYNC_INTERVAL
end

-- ── Entity check ─────────────────────────────────────────────────────────────

function M.is_assembler(entity)
  return entity and entity.valid and entity.name == "se-research-assembler"
end

-- ── Recipe name helpers ───────────────────────────────────────────────────────

local function pack_short(name)
  return (name:gsub("%-science%-pack$", ""))
end

local function get_research_recipe_name(force)
  if not force then return IDLE_RECIPE end
  local tech = force.current_research
  if not tech then return IDLE_RECIPE end
  local packs = {}
  for _, ing in pairs(tech.research_unit_ingredients) do
    if PACK_TO_SCRAP[ing.name] then
      table.insert(packs, ing.name)
    end
  end
  if #packs == 0 then return IDLE_RECIPE end
  table.sort(packs)
  local parts = {}
  for _, p in ipairs(packs) do table.insert(parts, pack_short(p)) end
  return "se-research-" .. table.concat(parts, "-")
end

-- ── Hidden lab ────────────────────────────────────────────────────────────────

local function create_hidden_lab(asm)
  local lab = asm.surface.create_entity{
    name     = "se-hidden-research-lab",
    position = asm.position,
    force    = asm.force,
  }
  if lab and lab.valid then
    lab.destructible = false
    return lab
  end
  return nil
end

-- ── Hidden speed beacon ───────────────────────────────────────────────────────

local function create_hidden_beacon(asm)
  local beacon = asm.surface.create_entity{
    name     = BEACON_NAME,
    position = asm.position,
    force    = asm.force,
  }
  if beacon and beacon.valid then
    beacon.destructible = false
    return beacon
  end
  return nil
end

-- Sum all laboratory-speed modifiers from researched technologies, then express
-- that total as a whole number of se-research-speed-modules (each worth the
-- average per-level bonus set in data-final-fixes). Using the actual sum rather
-- than a simple level count stays correct when tech levels carry unequal modifiers.
local function get_research_speed_level(force)
  local total = 0.0
  for _, tech in pairs(force.technologies) do
    if tech.researched then
      for _, effect in pairs(tech.prototype.effects or {}) do
        if effect.type == "laboratory-speed" then
          total = total + (effect.modifier or 0)
          break  -- count each tech's contribution once
        end
      end
    end
  end
  local per_module = prototypes.item[SPEED_MODULE_NAME].module_effects.speed
  if per_module <= 0 then return 0 end
  return math.floor(total / per_module + 0.5)
end

local function sync_beacon_modules(entry)
  local beacon = entry.beacon
  if not (beacon and beacon.valid) then
    if entry.asm and entry.asm.valid then
      entry.beacon = create_hidden_beacon(entry.asm)
      beacon = entry.beacon
    end
  end
  if not (beacon and beacon.valid) then return end

  local level = get_research_speed_level(entry.asm.force)
  local inv   = beacon.get_module_inventory()
  if not inv then return end

  inv.clear()
  if level > 0 then
    inv.insert{ name = SPEED_MODULE_NAME, count = level }
  end
end

function M.sync_beacons(force)
  M.ensure_globals()
  for _, entry in pairs(storage.assemblers) do
    if entry.asm and entry.asm.valid and entry.asm.force == force then
      sync_beacon_modules(entry)
    end
  end
end

-- ── Input flushing ────────────────────────────────────────────────────────────

local function build_recipe_sets(recipe_name)
  local needed  = {}
  local results = {}
  local proto = recipe_name and prototypes.recipe[recipe_name]
  if proto then
    for _, ing in pairs(proto.ingredients) do
      needed[ing.name] = true
    end
    for _, res in pairs(proto.products) do
      results[res.name] = true
    end
  end
  return needed, results
end

-- Step 0: if the assembler is mid-craft, the in-progress ingredients are no
-- longer in any inventory. Rescue them into trash before set_recipe discards them.
-- Only rescue ingredients that are NOT in the new recipe. Items that ARE in the
-- new recipe are returned to input automatically by the engine on set_recipe.
local function rescue_in_progress(asm, needed)
  if asm.crafting_progress <= 0 then return end
  local recipe = asm.get_recipe()
  if not recipe then return end
  local trash = asm.get_inventory(defines.inventory.crafter_trash)
  if not trash then return end
  for _, ing in pairs(recipe.ingredients) do
    if not needed[ing.name] then
      local n = trash.insert{name=ing.name, count=ing.amount}
      local remaining = ing.amount - n
      if remaining > 0 then
        asm.surface.spill_item_stack(
          asm.position, {name=ing.name, count=remaining}, true, asm.force, false)
      end
    end
  end
end

-- Step 1 (before set_recipe): move obsolete items input→trash, all output→trash,
-- and drain the hidden lab. Must run before set_recipe so nothing gets deleted.
local function flush_obsolete(asm, lab, needed)
  local input  = asm.get_inventory(defines.inventory.crafter_input)
  local output = asm.get_inventory(defines.inventory.crafter_output)
  local trash  = asm.get_inventory(defines.inventory.crafter_trash)
  if not (input and trash) then return end

  for _, stack in pairs(input.get_contents()) do
    if not needed[stack.name] then
      local n = trash.insert{name=stack.name, count=stack.count}
      if n > 0 then input.remove{name=stack.name, count=n} end
    end
  end

  if output then
    for _, stack in pairs(output.get_contents()) do
      local n = trash.insert{name=stack.name, count=stack.count}
      if n > 0 then output.remove{name=stack.name, count=n} end
    end
  end

  -- Note: lab_input is intentionally NOT flushed. Packs already inserted there
  -- have already generated scrap; draining them on recipe switch would be a
  -- double-reward. The lab drains its own inventory naturally via research.
end

-- Step 2 (after set_recipe): pull items back from trash into input (ingredients)
-- or output (results) now that both filters match the new recipe.
local function recover_from_trash(asm, needed, results)
  local input  = asm.get_inventory(defines.inventory.crafter_input)
  local output = asm.get_inventory(defines.inventory.crafter_output)
  local trash  = asm.get_inventory(defines.inventory.crafter_trash)
  if not (input and trash) then return end

  for _, stack in pairs(trash.get_contents()) do
    if needed[stack.name] then
      local n = input.insert{name=stack.name, count=stack.count}
      if n > 0 then trash.remove{name=stack.name, count=n} end
    elseif output and results[stack.name] then
      local n = output.insert{name=stack.name, count=stack.count}
      if n > 0 then trash.remove{name=stack.name, count=n} end
    end
  end
end

local process_assembler  -- forward declaration; defined in Per-tick processing section below

-- ── Registration ─────────────────────────────────────────────────────────────

function M.register(asm)
  M.ensure_globals()
  local u = asm.unit_number
  if not u then return end
  if storage.assemblers[u] and storage.assemblers[u].asm and storage.assemblers[u].asm.valid then return end

  local hidden_lab    = create_hidden_lab(asm)
  local hidden_beacon = create_hidden_beacon(asm)
  local recipe_name   = get_research_recipe_name(asm.force)
  asm.set_recipe(recipe_name)
  asm.recipe_locked = true
  asm.active = recipe_name ~= IDLE_RECIPE

  storage.assemblers[u] = {asm=asm, lab=hidden_lab, beacon=hidden_beacon, last_finished=asm.products_finished}
  table.insert(storage.asm_index, u)
  sync_beacon_modules(storage.assemblers[u])
end

function M.remove(unit_number)
  M.ensure_globals()
  local entry = storage.assemblers[unit_number]
  if entry then
    if entry.lab and entry.lab.valid then
      entry.lab.destroy()
    end
    if entry.beacon and entry.beacon.valid then
      entry.beacon.destroy()
    end
  end
  storage.assemblers[unit_number] = nil
  for i = #storage.asm_index, 1, -1 do
    if storage.asm_index[i] == unit_number then
      table.remove(storage.asm_index, i)
      if storage.asm_rr_pos > i then storage.asm_rr_pos = storage.asm_rr_pos - 1 end
      break
    end
  end
  if storage.asm_rr_pos < 1 then storage.asm_rr_pos = 1 end
  if storage.asm_rr_pos > #storage.asm_index then storage.asm_rr_pos = 1 end
end

-- ── Recipe updates ────────────────────────────────────────────────────────────

function M.update_recipes(force)
  M.ensure_globals()
  local recipe_name    = get_research_recipe_name(force)
  local needed, results = build_recipe_sets(recipe_name)
  for _, entry in pairs(storage.assemblers) do
    if entry.asm and entry.asm.valid and entry.asm.force == force then
      process_assembler(entry)                            -- credit any crafts finished since last tick_scan
      rescue_in_progress(entry.asm, needed)               -- save mid-craft ingredients not in new recipe to trash
      flush_obsolete(entry.asm, entry.lab, needed)       -- protect items before filter changes
      entry.asm.set_recipe(recipe_name)                  -- update input/output filter
      recover_from_trash(entry.asm, needed, results)     -- pull back items now filters accept them
      entry.asm.recipe_locked = true
      entry.asm.active = recipe_name ~= IDLE_RECIPE
      entry.last_finished = entry.asm.products_finished  -- reset baseline so tick_scan doesn't count pre-switch crafts
    end
  end
end

-- ── Per-tick processing ───────────────────────────────────────────────────────

process_assembler = function(entry)
  local asm = entry.asm
  if not (asm and asm.valid) then return false end

  if not (entry.lab and entry.lab.valid) then
    entry.lab = create_hidden_lab(asm)
  end

  if not (entry.beacon and entry.beacon.valid) then
    entry.beacon = create_hidden_beacon(asm)
    if entry.beacon then sync_beacon_modules(entry) end
  end

  local now_finished  = asm.products_finished
  local prev_finished = entry.last_finished or now_finished
  local crafts        = now_finished - prev_finished
  entry.last_finished = now_finished

  if crafts > 0 then
    local recipe = asm.get_recipe()
    if recipe and entry.lab and entry.lab.valid then
      for _, ing in pairs(recipe.ingredients) do
        if PACK_TO_SCRAP[ing.name] then
          entry.lab.insert{name=ing.name, count=ing.amount * crafts}
        end
      end
    end
  end

  return true
end

function M.tick_scan()
  M.ensure_globals()
  local index = storage.asm_index
  local map   = storage.assemblers
  local n     = #index
  if n == 0 then return end

  local start     = storage.asm_rr_pos
  local processed = 0

  while processed < SCAN_BUDGET and n > 0 do
    if storage.asm_rr_pos > n then storage.asm_rr_pos = 1 end
    local unit  = index[storage.asm_rr_pos]
    local entry = unit and map[unit]

    if entry then
      if not process_assembler(entry) then
        map[unit] = nil
        table.remove(index, storage.asm_rr_pos)
        n = #index
      else
        storage.asm_rr_pos = storage.asm_rr_pos + 1
      end
    else
      table.remove(index, storage.asm_rr_pos)
      n = #index
    end

    processed = processed + 1
    if n == 0 then break end
    if storage.asm_rr_pos == start then break end
  end

  -- Periodic beacon sync: catches edge cases not covered by on_research_finished
  storage.beacon_sync_countdown = storage.beacon_sync_countdown - 1
  if storage.beacon_sync_countdown <= 0 then
    storage.beacon_sync_countdown = BEACON_SYNC_INTERVAL
    local synced_forces = {}
    for _, entry in pairs(storage.assemblers) do
      if entry.asm and entry.asm.valid then
        local fname = entry.asm.force.name
        if not synced_forces[fname] then
          synced_forces[fname] = true
          M.sync_beacons(entry.asm.force)
        end
      end
    end
  end
end

-- ── Surface scan (init / config change) ──────────────────────────────────────

function M.scan_all_surfaces()
  for _, surface in pairs(game.surfaces) do
    for _, asm in pairs(surface.find_entities_filtered{name="se-research-assembler"}) do
      M.register(asm)
    end
  end
end

function M.destroy_all_hidden_labs()
  for _, surface in pairs(game.surfaces) do
    for _, lab in pairs(surface.find_entities_filtered{name="se-hidden-research-lab"}) do
      lab.destroy()
    end
  end
end

function M.destroy_all_hidden_beacons()
  for _, surface in pairs(game.surfaces) do
    for _, beacon in pairs(surface.find_entities_filtered{name=BEACON_NAME}) do
      beacon.destroy()
    end
  end
end

return M

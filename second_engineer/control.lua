-- second_engineer: runtime script entry point
local worldgen = require("scripts.worldgen")

local PACK_TO_SCRAP = {
  ["automation-science-pack"] = "scrap-red",
  ["logistic-science-pack"]   = "scrap-green",
  ["military-science-pack"]   = "scrap-black",
  ["chemical-science-pack"]   = "scrap-blue",
  ["production-science-pack"] = "scrap-purple",
  ["utility-science-pack"]    = "scrap-yellow",
  ["space-science-pack"]      = "scrap-white",
}

if script.active_mods["space-age"] then
  PACK_TO_SCRAP["metallurgic-science-pack"]    = "scrap-metallurgic"
  PACK_TO_SCRAP["electromagnetic-science-pack"] = "scrap-electromagnetic"
  PACK_TO_SCRAP["agricultural-science-pack"]   = "scrap-agricultural"
  PACK_TO_SCRAP["cryogenic-science-pack"]      = "scrap-cryogenic"
  PACK_TO_SCRAP["promethium-science-pack"]     = "scrap-promethium"
end

local SCRAP_PER_PACK = {
  ["automation-science-pack"]    = 1,
  ["logistic-science-pack"]      = 1,
  ["military-science-pack"]      = 2,
  ["chemical-science-pack"]      = 2,
  ["production-science-pack"]    = 3,
  ["utility-science-pack"]       = 3,
  ["space-science-pack"]         = 4,
  ["metallurgic-science-pack"]   = 5,
  ["electromagnetic-science-pack"] = 5,
  ["agricultural-science-pack"]  = 5,
  ["cryogenic-science-pack"]     = 6,
  ["promethium-science-pack"]    = 8,
}

local SCAN_INTERVAL = 10  -- ticks between scan cycles
local SCAN_BUDGET   = 25  -- max labs processed per cycle

local function is_lab(entity)
  return entity and entity.valid and entity.type == "lab"
end

local function skip_intro_cutscene(player)
  if not (player and player.valid) then return end
  if player.controller_type ~= defines.controllers.cutscene then return end

  -- Design decision: this scenario starts with immediate resource pressure and
  -- authored starter terrain, so the vanilla intro cutscene only delays the
  -- player from interacting with the world we just prepared.
  player.exit_cutscene()
end

local function ensure_globals()
  storage.labs      = storage.labs      or {}  -- [unit_number] = {lab=LuaEntity, last={pack->count}}
  storage.lab_index = storage.lab_index or {}  -- ordered array of unit_numbers for round-robin
  storage.rr_pos    = storage.rr_pos    or 1
end

local function snapshot_lab_input(lab)
  local inv = lab.get_inventory(defines.inventory.lab_input)
  local snap = {}
  if not inv then return snap end
  for pack_name in pairs(PACK_TO_SCRAP) do
    snap[pack_name] = inv.get_item_count(pack_name)
  end
  return snap
end

local function register_lab(lab)
  ensure_globals()
  local u = lab.unit_number
  if not u then return end
  if storage.labs[u] and storage.labs[u].lab and storage.labs[u].lab.valid then return end
  storage.labs[u] = {
    lab  = lab,
    last = snapshot_lab_input(lab),
  }
  table.insert(storage.lab_index, u)
end

local function remove_lab_by_unit(unit_number)
  ensure_globals()
  storage.labs[unit_number] = nil
  for i = #storage.lab_index, 1, -1 do
    if storage.lab_index[i] == unit_number then
      table.remove(storage.lab_index, i)
      if storage.rr_pos > i then storage.rr_pos = storage.rr_pos - 1 end
      break
    end
  end
  if storage.rr_pos < 1 then storage.rr_pos = 1 end
  if storage.rr_pos > #storage.lab_index then storage.rr_pos = 1 end
end

local function safe_insert_or_spill(surface, pos, force, inv, name, count)
  if count <= 0 then return end
  if inv then
    local inserted = inv.insert{name=name, count=count}
    local left = count - inserted
    if left > 0 then
      surface.spill_item_stack(pos, {name=name, count=left}, true, force, false)
    end
  else
    surface.spill_item_stack(pos, {name=name, count=count}, true, force, false)
  end
end

local function process_lab(entry)
  local lab = entry.lab
  if not (lab and lab.valid) then return false end

  local inv = lab.get_inventory(defines.inventory.lab_input)
  if not inv then
    entry.last = entry.last or {}
    return true
  end

  local trash = lab.get_inventory(defines.inventory.lab_trash)
  local last  = entry.last or {}

  for pack_name, scrap_name in pairs(PACK_TO_SCRAP) do
    local now  = inv.get_item_count(pack_name)
    local prev = last[pack_name] or 0
    if now < prev then
      local consumed = prev - now
      local per = SCRAP_PER_PACK[pack_name] or 1
      safe_insert_or_spill(lab.surface, lab.position, lab.force, trash, scrap_name, consumed * per)
    end
    last[pack_name] = now
  end

  entry.last = last
  return true
end

-- Events: init/load
script.on_init(function()
  ensure_globals()
  worldgen.on_init()
  for _, surface in pairs(game.surfaces) do
    for _, lab in pairs(surface.find_entities_filtered{type="lab"}) do
      register_lab(lab)
    end
  end
end)

script.on_configuration_changed(function()
  ensure_globals()
  worldgen.on_configuration_changed()
  storage.labs      = {}
  storage.lab_index = {}
  storage.rr_pos    = 1
  for _, surface in pairs(game.surfaces) do
    for _, lab in pairs(surface.find_entities_filtered{type="lab"}) do
      register_lab(lab)
    end
  end
end)

-- Build hooks
local function on_built(event)
  local ent = event.created_entity or event.entity
  if is_lab(ent) then register_lab(ent) end
end

script.on_event(defines.events.on_built_entity,     on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_built, on_built)
script.on_event(defines.events.script_raised_revive, on_built)

-- Remove hooks
local function on_removed(event)
  local ent = event.entity
  if is_lab(ent) and ent.unit_number then
    remove_lab_by_unit(ent.unit_number)
  end
end

script.on_event(defines.events.on_player_mined_entity, on_removed)
script.on_event(defines.events.on_robot_mined_entity,  on_removed)
script.on_event(defines.events.on_entity_died,         on_removed)
script.on_event(defines.events.script_raised_destroy,  on_removed)
script.on_event(defines.events.on_chunk_generated, worldgen.on_chunk_generated)
script.on_event(defines.events.on_cutscene_started, function(event)
  skip_intro_cutscene(game.get_player(event.player_index))
end)

-- Periodic round-robin scan
script.on_event(defines.events.on_tick, function(event)
  if (event.tick % SCAN_INTERVAL) ~= 0 then return end
  ensure_globals()

  local n = #storage.lab_index
  if n == 0 then return end

  local start     = storage.rr_pos
  local processed = 0

  while processed < SCAN_BUDGET and n > 0 do
    if storage.rr_pos > n then storage.rr_pos = 1 end
    local unit  = storage.lab_index[storage.rr_pos]
    local entry = unit and storage.labs[unit]

    if entry then
      local ok = process_lab(entry)
      if not ok then
        remove_lab_by_unit(unit)
        n = #storage.lab_index
      else
        storage.rr_pos = storage.rr_pos + 1
      end
    else
      -- stale index
      table.remove(storage.lab_index, storage.rr_pos)
      n = #storage.lab_index
    end

    processed = processed + 1
    if n == 0 then break end
    if storage.rr_pos == start then break end
  end
end)

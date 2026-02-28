-- second_engineer: runtime script entry point
local ResearchAssembler = require("scripts.research_assembler")
local abandoned_ruins = require("scripts.abandoned_ruins")
local worldgen = require("scripts.worldgen")

local SCAN_INTERVAL = 10  -- ticks between scan cycles

local function skip_intro_cutscene(player)
  if not (player and player.valid) then return end
  if player.controller_type ~= defines.controllers.cutscene then return end

  -- Design decision: this scenario starts with immediate resource pressure and
  -- authored starter terrain, so the vanilla intro cutscene only delays the
  -- player from interacting with the world we just prepared.
  player.exit_cutscene()
end

local function ensure_globals()
  storage.pending_cutscene_skip = storage.pending_cutscene_skip or {}
end

-- Events: init/load

-- ── Init / config change ──────────────────────────────────────────────────────

script.on_init(function()
  ensure_globals()
  ResearchAssembler.ensure_globals()
  ResearchAssembler.scan_all_surfaces()
  abandoned_ruins.register()
  worldgen.on_init()
end)

script.on_load(function()
  abandoned_ruins.register()
end)

script.on_configuration_changed(function()
  ResearchAssembler.destroy_all_hidden_labs()
  ResearchAssembler.ensure_globals()
  abandoned_ruins.register()
  worldgen.on_configuration_changed()
  storage.assemblers = {}
  storage.asm_index  = {}
  storage.asm_rr_pos = 1
  ResearchAssembler.scan_all_surfaces()
end)

-- ── Build / remove hooks ──────────────────────────────────────────────────────

local function on_built(event)
  local ent = event.created_entity or event.entity
  if ResearchAssembler.is_assembler(ent) then ResearchAssembler.register(ent) end
end

script.on_event(defines.events.on_built_entity,       on_built)
script.on_event(defines.events.on_robot_built_entity,  on_built)
script.on_event(defines.events.script_raised_built,   on_built)
script.on_event(defines.events.script_raised_revive,  on_built)

local function on_removed(event)
  local ent = event.entity
  if ResearchAssembler.is_assembler(ent) and ent.unit_number then
    ResearchAssembler.remove(ent.unit_number)
  end
end

script.on_event(defines.events.on_player_mined_entity, on_removed)
script.on_event(defines.events.on_robot_mined_entity,  on_removed)
script.on_event(defines.events.on_entity_died,         on_removed)
script.on_event(defines.events.script_raised_destroy,  on_removed)

script.on_event(defines.events.on_chunk_generated, worldgen.on_chunk_generated)
script.on_event(defines.events.on_cutscene_started, function(event)
  ensure_globals()
  -- Design decision: cancelling immediately inside on_cutscene_started can
  -- leave the vanilla "Press Tab to skip cutscene" hint stuck on screen. We
  -- defer the cancel by one tick so the engine can initialize and clean up the
  -- cutscene UI correctly.
  storage.pending_cutscene_skip[event.player_index] = game.tick + 1
end)

-- ── Research change ───────────────────────────────────────────────────────────

local function on_research_changed(event)
  local force = event.research and event.research.force
  if force then ResearchAssembler.update_recipes(force) end
end

script.on_event(defines.events.on_research_started,   on_research_changed)
script.on_event(defines.events.on_research_finished,  on_research_changed)
script.on_event(defines.events.on_research_cancelled, on_research_changed)

-- ── Periodic scan ─────────────────────────────────────────────────────────────

script.on_event(defines.events.on_tick, function(event)
  ensure_globals()
  for player_index, skip_tick in pairs(storage.pending_cutscene_skip) do
    if event.tick >= skip_tick then
      skip_intro_cutscene(game.get_player(player_index))
      storage.pending_cutscene_skip[player_index] = nil
    end
  end

  if (event.tick % SCAN_INTERVAL) ~= 0 then return end
  ResearchAssembler.tick_scan()
end)

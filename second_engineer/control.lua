-- second_engineer: runtime script entry point
local ResearchAssembler = require("scripts.research_assembler")
local abandoned_ruins = require("scripts.abandoned_ruins")
local worldgen = require("scripts.worldgen")

local SCAN_INTERVAL = 10  -- ticks between scan cycles
local LAUNCHER_MODE_SURFACE_TEST = "surface_test"
local LAUNCHER_MODE_PERIMETER_AUTHORING = "perimeter_authoring"
local LAUNCHER_SURFACE_TEST_MOISTURE_BIAS = "-2.5"
local LAUNCHER_SURFACE_TEST_AUX_BIAS = "2.0"
local LAUNCHER_PERIMETER_AUTHORING_MOISTURE_BIAS = "-3.5"
local LAUNCHER_PERIMETER_AUTHORING_AUX_BIAS = "2.5"
local SURFACE_TEST_NAME = "surface test"
local SURFACE_PERIMETER_AUTHORING_NAME = "perimeter authoring"
local DEBUG_RESET_HOTKEY = "se-debug-reset-surface-core-district"
local defer_surface_test_queue_after_load = false

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
  storage.pending_surface_test_relocate = storage.pending_surface_test_relocate or {}
  storage.pending_debug_surface_reset = storage.pending_debug_surface_reset or nil
end

local function detect_launcher_surface_mode()
  local nauvis = game.surfaces["nauvis"]
  if not nauvis then return nil end

  local expr = (nauvis.map_gen_settings and nauvis.map_gen_settings.property_expression_names) or {}
  if expr["control-setting:moisture:bias"] == LAUNCHER_SURFACE_TEST_MOISTURE_BIAS and
    expr["control-setting:aux:bias"] == LAUNCHER_SURFACE_TEST_AUX_BIAS then
    return LAUNCHER_MODE_SURFACE_TEST
  end
  if expr["control-setting:moisture:bias"] == LAUNCHER_PERIMETER_AUTHORING_MOISTURE_BIAS and
    expr["control-setting:aux:bias"] == LAUNCHER_PERIMETER_AUTHORING_AUX_BIAS then
    return LAUNCHER_MODE_PERIMETER_AUTHORING
  end
  return nil
end

local function launcher_surface_name(mode)
  if mode == LAUNCHER_MODE_PERIMETER_AUTHORING then
    return SURFACE_PERIMETER_AUTHORING_NAME
  end
  if mode == LAUNCHER_MODE_SURFACE_TEST then
    return SURFACE_TEST_NAME
  end
  return nil
end

local function maybe_prepare_surface_test()
  if storage.surface_test_mode == nil then
    storage.surface_test_mode = detect_launcher_surface_mode()
  end
  if not storage.surface_test_mode then return nil end
  if storage.surface_test_mode == LAUNCHER_MODE_PERIMETER_AUTHORING then
    return worldgen.ensure_perimeter_authoring_surface()
  end
  return worldgen.ensure_surface_test()
end

local function maybe_move_player_to_surface_test(player)
  if not (player and player.valid) then return end
  local surface = maybe_prepare_surface_test()
  if not (surface and surface.valid) then return end

  local report = worldgen.debug_get_last_core_layout_report()
  local target = report and report.anchor
  if not target then
    target = report and report.blocks and report.blocks.central_district and report.blocks.central_district.anchor
  end
  if not target then
    target = {x = 0, y = 0}
  end

  local safe = surface.find_non_colliding_position("character", target, 32, 0.5) or target
  player.teleport(safe, surface)
  player.force.chart(surface, {
    left_top = {x = safe.x - 128, y = safe.y - 128},
    right_bottom = {x = safe.x + 128, y = safe.y + 128},
  })
end

local function move_all_players_to_surface_test()
  for _, player in pairs(game.players) do
    maybe_move_player_to_surface_test(player)
  end
end

local function queue_surface_test_move(player_index, delay_ticks)
  ensure_globals()
  if not storage.surface_test_mode then return end
  storage.pending_surface_test_relocate[player_index] = game.tick + (delay_ticks or 60)
end

local function queue_all_players_surface_test_move(delay_ticks)
  for _, player in pairs(game.players) do
    queue_surface_test_move(player.index, delay_ticks)
  end
end

local function rebuild_research_assembler_state()
  ResearchAssembler.destroy_all_hidden_labs()
  ResearchAssembler.ensure_globals()
  storage.assemblers = {}
  storage.asm_index = {}
  storage.asm_rr_pos = 1
  ResearchAssembler.scan_all_surfaces()
end

local function run_pending_debug_surface_reset()
  ensure_globals()
  local pending = storage.pending_debug_surface_reset
  if not pending then return end

  storage.pending_debug_surface_reset = nil

  local surface = pending.surface_name and game.surfaces[pending.surface_name] or nil
  if not (surface and surface.valid) then
    if pending.player_index then
      local player = game.get_player(pending.player_index)
      if player and player.valid then
        player.print("second_engineer: debug reset skipped (target surface no longer exists).")
      end
    end
    return
  end

  local include_defense = surface.name ~= SURFACE_PERIMETER_AUTHORING_NAME
  local report = worldgen.debug_reset_surface_for_core_district(surface, {
    include_defense = include_defense,
  })
  rebuild_research_assembler_state()

  local player = pending.player_index and game.get_player(pending.player_index) or nil
  if player and player.valid then
    if surface.name == SURFACE_TEST_NAME or surface.name == SURFACE_PERIMETER_AUTHORING_NAME then
      queue_surface_test_move(player.index, 15)
    end
    local destroyed = (report and report.destroyed_entities) or 0
    player.print(string.format(
      "second_engineer: debug reset finished on '%s' (destroyed entities: %d).",
      surface.name,
      destroyed
    ))
  end
end

-- Events: init/load

-- ── Init / config change ──────────────────────────────────────────────────────

script.on_init(function()
  ensure_globals()
  -- Capture launcher intent before worldgen mutates Nauvis map-gen settings.
  storage.surface_test_mode = detect_launcher_surface_mode()
  ResearchAssembler.ensure_globals()
  ResearchAssembler.scan_all_surfaces()
  abandoned_ruins.register()
  worldgen.on_init()

  move_all_players_to_surface_test()
  queue_all_players_surface_test_move(120)
end)

script.on_load(function()
  abandoned_ruins.register()
  defer_surface_test_queue_after_load = true
end)

script.on_configuration_changed(function()
  ensure_globals()
  if storage.surface_test_mode == nil then
    storage.surface_test_mode = detect_launcher_surface_mode()
  end
  ResearchAssembler.destroy_all_hidden_labs()
  ResearchAssembler.ensure_globals()
  abandoned_ruins.register()
  worldgen.on_configuration_changed()
  storage.assemblers = {}
  storage.asm_index  = {}
  storage.asm_rr_pos = 1
  ResearchAssembler.scan_all_surfaces()
  move_all_players_to_surface_test()
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
script.on_event(defines.events.on_player_created, function(event)
  queue_surface_test_move(event.player_index, 90)
end)
script.on_event(defines.events.on_player_joined_game, function(event)
  queue_surface_test_move(event.player_index, 90)
end)
script.on_event(defines.events.on_cutscene_started, function(event)
  ensure_globals()
  -- Design decision: cancelling immediately inside on_cutscene_started can
  -- leave the vanilla "Press Tab to skip cutscene" hint stuck on screen. We
  -- defer the cancel by one tick so the engine can initialize and clean up the
  -- cutscene UI correctly.
  storage.pending_cutscene_skip[event.player_index] = game.tick + 1
end)

script.on_event(DEBUG_RESET_HOTKEY, function(event)
  ensure_globals()

  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  if not player.admin then
    player.print("second_engineer: admin rights required for debug surface reset.")
    return
  end
  local mode_surface_name = launcher_surface_name(storage.surface_test_mode)
  if player.surface.name ~= mode_surface_name then
    player.print("second_engineer: debug surface reset is only enabled on the active debug surface.")
    return
  end

  storage.pending_debug_surface_reset = {
    player_index = player.index,
    surface_name = player.surface.name,
  }

  player.print("second_engineer: reloading mods, then rebuilding core district surface...")
  game.reload_mods()
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
  run_pending_debug_surface_reset()

  if defer_surface_test_queue_after_load then
    queue_all_players_surface_test_move(120)
    defer_surface_test_queue_after_load = false
  end

  for player_index, skip_tick in pairs(storage.pending_cutscene_skip) do
    if event.tick >= skip_tick then
      skip_intro_cutscene(game.get_player(player_index))
      storage.pending_cutscene_skip[player_index] = nil
    end
  end

  for player_index, move_tick in pairs(storage.pending_surface_test_relocate) do
    if event.tick >= move_tick then
      maybe_move_player_to_surface_test(game.get_player(player_index))
      storage.pending_surface_test_relocate[player_index] = nil
    end
  end

  if (event.tick % SCAN_INTERVAL) ~= 0 then return end
  ResearchAssembler.tick_scan()
end)

-- ── Tests (dev only) ──────────────────────────────────────────────────────────

if script.active_mods["factorio-test"] then
  require("__factorio-test__/init")(
    { "scripts.tests" },
    { load_luassert = true, game_speed = 1000 }
  )
end

commands.add_command("se-export-authored-perimeter", "Export the authored perimeter from the perimeter authoring surface.", function(command)
  ensure_globals()

  local player = command.player_index and game.get_player(command.player_index) or nil
  if not (player and player.valid) then return end
  if player.surface.name ~= SURFACE_PERIMETER_AUTHORING_NAME then
    player.print("second_engineer: perimeter export is only available on 'perimeter authoring'.")
    return
  end

  local export_report = worldgen.export_authored_perimeter(player.surface)
  if not export_report then
    player.print("second_engineer: perimeter export failed.")
    return
  end

  player.print(string.format(
    "second_engineer: exported authored perimeter to script-output/%s (%d entities, %d tiles).",
    export_report.path,
    export_report.entity_count,
    export_report.tile_count
  ))
end)

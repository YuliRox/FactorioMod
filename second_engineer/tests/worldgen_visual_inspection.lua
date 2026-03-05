-- tests/worldgen_visual_inspection.lua
-- Automated visual-inspection capture for the desert core district layout.

local Worldgen = require("scripts.worldgen")
local SURFACE_TEST_NAME = "surface test"

local function create_visual_surface_with_lab_tiles()
  local existing = game.surfaces[SURFACE_TEST_NAME]
  local surface = existing or game.create_surface(SURFACE_TEST_NAME, {
    peaceful_mode = true,
    autoplace_controls = {
      ["enemy-base"] = {frequency = 0, size = 0, richness = 0},
    },
  })

  -- Same runtime pattern as for Nauvis lab-tile generation.
  surface.generate_with_lab_tiles = true
  surface.request_to_generate_chunks({0, 0}, 20)
  surface.force_generate_chunk_requests()
  surface.generate_with_lab_tiles = false
  return surface
end

local function enable_debug_grid_like_view(player)
  if not (player and player.valid and player.game_view_settings) then return end
  local gvs = player.game_view_settings

  -- Best-effort equivalent of "F5 debug-like readability".
  pcall(function() gvs.show_entity_info = true end)
  pcall(function() gvs.show_circuit_network_numbers = true end)
  pcall(function() gvs.show_logistic_network = true end)
  pcall(function() gvs.show_tile_grid = true end)
  pcall(function() gvs.show_grid = true end)
end

describe("worldgen visual inspection", function()
  it("captures a three-shot inspection set (overview, rail, production)", function()
    async(1800)
    storage.worldgen = nil

    local surface = create_visual_surface_with_lab_tiles()
    assert.is_true(Worldgen.debug_spawn_core_district_on_surface(surface))

    local report = Worldgen.debug_get_last_core_layout_report()
    assert.is_not_nil(report)

    local district = report.blocks.central_district
    local center = report.anchor
    local area = district.area
    local player = game.get_player(1)
    assert.is_not_nil(player)
    assert.is_true(player.valid)

    player.teleport(center, surface)
    enable_debug_grid_like_view(player)

    -- 1) Wide overview for district shape and on-map placement.
    local overview_pos = {
      x = center.x,
      y = center.y,
    }
    game.take_screenshot({
      player = player,
      surface = surface,
      position = overview_pos,
      resolution = {x = 5120, y = 2880},
      zoom = 0.10,
      path = "second_engineer/core_district_overview.png",
      show_gui = false,
    })

    -- 2) Rail corridor close-up.
    local rail_pos = {
      x = area.left_top.x + 96,
      y = area.left_top.y + 48,
    }
    game.take_screenshot({
      player = player,
      surface = surface,
      position = rail_pos,
      resolution = {x = 3840, y = 2160},
      zoom = 0.22,
      path = "second_engineer/core_district_rail_closeup.png",
      show_gui = false,
    })

    -- 3) Production/logistics core close-up.
    local production_pos = {
      x = area.right_bottom.x - 112,
      y = area.right_bottom.y - 112,
    }
    game.take_screenshot({
      player = player,
      surface = surface,
      position = production_pos,
      resolution = {x = 3840, y = 2160},
      zoom = 0.26,
      path = "second_engineer/core_district_production_closeup.png",
      show_gui = false,
    })

    -- Screenshot writing is asynchronous; allow enough ticks before finishing.
    after_ticks(700, function()
      done()
    end)
  end)
end)

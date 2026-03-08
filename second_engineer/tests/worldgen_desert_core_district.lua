-- tests/worldgen_desert_core_district.lua
-- Integration tests for spawning the generated central district ruin.

local Worldgen = require("scripts.worldgen")
local SURFACE_TEST_NAME = "surface test"

local function new_surface_test_with_lab_tiles()
  local existing = game.surfaces[SURFACE_TEST_NAME]
  local surface = existing or game.create_surface(SURFACE_TEST_NAME, {
    peaceful_mode = true,
    autoplace_controls = {
      ["enemy-base"] = {frequency = 0, size = 0, richness = 0},
    },
  })

  surface.generate_with_lab_tiles = true
  surface.request_to_generate_chunks({0, 0}, 24)
  surface.force_generate_chunk_requests()
  surface.generate_with_lab_tiles = false
  return surface
end

local function clear_area_to_desert(surface, area)
  local tiles = {}

  for x = math.floor(area.left_top.x), math.ceil(area.right_bottom.x) do
    for y = math.floor(area.left_top.y), math.ceil(area.right_bottom.y) do
      tiles[#tiles + 1] = {
        name = "sand-1",
        position = {x = x, y = y},
      }
    end
  end

  surface.set_tiles(tiles)

  for _, entity in ipairs(surface.find_entities_filtered({area = area})) do
    if entity.valid then
      entity.destroy()
    end
  end
end

local function count_entities_in_area(surface, area)
  return #surface.find_entities_filtered({area = area})
end

local function summarize_district(surface, area)
  return {
    entities = count_entities_in_area(surface, area),
    rail_remnants = #surface.find_entities_filtered({area = area, name = "straight-rail-remnants"}),
    walls = #surface.find_entities_filtered({area = area, name = "stone-wall"}),
    assemblers = #surface.find_entities_filtered({area = area, name = "assembling-machine-3"}),
    furnaces = #surface.find_entities_filtered({area = area, name = "electric-furnace"}),
    gun_turrets = #surface.find_entities_filtered({area = area, name = "gun-turret"}),
    laser_turrets = #surface.find_entities_filtered({area = area, name = "laser-turret"}),
    roboports = #surface.find_entities_filtered({area = area, name = "roboport"}),
  }
end

local function assert_same_position(actual, expected)
  assert.is_true(actual.x == expected.x)
  assert.is_true(actual.y == expected.y)
end

local function assert_same_area(actual, expected)
  assert_same_position(actual.left_top, expected.left_top)
  assert_same_position(actual.right_bottom, expected.right_bottom)
end

describe("worldgen desert core district", function()
  it("spawns the authored central district ruin on an empty surface", function()
    storage.worldgen = nil

    local spec = Worldgen.debug_get_core_layout_spec()
    local surface = new_surface_test_with_lab_tiles()
    clear_area_to_desert(surface, spec.area)
    assert.is_true(count_entities_in_area(surface, spec.area) == 0)

    assert.is_true(Worldgen.debug_spawn_core_district_on_surface(surface))

    local report = Worldgen.debug_get_last_core_layout_report()
    local district = report.blocks.central_district
    local expected = spec.blocks.central_district

    assert.is_not_nil(report)
    assert.is_true(report.surface_name == surface.name)
    assert.is_true(report.surface_index == surface.index)
    assert.is_true(storage.worldgen.core_district_placed)
    assert.is_true(#report.defense_segments == 0)
    assert.is_not_nil(report.land_suitability)
    assert.is_true(report.land_suitability.water_ratio == 0)
    assert_same_position(report.anchor, spec.anchor)
    assert_same_area(report.area, spec.area)

    assert.is_true(district.package == "core_district")
    assert.is_true(district.placed)
    assert_same_position(district.anchor, expected.anchor)
    assert_same_area(district.area, expected.area)
    assert.is_true(count_entities_in_area(surface, district.area) > 0)
    assert.is_true(#surface.find_entities_filtered({area = district.area, name = "straight-rail-remnants"}) > 0)
    assert.is_true(#surface.find_entities_filtered({area = district.area, name = "stone-wall"}) > 0)
    assert.is_true(#surface.find_entities_filtered({area = district.area, name = "assembling-machine-3"}) > 0)
    assert.is_true(#surface.find_entities_filtered({area = district.area, name = "electric-furnace"}) > 0)

    local center_chunk = {
      x = math.floor(district.anchor.x / 32),
      y = math.floor(district.anchor.y / 32),
    }
    assert.is_true(surface.is_chunk_generated(center_chunk))
  end)

  it("rebuilds the same district area deterministically after a reset", function()
    storage.worldgen = nil

    local surface = new_surface_test_with_lab_tiles()
    assert.is_true(Worldgen.debug_spawn_core_district_on_surface(surface))
    local first = Worldgen.debug_get_last_core_layout_report()

    local reset_report = Worldgen.debug_reset_surface_for_core_district(surface, {include_defense = false})
    assert.is_not_nil(reset_report)

    local second = Worldgen.debug_get_last_core_layout_report()
    assert_same_position(first.anchor, second.anchor)
    assert_same_area(first.area, second.area)
    assert_same_position(first.blocks.central_district.anchor, second.blocks.central_district.anchor)
    assert_same_area(first.blocks.central_district.area, second.blocks.central_district.area)
  end)

  it("rebuilds stable authored entity counts on the same lab surface", function()
    storage.worldgen = nil

    local surface = new_surface_test_with_lab_tiles()
    clear_area_to_desert(surface, Worldgen.debug_get_core_layout_spec().area)
    assert.is_true(Worldgen.debug_spawn_core_district_on_surface(surface))

    local first = Worldgen.debug_get_last_core_layout_report()
    local first_summary = summarize_district(surface, first.blocks.central_district.area)

    Worldgen.debug_reset_surface_for_core_district(surface, {include_defense = false})
    local second = Worldgen.debug_get_last_core_layout_report()
    local second_summary = summarize_district(surface, second.blocks.central_district.area)

    assert.same(first_summary, second_summary)
    assert.is_true(first_summary.entities > 4000)
    assert.is_true(first_summary.rail_remnants > 700)
    assert.is_true(first_summary.walls > 3000)
    assert.is_true(first_summary.assemblers > 50)
    assert.is_true(first_summary.furnaces > 25)
    assert.is_true(first_summary.gun_turrets > 100)
    assert.is_true(first_summary.laser_turrets > 100)
    assert.is_true(first_summary.roboports > 10)
  end)
end)

-- tests/worldgen.lua
-- Runtime integration tests for scripts/worldgen.lua placement guarantees.

local Worldgen = require("scripts.worldgen")

local function nauvis()
  return game.surfaces["nauvis"] or game.surfaces[1]
end

local function area_around(center, radius)
  return {
    left_top = {x = center.x - radius, y = center.y - radius},
    right_bottom = {x = center.x + radius, y = center.y + radius},
  }
end

local function count_entities(surface, name, center, radius)
  local entities = surface.find_entities_filtered({
    name = name,
    area = area_around(center, radius),
  })
  return #entities
end

describe("worldgen placement", function()
  it("places starter resource guarantees and core district on init", function()
    storage.worldgen = nil

    Worldgen.on_init()

    local surface = nauvis()
    local report = Worldgen.debug_get_last_core_layout_report()
    assert.is_not_nil(report)
    local district = report.blocks.central_district
    assert.is_not_nil(district)

    -- Starter ore guarantees near spawn ring.
    assert.is_true(count_entities(surface, "iron-ore", {x = -24, y = -16}, 7) > 0)
    assert.is_true(count_entities(surface, "copper-ore", {x = 24, y = -16}, 7) > 0)
    assert.is_true(count_entities(surface, "coal", {x = -22, y = 20}, 7) > 0)
    assert.is_true(count_entities(surface, "stone", {x = 22, y = 20}, 7) > 0)

    local center = district.anchor
    assert.is_true(count_entities(surface, "straight-rail-remnants", center, 320) > 0)
    assert.is_true(count_entities(surface, "stone-wall", center, 320) > 0)
    assert.is_true(count_entities(surface, "express-transport-belt", center, 320) > 0)
    assert.is_true(count_entities(surface, "assembling-machine-3", center, 320) > 0)
    assert.is_true(count_entities(surface, "electric-furnace", center, 320) > 0)
    assert.is_true(district.area.left_top.x <= 48)
    assert.is_true(district.area.left_top.y <= 24)
    assert.is_true(district.area.left_top.x >= 24)
    assert.is_true(district.area.left_top.y >= 12)
    assert.is_not_nil(report.land_suitability)
    assert.is_true(report.land_suitability.water_ratio <= 0.08)

    assert.is_true(storage.worldgen.starter_area_prepared)
    assert.is_true(storage.worldgen.core_district_placed)
  end)
end)

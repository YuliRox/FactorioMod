-- tests/worldgen_perimeter_authoring_surface.lua
-- Integration test for the perimeter-authoring lab surface.

local Worldgen = require("scripts.worldgen")

describe("worldgen perimeter authoring surface", function()
  it("creates an empty 4096x4096 lab surface with no district or defenses", function()
    storage.worldgen = nil

    local surface = Worldgen.ensure_perimeter_authoring_surface()
    local report = Worldgen.debug_get_last_core_layout_report()

    assert.is_not_nil(surface)
    assert.is_true(surface.name == "perimeter authoring")
    assert.is_nil(report)
    assert.is_false(storage.worldgen.core_district_placed)
    assert.is_false(storage.worldgen.debug_spidertron_placed)
    assert.is_true(storage.worldgen.perimeter_authoring_surface_index == surface.index)

    assert.is_true(string.find(surface.get_tile(0, 0).name, "lab-", 1, true) == 1)
    assert.is_true(string.find(surface.get_tile(2047, 2047).name, "lab-", 1, true) == 1)
    assert.is_true(string.find(surface.get_tile(-2048, -2048).name, "lab-", 1, true) == 1)
    assert.is_true(#surface.find_entities_filtered({type = "tree"}) == 0)
    assert.is_true(#surface.find_entities_filtered({force = "enemy"}) == 0)
    assert.is_true(#surface.find_entities_filtered({area = {{-2048, -2048}, {2048, 2048}}}) == 0)
  end)

  it("exports authored entities from the empty authoring surface", function()
    local surface = Worldgen.ensure_perimeter_authoring_surface()
    local wall_pos = {
      x = 128,
      y = -96,
    }

    surface.create_entity({
      name = "stone-wall",
      position = wall_pos,
      force = game.forces.player,
      raise_built = false,
    })

    local export_report = Worldgen.export_authored_perimeter(surface)
    assert.is_not_nil(export_report)
    assert.is_true(export_report.path == "perimeter_authoring_export.tsv")
    assert.is_true(export_report.entity_count == 1)
  end)
end)

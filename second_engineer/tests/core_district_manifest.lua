-- tests/core_district_manifest.lua
-- Validation tests for the authored central district manifest wiring.

local Worldgen = require("scripts.worldgen")
local GeneratedManifest = require("scripts.worldgeneration.generated.core_district.manifest")

local function find_block_by_id(blocks, id)
  for _, block in ipairs(blocks) do
    if block.id == id then
      return block
    end
  end
  return nil
end

local function wear_total(wear)
  return (wear.alive or 0) + (wear.remnants or 0) + (wear.missing or 0)
end

describe("core district manifest", function()
  it("describes the authored central district package and generated bounds", function()
    local manifest = Worldgen.get_district_manifest()
    local block = find_block_by_id(manifest.blocks, "central_district")
    local bounds = GeneratedManifest.template.bounds
    local expected_width = math.floor(bounds.right_bottom.x - bounds.left_top.x + 1)
    local expected_height = math.floor(bounds.right_bottom.y - bounds.left_top.y + 1)

    assert.is_true(type(manifest) == "table")
    assert.is_true(type(manifest.version) == "number")
    assert.is_true(manifest.id == "core_district_authored_v1")
    assert.is_true(manifest.package == "core_district")
    assert.is_true(type(manifest.blocks) == "table" and #manifest.blocks == 1)
    assert.is_true(manifest.footprint.width == expected_width)
    assert.is_true(manifest.footprint.height == expected_height)

    assert.is_not_nil(block)
    assert.is_true(block.package == "core_district")
    assert.is_true(block.category == "authored")
    assert.is_true(block.footprint.width == expected_width)
    assert.is_true(block.footprint.height == expected_height)
    assert.is_true(type(block.guarantees) == "table" and #block.guarantees >= 4)
  end)

  it("uses sane wear budgets and references a compiled generated package", function()
    local manifest = Worldgen.get_district_manifest()
    local block = find_block_by_id(manifest.blocks, "central_district")
    local eps = 0.00001

    assert.is_true(type(manifest.defaults) == "table")
    assert.is_true(type(manifest.defaults.wear) == "table")
    assert.is_true(math.abs(wear_total(manifest.defaults.wear) - 1.0) <= eps)
    assert.is_true(type(GeneratedManifest.sectors) == "table")
    assert.is_true(#GeneratedManifest.sectors > 0)
    assert.is_true(GeneratedManifest.sector_size == 32)

    assert.is_true(type(block.wear) == "table")
    assert.is_true(block.wear.alive >= 0)
    assert.is_true(block.wear.remnants >= 0)
    assert.is_true(block.wear.missing >= 0)
    assert.is_true(math.abs(wear_total(block.wear) - 1.0) <= eps)
  end)

  it("stores the manifest version in worldgen state on init", function()
    local manifest = Worldgen.get_district_manifest()
    storage.worldgen = nil

    Worldgen.on_init()

    assert.is_true(type(storage.worldgen) == "table")
    assert.is_true(storage.worldgen.district_manifest_version == manifest.version)
  end)
end)

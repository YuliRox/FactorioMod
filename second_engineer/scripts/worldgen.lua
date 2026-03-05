local Worldgen = {}
local generated_core_district_manifest = require("scripts.worldgeneration.generated.core_district.manifest")
local district_manifest = require("scripts.worldgeneration.district_manifest")
local generated_core_district_sectors = {}

local CHUNK_SIZE = 32
local NAUVIS_NAME = "nauvis"
local SURFACE_TEST_NAME = "surface test"
local SURFACE_PERIMETER_AUTHORING_NAME = "perimeter authoring"
local SURFACE_TEST_CHUNK_RADIUS = 20
local SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS = 64
local PERIMETER_EXPORT_PATH = "perimeter_authoring_export.tsv"

-- Design decision: Nauvis should still let the player start normally, but the
-- local resource cushion must be obviously finite. These stamped patches create
-- a predictable 3-5 hour runway instead of relying on vanilla start area luck.
local STARTER_PATCHES = {
  -- Design decision: bootstrap patches should be close enough that the player
  -- can start immediately, but still spread out enough to avoid feeling like a
  -- vanilla super-cluster. This ring keeps the opening practical, not brutal.
  {name = "iron-ore",   pos = {x = -24, y = -16}, radius = 5, amount = 900},
  {name = "copper-ore", pos = {x =  24, y = -16}, radius = 5, amount = 850},
  {name = "coal",       pos = {x = -22, y =  20}, radius = 5, amount = 850},
  {name = "stone",      pos = {x =  22, y =  20}, radius = 5, amount = 900},
}

-- Design decision: the spawn area should not contain enough random vanilla ore
-- to support a standard bus-first expansion. We clear a square around spawn and
-- replace it with hand-authored starter deposits.
local STARTER_CLEAR_AREA = {
  left_top = {x = -96, y = -96},
  right_bottom = {x = 96, y = 96},
}

-- Design decision: the first district should sit just at the edge of the
-- player's initial viewport so the player sees enough wall/structure to get
-- curious without starting inside the ruin footprint.
local CORE_DISTRICT_VIEW_EDGE_LEFT_TOP = {x = 24, y = 12}
local CORE_DISTRICT_FALLBACK_ANCHOR = {x = 306.5, y = 194.5}
local CORE_DISTRICT_DEBUG_TAG = "[DEBUG] BLOCK: central_district"
local CORE_DISTRICT_WATER_SAMPLE_STEP = 16
local CORE_DISTRICT_MAX_WATER_RATIO = 0.08
local CORE_DISTRICT_CANDIDATE_OFFSETS = {
  {x = 0, y = 0},
  {x = 32, y = 0},
  {x = 0, y = 32},
  {x = 32, y = 32},
  {x = 64, y = 0},
  {x = 0, y = 64},
  {x = 64, y = 32},
  {x = 32, y = 64},
  {x = 64, y = 64},
  {x = 96, y = 0},
  {x = 0, y = 96},
  {x = 96, y = 32},
  {x = 32, y = 96},
}

-- Design decision: not every remote ore field should be worth the rail, power,
-- and outpost cost. These bands intentionally create many marginal deposits.
local RESOURCE_BANDS = {
  {name = "bootstrap", max_distance = 7, keep_chance = 0.45, amount_scale = 0.28},
  {name = "marginal",  max_distance = 18, keep_chance = 0.35, amount_scale = 0.22},
  {name = "contested", max_distance = 36, keep_chance = 0.55, amount_scale = 0.40},
  {name = "strategic", max_distance = math.huge, keep_chance = 0.75, amount_scale = 0.62},
}

local RESOURCE_MINIMUMS = {
  ["iron-ore"] = 150,
  ["copper-ore"] = 120,
  ["coal"] = 120,
  ["stone"] = 100,
  ["uranium-ore"] = 180,
  ["crude-oil"] = 15000,
}

local RESOURCE_SALTS = {
  ["iron-ore"] = 11,
  ["copper-ore"] = 17,
  ["coal"] = 23,
  ["stone"] = 29,
  ["uranium-ore"] = 31,
  ["crude-oil"] = 37,
}

local place_ruin_cluster

-- Design decision: Factorio only allows require() while parsing control stage
-- files, not during runtime events. Preload generated sector modules once here
-- and use table lookups during placement.
for _, sector_spec in ipairs(generated_core_district_manifest.sectors or {}) do
  local module_path = "scripts.worldgeneration.generated.core_district.sectors." .. sector_spec.key
  local ok, sector = pcall(require, module_path)
  if ok then
    generated_core_district_sectors[sector_spec.key] = sector
  end
end

local function manifest_anchor(manifest)
  local anchor = manifest and manifest.template and manifest.template.anchor
  return {
    x = (anchor and anchor.x) or 0,
    y = (anchor and anchor.y) or 0,
  }
end

local function origin_from_anchor(manifest, anchor_pos)
  local anchor = manifest_anchor(manifest)
  return {
    x = anchor_pos.x - anchor.x,
    y = anchor_pos.y - anchor.y,
  }
end

local function clone_pos(pos)
  return {x = pos.x, y = pos.y}
end

local function clone_area(area)
  return {
    left_top = clone_pos(area.left_top),
    right_bottom = clone_pos(area.right_bottom),
  }
end

local function area_contains_position(area, position)
  return position.x >= area.left_top.x and
    position.x < area.right_bottom.x and
    position.y >= area.left_top.y and
    position.y < area.right_bottom.y
end

local function area_contains_any(areas, position)
  for _, area in ipairs(areas) do
    if area_contains_position(area, position) then
      return true
    end
  end
  return false
end

local function format_export_number(value)
  return string.format("%.3f", value)
end

local function ensure_globals()
  storage.worldgen = storage.worldgen or {
    starter_area_prepared = false,
    core_district_placed = false,
    core_district_tagged = false,
    core_district_anchor = nil,
    core_district_anchor_stats = nil,
    debug_spidertron_placed = false,
    district_manifest_version = nil,
  }
end

local function validate_district_manifest(manifest)
  if type(manifest) ~= "table" then return false end
  if type(manifest.version) ~= "number" then return false end
  if type(manifest.id) ~= "string" or manifest.id == "" then return false end
  if type(manifest.blocks) ~= "table" or #manifest.blocks == 0 then return false end

  for _, block in ipairs(manifest.blocks) do
    if type(block) ~= "table" then return false end
    if type(block.id) ~= "string" or block.id == "" then return false end
    if type(block.category) ~= "string" or block.category == "" then return false end
    if type(block.footprint) ~= "table" then return false end
    if type(block.footprint.width) ~= "number" or block.footprint.width <= 0 then return false end
    if type(block.footprint.height) ~= "number" or block.footprint.height <= 0 then return false end
    if type(block.wear) ~= "table" then return false end
    if type(block.wear.alive) ~= "number" then return false end
    if type(block.wear.remnants) ~= "number" then return false end
    if type(block.wear.missing) ~= "number" then return false end
  end

  return true
end

local function chunk_to_area(chunk_pos)
  return {
    left_top = {
      x = chunk_pos.x * CHUNK_SIZE,
      y = chunk_pos.y * CHUNK_SIZE,
    },
    right_bottom = {
      x = (chunk_pos.x + 1) * CHUNK_SIZE,
      y = (chunk_pos.y + 1) * CHUNK_SIZE,
    },
  }
end

local function area_intersects(a, b)
  return not (
    a.right_bottom.x <= b.left_top.x or
    a.left_top.x >= b.right_bottom.x or
    a.right_bottom.y <= b.left_top.y or
    a.left_top.y >= b.right_bottom.y
  )
end

local function area_contains_pos(area, pos)
  return pos.x >= area.left_top.x and pos.x < area.right_bottom.x and
         pos.y >= area.left_top.y and pos.y < area.right_bottom.y
end

local function get_player_force()
  return game.forces.player or game.forces["player"]
end

local function deterministic_roll(x, y, salt)
  local value = math.sin(x * 12.9898 + y * 78.233 + salt * 37.719) * 43758.5453
  return value - math.floor(value)
end

local function classify_band(distance_in_chunks)
  for _, band in ipairs(RESOURCE_BANDS) do
    if distance_in_chunks <= band.max_distance then
      return band.name, band
    end
  end
  return "strategic", RESOURCE_BANDS[#RESOURCE_BANDS]
end

local function create_resource_patch(surface, patch)
  for dx = -patch.radius, patch.radius do
    for dy = -patch.radius, patch.radius do
      if (dx * dx + dy * dy) <= (patch.radius * patch.radius) then
        local pos = {x = patch.pos.x + dx, y = patch.pos.y + dy}
        local falloff = 1 - ((dx * dx + dy * dy) / (patch.radius * patch.radius + 1))
        local amount = math.max(1, math.floor(patch.amount * (0.55 + falloff)))
        surface.create_entity({
          name = patch.name,
          position = pos,
          amount = amount,
        })
      end
    end
  end
end

local function set_disc_tiles(surface, center, radius, tile_name)
  local tiles = {}

  for dx = -radius, radius do
    for dy = -radius, radius do
      if (dx * dx + dy * dy) <= (radius * radius) then
        tiles[#tiles + 1] = {
          name = tile_name,
          position = {x = center.x + dx, y = center.y + dy},
        }
      end
    end
  end

  surface.set_tiles(tiles)
end

local function clear_blocking_entities(surface, area)
  -- Design decision: authored spawn content must remain readable and usable.
  -- Trees, rocks, and cliffs are fine elsewhere, but not on top of guaranteed
  -- ruins or starter patches where they can hide structures or invalidate ore.
  local blockers = surface.find_entities_filtered({
    area = area,
    type = {"tree", "cliff", "simple-entity", "simple-entity-with-owner"},
  })

  for _, entity in ipairs(blockers) do
    if entity.valid then
      entity.destroy()
    end
  end
end

local function pad_area(center, radius)
  return {
    left_top = {x = center.x - radius, y = center.y - radius},
    right_bottom = {x = center.x + radius + 1, y = center.y + radius + 1},
  }
end

local function classify_tile_family(tile_name)
  if not tile_name then return nil end
  if string.find(tile_name, "grass", 1, true) then return "grass" end
  if string.find(tile_name, "dirt", 1, true) then return "dirt" end
  if string.find(tile_name, "sand", 1, true) then return "sand" end
  return nil
end

local function choose_replacement_tile_name(family)
  if family == "sand" then
    return "sand-1"
  end

  if family == "dirt" then
    return "dirt-4"
  end

  return "grass-1"
end

local function detect_patch_tile_name(surface, center, radius)
  local counts = {grass = 0, dirt = 0, sand = 0}

  for dx = -(radius + 2), radius + 2 do
    for dy = -(radius + 2), radius + 2 do
      if (dx * dx + dy * dy) > (radius * radius) then
        local family = classify_tile_family(surface.get_tile(center.x + dx, center.y + dy).name)
        if family then
          counts[family] = counts[family] + 1
        end
      end
    end
  end

  if counts.sand >= counts.dirt and counts.sand >= counts.grass then
    return choose_replacement_tile_name("sand")
  end

  if counts.dirt >= counts.grass then
    return choose_replacement_tile_name("dirt")
  end

  return choose_replacement_tile_name("grass")
end

local function count_patch_resources(surface, patch)
  local total_amount = 0
  local resources = surface.find_entities_filtered({
    area = pad_area(patch.pos, patch.radius + 1),
    name = patch.name,
    type = "resource",
  })

  for _, entity in ipairs(resources) do
    total_amount = total_amount + entity.amount
  end

  return #resources, total_amount
end

local function prepare_patch_terrain(surface, patch)
  -- Design decision: starter resources are hand-authored guarantees. We stamp
  -- land under them first so lakes cannot erase a required bootstrap deposit.
  -- The replacement tile should match the local biome rather than forcing a
  -- bright grass island into dust or desert starts.
  local tile_name = detect_patch_tile_name(surface, patch.pos, patch.radius + 2)
  set_disc_tiles(surface, patch.pos, patch.radius + 1, tile_name)
  clear_blocking_entities(surface, pad_area(patch.pos, patch.radius + 2))
end

local function damage_entity(entity, health_ratio)
  if not (entity and entity.valid and health_ratio) then return end
  -- Factorio 2.0 removed LuaEntityPrototype.max_health at runtime. Using the
  -- entity value keeps this working for normal entities and future quality use.
  local max_health = entity.max_health
  if not max_health or max_health <= 1 then return end
  entity.health = math.max(1, math.floor(max_health * health_ratio))
end

local function fill_loot(entity, loot)
  if not (entity and entity.valid and loot) then return end
  local inv = entity.get_inventory(defines.inventory.chest)
  if not inv then return end
  for _, stack in ipairs(loot) do
    inv.insert(stack)
  end
end

local function place_ruin_entities(surface, origin, entities)
  local player_force = get_player_force()
  if not player_force then return end

  for _, spec in ipairs(entities) do
    if not prototypes.entity[spec.name] then goto continue end

    local params = {
      name = spec.name,
      position = {x = origin.x + spec.offset.x, y = origin.y + spec.offset.y},
      raise_built = false,
    }

    if spec.force then
      params.force = spec.force == "player" and player_force or spec.force
    end

    if spec.direction then
      params.direction = spec.direction
    end

    local entity = surface.create_entity(params)

    damage_entity(entity, spec.health)
    fill_loot(entity, spec.loot)
    ::continue::
  end
end

local function shift_area(area, origin)
  return {
    left_top = {
      x = origin.x + area.left_top.x,
      y = origin.y + area.left_top.y,
    },
    right_bottom = {
      x = origin.x + area.right_bottom.x + 1,
      y = origin.y + area.right_bottom.y + 1,
    },
  }
end

local function area_from_manifest_anchor(manifest, anchor_pos)
  local origin = origin_from_anchor(manifest, anchor_pos)
  return shift_area(manifest.template.bounds, origin)
end

local function default_core_district_anchor()
  local bounds = generated_core_district_manifest.template.bounds
  return {
    x = CORE_DISTRICT_VIEW_EDGE_LEFT_TOP.x - bounds.left_top.x,
    y = CORE_DISTRICT_VIEW_EDGE_LEFT_TOP.y - bounds.left_top.y,
  }
end

local function is_water_tile(tile_name)
  return tile_name ~= nil and string.find(tile_name, "water", 1, true) ~= nil
end

local function ensure_area_generated(surface, area)
  local extent = math.max(
    math.abs(area.left_top.x),
    math.abs(area.left_top.y),
    math.abs(area.right_bottom.x),
    math.abs(area.right_bottom.y)
  )
  local chunk_radius = math.ceil(extent / CHUNK_SIZE) + 1
  surface.request_to_generate_chunks({0, 0}, chunk_radius)
  surface.force_generate_chunk_requests()
end

local function sample_water_ratio(surface, area)
  local water_tiles = 0
  local samples = 0

  for x = math.floor(area.left_top.x), math.ceil(area.right_bottom.x), CORE_DISTRICT_WATER_SAMPLE_STEP do
    for y = math.floor(area.left_top.y), math.ceil(area.right_bottom.y), CORE_DISTRICT_WATER_SAMPLE_STEP do
      samples = samples + 1
      if is_water_tile(surface.get_tile(x, y).name) then
        water_tiles = water_tiles + 1
      end
    end
  end

  if samples == 0 then
    return 0, 0, 0
  end

  return water_tiles / samples, water_tiles, samples
end

local function choose_core_district_anchor(surface)
  local preferred = default_core_district_anchor()
  if not (surface and surface.valid) then
    return clone_pos(preferred), {water_ratio = 0, water_tiles = 0, sample_tiles = 0}
  end

  local best_anchor = nil
  local best_stats = nil
  local best_score = nil

  for _, offset in ipairs(CORE_DISTRICT_CANDIDATE_OFFSETS) do
    local candidate = {
      x = preferred.x + offset.x,
      y = preferred.y + offset.y,
    }
    local area = area_from_manifest_anchor(generated_core_district_manifest, candidate)
    ensure_area_generated(surface, area)

    local water_ratio, water_tiles, sample_tiles = sample_water_ratio(surface, area)
    local score = water_ratio * 10000 + math.abs(offset.x) + math.abs(offset.y)

    if water_ratio <= CORE_DISTRICT_MAX_WATER_RATIO and (best_score == nil or score < best_score) then
      best_anchor = candidate
      best_score = score
      best_stats = {
        water_ratio = water_ratio,
        water_tiles = water_tiles,
        sample_tiles = sample_tiles,
      }
    end
  end

  if best_anchor then
    return best_anchor, best_stats
  end

  local fallback_area = area_from_manifest_anchor(generated_core_district_manifest, preferred)
  ensure_area_generated(surface, fallback_area)
  local water_ratio, water_tiles, sample_tiles = sample_water_ratio(surface, fallback_area)
  return clone_pos(preferred), {
    water_ratio = water_ratio,
    water_tiles = water_tiles,
    sample_tiles = sample_tiles,
  }
end

local function get_core_district_anchor(surface)
  storage.worldgen = storage.worldgen or {}
  if storage.worldgen and storage.worldgen.core_district_anchor then
    return clone_pos(storage.worldgen.core_district_anchor)
  end

  local fallback = default_core_district_anchor()
  if not (surface and surface.valid) then
    return fallback
  end

  local anchor, stats = choose_core_district_anchor(surface)
  storage.worldgen.core_district_anchor = clone_pos(anchor)
  storage.worldgen.core_district_anchor_stats = stats
  return anchor
end

local function describe_core_layout_spec(surface)
  local anchor = get_core_district_anchor(surface)
  return {
    anchor = clone_pos(anchor),
    area = area_from_manifest_anchor(generated_core_district_manifest, anchor),
    blocks = {
      central_district = {
        package = "core_district",
        anchor = clone_pos(anchor),
        area = area_from_manifest_anchor(generated_core_district_manifest, anchor),
      },
    },
    defense_segments = {},
  }
end

local function place_generated_tile_bucket(surface, origin, tiles)
  if not tiles or #tiles == 0 then return end

  local placed = {}
  for _, spec in ipairs(tiles) do
    local tile_name = spec.name or spec.target_name
    if tile_name then
    placed[#placed + 1] = {
      name = tile_name,
      position = {
        x = origin.x + spec.offset.x,
        y = origin.y + spec.offset.y,
      },
    }
    end
  end

  if #placed > 0 then
    surface.set_tiles(placed)
  end
end

local function load_generated_sector(package_name, key, label)
  local sector
  if package_name == "core_district" then
    sector = generated_core_district_sectors[key]
  end

  if not sector then
    log(string.format("second_engineer: missing preloaded %s sector %s", label, key))
  end
  return sector
end

local function clear_generated_ghosts(surface, area)
  -- Design decision: this placement is an inspection scaffold, not a
  -- blueprint. Any leftover ghosts in the footprint are just noise.
  local ghosts = surface.find_entities_filtered({
    area = area,
    name = {"entity-ghost", "tile-ghost"},
  })

  for _, ghost in ipairs(ghosts) do
    if ghost.valid then
      ghost.destroy()
    end
  end
end

local function ruin_marker_exists(surface, area, marker_name)
  local entities = surface.find_entities_filtered({
    area = area,
    name = marker_name,
  })
  return #entities > 0
end

local function entity_already_exists(surface, params)
  local pos = params.position
  local area = {
    left_top = {x = pos.x - 0.2, y = pos.y - 0.2},
    right_bottom = {x = pos.x + 0.2, y = pos.y + 0.2},
  }

  local nearby = surface.find_entities_filtered({
    area = area,
    name = params.name,
  })

  for _, entity in ipairs(nearby) do
    if entity.valid then
      local same_direction = (params.direction == nil) or (entity.direction == params.direction)
      local same_force = true

      if params.force and entity.force then
        local expected = params.force
        if type(expected) == "table" and expected.name then
          expected = expected.name
        end
        same_force = entity.force.name == expected
      end

      if same_direction and same_force then
        return entity
      end
    end
  end

  return nil
end

local function place_generated_remnants(surface, origin, entities)
  if not entities or #entities == 0 then return end

  for _, spec in ipairs(entities) do
    local entity_name = spec.name or spec.target_name
    if entity_name then
    local params = {
      name = entity_name,
      position = {
        x = origin.x + spec.offset.x,
        y = origin.y + spec.offset.y,
      },
      raise_built = false,
    }

    if spec.direction then
      params.direction = spec.direction
    end

    if not entity_already_exists(surface, params) then
      surface.create_entity(params)
    end
    end
  end
end

local function place_generated_damaged_entities(surface, origin, entities)
  if not entities or #entities == 0 then return end

  for _, spec in ipairs(entities) do
    local entity_name = spec.name or spec.target_name
    if entity_name then
    local params = {
      name = entity_name,
      position = {
        x = origin.x + spec.offset.x,
        y = origin.y + spec.offset.y,
      },
      force = "neutral",
      raise_built = false,
    }

    if spec.direction then
      params.direction = spec.direction
    end

    local entity = entity_already_exists(surface, params) or surface.create_entity(params)
    if entity and entity.valid and spec.damage then
      -- Design decision: "damaged live" means barely surviving, not immediately
      -- destroyed on spawn. Applying raw damage can kill low-health entities
      -- like solar panels outright, so clamp to 1 HP minimum instead.
      local max_health = entity.max_health
      if max_health and max_health > 1 then
        entity.health = math.max(1, max_health - spec.damage)
      end
    end
    end
  end
end

local function place_generated_package(surface, package_name, manifest, anchor_pos, marker_name)
  local origin = origin_from_anchor(manifest, anchor_pos)
  local area = shift_area(manifest.template.bounds, origin)
  local placed_any_sector = false

  clear_blocking_entities(surface, area)
  clear_generated_ghosts(surface, area)

  for _, sector_spec in ipairs(manifest.sectors or {}) do
    local sector = load_generated_sector(package_name, sector_spec.key, package_name)
    if sector then
      placed_any_sector = true
      place_generated_tile_bucket(surface, origin, sector.tiles.foundation_kept)
      place_generated_tile_bucket(surface, origin, sector.tiles.foundation_cracked)
      place_generated_remnants(surface, origin, sector.entities.remnant)
      place_generated_damaged_entities(surface, origin, sector.entities.damaged_live)
    end
  end

  clear_generated_ghosts(surface, area)
  if marker_name then
    return placed_any_sector and ruin_marker_exists(surface, area, marker_name), area
  end
  return placed_any_sector, area
end

local function place_core_district(surface, opts)
  opts = opts or {}
  local force_place = opts.force == true
  local layout = describe_core_layout_spec(surface)
  local report = {
    surface_name = surface.name,
    surface_index = surface.index,
    anchor = clone_pos(layout.anchor),
    area = clone_area(layout.area),
    blocks = {},
    defense_segments = {},
  }

  local placed
  local area
  if force_place or not storage.worldgen.core_district_placed then
    placed, area = place_generated_package(
      surface,
      "core_district",
      generated_core_district_manifest,
      layout.anchor,
      "straight-rail-remnants"
    )
    storage.worldgen.core_district_placed = placed
    local rail_remnants = #surface.find_entities_filtered({area = area, name = "straight-rail-remnants"})
    local wall_count = #surface.find_entities_filtered({area = area, name = "stone-wall"})
    local live_total = #surface.find_entities_filtered({area = area, name = {"assembling-machine-3", "electric-furnace", "laser-turret", "gun-turret", "roboport"}})
    log(string.format(
      "second_engineer: core-district spawn counts rails=%d walls=%d live=%d placed=%s",
      rail_remnants,
      wall_count,
      live_total,
      tostring(storage.worldgen.core_district_placed)
    ))
  else
    placed = storage.worldgen.core_district_placed
    area = layout.area
  end

  report.land_suitability = storage.worldgen.core_district_anchor_stats or {
    water_ratio = 0,
    water_tiles = 0,
    sample_tiles = 0,
  }

  report.blocks.central_district = {
    package = "core_district",
    anchor = clone_pos(layout.anchor),
    area = clone_area(area),
    placed = placed,
    skipped = not force_place and storage.worldgen.core_district_placed,
  }

  storage.worldgen.last_core_layout_report = report
end

local function place_debug_chart_tag(surface, position, text)
  local player_force = get_player_force()
  if not player_force then return false end

  player_force.chart(surface, {
    left_top = {x = position.x - 16, y = position.y - 16},
    right_bottom = {x = position.x + 16, y = position.y + 16},
  })
  player_force.add_chart_tag(surface, {
    position = position,
    text = text,
  })
  return true
end

local function place_core_district_debug_tag(surface, opts)
  storage.worldgen.core_district_tagged = place_debug_chart_tag(surface, get_core_district_anchor(surface), CORE_DISTRICT_DEBUG_TAG)
end

local function place_debug_spidertron(surface)
  if storage.worldgen.debug_spidertron_placed then return end

  local player_force = get_player_force()
  if not player_force then return end

  -- DEBUG ONLY: this spidertron exists to speed up inspection while building
  -- the mod and must be removed prior to mod publishing.
  local spidertron = surface.create_entity({
    name = "spidertron",
    position = {x = 6, y = 6},
    force = player_force,
    quality = "legendary",
    raise_built = false,
  })

  if spidertron and spidertron.valid and spidertron.grid then
    -- Design decision: the debug spidertron should be inspection-ready without
    -- any manual setup, so it spawns fully equipped at top quality.
    spidertron.grid.put({
      name = "fusion-reactor-equipment",
      position = {x = 0, y = 0},
      quality = "legendary",
    })
    spidertron.grid.put({
      name = "exoskeleton-equipment",
      position = {x = 4, y = 0},
      quality = "legendary",
    })
    spidertron.grid.put({
      name = "exoskeleton-equipment",
      position = {x = 6, y = 0},
      quality = "legendary",
    })
    spidertron.grid.put({
      name = "exoskeleton-equipment",
      position = {x = 4, y = 2},
      quality = "legendary",
    })
  end

  if spidertron and spidertron.valid then
    local trunk = spidertron.get_inventory(defines.inventory.spider_trunk)
    if trunk then
      trunk.insert({name = "infinity-chest", count = 1})
    end
  end

  storage.worldgen.debug_spidertron_placed = true
end

local function verify_starter_patch(surface, patch)
  local entity_count, total_amount = count_patch_resources(surface, patch)
  local minimum_entities = math.max(8, math.floor((patch.radius * patch.radius) * 0.8))
  local minimum_amount = math.floor(patch.amount * 18)

  if entity_count >= minimum_entities and total_amount >= minimum_amount then
    return
  end

  -- Design decision: starter patches are authored guarantees, not best-effort
  -- suggestions. If a seed or later chunk processing damages one, rebuild it.
  prepare_patch_terrain(surface, patch)

  local old_resources = surface.find_entities_filtered({
    area = pad_area(patch.pos, patch.radius + 1),
    name = patch.name,
    type = "resource",
  })

  for _, entity in ipairs(old_resources) do
    entity.destroy()
  end

  create_resource_patch(surface, patch)
end

local function verify_starter_area(surface)
  for _, patch in ipairs(STARTER_PATCHES) do
    verify_starter_patch(surface, patch)
  end
end

local function clear_starter_resources(surface)
  local resources = surface.find_entities_filtered({
    area = STARTER_CLEAR_AREA,
    type = "resource",
  })

  for _, entity in ipairs(resources) do
    entity.destroy()
  end
end

local function prepare_starter_area(surface)
  if storage.worldgen.starter_area_prepared then return end

  -- Design decision: we pre-generate several chunks around spawn so the custom
  -- bootstrap patches and ruins are present immediately on a new game.
  surface.request_to_generate_chunks({0, 0}, 12)
  surface.force_generate_chunk_requests()

  clear_starter_resources(surface)

  for _, patch in ipairs(STARTER_PATCHES) do
    prepare_patch_terrain(surface, patch)
    create_resource_patch(surface, patch)
  end

  -- Design decision: spawn the authored core district here. The generated
  -- solar mega-ruin remains disabled in runtime flow for now.
  place_core_district(surface)
  place_core_district_debug_tag(surface)
  place_debug_spidertron(surface)
  verify_starter_area(surface)
  storage.worldgen.starter_area_prepared = true
end

local function trim_resource_entity(entity, band, distance_in_chunks)
  if not (entity and entity.valid) then return end

  local salt = RESOURCE_SALTS[entity.name] or 7
  local roll = deterministic_roll(entity.position.x, entity.position.y, salt)
  if roll > band.keep_chance then
    entity.destroy()
    return
  end

  local scaled = math.floor(entity.amount * band.amount_scale)
  local minimum = RESOURCE_MINIMUMS[entity.name] or 100

  -- Design decision: marginal fields should still be mineable, just often not
  -- worth the infrastructure. We leave a floor so fields feel disappointing,
  -- not randomly deleted into nothing.
  entity.amount = math.max(minimum, scaled)

  if distance_in_chunks <= 18 then
    local extra_roll = deterministic_roll(entity.position.y, entity.position.x, entity.amount)
    if extra_roll > 0.82 then
      entity.amount = math.max(minimum, math.floor(entity.amount * 0.55))
    end
  end
end

local function process_chunk_resources(surface, area)
  local center_x = area.left_top.x + CHUNK_SIZE / 2
  local center_y = area.left_top.y + CHUNK_SIZE / 2
  local distance = math.sqrt(center_x * center_x + center_y * center_y) / CHUNK_SIZE
  local _, band = classify_band(distance)

  local resources = surface.find_entities_filtered({
    area = area,
    type = "resource",
  })

  for _, entity in ipairs(resources) do
    if not area_intersects(area, STARTER_CLEAR_AREA) then
      trim_resource_entity(entity, band, distance)
    end
  end
end

function Worldgen.apply_map_gen_settings()
  local surface = game.surfaces[NAUVIS_NAME]
  if not surface then return end

  local settings = surface.map_gen_settings
  local controls = settings.autoplace_controls or {}

  local function tune(name, frequency, size, richness)
    if not controls[name] then return end
    controls[name].frequency = frequency
    controls[name].size = size
    controls[name].richness = richness
  end

  -- Design decision: map-gen does the coarse scarcity pass, then chunk post-
  -- processing applies the harsher "many deposits are economically bad" layer.
  tune("iron-ore", 0.45, 0.30, 0.38)
  tune("copper-ore", 0.42, 0.28, 0.36)
  tune("coal", 0.42, 0.26, 0.34)
  tune("stone", 0.35, 0.24, 0.32)
  tune("uranium-ore", 0.40, 0.30, 0.45)
  tune("crude-oil", 0.55, 0.45, 0.60)

  -- DEBUG ONLY: peaceful mode is enabled to simplify worldgen inspection
  -- while developing the mod and must be revisited prior to publishing.
  settings.peaceful_mode = true

  -- DEBUG ONLY: force a desert-biased Nauvis during worldgen iteration so
  -- ruin silhouettes remain readable; remove or relax before release.
  settings.property_expression_names = settings.property_expression_names or {}
  settings.property_expression_names["control-setting:moisture:bias"] = "-2"
  settings.property_expression_names["control-setting:aux:bias"] = "1.8"

  settings.autoplace_controls = controls
  surface.map_gen_settings = settings
end

function Worldgen.get_district_manifest()
  return district_manifest
end

function Worldgen.debug_get_core_layout_spec()
  return describe_core_layout_spec()
end

function Worldgen.debug_get_last_core_layout_report()
  return storage.worldgen and storage.worldgen.last_core_layout_report or nil
end

function Worldgen.debug_spawn_core_district_on_surface(surface, opts)
  if not (surface and surface.valid) then return false end
  ensure_globals()
  opts = opts or {}
  opts.force = true
  place_core_district(surface, opts)
  return storage.worldgen and storage.worldgen.last_core_layout_report ~= nil
end

local function reset_core_district_flags()
  storage.worldgen.core_district_placed = false
  storage.worldgen.core_district_tagged = false
  storage.worldgen.core_district_anchor = nil
  storage.worldgen.core_district_anchor_stats = nil
  storage.worldgen.debug_spidertron_placed = false
end

function Worldgen.debug_reset_surface_for_core_district(surface, opts)
  if not (surface and surface.valid) then return nil end
  ensure_globals()
  opts = opts or {}

  local min_chunk_x, max_chunk_x, min_chunk_y, max_chunk_y
  for chunk in surface.get_chunks() do
    min_chunk_x = min_chunk_x and math.min(min_chunk_x, chunk.x) or chunk.x
    max_chunk_x = max_chunk_x and math.max(max_chunk_x, chunk.x) or chunk.x
    min_chunk_y = min_chunk_y and math.min(min_chunk_y, chunk.y) or chunk.y
    max_chunk_y = max_chunk_y and math.max(max_chunk_y, chunk.y) or chunk.y
  end

  if not min_chunk_x then
    min_chunk_x, max_chunk_x = -SURFACE_TEST_CHUNK_RADIUS, SURFACE_TEST_CHUNK_RADIUS
    min_chunk_y, max_chunk_y = -SURFACE_TEST_CHUNK_RADIUS, SURFACE_TEST_CHUNK_RADIUS
  end

  local area = {
    left_top = {x = min_chunk_x * CHUNK_SIZE, y = min_chunk_y * CHUNK_SIZE},
    right_bottom = {x = (max_chunk_x + 1) * CHUNK_SIZE, y = (max_chunk_y + 1) * CHUNK_SIZE},
  }

  local destroyed_entities = 0
  local entities = surface.find_entities()
  for _, entity in ipairs(entities) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy({raise_destroy = true})
      destroyed_entities = destroyed_entities + 1
    end
  end

  if surface.clear_pollution then
    surface.clear_pollution()
  end
  if surface.destroy_decoratives then
    surface.destroy_decoratives({area = area})
  end
  if surface.build_checkerboard then
    surface.build_checkerboard(area)
  end

  reset_core_district_flags()
  place_core_district(surface, {force = true, include_defense = opts.include_defense ~= false})
  place_core_district_debug_tag(surface, {include_defense = opts.include_defense ~= false})

  return {
    destroyed_entities = destroyed_entities,
    area = area,
  }
end

local function ensure_lab_surface(surface_name, chunk_radius)
  chunk_radius = chunk_radius or SURFACE_TEST_CHUNK_RADIUS
  local surface = game.surfaces[surface_name]
  if not (surface and surface.valid) then
    surface = game.create_surface(surface_name, {
      peaceful_mode = true,
      autoplace_controls = {
        ["enemy-base"] = {frequency = 0, size = 0, richness = 0},
      },
    })
  end

  surface.generate_with_lab_tiles = true
  surface.request_to_generate_chunks({0, 0}, chunk_radius)
  surface.force_generate_chunk_requests()
  surface.generate_with_lab_tiles = false

  local r = chunk_radius * CHUNK_SIZE
  local area = {
    left_top = {x = -r, y = -r},
    right_bottom = {x = r, y = r},
  }

  if surface.destroy_decoratives then
    surface.destroy_decoratives({area = area})
  end
  if surface.build_checkerboard then
    surface.build_checkerboard(area)
  end

  return surface
end

function Worldgen.ensure_surface_test()
  ensure_globals()
  local surface = ensure_lab_surface(SURFACE_TEST_NAME)

  place_core_district(surface, {force = true})
  storage.worldgen.surface_test_prepared = true
  storage.worldgen.surface_test_index = surface.index
  return surface
end

function Worldgen.ensure_perimeter_authoring_surface()
  ensure_globals()

  local surface = ensure_lab_surface(SURFACE_PERIMETER_AUTHORING_NAME, SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS)
  if not storage.worldgen.perimeter_authoring_prepared then
    local reset_report = Worldgen.debug_reset_surface_for_core_district(surface, {include_defense = false})
    local area = reset_report and reset_report.area or {
      left_top = {x = -SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS * CHUNK_SIZE, y = -SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS * CHUNK_SIZE},
      right_bottom = {x = SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS * CHUNK_SIZE, y = SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS * CHUNK_SIZE},
    }

    for _, entity in ipairs(surface.find_entities_filtered({area = area})) do
      if entity.valid and entity.type ~= "character" then
        entity.destroy({raise_destroy = true})
      end
    end
    if surface.destroy_decoratives then
      surface.destroy_decoratives({area = area})
    end
    if surface.build_checkerboard then
      surface.build_checkerboard(area)
    end

    reset_core_district_flags()
    storage.worldgen.last_core_layout_report = nil
    storage.worldgen.perimeter_authoring_prepared = true
  end

  storage.worldgen.perimeter_authoring_surface_index = surface.index
  return surface
end

function Worldgen.export_authored_perimeter(surface)
  if not (surface and surface.valid) then return nil end

  local export_area
  local anchor
  local block_areas = {}

  if surface.name == SURFACE_PERIMETER_AUTHORING_NAME then
    local r = SURFACE_PERIMETER_AUTHORING_CHUNK_RADIUS * CHUNK_SIZE
    export_area = {
      left_top = {x = -r, y = -r},
      right_bottom = {x = r, y = r},
    }
    anchor = {x = 0, y = 0}
  else
    local layout = describe_core_layout_spec()
    anchor = layout.blocks.central_depot.anchor
    for _, block in pairs(layout.blocks) do
      block_areas[#block_areas + 1] = block.area
    end
    export_area = {
      left_top = {
        x = layout.perimeter.left_x - CORE_ROW_DELTA,
        y = layout.perimeter.top_y - CORE_ROW_DELTA,
      },
      right_bottom = {
        x = layout.perimeter.right_x + CORE_ROW_DELTA,
        y = layout.perimeter.bottom_y + CORE_ROW_DELTA,
      },
    }
  end

  local entity_rows = {}
  local entities = surface.find_entities_filtered({area = export_area})
  for _, entity in ipairs(entities) do
    if entity.valid and entity.type ~= "character" and not area_contains_any(block_areas, entity.position) then
      entity_rows[#entity_rows + 1] = {
        name = entity.name,
        x = entity.position.x - anchor.x,
        y = entity.position.y - anchor.y,
        direction = entity.direction or 0,
        type = entity.type or "",
      }
    end
  end

  table.sort(entity_rows, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.name < b.name
  end)

  local tile_rows = {}
  if surface.name ~= SURFACE_PERIMETER_AUTHORING_NAME and surface.find_tiles_filtered then
    local tiles = surface.find_tiles_filtered({area = export_area})
    for _, tile in ipairs(tiles) do
      if tile.valid and not string.find(tile.name, "lab-", 1, true) and not area_contains_any(block_areas, tile.position) then
        tile_rows[#tile_rows + 1] = {
          name = tile.name,
          x = tile.position.x - anchor.x,
          y = tile.position.y - anchor.y,
        }
      end
    end
  end

  table.sort(tile_rows, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    if a.x ~= b.x then return a.x < b.x end
    return a.name < b.name
  end)

  local lines = {
    "# second_engineer perimeter authoring export",
    "surface\t" .. surface.name,
    "anchor\torigin\t" .. format_export_number(anchor.x) .. "\t" .. format_export_number(anchor.y),
    "entity_count\t" .. tostring(#entity_rows),
    "tile_count\t" .. tostring(#tile_rows),
  }

  for _, row in ipairs(entity_rows) do
    lines[#lines + 1] = table.concat({
      "entity",
      row.name,
      format_export_number(row.x),
      format_export_number(row.y),
      tostring(row.direction),
      row.type,
    }, "\t")
  end

  for _, row in ipairs(tile_rows) do
    lines[#lines + 1] = table.concat({
      "tile",
      row.name,
      format_export_number(row.x),
      format_export_number(row.y),
    }, "\t")
  end

  helpers.write_file(PERIMETER_EXPORT_PATH, table.concat(lines, "\n") .. "\n", false, 0)

  return {
    path = PERIMETER_EXPORT_PATH,
    entity_count = #entity_rows,
    tile_count = #tile_rows,
  }
end

function Worldgen.on_init()
  ensure_globals()
  if validate_district_manifest(district_manifest) then
    storage.worldgen.district_manifest_version = district_manifest.version
  else
    log("second_engineer: invalid district manifest; keeping existing worldgen behavior")
  end
  Worldgen.apply_map_gen_settings()

  local surface = game.surfaces[NAUVIS_NAME]
  if not surface then return end
  prepare_starter_area(surface)
end

function Worldgen.on_configuration_changed()
  ensure_globals()
  if validate_district_manifest(district_manifest) then
    storage.worldgen.district_manifest_version = district_manifest.version
  else
    log("second_engineer: invalid district manifest; keeping existing worldgen behavior")
  end
  Worldgen.apply_map_gen_settings()

  local surface = game.surfaces[NAUVIS_NAME]
  if not surface then return end

  if not storage.worldgen.starter_area_prepared then
    prepare_starter_area(surface)
  elseif not storage.worldgen.core_district_placed then
    place_core_district(surface)
  elseif not storage.worldgen.core_district_tagged then
    place_core_district_debug_tag(surface)
  elseif not storage.worldgen.debug_spidertron_placed then
    place_debug_spidertron(surface)
  end
end

function Worldgen.on_chunk_generated(event)
  ensure_globals()

  local surface = event.surface
  if not (surface and surface.valid and surface.name == NAUVIS_NAME) then return end

  local area = event.area or chunk_to_area(event.position)
  process_chunk_resources(surface, area)

  if area_intersects(area, STARTER_CLEAR_AREA) then
    clear_starter_resources(surface)
    verify_starter_area(surface)
    place_core_district(surface)
  end

end

return Worldgen

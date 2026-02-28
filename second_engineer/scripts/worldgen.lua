local Worldgen = {}
local ruins = require("scripts.worldgeneration.ruins")
local remnants = require("scripts.worldgeneration.remnants")

local CHUNK_SIZE = 32
local NAUVIS_NAME = "nauvis"

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

local function ensure_globals()
  storage.worldgen = storage.worldgen or {
    starter_area_prepared = false,
    starter_ruins_placed = false,
  }
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

local function prepare_ruin_terrain(surface)
  -- Design decision: the first guaranteed ruin cluster is supposed to teach the
  -- player to notice and evaluate repair opportunities. Hidden ruins fail that.
  local tiles = {}
  local tile_name = detect_patch_tile_name(surface, ruins.starter_cluster.origin, 8)
  for x = ruins.starter_clear_area.left_top.x, ruins.starter_clear_area.right_bottom.x - 1 do
    for y = ruins.starter_clear_area.left_top.y, ruins.starter_clear_area.right_bottom.y - 1 do
      tiles[#tiles + 1] = {
        name = tile_name,
        position = {x = x, y = y},
      }
    end
  end

  surface.set_tiles(tiles)
  clear_blocking_entities(surface, ruins.starter_clear_area)
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

local function choose_ruin_decoration_name(tile_name)
  local family = classify_tile_family(tile_name)
  if not family then
    return nil
  end

  -- Design decision: ruin dressing should reinforce the local biome instead of
  -- importing a fake forest into deserts. Grass gets trees; dry ground gets
  -- scrubby desert plants; sand gets no extra dressing at all.
  if family == "grass" then
    return "tree-04"
  end

  if family == "dirt" then
    return "dry-hairy-tree"
  end

  if family == "sand" then
    return nil
  end

  return nil
end

local function detect_ruin_biome(surface)
  local counts = {grass = 0, dirt = 0, sand = 0}

  -- Design decision: the ruin footprint itself is terrain-corrected for
  -- usability, so biome detection must sample the untouched ring around it.
  for x = ruins.starter_clear_area.left_top.x - 2, ruins.starter_clear_area.right_bottom.x + 1 do
    for y = ruins.starter_clear_area.left_top.y - 2, ruins.starter_clear_area.right_bottom.y + 1 do
      local in_clear_x = x >= ruins.starter_clear_area.left_top.x and x < ruins.starter_clear_area.right_bottom.x
      local in_clear_y = y >= ruins.starter_clear_area.left_top.y and y < ruins.starter_clear_area.right_bottom.y
      if not (in_clear_x and in_clear_y) then
        local family = classify_tile_family(surface.get_tile(x, y).name)
        if family then
          counts[family] = counts[family] + 1
        end
      end
    end
  end

  if counts.sand >= counts.dirt and counts.sand >= counts.grass then
    return "sand"
  end

  if counts.dirt >= counts.grass then
    return "dirt"
  end

  return "grass"
end

local function place_ruin_decorations(surface)
  local biome = detect_ruin_biome(surface)

  for _, spec in ipairs(ruins.starter_decoration_points) do
    local pos = {
      x = ruins.starter_cluster.origin.x + spec.offset.x,
      y = ruins.starter_cluster.origin.y + spec.offset.y,
    }
    local decoration_name = choose_ruin_decoration_name(biome)

    if decoration_name then
      surface.create_entity({
        name = decoration_name,
        position = pos,
        raise_built = false,
      })
    end
  end
end

local function place_ruin_entities(surface, origin, entities)
  local player_force = get_player_force()
  if not player_force then return end

  for _, spec in ipairs(entities) do
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
  end
end

local function get_template_area(origin, entities)
  local min_x, min_y = math.huge, math.huge
  local max_x, max_y = -math.huge, -math.huge

  for _, spec in ipairs(entities) do
    local x = origin.x + spec.offset.x
    local y = origin.y + spec.offset.y
    if x < min_x then min_x = x end
    if y < min_y then min_y = y end
    if x > max_x then max_x = x end
    if y > max_y then max_y = y end
  end

  return {
    left_top = {x = min_x - 1, y = min_y - 1},
    right_bottom = {x = max_x + 2, y = max_y + 2},
  }
end

local function place_template(surface, origin, template_index)
  local template = remnants.templates[template_index]
  if not template then return end

  -- Design decision: ambient remnants should be discoverable landmarks, not
  -- hidden under forests. We clear blockers in the template footprint but do
  -- not retile the ground, so the scene still reads as part of the biome.
  clear_blocking_entities(surface, get_template_area(origin, template.entities))
  place_ruin_entities(surface, origin, template.entities)
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

local function verify_starter_ruin_cluster(surface)
  local starter_structures = surface.find_entities_filtered({
    area = ruins.starter_clear_area,
    force = get_player_force(),
  })

  if #starter_structures >= 6 then
    return
  end

  -- Design decision: the guaranteed starter ruin is part of the intended
  -- tutorial path. If it is missing or too damaged by generation issues, reset
  -- the footprint and restamp it.
  prepare_ruin_terrain(surface)
  storage.worldgen.starter_ruins_placed = false
  place_ruin_cluster(surface)
end

local function verify_starter_area(surface)
  for _, patch in ipairs(STARTER_PATCHES) do
    verify_starter_patch(surface, patch)
  end

  verify_starter_ruin_cluster(surface)
end

local function place_guaranteed_remnants(surface)
  -- Design decision: the player should reliably encounter non-starter remnants
  -- on early scouting trips. These fixed anchors make the world read as ruined
  -- even if the probabilistic spray happens to miss the nearby chunks.
  for _, spec in ipairs(remnants.guaranteed) do
    place_template(surface, spec.origin, spec.template_index)
  end
end

place_ruin_cluster = function(surface)
  if storage.worldgen.starter_ruins_placed then return end

  place_ruin_entities(surface, ruins.starter_cluster.origin, ruins.starter_cluster.entities)
  place_ruin_decorations(surface)

  storage.worldgen.starter_ruins_placed = true
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
  surface.request_to_generate_chunks({0, 0}, 6)
  surface.force_generate_chunk_requests()

  clear_starter_resources(surface)

  for _, patch in ipairs(STARTER_PATCHES) do
    prepare_patch_terrain(surface, patch)
    create_resource_patch(surface, patch)
  end

  prepare_ruin_terrain(surface)
  place_ruin_cluster(surface)
  place_guaranteed_remnants(surface)
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

local function maybe_place_band_ruin(surface, area, chunk_pos)
  local center_x = area.left_top.x + CHUNK_SIZE / 2
  local center_y = area.left_top.y + CHUNK_SIZE / 2
  local distance = math.sqrt(center_x * center_x + center_y * center_y) / CHUNK_SIZE

  if distance < 3 or distance > 48 then return end

  local roll = deterministic_roll(chunk_pos.x, chunk_pos.y, 17)
  if roll > 0.42 then return end

  -- Design decision: the map should feel sprayed with partial industrial
  -- leftovers, not populated by one repeated chest vignette. These templates
  -- stay small enough to scatter often while still telling production stories.
  local anchor = {x = center_x, y = center_y}
  local template_index = 1 + math.floor(deterministic_roll(chunk_pos.y, chunk_pos.x, 29) * #remnants.templates)
  place_template(surface, anchor, template_index)
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

  settings.autoplace_controls = controls
  surface.map_gen_settings = settings
end

function Worldgen.on_init()
  ensure_globals()
  Worldgen.apply_map_gen_settings()

  local surface = game.surfaces[NAUVIS_NAME]
  if not surface then return end
  prepare_starter_area(surface)
end

function Worldgen.on_configuration_changed()
  ensure_globals()
  Worldgen.apply_map_gen_settings()

  local surface = game.surfaces[NAUVIS_NAME]
  if not surface then return end

  if not storage.worldgen.starter_area_prepared then
    prepare_starter_area(surface)
  elseif not storage.worldgen.starter_ruins_placed then
    place_ruin_cluster(surface)
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
  end

  if area_contains_pos(area, ruins.starter_cluster.origin) then
    place_ruin_cluster(surface)
  else
    maybe_place_band_ruin(surface, area, event.position)
  end
end

return Worldgen

-- prototypes/entity/research-assembler.lua
-- Entity, item, and recipe for the se-research-assembler.

local base_lab   = data.raw["lab"]["lab"]
local lab_recipe = data.raw["recipe"]["lab"]

data:extend({{
  type = "assembling-machine",
  name = "se-research-assembler",
  icon = "__base__/graphics/icons/lab.png",
  icon_size = 64,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "se-research-assembler"},
  max_health = 150,
  corpse = "medium-remnants",
  collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
  selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
  crafting_categories = {"se-research-crafting"},
  crafting_speed = 1,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    drain = "0W",
  },
  energy_usage = "60kW",
  ingredient_count = 12,
  trash_inventory_size = 12,
  module_slots = 2,
  allowed_effects = {"speed", "consumption", "pollution"},
  icons_positioning = {
    {inventory_index = defines.inventory.crafter_input,   shift = {0,  0.3}, max_icons_per_row = 6, separation_multiplier = 1/1.1},
    {inventory_index = defines.inventory.crafter_output,  shift = {0,  0.5}, max_icons_per_row = 6},
    {inventory_index = defines.inventory.crafter_trash,   shift = {0,  1.0}, max_icons_per_row = 6},
    {inventory_index = defines.inventory.crafter_modules, shift = {0,  1.5}},
  },
  graphics_set = {
    animation = util.table.deepcopy(base_lab.on_animation),
  },
}})

data:extend({{
  type = "item",
  name = "se-research-assembler",
  icon = "__base__/graphics/icons/lab.png",
  icon_size = 64,
  place_result = "se-research-assembler",
  stack_size = 10,
}})

data:extend({{
  type        = "recipe",
  name        = "se-research-assembler",
  enabled     = lab_recipe.enabled,
  ingredients = util.table.deepcopy(lab_recipe.ingredients),
  results     = {{type="item", name="se-research-assembler", amount=1}},
}})

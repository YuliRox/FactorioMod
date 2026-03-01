-- prototypes/recipe/scrap-smelting.lua
-- Probabilistic furnace recipes that smelt scrap into base materials.
-- 90% loss: each result has a 10% chance of being produced per craft.

data:extend({{
  type            = "recipe",
  name            = "se-smelt-scrap-red",
  localised_name  = {"recipe-name.se-smelt-scrap-red"},
  icon            = "__second_engineer__/graphics/icons/scrap/automation_scrap_64x64.png",
  icon_size       = 64,
  category        = "smelting",
  subgroup        = "intermediate-product",
  order           = "z[scrap-smelting]-a[scrap-red]",
  enabled         = true,
  energy_required = 3.2,
  ingredients     = {
    {type = "item", name = "scrap-red", amount = 1},
  },
  results = {
    {type = "item", name = "iron-plate",   amount = 2, probability = 0.1},
    {type = "item", name = "copper-plate", amount = 1, probability = 0.1},
  },
}})

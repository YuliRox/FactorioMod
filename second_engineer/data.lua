-- second_engineer: data stage entry point
-- Prototype definitions will be added in future milestones.

local scraps = {
  {name="scrap-red",    icon="__second_engineer__/graphics/icons/scrap/automation_scrap_64x64.png"},
  {name="scrap-green",  icon="__second_engineer__/graphics/icons/scrap/logistic_scrap_64x64.png"},
  {name="scrap-black",  icon="__second_engineer__/graphics/icons/scrap/military_scrap_64x64.png"},
  {name="scrap-blue",   icon="__second_engineer__/graphics/icons/scrap/chemical_scrap_64x64.png"},
  {name="scrap-purple", icon="__second_engineer__/graphics/icons/scrap/production_scrap_64x64.png"},
  {name="scrap-yellow", icon="__second_engineer__/graphics/icons/scrap/utility_scrap_64x64.png"},
  {name="scrap-white",  icon="__second_engineer__/graphics/icons/scrap/space_scrap_64x64.png"},
}

if mods["space-age"] then
  table.insert(scraps, {name="scrap-metallurgic",    icon="__second_engineer__/graphics/icons/scrap/metallurgic_scrap_64x64.png"})
  table.insert(scraps, {name="scrap-electromagnetic", icon="__second_engineer__/graphics/icons/scrap/electromagnetic_scrap_64x64.png"})
  table.insert(scraps, {name="scrap-agricultural",   icon="__second_engineer__/graphics/icons/scrap/agricultural_scrap_64x64.png"})
  table.insert(scraps, {name="scrap-cryogenic",      icon="__second_engineer__/graphics/icons/scrap/cryogenic_scrap_64x64.png"})
  table.insert(scraps, {name="scrap-promethium",     icon="__second_engineer__/graphics/icons/scrap/promethium_scrap_64x64.png"})
end

local items = {}
for _, s in pairs(scraps) do
  table.insert(items, {
    type = "item",
    name = s.name,
    icon = s.icon,
    icon_size = 64,
    stack_size = 200,
    subgroup = "intermediate-product",
    order = "z[scrap]-" .. s.name
  })
end

data:extend(items)

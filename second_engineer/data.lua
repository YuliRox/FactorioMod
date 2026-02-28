-- second_engineer: data stage entry point
-- Prototype definitions will be added in future milestones.

local scraps = {
  {name="scrap-red",    icon="__base__/graphics/icons/automation-science-pack.png"},
  {name="scrap-green",  icon="__base__/graphics/icons/logistic-science-pack.png"},
  {name="scrap-black",  icon="__base__/graphics/icons/military-science-pack.png"},
  {name="scrap-blue",   icon="__base__/graphics/icons/chemical-science-pack.png"},
  {name="scrap-purple", icon="__base__/graphics/icons/production-science-pack.png"},
  {name="scrap-yellow", icon="__base__/graphics/icons/utility-science-pack.png"},
  {name="scrap-white",  icon="__base__/graphics/icons/space-science-pack.png"},
}

if mods["space-age"] then
  table.insert(scraps, {name="scrap-metallurgic",    icon="__space-age__/graphics/icons/metallurgic-science-pack.png"})
  table.insert(scraps, {name="scrap-electromagnetic", icon="__space-age__/graphics/icons/electromagnetic-science-pack.png"})
  table.insert(scraps, {name="scrap-agricultural",   icon="__space-age__/graphics/icons/agricultural-science-pack.png"})
  table.insert(scraps, {name="scrap-cryogenic",      icon="__space-age__/graphics/icons/cryogenic-science-pack.png"})
  table.insert(scraps, {name="scrap-promethium",     icon="__space-age__/graphics/icons/promethium-science-pack.png"})
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

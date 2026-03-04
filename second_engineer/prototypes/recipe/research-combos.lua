-- prototypes/recipe/research-combos.lua
-- Required from data-final-fixes.lua (must run last — technologies from all
-- mods must be registered before this scans data.raw.technology).
--
-- Registers the idle recipe used when no research is active, then generates
-- one hidden recipe per unique science-pack combination found in the tree.

local PACK_TO_SCRAP = require("shared.pack_to_scrap")

local SCRAP_PER_PACK = {
  ["automation-science-pack"]      = 1,
  ["logistic-science-pack"]        = 1,
  ["military-science-pack"]        = 2,
  ["chemical-science-pack"]        = 2,
  ["production-science-pack"]      = 3,
  ["utility-science-pack"]         = 3,
  ["space-science-pack"]           = 4,
  ["metallurgic-science-pack"]     = 5,
  ["electromagnetic-science-pack"] = 5,
  ["agricultural-science-pack"]    = 5,
  ["cryogenic-science-pack"]       = 6,
  ["promethium-science-pack"]      = 8,
}

-- Stable short name: "automation-science-pack" → "automation"
local function pack_short(name)
  return (name:gsub("%-science%-pack$", ""))
end

-- Deterministic recipe name from a sorted list of pack names
local function combo_recipe_name(sorted_packs)
  local parts = {}
  for _, p in ipairs(sorted_packs) do
    table.insert(parts, pack_short(p))
  end
  return "se-research-" .. table.concat(parts, "-")
end

-- Localised name built from existing item-name locale keys, e.g.
-- "Automation science pack + Logistic science pack"
-- Chunks of ≤9 packs keep each table within Factorio's 20-parameter limit
-- (1 empty key + 9 names + 8 separators = 18).
local function combo_localised_name(sorted_packs)
  local MAX = 9
  local function build(i, j)
    if j - i < MAX then
      local parts = {""}
      for k = i, j do
        if k > i then table.insert(parts, " + ") end
        table.insert(parts, {"item-name." .. sorted_packs[k]})
      end
      return parts
    end
    local mid = i + MAX - 1
    return {"", build(i, mid), " + ", build(mid + 1, j)}
  end
  return build(1, #sorted_packs)
end

-- ── Idle recipe (no research active) ────────────────────────────────────────

data:extend({{
  type            = "recipe",
  name            = "se-research-idle",
  localised_name  = {"recipe-name.se-research-idle"},
  category        = "se-research-crafting",
  icon            = "__base__/graphics/icons/lab.png",
  icon_size       = 64,
  hidden          = true,
  enabled         = true,
  ingredients     = {},
  results         = {},
  energy_required = 60,
}})

-- ── Dynamic recipe generation ────────────────────────────────────────────────
-- One hidden recipe per unique pack combination found across all technologies.

local combos = {}  -- key → sorted pack name array

for _, tech in pairs(data.raw.technology) do
  if tech.unit and tech.unit.ingredients then
    local packs = {}
    for _, ing in pairs(tech.unit.ingredients) do
      local name = (type(ing) == "table") and (ing[1] or (ing --[[@as {name:string}]]).name) or tostring(ing)
      if PACK_TO_SCRAP[name] then
        table.insert(packs, name)
      end
    end
    if #packs > 0 then
      table.sort(packs)
      local key = table.concat(packs, "|")
      combos[key] = packs
    end
  end
end

for _, packs in pairs(combos) do
  local ingredients = {}
  local results     = {}

  for _, pack_name in ipairs(packs) do
    table.insert(ingredients, {type="item", name=pack_name, amount=1})
    local scrap = PACK_TO_SCRAP[pack_name]
    if scrap then
      table.insert(results, {type="item", name=scrap, amount=SCRAP_PER_PACK[pack_name] or 1})
    end
  end

  data:extend({{
    type            = "recipe",
    name            = combo_recipe_name(packs),
    localised_name  = combo_localised_name(packs),
    category        = "se-research-crafting",
    icon            = "__base__/graphics/icons/lab.png",
    icon_size       = 64,
    hidden          = true,
    enabled         = true,
    always_show_made_in = false,
    ingredients     = ingredients,
    results         = results,
    energy_required = 15,  -- one lab cycle
  }})
end

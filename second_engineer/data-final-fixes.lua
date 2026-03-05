-- second_engineer: data-final-fixes stage
-- Runs last. Patches the hidden research lab animation and generates one hidden
-- recipe per unique science-pack combination found in the technology tree.

-- ── Lookup tables (must match control.lua) ─────────────────────────────────

local PACK_TO_SCRAP = {
  ["automation-science-pack"] = "scrap-red",
  ["logistic-science-pack"]   = "scrap-green",
  ["military-science-pack"]   = "scrap-black",
  ["chemical-science-pack"]   = "scrap-blue",
  ["production-science-pack"] = "scrap-purple",
  ["utility-science-pack"]    = "scrap-yellow",
  ["space-science-pack"]      = "scrap-white",
}
if mods["space-age"] then
  PACK_TO_SCRAP["metallurgic-science-pack"]    = "scrap-metallurgic"
  PACK_TO_SCRAP["electromagnetic-science-pack"] = "scrap-electromagnetic"
  PACK_TO_SCRAP["agricultural-science-pack"]   = "scrap-agricultural"
  PACK_TO_SCRAP["cryogenic-science-pack"]      = "scrap-cryogenic"
  PACK_TO_SCRAP["promethium-science-pack"]     = "scrap-promethium"
end

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

-- ── Hidden lab debug animation ───────────────────────────────────────────────

local base_lab = data.raw["lab"]["lab"]

-- DEBUG: give the hidden research lab a visible, green-tinted copy of the base
-- lab animation so it can be inspected in-game. Remove when no longer needed.
do
  local function tint_anim(anim, tint, scale)
    if not anim then return end
    anim = util.table.deepcopy(anim)
    local function apply(a)
      if not a then return end
      if a.layers then
        for _, l in pairs(a.layers) do apply(l) end
      else
        a.tint         = tint
        a.scale        = (a.scale or 1) * scale
        a.render_layer = "higher-entity"
      end
    end
    if anim.north then
      for _, dir in pairs{"north", "south", "east", "west"} do apply(anim[dir]) end
    else
      apply(anim)
    end
    return anim
  end

  local hidden = data.raw["lab"]["se-hidden-research-lab"]
  hidden.on_animation  = tint_anim(base_lab.on_animation,  {r=0.2, g=1.0, b=0.2, a=0.9}, 0.5)
  hidden.off_animation = tint_anim(base_lab.off_animation, {r=0.2, g=1.0, b=0.2, a=0.5}, 0.5)
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

-- ── Dynamic recipe generation ───────────────────────────────────────────────
-- One hidden recipe per unique pack combination found across all technologies.

local combos = {}  -- key → sorted pack name array

for _, tech in pairs(data.raw.technology) do
  if tech.unit and tech.unit.ingredients then
    local packs = {}
    for _, ing in pairs(tech.unit.ingredients) do
      local name = (type(ing) == "table") and (ing[1] or ing.name) or tostring(ing)
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

-- prototypes/entity/hidden-research-lab.lua
-- Internal lab spawned at the research assembler's position.
-- Void energy, high research speed. Animation patched in data-final-fixes.

local ALL_SCIENCE_PACKS = {
  "automation-science-pack",
  "logistic-science-pack",
  "military-science-pack",
  "chemical-science-pack",
  "production-science-pack",
  "utility-science-pack",
  "space-science-pack",
}
if mods["space-age"] then
  table.insert(ALL_SCIENCE_PACKS, "metallurgic-science-pack")
  table.insert(ALL_SCIENCE_PACKS, "electromagnetic-science-pack")
  table.insert(ALL_SCIENCE_PACKS, "agricultural-science-pack")
  table.insert(ALL_SCIENCE_PACKS, "cryogenic-science-pack")
  table.insert(ALL_SCIENCE_PACKS, "promethium-science-pack")
end

-- DEBUG: visible, selectable, shows on map.
data:extend({ {
  type = "lab",
  name = "se-hidden-research-lab",
  flags = { "placeable-off-grid", "not-blueprintable", "not-deconstructable" },
  hidden = false,
  selectable_in_game = true,
  collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
  selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
  collision_mask = { layers = {} },
  energy_source = { type = "void" },
  module_slots = 2,
  allowed_effects = { "productivity" },
  effect_receiver = { uses_beacon_effects = false },
  energy_usage = "1W",
  researching_speed = 10000,
  inputs = ALL_SCIENCE_PACKS,
  on_animation = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    frame_count = 1,
  },
  off_animation = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1,
    frame_count = 1,
  },
} })

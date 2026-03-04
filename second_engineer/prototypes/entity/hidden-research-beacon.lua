-- prototypes/entity/hidden-research-beacon.lua
-- Custom module category, hidden speed module, and hidden beacon for the research assembler.
-- The beacon sits at the assembler's position and distributes speed bonuses that mirror the
-- force's accumulated laboratory-speed technology bonus.
-- module_slots is patched in data-final-fixes.lua after all technologies are registered.

data:extend({
  {
    type = "module-category",
    name = "se-research-speed",
  },
  {
    type = "module",
    name = "se-research-speed-module",
    hidden = true,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    category = "se-research-speed",
    tier = 1,
    effect = { speed = 0.2 },  -- placeholder; patched in data-final-fixes
    stack_size = 200,
  },
  {
    type = "beacon",
    name = "se-research-speed-beacon",
    flags = {
      "placeable-off-grid",
      "not-blueprintable",
      "not-deconstructable",
    },
    hidden = true,
    selectable_in_game = false,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
    collision_mask = { layers = {} },
    energy_source = { type = "void" },
    energy_usage = "1W",
    supply_area_distance = 1,
    distribution_effectivity = 1,
    module_slots = 1,  -- patched in data-final-fixes to match lab-speed tech count
    allowed_module_categories = { "se-research-speed" },
    allowed_effects = { "speed" },
    graphics_set = {
      animation_list = {{
        render_layer = "object",
        always_draw = false,
        animation = {
          filename = "__core__/graphics/empty.png",
          width = 1,
          height = 1,
          frame_count = 1,
        },
      }},
    },
  },
})

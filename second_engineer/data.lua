-- second_engineer: data stage entry point

require("prototypes.item.scraps")

-- Recipe category: only se-research-assembler can craft these recipes
data:extend({{
  type = "recipe-category",
  name = "se-research-crafting",
}})

require("prototypes.entity.research-assembler")
require("prototypes.entity.hidden-research-lab")

-- Debug hotkey: clear the active inspect surface and respawn the core district.
data:extend({{
  type = "custom-input",
  name = "se-debug-reset-surface-core-district",
  key_sequence = "CONTROL + ALT + R",
  consuming = "none",
}})

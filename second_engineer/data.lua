-- second_engineer: data stage entry point

require("prototypes.item.scraps")

-- Recipe category: only se-research-assembler can craft these recipes
data:extend({{
  type = "recipe-category",
  name = "se-research-crafting",
}})

require("prototypes.entity.research-assembler")
require("prototypes.entity.hidden-research-lab")

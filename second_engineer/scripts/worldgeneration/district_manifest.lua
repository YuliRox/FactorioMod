local generated_core_district_manifest = require("scripts.worldgeneration.generated.core_district.manifest")

local bounds = generated_core_district_manifest.template.bounds
local width = math.floor(bounds.right_bottom.x - bounds.left_top.x + 1)
local height = math.floor(bounds.right_bottom.y - bounds.left_top.y + 1)

return {
  version = 2,
  id = "core_district_authored_v1",
  template = "central_district",
  package = "core_district",
  footprint = {width = width, height = height},
  defaults = {
    wear = {alive = 0.27, remnants = 0.25, missing = 0.48},
  },
  global_rules = {
    require_package_bounds = true,
    require_generated_sectors = true,
    preserve_authored_anchor = true,
    preserve_authored_shape = true,
    clear_decoratives_on_structures = true,
    preserve_early_scarcity_pressure = true,
  },
  blocks = {
    {
      id = "central_district",
      category = "authored",
      package = "core_district",
      template = "central_district",
      footprint = {width = width, height = height},
      wear = {alive = 0.27, remnants = 0.25, missing = 0.48},
      guarantees = {
        {name = "straight-rail-remnants", min_count = 700},
        {name = "stone-wall", min_count = 3000},
        {name = "assembling-machine-3", min_count = 50},
        {name = "electric-furnace", min_count = 25},
      },
    },
  },
}

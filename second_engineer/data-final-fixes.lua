-- second_engineer: data-final-fixes stage
-- Runs last. Requires override patches and generated recipes that depend on
-- the complete prototype tree (all mods' data and data-updates already done).

require("prototypes.override.furnace-output-slots")
require("prototypes.override.hidden-lab-animation")
require("prototypes.recipe.research-combos")

-- Scan all technologies for laboratory-speed effects (all mods registered by now).
-- Derive per-module speed bonus as the average modifier per level so that N modules
-- applied by the beacon exactly reproduce the speed bonus from N researched levels.
local lab_speed_levels = 0
local lab_speed_total  = 0.0
for _, tech in pairs(data.raw.technology) do
  if tech.effects then
    for _, effect in pairs(tech.effects) do
      if effect.type == "laboratory-speed" then
        lab_speed_levels = lab_speed_levels + 1
        lab_speed_total  = lab_speed_total + (effect.modifier or 0)
        break  -- count each tech once even if it carries multiple lab-speed modifiers
      end
    end
  end
end

local per_module_speed = lab_speed_levels > 0 and (lab_speed_total / lab_speed_levels) or 0.2

local beacon = data.raw["beacon"]["se-research-speed-beacon"]
if beacon then
  beacon.module_slots = math.max(lab_speed_levels, 1)
end

local speed_module = data.raw["module"]["se-research-speed-module"]
if speed_module then
  speed_module.effect.speed = per_module_speed
end

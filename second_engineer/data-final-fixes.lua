-- second_engineer: data-final-fixes stage
-- Runs last. Requires override patches and generated recipes that depend on
-- the complete prototype tree (all mods' data and data-updates already done).

require("prototypes.override.furnace-output-slots")
require("prototypes.override.hidden-lab-animation")
require("prototypes.recipe.research-combos")

-- Scan all technologies for laboratory-speed effects (all mods registered by now).
-- Each se-research-speed-module gives a fixed 10% speed boost; slot count is the
-- ceiling of the total accumulated lab-speed bonus divided by that fixed step.
local MODULE_SPEED    = 0.1
local lab_speed_total = 0.0
for _, tech in pairs(data.raw.technology) do
  if tech.effects then
    for _, effect in pairs(tech.effects) do
      if effect.type == "laboratory-speed" then
        lab_speed_total = lab_speed_total + (effect.modifier or 0)
        break  -- count each tech's contribution once
      end
    end
  end
end

local beacon = data.raw["beacon"]["se-research-speed-beacon"]
if beacon then
  beacon.module_slots = math.max(math.ceil(lab_speed_total / MODULE_SPEED), 1)
end

local speed_module = data.raw["module"]["se-research-speed-module"]
if speed_module then
  speed_module.effect.speed = MODULE_SPEED
end

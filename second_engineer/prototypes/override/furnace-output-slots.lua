-- prototypes/override/furnace-output-slots.lua
-- Required from data-final-fixes.lua (must run last — see rationale below).
--
-- Vanilla furnaces ship with result_inventory_size = 1, which only allows a
-- single output item per recipe. Our scrap-smelting recipes produce up to 2
-- distinct probabilistic results, so every furnace needs at least 2 slots.
--
-- Must run in data-final-fixes so the patch applies after all other mods have
-- registered their own furnace variants (including Space Age). math.max ensures
-- we never shrink a furnace that another mod already widened.

local REQUIRED_SLOTS = 2

for _, furnace in pairs(data.raw["furnace"]) do
  furnace.result_inventory_size = math.max(
    furnace.result_inventory_size or 1,
    REQUIRED_SLOTS
  )
end

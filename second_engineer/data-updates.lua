-- second_engineer: data-updates stage
-- Runs after all mods' data.lua. Used for patching existing prototypes.

-- Give all labs 13 trash slots:
--   12 for coloured scrap (one per science pack type)
--    1 for real spoilage output
for _, lab in pairs(data.raw["lab"]) do
  lab.trash_inventory_size = 13
end

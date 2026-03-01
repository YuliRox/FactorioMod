-- second_engineer: data-updates stage
-- Runs after all mods' data.lua. Used for patching existing prototypes.

-- Give all labs 13 trash slots:
--   12 for coloured scrap (one per science pack type)
--    1 for real spoilage output
for _, lab in pairs(data.raw["lab"]) do
  lab.trash_inventory_size = 13
end

if mods["AbandonedRuins_updated_fork"] then
  local setting = data.raw["string-setting"] and data.raw["string-setting"]["current-ruin-set"]
  if setting then
    local exists = false
    for _, value in ipairs(setting.allowed_values or {}) do
      if value == "second-engineer" then
        exists = true
        break
      end
    end

    if not exists then
      table.insert(setting.allowed_values, "second-engineer")
    end

    -- Default to the scenario's own ruin set when the engine is present and no
    -- other ruin set has been selected yet.
    if setting.default_value == "none" then
      setting.default_value = "second-engineer"
    end
  end
end

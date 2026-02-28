local ruin_set = require("scripts.worldgeneration.abandoned_ruins_set")

local abandoned_ruins = {}

local MOD_NAME = "AbandonedRuins_updated_fork"

function abandoned_ruins.is_available()
  return script.active_mods[MOD_NAME] ~= nil
end

function abandoned_ruins.register()
  if not abandoned_ruins.is_available() then return end
  if not (remote.interfaces and remote.interfaces["AbandonedRuins"]) then return end

  -- Design decision: keep Abandoned Ruins as the ambient ruin backend while
  -- preserving second_engineer's native starter ruins and scarcity logic.
  remote.call("AbandonedRuins", "add_ruin_sets", ruin_set.name, ruin_set.ruins)
end

return abandoned_ruins

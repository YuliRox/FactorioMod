-- scripts/pack_to_scrap.lua
-- Shared lookup: science pack name → scrap item name.
-- Safe to require from both data stage and runtime stage.

local space_age = (mods and mods["space-age"]) or (script and script.active_mods["space-age"])

local pack_to_scrap = {
  ["automation-science-pack"] = "scrap-red",
  ["logistic-science-pack"]   = "scrap-green",
  ["military-science-pack"]   = "scrap-black",
  ["chemical-science-pack"]   = "scrap-blue",
  ["production-science-pack"] = "scrap-purple",
  ["utility-science-pack"]    = "scrap-yellow",
  ["space-science-pack"]      = "scrap-white",
}

if space_age then
  pack_to_scrap["metallurgic-science-pack"]    = "scrap-metallurgic"
  pack_to_scrap["electromagnetic-science-pack"] = "scrap-electromagnetic"
  pack_to_scrap["agricultural-science-pack"]   = "scrap-agricultural"
  pack_to_scrap["cryogenic-science-pack"]      = "scrap-cryogenic"
  pack_to_scrap["promethium-science-pack"]     = "scrap-promethium"
end

return pack_to_scrap

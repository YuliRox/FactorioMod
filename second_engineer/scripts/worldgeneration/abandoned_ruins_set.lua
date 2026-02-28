local set = {}

local function nauvis_only()
  return {nauvis = true}
end

set.name = "second-engineer"

-- Design decision: this set is ambient world content for Nauvis, not the
-- handcrafted starter ruin. These ruins should reinforce the scenario's
-- salvage economy without replacing the authored bootstrap experience.
set.ruins = {
  small = {
    {
      name = "se-burner-outpost",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"burner-mining-drill-remnants", {x = -3, y = -2}},
        {"transport-belt-remnants", {x = -3, y = 0}},
        {"transport-belt-remnants", {x = -2, y = 0}},
        {"stone-furnace", {x = 0, y = -1}, {force = "player", dmg = {dmg = 140}}},
        {"stone-furnace", {x = 2, y = -1}, {force = "player", dmg = {dmg = 110}}},
        {"burner-inserter", {x = 0, y = 0}, {force = "player", dir = "north", dmg = {dmg = 120}}},
        {"wooden-chest", {x = 3, y = 1}, {force = "player", items = {
          ["coal"] = 16,
          ["repair-pack"] = 4,
          ["transport-belt"] = 12,
        }}},
      },
    },
    {
      name = "se-solar-scrap",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"solar-panel-remnants", {x = -3, y = -2}},
        {"solar-panel-remnants", {x = 0, y = -2}},
        {"solar-panel-remnants", {x = 3, y = -2}},
        {"solar-panel-remnants", {x = -3, y = 1}},
        {"solar-panel-remnants", {x = 0, y = 1}},
        {"medium-electric-pole-remnants", {x = 5, y = 0}},
        {"wooden-chest-remnants", {x = 2, y = 3}},
      },
    },
    {
      name = "se-overrun-patrol",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"tank-remnants", {x = 0, y = 0}},
        {"behemoth-worm-corpse", {x = -2, y = 2}},
        {"small-biter-corpse", {x = 2, y = 1}},
        {"small-biter-corpse", {x = 3, y = 2}},
        {"medium-biter-corpse", {x = -3, y = 1}},
        {"gun-turret-remnants", {x = 3, y = -1}},
        {"medium-scorchmark-tintable", {x = 1, y = 2}},
      },
    },
  },
  medium = {
    {
      name = "se-rail-loading-spur",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"straight-rail-remnants", {x = 0, y = -6}},
        {"straight-rail-remnants", {x = 0, y = -4}},
        {"straight-rail-remnants", {x = 0, y = -2}},
        {"straight-rail-remnants", {x = 0, y = 0}},
        {"train-stop-remnants", {x = 2, y = -3}},
        {"stack-inserter-remnants", {x = 2, y = 1}},
        {"stack-inserter-remnants", {x = 2, y = 2}},
        {"transport-belt-remnants", {x = 3, y = 3}},
        {"transport-belt-remnants", {x = 3, y = 4}},
        {"steel-chest-remnants", {x = 2, y = 5}},
        {"small-electric-pole-remnants", {x = 3, y = -1}},
      },
    },
    {
      name = "se-smelter-yard",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"transport-belt-remnants", {x = -4, y = 2}},
        {"transport-belt-remnants", {x = -3, y = 2}},
        {"transport-belt-remnants", {x = -2, y = 2}},
        {"stone-furnace", {x = -2, y = 0}, {force = "player", dmg = {dmg = 130}}},
        {"stone-furnace", {x = 0, y = 0}, {force = "player", dmg = {dmg = 160}}},
        {"stone-furnace", {x = 2, y = 0}, {force = "player", dmg = {dmg = 120}}},
        {"burner-inserter", {x = -2, y = 1}, {force = "player", dir = "north", dmg = {dmg = 120}}},
        {"burner-inserter", {x = 0, y = 1}, {force = "player", dir = "north", dmg = {dmg = 150}}},
        {"burner-inserter", {x = 2, y = 1}, {force = "player", dir = "north", dmg = {dmg = 100}}},
        {"small-electric-pole", {x = 4, y = 1}, {force = "player", dmg = {dmg = 110}}},
        {"wooden-chest", {x = 5, y = -1}, {force = "player", items = {
          ["iron-plate"] = 32,
          ["stone-brick"] = 16,
          ["repair-pack"] = 6,
        }}},
      },
    },
    {
      name = "se-defensive-line",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"wall-remnants", {x = -5, y = 0}},
        {"wall-remnants", {x = -4, y = 0}},
        {"wall-remnants", {x = -3, y = 0}},
        {"wall-remnants", {x = -2, y = 0}},
        {"laser-turret-remnants", {x = 0, y = -1}},
        {"artillery-turret-remnants", {x = 3, y = -1}},
        {"big-biter-corpse", {x = -5, y = 2}},
        {"big-biter-corpse", {x = -2, y = 3}},
        {"medium-biter-corpse", {x = -4, y = 2}},
        {"medium-biter-corpse", {x = 0, y = 2}},
        {"small-biter-corpse", {x = -6, y = 1}},
        {"small-biter-corpse", {x = -3, y = 2}},
        {"small-biter-corpse", {x = 1, y = 3}},
        {"medium-scorchmark-tintable", {x = 1, y = 1}},
      },
    },
  },
  large = {
    {
      name = "se-abandoned-subfactory",
      spawn_on_surfaces = nauvis_only(),
      entities = {
        {"assembling-machine-1", {x = -3, y = -2}, {force = "player", dmg = {dmg = 200}}},
        {"assembling-machine-1", {x = 0, y = -2}, {force = "player", dmg = {dmg = 230}}},
        {"assembling-machine-1", {x = 3, y = -2}, {force = "player", dmg = {dmg = 190}}},
        {"small-electric-pole", {x = -1, y = 1}, {force = "player", dmg = {dmg = 120}}},
        {"small-electric-pole", {x = 2, y = 1}, {force = "player", dmg = {dmg = 140}}},
        {"transport-belt-remnants", {x = -5, y = 3}},
        {"transport-belt-remnants", {x = -4, y = 3}},
        {"transport-belt-remnants", {x = -3, y = 3}},
        {"transport-belt-remnants", {x = -2, y = 3}},
        {"transport-belt-remnants", {x = 0, y = 3}},
        {"transport-belt-remnants", {x = 1, y = 3}},
        {"transport-belt-remnants", {x = 2, y = 3}},
        {"stone-furnace", {x = -4, y = -5}, {force = "player", dmg = {dmg = 140}}},
        {"stone-furnace", {x = -2, y = -5}, {force = "player", dmg = {dmg = 120}}},
        {"stone-furnace", {x = 0, y = -5}, {force = "player", dmg = {dmg = 180}}},
        {"stone-furnace", {x = 2, y = -5}, {force = "player", dmg = {dmg = 150}}},
        {"wooden-chest", {x = 5, y = 0}, {force = "player", items = {
          ["iron-gear-wheel"] = 24,
          ["electronic-circuit"] = 16,
          ["inserter"] = 8,
          ["repair-pack"] = 10,
        }}},
        {"steel-chest-remnants", {x = -6, y = 0}},
        {"medium-electric-pole-remnants", {x = 5, y = -3}},
      },
    },
  },
}

return set

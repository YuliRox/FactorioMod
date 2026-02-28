local Ruins = {}

Ruins.starter_cluster = {
  origin = {x = 52, y = -18},
  entities = {
    {name = "burner-mining-drill", offset = {x = -5, y = -4}, force = "player", health = 0.31, direction = defines.direction.south},
    {name = "transport-belt", offset = {x = -5, y = -1}, force = "player", health = 0.24, direction = defines.direction.east},
    {name = "transport-belt", offset = {x = -4, y = -1}, force = "player", health = 0.21, direction = defines.direction.east},
    {name = "transport-belt", offset = {x = -3, y = -1}, force = "player", health = 0.16, direction = defines.direction.east},
    {name = "transport-belt", offset = {x = -1, y = -1}, force = "player", health = 0.19, direction = defines.direction.east},
    {name = "transport-belt", offset = {x = 1, y = -1}, force = "player", health = 0.17, direction = defines.direction.east},
    {name = "burner-inserter", offset = {x = 0, y = -2}, force = "player", health = 0.28, direction = defines.direction.north},
    {name = "burner-inserter", offset = {x = 2, y = -2}, force = "player", health = 0.33, direction = defines.direction.north},
    {name = "stone-furnace", offset = {x = 0, y = -3}, force = "player", health = 0.42},
    {name = "stone-furnace", offset = {x = 2, y = -3}, force = "player", health = 0.38},
    {name = "stone-furnace", offset = {x = 5, y = -2}, force = "player", health = 0.24},
    {name = "assembling-machine-1", offset = {x = 5, y = 3}, force = "player", health = 0.29},
    {name = "small-electric-pole", offset = {x = 1, y = 3}, force = "player", health = 0.35},
    {name = "wooden-chest", offset = {x = 6, y = -1}, force = "neutral", health = 0.75, loot = {
      {name = "iron-plate", count = 32},
      {name = "copper-plate", count = 24},
      {name = "iron-gear-wheel", count = 16},
      {name = "transport-belt", count = 32},
      {name = "burner-mining-drill", count = 1},
      {name = "repair-pack", count = 12},
    }},
    {name = "wooden-chest", offset = {x = -3, y = 3}, force = "neutral", health = 0.68, loot = {
      {name = "stone-furnace", count = 2},
      {name = "pipe", count = 20},
      {name = "small-electric-pole", count = 6},
      {name = "iron-stick", count = 20},
      {name = "burner-inserter", count = 2},
    }},
  },
}

Ruins.starter_clear_area = {
  left_top = {x = 43, y = -25},
  right_bottom = {x = 64, y = -9},
}

Ruins.starter_decoration_points = {
  {offset = {x = -6, y = -4}},
  {offset = {x = -5, y = 6}},
  {offset = {x = -2, y = -5}},
  {offset = {x = 2, y = 6}},
  {offset = {x = 6, y = -5}},
  {offset = {x = 8, y = 4}},
}

return Ruins

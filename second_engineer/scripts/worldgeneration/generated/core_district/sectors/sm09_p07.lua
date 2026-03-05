local Sector = {
  sector = {
    x = -9,
    y = 7,
    key = "sm09_p07",
  },
  entities = {
    remnant = {},
    damaged_live = {
      {
        name = "stone-wall",
        offset = {
          x = -256.5,
          y = 225.5,
        },
        damage = 200,
      },
      {
        name = "stone-wall",
        offset = {
          x = -256.5,
          y = 227.5,
        },
        damage = 135,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

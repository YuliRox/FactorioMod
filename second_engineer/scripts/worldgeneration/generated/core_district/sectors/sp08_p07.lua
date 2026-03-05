local Sector = {
  sector = {
    x = 8,
    y = 7,
    key = "sp08_p07",
  },
  entities = {
    remnant = {},
    damaged_live = {
      {
        name = "stone-wall",
        offset = {
          x = 256.5,
          y = 224.5,
        },
        damage = 72,
      },
      {
        name = "stone-wall",
        offset = {
          x = 256.5,
          y = 226.5,
        },
        damage = 112,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

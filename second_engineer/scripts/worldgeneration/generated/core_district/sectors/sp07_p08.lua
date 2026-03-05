local Sector = {
  sector = {
    x = 7,
    y = 8,
    key = "sp07_p08",
  },
  entities = {
    remnant = {
      {
        name = nil,
        offset = {
          x = 227.5,
          y = 256.5,
        },
      },
    },
    damaged_live = {
      {
        name = "stone-wall",
        offset = {
          x = 225.5,
          y = 256.5,
        },
        damage = 181,
      },
      {
        name = "stone-wall",
        offset = {
          x = 224.5,
          y = 258.5,
        },
        damage = 97,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

local Sector = {
  sector = {
    x = 0,
    y = -6,
    key = "sp00_m06",
  },
  entities = {
    remnant = {
      {
        name = "rail-signal-remnants",
        offset = {
          x = 3.5,
          y = -182.5,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 5,
          y = -181,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 5,
          y = -173,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 5,
          y = -165,
        },
      },
      {
        name = nil,
        offset = {
          x = 24.5,
          y = -160.5,
        },
      },
    },
    damaged_live = {
      {
        name = "stone-wall",
        offset = {
          x = 0.5,
          y = -160.5,
        },
        damage = 139,
      },
      {
        name = "gate",
        offset = {
          x = 4.5,
          y = -160.5,
        },
        direction = 4,
        damage = 195,
      },
      {
        name = "stone-wall",
        offset = {
          x = 8.5,
          y = -160.5,
        },
        damage = 170,
      },
      {
        name = "stone-wall",
        offset = {
          x = 10.5,
          y = -160.5,
        },
        damage = 99,
      },
      {
        name = "stone-wall",
        offset = {
          x = 12.5,
          y = -160.5,
        },
        damage = 112,
      },
      {
        name = "stone-wall",
        offset = {
          x = 14.5,
          y = -160.5,
        },
        damage = 88,
      },
      {
        name = "stone-wall",
        offset = {
          x = 18.5,
          y = -160.5,
        },
        damage = 113,
      },
      {
        name = "stone-wall",
        offset = {
          x = 26.5,
          y = -160.5,
        },
        damage = 168,
      },
      {
        name = "stone-wall",
        offset = {
          x = 28.5,
          y = -160.5,
        },
        damage = 150,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

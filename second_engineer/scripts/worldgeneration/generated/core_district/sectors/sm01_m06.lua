local Sector = {
  sector = {
    x = -1,
    y = -6,
    key = "sm01_m06",
  },
  entities = {
    remnant = {
      {
        name = "rail-chain-signal-remnants",
        offset = {
          x = -3.5,
          y = -182.5,
        },
        direction = 8,
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = -5,
          y = -181,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = -5,
          y = -173,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = -5,
          y = -165,
        },
      },
      {
        name = nil,
        offset = {
          x = -23.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = -15.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = -3.5,
          y = -160.5,
        },
      },
    },
    damaged_live = {
      {
        name = "stone-wall",
        offset = {
          x = -27.5,
          y = -160.5,
        },
        damage = 146,
      },
      {
        name = "stone-wall",
        offset = {
          x = -21.5,
          y = -160.5,
        },
        damage = 216,
      },
      {
        name = "stone-wall",
        offset = {
          x = -17.5,
          y = -160.5,
        },
        damage = 204,
      },
      {
        name = "stone-wall",
        offset = {
          x = -13.5,
          y = -160.5,
        },
        damage = 155,
      },
      {
        name = "stone-wall",
        offset = {
          x = -11.5,
          y = -160.5,
        },
        damage = 146,
      },
      {
        name = "stone-wall",
        offset = {
          x = -7.5,
          y = -160.5,
        },
        damage = 171,
      },
      {
        name = "gate",
        offset = {
          x = -5.5,
          y = -160.5,
        },
        direction = 4,
        damage = 136,
      },
      {
        name = "stone-wall",
        offset = {
          x = -1.5,
          y = -160.5,
        },
        damage = 177,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

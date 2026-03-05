local Sector = {
  sector = {
    x = 3,
    y = -6,
    key = "sp03_m06",
  },
  entities = {
    remnant = {
      {
        name = "rail-chain-signal-remnants",
        offset = {
          x = 96.5,
          y = -182.5,
        },
        direction = 8,
      },
      {
        name = "rail-signal-remnants",
        offset = {
          x = 103.5,
          y = -182.5,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 105,
          y = -173,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 105,
          y = -165,
        },
      },
      {
        name = nil,
        offset = {
          x = 96.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = 110.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = 116.5,
          y = -160.5,
        },
      },
    },
    damaged_live = {
      {
        name = "big-electric-pole",
        offset = {
          x = 100,
          y = -178,
        },
        damage = 100,
      },
      {
        name = "stone-wall",
        offset = {
          x = 102.5,
          y = -160.5,
        },
        damage = 185,
      },
      {
        name = "gate",
        offset = {
          x = 104.5,
          y = -160.5,
        },
        direction = 4,
        damage = 214,
      },
      {
        name = "stone-wall",
        offset = {
          x = 106.5,
          y = -160.5,
        },
        damage = 218,
      },
      {
        name = "stone-wall",
        offset = {
          x = 112.5,
          y = -160.5,
        },
        damage = 199,
      },
      {
        name = "stone-wall",
        offset = {
          x = 118.5,
          y = -160.5,
        },
        damage = 164,
      },
      {
        name = "stone-wall",
        offset = {
          x = 120.5,
          y = -160.5,
        },
        damage = 70,
      },
      {
        name = "stone-wall",
        offset = {
          x = 122.5,
          y = -160.5,
        },
        damage = 162,
      },
      {
        name = "stone-wall",
        offset = {
          x = 124.5,
          y = -160.5,
        },
        damage = 206,
      },
      {
        name = "stone-wall",
        offset = {
          x = 126.5,
          y = -160.5,
        },
        damage = 174,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

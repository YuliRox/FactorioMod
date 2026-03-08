local Sector = {
  sector = {
    x = -3,
    y = -6,
    key = "sm03_m06",
  },
  entities = {
    remnant = {
      {
        name = "straight-rail-remnants",
        offset = {
          x = -95,
          y = -181,
        },
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = -95,
          y = -165,
        },
      },
      {
        name = nil,
        offset = {
          x = -85.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = -83.5,
          y = -160.5,
        },
      },
      {
        name = nil,
        offset = {
          x = -65.5,
          y = -160.5,
        },
      },
    },
    damaged_live = {
      {
        name = "straight-rail",
        offset = {
          x = -95,
          y = -173,
        },
        damage = 68,
      },
      {
        name = "stone-wall",
        offset = {
          x = -87.5,
          y = -160.5,
        },
        damage = 147,
      },
      {
        name = "stone-wall",
        offset = {
          x = -73.5,
          y = -160.5,
        },
        damage = 199,
      },
      {
        name = "stone-wall",
        offset = {
          x = -71.5,
          y = -160.5,
        },
        damage = 201,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

local Sector = {
  sector = {
    x = 5,
    y = 6,
    key = "sp05_p06",
  },
  entities = {
    remnant = {
      {
        name = "rail-chain-signal-remnants",
        offset = {
          x = 182.5,
          y = 196.5,
        },
        direction = 12,
      },
      {
        name = "rail-signal-remnants",
        offset = {
          x = 182.5,
          y = 203.5,
        },
        direction = 4,
      },
      {
        name = nil,
        offset = {
          x = 189,
          y = 193,
        },
        direction = 4,
      },
      {
        name = nil,
        offset = {
          x = 189,
          y = 193,
        },
        direction = 2,
      },
      {
        name = nil,
        offset = {
          x = 184,
          y = 195,
        },
        direction = 4,
      },
      {
        name = nil,
        offset = {
          x = 187,
          y = 198,
        },
        direction = 2,
      },
      {
        name = nil,
        offset = {
          x = 187,
          y = 202,
        },
        direction = 8,
      },
      {
        name = nil,
        offset = {
          x = 184,
          y = 205,
        },
        direction = 6,
      },
      {
        name = nil,
        offset = {
          x = 189,
          y = 207,
        },
        direction = 8,
      },
      {
        name = nil,
        offset = {
          x = 189,
          y = 207,
        },
        direction = 6,
      },
      {
        name = "straight-rail-remnants",
        offset = {
          x = 167,
          y = 205,
        },
        direction = 4,
      },
      {
        name = "accumulator-remnants",
        offset = {
          x = 160,
          y = 192,
        },
      },
      {
        name = "accumulator-remnants",
        offset = {
          x = 162,
          y = 192,
        },
      },
      {
        name = "accumulator-remnants",
        offset = {
          x = 170,
          y = 192,
        },
      },
      {
        name = "accumulator-remnants",
        offset = {
          x = 186,
          y = 192,
        },
      },
      {
        name = "big-electric-pole-remnants",
        offset = {
          x = 178,
          y = 222,
        },
      },
    },
    damaged_live = {
      {
        name = "straight-rail",
        offset = {
          x = 167,
          y = 195,
        },
        direction = 4,
        damage = 192,
      },
      {
        name = "accumulator",
        offset = {
          x = 176,
          y = 192,
        },
        damage = 144,
      },
      {
        name = "accumulator",
        offset = {
          x = 178,
          y = 192,
        },
        damage = 84,
      },
      {
        name = "accumulator",
        offset = {
          x = 180,
          y = 192,
        },
        damage = 161,
      },
    },
  },
  tiles = {
    foundation_kept = {},
    foundation_cracked = {},
  },
}

return Sector

# Large Ruin Runtime Strategy

## Problem

The current offline pipeline can successfully convert a large merged blueprint into:

- extracted JSON
- normalized merged JSON
- ruin-template intermediate JSON
- worn ruin JSON
- Lua export

That proves the conversion pipeline works, but it also shows the runtime problem clearly:

- one generated Lua module for a single large ruin is already close to 1 MB
- the goal is to support multiple ruins of this size
- loading several such templates directly into runtime worldgen is the wrong architecture

The current export format is therefore only an intermediate artifact, not the final runtime format.

## Core Decision

Large ruins must not be treated as "spawn this full giant table".

They need to be compiled offline into a chunk-aware runtime format that:

- is split into smaller pieces
- avoids storing repeated structures literally
- can be loaded and placed incrementally

## Recommended Runtime Strategy

### 1. Split mega-templates into sectors

Each large ruin should be compiled into smaller cells, for example:

- `32x32` tiles
- or `64x64` tiles

Runtime placement should then work sector-by-sector instead of trying to place the entire ruin at once.

This allows:

- chunk-aligned placement
- partial loading
- staged spawning over multiple ticks

### 2. Separate manifest from payload

Each large ruin package should have a small manifest file containing only control data, for example:

- template id
- total bounds
- sector list
- allowed surfaces / biome tags
- weight / rarity
- wear profile id

Then store the actual placement payload in separate per-sector files.

This keeps the always-loaded data small.

### 3. Compile repeated patterns into primitives

The rail and solar base contains massive repetition.

It is wasteful to store every surviving entity as a literal placement record if the same result can be described as a higher-level primitive.

Useful primitives would be:

- rail line segment
- rail corner / junction skeleton
- solar field rectangle
- accumulator strip
- foundation rectangle
- damaged infrastructure anchor

That means the compiled runtime format should not just be a huge list of entities. It should be a set of placement instructions.

### 4. Instantiate from rules, not raw dumps

Runtime should place from compiled instructions such as:

- place remnant rail skeleton across this span
- place solar-panel remnants from this rectangle mask
- place damaged substations at these anchor points
- place cracked foundation tiles from this mask

This reduces memory use and also gives variation for free.

### 5. Stream placement over time

Large ruins should not be spawned fully in one `on_chunk_generated` pass.

Instead:

- choose a ruin anchor
- enqueue its sectors
- place sectors over several ticks and/or chunks

That avoids heavy one-tick spikes.

### 6. Avoid giant always-loaded Lua modules

Large ruin data should not live as a few huge `require(...)` modules that are always loaded up front.

Instead:

- keep data split into smaller modules
- load only the selected ruin package
- ideally load only the sectors needed for active placement

## Proposed Pipeline

The pipeline should evolve into:

1. Blueprint extract
2. Normalize / merge
3. Ruin mapping
4. Wear pass
5. Compile into sectorized runtime package

## Proposed Runtime Package Shape

Example package layout:

```text
second_engineer/scripts/worldgeneration/generated/merged_rails_solar/
├── manifest.lua
├── sector_00_00.lua
├── sector_00_01.lua
├── sector_01_00.lua
└── sector_01_01.lua
```

`manifest.lua` should contain:

- name
- bounds
- sector size
- sector keys
- placement metadata

Each sector file should contain only that sector's compiled placement instructions.

## Specific Direction For The Rail-Solar Base

For the merged rail + solar template, the compiled runtime representation should likely contain:

- rail skeleton sectors
- solar field rectangle masks
- infrastructure anchor points
- damaged-live entity anchors
- foundation rectangles and cracked-tile masks

That is much more scalable than one enormous flat entity list.

## Immediate Next Step

Implement a compiler that takes the current worn JSON and emits a sectorized runtime package under:

`second_engineer/scripts/worldgeneration/generated/merged_rails_solar/`

That compiler should:

- choose a sector size
- split the template into sectors
- write one manifest
- write one payload file per sector
- prefer compact placement primitives where possible

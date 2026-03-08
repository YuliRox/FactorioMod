# Megabase Train Ruins

## Intent

Model the old world as a **ruined train megabase**:

- not one giant rectangle
- many specialized industrial districts
- connected by rail corridors
- partially destroyed, partially salvageable

The map should read like a broken industrial city, not random ruin props.

## Core District

The core district is the old operations/logistics hub, not heavy throughput production.

### Current Direction

The district workflow is now blueprint-first:

1. build the intended structure in Factorio
2. export the blueprint string
3. run it through the offline ruin pipeline
4. compile it into one generated runtime package
5. spawn that package from worldgen

The old hand-assembled multi-block core district plan is no longer the active implementation path.

### Core District Status

Core District is considered done for the current phase.

- source: authored blueprint
- pipeline output: compiled ruin package
- runtime package: `second_engineer/scripts/worldgeneration/generated/core_district/`
- worldgen status: spawned near player start and covered by stability/visual tests

### Core District v1 (Concrete Draft)

Target shape: one connected cluster near spawn, roughly `320x320` tiles, composed of 7 blocks with short rail/belt/power connectors between them.

This section is now historical design context only. Runtime no longer assembles the core district from these seven blocks.

1. Rail spine + junction
- footprint: `96x96`
- role: main in-district movement backbone and visual anchor
- minimum guaranteed survivors: one continuous rail line through the district center, at least two functioning signals, at least one functioning train stop
- wear target: `3% alive`, `10% remnants`, `87% missing`

2. Central depot + stacker fragment
- footprint: `96x96`
- role: provides obvious train logistics context and repair goals
- blueprint combination: `03-rails-barbone-grid.json` + `01-2-stations-low.json` + `07-cargo-unloading.json`
- note: this should read as a small depot throat and repairable siding/logistics stub, not a full multi-station terminal
- minimum guaranteed survivors: one chest cluster, one inserter chain, one short siding usable after limited repair
- wear target: `3% alive`, `10% remnants`, `87% missing`

3. Mall/service yard
- footprint: `128x96`
- role: early replacement parts and local rebuild incentive
- minimum guaranteed survivors: at least 2 assemblers, 6 inserters, 20 belt entities distributed across the block
- wear target: `5% alive`, `12% remnants`, `83% missing`

4. Light smelting fragment
- footprint: `96x96`
- role: teach repair loop, not solve economy
- minimum guaranteed survivors: at least 4 furnaces, 2 inserters, 1 short output belt lane
- wear target: `4% alive`, `10% remnants`, `86% missing`

5. Power distribution node
- footprint: `96x96`
- role: restore local grid first, then expand outward
- blueprint combination: `11-solar-grid.json` + `12-roboports-grid.json` + `03-rails-barbone-grid.json` + `00-power-barebone-grid.json`
- note: this is a local distribution/buffer node, not the district's sole long-term generation source
- minimum guaranteed survivors: at least 4 medium poles/substations, 8 solar panels, 4 accumulators
- wear target: `6% alive`, `12% remnants`, `82% missing`

6. Construction hub stub
- footprint: `64x64`
- role: obvious robotics/logistics repair objective
- minimum guaranteed survivors: one roboport, one storage/remnant storage cluster, one charging-area connection to power node
- wear target: `4% alive`, `12% remnants`, `84% missing`

7. Defense ring fragment
- footprint: perimeter strips around all blocks
- role: communicate prior war and define district boundary
- minimum guaranteed survivors: at least 40 intact wall segments distributed around edges, 2 intact turrets, several destroyed military remnants
- wear target: `5% alive`, `15% remnants`, `80% missing`

### Implementation Status (Current Branch)

Implemented:

1. Core district
- status: done for this phase
- implementation: one authored blueprint compiled into one ruin package
- runtime: spawned near start

Next district work should follow the same blueprint-first workflow.

Pending district families:

1. Blue circuits district
2. Oil / chemical district
3. Science district
4. Mining districts
- iron
- copper
- coal
- stone
- one additional ore-focused mining district as needed by gameplay scope
5. Rail-remnant connectors between districts

Still pending at system level:

1. scattered district rollout
- choose district anchors away from spawn
- place compiled packages deterministically across the world

2. rail corridor generation
- broken rail remnants should visually and logically connect the district families

Core district global rules:

1. Connectivity first
- At least one traversable path (rails + walkable corridors) must connect all seven blocks.

2. Power first-repair loop
- At least one broken-but-finishable local power chain from power node to mall and depot should be present.

3. No full automation on spawn
- The district must never start in a self-sustaining state; player must repair and recycle to bootstrap.

4. Visual readability
- Keep tree/decoration exclusion on top of structures.
- Allow biome-matching sparse vegetation around edges only.

5. Early-game pressure preserved
- Starter ore still limited and not enough for standard expansion-style opening.
- Core district repair should be cheaper than building equivalent capacity from raw ore.

### What a realistic core district contains

1. Rail control node
- central junction fragment
- signaling remains
- small depot/stacker remnants

2. Power distribution spine
- substations / medium-big poles
- accumulator fragments
- outgoing trunk lines to outer solar and nuclear districts

3. Mall/service remains
- assembler fragments
- belts/inserters/chest areas
- maintenance/build supply leftovers

4. Light bootstrap processing
- small local smelting fragment
- enough to teach repair/recovery, not enough to solve progression

5. Logistics buffers
- storage clusters
- short loading stubs
- pipe/utility junction remnants

6. Defense ring remnants
- walls/turrets/artillery scars
- evidence this area was defended more heavily

### Core district gameplay role

- immediate repair opportunities
- clear visual pointers to outer corridors
- recoverable early infrastructure
- still strongly broken so recycling remains mandatory

## Scattered District Parts

Train megabase ruins should be scattered and linked by broken rail lines.

### District types

1. Rail backbone districts
- main lines, intersections, depots, stackers, station throats

2. Ore intake + smelting districts
- ore unload
- buffers
- smelter rows
- plate loading

3. Power generation districts
- solar + accumulator fields
- outer nuclear block remnants as bulk generation for believable megabase-scale power
- power export nodes

4. Green circuit districts
- high-volume plate/cable feed
- large circuit output loading

5. Red/blue circuit districts
- higher-tier electronics blocks

6. Oil/chem districts
- refining/cracking
- plastic/sulfur/acid chains

7. Mall/service districts
- mixed utility production
- logistics support blocks

8. Science districts
- pack production fragments
- lab complex remnants

9. Military/defense districts
- perimeter lines
- artillery/turret nodes
- breach/battle remnants

### Active Build Order

The next authored blueprint targets are:

1. blue circuits
2. oil / chem
3. science
4. mining districts for iron, copper, coal, stone, and one additional ore-focused district
5. rail remnants connecting those districts

## Logical Groupings

Some parts should co-locate; others should be decoupled.

### Strong pairings

1. Ore intake + smelting + rail loading
2. Green circuits + strong plate/cable logistics
3. Oil refining + chem downstream
4. Solar + accumulators + substation trunk
5. Defense nodes + nearby power/logistics feed

### Not a primary pairing

- Solar farm + smelting is usually not a tight natural pair.
- Better: solar with power storage/distribution, and smelting with ore rail handling.

## Repeat vs Singleton Tendencies

Typical megabase behavior to mirror in ruins:

1. Usually repeated many times
- rail segments/junctions
- smelting blocks
- green circuit blocks
- solar fields
- defense segments

2. Usually few copies
- red/blue circuit blocks
- oil/chem complexes
- science/lab complexes
- nuclear plants (if present; at least one outer nuclear district is recommended)

3. Usually one core
- operations/mall-style main hub
- may have one backup service area

## Placement Direction (High-level)

1. Near spawn
- one core district ruin (guaranteed)

2. Early exploration ring
- several medium districts connected by broken rail hints

3. Outer bands
- repeated heavy-production districts
- larger rail backbone fragments
- stronger battle damage

## Blueprint Coverage (Current Extracted Set)

Based on:

- `tools/blueprint-extracted/root-modular-train-grid/*`

the current extracted blueprint catalog already covers almost all required scattered district types.

### District types we can build directly

1. Rail backbone districts
- Source books: `0-grid-rails`, `1-generic-stations`
- Available pieces: lines, grids, turns, paved rail variants, station throats, loading/unloading blocks, balancers, underground transitions.

2. Power districts
- Source books: `0-grid-rails`, `3-near-water`
- Available pieces: solar line/grid, power/roboport grid variants, `2.4 GW` nuclear block.

3. Ore intake + smelting districts
- Source books: `1-generic-stations`, `2-production`
- Available pieces: cargo/fluid station modules + iron/copper/steel/stone smelting.

4. Circuit/electronics districts
- Source book: `2-production`
- Available pieces: electronic circuits (green), red circuits, processing units (blue).

5. Oil/chem districts
- Source books: `3-near-water`, `2-production`
- Available pieces: oil processing, sulfur processing, pipelines, plastic, batteries, sulfuric acid handling.

6. Science districts
- Source book: `5-science`
- Available pieces: multiple SPM-scale science blocks + dedicated lab blocks + landing pad.

7. Mall/service district
- Source book: `2-production`
- Available piece: `18-mall.json` (direct mall/service core candidate).

8. Defense districts
- Source books: `4-defense`, `3-near-water`
- Available pieces: outer/inner/straight wall segments, artillery, ammo/combat support.

### Logical groupings supported by the current set

1. Rail backbone + stations
2. Stations + smelting
3. Oil + sulfur + pipelines + plastic/batteries
4. Solar + power distribution + roboport grids
5. Defense segments + ammo/combat support

## Immediate Implication

The current extracted set is sufficient to assemble a full ruined train-megabase ecosystem:

- one realistic core district
- multiple repeated outer production/power districts
- rail-linked station and logistics districts
- defense perimeter fragments

## Execution Plan (Next)

Use one controlled integration step focused on moving from debug near-spawn block placement to category-driven district spawning.

### 1. Finish core district v1 set

1. Stabilize defense perimeter placement around the core cluster.
2. Verify visible corner pieces on all four corners.
3. Ensure no defense segments spawn inside the interior district blocks.

### 2. Promote runtime to district categories

1. Keep one guaranteed `core` cluster near spawn.
2. Add `power` and `smelting` district categories as separate placements outside the start cluster.
3. Keep placement counts/rings data-driven through the district manifest.

### 3. Add overlap-safe placement retries

Before placing a category district:

1. check bounding-box collision vs already placed districts
2. retry alternative anchors when colliding
3. skip gracefully if retries are exhausted

### 4. Expand to outer production districts

After `core/power/smelting` placement loop is stable:

1. circuits (`green` then `red/blue`)
2. oil/chem
3. science
4. defense perimeter expansions

## Next Discussion (Tomorrow): Defense Placement Strategy

Current state:

1. Defense generation uses real straight/corner templates.
2. Placement math is still not producing a clean visible perimeter.
3. Corners are not reliably visible in-game.

Topics to decide:

1. Reference frame for perimeter placement
- should defense anchors be based on block anchors, block bounds, or an explicit district bounding box generated from placed blocks?

2. Ring distance policy
- fixed tile offset from district bounds vs. one-template-width offset vs. configurable per side.

3. Edge/corner ownership and overlap
- how to prevent corner/straight overlap from deleting or hiding corners.
- whether seams should intentionally overlap (blueprint-style) or be gap-joined.

4. Placement validation pass
- post-placement checks for each side/corner (`stone-wall`, turret counts, corner presence).
- if failed: retry with corrected offsets or fallback layout.

5. Debug instrumentation
- temporary tags for `defense_nw/ne/se/sw` and `defense_north/east/south/west`.
- optional one-time log dump of computed anchors and package bounds for quick diagnosis.

### 5. Iteration loop

Per tuning cycle:

1. regenerate with one chosen seam-policy preset
2. start a fresh world
3. inspect rail seams, overlap quality, and district readability
4. tune manifest values first (distance/repeat/wear), then code only if needed

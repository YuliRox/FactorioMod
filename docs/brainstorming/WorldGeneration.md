# World Generation

The document points in a clear direction: this is not a standard content mod with a few scarcity tweaks, it is a survival scenario where world generation has to enforce the economy.

The main constraints I take from [Zusammenfassung-AktuellerStand.txt](./Zusammenfassung-AktuellerStand.txt) are:

- The starting planet should feel post-exploitation: small, distant, expensive primary resources; lots of ruins; salvage is the early-game backbone.
- Recycling is not optional. World gen has to create a map where scrap, ruins, and recovery are more practical than normal ore expansion.
- Each planet needs mechanical identity, not just visual identity. That means world gen must differ by planet rules, not only by resource multipliers.
- Softlock prevention is mandatory. Scarcity can be harsh, but the generator must always preserve a recoverable path forward.

## Nauvis Target Experience

Nauvis remains the standard start planet, but it should feel visibly and mechanically exhausted.

- Accessible primary resources should support roughly 3 to 5 hours of normal play.
- That window is the player's transition period to establish recycling and salvage workflows.
- The player should not be able to sustain a conventional "mine more ore and build everything new" progression path for long.
- If the player insists on playing standard Factorio, they should hit resource pressure early and hard.
- Ruins must not be cosmetic. Some of them should be important enough that repairing and reusing them is materially cheaper than rebuilding from raw resources.
- Early progression should regularly present "repair vs scrap vs rebuild" as a real economic decision.
- Remote ore should create a second economic decision: whether it is worth exploiting at all once transport infrastructure costs are included.
- Some deposits should be so small or awkwardly placed that building tracks, power, defenses, and outpost infrastructure yields worse total material value than the field returns.

## Design Implications

These constraints push Nauvis generation toward a very specific shape:

1. Nearby ore exists, but in deliberately limited quantities.
2. Medium-term survival depends on recoverable value from ruins and scrap.
3. Useful ruined infrastructure must appear early enough that the player discovers repair as a valid strategy before the starting resource cushion is gone.
4. Fresh ore expansion should remain possible, but expensive enough that recycling is the intended answer, not a novelty system.
5. Distance alone is not enough; ore fields should often be marginal in net value after infrastructure investment.
6. The player should sometimes conclude that the correct move is to leave a deposit untouched.

For world generation, that implies we should design it around three layers instead of "just tune ore":

1. Terrain and resource distribution.
2. Ruin and salvage distribution.
3. Recovery guarantees and anti-softlock rules.

The right next step is to define the start planet generator first, because that sets the tone for the whole mod. I’d structure that discussion around:

1. What the player must reliably find in the first 30 minutes.
2. What should be scarce enough to force recycling.
3. What kinds of ruins should spawn, and how damaged/useful they should be.
4. How far "real" ore should be pushed out, and whether some of it should be hidden behind repair/power/logistics thresholds.

If you want, I can turn that into a concrete world-gen design spec for `Nauvis`, including chunk rules, ruin archetypes, salvage density, and softlock safeguards.

## First Draft: Nauvis World Generation

This is the current implemented draft. It is intentionally opinionated and should be treated as a tuning baseline, not final balance.

### Core Goal

Nauvis should give the player a short-lived illusion of normal Factorio expansion, then steadily punish that approach until salvage, repair, and recycling become the only efficient path forward.

### Generation Model

The current implementation combines three systems:

1. Custom Nauvis map-gen settings to suppress normal ore abundance.
2. Scripted `on_chunk_generated` post-processing to reshape ore, place ruins, and inject salvage opportunities.
3. Hard spawn-region guarantees to prevent softlocks and ensure the intended early-game discovery path.

### Phase Targets

The world should support these rough progression phases:

1. Phase 1, survival bootstrap, 0 to 60 minutes.
The player uses local ore, nearby hand-salvage, and the easiest ruins.

2. Phase 2, tightening pressure, 1 to 3 hours.
The player starts feeling that fresh builds are too expensive and begins reusing infrastructure.

3. Phase 3, forced transition, 3 to 5 hours.
The player can still mine, but standard expansion becomes materially worse than recycling and repair.

4. Phase 4, post-transition.
Ore is supplementary. Salvage and recycling are the economic core.

### Spawn Region Rules

The spawn area is currently designed, not random.

- The code clears vanilla resources in a `192x192` area around spawn and replaces them with a tighter fixed starter ring for iron, copper, coal, and stone so the player can reach bootstrap ore quickly.
- Those starting fields are intentionally smaller than vanilla and are meant to be a finite bootstrap, not a comfortable midgame resource base.
- The implementation actively stamps land under the starter patches using biome-matching replacement tiles and clears blocking trees, rocks, and cliffs around them so water or clutter cannot erase a guaranteed bootstrap deposit.
- The implementation also runs a post-generation verification pass for the authored starter area and re-stamps missing or undersized guaranteed patches.
- One small ruin cluster is guaranteed near spawn at approximately `(52, -18)`, and its footprint is cleared and stamped onto biome-matching land so it remains visible and usable without creating an obvious grass island in dry starts.
- That cluster is currently staged as a half-collapsed burner mining outpost, with a readable drill-to-belt-to-furnace flow, extra salvage chests, and light biome-aware dressing chosen from the surrounding native terrain rather than the stamped ruin footprint.
- The guaranteed starter ruin intentionally uses damaged live structures because it is meant to be repairable.
- The intended player choice in that cluster is already present in simple form: some parts are obvious repair candidates, while some are compact salvage.

### Ore Distribution Rules

In the current implementation, ore on Nauvis is divided into four distance bands.

1. Bootstrap fields.
These are near spawn, easy to reach, and deliberately limited.

2. Marginal outpost fields.
These are reachable in the early-to-mid game, but many should have poor net return once rails, poles, belts, defenses, and miners are counted.

3. Contested fields.
These are less punishing than the marginal band, but still visibly depleted compared to vanilla and not automatically worth the logistics cost.

4. Strategic fields.
These are the least degraded deposits, but they are still below vanilla abundance and intended to compete with salvage, not replace it.

The code currently enforces the following behaviors:

- Nearby fields are small enough that casual overbuilding burns through them quickly.
- Newly generated vanilla resource entities are probabilistically deleted or reduced in value based on chunk distance from spawn.
- Bootstrap and marginal bands are the harshest, so many early remote deposits are intentionally disappointing.
- Strategic fields survive more often and retain more value, but still remain well below vanilla abundance.
- The implementation currently creates economic pressure through scarcity and distance banding, not through special terrain shaping or threat-aware placement.

### Ruin Distribution Rules

Ruins are not decoration. They are embedded material reserves and alternative production paths.

The current implementation supports two ruin sources:

1. A guaranteed starter ruin cluster near spawn.
This teaches the system immediately.

2. Small procedural ruin fragments in generated chunks roughly 3 to 48 chunks from spawn.
These are drawn from a small remnant template library, including burner outpost wreckage, broken furnace lines, decayed assembly and transfer lines, power fragments, damaged utility leftovers, and a few battlefield wreck scenes.

3. A few guaranteed non-starter remnant anchors near the early scouting ring.
These ensure the world reads as ruined even if the procedural spray happens to miss the first nearby chunks, and they are now spread more aggressively around the early and mid scouting bands.

The implemented ruin palette currently covers:

- Furnace remnants.
- Burner drill remnants.
- Short belt fragments.
- Small power fragments.
- A damaged early assembler.
- Salvage chests with repair packs and basic materials.
- Repeated small remnant clusters sprayed across the map rather than a single repeated fragment.
- Several remnant templates are staged as visibly decayed production lines so experienced players can read the intended old workflow at a glance.
- Some remnant scenes are staged as failed defenses or lost expeditions, including wrecked heavy vehicles and scorched battle aftermath, so the world implies that biters did not merely inherit the ruins peacefully.
- Unlike the guaranteed starter ruin, these ambient scenes mostly use actual remnant or wreck entities rather than damaged repairable machines.
- Ambient remnant footprints clear blocking trees, rocks, and cliffs before placement so forest-heavy starts do not hide the authored scenes.

This is narrower than the full design goal. Mining outpost ruins, larger factory remnants, and richer mid-band and outer-band template sets are still future work.

### Repair Pressure Rules

To force repair as a valid strategy, ruins must sometimes contain expensive-to-replace structure density.

- Repaired ruins should often cost less than rebuilding the same capability from virgin resources.
- Some early ruins should already solve a problem the player is about to face, such as smelting, local power, or short-distance transport.
- Full teardown should be viable, but not always optimal.
- Damage states should be readable enough that the player can judge whether repair is sensible.

### Anti-Standard-Factorio Pressure

The scenario should actively punish pure greenfield growth.

- Ore alone should not comfortably support rebuilding every machine, belt line, and power system from scratch.
- Long transport corridors should be expensive relative to the deposits they unlock.
- Infrastructure cost should be part of the intended ore valuation problem, not an incidental inconvenience.
- The player should feel that replacing an existing ruin with a brand-new build is often wasteful.

### Softlock Safeguards

Harsh does not mean fragile.

The current implementation directly guarantees:

- Fixed starter patches for iron, copper, coal, and stone near spawn.
- A guaranteed nearby ruin cluster with basic loot, repair packs, and reusable infrastructure.
- A deterministic bootstrap layout instead of relying on vanilla spawn luck.
- A verification pass that rebuilds missing starter patches and re-stamps the guaranteed starter ruin cluster if generation leaves it in a bad state.

The following safeguards are still intended, but are not yet explicitly enforced in code:

- Validation that the guaranteed ruins are never placed in hostile-only access positions.
- Explicit science-path checks proving a recoverable route to red and green science after bad early decisions.

### First Technical Approach

This is currently implemented in two layers.

1. Map-gen preset changes.
Set Nauvis ore frequency, size, and richness well below vanilla so the base surface already trends toward scarcity.

2. Scripted post-processing.
Use `on_chunk_generated` to:
- thin or delete oversized ore patches
- cap local field value in early rings
- place ruin templates
- place salvage containers
- classify chunks into bootstrap, marginal, contested, and strategic resource bands

### Optional Integration: Abandoned Ruins Updated Fork

An external ruins engine is a viable option, but it should be treated as a controlled integration, not as a full replacement for the scenario logic.

Current recommendation:

1. Keep `second_engineer` in control of Nauvis scarcity and bootstrap guarantees.
2. Treat `AbandonedRuins_updated_fork` as an optional ruin spawning backend.
3. Restrict external ruin spawning to Nauvis first.
4. Use a custom `second_engineer` ruin set instead of the generic packs as the primary scenario content.

Why this split makes sense:

- Our scenario depends on deterministic early pressure, including fixed starter ore and a guaranteed repair-vs-scrap teaching moment near spawn.
- A generic ruin mod is useful for template spawning and content packaging, but it should not own the early-game economy.
- External ruins fit best in the mid-band and outer-band layers, where variety matters more than exact tutorial pacing.

Suggested integration stages:

1. Compatibility investigation.
Confirm the exact remote interface and ruin-set format exposed by `AbandonedRuins_updated_fork`.

2. Dependency strategy.
Decide whether `second_engineer` should use it as an optional dependency or whether a companion mod should carry the integration.

3. Surface policy.
Default external ruins to Nauvis only. Other Space Age surfaces should remain excluded until explicitly designed and tested.

4. Spawn ownership split.
Keep the guaranteed starter ruin cluster native to `second_engineer`.
Use the external ruins backend only for non-starter ruins.

5. Custom ruin set.
Author a `second_engineer` ruin pack containing repair-biased furnace blocks, damaged outposts, partial smelters, rail fragments, and abandoned utility infrastructure.

6. Economic tuning.
Tune external ruin frequency so they reinforce salvage play without overwhelming the scarcity curve.

Current unknowns:

- The exact remote interface contract still needs direct source verification.
- It is not yet decided whether the integration belongs in this mod or in a separate companion ruin-pack mod.
- We have not yet tested whether the external engine can cleanly respect our starter exclusion zone around spawn.

### Suggested First-Pass Tuning

These are draft targets, not final numbers.

- Spawn ore total: enough for early automation, basic defenses, and initial science, but not enough for a comfortable bus-first expansion.
- Expected standard-play exhaustion: around 3 to 5 hours.
- Inner ruin discovery time: within the first 10 to 20 minutes.
- First clearly repair-worthy ruin: within the first 30 to 45 minutes.
- Marginal remote ore fields: common.
- Clearly profitable remote ore fields: uncommon.

### Current Prototype Scope

The current prototype stays intentionally narrow.

1. Modify Nauvis ore downwards.
2. Guarantee one small spawn ruin cluster.
3. Add a very small procedural ruin fragment for generated chunks outside the spawn region.
4. Add distance-based ore degradation bands for remote fields.
5. Test whether a normal early bus approach collapses on schedule.
6. Test whether a player who salvages and repairs can stabilize.

### Open Balance Questions

These are the main variables we will need to tune after the first prototype:

1. How much starting ore produces 3 to 5 hours for an average player instead of an expert.
2. How many ruins near spawn are enough to teach the system without trivializing scarcity.
3. How often remote deposits should be net-negative.
4. How aggressive biter pressure should be on profitable remote fields.
5. Whether repair needs explicit mechanical bonuses beyond pure material savings.

#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const INPUT = path.join(
  __dirname,
  "blueprint-normalized",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.json"
);

const OUTPUT = path.join(
  __dirname,
  "ruin-templates",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.ruin-template.json"
);

const ENTITY_RULES = {
  "solar-panel": { strategy: "convert_to_remnant", target_name: "solar-panel-remnants", category: "power_generation" },
  "rail-chain-signal": { strategy: "convert_to_remnant", target_name: "rail-chain-signal-remnants", category: "rail_signal" },
  "rail-signal": { strategy: "convert_to_remnant", target_name: "rail-signal-remnants", category: "rail_signal" },

  "straight-rail": { strategy: "cluster_to_remnants", cluster: "rail_network", target_name: "straight-rail-remnants", category: "rail_track" },
  "curved-rail-a": { strategy: "cluster_to_remnants", cluster: "rail_network", target_name: null, category: "rail_track" },
  "curved-rail-b": { strategy: "cluster_to_remnants", cluster: "rail_network", target_name: null, category: "rail_track" },

  "accumulator": { strategy: "preserve_as_damaged", target_name: "accumulator", category: "power_storage" },
  "big-electric-pole": { strategy: "preserve_as_damaged", target_name: "big-electric-pole", category: "power_distribution" },
  "substation": { strategy: "preserve_as_damaged", target_name: "substation", category: "power_distribution" },
  "roboport": { strategy: "preserve_as_damaged", target_name: "roboport", category: "logistics" },
};

const TILE_RULES = {
  landfill: { strategy: "foundation", category: "terrain_support" },
  concrete: { strategy: "foundation", category: "terrain_support" },
  "hazard-concrete-left": { strategy: "foundation", category: "terrain_support" },
  "hazard-concrete-right": { strategy: "foundation", category: "terrain_support" },
  "refined-concrete": { strategy: "foundation", category: "terrain_support" },
  "refined-hazard-concrete-left": { strategy: "foundation", category: "terrain_support" },
  "refined-hazard-concrete-right": { strategy: "foundation", category: "terrain_support" },
  "stone-path": { strategy: "foundation", category: "terrain_support" },
};

function parseArgs(argv) {
  const args = {
    input: INPUT,
    output: OUTPUT,
    templateName: "se-merged-rails-solar-grid",
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      args.input = path.resolve(argv[++i]);
    } else if (arg === "--output") {
      args.output = path.resolve(argv[++i]);
    } else if (arg === "--template-name") {
      args.templateName = argv[++i];
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing input file: ${filePath}`);
  }

  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function keyForDirectionEntity(entity) {
  return [
    entity.target_name || entity.source_name,
    entity.position.x,
    entity.position.y,
    entity.direction ?? "",
  ].join("|");
}

function keyForSourceEntity(entity) {
  return [
    entity.name,
    entity.position.x,
    entity.position.y,
    entity.direction ?? "",
  ].join("|");
}

function keyForTile(tile) {
  return [tile.target_name || tile.source_name, tile.position.x, tile.position.y].join("|");
}

function dedupe(items, keyFn) {
  const seen = new Set();
  const result = [];

  for (const item of items) {
    const key = keyFn(item);
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    result.push(item);
  }

  return result;
}

function summarizeGroups(groups) {
  const summary = {};

  for (const [name, items] of Object.entries(groups)) {
    summary[name] = items.length;
  }

  return summary;
}

function groupBy(items, keyFn) {
  const groups = new Map();

  for (const item of items) {
    const key = keyFn(item);
    if (!groups.has(key)) {
      groups.set(key, []);
    }
    groups.get(key).push(item);
  }

  return groups;
}

function resolveEntityRule(name) {
  if (ENTITY_RULES[name]) {
    return ENTITY_RULES[name];
  }

  if (
    name === "medium-electric-pole" ||
    name === "small-electric-pole"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "power_distribution" };
  }

  if (
    name === "steel-chest" ||
    name === "iron-chest" ||
    name === "storage-chest" ||
    name === "passive-provider-chest" ||
    name === "active-provider-chest" ||
    name === "buffer-chest" ||
    name === "requester-chest"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "logistics" };
  }

  if (
    name === "transport-belt" ||
    name === "fast-transport-belt" ||
    name === "express-transport-belt" ||
    name === "underground-belt" ||
    name === "fast-underground-belt" ||
    name === "express-underground-belt" ||
    name === "splitter" ||
    name === "fast-splitter" ||
    name === "express-splitter"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "logistics" };
  }

  if (
    name === "inserter" ||
    name === "fast-inserter" ||
    name === "bulk-inserter" ||
    name === "long-handed-inserter"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "logistics" };
  }

  if (
    name === "assembling-machine-2" ||
    name === "assembling-machine-3" ||
    name === "electric-furnace" ||
    name === "chemical-plant" ||
    name === "oil-refinery"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "production" };
  }

  if (
    name === "gun-turret" ||
    name === "laser-turret" ||
    name === "flamethrower-turret"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "defense" };
  }

  if (name === "stone-wall" || name === "gate") {
    return { strategy: "preserve_as_damaged", target_name: name, category: "fortification" };
  }

  if (
    name === "beacon" ||
    name === "radar" ||
    name === "arithmetic-combinator" ||
    name === "constant-combinator" ||
    name === "selector-combinator" ||
    name === "small-lamp" ||
    name === "display-panel"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "control" };
  }

  if (
    name === "pipe" ||
    name === "pipe-to-ground" ||
    name === "pump" ||
    name === "storage-tank"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "fluid" };
  }

  if (
    name === "train-stop" ||
    name === "cargo-wagon" ||
    name === "locomotive"
  ) {
    return { strategy: "preserve_as_damaged", target_name: name, category: "rail_logistics" };
  }

  if (name === "stone-furnace") {
    return { strategy: "preserve_as_damaged", target_name: name, category: "production" };
  }

  return { strategy: "skip", category: "unmapped", target_name: null };
}

function cloneEntity(entity) {
  return {
    source_name: entity.source_name,
    target_name: entity.target_name,
    category: entity.category,
    cluster: entity.cluster,
    source_blueprint: entity.source_blueprint,
    position: entity.position,
    direction: entity.direction,
    type: entity.type,
  };
}

function collapseRailNetwork(clusterCandidates) {
  const curved = [];
  const straights = [];

  for (const entity of clusterCandidates) {
    if (entity.source_name === "straight-rail") {
      straights.push(entity);
    } else {
      curved.push(entity);
    }
  }

  const collapsed = curved.map(cloneEntity);

  const horizontalGroups = groupBy(
    straights.filter(function (entity) { return entity.direction === 4; }),
    function (entity) { return String(entity.position.y); }
  );
  const verticalGroups = groupBy(
    straights.filter(function (entity) { return entity.direction === undefined; }),
    function (entity) { return String(entity.position.x); }
  );

  function pushSampledLine(line, axis) {
    const sorted = line.slice().sort(function (a, b) {
      return axis === "x" ? a.position.x - b.position.x : a.position.y - b.position.y;
    });

    for (let i = 0; i < sorted.length; i = i + 1) {
      const isEdge = i === 0 || i === sorted.length - 1;
      const isSample = i % 4 === 0;
      if (isEdge || isSample) {
        collapsed.push(cloneEntity(sorted[i]));
      }
    }
  }

  for (const line of horizontalGroups.values()) {
    pushSampledLine(line, "x");
  }

  for (const line of verticalGroups.values()) {
    pushSampledLine(line, "y");
  }

  return dedupe(collapsed, keyForDirectionEntity);
}

function buildConnectorIndex(normalized) {
  const metadata = normalized.connector_metadata;
  const index = {
    keepSides: new Set(),
    dropSides: new Set(),
    sideToKeys: {},
  };

  if (!metadata || !metadata.strips) {
    return index;
  }

  for (const side of metadata.keep_sides || []) {
    index.keepSides.add(side);
  }
  for (const side of metadata.drop_sides || []) {
    index.dropSides.add(side);
  }

  for (const [side, strip] of Object.entries(metadata.strips)) {
    index.sideToKeys[side] = new Set((strip.entities || []).map(function (entity) {
      return entity.key;
    }));
  }

  return index;
}

function shouldPruneForConnectorSeam(entity, connectorIndex) {
  if (!connectorIndex || Object.keys(connectorIndex.sideToKeys).length === 0) {
    return false;
  }

  const key = keyForSourceEntity(entity);
  const touchedSides = [];

  for (const [side, keys] of Object.entries(connectorIndex.sideToKeys)) {
    if (keys.has(key)) {
      touchedSides.push(side);
    }
  }

  if (touchedSides.length === 0) {
    return false;
  }

  for (const side of touchedSides) {
    if (connectorIndex.keepSides.has(side)) {
      return false;
    }
  }

  for (const side of touchedSides) {
    if (connectorIndex.dropSides.has(side)) {
      return true;
    }
  }

  return false;
}

function main() {
  const args = parseArgs(process.argv);
  const normalized = readJson(args.input);
  const connectorIndex = buildConnectorIndex(normalized);
  const groupedEntities = {
    convert_to_remnant: [],
    cluster_to_remnants: [],
    preserve_as_damaged: [],
    skip: [],
  };
  const groupedTiles = {
    foundation: [],
    keep_literal: [],
    skip: [],
  };

  for (const entity of normalized.entities || []) {
    if (shouldPruneForConnectorSeam(entity, connectorIndex)) {
      groupedEntities.skip.push({
        source_name: entity.name,
        target_name: null,
        category: "seam_pruned",
        cluster: null,
        source_blueprint: entity.source || null,
        position: entity.position,
        direction: entity.direction,
        type: entity.type,
      });
      continue;
    }

    const rule = resolveEntityRule(entity.name);

    groupedEntities[rule.strategy].push({
      source_name: entity.name,
      target_name: rule.target_name,
      category: rule.category,
      cluster: rule.cluster || null,
      source_blueprint: entity.source || null,
      position: entity.position,
      direction: entity.direction,
      type: entity.type,
    });
  }

  for (const tile of normalized.tiles || []) {
    const rule = TILE_RULES[tile.name] || { strategy: "keep_literal", category: "unmapped", target_name: tile.name };

    groupedTiles[rule.strategy].push({
      source_name: tile.name,
      target_name: rule.target_name || tile.name,
      category: rule.category,
      source_blueprint: tile.source || null,
      position: tile.position,
    });
  }

  const collapsedRailSkeleton = collapseRailNetwork(groupedEntities.cluster_to_remnants);

  // Design decision: this intermediate file is for review and later worldgen
  // authoring, so it keeps strategy buckets instead of forcing every source
  // entity into a final Factorio prototype before the mapping is validated.
  const output = {
    template_name: args.templateName,
    source_file: args.input,
    source_label: normalized.label,
    anchor: normalized.anchor,
    bounds: normalized.bounds,
    connector_metadata: normalized.connector_metadata || null,
    mapping_notes: [
      "rail pieces are first marked as cluster candidates, then collapsed into a sparse rail remnant skeleton",
      "connector seam pruning drops ownership-conflicting edge entities before mapping",
      "signal and solar entities are mapped directly to remnant targets",
      "power poles, substations, accumulators, and roboports are kept as damaged live entities for now",
      "landfill is treated as foundation support, not as a literal ruined floor decision yet",
    ],
    stats: {
      input_entities: normalized.entity_count,
      input_tiles: normalized.tile_count,
      mapped_entities: summarizeGroups(groupedEntities),
      collapsed_cluster_entities: {
        rail_network_raw: groupedEntities.cluster_to_remnants.length,
        rail_network_collapsed: collapsedRailSkeleton.length,
      },
      mapped_tiles: summarizeGroups(groupedTiles),
    },
    entities: {
      convert_to_remnant: dedupe(groupedEntities.convert_to_remnant, keyForDirectionEntity),
      cluster_to_remnants: dedupe(groupedEntities.cluster_to_remnants, keyForDirectionEntity),
      collapsed_to_remnants: collapsedRailSkeleton,
      preserve_as_damaged: dedupe(groupedEntities.preserve_as_damaged, keyForDirectionEntity),
      skip: dedupe(groupedEntities.skip, keyForDirectionEntity),
    },
    tiles: {
      foundation: dedupe(groupedTiles.foundation, keyForTile),
      keep_literal: dedupe(groupedTiles.keep_literal, keyForTile),
      skip: dedupe(groupedTiles.skip, keyForTile),
    },
  };

  fs.mkdirSync(path.dirname(args.output), { recursive: true });
  fs.writeFileSync(args.output, `${JSON.stringify(output, null, 2)}\n`, "utf8");
  console.log(`Wrote ruin template to ${args.output}`);
}

main();

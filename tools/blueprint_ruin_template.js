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
};

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

function main() {
  const normalized = readJson(INPUT);
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
    const rule = ENTITY_RULES[entity.name] || { strategy: "skip", category: "unmapped", target_name: null };

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
    template_name: "se-merged-rails-solar-grid",
    source_file: INPUT,
    source_label: normalized.label,
    anchor: normalized.anchor,
    bounds: normalized.bounds,
    mapping_notes: [
      "rail pieces are first marked as cluster candidates, then collapsed into a sparse rail remnant skeleton",
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

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(output, null, 2)}\n`, "utf8");
  console.log(`Wrote ruin template to ${OUTPUT}`);
}

main();

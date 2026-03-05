#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const INPUTS = [
  path.join(__dirname, "blueprint-extracted", "root-modular-train-grid", "0-grid-rails", "03-rails-barbone-grid.json"),
  path.join(__dirname, "blueprint-extracted", "root-modular-train-grid", "0-grid-rails", "11-solar-grid.json"),
];

const OUTPUT = path.join(
  __dirname,
  "blueprint-normalized",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.json"
);
const SEAM_POLICY_PATH = path.join(__dirname, "seam_policy.json");

function parseArgs(argv) {
  const args = {
    seamPolicyPath: SEAM_POLICY_PATH,
  };

  for (let i = 0; i < argv.length; i = i + 1) {
    const arg = argv[i];
    if (arg === "--seam-policy") {
      i = i + 1;
      args.seamPolicyPath = path.resolve(argv[i]);
    } else if (arg === "--help" || arg === "-h") {
      console.log("Usage: node tools/blueprint_normalize_merge.js [--seam-policy path/to/policy.json]");
      process.exit(0);
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

function collectBounds(blueprint) {
  const positions = [];

  for (const entity of blueprint.entities || []) {
    positions.push(entity.position);
  }

  for (const tile of blueprint.tiles || []) {
    positions.push(tile.position);
  }

  if (positions.length === 0) {
    fail(`Blueprint has no entities or tiles: ${blueprint.label || "<unnamed>"}`);
  }

  const xs = positions.map(function (position) { return position.x; });
  const ys = positions.map(function (position) { return position.y; });

  return {
    left_top: { x: Math.min.apply(null, xs), y: Math.min.apply(null, ys) },
    right_bottom: { x: Math.max.apply(null, xs), y: Math.max.apply(null, ys) },
  };
}

function dedupeByKey(items, keyFn) {
  const seen = new Set();
  const deduped = [];

  for (const item of items) {
    const key = keyFn(item);
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    deduped.push(item);
  }

  return deduped;
}

function keyForEntity(entity) {
  return [
    entity.name,
    entity.position.x,
    entity.position.y,
    entity.direction ?? "",
  ].join("|");
}

function loadSeamPolicy(seamPolicyPath) {
  if (!fs.existsSync(seamPolicyPath)) {
    return {
      strip_width: 3,
      keep_sides: ["north", "west"],
      drop_sides: ["south", "east"],
      connector_entity_names: [
        "straight-rail",
        "curved-rail-a",
        "curved-rail-b",
        "rail-signal",
        "rail-chain-signal",
        "big-electric-pole",
        "substation",
        "roboport",
      ],
    };
  }

  const parsed = JSON.parse(fs.readFileSync(seamPolicyPath, "utf8"));
  return {
    strip_width: Number.isFinite(parsed.strip_width) ? parsed.strip_width : 3,
    keep_sides: Array.isArray(parsed.keep_sides) ? parsed.keep_sides : ["north", "west"],
    drop_sides: Array.isArray(parsed.drop_sides) ? parsed.drop_sides : ["south", "east"],
    connector_entity_names: Array.isArray(parsed.connector_entity_names)
      ? parsed.connector_entity_names
      : [
        "straight-rail",
        "curved-rail-a",
        "curved-rail-b",
        "rail-signal",
        "rail-chain-signal",
        "big-electric-pole",
        "substation",
        "roboport",
      ],
  };
}

function buildConnectorMetadata(entities, bounds, seamPolicy) {
  const stripWidth = seamPolicy.strip_width;
  const keepSides = seamPolicy.keep_sides;
  const dropSides = seamPolicy.drop_sides;
  const connectorEntityNames = new Set(seamPolicy.connector_entity_names);
  const strips = {
    north: {entities: []},
    east: {entities: []},
    south: {entities: []},
    west: {entities: []},
  };

  for (const entity of entities) {
    if (!connectorEntityNames.has(entity.name)) {
      continue;
    }

    if (entity.position.y <= bounds.left_top.y + stripWidth) {
      strips.north.entities.push({
        key: keyForEntity(entity),
        name: entity.name,
        position: entity.position,
        direction: entity.direction,
      });
    }

    if (entity.position.x >= bounds.right_bottom.x - stripWidth) {
      strips.east.entities.push({
        key: keyForEntity(entity),
        name: entity.name,
        position: entity.position,
        direction: entity.direction,
      });
    }

    if (entity.position.y >= bounds.right_bottom.y - stripWidth) {
      strips.south.entities.push({
        key: keyForEntity(entity),
        name: entity.name,
        position: entity.position,
        direction: entity.direction,
      });
    }

    if (entity.position.x <= bounds.left_top.x + stripWidth) {
      strips.west.entities.push({
        key: keyForEntity(entity),
        name: entity.name,
        position: entity.position,
        direction: entity.direction,
      });
    }
  }

  return {
    policy: seamPolicy,
    strip_width: stripWidth,
    keep_sides: keepSides,
    drop_sides: dropSides,
    strips: strips,
  };
}

function toRelativePosition(position, anchor) {
  return {
    x: position.x - anchor.x,
    y: position.y - anchor.y,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const sourceBlueprints = INPUTS.map(readJson);
  const seamPolicy = loadSeamPolicy(args.seamPolicyPath);
  const sourceMetadata = sourceBlueprints.map(function (blueprint, sourceIndex) {
    return {
      file: INPUTS[sourceIndex],
      label: blueprint.label || null,
      index: blueprint.index ?? null,
      grid: blueprint.grid || null,
      bounds: collectBounds(blueprint),
    };
  });

  // Design decision: use one shared absolute anchor for both source blueprints.
  // That keeps the solar block aligned inside the rail frame after merging.
  const anchor = {
    x: Math.min.apply(null, sourceMetadata.map(function (source) { return source.bounds.left_top.x; })),
    y: Math.min.apply(null, sourceMetadata.map(function (source) { return source.bounds.left_top.y; })),
  };

  const mergedEntities = [];
  const mergedTiles = [];

  for (let i = 0; i < sourceBlueprints.length; i = i + 1) {
    const blueprint = sourceBlueprints[i];
    const sourceLabel = blueprint.label || path.basename(INPUTS[i], ".json");

    for (const entity of blueprint.entities || []) {
      mergedEntities.push({
        source: sourceLabel,
        name: entity.name,
        position: toRelativePosition(entity.position, anchor),
        direction: entity.direction,
        type: entity.type,
      });
    }

    for (const tile of blueprint.tiles || []) {
      mergedTiles.push({
        source: sourceLabel,
        name: tile.name,
        position: toRelativePosition(tile.position, anchor),
      });
    }
  }

  // Design decision: drop only perfect overlaps. Near-duplicates are left
  // intact because later ruin conversion may still want both layers present.
  const entities = dedupeByKey(mergedEntities, function (entity) {
    return [
      entity.name,
      entity.position.x,
      entity.position.y,
      entity.direction ?? "",
      entity.type ?? "",
    ].join("|");
  });

  const tiles = dedupeByKey(mergedTiles, function (tile) {
    return [tile.name, tile.position.x, tile.position.y].join("|");
  });

  const allRelativePositions = entities.map(function (entity) { return entity.position; })
    .concat(tiles.map(function (tile) { return tile.position; }));
  const xs = allRelativePositions.map(function (position) { return position.x; });
  const ys = allRelativePositions.map(function (position) { return position.y; });

  const output = {
    label: "Merged Rails Barbone Grid + Solar Grid",
    sources: sourceMetadata,
    anchor: anchor,
    bounds: {
      left_top: { x: Math.min.apply(null, xs), y: Math.min.apply(null, ys) },
      right_bottom: { x: Math.max.apply(null, xs), y: Math.max.apply(null, ys) },
    },
    entity_count: entities.length,
    tile_count: tiles.length,
    connector_metadata: buildConnectorMetadata(entities, {
      left_top: {x: Math.min.apply(null, xs), y: Math.min.apply(null, ys)},
      right_bottom: {x: Math.max.apply(null, xs), y: Math.max.apply(null, ys)},
    }, seamPolicy),
    entities: entities,
    tiles: tiles,
  };

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(output, null, 2)}\n`, "utf8");
  console.log(`Wrote normalized merged blueprint to ${OUTPUT}`);
}

main();

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

function toRelativePosition(position, anchor) {
  return {
    x: position.x - anchor.x,
    y: position.y - anchor.y,
  };
}

function main() {
  const sourceBlueprints = INPUTS.map(readJson);
  const sourceMetadata = sourceBlueprints.map(function (blueprint, sourceIndex) {
    return {
      file: INPUTS[sourceIndex],
      label: blueprint.label || null,
      index: blueprint.index ?? null,
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
    entities: entities,
    tiles: tiles,
  };

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(output, null, 2)}\n`, "utf8");
  console.log(`Wrote normalized merged blueprint to ${OUTPUT}`);
}

main();

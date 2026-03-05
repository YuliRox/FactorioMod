#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    input: null,
    output: null,
    label: null,
    anchorX: 0,
    anchorY: 0,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      args.input = argv[++i];
    } else if (arg === "--output") {
      args.output = argv[++i];
    } else if (arg === "--label") {
      args.label = argv[++i];
    } else if (arg === "--anchor-x") {
      args.anchorX = Number(argv[++i]);
    } else if (arg === "--anchor-y") {
      args.anchorY = Number(argv[++i]);
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }

  if (!args.input || !args.output) {
    fail("Usage: node tools/blueprint_normalize_single.js --input <extracted.json> --output <normalized.json> [--label <label>] [--anchor-x <n>] [--anchor-y <n>]");
  }

  return args;
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing input file: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function collectBounds(positions) {
  if (positions.length === 0) {
    fail("Blueprint has no entities or tiles.");
  }

  let minX = positions[0].x;
  let minY = positions[0].y;
  let maxX = positions[0].x;
  let maxY = positions[0].y;

  for (let i = 1; i < positions.length; i += 1) {
    const position = positions[i];
    if (position.x < minX) minX = position.x;
    if (position.y < minY) minY = position.y;
    if (position.x > maxX) maxX = position.x;
    if (position.y > maxY) maxY = position.y;
  }

  return {
    left_top: {x: minX, y: minY},
    right_bottom: {x: maxX, y: maxY},
  };
}

function toRelative(position, anchor) {
  return {
    x: position.x - anchor.x,
    y: position.y - anchor.y,
  };
}

function dedupe(items, keyFn) {
  const seen = new Set();
  const out = [];

  for (const item of items) {
    const key = keyFn(item);
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    out.push(item);
  }

  return out;
}

function main() {
  const args = parseArgs(process.argv);
  const blueprint = readJson(args.input);
  const anchor = {x: args.anchorX, y: args.anchorY};

  const entities = dedupe((blueprint.entities || []).map((entity) => ({
    source: blueprint.label || path.basename(args.input, ".json"),
    name: entity.name,
    position: toRelative(entity.position, anchor),
    direction: entity.direction,
    type: entity.type,
  })), (entity) => [
    entity.name,
    entity.position.x,
    entity.position.y,
    entity.direction ?? "",
    entity.type ?? "",
  ].join("|"));

  const tiles = dedupe((blueprint.tiles || []).map((tile) => ({
    source: blueprint.label || path.basename(args.input, ".json"),
    name: tile.name,
    position: toRelative(tile.position, anchor),
  })), (tile) => [tile.name, tile.position.x, tile.position.y].join("|"));

  const bounds = collectBounds(
    entities.map((entity) => entity.position).concat(tiles.map((tile) => tile.position))
  );

  const output = {
    label: args.label || blueprint.label || path.basename(args.input, ".json"),
    sources: [{
      file: path.resolve(args.input),
      label: blueprint.label || null,
      index: blueprint.index ?? null,
      grid: blueprint.grid || null,
      bounds: bounds,
    }],
    anchor: anchor,
    bounds: bounds,
    entity_count: entities.length,
    tile_count: tiles.length,
    connector_metadata: null,
    entities: entities,
    tiles: tiles,
  };

  fs.mkdirSync(path.dirname(args.output), {recursive: true});
  fs.writeFileSync(args.output, `${JSON.stringify(output, null, 2)}\n`, "utf8");
  console.log(`Wrote normalized blueprint to ${args.output}`);
}

main();

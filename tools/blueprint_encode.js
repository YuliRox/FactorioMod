#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    input: null,
    output: null,
    stdout: false,
    label: null,
    description: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      i += 1;
      args.input = argv[i] || null;
    } else if (arg === "--output") {
      i += 1;
      args.output = argv[i] || null;
    } else if (arg === "--label") {
      i += 1;
      args.label = argv[i] || null;
    } else if (arg === "--description") {
      i += 1;
      args.description = argv[i] || null;
    } else if (arg === "--stdout") {
      args.stdout = true;
    } else if (arg === "--help" || arg === "-h") {
      console.log(`Usage: node tools/blueprint_encode.js --input path/to/layout.json [--output path/to/blueprint.txt] [--stdout]

Encodes the repo's extracted/authored blueprint JSON shape into a Factorio
blueprint string that can be imported in-game.
`);
      process.exit(0);
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }

  if (!args.input) {
    fail("Missing required --input path/to/layout.json");
  }
  if (!args.output && !args.stdout) {
    fail("Specify --output path/to/blueprint.txt and/or --stdout");
  }

  return args;
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing input file: ${filePath}`);
  }

  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    fail(`Failed to parse JSON ${filePath}: ${error.message}`);
  }
}

function clonePosition(position) {
  return {
    x: position.x,
    y: position.y,
  };
}

function encodeEntity(entity, entityNumber) {
  const out = {
    entity_number: entityNumber,
    name: entity.name,
    position: clonePosition(entity.position),
  };

  if (entity.direction !== undefined) out.direction = entity.direction;
  if (entity.type !== undefined) out.type = entity.type;
  if (entity.recipe !== undefined) out.recipe = entity.recipe;
  if (entity.bar !== undefined) out.bar = entity.bar;
  if (entity.control_behavior !== undefined) out.control_behavior = entity.control_behavior;
  if (entity.request_filters !== undefined) out.request_filters = entity.request_filters;
  if (entity.items !== undefined) out.items = entity.items;

  return out;
}

function encodeTile(tile) {
  return {
    name: tile.name,
    position: clonePosition(tile.position),
  };
}

function buildBlueprint(layout, args) {
  const entities = Array.isArray(layout.entities) ? layout.entities : [];
  const tiles = Array.isArray(layout.tiles) ? layout.tiles : [];
  const grid = layout.grid || {};
  const blueprint = {
    item: "blueprint",
    label: args.label || layout.label || "Authored Blueprint",
    description: args.description || layout.description || "",
    entities: entities.map(function (entity, index) {
      return encodeEntity(entity, index + 1);
    }),
  };

  if (tiles.length > 0) {
    blueprint.tiles = tiles.map(encodeTile);
  }
  if (grid.snap_to_grid) {
    blueprint.snap_to_grid = grid.snap_to_grid;
  }
  if (grid.absolute_snapping !== null && grid.absolute_snapping !== undefined) {
    blueprint.absolute_snapping = grid.absolute_snapping;
  }
  if (grid.position_relative_to_grid) {
    blueprint.position_relative_to_grid = grid.position_relative_to_grid;
  }

  return { blueprint };
}

function encodeBlueprintString(payload) {
  const json = JSON.stringify(payload);
  const compressed = zlib.deflateSync(Buffer.from(json, "utf8"));
  return `0${compressed.toString("base64")}`;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = path.resolve(args.input);
  const layout = readJson(inputPath);
  const payload = buildBlueprint(layout, args);
  const blueprintString = encodeBlueprintString(payload);

  if (args.output) {
    const outputPath = path.resolve(args.output);
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    fs.writeFileSync(outputPath, `${blueprintString}\n`, "utf8");
    console.log(`Wrote blueprint string: ${outputPath}`);
  }

  if (args.stdout) {
    process.stdout.write(`${blueprintString}\n`);
  }
}

main();

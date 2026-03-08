#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const DEFAULT_INPUT = path.join(
  __dirname,
  "ruin-templates-worn",
  "authored",
  "central-district.worn.json"
);

const DEFAULT_OUTPUT_ROOT = path.join(
  __dirname,
  "..",
  "second_engineer",
  "scripts",
  "worldgeneration",
  "generated",
  "core_district"
);

const SECTOR_SIZE = 32;

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const out = {
    input: DEFAULT_INPUT,
    outputRoot: DEFAULT_OUTPUT_ROOT,
  };

  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--input") {
      out.input = argv[++i];
    } else if (arg === "--output-root") {
      out.outputRoot = argv[++i];
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }

  if (!out.input || !out.outputRoot) {
    fail("Usage: node tools/blueprint_compile_sectors.js --input <worn.json> --output-root <dir>");
  }

  return out;
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`Missing input file: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function luaQuote(value) {
  return JSON.stringify(value);
}

function formatNumber(value) {
  if (Number.isInteger(value)) {
    return String(value);
  }
  return String(value);
}

function toLua(value, level) {
  const indent = "  ".repeat(level || 0);
  const childIndent = "  ".repeat((level || 0) + 1);

  if (value === null || value === undefined) {
    return "nil";
  }

  if (typeof value === "string") {
    return luaQuote(value);
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return "{}";
    }
    const lines = ["{"];
    for (const item of value) {
      lines.push(`${childIndent}${toLua(item, (level || 0) + 1)},`);
    }
    lines.push(`${indent}}`);
    return lines.join("\n");
  }

  const entries = Object.entries(value);
  if (entries.length === 0) {
    return "{}";
  }

  const lines = ["{"];
  for (const [key, item] of entries) {
    lines.push(`${childIndent}${key} = ${toLua(item, (level || 0) + 1)},`);
  }
  lines.push(`${indent}}`);
  return lines.join("\n");
}

function sectorCoord(offset) {
  return Math.floor(offset / SECTOR_SIZE);
}

function sectorKey(sx, sy) {
  const xx = sx < 0 ? `m${String(Math.abs(sx)).padStart(2, "0")}` : `p${String(sx).padStart(2, "0")}`;
  const yy = sy < 0 ? `m${String(Math.abs(sy)).padStart(2, "0")}` : `p${String(sy).padStart(2, "0")}`;
  return `s${xx}_${yy}`;
}

function ensureSector(sectors, sx, sy) {
  const key = sectorKey(sx, sy);
  if (!sectors[key]) {
    sectors[key] = {
      sector: {
        x: sx,
        y: sy,
        key: key,
      },
      entities: {
        remnant: [],
        damaged_live: [],
      },
      tiles: {
        foundation_kept: [],
        foundation_cracked: [],
      },
    };
  }
  return sectors[key];
}

function assignByOffset(sectors, item, targetArray) {
  const sx = sectorCoord(item.offset.x);
  const sy = sectorCoord(item.offset.y);
  const sector = ensureSector(sectors, sx, sy);
  sector[targetArray.group][targetArray.bucket].push(item);
}

function compactEntity(source) {
  const pos = source.offset || source.position;
  if (!pos) {
    fail(`Entity is missing position/offset: ${JSON.stringify(source).slice(0, 300)}`);
  }

  const out = {
    name: source.name || source.target_name,
    offset: {
      x: pos.x,
      y: pos.y,
    },
  };

  if (typeof source.direction === "number") {
    out.direction = source.direction;
  }

  if (typeof source.damage === "number") {
    out.damage = source.damage;
  }

  return out;
}

function compactTile(source) {
  const pos = source.offset || source.position;
  if (!pos) {
    fail(`Tile is missing position/offset: ${JSON.stringify(source).slice(0, 300)}`);
  }

  return {
    name: source.name || source.target_name,
    offset: {
      x: pos.x,
      y: pos.y,
    },
  };
}

function writeLuaModule(filePath, localName, data) {
  const body = toLua(data, 0);
  const output = `local ${localName} = ${body}\n\nreturn ${localName}\n`;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, output, "utf8");
}

function main() {
  const args = parseArgs(process.argv);
  const worn = readJson(args.input);
  const sectors = {};

  const remnantEntities = (worn.entities && worn.entities.remnant) || [];
  const damagedEntities = (worn.entities && worn.entities.damaged_live) || [];
  const keptTiles = (worn.tiles && worn.tiles.foundation_kept) || [];
  const crackedTiles = (worn.tiles && worn.tiles.foundation_cracked) || [];

  for (const entity of remnantEntities) {
    assignByOffset(sectors, compactEntity(entity), {group: "entities", bucket: "remnant"});
  }
  for (const entity of damagedEntities) {
    assignByOffset(sectors, compactEntity(entity), {group: "entities", bucket: "damaged_live"});
  }
  for (const tile of keptTiles) {
    assignByOffset(sectors, compactTile(tile), {group: "tiles", bucket: "foundation_kept"});
  }
  for (const tile of crackedTiles) {
    assignByOffset(sectors, compactTile(tile), {group: "tiles", bucket: "foundation_cracked"});
  }

  const keys = Object.keys(sectors).sort();

  const manifest = {
    template: {
      name: worn.template_name,
      wear_profile: worn.wear_profile,
      anchor: worn.anchor,
      bounds: worn.bounds,
    },
    sector_size: SECTOR_SIZE,
    sectors: keys.map(function (key) {
      const sector = sectors[key];
      return {
        key: key,
        x: sector.sector.x,
        y: sector.sector.y,
        counts: {
          remnant_entities: sector.entities.remnant.length,
          damaged_live_entities: sector.entities.damaged_live.length,
          kept_tiles: sector.tiles.foundation_kept.length,
          cracked_tiles: sector.tiles.foundation_cracked.length,
        },
      };
    }),
  };

  const manifestPath = path.join(args.outputRoot, "manifest.lua");
  writeLuaModule(manifestPath, "Manifest", manifest);

  const sectorsRoot = path.join(args.outputRoot, "sectors");
  for (const key of keys) {
    const sectorPath = path.join(sectorsRoot, `${key}.lua`);
    writeLuaModule(sectorPath, "Sector", sectors[key]);
  }

  console.log(`Wrote sectorized package to ${args.outputRoot}`);
  console.log(`Manifest: ${manifestPath}`);
  console.log(`Sectors: ${keys.length}`);
}

main();

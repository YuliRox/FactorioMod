#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const INPUT = path.join(
  __dirname,
  "ruin-templates-worn",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.worn.json"
);

const OUTPUT = path.join(
  __dirname,
  "..",
  "second_engineer",
  "scripts",
  "worldgeneration",
  "generated",
  "merged_rails_solar.lua"
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

function luaQuote(value) {
  return JSON.stringify(value);
}

function formatNumber(value) {
  if (Number.isInteger(value)) {
    return String(value);
  }
  return String(value);
}

function indent(level) {
  return "  ".repeat(level);
}

function renderArray(items, level, renderItem) {
  if (!items || items.length === 0) {
    return "{}";
  }

  const lines = ["{"];
  for (const item of items) {
    lines.push(`${indent(level + 1)}${renderItem(item, level + 1)},`);
  }
  lines.push(`${indent(level)}}`);
  return lines.join("\n");
}

function renderPosition(position) {
  return `{x = ${formatNumber(position.x)}, y = ${formatNumber(position.y)}}`;
}

function renderEntity(item) {
  const fields = [
    `name = ${luaQuote(item.target_name || item.source_name)}`,
    `offset = ${renderPosition(item.position)}`,
  ];

  if (typeof item.direction === "number") {
    fields.push(`direction = ${item.direction}`);
  }

  if (typeof item.damage === "number") {
    fields.push(`damage = ${item.damage}`);
  }

  if (typeof item.category === "string") {
    fields.push(`category = ${luaQuote(item.category)}`);
  }

  if (typeof item.source_blueprint === "string") {
    fields.push(`source = ${luaQuote(item.source_blueprint)}`);
  }

  return `{${fields.join(", ")}}`;
}

function renderTile(item) {
  const fields = [
    `name = ${luaQuote(item.target_name || item.source_name)}`,
    `offset = ${renderPosition(item.position)}`,
  ];

  if (typeof item.category === "string") {
    fields.push(`category = ${luaQuote(item.category)}`);
  }

  return `{${fields.join(", ")}}`;
}

function renderModule(data) {
  const lines = [];
  lines.push("local GeneratedRuin = {}");
  lines.push("");
  lines.push("-- Design decision: export the offline wear result as plain Lua data so");
  lines.push("-- runtime worldgen can consume it directly without JSON parsing.");
  lines.push("GeneratedRuin.template = {");
  lines.push(`  name = ${luaQuote(data.template_name)},`);
  lines.push(`  wear_profile = ${luaQuote(data.wear_profile)},`);
  lines.push(`  anchor = ${renderPosition(data.anchor)},`);
  lines.push("  bounds = {");
  lines.push(`    left_top = ${renderPosition(data.bounds.left_top)},`);
  lines.push(`    right_bottom = ${renderPosition(data.bounds.right_bottom)},`);
  lines.push("  },");
  lines.push(`  wear_notes = ${renderArray(data.wear_notes || [], 1, function (note) { return luaQuote(note); })},`);
  lines.push("  entities = {");
  lines.push(`    remnant = ${renderArray(data.entities.remnant || [], 2, renderEntity)},`);
  lines.push(`    damaged_live = ${renderArray(data.entities.damaged_live || [], 2, renderEntity)},`);
  lines.push(`    missing = ${renderArray(data.entities.missing || [], 2, renderEntity)},`);
  lines.push("  },");
  lines.push("  tiles = {");
  lines.push(`    foundation_kept = ${renderArray(data.tiles.foundation_kept || [], 2, renderTile)},`);
  lines.push(`    foundation_cracked = ${renderArray(data.tiles.foundation_cracked || [], 2, renderTile)},`);
  lines.push(`    foundation_missing = ${renderArray(data.tiles.foundation_missing || [], 2, renderTile)},`);
  lines.push("  },");
  lines.push("  stats = {");
  lines.push("    input = {");
  lines.push(`      remnant_candidates = ${data.stats.input.remnant_candidates},`);
  lines.push(`      damaged_live_candidates = ${data.stats.input.damaged_live_candidates},`);
  lines.push(`      foundation_tiles = ${data.stats.input.foundation_tiles},`);
  lines.push("    },");
  lines.push("    output_entities = {");
  lines.push(`      remnant = ${data.stats.output_entities.remnant},`);
  lines.push(`      damaged_live = ${data.stats.output_entities.damaged_live},`);
  lines.push(`      missing = ${data.stats.output_entities.missing},`);
  lines.push("    },");
  lines.push("    output_tiles = {");
  lines.push(`      foundation_kept = ${data.stats.output_tiles.foundation_kept},`);
  lines.push(`      foundation_cracked = ${data.stats.output_tiles.foundation_cracked},`);
  lines.push(`      foundation_missing = ${data.stats.output_tiles.foundation_missing},`);
  lines.push("    },");
  lines.push("  },");
  lines.push("}");
  lines.push("");
  lines.push("return GeneratedRuin");
  lines.push("");
  return lines.join("\n");
}

function main() {
  const data = readJson(INPUT);
  const lua = renderModule(data);
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, lua, "utf8");
  console.log(`Wrote Lua ruin module to ${OUTPUT}`);
}

main();

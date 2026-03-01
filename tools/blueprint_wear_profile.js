#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");

const INPUT = path.join(
  __dirname,
  "ruin-templates",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.ruin-template.json"
);

const OUTPUT = path.join(
  __dirname,
  "ruin-templates-worn",
  "root-modular-train-grid",
  "0-grid-rails",
  "merged-rails-barbone-grid-solar-grid.worn.json"
);

const PROFILE = {
  name: "abandoned-power-rail-grid-v1",
  remnantMissingRate: {
    rail_track: 0.87,
    rail_signal: 0.87,
    power_generation: 0.87,
  },
  remnantToLiveRate: {
    power_generation: 0.03,
  },
  liveMissingRate: {
    power_distribution: 0.87,
    power_storage: 0.87,
    logistics: 0.87,
  },
  liveToRemnantRate: {
    power_distribution: 0.10,
    power_storage: 0.10,
    logistics: 0.10,
  },
  foundationMissingRate: 0.08,
  foundationCrackedRate: 0.24,
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

function stableHash(text) {
  let hash = 2166136261;
  for (let i = 0; i < text.length; i = i + 1) {
    hash ^= text.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function scoreFor(item, templateName, salt) {
  const key = [
    templateName,
    salt,
    item.target_name || item.source_name || "",
    item.category || "",
    item.position ? item.position.x : "",
    item.position ? item.position.y : "",
    item.direction ?? "",
  ].join("|");
  return stableHash(key) / 4294967295;
}

function damageFor(item, templateName) {
  const roll = scoreFor(item, templateName, "damage");
  return 60 + Math.floor(roll * 160);
}

function remnantNameForLive(item) {
  const explicit = {
    accumulator: "accumulator-remnants",
    "big-electric-pole": "big-electric-pole-remnants",
    substation: "substation-remnants",
    roboport: "roboport-remnants",
  };
  return explicit[item.target_name] || explicit[item.source_name] || null;
}

function liveNameForRemnant(item) {
  const explicit = {
    "straight-rail-remnants": "straight-rail",
    "solar-panel-remnants": "solar-panel",
    "solar-panel": "solar-panel",
    "curved-rail-a": "curved-rail-a",
    "curved-rail-b": "curved-rail-b",
  };
  return explicit[item.target_name] || explicit[item.source_name] || null;
}

function summarize(obj) {
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    result[key] = Array.isArray(value) ? value.length : value;
  }
  return result;
}

function main() {
  const template = readJson(INPUT);

  const worn = {
    template_name: template.template_name,
    source_file: INPUT,
    wear_profile: PROFILE.name,
    anchor: template.anchor,
    bounds: template.bounds,
    wear_notes: [
      "deterministic wear pass keyed by template name and relative position",
      "rail skeleton and remnant-mapped entities can partially disappear",
      "preserved live infrastructure can become missing, become remnants, or stay as damaged live entities",
      "foundation tiles are thinned and marked for cracked treatment rather than kept fully intact",
    ],
    entities: {
      remnant: [],
      damaged_live: [],
      missing: [],
    },
    tiles: {
      foundation_kept: [],
      foundation_cracked: [],
      foundation_missing: [],
    },
  };

  const remnantCandidates = []
    .concat(template.entities.convert_to_remnant || [])
    .concat(template.entities.collapsed_to_remnants || []);

  for (const item of remnantCandidates) {
    const missingRate = PROFILE.remnantMissingRate[item.category] ?? 0.87;
    const toLiveRate = PROFILE.remnantToLiveRate[item.category] ?? 0.03;
    const roll = scoreFor(item, template.template_name, "remnant");
    if (roll < missingRate) {
      worn.entities.missing.push({
        source_name: item.source_name,
        target_name: item.target_name,
        category: item.category,
        source_blueprint: item.source_blueprint,
        position: item.position,
        direction: item.direction,
        reason: "wear_removed",
      });
      continue;
    }

    if (roll < missingRate + toLiveRate) {
      const localLiveName = liveNameForRemnant(item);
      if (localLiveName) {
        worn.entities.damaged_live.push({
          source_name: item.source_name,
          target_name: localLiveName,
          category: item.category,
          source_blueprint: item.source_blueprint,
          position: item.position,
          direction: item.direction,
          damage: damageFor(item, template.template_name),
        });
        continue;
      }
    }

    worn.entities.remnant.push({
      source_name: item.source_name,
      target_name: item.target_name,
      category: item.category,
      source_blueprint: item.source_blueprint,
      position: item.position,
      direction: item.direction,
    });
  }

  for (const item of template.entities.preserve_as_damaged || []) {
    const missingRate = PROFILE.liveMissingRate[item.category] ?? 0.87;
    const toRemnantRate = PROFILE.liveToRemnantRate[item.category] ?? 0.10;
    const roll = scoreFor(item, template.template_name, "live");

    if (roll < missingRate) {
      worn.entities.missing.push({
        source_name: item.source_name,
        target_name: item.target_name,
        category: item.category,
        source_blueprint: item.source_blueprint,
        position: item.position,
        direction: item.direction,
        reason: "wear_removed",
      });
      continue;
    }

    if (roll < missingRate + toRemnantRate) {
      worn.entities.remnant.push({
        source_name: item.source_name,
        target_name: remnantNameForLive(item),
        category: item.category,
        source_blueprint: item.source_blueprint,
        position: item.position,
        direction: item.direction,
      });
      continue;
    }

    worn.entities.damaged_live.push({
      source_name: item.source_name,
      target_name: item.target_name,
      category: item.category,
      source_blueprint: item.source_blueprint,
      position: item.position,
      direction: item.direction,
      damage: damageFor(item, template.template_name),
    });
  }

  for (const tile of template.tiles.foundation || []) {
    const roll = scoreFor(tile, template.template_name, "foundation");
    if (roll < PROFILE.foundationMissingRate) {
      worn.tiles.foundation_missing.push(tile);
    } else if (roll < PROFILE.foundationMissingRate + PROFILE.foundationCrackedRate) {
      worn.tiles.foundation_cracked.push(tile);
    } else {
      worn.tiles.foundation_kept.push(tile);
    }
  }

  worn.stats = {
    input: {
      remnant_candidates: remnantCandidates.length,
      damaged_live_candidates: (template.entities.preserve_as_damaged || []).length,
      foundation_tiles: (template.tiles.foundation || []).length,
    },
    output_entities: summarize(worn.entities),
    output_tiles: summarize(worn.tiles),
  };

  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(worn, null, 2)}\n`, "utf8");
  console.log(`Wrote worn ruin template to ${OUTPUT}`);
}

main();

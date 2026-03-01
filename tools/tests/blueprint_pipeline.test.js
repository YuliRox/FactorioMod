const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");
const {spawnSync} = require("node:child_process");

const REPO_ROOT = path.resolve(__dirname, "..", "..");

function runNodeScript(relativeScriptPath, args) {
  const result = spawnSync(process.execPath, [path.join(REPO_ROOT, relativeScriptPath)].concat(args || []), {
    cwd: REPO_ROOT,
    stdio: ["ignore", "pipe", "pipe"],
    encoding: "utf8",
  });

  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || `Script failed: ${relativeScriptPath}`);
  }
}

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8"));
}

function makeBlueprintString(payload) {
  return `0${zlib.deflateSync(Buffer.from(JSON.stringify(payload))).toString("base64")}`;
}

test("blueprint_extract exports one directory per book and one file per blueprint", function () {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "se-blueprint-extract-"));
  const inputPath = path.join(tempDir, "input.txt");
  const outputDir = path.join(tempDir, "out");

  const payload = {
    blueprint_book: {
      item: "blueprint-book",
      label: "Root Book",
      active_index: 0,
      blueprints: [
        {
          index: 0,
          blueprint_book: {
            item: "blueprint-book",
            label: "Grid Book",
            blueprints: [
              {
                index: 0,
                blueprint: {
                  item: "blueprint",
                  label: "Test Grid",
                  entities: [
                    {entity_number: 1, name: "solar-panel", position: {x: 1.5, y: 2.5}},
                    {entity_number: 2, name: "rail-signal", position: {x: 4.5, y: 6.5}, direction: 4},
                  ],
                  tiles: [
                    {name: "landfill", position: {x: 0, y: 0}},
                  ],
                },
              },
              {
                index: 1,
                blueprint: {
                  item: "blueprint",
                  label: "Other Grid",
                  entities: [
                    {entity_number: 1, name: "big-electric-pole", position: {x: 10, y: 10}},
                  ],
                  tiles: [],
                },
              },
            ],
          },
        },
      ],
    },
  };

  fs.writeFileSync(
    inputPath,
    `# comment line should be ignored\n${makeBlueprintString(payload)}\n`,
    "utf8"
  );

  runNodeScript("tools/blueprint_extract.js", ["--input", inputPath, "--output-dir", outputDir]);

  const bookDir = path.join(outputDir, "root-root-book", "0-grid-book");
  assert.ok(fs.existsSync(bookDir), "nested blueprint-book directory should exist");

  const files = fs.readdirSync(bookDir).sort();
  assert.deepEqual(files, ["00-test-grid.json", "01-other-grid.json"]);

  const extracted = JSON.parse(fs.readFileSync(path.join(bookDir, "00-test-grid.json"), "utf8"));
  assert.equal(extracted.label, "Test Grid");
  assert.equal(extracted.entity_count, 2);
  assert.equal(extracted.tile_count, 1);
  assert.deepEqual(extracted.entities[1], {
    name: "rail-signal",
    position: {x: 4.5, y: 6.5},
    direction: 4,
  });
});

test("normalize/ruin/wear/export pipeline keeps live solar panels in the final Lua module", function () {
  runNodeScript("tools/blueprint_normalize_merge.js");
  runNodeScript("tools/blueprint_ruin_template.js");
  runNodeScript("tools/blueprint_wear_profile.js");
  runNodeScript("tools/blueprint_export_lua.js");

  const normalized = readJson("tools/blueprint-normalized/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.json");
  assert.deepEqual(normalized.anchor, {x: -14, y: -14});
  assert.deepEqual(normalized.bounds, {
    left_top: {x: 0, y: 0},
    right_bottom: {x: 127, y: 127},
  });

  const ruinTemplate = readJson("tools/ruin-templates/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.ruin-template.json");
  assert.ok(
    ruinTemplate.stats.collapsed_cluster_entities.rail_network_collapsed <
      ruinTemplate.stats.collapsed_cluster_entities.rail_network_raw,
    "rail skeleton should be smaller than the raw rail cluster"
  );

  const worn = readJson("tools/ruin-templates-worn/root-modular-train-grid/0-grid-rails/merged-rails-barbone-grid-solar-grid.worn.json");
  const liveSolar = worn.entities.damaged_live.filter(function (entity) {
    return entity.target_name === "solar-panel";
  }).length;
  const remnantSolar = worn.entities.remnant.filter(function (entity) {
    return entity.target_name === "solar-panel-remnants";
  }).length;

  assert.ok(liveSolar > 0, "wear pass should preserve some solar panels as live entities");
  assert.ok(remnantSolar > 0, "wear pass should still leave some solar panel remnants");

  const luaPath = path.join(REPO_ROOT, "second_engineer", "scripts", "worldgeneration", "generated", "merged_rails_solar.lua");
  const lua = fs.readFileSync(luaPath, "utf8");

  assert.match(lua, /damaged_live = \{/);
  assert.match(lua, /name = "solar-panel"/);
  assert.match(lua, /name = "solar-panel-remnants"/);
  assert.match(lua, /return GeneratedRuin/);
});

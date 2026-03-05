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

function runCommand(command, args) {
  const result = spawnSync(command, args || [], {
    cwd: REPO_ROOT,
    stdio: ["ignore", "pipe", "pipe"],
    encoding: "utf8",
  });

  if (result.status !== 0) {
    throw new Error(result.stderr || result.stdout || `Command failed: ${command}`);
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
                  "snap-to-grid": {x: 100, y: 100},
                  "absolute-snapping": true,
                  "position-relative-to-grid": {x: 0, y: 0},
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
  assert.deepEqual(extracted.grid, {
    snap_to_grid: {x: 100, y: 100},
    absolute_snapping: true,
    position_relative_to_grid: {x: 0, y: 0},
  });
  assert.deepEqual(extracted.entities[1], {
    name: "rail-signal",
    position: {x: 4.5, y: 6.5},
    direction: 4,
  });
});

test("blueprint_encode produces a valid import string for the authored construction hub", function () {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), "se-blueprint-encode-"));
  const outputPath = path.join(tempDir, "construction-hub.txt");

  runNodeScript("tools/blueprint_encode.js", [
    "--input",
    "tools/blueprint-authored/core-construction-hub-working-64x64.json",
    "--output",
    outputPath,
  ]);

  const blueprintString = fs.readFileSync(outputPath, "utf8").trim();
  assert.match(blueprintString, /^0/);

  const inflated = zlib.inflateSync(Buffer.from(blueprintString.slice(1), "base64")).toString("utf8");
  const payload = JSON.parse(inflated);
  assert.equal(payload.blueprint.label, "Core Construction Hub Working 64x64");
  assert.equal(payload.blueprint.entities.length, 54);

  const tempInputPath = path.join(tempDir, "input.txt");
  const extractedDir = path.join(tempDir, "extracted");
  fs.writeFileSync(tempInputPath, `${blueprintString}\n`, "utf8");
  runNodeScript("tools/blueprint_extract.js", ["--input", tempInputPath, "--output-dir", extractedDir]);

  const rootEntry = fs.readdirSync(extractedDir).find((entry) => entry.startsWith("root-"));
  const rootDir = path.join(extractedDir, rootEntry);
  const extractedFile = fs.readdirSync(rootDir).find((entry) => entry.endsWith(".json"));
  const extracted = JSON.parse(fs.readFileSync(path.join(rootDir, extractedFile), "utf8"));

  assert.equal(extracted.entity_count, 54);
  assert.equal(extracted.tile_count, 0);
  assert.deepEqual(extracted.entities[0], {
    name: "roboport",
    position: {x: 20, y: 24},
  });
});

test("authored central district pipeline produces a compiled package with stable bounds and sectors", function () {
  runCommand("bash", ["tools/build_central_district_from_blueprint.sh"]);

  const normalized = readJson("tools/blueprint-normalized/authored/central-district.json");
  const worn = readJson("tools/ruin-templates-worn/authored/central-district.worn.json");
  const manifestLua = fs.readFileSync(
    path.join(
      REPO_ROOT,
      "second_engineer",
      "scripts",
      "worldgeneration",
      "generated",
      "core_district",
      "manifest.lua"
    ),
    "utf8"
  );

  assert.deepEqual(normalized.anchor, {x: 0, y: 0});
  assert.deepEqual(normalized.bounds, {
    left_top: {x: -282.5, y: -182.5},
    right_bottom: {x: 282.5, y: 282.5},
  });
  assert.equal(worn.entities.remnant.filter((entity) => entity.target_name === "straight-rail-remnants").length, 807);
  assert.equal(worn.entities.damaged_live.filter((entity) => entity.target_name === "stone-wall").length, 3622);
  assert.equal(worn.entities.damaged_live.filter((entity) => entity.target_name === "assembling-machine-3").length, 65);
  assert.equal(worn.entities.damaged_live.filter((entity) => entity.target_name === "electric-furnace").length, 32);
  assert.equal(worn.tiles.foundation_kept.length, 68739);
  assert.equal(worn.tiles.foundation_cracked.length, 23754);
  assert.match(manifestLua, /sector_size = 32/);
  assert.match(manifestLua, /x = -8,/);
  assert.match(manifestLua, /y = -6,/);
  assert.match(manifestLua, /x = 8,/);
  assert.match(manifestLua, /y = 8,/);
});

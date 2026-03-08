#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const DEFAULT_INPUT = path.join(__dirname, "blueprint-input.txt");
const DEFAULT_OUTPUT_DIR = path.join(__dirname, "blueprint-extracted");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function parseArgs(argv) {
  const args = {
    input: null,
    outputDir: DEFAULT_OUTPUT_DIR,
    string: null,
    stdout: false,
  };

  for (let i = 0; i < argv.length; i = i + 1) {
    const arg = argv[i];

    if (arg === "--input") {
      i = i + 1;
      args.input = argv[i];
    } else if (arg === "--output-dir") {
      i = i + 1;
      args.outputDir = argv[i];
    } else if (arg === "--output") {
      i = i + 1;
      args.outputDir = argv[i];
    } else if (arg === "--string") {
      i = i + 1;
      args.string = argv[i];
    } else if (arg === "--stdout") {
      args.stdout = true;
      args.outputDir = null;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

function printHelp() {
  console.log(`Usage:
  npm run blueprint:extract
  npm run blueprint:extract -- --stdout
  npm run blueprint:extract -- --input path/to/blueprint.txt
  npm run blueprint:extract -- --output-dir path/to/exported-books
  npm run blueprint:extract -- --string "0eN..."

Default behavior:
  - Reads the blueprint string from tools/blueprint-input.txt
  - Writes one directory per blueprint book into tools/blueprint-extracted/

What gets extracted:
  - one directory per blueprint book
  - one JSON file per blueprint
  - per blueprint: entities[] with name, type, position, direction
  - per blueprint: tiles[] with name, position
`);
}

function readStdinIfPresent() {
  if (process.stdin.isTTY) {
    return null;
  }

  const data = fs.readFileSync(0, "utf8").trim();
  return data.length > 0 ? data : null;
}

function extractBlueprintStringFromText(text) {
  const lines = text
    .split(/\r?\n/)
    .map(function (line) {
      return line.trim();
    })
    .filter(function (line) {
      return line !== "" && !line.startsWith("#");
    });

  if (lines.length === 0) {
    return "";
  }

  return lines.join("");
}

function readBlueprintString(args) {
  if (typeof args.string === "string" && args.string.trim() !== "") {
    return args.string.trim();
  }

  const stdinValue = readStdinIfPresent();
  if (stdinValue) {
    return stdinValue;
  }

  const inputPath = args.input || DEFAULT_INPUT;
  if (!fs.existsSync(inputPath)) {
    fail(`Blueprint input not found: ${inputPath}`);
  }

  const rawValue = fs.readFileSync(inputPath, "utf8");
  const value = extractBlueprintStringFromText(rawValue);
  if (value === "") {
    fail(`Blueprint input file is empty: ${inputPath}`);
  }

  return value;
}

function decodeBlueprintString(blueprintString) {
  // Design decision: keep the decoder dependency-free so the import pipeline
  // stays easy to run locally for quick ruin authoring iterations.
  if (blueprintString[0] !== "0") {
    fail("Unsupported blueprint string version. Expected a Factorio 0-prefixed blueprint string.");
  }

  let compressed;
  try {
    compressed = Buffer.from(blueprintString.slice(1), "base64");
  } catch (error) {
    fail(`Failed to base64 decode blueprint string: ${error.message}`);
  }

  let jsonString;
  try {
    jsonString = zlib.inflateSync(compressed).toString("utf8");
  } catch (error) {
    fail(`Failed to inflate blueprint string: ${error.message}`);
  }

  try {
    return JSON.parse(jsonString);
  } catch (error) {
    fail(`Failed to parse blueprint JSON: ${error.message}`);
  }
}

function roundCoordinate(value) {
  return Math.round(value * 1000) / 1000;
}

function sanitizeFilePart(value) {
  return String(value || "unnamed-book")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-{2,}/g, "-") || "unnamed-book";
}

function extractBlueprint(blueprint, meta) {
  const entities = Array.isArray(blueprint.entities) ? blueprint.entities : [];
  const tiles = Array.isArray(blueprint.tiles) ? blueprint.tiles : [];
  const grid = {
    snap_to_grid: blueprint["snap-to-grid"] || blueprint.snap_to_grid || null,
    absolute_snapping: blueprint["absolute-snapping"] ?? blueprint.absolute_snapping ?? null,
    position_relative_to_grid: blueprint["position-relative-to-grid"] || blueprint.position_relative_to_grid || null,
  };

  return {
    index: meta.index ?? null,
    label: blueprint.label || null,
    description: blueprint.description || null,
    grid: grid,
    entity_count: entities.length,
    tile_count: tiles.length,
    entities: entities.map(function (entity) {
      const extracted = {
        name: entity.name,
        position: {
          x: roundCoordinate(entity.position.x),
          y: roundCoordinate(entity.position.y),
        },
      };

      if (typeof entity.direction === "number") {
        extracted.direction = entity.direction;
      }

      if (typeof entity.type === "string") {
        extracted.type = entity.type;
      }

      return extracted;
    }),
    tiles: tiles.map(function (tile) {
      return {
        name: tile.name,
        position: {
          x: roundCoordinate(tile.position.x),
          y: roundCoordinate(tile.position.y),
        },
      };
    }),
  };
}

function buildBookTree(node, pathParts) {
  if (!node.blueprint_book || !Array.isArray(node.blueprint_book.blueprints)) {
    fail("Decoded data does not contain a blueprint or blueprint book.");
  }

  const book = node.blueprint_book;
  const tree = {
    name: `${pathParts.length > 0 ? `${pathParts[pathParts.length - 1]}-` : "root-"}${sanitizeFilePart(book.label)}`,
    book: {
      label: book.label || null,
      path: pathParts.slice(),
      path_string: pathParts.length > 0 ? pathParts.join(".") : "root",
      blueprint_count: 0,
      nested_book_count: 0,
    },
    blueprints: [],
    books: [],
  };

  for (const entry of book.blueprints) {
    if (entry.blueprint) {
      tree.blueprints.push({
        file_name: `${String(entry.index ?? tree.blueprints.length).padStart(2, "0")}-${sanitizeFilePart(entry.blueprint.label)}.json`,
        data: extractBlueprint(entry.blueprint, { index: entry.index }),
      });
    } else if (entry.blueprint_book) {
      tree.books.push(buildBookTree(entry, pathParts.concat(entry.index ?? 0)));
    }
  }

  tree.book.blueprint_count = tree.blueprints.length;
  tree.book.nested_book_count = tree.books.length;
  return tree;
}

function exportBooks(decoded) {
  if (decoded.blueprint) {
    return {
      name: "root-single-blueprint",
      book: {
        label: decoded.blueprint.label || null,
        path: [],
        path_string: "root",
        blueprint_count: 1,
        nested_book_count: 0,
      },
      blueprints: [
        {
          file_name: `00-${sanitizeFilePart(decoded.blueprint.label)}.json`,
          data: extractBlueprint(decoded.blueprint, { index: null }),
        },
      ],
      books: [],
    };
  }

  return buildBookTree(decoded, []);
}

function writeBookTree(bookTree, outputDir) {
  const bookDir = path.join(outputDir, bookTree.name);
  fs.mkdirSync(bookDir, { recursive: true });

  for (const blueprint of bookTree.blueprints) {
    fs.writeFileSync(path.join(bookDir, blueprint.file_name), `${JSON.stringify(blueprint.data, null, 2)}\n`, "utf8");
  }

  for (const nestedBook of bookTree.books) {
    writeBookTree(nestedBook, bookDir);
  }

  return countBookTree(bookTree);
}

function countBookTree(bookTree) {
  let bookCount = 1;
  let blueprintCount = bookTree.blueprints.length;

  for (const nestedBook of bookTree.books) {
    const nestedCounts = countBookTree(nestedBook);
    bookCount += nestedCounts.bookCount;
    blueprintCount += nestedCounts.blueprintCount;
  }

  return { bookCount, blueprintCount };
}

function writeStdout(bookTree) {
  process.stdout.write(`${JSON.stringify(bookTree, null, 2)}\n`);
}

function main() {
  try {
    const args = parseArgs(process.argv.slice(2));
    const blueprintString = readBlueprintString(args);
    const decoded = decodeBlueprintString(blueprintString);
    const exportedBooks = exportBooks(decoded);

    if (args.stdout) {
      writeStdout(exportedBooks);
    } else {
      fs.mkdirSync(args.outputDir, { recursive: true });
      const counts = writeBookTree(exportedBooks, args.outputDir);
      console.log(`Wrote ${counts.blueprintCount} blueprint file(s) across ${counts.bookCount} blueprint book director${counts.bookCount === 1 ? "y" : "ies"} to ${args.outputDir}`);
    }
  } catch (error) {
    fail(error && error.message ? error.message : String(error));
  }
}

main();

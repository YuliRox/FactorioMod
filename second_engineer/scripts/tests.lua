-- scripts/tests.lua
-- Test coordinator: require all test modules here.
-- This file is the single entry point passed to __factorio-test__/init in control.lua.

-- Research assembler tests are intentionally optional on this branch because
-- the file is aligned to main and may not exist in every feature worktree.
require("tests.worldgen")
require("tests.core_district_manifest")
require("tests.worldgen_desert_core_district")
require("tests.worldgen_perimeter_authoring_surface")
require("tests.worldgen_visual_inspection")

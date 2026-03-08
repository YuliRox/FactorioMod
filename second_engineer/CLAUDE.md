# second_engineer — Mod Root Instructions

`AGENTS.md` in this directory is a symlink to this file so Codex and Claude Code share the same subtree instructions. Edit this `CLAUDE.md` target, not the symlink.

## Scope

This directory is the Factorio mod root. Changes here affect what the game loads.

Before editing Lua files in this subtree, read and follow [../.claude/rules/second_engineer/lua-guidelines.md](../.claude/rules/second_engineer/lua-guidelines.md).

## Load Order

1. `settings.lua` if present
2. `data.lua`
3. `data-updates.lua`
4. `data-final-fixes.lua`
5. `control.lua`
6. `scripts/` runtime modules

Use the correct stage for each change. Do not put runtime logic in data stage files or prototype definitions in `control.lua`.

## Edit Boundaries

- `data.lua`, `data-updates.lua`, `data-final-fixes.lua`: prototype registration, patching, and late data-stage generation.
- `prototypes/`: prototype definitions and data-stage modules.
- `control.lua`: runtime event wiring and top-level orchestration.
- `scripts/`: runtime systems such as worldgen, ruins, research, and test helpers.
- `tests/`: Factorio-side verification helpers and authoring/inspection fixtures.
- `locale/`: names, descriptions, and player-facing strings.

## Generated Files

These paths are generated artifacts and should not be hand-edited unless the task is explicitly about generated output debugging:

- `scripts/worldgeneration/generated/core_district/**`

When changing the central district blueprint pipeline, edit the authored/tooling inputs under `../tools/` and regenerate with:

- `npm run blueprint:build:central-district`

Relevant authored sources live under:

- `../tools/central-district-blueprint.txt`
- `../tools/blueprint-authored/`
- `../tools/blueprint-normalized/`
- `../tools/ruin-templates/`
- `../tools/ruin-templates-worn/`

## Change-Specific Verification

- Prototype or load-order changes: `npm test`
- Runtime logic changes in `control.lua` or `scripts/`: `npm test`
- Worldgen changes: `npm test`, then `npm run inspect:surface` or `npm run inspect:perimeter` when visual placement matters
- Node/tooling changes under `../tools/`: `npm run test:node`
- Blueprint pipeline changes: `npm run blueprint:build:central-district`, then `npm run test:node` if JavaScript tooling changed

## Repo-Specific Rules

- Keep Space Age-specific prototypes or runtime behavior behind `if mods["space-age"] then`.
- Use [../docs/hooks.md](../docs/hooks.md) when touching event registration or handler ownership.
- Use `storage.*` for persistent runtime state.
- Keep hidden/internal entities non-player-facing unless the task explicitly requires debug visibility.
- If a change updates behavior that already has a matching doc in `../docs/features/`, update that doc in the same task.

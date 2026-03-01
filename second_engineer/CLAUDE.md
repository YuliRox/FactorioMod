# second_engineer — Read First

## Data Stage (load order)

1. `settings.lua` — [MISSING] startup/runtime settings
2. `data.lua` — entry point; requires all prototypes
3. `data-updates.lua` — patches lab trash slots; AbandonedRuins string-setting hook
4. `data-final-fixes.lua` — hidden lab animation; generates all `se-research-*` recipes

## Runtime Stage

5. `control.lua` — event dispatcher; requires all script modules
6. `scripts/` — runtime logic, see [docs/hooks.md](../docs/hooks.md) and [docs/features/](../docs/features/)

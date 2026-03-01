# New Recipe Checklist

Walk through every step needed to add a Factorio recipe to second_engineer. Confirm each step is complete before moving on.

---

## Step 1 — Decide the recipe details

Confirm with the user:

- **Recipe name** — snake-case, prefixed `se-`, e.g. `se-smelt-scrap-red`
- **Category** — which machine crafts it:
  - `"smelting"` → stone/electric furnace
  - `"crafting"` → assembler
  - `"se-research-crafting"` → research assembler (mod-specific)
- **Ingredients** — item name + amount for each input
- **Results** — item name + amount for each output; add `probability = 0.0–1.0` for probabilistic drops
- **`energy_required`** — craft time in seconds
- **`subgroup` / `order`** — where the recipe appears in the crafting UI (e.g. `"intermediate-product"`)
- **`enabled`** — `true` if available from the start, `false` if unlocked by a technology

---

## Step 2 — Create or extend the recipe file

Recipe files live in `second_engineer/prototypes/recipe/`. Group related recipes in one file (e.g. all scrap-smelting recipes in `scrap-smelting.lua`).

- If a suitable file already exists, add the new `data:extend` block there.
- Otherwise create a new file named after the recipe group.

Template (omit optional fields that do not apply):

```lua
data:extend({{
  type            = "recipe",
  name            = "se-<name>",
  localised_name  = {"recipe-name.se-<name>"},
  icon            = "<path-to-icon>",
  icon_size       = 64,
  category        = "<category>",
  subgroup        = "<subgroup>",           -- optional; controls crafting-menu tab
  order           = "<order-string>",       -- optional; controls sort position
  enabled         = true,
  energy_required = <seconds>,
  ingredients = {
    {type = "item", name = "<item>", amount = <n>},
  },
  results = {
    {type = "item", name = "<item>", amount = <n>},
    -- probabilistic result:
    {type = "item", name = "<item>", amount = <n>, probability = <0.0–1.0>},
  },
}})
```

---

## Step 3 — Register the file in data.lua

Open `second_engineer/data.lua` and add a `require` for the new file **before** any `data:extend` block that depends on it:

```lua
require("prototypes.recipe.<filename-without-.lua>")
```

---

## Step 4 — Add the locale string

Open `second_engineer/locale/en/second_engineer.cfg` and add one line under `[recipe-name]`:

```
se-<name>=Human Readable Name
```

---

## Step 5 — Check for machine limit overrides

Some vanilla machines have hardcoded inventory limits that block multi-output recipes. Check whether the chosen category requires a patch:

| Category | Machine | Known limit | Override file |
|---|---|---|---|
| `"smelting"` | furnaces | `result_inventory_size = 1` | `prototypes/override/furnace-output-slots.lua` |

**If the recipe has more distinct result items than the machine's default output slots:**

1. Find or create the relevant file in `prototypes/override/`.
2. Patch the limit upward using `math.max` so other mods that already widened it are not broken.
3. Require the override file from `data-final-fixes.lua` — **not** from `data.lua` or `data-updates.lua` — so that Space Age and other mods have already registered all their machine variants before the patch runs.

If the recipe has only one result, or the machine already supports enough slots, skip this step.

---

## Step 6 — Verify

- [ ] Recipe file exists in `prototypes/recipe/`
- [ ] `data.lua` has the `require`
- [ ] Locale entry added under `[recipe-name]`
- [ ] If `enabled = false`: a technology exists (or is planned) that unlocks `se-<name>`
- [ ] If results use `probability`: confirm `amount × probability` gives the intended expected yield
- [ ] If results exceed the machine's default output slots: override file updated and required from `data-final-fixes.lua`

---

Now apply these steps to the recipe the user wants to create.

-- tests/research_assembler.lua
-- Tests for scripts/research_assembler.lua

local M = require("scripts.research_assembler")

local POS     = {x = 200, y = 200}   -- far from spawn to avoid worldgen conflicts

local function surface()
  return game.surfaces["nauvis"] or game.surfaces[1]
end

local function reset_storage()
  storage.assemblers = {}
  storage.asm_index  = {}
  storage.asm_rr_pos = 1
end

local function count_in(inventory, item_name)
  local n = 0
  for _, stack in pairs(inventory.get_contents()) do
    if stack.name == item_name then n = n + stack.count end
  end
  return n
end

-- ── is_assembler ──────────────────────────────────────────────────────────────

describe("is_assembler", function()
  it("returns falsy for nil", function()
    assert.is_falsy(M.is_assembler(nil))
  end)

  it("returns false for a non-assembler entity", function()
    local ent = surface().create_entity{name="iron-chest", position=POS, force="player"}
    assert.is_not_nil(ent)
    assert.is_false(M.is_assembler(ent))
    ---@cast ent -nil
    ent.destroy()
  end)

  it("returns true for se-research-assembler", function()
    local asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
    assert.is_not_nil(asm)
    assert.is_true(M.is_assembler(asm))
    ---@cast asm -nil
    asm.destroy()
  end)
end)

-- ── register / remove ─────────────────────────────────────────────────────────

describe("register / remove", function()
  local asm

  before_each(function()
    reset_storage()
    asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
  end)

  after_each(function()
    if asm and asm.valid then asm.destroy() end
    reset_storage()
  end)

  it("adds the assembler to storage", function()
    M.register(asm)
    assert.is_not_nil(storage.assemblers[asm.unit_number])
    assert.equal(1, #storage.asm_index)
  end)

  it("does not double-register the same assembler", function()
    M.register(asm)
    M.register(asm)
    assert.equal(1, #storage.asm_index)
  end)

  it("creates a hidden lab on register", function()
    M.register(asm)
    local entry = storage.assemblers[asm.unit_number]
    assert.is_not_nil(entry.lab)
    assert.is_true(entry.lab.valid)
  end)

  it("removes the assembler from storage", function()
    M.register(asm)
    local u = asm.unit_number
    M.remove(u)
    assert.is_nil(storage.assemblers[u])
    assert.equal(0, #storage.asm_index)
  end)

  it("destroys the hidden lab on remove", function()
    M.register(asm)
    local lab = storage.assemblers[asm.unit_number].lab
    M.remove(asm.unit_number)
    assert.is_false(lab.valid)
  end)

  it("keeps rr_pos in bounds after the last assembler is removed", function()
    M.register(asm)
    M.remove(asm.unit_number)
    assert.equal(1, storage.asm_rr_pos)
  end)
end)

-- ── update_recipes — recipe switching ────────────────────────────────────────

describe("update_recipes / recipe switching", function()
  local asm, force
  local TECH = "automation"  -- automation-science-pack → se-research-automation

  before_each(function()
    reset_storage()
    force = game.forces.player
    if force.current_research then force.cancel_current_research() end
    force.research_queue = {}
    -- automation-science-pack is a prerequisite of automation in Factorio 2.0;
    -- pre-research it so automation can be queued, then reset automation itself.
    for name in pairs(force.technologies[TECH].prerequisites) do
      force.technologies[name].researched = true
    end
    force.technologies[TECH].researched = false
    asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
    M.register(asm)
  end)

  after_each(function()
    if force.current_research then force.cancel_current_research() end
    force.research_queue = {}
    if asm and asm.valid then asm.destroy() end
    reset_storage()
  end)

  it("sets idle recipe and deactivates assembler when no research is active", function()
    M.update_recipes(force)
    local recipe = asm.get_recipe()
    assert.is_not_nil(recipe)
    assert.equal("se-research-idle", recipe.name)
    assert.is_false(asm.active)
  end)

  it("sets matching recipe and activates assembler during automation research", function()
    async(120)
    force.research_queue = {force.technologies[TECH]}
    after_ticks(5, function()
      M.update_recipes(force)
      local recipe = asm.get_recipe()
      assert.is_not_nil(recipe)
      assert.equal("se-research-automation", recipe.name)
      assert.is_true(asm.active)
      done()
    end)
  end)

  it("resets last_finished baseline on recipe switch so tick_scan does not miscount", function()
    async(120)
    force.research_queue = {force.technologies[TECH]}
    after_ticks(5, function()
      M.update_recipes(force)
      local entry = storage.assemblers[asm.unit_number]
      assert.equal(asm.products_finished, entry.last_finished)
      done()
    end)
  end)
end)

-- ── update_recipes — item interaction ────────────────────────────────────────

describe("update_recipes / item interaction", function()
  local asm, force
  local TECH = "automation"

  before_each(function()
    reset_storage()
    force = game.forces.player
    if force.current_research then force.cancel_current_research() end
    force.research_queue = {}
    for name in pairs(force.technologies[TECH].prerequisites) do
      force.technologies[name].researched = true
    end
    force.technologies[TECH].researched = false
    asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
    M.register(asm)
  end)

  after_each(function()
    if force.current_research then force.cancel_current_research() end
    force.research_queue = {}
    if asm and asm.valid then asm.destroy() end
    reset_storage()
  end)

  it("flushes input items not needed by new recipe into trash", function()
    -- Put assembler on automation recipe and load its input
    asm.set_recipe("se-research-automation")
    local input = asm.get_inventory(defines.inventory.crafter_input)
    input.insert{name="automation-science-pack", count=5}

    -- Switch to idle (no research) — packs not needed → must move to trash
    M.update_recipes(force)

    local trash = asm.get_inventory(defines.inventory.crafter_trash)
    assert.equal(5, count_in(trash, "automation-science-pack"))
    assert.equal(0, count_in(input,  "automation-science-pack"))
  end)

  it("recovers matching items from trash back to input when research resumes", function()
    async(120)
    -- Flush packs to trash by switching from automation to idle
    asm.set_recipe("se-research-automation")
    local input = asm.get_inventory(defines.inventory.crafter_input)
    input.insert{name="automation-science-pack", count=5}
    M.update_recipes(force)  -- → idle, packs go to trash

    -- Resume automation research — packs must return to input
    force.research_queue = {force.technologies[TECH]}
    after_ticks(5, function()
      M.update_recipes(force)
      local trash = asm.get_inventory(defines.inventory.crafter_trash)
      assert.equal(5, count_in(input, "automation-science-pack"))
      assert.equal(0, count_in(trash, "automation-science-pack"))
      done()
    end)
  end)
end)

-- ── tick_scan ─────────────────────────────────────────────────────────────────

describe("tick_scan", function()
  local asm

  before_each(function()
    reset_storage()
    asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
    M.register(asm)
  end)

  after_each(function()
    if asm and asm.valid then asm.destroy() end
    reset_storage()
  end)

  it("runs without error when no crafts have finished", function()
    -- products_finished unchanged → no inserts; just must not crash
    M.tick_scan()
    assert.equal(1, #storage.asm_index)
  end)

  it("auto-removes stale entries whose entity became invalid", function()
    asm.destroy()
    asm = nil
    M.tick_scan()
    assert.equal(0, #storage.asm_index)
  end)
end)

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

-- ── is_assembler ──────────────────────────────────────────────────────────────

describe("is_assembler", function()
  it("returns falsy for nil", function()
    assert.is_falsy(M.is_assembler(nil))
  end)

  it("returns false for a non-assembler entity", function()
    local ent = surface().create_entity{name="iron-chest", position=POS, force="player"}
    assert.is_false(M.is_assembler(ent))
    ent.destroy()
  end)

  it("returns true for se-research-assembler", function()
    local asm = surface().create_entity{name="se-research-assembler", position=POS, force="player"}
    assert.is_true(M.is_assembler(asm))
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

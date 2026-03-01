-- prototypes/override/hidden-lab-animation.lua
-- Required from data-final-fixes.lua.
--
-- DEBUG: give the hidden research lab a visible, green-tinted copy of the base
-- lab animation so it can be inspected in-game. Remove when no longer needed.

local base_lab = data.raw["lab"]["lab"]

local function tint_anim(anim, tint, scale)
  if not anim then return end
  anim = util.table.deepcopy(anim)
  local function apply(a)
    if not a then return end
    if a.layers then
      for _, l in pairs(a.layers) do apply(l) end
    else
      a.tint         = tint
      a.scale        = (a.scale or 1) * scale
      a.render_layer = "higher-entity"
    end
  end
  if anim.north then
    for _, dir in pairs{"north", "south", "east", "west"} do apply(anim[dir]) end
  else
    apply(anim)
  end
  return anim
end

local hidden = data.raw["lab"]["se-hidden-research-lab"]
hidden.on_animation  = tint_anim(base_lab.on_animation,  {r=0.2, g=1.0, b=0.2, a=0.9}, 0.5)
hidden.off_animation = tint_anim(base_lab.off_animation, {r=0.2, g=1.0, b=0.2, a=0.5}, 0.5)

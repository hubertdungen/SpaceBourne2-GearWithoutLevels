--[[
  Penalty math (pure Lua, no game calls; see DESIGN.md section 5).

    q(L) = clamp(ln L / ln MaxLevel, 0, 1)       same scale as HTR's gear bonus
    p    = clamp((q(item) - q(you)) / FullPenaltyGap, 0, 1)

  p depends on the ratio item level / your level: 2x -> 0.56, 3.4x -> 1.0 (defaults).
]]

local P = {}

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

function P.quality(level, maxLevel)
    return clamp(math.log(math.max(1, tonumber(level) or 1)) / math.log(math.max(2, maxLevel)), 0, 1)
end

-- Penalty strength 0..1 for an item of itemLevel used at yourLevel. c: config.Penalty.
function P.factor(itemLevel, yourLevel, c)
    local item, you = tonumber(itemLevel) or 0, tonumber(yourLevel) or 1
    if item <= you or not c.Enabled then return 0 end
    local gap = P.quality(item, c.MaxLevel) - P.quality(you, c.MaxLevel)
    return clamp(gap / c.FullPenaltyGap, 0, 1)
end

-- Extra view kick for one shot (same units as the game's own kick in Master_Hand_Weapon:
-- pitch rand(-0.25, 0), yaw rand(-0.1, 0.1)). Returns pitch, yaw to add.
function P.recoil(p, c, rnd)
    rnd = rnd or math.random
    local k = p * c.Recoil
    return -0.25 * rnd() * k, 0.1 * (rnd() * 2 - 1) * k
end

-- Without HTR: damage multiplier so an over-level gun hits like one capLevels above you.
-- W(L) = base + perLevel * L is the vanilla Character_Stats.W_Damage curve.
function P.damageCap(itemLevel, yourLevel, capLevels, W)
    local item, you = tonumber(itemLevel) or 0, tonumber(yourLevel) or 1
    if capLevels <= 0 or item <= you + capLevels then return 1 end
    local function w(L) return W.base + W.perLevel * L end
    return w(you + capLevels) / w(item)
end

return P

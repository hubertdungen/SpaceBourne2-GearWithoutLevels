--[[
  Training: familiarity with over-level items grows with use (DESIGN.md section 5.4).
  Pure bookkeeping, no game calls. One line per item in training.txt: "<key>\t<amount>".
  Only over-level items are counted, so the file stays small.
]]

local T = { data = {}, dirty = false, path = nil }

-- Item identity: the game has no unique item id (generated items share ids like "Random3"),
-- so kind + price + level + rarity is used. Two identical drops share their training.
function T.key(kind, price, level, tier)
    local k = string.format("%s|%s|%d|%d", kind, tostring(price or "?"), math.floor(tonumber(level) or 0),
        math.floor(tonumber(tier) or 0))
    return (k:gsub("[\t\r\n]", " "))
end

function T.load(path)
    T.path = path
    local f = io.open(path, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^(.-)\t([%d%.]+)$")
        if k then T.data[k] = tonumber(v) end
    end
    f:close()
end

function T.save()
    if not (T.dirty and T.path) then return end
    local f = io.open(T.path, "w")
    if not f then return end
    for k, v in pairs(T.data) do f:write(k, "\t", string.format("%.2f", v), "\n") end
    f:close()
    T.dirty = false
end

function T.add(key, amount)
    if not key or amount <= 0 then return end
    T.data[key] = (T.data[key] or 0) + amount
    T.dirty = true
end

-- Share of the penalty training has removed (0..maxRelief). need: amount for full familiarity.
function T.relief(key, need, maxRelief)
    if not key or need <= 0 then return 0 end
    return maxRelief * math.min(1, (T.data[key] or 0) / need)
end

return T

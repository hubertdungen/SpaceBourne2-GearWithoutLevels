--[[
  Lazy, fault-isolated hook registration. Copied from HTR 0.4.1 (htr/hooks.lua), trimmed;
  keep the two in sync when one gets a fix.

  Hooks are grouped by class: when a class appears, all its hooks register; if the class
  object is replaced, they register again. A callback that keeps throwing Lua errors is
  switched off. A StaticFindObject that misses costs ~37 ms, so missing classes are looked
  up with a growing pause (1, 2, 4, 8, 16 s), at most one per poll.

  UE4SS 3.0 facts for Blueprint functions (verified in HTR): the callback runs AFTER the
  Blueprint body, and writing an OUT parameter with :set() changes what the caller receives.
]]

local U = require("gal.util")

local H = { list = {}, groups = {}, order = {}, SLOW = 0.008 }
local MAX_ERRORS = 25
local CHECK_LOADED = 5
local RETRY_MAX = 16

-- maxRetry: longest pause (s) between looks while the class is not loaded. UI widget classes
-- load only when a menu opens, so they get a long pause and H.want() instead.
function H.add(path, fn, tag, maxRetry)
    local h = { path = path, fn = fn, tag = tag or path, errors = 0, disabled = false, on = false, slowAt = -1e9 }
    h.cb = function(...)
        if h.disabled then return end
        local t0 = os.clock()
        local ok, err = pcall(h.fn, ...)
        local dt = os.clock() - t0
        if dt > H.SLOW and t0 - h.slowAt > 30 then
            h.slowAt = t0
            U.warn(string.format("slow hook %s: %.0f ms", h.tag, dt * 1000))
        end
        if not ok then
            h.errors = h.errors + 1
            if h.errors <= 3 then U.warn("error in " .. h.tag .. ": " .. tostring(err)) end
            if h.errors >= MAX_ERRORS then
                h.disabled = true
                U.warn("hook " .. h.tag .. " disabled after repeated errors")
            end
        end
    end
    H.list[#H.list + 1] = h
    local cls = path:match("^(.-):") or path
    local g = H.groups[cls]
    if not g then
        g = { cls = cls, hooks = {}, addr = nil, retry = 1, nextTry = 0, maxRetry = maxRetry or RETRY_MAX }
        H.groups[cls] = g
        H.order[#H.order + 1] = g
    end
    g.hooks[#g.hooks + 1] = h
end

-- A class is known to be loaded now (e.g. seen in a hook): look for it on the next poll.
function H.want(cls)
    local g = cls and H.groups[cls]
    if g and not g.addr then g.nextTry, g.retry = 0, 1 end
end

local function register(h)
    local ok, err = pcall(RegisterHook, h.path, h.cb)
    h.on = ok
    if ok then U.log("hooked " .. h.tag) else U.warn("could not hook " .. h.path .. ": " .. tostring(err)) end
end

-- Call on the game thread about once a second. now: os.clock().
function H.poll(now)
    local probed = false
    for _, g in ipairs(H.order) do
        if now >= g.nextTry and (g.addr or not probed) then
            if not g.addr then probed = true end
            local c = StaticFindObject(g.cls)
            local a = (c and c:IsValid()) and c:GetAddress() or nil
            if a then
                g.nextTry, g.retry = now + CHECK_LOADED, 1
                if a ~= g.addr then
                    g.addr = a
                    for _, h in ipairs(g.hooks) do register(h) end
                end
            else
                if g.addr then
                    g.addr = nil
                    for _, h in ipairs(g.hooks) do h.on = false end
                end
                g.nextTry = now + g.retry
                g.retry = math.min(g.retry * 2, g.maxRetry)
            end
        end
    end
end

function H.status()
    local on, off = 0, 0
    for _, h in ipairs(H.list) do if h.on and not h.disabled then on = on + 1 else off = off + 1 end end
    return on, off
end

return H

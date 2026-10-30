--[[
  Shared helpers (subset of HTR's htr/util.lua; same safety rules):
   * Game objects are only touched inside hook callbacks or right after an engine lookup.
     Nothing is kept from one frame to the next except plain numbers keyed by address.
   * Never FindAllOf/FindFirstOf in frequent code (~50 ms each in this game).
   * Hooks only on Blueprint functions; never RegisterLoadMapPre/PostHook (crashes).
]]

local U = {}

-- Mod folder (UE4SS may report the path as ...\Scripts\ or ...\scripts\).
do
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local lower = src:lower()
    local cut
    for i in lower:gmatch("()[\\/]scripts[\\/]") do cut = i end
    U.Dir = cut and src:sub(1, cut) or ".\\Mods\\GearWithoutLevels\\"
end
U.LogFile = U.Dir .. "gal.log"
U.Verbose = false

function U.log(...)
    if not U.Verbose then return end
    local t = {}
    for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
    local f = io.open(U.LogFile, "a")
    if f then f:write(os.date("%H:%M:%S "), table.concat(t, " "), "\n"); f:close() end
end

-- Always printed (UE4SS.log) and logged.
function U.warn(...)
    local msg = table.concat({ ... }, " ")
    print("[GearWithoutLevels] " .. msg .. "\n")
    local f = io.open(U.LogFile, "a")
    if f then f:write(os.date("%H:%M:%S "), "WARN ", msg, "\n"); f:close() end
end

function U.valid(o)
    if o == nil then return false end
    local ok, v = pcall(function() return o:IsValid() end)
    return ok and v
end

function U.addr(o)
    if not U.valid(o) then return nil end
    local ok, a = pcall(function() return o:GetAddress() end)
    return ok and a or nil
end

-- Object property of a valid object, only if it is itself a valid object (else nil).
-- Calling a method on an empty object reference (e.g. no weapon in hand) crashes the game
-- inside UE4SS - pcall cannot catch that - so every object chain goes through here.
function U.child(o, prop)
    if not U.valid(o) then return nil end
    local ok, v = pcall(function() return o[prop] end)
    if ok and U.valid(v) then return v end
    return nil
end

function U.get(o, prop, default)
    local ok, v = pcall(function() return o[prop] end)
    if ok and v ~= nil then return v end
    return default
end

function U.set(o, prop, value)
    return pcall(function() o[prop] = value end)
end

-- Short class name, cached per class address (one engine call per new class).
local classNames = {}
function U.shortClass(o)
    if not U.valid(o) then return nil end
    local ok, cls = pcall(function() return o:GetClass() end)
    if not ok or not cls then return nil end
    local a = U.addr(cls)
    if not a then return nil end
    local n = classNames[a]
    if not n then
        local ok2, s = pcall(function() return cls:GetFName():ToString() end)
        n = ok2 and s or "?"
        classNames[a] = n
    end
    return n
end

local GS
function U.gameplayStatics()
    if not U.valid(GS) then GS = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
    return GS
end

-- The player's pawn from any live object in the world (instant engine lookup).
function U.playerPawn(ctx)
    local ok, p = pcall(function() return U.gameplayStatics():GetPlayerPawn(ctx, 0) end)
    if ok and U.valid(p) then return p end
    return nil
end

-- The pawn you control right now (the character on foot, the ship when flying).
-- Key presses only: no live object at hand, so it scans (~50 ms). Never in combat code.
function U.possessedPawnSlow()
    local ok, pcs = pcall(FindAllOf, "PlayerController")
    if not ok or not pcs then return nil end
    for _, pc in ipairs(pcs) do
        local p = U.valid(pc) and U.get(pc, "Pawn", nil) or nil
        if U.valid(p) then return p end
    end
    return nil
end


-- HUD line, as in HTR 0.4.1 (both verified there): on foot the "No Target Nearby" style
-- warning (TMWPerkWarning); elsewhere, e.g. in a ship, the red cursor warning line.
local MSG_LIB = "/Game/1Data/FunctionsMacros/Q1FunctionLibary.Default__Q1FunctionLibary_C"
function U.notify(text, ctx)
    local p = U.playerPawn(ctx)
    if U.valid(p) and pcall(function() p:TMWPerkWarning(FText(text)) end) then return true end
    local lib = StaticFindObject(MSG_LIB)
    local wc = U.valid(p) and p or ctx
    if not (U.valid(lib) and U.valid(wc)) then return false end
    return pcall(function() lib:CursorWarningWidget(FText(text), wc) end)
end

-- Is Hardcore Tactical Realism installed and switched on? (Each UE4SS mod has its own Lua
-- state, so this looks at the files: HTR's enabled.txt or its line in mods.txt.)
function U.htrInstalled()
    local mods = U.Dir .. "..\\"
    local f = io.open(mods .. "HardcoreTacticalRealism\\enabled.txt", "r")
    if f then f:close(); return true end
    f = io.open(mods .. "mods.txt", "r")
    if not f then return false end
    local s = f:read("a") or ""
    f:close()
    return s:match("\n%s*HardcoreTacticalRealism%s*:%s*1") ~= nil or s:match("^%s*HardcoreTacticalRealism%s*:%s*1") ~= nil
end

function U.clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end

return U

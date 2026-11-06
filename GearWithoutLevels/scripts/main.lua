--[[
  Gear Without Levels - SpaceBourne 2 UE4SS Lua mod.
  Weapons, melee weapons and suits usable at any character level, with small, realistic
  handling penalties for kit above your level. Design: ../DESIGN.md.

  In-game test 2026-10-30 (build of 2026-10-26, UE4SS 3.0.1, with HTR): level override on the
  lock widgets, equipping over-level suits and weapons through the real inventory, recoil,
  suit stamina, training count and frame times verified. Melee and the standalone damage cap:
  not tested. Off by default (config.lua).

  Layout (same as Hardcore Tactical Realism):
    config.lua        user settings
    gal/gamedefs.lua  every game-internal name (the only file to fix after a game patch)
    gal/penalty.lua   penalty math (pure, no game calls)
    gal/training.lua  familiarity per item (pure bookkeeping, training.txt)
    gal/hooks.lua     lazy, fault-isolated hook registration (from HTR)
    gal/util.lua      helpers
]]

local VERSION = "0.1.1"

local U = require("gal.util")
local G = require("gal.gamedefs")
local P = require("gal.penalty")
local T = require("gal.training")
local H = require("gal.hooks")

-- Settings -------------------------------------------------------------------
local okCfg, cfg = pcall(require, "config")
if not okCfg or type(cfg) ~= "table" then
    U.warn("config.lua could not be read (" .. tostring(cfg) .. "); using defaults")
    cfg = {}
end
local function section(name, defaults)
    if type(cfg[name]) ~= "table" then cfg[name] = {} end
    for k, v in pairs(defaults) do if cfg[name][k] == nil then cfg[name][k] = v end end
end
if cfg.Enabled == nil then cfg.Enabled = false end
if cfg.ToggleKey == nil then cfg.ToggleKey = "Shift+Delete" end -- shared key plan rev 2 (laptop-safe)
if cfg.Notify == nil then cfg.Notify = true end
section("Unlock", { PickLists = true, ShopShowsAllLevels = false })
section("Penalty", { Enabled = true, MaxLevel = 60, FullPenaltyGap = 0.30, Recoil = 0.40, Reload = 0.20,
    MeleeStamina = 0.25, SuitStamina = 0.20, SuitSprintSpeed = 0.0 })
section("Training", { Enabled = true, Rounds = 400, Swings = 120, SuitBars = 20, MaxRelief = 0.75 })
section("Standalone", { DamageCapLevels = 5 })
section("Debug", { Log = false, SlowHookMs = 8 })
U.Verbose = cfg.Debug.Log
H.SLOW = cfg.Debug.SlowHookMs / 1000
local PEN, TR = cfg.Penalty, cfg.Training
T.load(U.Dir .. "training.txt")

-- On/off, remembered between sessions when changed with the key.
local STATE = U.Dir .. "state.txt"
local on = cfg.Enabled == true
do
    local f = io.open(STATE, "r")
    if f then
        local v = (f:read("a") or ""):match("enabled=(%a+)")
        f:close()
        if v then on = (v == "on") end
    end
end
local function saveState()
    local f = io.open(STATE, "w")
    if f then f:write("enabled=" .. (on and "on" or "off") .. "\n"); f:close() end
end

local HTR_PRESENT = U.htrInstalled()
U.warn(string.format("Gear Without Levels %s loaded, on=%s, HTR=%s",
    VERSION, tostring(on), tostring(HTR_PRESENT)))

-- Helpers ----------------------------------------------------------------------
local function itemLevel(item) return tonumber(U.get(item, G.Item.Level, 0)) or 0 end
local function yourLevel(pawn) return tonumber(U.get(pawn, G.P.PlayerLevel, 1)) or 1 end
local function gameBuilder(pawn) return U.child(U.child(pawn, G.P.Controller), G.P.GameBuilder) end
-- Numbers only (reading the item's FText name crashes UE4SS 3.0.1).
local function itemKey(kind, item)
    return T.key(kind, tostring(tonumber(U.get(item, G.Item.Value, 0)) or 0), itemLevel(item), U.get(item, G.Item.Tier, 0))
end
-- Penalty after training (DESIGN 5.4). need: uses for full familiarity.
local function trained(p, key, need)
    if p <= 0 or not TR.Enabled then return p end
    return p * (1 - T.relief(key, need, TR.MaxRelief))
end

-- One HUD line per over-level item (by name + level) per session.
local told = {}
local function tell(item, pawn, what)
    if not cfg.Notify then return end
    local lvl, you = itemLevel(item), yourLevel(pawn)
    if lvl <= you then return end
    local key = itemKey(what, item)
    if told[key] then return end
    told[key] = true
    local p = P.factor(lvl, you, PEN)
    -- short, and held 6 s: the game's HUD line hides after 2 s and wraps long text in big letters
    local text = string.format("Unfamiliar %s (L%d, you L%d)", what, math.floor(lvl), math.floor(you))
    if p > 0 then text = text .. string.format(": %d%% worse until trained", math.floor(p * 100 + 0.5)) end
    pcall(U.notify, text, pawn, 6)
end

-- 1. Level lock bypass (DESIGN 4.1) ----------------------------------------------
-- A lock widget arms ONE override for the next Game_Builder GetPlayerLevel(0) call: the
-- EquipSuit / EquipSword re-check that follows synchronously. Cleared when used, by the
-- widget event's post-hook (disarm), or on expiry.
local arm = { n = 0, untilT = 0 }
local function armOnce(seconds) arm.n, arm.untilT = 1, os.clock() + seconds end
local function disarm() arm.n = 0 end

-- Verified in game: the written Level reaches the Blueprint caller, only the lock widgets get
-- it, other callers (contracts, the character) keep the real level.
-- Q1FunctionLibary_C:GetPlayerLevel(Whom, __WorldContext, out Level)
local function onGetPlayerLevel(_, whomP, ctxP, levelP)
    if not on then return end
    if whomP:get() ~= 0 then return end -- pilot/ship levels: leave, and leave fast (hot in space combat)
    local ctx = ctxP:get()
    local cls = U.shortClass(ctx)
    local lock = G.LockWidgets[cls]
    if lock then
        H.want(lock.path) -- its class is loaded now: register its hooks on the next poll
        if lock.kind == "item" then -- inventory grid slot: only for its own on-foot gear (not probe stats)
            local item = U.get(ctx, G.P.ItemHere, nil)
            if not G.GearTypes[tonumber(U.get(item, G.Item.Type, -1)) or -1] then return end
        end
        levelP:set(G.OverrideLevel)
        armOnce(0.25)
        U.log("lock passed for " .. cls)
    elseif cls == G.GameBuilderClass then
        if arm.n > 0 and os.clock() < arm.untilT then
            levelP:set(G.OverrideLevel)
            arm.n = 0
            U.log("Game_Builder re-check passed (EquipSuit / EquipSword)")
        end
    elseif cls == G.PickListClass then
        if cfg.Unlock.PickLists then levelP:set(G.OverrideLevel) end
    elseif cls == G.ShopClass then
        if cfg.Unlock.ShopShowsAllLevels then levelP:set(G.OverrideLevel) end
    end
end

-- Dragging a melee item to the melee slot has no widget check before EquipSword, so the
-- drag start arms the override for an over-level hand weapon (type 12; melee is a hand
-- weapon subtype, but text properties are not read: see gamedefs). A gun dragged to a weapon
-- slot re-arms and disarms through that slot anyway.
local function onInvSlotDrag(selfP)
    if not on then return end
    local slot = selfP:get()
    local item = U.get(slot, G.P.ItemHere, nil)
    if tonumber(U.get(item, G.Item.Type, -1)) ~= 12 then return end
    if itemLevel(item) > yourLevel(U.playerPawn(slot)) then armOnce(15) end
end

-- 2. Penalties (DESIGN 5) -------------------------------------------------------------
-- Weapon penalty per weapon actor, cached a few seconds (gear rarely changes).
local wcache, wcount = {}, 0
local function weaponPenalty(w)
    local a, now = U.addr(w), os.clock()
    local e = a and wcache[a]
    if e and now - e.t < 5 then return e.p, e.owner, e.key end
    local owner = U.child(w, G.P.WeaponOwner)
    if not owner then return 0, nil, nil end
    local item
    pcall(function() item = w[G.P.WeaponData][G.P.WeaponItem] end)
    local raw = P.factor(itemLevel(item), yourLevel(owner), PEN)
    local key = raw > 0 and itemKey("gun", item) or nil
    local p = trained(raw, key, TR.Rounds)
    if a then
        if not e then wcount = wcount + 1; if wcount > 32 then wcache, wcount = {}, 1 end end
        wcache[a] = { p = p, t = now, owner = owner, key = key }
    end
    return p, owner, key
end

-- Recoil: once per trigger pull, a bit more of the game's own kick; each pull also counts
-- as training with that gun. Verified in game (L30 gun at level 8: +0.5 deg over 3 shots).
-- Master_Hand_Weapon_C:SpawnProjectile(TypeName)
local function onShot(selfP)
    if not on or not PEN.Enabled then return end
    local w = selfP:get()
    if not U.valid(w) then return end
    local p, owner, key = weaponPenalty(w)
    if key and TR.Enabled then T.add(key, 1) end
    if p <= 0 or PEN.Recoil <= 0 or not U.valid(owner) then return end
    local pitch, yaw = P.recoil(p, PEN)
    local ok = pcall(function()
        owner:AddControllerPitchInput(pitch)
        owner:AddControllerYawInput(yaw)
    end)
    if U.Verbose then U.log(string.format("recoil p=%.2f pitch=%.3f yaw=%.3f ok=%s", p, pitch, yaw, tostring(ok))) end
end

-- Melee stamina per swing. The game recomputes MeleeWeaponReqStamina from the item on every
-- refresh; we remember what we wrote so nested refreshes never stack. Not tested in game yet.
-- Q1_Character_C:Refresh Melee Weapon / SpawnMeleeWeapon
local melee = { base = nil, written = nil, key = nil, swings = 0 }
local function applyMelee(pawn)
    if not U.valid(pawn) then return end
    local cur = U.get(pawn, G.P.MeleeStamina, nil)
    if type(cur) ~= "number" then return end
    if cur ~= melee.written then melee.base = cur end -- a fresh value from the game
    local want = melee.base
    melee.key = nil
    if on and PEN.Enabled then
        local item = U.get(gameBuilder(pawn), G.P.SwordData, nil)
        local raw = P.factor(itemLevel(item), yourLevel(pawn), PEN)
        melee.key = raw > 0 and itemKey("melee", item) or nil
        want = melee.base * (1 + PEN.MeleeStamina * trained(raw, melee.key, TR.Swings))
        tell(item, pawn, "melee weapon")
    end
    if want ~= cur then U.set(pawn, G.P.MeleeStamina, want) end
    melee.written = want
    U.log(string.format("melee stamina per swing %.2f -> %.2f", melee.base, want))
end
local function onMeleeRefresh(selfP) applyMelee(selfP:get()) end

-- Each swing with an over-level melee weapon counts as training; every 10 swings the
-- stamina cost is recomputed. Not tested in game yet (is MeleeAttack called once per swing?).
-- Q1_Character_C:MeleeAttack()
local function onMeleeSwing(selfP)
    if not on or not melee.key or not TR.Enabled then return end
    T.add(melee.key, 1)
    melee.swings = melee.swings + 1
    if melee.swings % 10 == 0 then applyMelee(selfP:get()) end
end

-- Suit: extra stamina drain. Five times a second the player's stamina is compared with the
-- last look; when it dropped (sprint, swing), a little more is taken. Regeneration is untouched.
-- ALS_Base_C:ReceiveTick (every ALS character, every frame: the clock check comes first, then
-- only the player is looked at). The game's stamina event only reaches a ship panel that does
-- not exist on foot (verified in game), so it cannot be used.
local suit = { p = 0, t = -1e9, last = nil, key = nil }
local function suitPenalty(pawn)
    local now = os.clock()
    if now - suit.t < 5 then return suit.p end
    suit.t = now
    local item
    pcall(function() item = gameBuilder(pawn)[G.P.CharacterData][G.P.SuitItem] end)
    local raw = P.factor(itemLevel(item), yourLevel(pawn), PEN)
    suit.key = raw > 0 and itemKey("suit", item) or nil
    suit.p = trained(raw, suit.key, TR.SuitBars)
    if raw > 0 then tell(item, pawn, "suit") end
    return suit.p
end

-- Exertion in the suit (stamina spent, in full bars) also counts as training with it.
local tickAt = 0
local function onTick(selfP)
    local now = os.clock()
    if now < tickAt then return end
    if not on or not PEN.Enabled or PEN.SuitStamina <= 0 then tickAt, suit.last = now + 1, nil; return end
    local pawn = selfP:get()
    if U.shortClass(pawn) ~= G.PlayerClass then return end -- an NPC ticked first: keep looking this frame
    tickAt = now + 0.2
    local cur = tonumber(U.get(pawn, G.P.Stamina, nil))
    if not cur then return end
    local last = suit.last
    suit.last = cur
    if not last or cur >= last - 0.01 then return end -- ignore float noise
    local p = suitPenalty(pawn)
    if p <= 0 then return end
    local mx = tonumber(U.get(pawn, G.P.MaxStamina, 0)) or 0
    if suit.key and TR.Enabled and mx > 0 then T.add(suit.key, (last - cur) / mx) end
    local extra = (last - cur) * PEN.SuitStamina * p
    U.set(pawn, G.P.Stamina, math.max(0, (tonumber(U.get(pawn, G.P.Stamina, cur)) or cur) - extra))
    suit.last = cur - extra -- so our own drain is not counted as the next drop
    if U.Verbose then U.log(string.format("suit stamina p=%.2f drop=%.3f extra=%.3f", p, last - cur, extra)) end
end

-- Weapon drawn: HUD line, and without HTR the damage cap (DESIGN 5.3). Cap not tested in game.
-- Q1_Character_C:SpawnAndAddWeapon(Slot) - sets Master_Hand_Weapon.Damage
local function onWeaponSpawned(selfP)
    if not on then return end
    local pawn = selfP:get()
    local w = U.child(U.child(pawn, G.P.CurrentWeapon), "ChildActor")
    if not w then return end
    local item
    pcall(function() item = w[G.P.WeaponData][G.P.WeaponItem] end)
    tell(item, pawn, "weapon")
    if HTR_PRESENT or cfg.Standalone.DamageCapLevels <= 0 then return end
    local m = P.damageCap(itemLevel(item), yourLevel(pawn), cfg.Standalone.DamageCapLevels, G.WDamage)
    if m < 1 then
        local d = tonumber(U.get(w, G.P.Damage, 0)) or 0
        U.set(w, G.P.Damage, d * m)
        U.log(string.format("standalone damage cap: %.1f -> %.1f", d, d * m))
    end
end

-- Hooks ------------------------------------------------------------------------
-- UI widget classes load only when a menu opens and a missed lookup costs ~37 ms, so they
-- are looked for rarely (UI_RETRY) and right away once onGetPlayerLevel sees them in use.
-- Alternative to test: UE4SS NotifyOnNewObject on the widget classes.
local UI_RETRY = 120
H.add(G.Fn.GetPlayerLevel, onGetPlayerLevel, "level lock")
H.add(G.Fn.WeaponSlotDrop, disarm, "disarm (weapon slot)", UI_RETRY)
H.add(G.Fn.EquipSlotDrop, disarm, "disarm (equipment slot)", UI_RETRY)
H.add(G.Fn.InvSlotClick, disarm, "disarm (inventory click)", UI_RETRY)
H.add(G.Fn.InvSlotDrag, onInvSlotDrag, "melee drag", UI_RETRY)
H.add(G.Fn.InvSlotDragStop, disarm, "disarm (drag cancelled)", UI_RETRY)
H.add(G.Fn.InvSlotDrop, disarm, "disarm (dropped in inventory)", UI_RETRY)
H.add(G.Fn.Shot, onShot, "recoil")
H.add(G.Fn.MeleeRefresh, onMeleeRefresh, "melee stamina")
H.add(G.Fn.MeleeSpawn, onMeleeRefresh, "melee stamina (spawn)")
H.add(G.Fn.MeleeSwing, onMeleeSwing, "melee training")
H.add(G.Fn.WeaponSpawned, onWeaponSpawned, "weapon drawn")
H.add(G.Fn.PlayerTick, onTick, "suit stamina")
-- Phase 2b (not written yet): reload penalty - montage play rate + EBBarrel.ShootingBlocked
-- window after the vanilla refill (DESIGN 5.1).

local lastStatus, saveAt = "", os.clock() + 30
LoopAsync(1000, function()
    ExecuteInGameThread(function()
        local now = os.clock()
        local ok, err = pcall(H.poll, now)
        if not ok then U.warn("poll: " .. tostring(err)) end
        if now > saveAt then saveAt = now + 30; pcall(T.save) end -- training.txt, only when changed
        local a, b = H.status()
        local s = string.format("hooks active %d, waiting %d", a, b)
        if s ~= lastStatus then lastStatus = s; U.log(s) end
    end)
    return false
end)

-- Toggle key --------------------------------------------------------------------
local function toggle()
    local pawn = U.possessedPawnSlow() -- character on foot, ship when flying (for the HUD line)
    on = not on
    disarm()
    saveState()
    pcall(T.save)
    U.warn("Gear Without Levels " .. (on and "ON" or "OFF"))
    pcall(U.notify, on and "Gear Without Levels ON - over-level kit works, handles a bit worse"
        or "Gear Without Levels OFF - vanilla level locks", pawn, nil, true)
end

-- "Shift+Delete" -> Key.DEL with ModifierKey.SHIFT (shared key plan rev 2: Shift is the only
-- modifier; F6/F8/F10 belong to the game). This mod has no plain-key binds, so it never
-- needs to stay quiet while Shift is held.
local KEY_ALIAS = { DELETE = "DEL" }
local function bindToggle(spec)
    if type(spec) ~= "string" or spec == "" or not Key then return end
    local parts = {}
    for p in spec:gmatch("[^+%s]+") do parts[#parts + 1] = p end
    local name = (parts[#parts] or ""):upper()
    local key = Key[KEY_ALIAS[name] or name]
    if not key then U.warn("unknown ToggleKey " .. spec); return end
    local mods = {}
    for i = 1, #parts - 1 do
        local m = ({ shift = "SHIFT", ctrl = "CONTROL", control = "CONTROL", alt = "ALT" })[parts[i]:lower()]
        if m and ModifierKey and ModifierKey[m] then mods[#mods + 1] = ModifierKey[m] end
    end
    local fn = function() ExecuteInGameThread(toggle) end
    if #mods > 0 then RegisterKeyBind(key, mods, fn) else RegisterKeyBind(key, fn) end
end
bindToggle(cfg.ToggleKey)

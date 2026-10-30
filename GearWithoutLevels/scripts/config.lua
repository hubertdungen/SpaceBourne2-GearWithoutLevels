--[[
  Gear Without Levels - user settings. Edit with any text editor, then restart the game.
  Everything here is optional: delete a line and the default is used.

  !! GROUNDWORK BUILD: nothing in this mod has been tested in game yet. !!
]]

return {
    -- Master switch. OFF by default. Shift+Delete flips it in game, anywhere (remembered in
    -- state.txt). Format: "Shift+<key>" or "<key>" with a UE4SS key name; "" = no key.
    -- Keep to Shift (on foot Ctrl opens the map, Alt crouches) and to keys the game leaves
    -- free everywhere (F7, F9, F11, Delete). Never F6/F8/F10 (quick save, quick load, bug
    -- report). Keys of the whole realistic set follow one shared key plan.
    Enabled = false,
    ToggleKey = "Shift+Delete",

    Unlock = {
        -- Lists that hide items above your level (the character screen's item picker).
        PickLists = true,
        -- Shops already sell everything; their "show unusable" filter hides over-level items.
        -- true = the filter treats every item as usable.
        ShopShowsAllLevels = false,
        -- Picking up an over-level weapon never auto-equips it (vanilla behaviour, kept).
    },

    -- Unfamiliar-kit penalties. Strength p (0..1) grows with the RATIO item level / your
    -- level on HTR's log scale: an item at 2x your level gives p = 0.56, the full penalty
    -- comes at about 3.4x. A veteran adapts faster: level 50 -> 60 is only p = 0.15.
    -- Values below are the maximum (at p = 1). Damage, protection and rate of fire are
    -- never changed.
    Penalty = {
        Enabled = true,
        MaxLevel = 60,          -- same scale as HTR's gear bonus
        FullPenaltyGap = 0.30,  -- quality gap for the full penalty (0.30 = about 3.4x your level)
        Recoil = 0.40,          -- +40 % view kick per shot
        Reload = 0.20,          -- +20 % reload time (phase 2b, not implemented yet)
        MeleeStamina = 0.25,    -- +25 % stamina per melee swing
        SuitStamina = 0.20,     -- +20 % stamina drain (sprint, swings) in an over-level suit
        SuitSprintSpeed = 0.0,  -- optional: -x sprint speed in an over-level suit (not implemented yet)
    },

    -- Training: using an over-level item makes you familiar with it, so its penalty fades
    -- before you level up. Counted per item, kept in training.txt (per install, not per save).
    Training = {
        Enabled = true,
        Rounds = 400,       -- rounds fired with a gun for full familiarity (~13 rifle magazines)
        Swings = 120,       -- melee swings
        SuitBars = 20,      -- full stamina bars spent in a suit (sprinting, swinging)
        MaxRelief = 0.75,   -- training removes up to 75 % of the penalty; the rest goes with levels
    },

    -- Only used when Hardcore Tactical Realism is NOT installed: vanilla weapon damage grows
    -- with item level (x3.7 from level 10 to 40), so an over-level gun hits like a gun this
    -- many levels above you. 0 = no cap.
    Standalone = { DamageCapLevels = 5 },

    Notify = true, -- one HUD line when you equip over-level kit

    Debug = { Log = false, SlowHookMs = 8 },
}

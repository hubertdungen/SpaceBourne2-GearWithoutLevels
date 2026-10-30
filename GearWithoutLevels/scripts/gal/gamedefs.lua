--[[
  Every SpaceBourne 2 internal name this mod depends on. After a game update, this is the
  only file to fix. Names come from the game's Blueprints (UE 4.27, build of 2026-10-26).
  See ../../DESIGN.md section 2 for where each one is used by the game.
]]

local G = {}

-- Classes ---------------------------------------------------------------------
G.Lib         = "/Game/1Data/FunctionsMacros/Q1FunctionLibary.Q1FunctionLibary_C"
G.Player      = "/Game/1Data/Q1_Character.Q1_Character_C"
G.HandWeapon  = "/Game/1Data/Weapons/Hand_Weapons/Weapons/Master_Hand_Weapon.Master_Hand_Weapon_C"
G.WeaponSlot  = "/Game/1Widgets/Character/Hand_Weapon_Slot.Hand_Weapon_Slot_C"               -- lock A
G.EquipSlot   = "/Game/1Widgets/Character/Character_Equipment_slot.Character_Equipment_slot_C" -- lock B
G.InvSlot     = "/Game/1Widgets/Ship/UI_Ship_Weapon_Slot.UI_Ship_Weapon_Slot_C"              -- lock E (inventory grid)
G.ALSBase     = "/Game/Locomotion/Blueprints/CharacterLogic/ALS_Base.ALS_Base_C"
G.PlayerClass = "Q1_Character_C"

-- Short class names (GetClass():GetFName()) of the GetPlayerLevel callers we override.
--   "drop": its only GetPlayerLevel(0) call is the lock in OnDrop -> always override.
--   "item": also calls GetPlayerLevel(0) to show probe/drone stats -> override only when
--           the slot's own item (ItemHere) is on-foot gear (G.GearTypes).
G.LockWidgets = {
    Hand_Weapon_Slot_C = { kind = "drop", path = G.WeaponSlot },         -- A: drag to a weapon slot
    Character_Equipment_slot_C = { kind = "drop", path = G.EquipSlot },  -- B: drag a suit to the equipment slot
    UI_Ship_Weapon_Slot_C = { kind = "item", path = G.InvSlot },         -- E: right-click in the inventory grid
}
G.GearTypes = { [12] = true, [15] = true } -- S_Item_Data.Type: 12 hand weapon (melee too), 15 suit
G.PickListClass    = "Upgrade_Inventory_C"  -- G: item picker hides over-level items
G.ShopClass        = "Shop_Widget_C"        -- "show unusable" filter
G.GameBuilderClass = "Game_Builder_C"       -- C/D: EquipSuit / EquipSword re-check

-- Hooked functions --------------------------------------------------------------
G.Fn = {
    GetPlayerLevel  = G.Lib .. ":GetPlayerLevel",                 -- (Whom, __WorldContext, out Level), static pure
    WeaponSlotDrop  = G.WeaponSlot .. ":OnDrop",                  -- (MyGeometry, PointerEvent, Operation, ret bool)
    EquipSlotDrop   = G.EquipSlot .. ":OnDrop",
    InvSlotClick    = G.InvSlot .. ":OnPreviewMouseButtonDown",
    InvSlotDrag     = G.InvSlot .. ":OnDragDetected",             -- drag start from the inventory grid
    InvSlotDragStop = G.InvSlot .. ":OnDragCancelled",
    InvSlotDrop     = G.InvSlot .. ":OnDrop",                     -- dropped back into the grid
    Shot            = G.HandWeapon .. ":SpawnProjectile",         -- once per trigger pull (pellets inside)
    MeleeRefresh    = G.Player .. ":Refresh Melee Weapon",
    MeleeSpawn      = G.Player .. ":SpawnMeleeWeapon",
    MeleeSwing      = G.Player .. ":MeleeAttack",                 -- one melee swing (training count)
    WeaponSpawned   = G.Player .. ":SpawnAndAddWeapon",           -- sets Master_Hand_Weapon.Damage
    PlayerTick      = G.ALSBase .. ":ReceiveTick",                -- every ALS character, every frame (HTR uses it too)
}

-- Properties ---------------------------------------------------------------------
G.P = {
    PlayerLevel   = "PlayerLevel",            -- Q1_Character: cached character level
    Controller    = "Controller",             -- APawn -> Q1Controller
    GameBuilder   = "GameBuilderRef",         -- Q1Controller -> Game_Builder_C (holds the real gear data)
    CurrentWeapon = "CurrentWeapon",          -- Q1_Character: ChildActorComponent
    SwordData     = "EquipSword Data",        -- Game_Builder (and Q1_Character copy): equipped melee item
    CharacterData = "CharacterData",          -- Game_Builder: S_Character_Data_1 (EquipSuit writes here;
                                              -- HTR found the pawn's copy can read level 0)
    SuitItem      = "ArmorData_48_7F9011B443DE8EDE80BF42ADE651F30B",
    MeleeStamina  = "MeleeWeaponReqStamina",  -- Q1_Character
    Stamina       = "CurrentStamina",         -- ALS_Base
    MaxStamina    = "MaxStamina",             -- ALS_Base
    ItemHere      = "ItemHere",               -- inventory / equipment slot widgets
    UpgradeSlot   = "Upgrade_Slot",           -- drag operation -> source inventory slot
    WeaponData    = "Weapon_Data",            -- Master_Hand_Weapon: S_Equiped_HandWeapon
    WeaponItem    = "ItemData_2_DAF7632548C524437769A9884E99CE86",
    WeaponOwner   = "Q1Character",            -- Master_Hand_Weapon -> owning player
    Damage        = "Damage",                 -- Master_Hand_Weapon
}
G.Item = {
    Level   = "ItemLevel_32_36C68C8841BC84733BDEE38AC9296BF6",  -- 1..99
    Tier    = "ItemTier_31_620BE1F64621359F21DE589574539BBB",   -- rarity 1..4
    Type    = "Type_10_BF723D5042242143C6379BB031CAA5DB",       -- 12 hand weapon, 15 suit
    Value   = "Value_48_FEFCE2EF4E309330F1862F955E59864E",      -- price (int)
    -- Never read the item's Name (FText inside a struct): it crashed the game in UE4SS 3.0.1
    -- (access violation, 2026-10-30 test). Items are identified by numbers only.
}

-- Level reported to the lock sites (anything above 99 passes every check).
G.OverrideLevel = 999

-- Vanilla weapon damage curve Character_Stats.W_Damage: linear 5 at level 0 -> 800 at 200.
G.WDamage = { base = 5, perLevel = 3.975 }

return G

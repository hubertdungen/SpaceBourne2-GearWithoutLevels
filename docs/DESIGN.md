# Gear At Any Level — design

Status: **tested in game on 2026-10-30** (see §12): equipping over-level suits and weapons
through the real inventory, recoil, suit stamina, training and frame times work. Melee and the
standalone damage cap are not tested yet.

Goal: weapons, melee weapons and suits can be equipped at any character level. An item
above your level always works, but an unfamiliar, more advanced piece of kit handles a
little worse until you have the experience for it. With HTR's gear bonus on, the item still
gives its small HTR bonus, so the net effect is a minor bonus with a small handling cost.

Everything below comes from the game's Blueprints (UE 4.27, build of 2026-10-26). Function
and property names are exact; offsets like `@1016` are bytecode offsets in the decompiled
function, for whoever re-checks after a game patch.

---

## 1. Realism model in one paragraph

A better rifle does not need a "level". What a rookie lacks is familiarity: recoil
management, fast and clean magazine changes, and the conditioning to carry heavy, advanced
armor. So the mod never touches what the item *is* (calibre, protection, rate of fire) and
only adds small handling penalties that shrink with experience. "Experience" is the
character level, measured on the same log scale HTR's gear bonus uses, so a veteran adapts
to new kit faster than a rookie (level 50 → 60 is a small step; level 5 → 15 is a big one).

---

## 2. Where the game enforces the level lock

There is **one** source of truth: `Q1FunctionLibary_C:GetPlayerLevel(Whom, __WorldContext, out Level)`
(`/Game/1Data/FunctionsMacros/Q1FunctionLibary`). It is a Blueprint (static, pure) function.
`Whom` selects which level: `0` = character (`CharacterData.CHAR_Level`), `1` = pilot,
`2` = a third track (probes/misactor tools). Every lock compares its `Level` with
`S_Item_Data.ItemLevel` (`ItemLevel_32_36C68C8841BC84733BDEE38AC9296BF6`, 1..99).

### 2.1 On-foot gear locks (character level, `Whom = 0`)

| # | Where | Path | Context passed as `__WorldContext` | After the check |
|---|---|---|---|---|
| A | Weapon dragged to a weapon slot | `Hand_Weapon_Slot_C:OnDrop` @253 | the widget (`Hand_Weapon_Slot_C`) | `Game_Builder.EquipHandWeaponToPack` (no further check) — else cursor warning "High Level" |
| B | Suit / melee dragged to the equipment slot | `Character_Equipment_slot_C:OnDrop` @968 (suit only) | the widget | `Game_Builder.EquipSuit` → **check C** |
| C | Suit equip itself | `Game_Builder_C:EquipSuit` @125 | `Game_Builder_C` | equips, else "High Level" |
| D | Melee equip itself | `Game_Builder_C:EquipSword` @0 | `Game_Builder_C` | equips, else "High Level" |
| E | Right-click "quick equip" in the inventory grid | `UI_Ship_Weapon_Slot_C:OnPreviewMouseButtonDown` @1080 (suit), @1567 (weapon) | the widget | suit → `EquipSuit` (**check C**); weapon → `EquipHandWeaponToPack` — else "High Level Weapon" |
| F | Auto-equip on pickup into an empty slot | `Game_Builder_C:AutoEquipNN` @0 | `Game_Builder_C` | `EquipHandWeaponToPack`, else silently skipped |
| G | Item pick list (filters out items above your level) | `Upgrade_Inventory_C` ubergraph @1708 | the widget | item hidden from the list |

Not locks:
- `Game_Builder.EquipHandWeaponToPack` / `EquipHandWeaponToHand` have **no** level check.
  Saved loadouts re-equip on spawn through `Q1_Character → EquipHandWeaponToPack_0`, also
  without a check (so over-level gear stays equipped after a reload, even without the mod).
- **Shops do not lock buying.** `Shop_Widget` only *hides* items above your level while its
  "show unusable" filter (`UnusableShow`) is off; buying checks money only.
- `Q1_Character` calls `GetPlayerLevel(0, self)` on every weapon refresh to cache
  `Q1_Character.PlayerLevel` (HTR reads this). The bypass must never touch that call.

### 2.2 Ship gear (pilot level, `Whom = 1`) — later (decided)

Ship weapons, upgrades and modules use the pilot level: `UI_Ship_Weapon_Slot_C:AutoEquioWeapon`,
`SwitchWeapon`, `InventoryWeapon_Slot_Trans1`, `Q1_Master_Ship_C:EquipUpgrade` (warning
"High Level Item"), `EquipMisactorTool` (`Whom = 2`).

Not easy enough to include now, for two reasons:
- `Q1_Master_Ship_C` is itself the context of the upgrade check **and** calls
  `GetPlayerLevel(1)` in space combat (`HandleSwarmDamage`, perk energy, ship guns). The
  bypass would lose its cheap `Whom ≠ 0` exit and need the "arm" trick on a hot path.
- Ship gear needs its own realistic penalty model (what does an unfamiliar ship weapon or
  module do?), separate from on-foot handling.

So it is phase 4, after the on-foot version is tested.

### 2.3 Where over-level gear comes from

- Enemy drops: `Q1_Shooter_AI` generates weapons at **the NPC's own level** (`self.Level`).
- Loot crates / corpses: your character level ± 2 (`Random_Item_Generator.Set_Level`:
  `RandomIntegerInRange(DropperLevel-2, DropperLevel+2)`, clamped 1..99).
- Some generator paths and markets use the **pilot** level (`GetPlayerLevel(1)`), which is
  often higher than the character level. This mismatch is the most likely reason players hit
  "High Level" on loot.
- Shops: price grows linearly with level (`Economy__Curve.BasePrices`: 100 at level 1,
  120 000 at level 100 → about 11 000 at 10, 23 000 at 20, 47 000 at 40).

---

## 3. What item level actually changes (and what HTR already neutralises)

Item stats are **baked into the item when it is generated** (`Random_Item_Generator.GetStats`),
from level curves:

| Stat on the item | Curve (row) | Shape | Level 10 → 40 |
|---|---|---|---|
| Weapon damage `C_W_DMG` | `Character_Stats` `W_Damage` | linear 5 @0 → 800 @200 | 45 → 164 (**×3.7**) |
| Rate of fire `C_W_ROF`, velocity `C_W_VEL`, magazine `C_W_MAG` | `H_W_Rifle_Curve` | small, by tier | — |
| Suit armor / HP / regen | `Character_Stats` `Armor`, `HP`, … | cubic 1 → 200 | armor ≈ 137 → 1 034 (approx.) |

The weapon's damage is `C_W_DMG × (1 + DamageBonus/100)` (`Q1_Character.SpawnAndAddWeapon`
→ `Master_Hand_Weapon.Damage`).

There is **no** per-item accuracy, recoil, reload or weight stat. Handling is fixed per
weapon class:
- Recoil: every shot calls `ALS_Base.AddRecoil()` and kicks the view by
  `AddControllerPitchInput(rand −0.25..0)` / `AddControllerYawInput(rand −0.1..0.1)`
  (`Master_Hand_Weapon` @7067–7398), plus a camera shake.
- Spread: only shotguns (`ShellSpread` 0.01 / 0.08 / 0.15); rifles fire exactly at the
  crosshair. The character `Accurcy` stat is computed but never used by hand weapons.
- Reload: `PlayAnimMontage(ReloadMontage, 1.0)` and the reload completes after
  `Delay(montage.GetPlayLength())` (`Q1_Character` @26421–26710). Slowing the montage alone
  does **not** delay the magazine refill.
- Stamina: `ALS_Base` tick drains/regenerates `CurrentStamina` and broadcasts
  `UpdateStamina(Current, Max)`; the HUD listens with
  `/Game/11Misc/LGUI/ShipAndCharacter/Character_Stats.Character_Stats_C:CustomEvent_0`.
  Melee swings subtract `Q1_Character.MeleeWeaponReqStamina` (set from the melee item in
  `Refresh Melee Weapon` and `SpawnMeleeWeapon`).

With **HTR** on:
- Damage to NPCs ignores the weapon's level damage (calibre + armor + hit zone). Item level
  only matters through HTR's optional gear bonus (F8): up to +8 penetration and +15 % damage.
  So an over-level weapon is **not** an exploit with HTR.
- The suit still leaks level: HTR derives your armor rating from
  `15 + 45 × MaxArmor / MaxHP` (capped at 66). If a suit raises `MaxArmor` but not `MaxHP`,
  a suit at 2× your level already reaches the cap (≈66 vs ≈53 at parity). If the suit
  raises both, the ratio barely moves. **Must be measured in game (test T6).**

Without HTR, vanilla damage scales with weapon level, so a level-40 gun at level 10 hits
3.7× harder: the bypass alone would be an exploit. See §5.3.

---

## 4. How to bypass the lock (no pak modding needed)

### 4.1 Mechanism: override `GetPlayerLevel`'s out param in the right context

UE4SS post-hooks run after the Blueprint body, and writing an out param with `:set()`
changes what the caller receives (verified in HTR on `CalculateIncomeDamage`). The locks all
read `GetPlayerLevel`'s `Level` right after the call, so a post-hook on
`Q1FunctionLibary_C:GetPlayerLevel` can report a high level **only to the lock sites**:

```
post-hook GetPlayerLevel(self, Whom, WorldContext, Level):
    if Whom ~= 0 then return end                      -- cheap exit: ship/pilot calls
    cls = class of WorldContext (cached per class address)
    if cls is a lock widget (A, B, E, G):  Level:set(999); arm()   -- one Game_Builder call
    elseif cls == Game_Builder_C and armed and not expired: Level:set(999); disarm()
    -- anything else (NPC CalculateStats, Q1_Character refresh, ...) is left alone
```

- Checks A, B, E, G pass the widget as context: recognised by class. A and B call
  `GetPlayerLevel(0)` only in `OnDrop`, so they are always overridden. The inventory slot
  (E, `UI_Ship_Weapon_Slot_C`) also calls it to display probe/drone stats (@10081, level
  clamped to 2..99): it is overridden only when its own `ItemHere.Type` is 12 (hand weapon,
  melee included) or 15 (suit), otherwise probe stats would show level-99 values.
- Checks C and D (`EquipSuit`, `EquipSword`) pass `Game_Builder_C`, which also calls
  `GetPlayerLevel(0)` for many unrelated things (contracts, level-up…). So every lock widget
  "arms" a **single** override for the next `Game_Builder` call. Weapons need it too: a melee
  item dropped on a weapon slot or right-clicked goes `EquipHandWeaponToPack` → (subtype
  "Melee") → `EquipSword`. The call chain is synchronous (`OnDrop` → `EquipSuit` →
  `GetPlayerLevel`), and the arm is cleared:
  - when used (one shot),
  - in a post-hook on the widget event that started it (`Hand_Weapon_Slot_C:OnDrop`,
    `Character_Equipment_slot_C:OnDrop`, `UI_Ship_Weapon_Slot_C:OnPreviewMouseButtonDown`),
  - after 0.25 s as a safety net.
- One path has no widget check at all: dragging a melee item onto the melee slot
  (`Character_Equipment_slot_C:OnDrop` → `EquipSword` directly). For it, a post-hook on the
  drag source `UI_Ship_Weapon_Slot_C:OnDragDetected` arms a "melee drag" when
  `self.ItemHere` is an over-level melee item (type 12, subtype "Melee"). It is cleared when
  used, on `UI_Ship_Weapon_Slot_C:OnDragCancelled`, on any slot's `OnDrop` post-hook
  (including a drop back into the inventory grid), or after 15 s. The leak window is the drag itself, and only for over-level melee drags.
  (Hooking `Q2_GetGameBuildier_C:GetDataBuilder`, which the slot calls just before
  `EquipSword`, was rejected: it has 805 call sites, some per tick.)
- F (auto-equip on pickup) stays locked: no widget arms it, so picking up a high-level gun
  never fills an empty slot by itself. You equip over-level kit on purpose.
- Shops: left vanilla by default (the player can already toggle "show unusable"). Option
  `ShopShowsAllLevels` (context `Shop_Widget_C`, only `Whom = 0`).

Cost: `GetPlayerLevel` is called from many places, some in combat (ship guns,
`HandleSwarmDamage`), but those use `Whom = 1`, so they exit after one param read. `Whom = 0`
calls are rare (NPC spawn stats, UI). Budget: under 0.1 ms per second in combat; checked
with the hook profiler (T8).

Hook registration: the widget classes load only when a menu opens, and a `StaticFindObject`
that misses costs ~37 ms (HTR lesson). So the widget hooks are looked for at most every
120 s while missing, and right away once `GetPlayerLevel` sees one of them as context
(`H.want`). The first drop after opening the inventory therefore runs without the disarm
hooks; the 0.25 s expiry covers it. Worth testing instead: UE4SS `NotifyOnNewObject` on
the widget classes.

Nothing is written to item data or saves. Removing the mod leaves equipped over-level items
in place (the game never re-checks on load); they just cannot be re-equipped.

### 4.2 Fallbacks if 4.1 does not work in game

- **B — redo the equip in a post-hook.** Hook `Hand_Weapon_Slot_C:OnDrop` etc.; if the drop
  was refused for level (dragged item level > your level, slot type right), call
  `Game_Builder:EquipHandWeaponToPack(item, EquipIndex)` ourselves. Suits need `EquipSuit`,
  which has its own check, so suits would still need 4.1 or a manual equip
  (`CharacterData.ArmorData_48…` + `Q1_Character:EquipArmor(mesh, material)` + inventory
  removal) — fragile. The "High Level" cursor warning would still flash.
- **C — pak mod.** Patch the five comparisons in the Blueprints and ship a `_P.pak`. Works
  with no runtime cost but breaks on every game update, needs cooking tools, and cannot be
  switched off in game. Last resort only.

---

## 5. Penalty model

### 5.1 Formula

Same quality scale as HTR's gear bonus (`htr/gear.lua`):

```
q(L)  = clamp( ln(L) / ln(MaxLevel), 0, 1 )          MaxLevel = 60
gap   = max(0, q(itemLevel) − q(yourLevel))           = ln(item/you) / ln 60 below 60
p     = clamp( gap / FullPenaltyGap, 0, 1 )           FullPenaltyGap = 0.30
```

`p` (0..1) depends on the **ratio** of item level to your level: the full penalty arrives at
about 3.4× your level; an item at 2× your level gives p ≈ 0.56; the ±2 level noise of normal
loot gives almost nothing. Rarity does not count (the vanilla lock ignores it). Your level is
`Q1_Character.PlayerLevel` (character level).

Effects at p = 1 (scaled linearly by p; all configurable):

| Kit | Effect | Max | Mechanism | Phase |
|---|---|---|---|---|
| Firearm | extra recoil kick per shot | +40 % | post-hook `Master_Hand_Weapon_C:SpawnProjectile` (once per trigger pull, pellets included) → `pawn:AddControllerPitchInput(−rand(0, 0.25)·0.40·p)` and yaw `±0.1·0.40·p` | 2 |
| Firearm | slower reload | +20 % time | at reload start: montage play rate `1/(1+0.20p)`; after the vanilla refill, keep `EBBarrel.ShootingBlocked = true` until the slowed montage ends | 2b (needs in-game check) |
| Melee | more stamina per swing | +25 % | post-hook `Q1_Character_C:Refresh Melee Weapon` / `SpawnMeleeWeapon`: `MeleeWeaponReqStamina *= 1 + 0.25p` (recomputed by the game each time, so no stacking) | 2 |
| Suit | more stamina drain (sprint, swings) | +20 % | post-hook `ALS_Base_C:ReceiveTick`, clock check first, then only the player, 5 times a second: when `CurrentStamina` **dropped** since the last look, subtract an extra `0.20·p·drop`; regeneration untouched. (The game's `UpdateStamina` event only reaches the ship's LGUI panel `Character_Stats_C`, which does not exist on foot: verified in game.) | 2 |
| Suit | slightly lower sprint speed | off (0 %) | post-hook `ALS_Base:UpdateDynamicMovementSettings`, scale `MaxWalkSpeed` (idea from the Tactical FPS notes) | 3, optional |
| Firearm | aim sway while aiming | off | per-frame view drift; **leave to the Tactical FPS mod**, which owns aim feel; this mod would only feed it `p` | 3, optional |

Never changed: damage, penetration, rate of fire, magazine, protection (with HTR), movement
speed (by default). The item is exactly as good as it is; you just handle it worse.

### 5.2 Numbers

| You | Item | p | Recoil | Reload | Suit stamina | Melee stamina |
|---|---|---|---|---|---|---|
| 1 | 5 | 1.00 | +40 % | +20 % | +20 % | +25 % |
| 5 | 10 | 0.56 | +23 % | +11 % | +11 % | +14 % |
| 10 | 12 | 0.15 | +6 % | +3 % | +3 % | +4 % |
| 10 | 15 | 0.33 | +13 % | +7 % | +7 % | +8 % |
| 10 | 20 | 0.56 | +23 % | +11 % | +11 % | +14 % |
| 10 | 30 | 0.89 | +36 % | +18 % | +18 % | +22 % |
| 10 | 60 | 1.00 | +40 % | +20 % | +20 % | +25 % |
| 20 | 22 | 0.08 | +3 % | +2 % | +2 % | +2 % |
| 30 | 40 | 0.23 | +9 % | +5 % | +5 % | +6 % |
| 30 | 60 | 0.56 | +23 % | +11 % | +11 % | +14 % |
| 50 | 60 | 0.15 | +6 % | +3 % | +3 % | +4 % |

### 5.3 Without HTR (standalone)

Vanilla damage scales with item level (×3.7 from level 10 to 40), so "any level" alone
would trivialise combat. Option `Standalone.DamageCapLevels` (default 5, used only when HTR
is not detected): after `Q1_Character_C:SpawnAndAddWeapon`, scale the spawned
`Master_Hand_Weapon.Damage` by `W(min(item, you + 5)) / W(item)` with `W(L) = 5 + 3.975·L`
(the linear `W_Damage` curve). A level-40 gun at level 10 then hits like a level-15 gun
(×0.39). HTR is detected by `Mods\HardcoreTacticalRealism\enabled.txt` or a
`HardcoreTacticalRealism : 1` line in `Mods\mods.txt`.

Suits without HTR keep their vanilla armor (realistic: armor is armor) unless the user turns
on `SuitArmorCap` (open question, §9).

### 5.4 Training (familiarity with use)

Using an over-level item makes you familiar with it, so its penalty fades before you level
up. Training can remove up to `MaxRelief` = 75 % of the penalty; the last quarter only goes
away with levels (experience still matters).

```
penalty = p × (1 − MaxRelief × min(1, used / needed))
```

| Kit | Counted | Full familiarity (default) | Hook |
|---|---|---|---|
| Gun | rounds fired (trigger pulls) | 400 (~13 rifle magazines) | `Master_Hand_Weapon_C:SpawnProjectile` |
| Melee | swings | 120 | `Q1_Character_C:MeleeAttack` (UNTESTED: once per swing?) |
| Suit | stamina spent in it, in full bars | 20 bars | `ALS_Base_C:ReceiveTick` (as the penalty) |

- The game has no unique item id (generated items share ids like `Random3`), so an item is
  identified by kind + name + level + rarity. Two identical drops share their training.
- Only over-level items are counted. Kept in `training.txt` next to the mod (per install,
  not per save slot), written at most every 30 s and when the mod is toggled.
- Example: level 10 with a level-30 rifle, p = 0.89 → +36 % recoil new; after 200 rounds
  +22 %; after 400 rounds +9 %, which stays until you level up.

---

## 6. Cooperation with HTR

- The mods share no code or state (each UE4SS mod has its own Lua state). Both read the same
  item fields, so nothing needs wiring.
- HTR's gear bonus keeps using the item's level; this mod never changes item data.
- The bypass never alters `GetPlayerLevel` for `Q1_Character` or NPCs, so HTR's
  `PlayerLevel`, NPC stats and squad levels are untouched.
- Net effect, HTR gear bonus on, level-10 character (own-level gun: +4.5 pen, +8.4 % dmg):

| Gun level | HTR bonus | Extra vs own-level gun | Handling cost |
|---|---|---|---|
| 15 | +5.3 pen, +9.9 % | +0.8 pen, +1.5 % | +13 % recoil, +7 % reload |
| 20 | +5.9 pen, +11.0 % | +1.4 pen, +2.6 % | +23 % recoil, +11 % reload |
| 30 | +6.6 pen, +12.5 % | +2.1 pen, +4.1 % | +36 % recoil, +18 % reload |
| 60 | +8.0 pen, +15.0 % | +3.5 pen, +6.6 % | +40 % recoil, +20 % reload |

  A minor bonus with a small, noticeable cost: what the request asked for.
- **Suits with HTR (decided).** Weapons follow "level gives a small HTR bonus, never the
  class"; suits should follow the same rule. If T6 confirms the `MaxArmor / MaxHP` jump
  (§3), the balanced and realistic fix is **in HTR**: compute the player's armor rating with
  the suit normalised to its own level (suit armor at its level ÷ HP at that same level,
  about 0.83–0.89 at every level), so the suit's level never moves the armor class; level then
  acts only through HTR's gear bonus (up to +8 rating), like weapons. This mod adds the
  stamina cost and leaves protection alone. Fallback only if HTR cannot change: a
  `SuitArmorCap` here (post-hook on `Game_Builder_C:Calculate Character Stats`, scale the
  suit's share of the out param `MaxArmorr1`), not written.
- Both mods hook `ALS_Base`/player events; UE4SS allows several hooks on one function. Keep
  each callback under 1 ms (HTR's slow-hook watchdog rule).

---

## 7. Config (all off by default)

`scripts/config.lua`:

```lua
Enabled = false            -- master switch; the toggle key flips it in game (remembered in state.txt)
ToggleKey = "Shift+Delete" -- works anywhere (Delete is free in every context); shared key plan rev 2
Unlock = { PickLists = true, ShopShowsAllLevels = false }
Penalty = { Enabled = true, MaxLevel = 60, FullPenaltyGap = 0.30,
            Recoil = 0.40, Reload = 0.20, MeleeStamina = 0.25, SuitStamina = 0.20,
            SuitSprintSpeed = 0.0 }
Training = { Enabled = true, Rounds = 400, Swings = 120, SuitBars = 20, MaxRelief = 0.75 }
Standalone = { DamageCapLevels = 5 }   -- only when HTR is not installed; 0 = no cap
Notify = true              -- one HUD line per over-level item
Debug = { Log = false, SlowHookMs = 8 }
```

There is one unlock switch (the mod itself): the lock widgets cannot tell a suit from a
weapon at the moment `GetPlayerLevel` runs, so per-type unlocks would need extra hooks for
little value. Per-type strength lives in `Penalty`.

---

## 8. Risks

| Risk | Assessment |
|---|---|
| Saves | No item or save data is written. Over-level gear equipped with the mod stays equipped after removing it (the game never re-checks on load). Safe to add/remove. |
| Shops / economy | Buying was never level-locked; prices scale with level (~1 200 credits per level), so shop gear stays self-limiting. The real change is **free enemy drops** from higher-level NPCs: with HTR this is a minor bonus; without HTR the damage cap (§5.3) keeps it fair. |
| UI | On-foot UI shows item level as plain "L{n}" — no red text. The "High Level" cursor warnings simply stop appearing. The "show unusable" shop filter keeps hiding over-level items unless `ShopShowsAllLevels`. |
| Wrong context overridden | Only `Whom = 0` with a lock-widget class, or one armed `Game_Builder` call. Worst case if arming leaks: one unrelated `Game_Builder` call (e.g. contract generation) sees level 999 once. Mitigated by one-shot + 0.25 s expiry + disarm hooks. |
| Out param not written back for a static pure function | Possible (only verified on member functions). Detect in T1; fall back to §4.2 B. |
| Performance | `GetPlayerLevel` hook: one param read on hot paths. Recoil hook: per shot, two native calls. Stamina hook: per stamina change, player only. Profile like HTR (T8). |
| Other mods | Tactical FPS may add aim sway/recoil: agree that it owns sway and this mod only adds recoil kick. HTR: no conflict. |
| Game patch | All names in `scripts/gal/gamedefs.lua`; re-check with `tools/sb2dump` + `kis.py` (`Q1FunctionLibary`, the four widgets, `Game_Builder`, `Master_Hand_Weapon`, `Q1_Character`, `Character_Stats` HUD). |

---

## 9. Decisions (user, 2026-10-30)

1. **Suit protection with HTR:** "the most balanced with realism" → fix in HTR if T6
   confirms the jump (suit level never changes the armor class; small gear bonus only).
   See §6. Needs the HTR owner.
2. **Training:** yes → §5.4 (fades up to 75 % of the penalty with use).
3. **Ship gear:** later; include now only if easy → it is not (§2.2), phase 4.
4. **Toggle key:** F6 only if the game does not use it → it does (quick save, all presets;
   `Q1Controller` `InpActEvt_X_QuickSave`). Now **Shift+Delete**, from revision 2 of the
   shared key plan (laptop-safe: no Home key, Ctrl/Alt are game actions on foot, Shift is the
   only modifier; on/off toggles use keys the game leaves free everywhere). Engineering
   Turrets owns plain Delete and keeps it quiet while Shift is held. Works on foot and in a
   ship.
5. **Penalty strength:** the maxima (+40 % recoil, +20 % reload, +20/25 % stamina) are kept.

Still open: real numbers from tests T5–T7 may move the defaults.

---

## 10. Phased plan

| Phase | Content | Done when |
|---|---|---|
| 1 | Lock bypass (4.1) for weapons (A, E), suits (B, C, E), melee (D), pick list (G). HUD line on equip. Config + toggle. | T1–T4 pass, T8 budget met |
| 2 | Penalties: recoil kick, melee stamina, suit stamina; training (§5.4). | T5, T7, T12 pass |
| 2b | Reload penalty (montage rate + `ShootingBlocked` window). | T9 pass, no stuck "can't shoot" state |
| 3 | Standalone damage cap; optional sprint speed; training (if wanted); README/Nexus page. | T10 |
| 4 | Optional: ship gear (pilot level). | — |

## 11. In-game test plan

Debug log on (`Debug.Log = true`). One save with a level-10 character, one level-30.
Spawn over-level items with the game's debug generator or kill higher-level NPCs.

| # | Test | Expect |
|---|---|---|
| T1 | Drag a weapon 10+ levels above you onto a weapon slot | Equips; no "High Level"; log shows the override with context `Hand_Weapon_Slot_C`. If the cursor still says "High Level": out param not written back → fallback 4.2 B. |
| T2 | Right-click the same weapon in the inventory grid | Equips into a free slot. |
| T3 | Suit and melee: drag to the equipment slot, right-click, and melee onto a weapon slot | All equip; log shows the armed `Game_Builder` override used exactly once each time, and no override left armed afterwards (also after cancelling a drag with Esc). |
| T4 | Mod off (toggle) | Vanilla lock is back; level-up, contracts and NPC levels unchanged (compare a contract reward before/after). |
| T5 | Fire 30 rounds with an own-level and an over-level gun | Over-level climbs visibly more; same damage per hit (HTR log). |
| T6 | Read `MaxHP`, `MaxArmor` with own-level vs over-level suit | Note the ratio → answers open question 1. |
| T7 | Sprint 10 s with own-level vs over-level suit; 10 melee swings | Stamina bar empties ~p·20 % / ~p·25 % faster; regeneration unchanged. |
| T8 | 5 minutes of ground combat and 2 minutes of space combat, hook profile on; HTR's frame-time routine (`dev/run_test.ps1`, local) with and without the mod | No stutter; total mod time < 1 ms/s; no "slow hook" warnings; frame times equal to the baseline. |
| T9 | Reload over-level gun 10× (also cancel by sprinting / switching weapon) | Longer reload; firing never stays blocked after a cancel. |
| T10 | Without HTR installed: level-40 gun at level 10 | Damage capped to a level-15 gun. |
| T11 | Save, quit, reload with over-level gear equipped; then remove the mod and reload | Gear still equipped and working both times. |
| T12 | Fire 200 rounds with an over-level gun, 60 swings, sprint ~10 bars in an over-level suit; restart the game | `training.txt` has the three items; penalties about half way down (log); still there after the restart. Shift+Delete toggles the mod on foot and in a ship (HUD line in both), and does not trigger Engineering Turrets' plain Delete. |

## 12. In-game test, 2026-10-30

Steam build of 2026-10-26, UE4SS 3.0.1, HTR 0.4.5 on, SB2HOTAS off, throwaway `GearTest` slot
(copy of the pre-test backup, deleted afterwards; no other save changed). The PC was locked,
so everything was driven from the dev console (SB2DevRepl); no mouse input.

| Check | Result |
|---|---|
| Mod loads, 13 hooks register, HTR detected | yes |
| `GetPlayerLevel` override: lock widgets get 999 | yes (`Hand_Weapon_Slot_C`, `Character_Equipment_slot_C`) |
| Other callers keep the real level | yes (`BP_Contract_Generator_C`, `Q1_Character_C`) |
| Out param written in a post-hook reaches a Blueprint caller | yes (`Q1_Character:Refresh` stored the written value) |
| Item lands in the slot through the real UI (mouse, second run) | yes: right-click on the L18 suit at level 13 equipped it (lock E + `EquipSuit` re-check); dragging the L12 sniper onto Rifle-1 at level 8 equipped it (lock A), the old rifle went back to the inventory. A hand-built `OnDrop` from the console equips nothing even in vanilla, so the first run could not show this |
| Recoil: L30 gun at level 8 (p = 1.00) | 3 extra kicks; view +0.53° up, −0.21° sideways (= logged inputs × 2.5) |
| Suit stamina: L30 suit at level 8 | drops of 40 and 38 cost 8.0 and 7.6 more (+20 %); regeneration unchanged |
| Training | `training.txt` counted the 3 rounds (`gun|70|30|1  3.00`) |
| Frames, 45 s idle, same spot and prep | mod on: 107 fps, median 9.0 ms, p99 20 ms, 4 isolated spikes ≤ 31 ms; mod off: 105 fps, median 9.0 ms, p99 20 ms, 1 spike 26 ms |

Lessons (in the code comments too):
- Never call a method on a possibly empty object reference (e.g. `CurrentWeapon.ChildActor`
  with no weapon drawn): UE4SS dereferences null and the game crashes (`EXCEPTION_ACCESS_VIOLATION`
  reading 0x10); `pcall` cannot catch it. Two test commands did that; the mod now checks every
  object chain (`U.child`).
- The mod reads no text properties of items (name, subtype); items are identified by numbers.
- During a weapon drop the one-shot `Game_Builder` permission can be taken by the game's
  auto-equip of the weapon that just left the slot (seen in the test; that weapon stayed in the
  inventory). Consequence: a melee item dropped on a gun slot may still show "High Level";
  the melee slot and right-click work.

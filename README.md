<p align="center"><img src="docs/banner.png" alt="Gear Without Levels - any weapon, any level, skill over stats" width="100%"></p>

# Gear Without Levels — for SpaceBourne 2

In SpaceBourne 2 a weapon or suit above your character level cannot be equipped ("High Level").
That is an MMO rule: a better rifle does not need a level. What a rookie lacks is familiarity with
advanced kit. **Gear Without Levels** removes the level lock for weapons, melee weapons and suits.
Kit above your level always works, but handles a little worse until you have the experience for it.

**Links:** [GitHub](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels) ·
[Nexus Mods](https://www.nexusmods.com/spacebourne2/mods/7) · UE4SS Lua mod · works alone or with
[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism)
and the rest of the realism set.
**Install the whole realism set in one go:** the
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)).

## Features

### No level lock

- **Equip anything.** Weapons, melee weapons and suits above your level can be equipped from the
  inventory, the character screen and the shops.
- **Nothing else changes.** Damage, protection and rate of fire are **never** changed. The mod
  changes no items and nothing in your saves. Gear you equipped with it stays equipped if you remove
  it later.

### Small handling penalties

- **Firearms kick a bit more** per shot (up to +40 %).
- **Melee weapons cost a bit more stamina** per swing (up to +25 %).
- **An advanced suit tires you a bit faster** when sprinting or swinging (up to +20 %).
- **On a log scale.** The penalty depends on how far above you the item is: an item at twice your
  level gives about half of it, the ±2 levels of normal loot give almost nothing, and a veteran
  adapts faster than a rookie.
- **A short line tells you.** When you equip unfamiliar kit, the HUD shows for example "Unfamiliar
  suit (L12, you L5): 18% worse until trained", for 6 seconds, without a beep.

### Training

- **Use it and you learn it.** Rounds fired with a gun, swings with a blade and exertion in a suit
  make you familiar with that item and remove up to three quarters of its penalty before you level
  up.

### With Hardcore Tactical Realism

- Built as a companion to **Hardcore Tactical Realism (HTR)**, where damage depends on calibre,
  armor and hit zone instead of item level. With HTR's optional gear bonus (F8) on, an over-level
  weapon still gives its small HTR bonus (up to +8 penetration, +15 % damage at level 60), so the
  result is a **minor bonus with a small handling cost**.
- Without HTR, vanilla weapon damage grows a lot with item level (×3.7 from level 10 to 40), so this
  mod caps an over-level gun to the damage of a gun 5 levels above you. It never becomes an exploit.

### On by default

- On as soon as it is installed. **Shift+Delete** switches it off and on in game; your choice is
  remembered between sessions.

## Install

**A. SpaceBourne 2 Realism installer (recommended)**
Get it on [Nexus](https://www.nexusmods.com/spacebourne2/mods/11) or
[GitHub](https://github.com/hubertdungen/SpaceBourne2-Realism/releases/latest). Tick Gear Without
Levels and any other mods of the set: it installs UE4SS if you don't have it, switches the mods on
and keeps them updated.

**B. Manual** (Nexus file, or the zip on the [releases page](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels/releases))
1. Extract the zip into your game folder (`...\SpaceBourne 2`, the one with `SpaceBourne2.exe`).
   It creates `SB2\Binaries\Win64\Mods\GearWithoutLevels` and switches itself on.
2. No UE4SS yet? Get [RE-UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1)
   and copy `dwmapi.dll`, `UE4SS.dll` and `UE4SS-settings.ini` into
   `SpaceBourne 2\SB2\Binaries\Win64\`.

**Uninstall:** untick Gear Without Levels in the installer or delete the `GearWithoutLevels` folder.

## Controls

- **Shift+Delete** switches the mod on/off in game (remembered between sessions).

## Settings (`scripts/config.lua`)

- `Enabled` — `false` keeps it off until you switch it on with the key.
- `Penalty` — strength per kit type (recoil, melee stamina, suit stamina) and how fast the penalty
  grows with the level gap.
- `Training` — rounds, swings and stamina bars for full familiarity; how much training can remove
  (default 75 %).
- `Unlock.PickLists` — show over-level items in the character screen's item picker.
- `Unlock.ShopShowsAllLevels` — make the shop's "show unusable" filter treat every item as usable.
- `Standalone.DamageCapLevels` — used only without Hardcore Tactical Realism (see above).

## For modders

- `scripts/gal/gamedefs.lua` holds every game-internal name; after a game update, that is the only
  file to check.
- [DESIGN.md](docs/DESIGN.md) explains where the game enforces the level lock and how the mod works.

Version history: [CHANGELOG.md](CHANGELOG.md).

## The SpaceBourne 2 realism set

Separate mods that work alone or in any combination. The
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)) installs the ones you tick and keeps them updated.

- **[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/4)): realistic ballistics, wounds and tactical AI. The core of the set.
- **[Silent Ops](https://github.com/hubertdungen/SpaceBourne2-SilentOps)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/6)): stealth, silent takedowns and suppressors.
- **[Ammo Discipline](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/12)): carried ammo limits and scavenging, so every magazine counts.
- **[Gear Without Levels](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/7)): use gear above your level, with small handling penalties.
- **[Tactical First Person](https://github.com/hubertdungen/SpaceBourne2-TacticalFirstPerson)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/15)): first person on foot, weapons held up, aiming down the sights.
- **[Tactical Engineering](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/10)): realistic deployable turrets.
- **[Get Out of the Way](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/14)): NPCs step aside naturally when you walk through them.
- **[Ground Waypoints](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/13)): planet waypoints on foot and on the hoverbike.
- **[Faction Power](https://github.com/hubertdungen/SpaceBourne2-FactionPower)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/9)): dungeons, strategic sales and missions earn your faction power.
- **[Bigger Armies](https://github.com/hubertdungen/SpaceBourne2-BiggerArmies)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/17)): twice the general slots for your faction's ground and space forces.
- **[Clear HUD](https://github.com/hubertdungen/SpaceBourne2-ClearHUD)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/16)): a reticle you can see and HUD colours of your choice.
- **[Split Controls](https://github.com/hubertdungen/SpaceBourne2-SplitControls)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/5)): separate vertical invert for ship and on foot, per device.
- **[SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)): HOTAS, rudder pedals, triple screens and head tracking.

## License

MIT licensed — see `LICENSE`. Uses [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT).

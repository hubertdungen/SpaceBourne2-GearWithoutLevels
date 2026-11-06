# Changelog

## 0.1.2 — 2026-11-06

- **Fix: a "Fatal Error!" crash that could come at any moment.** The mod's timed work (its
  once-a-second check and the on-screen lines) ran on a UE4SS background thread. When two mods of
  the set did that at the same moment, UE4SS's own bookkeeping broke and the game crashed. All of it
  now runs on the game's own thread, driven by the game's tick on foot, in your ship and in menus
  (the same fix in every mod of the realism set).
- Not tested in game yet.

## 0.1.1 — 2026-11-06

- **A warning you can read.** The "unfamiliar kit" line was long and gone in 2 seconds. It is now
  short, like "Unfamiliar suit (L12, you L5): 18% worse until trained", and stays 6 seconds.
- **No beep.** The game's HUD beeped on every line. Gear Without Levels' lines are now silent, and
  the same line shows at most once in 30 seconds.
- Tested in game through Ammo Discipline 0.1.2, which uses the same line code (no beep, the line
  held). The unfamiliar-kit line itself was not shown in that test.

## 0.1.0 — 2026-10-30

First release.

- Weapons, melee weapons and suits above your character level can be equipped (the game's
  "High Level" lock is lifted only where it guards equipping; nothing else sees a changed level).
- Unfamiliar-kit penalties, on a log scale of item level vs your level: up to +40 % recoil per
  shot, +25 % stamina per melee swing, +20 % stamina drain in an over-level suit.
- Training: using an over-level item removes up to 75 % of its penalty before you level up.
- Without Hardcore Tactical Realism, an over-level gun's damage is capped to a gun 5 levels above you.
- Off until you switch it on (Shift+Delete, remembered) or set `Enabled = true`.
- Tested in game with Hardcore Tactical Realism: penalties apply, same frame times as without the mod.

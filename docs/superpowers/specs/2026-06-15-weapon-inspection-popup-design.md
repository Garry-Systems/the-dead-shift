# Weapon Inspection Popup — Design

**Date:** 2026-06-15
**Status:** Approved (pending implementation plan)
**Project:** The Dead Shift (Godot 4 + GDScript)

## Goal

When the player taps a gun tile in the inventory, the detail popup should show the
gun's **real stats** and a **full talent breakdown** — not the current two crammed
summary lines. This makes it possible to actually judge a dropped/looted weapon.

## Background — what exists today

Tapping a tile in the MainMenu inventory grid opens `WeaponDetailPopup` (a modal card
over a dim scrim). Today it shows:

- Title: weapon display name, rarity-colored.
- One wrapped line: `Hardened · +18% DMG  +2 MULTI  +14% MAG` (the terse `stat_summary`).
- One wrapped line: `⟡ Killshot, Napalm, Venom (Lv14)` (the terse `talent_summary` — names only).
- Action buttons: EQUIP / SCRAP (inline two-step confirm) / CLOSE.

All the data needed for a richer view already exists:

- **Stats:** base values live in `Weapons.all()` (`damage`, `fire_interval`, `bullet_speed`,
  `range`, `projectiles`, `mag_size`, `reload_time`). Rolled affix bonuses resolve via
  `WeaponInstance.resolved_stats(inst)` (percent stats: damage/fire_rate/bullet_speed/range/
  reload/mag; flat stats: multishot/pierce/ricochet). These map 1:1 onto `Gun.upgrade_*` hooks.
- **Talents:** each instance talent is `{id, unlock_level, rolls:[0..1 per mod]}`. Its catalog
  def (`Talents.get_talent(id)`) carries `name`, `color`, a `desc` format string, and `mods`
  ranges. `Talents.resolve(def, idx, roll)` gives the real value per mod, so the `desc` can be
  filled with actual numbers.
- **Level/XP:** instance carries `level` + `xp`. Curve (from `Inventory.add_run_xp`): leveling
  from `L` to `L+1` costs `L * 100` XP, and `xp` is the remainder toward the next level.

## Scope

- **In scope:** Enhance the existing `WeaponDetailPopup` content + add pure display helpers
  to `WeaponInstance`.
- **Out of scope (unchanged):** the inventory grid, `WeaponTile` and its terse hover tooltip,
  equip/scrap/close behavior, the crate-opening flow, and any in-run UI.

## Layout

Inside the existing modal card, top to bottom:

```
            HARDENED AK-47               ← title, rarity-colored (unchanged)
            Hardened · Level 7           ← rarity name + weapon level
            XP ▕█████░░░░░▏ 120 / 300     ← progress toward next level

   ─ STATS ─
   DAMAGE        26     (+18%)
   FIRE RATE     8.3/s  (+12%)
   RANGE         754    (+16%)
   RELOAD        1.7s
   MAGAZINE      35     (+16%)
   MULTISHOT     3      (+2)      ← only shown when the gun has it

   ─ TALENTS ─
   ⚡ KILLSHOT      14% chance to crit for +65% dmg
   ⚡ NAPALM        28% chance: 22 dmg/s for 3s
   🔒 VENOM         poison — unlocks at Level 14   ← dimmed

   [ EQUIPPED / EQUIP ]
   [ SCRAP (12–20) ]
   [ CLOSE ]
```

- Title, subtitle (rarity name + `Level N`), and an XP progress bar with `xp / needed` text.
- A **STATS** section header + one row per stat: `LABEL   value   (+bonus)`. The bonus suffix
  appears only when an affix rolled that stat.
- A **TALENTS** section header + one row per talent: colored name + filled effect text. Locked
  talents render dimmed with `🔒` and "unlocks at Level N". Active talents use the talent's own
  color and `⚡`.
- The unchanged action row (EQUIP / SCRAP / CLOSE).
- The **stats + talents region lives in a `ScrollContainer`** with a capped height, so a
  max-roll weapon (up to 7 stats + 3 talents) cannot overflow the card on a portrait screen.
  The action buttons stay pinned below the scroll region and always reachable.

## Architecture

Keep data logic pure (in `WeaponInstance`); keep layout in the popup. New helpers mirror the
existing stateless style of `WeaponInstance` (the instance dict stays the source of truth).

### 1. New pure helpers in `WeaponInstance.gd`

- `full_stats(inst) -> Array` — ordered rows `{label, value, bonus}`. Starts from the base
  `Weapons` def and applies each resolved affix stat **using the same math `Gun` uses** (the
  implementation plan must read `Gun.gd`'s `apply_loot` / `upgrade_*` and mirror those formulas
  exactly, so the popup never disagrees with in-run behavior). Curated core set: Damage, Fire
  Rate, Range, Reload, Magazine — plus Multishot / Pierce / Ricochet only when present (base or
  rolled). `bonus` is `""` when no affix touched that stat.
- `talent_details(inst) -> Array` — rows `{name, color, effect, locked, unlock_level}`. `effect`
  is the catalog `desc` filled with the instance's resolved rolled values via `Talents.resolve`,
  through a small number formatter (round to int for percents/damage; one decimal for seconds).
  `locked = unlock_level > level`.
- `xp_progress(inst) -> Dictionary` — `{level, xp, needed, frac}` where `needed = level * 100`
  and `frac = xp / needed` (guard divide-by-zero).

### 2. Rewrite `WeaponDetailPopup._rebuild()`

Render the sections above from those helpers: title, subtitle, XP bar, STATS section, TALENTS
section, then the existing action row — with the stats+talents in a `ScrollContainer`. All
styling via the existing `PixelTheme` (fonts, colors, styleboxes). No behavior change to equip/
scrap/close.

## Edge cases

- **No talents rolled** (Rusted / common) → the TALENTS section header is hidden entirely.
- **Locked talent** → name shown dimmed (`PixelTheme.TEXT_DIM`) + `🔒` + "unlocks at Level N".
- **Stat with no affix bonus** → row still shows the base value, no `(+…)` suffix.
- **Long content** (max-roll weapon) → `ScrollContainer` prevents overflow; buttons stay reachable.
- **Equipped weapon** → EQUIP/SCRAP gating unchanged (EQUIPPED disabled, can't scrap equipped).

## Testing

No Godot runtime in WSL — Larry F5s. Before that:

1. **Headless compile gate:** `--headless --editor --quit`, grep for errors (ignore the benign
   `menu_background.jpg` JPEG-decode line).
2. **Logic probe:** build a known instance (fixed base + affix + talent rolls + level), print
   `full_stats` / `talent_details` / `xp_progress`, and confirm the resolved numbers and
   locked/active flags are correct before playtest.

## F5 smoke checklist

- Open inventory → tap several guns of different rarities.
- Stat block shows real values; rolled bonuses appear only where an affix rolled.
- Talent rows show filled effect text; locked talents are dimmed with their unlock level.
- Level + XP bar reads correctly; common weapons with no talents hide the TALENTS section.
- A max-roll weapon scrolls instead of overflowing; EQUIP/SCRAP/CLOSE still work.

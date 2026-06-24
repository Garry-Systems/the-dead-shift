# Arsenal Expansion — 11 New Guns + 3 New Fire Mechanics

**Date:** 2026-06-24
**Status:** Design (approved in brainstorm; pending spec review → plan)
**Game:** The Dead Shift (Godot 4 / GDScript)

## Goal

Grow the weapon roster from **10 → 21 guns** so every one of the 7 categories
(Pistol / SMG / Shotgun / Rifle / Sniper / Heavy / Special) holds **exactly 3 guns**.
The batch fills the four thin categories (Pistol, Shotgun, Sniper, Heavy were at 1)
and adds **3 brand-new fire mechanics** as standout guns. Naming/art lean
**military / real-world firearms**. Base stats are **starter values** — a balance
pass tunes them afterward.

## Decisions locked in brainstorm

- **Size:** big batch — 11 new guns, symmetric (3 per category).
- **New mechanics (3):** Explosive AoE, Piercing Beam, Hazard-Pool dropper. (Homing rounds dropped.)
- **Theme:** lean military / real guns.
- **Power positioning:** new guns are *archetypes* (playstyle sidegrades within a
  category). Raw power scaling is handled by the existing rarity/affix/talent loot
  system rolled on top — base stats only set the archetype's feel.

## Architecture principle (reuse-max)

The whole batch follows the **existing extension pattern** — exactly how Nail Gun,
Tesla, and Flamethrower were added:

- New weapon-def keys are read via `def.get(key, default)` in `Gun.configure()` →
  **the existing 10 guns are byte-for-byte untouched** (they never set the new keys).
- Two of the three new mechanics (Explosive, Hazard-Pool) are **a projectile that
  does something on impact** — they share ONE `Bullet` enhancement and reuse
  existing systems (`Shockwave`, `HazardZone`). They stay in the default
  `"projectile"` fire mode.
- Only **one** genuinely new fire mode is added: `"beam"` (the Railgun), mirroring
  the structure of `_fire_cone` / `_fire_lightning`.
- New guns **auto-enter loot** with zero extra code: `LootRoller.roll("")` picks a
  random base from `Weapons.all()`, so generic crates drop them and they roll
  rarities + affixes + talents for free. Only the *type-specific* crates need their
  `bases` lists extended.

## New weapon-def keys (all optional, default = inert)

Added to entries in `Weapons.all()`. Read in `Gun.configure()` via `def.get()`:

| Key | Type | Default | Meaning |
|---|---|---|---|
| `explode_radius` | float | `0.0` | >0 → shell detonates a `Shockwave` blast on impact/expiry |
| `explode_force` | float | `0.0` | knockback force passed to `Shockwave.blast` |
| `pool` | String | `""` | non-empty → shell spawns an enemy-only `HazardZone` on impact/expiry |
| `pool_radius` | float | `90.0` | pool radius (px) |
| `pool_duration` | float | `3.0` | pool lifetime (s) |
| `pool_slow` | float | `0.0` | slow factor applied to enemies in the pool (0 = none) |
| `pool_slow_dur` | float | `0.0` | slow duration (s) |
| `beam_width` | float | `28.0` | `"beam"` mode: half-corridor width (px) of the hitscan line |

**Damage flows through `damage` for every gun, including delivery shells.** The
explosion's blast damage and the acid pool's dps both equal the shell's `damage`
(= `gun.damage`, scaled by damage upgrade cards + damage affixes). There is no
separate `pool_dps`/`explode_damage` key — that keeps damage scaling uniform and
avoids dead upgrade cards.

Existing optional keys reused: `fire_mode`, `base_pierce`. Per-gun mechanic params
live **in the def** (consistent with `jump_count` / `cone_angle` / `jump_radius`),
not in `GameConfig`.

## The 11 new guns (canonical `Weapons.all()` entries)

Starter stats — tune in the balance pass. `upgrades` lists only reference existing
upgrade-card ids (`damage, fire_rate, range, bullet_speed, ricochet, pierce, reload,
mag, choke, projectile, incendiary`). No new upgrade cards in this batch.

### Pistol (1 → 3)

```gdscript
{
  "id": "magnum", "name": "Magnum", "desc": "Hand cannon — slow, brutal, punches through", "category": "Pistol",
  "fire_mode": "projectile", "base_pierce": 1,
  "damage": 55.0, "fire_interval": 0.45, "bullet_speed": 950.0,
  "range": 700.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 6, "reload_time": 1.4,
  "upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
},
{
  "id": "machine_pistol", "name": "Machine Pistol", "desc": "Full-auto sidearm — spray it", "category": "Pistol",
  "damage": 14.0, "fire_interval": 0.09, "bullet_speed": 850.0,
  "range": 480.0, "projectiles": 1, "spread": 0.10,
  "mag_size": 18, "reload_time": 1.2,
  "upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
},
```

### SMG (2 → 3)

```gdscript
{
  "id": "pdw", "name": "PDW", "desc": "Compact PDW — blistering fire rate, deep mag", "category": "SMG",
  "damage": 10.0, "fire_interval": 0.06, "bullet_speed": 900.0,
  "range": 500.0, "projectiles": 1, "spread": 0.07,
  "mag_size": 40, "reload_time": 1.5,
  "upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
},
```

### Shotgun (1 → 3)

```gdscript
{
  "id": "auto_shotgun", "name": "Auto Shotgun", "desc": "Semi-auto — keeps the lead coming", "category": "Shotgun",
  "damage": 12.0, "fire_interval": 0.30, "bullet_speed": 800.0,
  "range": 360.0, "projectiles": 4, "spread": 0.40,
  "mag_size": 8, "reload_time": 1.9,
  "upgrades": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary", "reload", "mag"],
},
{
  "id": "slug_gun", "name": "Slug Gun", "desc": "Solid slug — a shotgun that reaches out and pierces", "category": "Shotgun",
  "fire_mode": "projectile", "base_pierce": 2,
  "damage": 60.0, "fire_interval": 0.70, "bullet_speed": 1000.0,
  "range": 650.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 5, "reload_time": 2.0,
  "upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
},
```

### Rifle (2 → 3)

```gdscript
{
  "id": "battle_rifle", "name": "Battle Rifle", "desc": "Marksman DMR — fast, accurate, hits hard", "category": "Rifle",
  "damage": 45.0, "fire_interval": 0.28, "bullet_speed": 1200.0,
  "range": 850.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 12, "reload_time": 1.7,
  "upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
},
```

### Sniper (1 → 3)

```gdscript
{
  "id": "railgun", "name": "Railgun", "desc": "Magnetic rail — instant beam, pierces everything in line", "category": "Sniper",
  "fire_mode": "beam", "beam_width": 28.0,
  "damage": 90.0, "fire_interval": 0.85, "bullet_speed": 0.0,
  "range": 1100.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 5, "reload_time": 2.2,
  "upgrades": ["damage", "fire_rate", "range", "incendiary", "reload", "mag"],
},
{
  "id": "anti_materiel", "name": "Anti-Materiel Rifle", "desc": ".50 cal — devastating, line-piercing, painfully slow", "category": "Sniper",
  "fire_mode": "projectile", "base_pierce": 3,
  "damage": 160.0, "fire_interval": 1.10, "bullet_speed": 1600.0,
  "range": 1300.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 4, "reload_time": 2.6,
  "upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
},
```

### Heavy (1 → 3)

```gdscript
{
  "id": "grenade_launcher", "name": "Grenade Launcher", "desc": "Lobbed shells detonate in a crowd-clearing blast", "category": "Heavy",
  "fire_mode": "projectile", "explode_radius": 130.0, "explode_force": 600.0,
  "damage": 50.0, "fire_interval": 0.80, "bullet_speed": 650.0,
  "range": 600.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 6, "reload_time": 2.2,
  "upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
},
{
  "id": "lmg", "name": "LMG", "desc": "Belt-fed — more punch than the minigun, less spray", "category": "Heavy",
  "damage": 16.0, "fire_interval": 0.07, "bullet_speed": 880.0,
  "range": 600.0, "projectiles": 1, "spread": 0.09,
  "mag_size": 100, "reload_time": 3.2,
  "upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "pierce", "incendiary", "reload", "mag"],
},
```

### Special (2 → 3)

```gdscript
{
  "id": "acid_cannon", "name": "Acid Cannon", "desc": "Caustic shells leave a melting acid pool — area denial", "category": "Special",
  "fire_mode": "projectile", "pool": "acid",
  "pool_radius": 90.0, "pool_duration": 3.5, "pool_slow": 0.4, "pool_slow_dur": 1.0,
  "damage": 35.0, "fire_interval": 0.55, "bullet_speed": 700.0,
  "range": 520.0, "projectiles": 1, "spread": 0.0,
  "mag_size": 10, "reload_time": 2.0,
  "upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
},
```

Resulting category counts: Pistol 3, SMG 3, Shotgun 3, Rifle 3, Sniper 3, Heavy 3, Special 3 = **21 total**.

## New-mechanic implementation

### 1. Delivery shells (Explosive + Hazard-Pool) — `Bullet.gd`

Both the Grenade Launcher and Acid Cannon fire a normal projectile that **detonates
on impact or expiry** instead of dealing direct hit damage. Implemented as one
shared "on-death effect" on `Bullet`.

- New `Bullet` vars: `explode_radius := 0.0`, `explode_force := 0.0`,
  `pool_cfg := {}` (set by `Gun._spawn_bullet`).
- Add a private `_detonate()` helper. It runs the on-death effect (if any) at the
  bullet's current position, then the caller frees the bullet:
  - `explode_radius > 0` → instantiate a `Shockwave`, set its `global_position`,
    add to the scene, then `blast(explode_radius, damage, explode_force, gun, player)`.
    `Shockwave.blast` already does radial damage + knockback + on-hit talent procs
    (reads `gun.talent_payload`) + the lavender ring VFX.
  - `pool_cfg` non-empty → instantiate a `HazardZone`, set `global_position`,
    `add_child`, then `configure_hazard(pool_cfg)`. The cfg carries
    `hurts_player = false` so the pool damages **enemies only** (see §3).
- A "delivery shell" is identified by `explode_radius > 0 or not pool_cfg.is_empty()`.
  For such shells, on enemy contact / cover contact / `max_travel` / lifetime,
  call `_detonate()` then `queue_free()` **without** applying direct hit damage and
  **without** pierce/ricochet (the AoE/pool *is* the damage — no double-dip).
- The `gun` / `player` passed to `Shockwave.blast` come from
  `talent_player` and `talent_player.gun` (already available on the bullet; guard
  for null/invalid as the existing talent block does).
- Normal bullets: `explode_radius == 0` and `pool_cfg == {}` → `_detonate()` is a
  no-op and the existing hit/pierce/ricochet logic is unchanged.

Detonation points to wire: the three existing `queue_free()` sites in `Bullet`
(enemy hit, cover hit, `max_travel` in `_physics_process`, lifetime in
`_physics_process`) each call `_detonate()` first when the bullet is a shell.

### 2. Piercing Beam — `Gun._fire_beam` + `Beam.gd`

A new `"beam"` fire mode, dispatched in `Gun._fire(dir)` alongside `cone`/`lightning`.

- `_fire_beam(dir) -> bool`:
  - Gather candidate enemies with
    `LineOfSight.filter_visible(global_position, get_nodes_in_group("enemies"), space)`
    (cover-aware, same helper Tesla/Flamethrower use).
  - Keep enemies that are **in front** along `dir`, within `gun_range`, and within
    `beam_width` perpendicular distance of the aim ray (point-to-line distance).
  - For each: `roll := TalentEngine.roll_damage(damage, talent_payload)`,
    `e.take_damage(roll.damage)`, then `flash_hit()` / `ignite()` (if incendiary) /
    `TalentEngine.process_hit(...)` on survivors — exactly the per-enemy block used
    in `_fire_cone`. The beam **pierces all** matched enemies (no falloff).
  - `_show_muzzle(dir.angle())`, spawn the `Beam` VFX from `global_position` to
    `global_position + dir * gun_range`, return `true` (fires even into empty air,
    like the cone — it's an aimed instant beam).
- `Beam.gd` (new, `class_name Beam extends Node2D`): mirrors `Lightning.gd`'s
  lifecycle but draws **one straight thick fading line** from `start` to `end`.
  Color = **C4 lavender `Color(0.878, 0.898, 1.0)`** (the player color, same as
  `Shockwave.RING_COLOR`) → **stays inside the strict 4-color palette** (no new
  exception needed, unlike the cyan/orange of Lightning/FlameCone). Short life
  (~0.10–0.14 s), `z_index = 5`, frees itself.
- `Gun.configure()` reads `beam_width` via `def.get("beam_width", 28.0)`. The
  `bullet_scene == null` fire-gate in `_process` is already projectile-only, so beam
  mode fires without a bullet scene.

### 3. Enemy-only pools — `HazardZone.gd`

Environmental hazard pools damage **both** the player and enemies (area denial).
A weapon-spawned pool must hurt **enemies only**.

- Add `var _hurts_player := true`.
- In `configure_hazard(cfg)`: `_hurts_player = bool(cfg.get("hurts_player", true))`.
- In `_apply(dt)`: gate the player-damage block with `if _hurts_player and ...`.
- Env hazards never set `hurts_player` → default `true` → **environmental hazards
  are unchanged**. The Acid Cannon's `pool_cfg` sets `hurts_player = false`.
- The weapon pool's cfg is built at detonation in `Bullet._detonate()`: `color =
  Hazards.GREEN`, **`dps = `the shell's `damage`** (so damage cards/affixes scale
  it), `radius`/`duration`/`slow`/`slow_dur` from the def's `pool_*` keys, and
  `stun:0, chain:0, drift:0, hurts_player:false`. `pool_radius`/etc. are independent
  of the environmental-hazard `GameConfig.ACID_*` values, so weapon balance is
  decoupled. (Pools carry no weapon talents in v1 — area-denial DoT only.)

## Loot / crate wiring — `Crates.gd`

Generic crates need no change (they pull from all of `Weapons.all()`). Extend the
three type-specific crates' `bases` lists by flavor:

- **Buckshot & Bolts** (`precision_pack`, shotguns + bolts): add `auto_shotgun`,
  `slug_gun`, `railgun`, `anti_materiel`.
- **Full Auto Case** (`auto_case`, rapid fire): add `pdw`, `machine_pistol`, `lmg`.
- **Standard Arms** (`standard_arms`, staples / single-shot): add `magnum`,
  `battle_rifle`, `grenade_launcher`.
- `acid_cannon` (Special) stays generic-only, like Tesla/Flamethrower.

## Art — icons

Each gun loads `res://art/weapons/<id>.png` (falls back to `_placeholder.png`, so
guns are fully playable before art exists). Generate 11 icons via the home repo's
`gen_palette_sprites.py weapons()` for ids: `magnum, machine_pistol, pdw,
auto_shotgun, slug_gun, battle_rifle, railgun, anti_materiel, grenade_launcher,
lmg, acid_cannon`. Icons must obey the strict 4-color palette.

## Balance

All base stats are **starter values**. They position each gun's archetype; the
rarity/affix/talent system scales actual power. Larry's planned balance pass retunes
after on-phone feel. Specific knobs to expect tuning: grenade `explode_radius`/`damage`,
acid `damage` (pool dps) / `pool_radius` / `pool_duration`, railgun `damage`/`beam_width`,
anti-materiel `damage` vs the existing Sniper.

## Out of scope (YAGNI)

- Homing rounds (cut in brainstorm).
- New upgrade cards (radius/pool-size cards) — new guns use existing cards only.
- New rarity tiers / affixes — the batch rides the existing loot system.
- Weapon talents inside the acid pool (pool is dumb DoT for v1).
- Per-gun firing sounds / unique muzzle art (uses the shared muzzle).

## Verification

1. **Headless gate** (WSL Godot 4.6.3): `--headless --editor --quit` compiles clean;
   `--headless --script` a throwaway probe that (a) `Weapons.all()` returns 21 with
   unique ids and valid categories, (b) every new `upgrades` id exists, (c)
   `LootRoller.roll(r, id)` produces a valid instance for each new base across
   rarities, (d) each type crate's `bases` resolve to real weapon ids. Delete the
   probe after (per the project's transient-probe convention).
2. **Per-mechanic logic check (headless where pure):** beam corridor selection,
   cone/explosion membership are static-pure-style — assert hit sets on a synthetic
   enemy layout if feasible; otherwise verify in play mode.
3. **Phone F5 checklist (after merge → APK):**
   - Equip each new gun (DEV grant / crate) — all 21 appear; icons or placeholder show.
   - Magnum one-shots trash + pierces 1; Machine Pistol/PDW spray fast.
   - Auto Shotgun semi-auto cadence; Slug Gun pierces at range.
   - Battle Rifle fast accurate; Anti-Materiel line-pierces 3+.
   - **Railgun**: instant lavender beam, every enemy in the line takes damage; beam
     respects cover.
   - **Grenade Launcher**: shell flies, detonates in a crowd → ring + AoE damage +
     knockback; ignites if incendiary-rolled.
   - **Acid Cannon**: shell lands → green pool; enemies in it melt + slow;
     **the player takes NO damage standing in it**.
   - **Regression — env hazards still hurt the player**: barrel fire / chem acid /
     transformer fields still damage the player (the `hurts_player` default).
   - **Regression — existing 10 guns** behave exactly as before.
   - New guns drop from the right type crates + roll affixes ("Razor Railgun" etc.).

## T0 — verify against the live codebase before implementing

(Per the project's plan-vs-real-codebase discipline.)

- `Shockwave.blast(radius, damage, force, gun, player)` arg order + that the caller
  must set `global_position` and `add_child` **before** calling `blast`. (Confirmed
  in this session — re-confirm at implement time.)
- `HazardZone.configure_hazard(cfg)` cfg keys + that caller sets position +
  `add_child` first; confirm `_apply` is the only player-damage site to gate.
- `LineOfSight.filter_visible(origin, nodes, space)` signature + how
  `get_world_2d().direct_space_state` is obtained inside `Gun`.
- `TalentEngine.roll_damage` / `process_hit` signatures (copy the `_fire_cone` block).
- Enemy methods present: `take_damage`, `flash_hit`, `ignite`, `apply_slow`,
  `apply_knockback`, `apply_freeze`.
- Bullet's exact `queue_free()` sites to hook `_detonate()` (enemy / cover /
  max_travel / lifetime).
- `gen_palette_sprites.py` location (home repo) + its `weapons()` entry format.
- Weapon icon lookup path `res://art/weapons/<id>.png` (confirmed in `WeaponInstance.icon`).

## Files touched

- `scripts/logic/Weapons.gd` — +11 entries.
- `scripts/Gun.gd` — `configure()` reads new keys; `_spawn_bullet` sets shell params;
  `_fire` dispatch `"beam"`; new `_fire_beam`.
- `scripts/Bullet.gd` — shell vars + `_detonate()` + hook the queue_free sites.
- `scripts/HazardZone.gd` — `hurts_player` flag (enemy-only pools).
- `scripts/Beam.gd` — **new** straight-line beam VFX (lavender, in-palette).
- `scripts/loot/Crates.gd` — extend 3 type-crate `bases` lists.
- `art/weapons/*.png` — 11 new icons (home repo `gen_palette_sprites.py`).

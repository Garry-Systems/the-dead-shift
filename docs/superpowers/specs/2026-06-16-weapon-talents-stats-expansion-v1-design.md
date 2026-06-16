# Weapon Talents & Stats — Content Expansion v1 — Design

**Date:** 2026-06-16
**Status:** Approved (pending implementation plan)
**Project:** The Dead Shift (Godot 4 + GDScript)

## Goal

Deepen the crate-weapon loot layer with **more variety** while keeping it pure-RNG
("RNG is king"). Three things grow:

1. The **talent catalog** from 10 → ~31 — keeping all 10 existing, adding **5 brand-new
   marquee behaviors** (new combat verbs) plus **16 data talents** (remixes of the existing
   procs at new tiers/numbers/names).
2. The **affix prefixes** from 1-per-rarity (the rarity name) to **themed archetypes**,
   2–4 per rarity, each biasing a different stat lane.
3. **Display** — themed prefix in the name ("Razor AK-47") with the rarity tier shown as a
   tag (already rendered in the inspection popup as `Hardened · Level N`).

Every number below is a starting point Larry will tweak after reading it. The whole list is
enumerated for exactly that reason.

## Background — what exists today

The loot weapon system (all on `master`):

- A crate rolls a **rarity** (`Rarity.roll`, factorial ladder 1–7). `LootRoller.roll(rarity)`
  picks a random base gun (one of 7 in `Weapons.all()`) + an **affix** matching that rarity.
- The **affix** (`Affixes.gd`) declares which stats can roll (`PCT_STATS`
  damage/fire_rate/bullet_speed/range/reload/mag, `FLAT_STATS` multishot/pierce/ricochet),
  their min/max ranges, how many stats roll (`min_stats`/`max_stats`), and how many talents
  (`min_talents`/`max_talents`). **Today there is exactly one affix per rarity, and its name
  equals the rarity name** (Rusted/Salvaged/Hardened/Lethal/Savage/Merciless/Carnage).
- **Talents** (`Talents.gd`) is a 10-entry catalog, tiered 1–3. `LootRoller._roll_talents`
  fills talent slot *i* (0-based) with a random talent **of tier i+1**, so more talent slots
  (higher rarity) reach the stronger tiers. Each rolled talent stores `{id, unlock_level,
  rolls:[0..1 per mod]}`; it activates once the weapon's persistent `level` ≥ `unlock_level`.
- An instance stores only ids + 0..1 quality rolls; final values resolve as
  `min + (max-min)*roll`, so rebalancing the data tables retroactively rebalances every
  saved weapon. Instance shape: `{uid, base, affix, rarity, level, xp, stats:{id:roll},
  talents:[{id,unlock_level,rolls}]}`.
- **Combat plumbing** (`TalentEngine.gd`): `Gun.apply_loot` resolves the instance's *active*
  talents into a flat `payload = {crit_chance, crit_mult, procs:[...]}` once on equip. Every
  bullet carries the payload and calls `TalentEngine.roll_damage` (crit) on impact and
  `TalentEngine.process_hit` (on-hit/on-kill procs). `process_hit` dispatches by `proc.kind`
  using existing combat hooks: `Enemy.ignite/apply_slow/apply_dot/apply_knockback/take_damage/
  health_fraction/flash_hit`, `Player.heal`, `Gun.add_frenzy`, and engine-local `_chain` /
  `_explode` / `_nearest_excluding`.

### Verified combat-hook surface (read from source 2026-06-16)

- `Enemy.gd`: `take_damage(amount)`, `apply_slow(factor,dur)` (clamps move-speed mult to a
  0.05 floor — **not** a true stop), `apply_dot`, `apply_knockback`, `ignite`,
  `health_fraction`, `flash_hit`. Has `_slow_factor`/`_slow_time` ticked in
  `_physics_process` (`velocity = _desired_velocity() * _slow_factor`). **No damage-taken
  multiplier and no full-freeze state today** — those are the new hooks.
- `Gun.gd`: `add_frenzy(pct,dur)`, `apply_loot(inst)`, `_fire`/`_spawn_bullet`, reload state
  `_reloading`/`_reload_timer`; reload completes in `_process` (`_reloading = false` at line
  ~120). `configure` resets reload state.
- `Bullet.gd`: carries `pierce_count`, `ricochet_count`, `incendiary`/`burn_*`,
  `talent_payload`, `talent_player`; handles pierce/ricochet after each hit.
- `Player.gd`: `heal`, `full_heal`, `take_damage`, `health_fraction`.

## Scope

- **In scope:** `Talents.gd` (catalog), `Affixes.gd` (themed affixes + legacy flag),
  `LootRoller.gd` (roll pool excludes legacy), `TalentEngine.gd` (new resolve/process arms +
  one public area-damage helper), `Enemy.gd` (vulnerable + freeze), `Gun.gd` (surge + reload
  nova + overpen), `Bullet.gd` (overpen damage growth), a couple of `GameConfig` knobs, and a
  small display tweak (rarity tag on the tile, if not already present).
- **Out of scope (unchanged):** the rarity ladder/odds, crate definitions, the inventory grid
  + equip/scrap flow, the crate-opening reel, the in-run level-up *Upgrades* cards, relics,
  character perks, and weapon base stats. **No save migration** (see §6).

## Design decisions (locked with Larry 2026-06-16)

1. **Layer:** crate-weapon loot — affix STATS + the loot Talent procs (not the in-run cards).
2. **Goal:** more content/variety, stays pure-RNG.
3. **Talent ambition:** go nuts — data talents **and** new behaviors.
4. **Affixes:** themed archetype prefixes **and** show the rarity tier as a tag.

---

## 1. Full talent catalog (`scripts/loot/Talents.gd`)

Each talent: `id`, `name`, `kind`, `tier` (= which talent slot it rolls into), `level_required`
`{min,max}` (the rolled per-instance unlock level), and `mods` = ordered `{min,max}` ranges
matching the `%s` placeholders in `desc`. Resolved value = `min + (max-min)*roll`.

**EXISTING (10) — unchanged, listed for context:**

| id | name | kind | tier | unlock min–max | mods (in desc order) | effect |
|---|---|---|---|---|---|---|
| killshot | Killshot | crit | 1 | 1–3 | chance 8–18, mult 40–80 | %chance to crit for +%dmg |
| bloodrush | Bloodrush | onkill_frenzy | 1 | 2–5 | rof 15–30, dur 1.5–3.0 | kills surge fire rate +%for%s |
| concussive | Concussive | onhit_knockback | 1 | 1–4 | chance 15–30, force 120–260 | %chance to knock target back |
| napalm | Napalm | onhit_ignite | 2 | 5–10 | chance 18–35, dps 12–30, dur 2–4 | %chance to ignite |
| frostbite | Frostbite | onhit_slow | 2 | 5–12 | chance 25–45, slow 25–50, dur 1.5–3.0 | %chance to slow |
| livewire | Live Wire | onhit_chain | 2 | 6–12 | chance 20–35, jumps 2–4, dmg 35–60 | %chance to arc |
| venom | Venom | onhit_dot | 3 | 12–20 | chance 30–50, dps 10–22, dur 3–5 | %chance to poison (stacks) |
| bloodthirst | Bloodthirst | onhit_lifesteal | 3 | 14–22 | chance 8–18, heal 2–6 | %chance to heal |
| gutbomb | Gut Bomb | onkill_explode | 3 | 12–20 | chance 50–100, dmg 20–50, radius 70–130 | kill detonates |
| executioner | Executioner | onhit_execute | 3 | 15–25 | threshold 8–15 | instakill below %HP |

**NEW BEHAVIORS (5) — require engine work (see §2):**

| id | name | kind | tier | unlock min–max | mods (in desc order) | effect |
|---|---|---|---|---|---|---|
| marked | Marked | onhit_vulnerable | 2 | 5–12 | chance 20–40, amount 15–35, dur 3–5 | %chance to mark: target takes +%dmg for %s |
| coldsnap | Cold Snap | onhit_freeze | 3 | 14–22 | chance 10–22, freeze 1.0–2.0, shatter 40–90, radius 80–140 | %chance to freeze %s; a hit on a frozen enemy shatters for %dmg (radius %) |
| overflow | Overflow | onkill_surge | 2 | 6–12 | pierce 1–2, shots 1–2, dur 2–4 | kills grant +%pierce & +%shots for %s |
| backblast | Backblast | onreload_nova | 2 | 5–12 | dmg 25–60, radius 120–220 | finishing a reload blasts %dmg (radius %) |
| railbreaker | Railbreaker | overpen | 3 | 12–22 | pierce 2–4, growth 15–30 | shots pierce +% enemies, +%dmg per pierce |

**DATA TALENTS (16) — reuse existing behaviors, no engine work:**

| id | name | kind | tier | unlock min–max | mods (in desc order) | effect |
|---|---|---|---|---|---|---|
| pilotlight | Pilot Light | onhit_ignite | 1 | 1–4 | chance 12–24, dps 6–14, dur 1.5–3 | small burn |
| tar | Tar | onhit_slow | 1 | 1–5 | chance 20–35, slow 15–30, dur 1.5–3 | mild slow |
| marksman | Marksman | crit | 2 | 5–12 | chance 12–22, mult 70–130 | bigger crit |
| adrenaline | Adrenaline | onkill_frenzy | 2 | 5–12 | rof 30–50, dur 2.0–4.0 | bigger kill-surge |
| haymaker | Haymaker | onhit_knockback | 2 | 5–12 | chance 25–45, force 280–460 | hard knockback |
| rot | Rot | onhit_dot | 2 | 6–12 | chance 25–40, dps 8–16, dur 2–4 | moderate poison |
| leech | Leech | onhit_lifesteal | 2 | 8–16 | chance 10–20, heal 1–4 | small lifesteal |
| cluster | Cluster | onkill_explode | 2 | 6–14 | chance 40–70, dmg 12–30, radius 60–110 | small kill-blast |
| mercy | Mercy | onhit_execute | 2 | 10–18 | threshold 5–10 | low execute |
| hollowpoint | Hollowpoint | crit | 3 | 14–24 | chance 20–32, mult 100–180 | monster crit |
| inferno | Inferno | onhit_ignite | 3 | 14–24 | chance 28–48, dps 30–60, dur 3–5 | huge burn |
| glacial | Glacial | onhit_slow | 3 | 12–22 | chance 35–55, slow 50–75, dur 3–5 | heavy long slow |
| arcwelder | Arc Welder | onhit_chain | 3 | 14–24 | chance 30–45, jumps 3–5, dmg 55–90 | big chain |
| plague | Plague | onhit_dot | 3 | 15–25 | chance 40–60, dps 18–34, dur 4–6 | heavy stacking poison |
| daisycutter | Daisy Cutter | onkill_explode | 3 | 15–25 | chance 70–100, dmg 40–80, radius 140–240 | huge kill-blast |
| reaper | Reaper | onhit_execute | 3 | 18–28 | threshold 15–25 | high execute |

**Resulting tier pools** (what `random_of_tier` draws from per slot):
- **Tier 1 (slot 0):** killshot, bloodrush, concussive, pilotlight, tar — *5*
- **Tier 2 (slot 1):** napalm, frostbite, livewire, marked, overflow, backblast, marksman, adrenaline, haymaker, rot, leech, cluster, mercy — *13*
- **Tier 3 (slot 2):** venom, bloodthirst, gutbomb, executioner, coldsnap, railbreaker, hollowpoint, inferno, glacial, arcwelder, plague, daisycutter, reaper — *13*

Colors are per-talent catalog hints (for any UI that wants them); the inspection popup already
colors active vs locked itself (C4/C3) to honor the locked 4-color palette.

---

## 2. Engine wiring for the 5 new behaviors (`TalentEngine.gd` + hooks)

### `resolve_payload` — 5 new `match` arms
- `onhit_vulnerable` → `procs.append({kind:"vulnerable", chance, amount, dur})`
- `onhit_freeze` → `procs.append({kind:"freeze", chance, dur, shatter, radius})`
- `onkill_surge` → `procs.append({kind:"surge", pierce, shots, dur})`
- `onreload_nova` → flat field `payload["reload_nova"] = {dmg, radius}` (Gun reads it)
- `overpen` → flat field `payload["overpen"] = {pierce, growth}` (Gun/Bullet read it)

### `process_hit` — 3 new arms
- **vulnerable** (on alive hit): `if _roll(chance) and body.has_method("apply_vulnerable"):
  body.apply_vulnerable(amount/100.0, dur)`
- **freeze** (on alive hit): **shatter takes priority** — `if body.has_method("is_frozen") and
  body.is_frozen(): detonate(hit_pos, shatter, radius, tree)` (and the body thaws);
  `elif _roll(chance) and body.has_method("apply_freeze"): body.apply_freeze(dur)`. So the same
  talent freezes one hit and shatters the next.
- **surge** (on kill): `if killed and gun valid: gun.add_surge(pierce, shots, dur)`

`reload_nova` and `overpen` are **not** per-hit procs — the Gun reads them from the resolved
payload (see below), so no `process_hit` arm.

### New public helper
`TalentEngine.detonate(pos, dmg, radius, tree)` — a thin public wrapper over the existing
`_explode` so Gun (reload nova) and freeze-shatter can both deal area damage.

### `Enemy.gd`
- `apply_vulnerable(frac, dur)`: `_vuln_bonus = maxf(_vuln_bonus, frac)`,
  `_vuln_time = maxf(_vuln_time, dur)`. In `take_damage`, scale incoming:
  `amount *= (1.0 + minf(_vuln_bonus, GameConfig.TALENT_VULN_MAX))`. Tick `_vuln_time` down in
  `_physics_process`; reset `_vuln_bonus` to 0 on expiry.
- `apply_freeze(dur)`: `_frozen = true`, `_freeze_time = maxf(_freeze_time, dur)`; `is_frozen()`
  returns `_frozen`. In the velocity step, `if _frozen: velocity = Vector2.ZERO` (overrides the
  slow path). Tick `_freeze_time`; clear on expiry. **Visual tell:** while frozen, modulate to a
  palette-compliant tint (proposed **C2 indigo `#3D0099`**), restored on thaw. *(Open: confirm
  tint vs the 4-color palette — see §7.)*
- Ranged/Exploder/Hive subclasses inherit these automatically (they extend `Enemy`); freeze
  zeroes their `_desired_velocity`, and `_act` hooks should early-return while `is_frozen()`.

### `Gun.gd`
- `add_surge(pierce, shots, dur)`: `_surge_pierce`/`_surge_shots`/`_surge_time` (refresh by
  max). Tick in `_process`. In `_spawn_bullet`, `bullet.pierce_count += _surge_pierce` while
  active; in `_fire`, fire `_surge_shots` extra pellets while active.
- **Reload nova:** `apply_loot` stores `_reload_nova = payload.get("reload_nova", {})`. At
  reload-complete (where `_reloading = false`), if non-empty:
  `TalentEngine.detonate(global_position, dmg, radius, get_tree())`.
- **Overpen:** `apply_loot` stores `_overpen = payload.get("overpen", {})`. In `_spawn_bullet`:
  `bullet.pierce_count += _overpen.pierce`, `bullet.overpen_growth = _overpen.growth`.

### `Bullet.gd`
- New `var overpen_growth := 0.0`. On a pierce (the `pierce_count > 0` branch, before
  continuing): `damage *= (1.0 + overpen_growth / 100.0)` so each enemy pierced boosts the
  damage of the next pass-through.

### `GameConfig.gd`
- `const TALENT_VULN_MAX := 1.0` (cap vulnerability at +100% so stacks can't run away).
- (Freeze full-stop, surge, nova, overpen are otherwise self-contained in the data ranges.)

---

## 3. Themed affixes (`scripts/loot/Affixes.gd`)

**Archetypes** (each biases a stat lane; flavor name = the prefix shown in the weapon name):

- **Razor** — damage (+ range/fire_rate at high rarity)
- **Rapid** — fire_rate (+ reload)
- **Heavy** — mag (+ multishot, damage)
- **Hollow** — pierce (+ multishot, range)
- **Longshot** — range (+ bullet_speed, damage)
- **Brutal** — multishot + pierce + ricochet + damage (rarity 5+ only; chaos build)

`min_talents`/`max_talents` are kept per rarity exactly as the legacy ladder so talent counts
don't change: r1 `0/0`, r2 `0/1`, r3 `1/1`, r4 `1/2`, r5 `2/2`, r6 `2/3`, r7 `3/3`.

**Themed affix table** (`stats` = `{stat_id:[min,max]}`; `min/max_stats` = how many of the
affix's keys roll — the roller clamps to the key count):

**Rarity 1 — Rusted tier** (talents 0/0, stats 1/2)
| id | name | stats |
|---|---|---|
| r1_razor | Razor | damage [6,14] |
| r1_rapid | Rapid | fire_rate [6,14], reload [3,10] |

**Rarity 2 — Salvaged tier** (talents 0/1, stats 2/3)
| id | name | stats |
|---|---|---|
| r2_razor | Razor | damage [12,24], range [8,18] |
| r2_rapid | Rapid | fire_rate [8,16], reload [6,14] |
| r2_longshot | Longshot | range [12,24], bullet_speed [10,28] |

**Rarity 3 — Hardened tier** (talents 1/1, stats 2/3)
| id | name | stats |
|---|---|---|
| r3_razor | Razor | damage [20,40], range [14,26] |
| r3_rapid | Rapid | fire_rate [12,22], reload [10,22] |
| r3_heavy | Heavy | mag [14,30], damage [14,28] |

**Rarity 4 — Lethal tier** (talents 1/2, stats 3/4)
| id | name | stats |
|---|---|---|
| r4_razor | Razor | damage [32,58], range [20,36], fire_rate [12,22] |
| r4_heavy | Heavy | mag [20,40], multishot [1,1], damage [24,44] |
| r4_hollow | Hollow | pierce [1,1], multishot [1,1], damage [20,40] |
| r4_longshot | Longshot | range [24,42], bullet_speed [18,40], damage [20,40] |

**Rarity 5 — Savage tier** (talents 2/2, stats 4/5)
| id | name | stats |
|---|---|---|
| r5_razor | Razor | damage [48,84], fire_rate [18,30], range [28,48], bullet_speed [15,40] |
| r5_heavy | Heavy | mag [28,55], multishot [1,2], damage [36,64], reload [15,30] |
| r5_hollow | Hollow | pierce [1,2], multishot [1,2], damage [32,60], range [24,44] |
| r5_brutal | Brutal | damage [40,72], multishot [1,2], pierce [1,2], fire_rate [18,30] |

**Rarity 6 — Merciless tier** (talents 2/3, stats 4/6)
| id | name | stats |
|---|---|---|
| r6_razor | Razor | damage [64,110], fire_rate [28,44], range [36,60], bullet_speed [25,55], reload [25,45] |
| r6_heavy | Heavy | mag [38,75], multishot [2,3], damage [48,88], reload [25,45] |
| r6_hollow | Hollow | pierce [1,3], multishot [2,3], damage [44,84], ricochet [1,1] |
| r6_brutal | Brutal | damage [56,100], multishot [2,3], pierce [1,3], ricochet [1,1], fire_rate [28,44] |

**Rarity 7 — Carnage tier** (talents 3/3, stats 5/7)
| id | name | stats |
|---|---|---|
| r7_razor | Razor | damage [85,145], fire_rate [35,55], range [45,75], bullet_speed [40,80], reload [35,60], mag [40,80] |
| r7_heavy | Heavy | mag [55,105], multishot [2,4], damage [70,120], reload [35,60], pierce [2,4] |
| r7_hollow | Hollow | pierce [2,4], multishot [2,4], damage [64,116], ricochet [1,2], range [45,75] |
| r7_brutal | Brutal | damage [80,140], multishot [2,4], pierce [2,4], ricochet [1,2], fire_rate [35,55], bullet_speed [40,80] |

24 themed affixes total (r1:2, r2:3, r3:3, r4:4, r5:4, r6:4, r7:4).

### Legacy handling — no save migration
The 7 legacy affixes (`rusted`…`carnage`) **stay defined** in `Affixes.all()` so existing saved
weapons still resolve their stored stat rolls, but each is flagged `"legacy": true`. The roller
draws only from non-legacy affixes:
- Add `Affixes.rollable_of_rarity(rarity)` → affixes of that rarity **without** `legacy`.
- `LootRoller.roll` calls `rollable_of_rarity` instead of `of_rarity` (with a fallback to
  rarity 1 if somehow empty). `get_affix`/`of_rarity` are unchanged (still see legacy) so display
  and resolution of old instances are unaffected.

Result: old weapons keep working and display exactly as before; **every new drop is themed.**

---

## 4. Display (`WeaponInstance` / UI)

- `display_name` is already `"<affix name> <base name>"` → themed prefixes give `"Razor AK-47"`
  for free.
- The inspection popup already shows the **rarity tag** as `Hardened · Level N` (from the
  weapon-inspection-popup spec) and colors the name by rarity — so "theme + rarity tag" is
  satisfied in the popup with no change.
- **Tile:** `WeaponTile` shows the name + a rarity-colored border today. Optional small add: a
  one-word rarity label under the name (confirm space during planning; skip if it crowds the
  tile). No data change either way.

---

## 5. Balance notes

- Balance lives in the **data tables** (`Talents.gd` `mods` + `level_required`, `Affixes.gd`
  `stats`), not scattered consts — the only new `GameConfig` knob is `TALENT_VULN_MAX`.
- Tier gating still does the heavy lifting: a tier-1 slot can't roll Inferno; tier-3 talents
  only land on rarity-3+ weapons that have a 3rd talent slot, and their high `level_required`
  means they stay dormant until the gun is leveled.
- The new behaviors are tuned to *feel* like their tier: Marked/Overflow/Backblast (tier 2) are
  reliable build-shapers; Cold Snap+Shatter and Railbreaker (tier 3) are payoff talents.

## 6. Save compatibility

- **Talents:** additive — new ids only appear on *new* rolls. Old instances reference old ids,
  all still present. `TalentEngine` ignores any unknown kind (the `match` simply has no arm), so
  even a hand-edited save can't crash it.
- **Affixes:** legacy ids retained + flagged, never removed → old instances resolve unchanged.
  No `Inventory._ready` remap needed.
- **No new save keys.** The instance shape is unchanged.

## 7. Testing & verification

- **Headless import/compile gate:** `…Godot…_console.exe --path "…\mobile-game" --headless
  --editor --quit`, grep for errors, ignore the benign `menu_background.jpg` JPEG-decode line.
- **Logic probe** (`--headless --editor --script res://probe_talents.gd`; `class_name` globals
  available, autoloads not):
  1. Roll N=500 instances across all rarities; assert no crash, every rolled talent id exists in
     `Talents.all()`, every rolled affix is non-legacy.
  2. For one instance carrying each new kind, `resolve_payload` produces the expected proc/field
     (vulnerable/freeze/surge in `procs`; `reload_nova`/`overpen` as flat fields).
  3. Apply `apply_vulnerable(0.5, 5)` to an `Enemy`, then `take_damage(100)` and assert the HP
     drop reflects ×1.5; `apply_freeze` zeroes its velocity; thaw restores it.
  4. Resolve a hand-built legacy-affix instance (`affix:"hardened"`) and assert its stored stats
     still resolve to non-zero (no migration regression).
- **F5 smoke (Larry):** open crates → see themed names + rarity tag; level a gun so a new-behavior
  talent activates; verify Marked (+dmg tell), Cold Snap (enemy stops → shatters), Overflow
  (post-kill shots pierce), Backblast (nova on reload), Railbreaker (line-clear ramps).

## 8. Open tweakables (redline targets)

- **All talent numbers** — chances, magnitudes, durations, `level_required` gating.
- **All affix stat ranges** + which archetypes appear at which rarity + min/max_stats.
- **Theme/talent names** (gritty gas-station-apocalypse flavor — rename freely).
- **Freeze visual tint** (C2 indigo proposed; must respect the locked 4-color palette).
- Whether to keep legacy affixes in the roll pool at all (default: excluded) and whether to add
  the rarity label to the tile.

## 9. Files touched

| File | Change |
|---|---|
| `scripts/loot/Talents.gd` | +21 catalog entries (5 new-behavior + 16 data) |
| `scripts/loot/Affixes.gd` | +24 themed affixes; flag legacy; `rollable_of_rarity` |
| `scripts/loot/LootRoller.gd` | roll from `rollable_of_rarity` |
| `scripts/loot/TalentEngine.gd` | 5 `resolve_payload` arms, 3 `process_hit` arms, public `detonate` |
| `scripts/Enemy.gd` | `apply_vulnerable`+`apply_freeze`+`is_frozen`, ticks, damage mult, freeze stop/tint |
| `scripts/Gun.gd` | `add_surge`, surge fields, reload-nova, overpen fields |
| `scripts/Bullet.gd` | `overpen_growth` + per-pierce damage growth |
| `scripts/logic/GameConfig.gd` | `TALENT_VULN_MAX` |
| `scripts/ui/WeaponTile.gd` | (optional) rarity label |
| `probe_talents.gd` | new throwaway logic probe |

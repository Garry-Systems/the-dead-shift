# Survivability + new-player wall — balance pass v2, spec 2 of 3 (design)

**Date:** 2026-09-20 · **Target release:** v0.1.75 · **Status:** design approved section-by-section by Larry (buttons), awaiting spec read-through.

**Source:** `docs/superpowers/analysis/2026-09-19/ECONOMY-DIFFICULTY-MAP.md` (flags 4 and 6) and `map_difficulty.md`
§5/§6. Spec 1 (Power Curve, v0.1.74) fixed the *power* side — the player can now clear the horde at a
sane pace. This spec owns what happens **when the horde reaches the player anyway**, and the opening
ninety seconds a brand-new save faces. Spec 3 (economy/meta) is out of scope.

## 1. Problem

- **Deaths are unreadable.** The player has no invulnerability of any kind except the 2 s after a revive
  (`Player.gd:304-323`); dash grants none. Bite-and-bounce (Larry's design, 2026-06-21) gives every enemy
  its own 0.6 s bite cooldown and six shamblers fit around the player, so a surround lands ~10 bites/sec:
  100 HP is gone in 1.0 s at 0:00, **0.46 s at dawn**, 0.23 s at 15:00. Difficulty reads as binary —
  nothing touches you, or you are deleted.
- **One-hit kills exist.** Big discrete hits scale ×1.05/wave: a volatile elite blast one-shots a 100 HP
  player from wave 19, the Tanker's rupture at the wave-20 boss (~101), exploders and boss slams from
  wave 23 — and spec 1 made boss fights 40–70 s long.
- **The new-player wall.** Brutes (1:30), exploders + the first boss (2:00), elites (2:30) and hives
  (3:00) all arrive inside ninety seconds; threat grows ×4–5 across waves 3→7. v0.1.74 lifted a fresh
  save from ~0.3× to ~0.6–1.0× of the incoming threat, but the first boss is now a ~68 s fight for a
  starter gun, in the middle of it.
- **The speed cliff.** Enemy speed grows ×1.02/wave to wave 10 then ×1.15/wave: shamblers go 96 px/s at
  5:00 → 222 at 8:00 (player: 220). "Late enemies catch you" is deliberate (`ENEMY_SPEED_CAP` comment);
  the *shape* — a cliff between 5:00 and 8:00 — is the problem.

## 2. Larry's decisions (locked)

| # | decision |
|---|---|
| S1 | **Short i-frames after any hit.** Not on dash — dash stays as it is. |
| S2 | **Probation period for new hires**: only a save's first shifts get the gentler opening; afterwards the game runs exactly as today. Length: **10 shifts** (Larry asked for longer than the proposed 5). |
| S3 | Speed ramp: **same destination, smoother climb.** Mid-shift being somewhat faster than today is accepted. |
| S4 | **No one-shots from healthy** — a single hit never exceeds ~70% of max HP — **in every mode, HARDCORE included.** |
| — | Standing: bite-and-bounce, "late enemies catch you", talent level-gating and steep rarity all stay. |

## 3. Design

### 3.1 Two kinds of player damage
Every caller of `Player.take_damage` is one of two kinds, and the rules below treat them differently:

- **Discrete hits** — one number per event: enemy bites (`Enemy.gd:558`), `BossProjectile`, boss patterns
  `AimedBand` / `ChargeDash` / `ExpandingRing`, `ExploderEnemy` blast, `EliteVolatileBlast`.
- **Tick damage** — `dps × delta` applied every frame: `HazardZone` pools, `patterns/ZoneFill`,
  `DrivebyLane`, and a boss's body contact (`BossBase.gd:193`, `touch_damage * delta`).

`take_damage` gains a 4th parameter `is_tick: bool = false`; the four tick callers pass `true`. Nothing
else about those callers changes.

### 3.2 Hit i-frames
- After a **discrete** hit deals damage, the player ignores further **discrete** hits for
  `PLAYER_HIT_IFRAMES := 0.35` s. The timer ticks in `_process` like `_revive_invuln_time`.
- **Tick damage neither triggers nor respects i-frames** — otherwise standing in a weak fire pool would
  grant bite immunity, and a pool would be nullified by its own first tick.
- Order inside `take_damage`: revive-invuln return → **hit-i-frame return (discrete only)** → Thorns →
  dodge → armor → cap (§3.3) → apply → start i-frames (discrete only, and only if `amount > 0` after
  armor). Consequences, all intended: a **blocked** bite triggers nothing — no Spike Armor reflect, no
  Dead Man's Switch nova, no `adrenal_valve` refund, no hurt flash/shake; a **dodged** hit does not start
  i-frames.
- **Tell:** the player sprite blinks (alpha flicker at `PLAYER_IFRAME_BLINK_HZ := 12`) for the window.
  No new colors (strict palette); the existing hurt flash + `player_hurt` SFX still fire on the landed hit.
- The enemy side is unchanged: a biter still bounces off and goes on its own 0.6 s cooldown whether or
  not its bite was blocked.

Surrounded, 100 HP, no defenses (analytic; the probe prints the live table):

| time | bite | today | with i-frames |
|---|---|---|---|
| 0:00 | 10 | 1.0 s | 3.2 s |
| 5:00 | 16 | 0.6 s | 2.1 s |
| 8:00 (dawn) | 22 | 0.46 s | 1.4 s |
| 15:00 | 43 | 0.23 s | 0.7 s |
| 20:00 | 70 | 0.14 s | 0.35 s |

Bite damage and its growth are **unchanged**. Max incoming bite DPS becomes `bite / 0.35` (62 HP/s at
dawn vs ~218 today), which is what makes Tough Hide / Iron Skin / Regeneration / Quick Step rolls and
lifesteal worth taking.

### 3.3 No one-shots from healthy
- A single **discrete** hit is clamped to `PLAYER_MAX_HIT_FRAC := 0.70 × max_hp()`, applied **after**
  armor and before the health change. Tick damage is never clamped.
- Applies in every mode including HARDCORE (S4). It is a cap on one hit, not a death-save: the next hit
  0.35 s later can still kill, and a player below 70% HP can still die to one hit.

### 3.4 Probation period
- `on_probation := RunConfig.mode == "endless" and not RunConfig.daily and not RunConfig.overtime and not RunConfig.hardcore and SaveManager.games_played() < GameConfig.PROBATION_SHIFTS` with
  `PROBATION_SHIFTS := 10`. Computed **once at run start** (Main/Spawner), stored on `RunConfig`
  (`RunConfig.probation`, reset with the other run flags) so nothing re-reads the save mid-run.
  Daily Shift is excluded so its scores stay comparable; the rank-gated modes cannot be reached by a save
  that new anyway (the explicit exclusions are belt-and-braces).
- `games_played` already only counts deaths, wins, and abandons after 120 s **played** (v0.1.73), so
  probation cannot be skipped or farmed by instant quits. Nothing new is saved; existing saves with ≥ 10
  shifts never see probation.
- Effects while `RunConfig.probation`:

| arrival | normal | probation |
|---|---|---|
| runner | wave 2 (0:30) | wave 2 |
| brute | wave 4 (1:30) | **wave 5 (2:00)** |
| exploder | wave 5 (2:00) | **wave 7 (3:00)** |
| elites (`ELITE_MIN_WAVE`) | wave 6 (2:30) | **wave 8 (3:30)** |
| hive | wave 7 (3:00) | **wave 9 (4:00)** |
| spitter / mutant | wave 10 / 12 | unchanged |
| first boss (wave 5) HP | ×1.0 | **×`PROBATION_FIRST_BOSS_HP_MULT` = 0.6** |

  From 4:30 on a probation shift is identical to a normal one (wave-10 boss included).
- Implementation shape: `GameConfig.PROBATION_MIN_WAVE := {"brute": 5, "exploder": 7, "hive": 9}` and
  `PROBATION_ELITE_MIN_WAVE := 8`; pure statics `Enemies.min_wave_for(row, probation)` (used by the
  weighted pick) and `DifficultyCurve.elite_chance(wave, probation := false)`; the Spawner multiplies
  the wave-5 boss's `max_health` by the mult before `configure`. Pure functions take the flag as a
  parameter — they do not read `RunConfig` themselves (keeps them probe-able).
- **Presentation:** at run start one callout in the existing `CombatText.callout` style —
  `PROBATIONARY PERIOD — SHIFT n OF 10` (n = games_played + 1), ~3 s, house deadpan. The shift that
  completes probation (games_played 9 → 10) adds one line to the SHIFT'S OVER pay-stub:
  `PROBATION COMPLETE. HR HAS STOPPED WATCHING.` No other HUD.

### 3.5 Speed ramp
- `DifficultyCurve.enemy_stats` speed term: ×`ENEMY_SPEED_GROWTH` (1.02) per wave through
  `ENEMY_SPEED_RAMP_WAVE := 7`, then ×`ENEMY_RAMP_SPEED_GROWTH := 1.107` per wave, capped at
  `ENEMY_SPEED_CAP` (240) — reached at wave 18, same as today. Speed gets its **own** knee; HP keeps
  `ENEMY_LATE_WAVE` (10) untouched. `ENEMY_LATE_SPEED_GROWTH` is deleted.

| time | 1:00 | 3:00 | 5:00 | 6:30 | 8:00 | 8:30+ |
|---|---|---|---|---|---|---|
| today | 73 | 79 | 96 | 146 | 222 | 240 |
| new | 73 | 79 | 118 | 160 | 217 | 240 |

- Accepted cost (S3): 5:00–6:30 is faster than today (+22 / +14 px/s) and runners (×1.7) pass the
  player's 220 at ~5:30 instead of ~6:30. Hit i-frames land in the same release.
- Runner cap (360), per-type `spd_mult`, elite speed mods and boss speeds are untouched. Probation
  saves get the same ramp.

## 4. Targets (verified by probe)

| target | value |
|---|---|
| Surrounded TTD, 100 HP, no defenses, at 0:00 / 5:00 / 8:00 / 15:00 | within ±15% of 3.2 / 2.1 / 1.4 / 0.7 s |
| Max discrete hits that can land in any 1.0 s window | ≤ 3 |
| Largest single discrete hit at any wave, any source | ≤ 0.70 × max HP (HARDCORE too) |
| Tick damage during an i-frame window | 100% applied; never starts a window |
| Shambler speed at waves 1, 7, 18+ | 70, 78.8 (±0.5), 240 |
| Shambler speed at wave 11 / 14 | 118 / 160 (±3) |
| Probation schedule | exactly the §3.4 table; normal schedule byte-identical to v0.1.74 when not on probation |
| FRESH power ÷ threat on probation, 1:30–4:00 (power-curve sim, report) | ≥ the non-probation FRESH row at every sampled minute |
| v0.1.74 §4 targets | all still pass (the threat model does not use enemy speed) |

## 5. Out of scope
Coins, HARDCORE payout, ranks, crates, coworkers, benefits (spec 3) · dash i-frames (S1: no) · bite
damage growth, boss pattern damage values, lifesteal/regen numbers (re-measured after this ships; only
revisited if broken) · enemy HP, spawn rates, weapon stats, card values (spec 1, shipped) · Boss Rush's
own pass.

## 6. Save / compatibility
No save-format change. Probation derives from the existing `games_played`. `take_damage`'s new parameter
is defaulted, so every untouched caller keeps compiling and keeps discrete-hit semantics.

## 7. Testing
1. **Survivability probe** (`.superpowers/probe_survivability`, boot-scene pattern, real `Player`):
   i-frame window blocks a second discrete hit and expires on time; tick damage passes through and never
   starts a window; blocked bite fires no Thorns / hurt-nova / relic hook (recorders); dodged hit starts
   no window; 70% clamp with and without armor, in HARDCORE; the §4 TTD table computed by driving real
   `take_damage` calls on a simulated 6-biter cadence.
2. **Probation probe:** `min_wave_for` / `elite_chance` tables for both flags; `on_probation` truth table
   across mode / daily / overtime / hardcore / games_played 0, 9, 10; first-boss mult applied only on
   the wave-5 boss and only on probation; callout text.
3. **Speed probe:** the §4 speed rows; `ENEMY_LATE_SPEED_GROWTH` gone; HP curve byte-identical to v0.1.74.
4. **Re-run** `probe_power_curve` (+ a FRESH-on-probation report row) and every existing probe; dual gate
   at parity (19 editor Busy / 0 boot script errors).
5. **Larry F5:** dash out of a surround at dawn; is the blink readable; does 5:00–6:30 feel like a slope;
   a brand-new save's first two shifts (callout, delayed arrivals, 41 s first boss); HARDCORE with the
   70% cap.

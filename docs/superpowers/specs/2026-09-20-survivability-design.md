# Survivability + new-player wall — balance pass v2, spec 2 of 3 (design)

**Date:** 2026-09-20 · **Target release:** v0.1.75 · **Status:** **implemented in v0.1.75.** §4 measured
by probe at commit `b264b97` on 2026-09-20 — full output in
`docs/superpowers/analysis/2026-09-20/survivability-probe-v0.1.75.txt`. Every target met except the
FRESH-on-probation *report* row, whose measured result is recorded in §4 and deliberately **not**
retuned in this release. Text marked *(amended during implementation)* differs from the approved
design; the reason is given inline each time.

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
  The blink writes **`_sprite.self_modulate` only** — `modulate` belongs to the hurt flash and the two
  must not fight — and the sprite is **forced back to opaque when the player dies**, so a player killed
  mid-blink is not left as a half-transparent corpse (*added during implementation*; the window can
  outlive its owner, and the death path is the only place that can end it early).
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
- **Presentation** *(amended during implementation — the approved text said `CombatText.callout`, and
  those pooled callouts live **0.6 s**, far too short to read a two-line announcement. Shipped on the
  HUD banner instead, the same mechanism NightEvents and Extraction already use):*
  - At run start the probation announcement is one **`Hud.show_banner`** banner, **two lines, no dash**:
    `PROBATIONARY PERIOD\nSHIFT n OF 10` (`GameConfig.PROBATION_CALLOUT_FMT`, n = `games_played + 1`,
    10 = `PROBATION_SHIFTS`). House deadpan, unchanged.
  - It is **sequenced, never stacked** (banners are independent full-screen overlays that do not
    queue — two at once means a double scrim and overlapping text). When `_apply_location` actually
    showed the `TONIGHT'S SHIFT` banner (non-forecourt *and* the `hud` group resolved) probation
    waits `PROBATION_BANNER_DELAY_AFTER_LOCATION := 3.2` s — that banner holds 2.6 s + fades 0.4 s —
    otherwise `PROBATION_BANNER_DELAY := 1.5` s. The wait is a pause-safe `SceneTreeTimer`
    (`process_always = false`), so a pause or a level-up card holds the countdown instead of
    burning it down behind the overlay.
  - **Accepted overlap:** on a brand-new save's very first shift the first-run onboarding hint strip
    (`FirstRunHints`, "DRAG ANYWHERE TO MOVE") is already on screen when `Main._ready` runs, and
    probation is guaranteed true on exactly that run. The two can coexist on screen; accepted rather
    than delaying the probation banner past the point where it still reads as a run-start line.
  - The shift that **completes** probation adds one line to the SHIFT'S OVER pay-stub:
    `PROBATION COMPLETE. HR HAS STOPPED WATCHING.` (`GameConfig.PROBATION_COMPLETE_LINE`). It keys
    **purely on the `games_played` 9 → 10 crossing**, not on the run's mode — two consequences,
    both intended: it also appears when that 10th shift is a **Daily** run (a Daily is excluded from
    *getting* probation, but it still counts as a completed shift, so it can be the one that ends it),
    and an **abandon** that crosses 10 shows no line at all (that path has no pay-stub).
  - No other HUD.

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

Measured 2026-09-20 at commit `b264b97`; full probe output in
`docs/superpowers/analysis/2026-09-20/survivability-probe-v0.1.75.txt`.

| target | value | measured |
|---|---|---|
| Surrounded TTD, 100 HP, no defenses, at 0:00 / 5:00 / 8:00 / 15:00 | within ±15% of 3.2 / 2.1 / 1.4 / 0.7 s | **MET** — 3.600 / 2.400 / 1.600 / 0.800 s at waves 1 / 11 / 17 / 31 (+12.5% / +14.3% / +14.3% / +14.3%). The quantisation is structural, not slack: six biters attempt on a 0.1 s grid against a 0.35 s window, so a hit lands every 0.4 s and every TTD is a multiple of it. |
| Max discrete hits that can land in any 1.0 s window | ≤ 3 | **MET** — exactly 3 at every sampled wave (1 / 11 / 17 / 31) |
| Largest single discrete hit at any wave, any source | ≤ 0.70 × max HP (HARDCORE too) | **MET** — 500 damage on a fresh 100 HP player leaves 30 HP; same with armor 0.5 applied first (500 → 250 → capped to 70); same under HARDCORE |
| Tick damage during an i-frame window | 100% applied; never starts a window | **MET** — a tick inside a live window lands in full and does not clear the window; a tick on a fresh player opens none; an uncapped 500 tick kills |
| Shambler speed at waves 1, 7, 18+ | 70, 78.8 (±0.5), 240 | **MET** — 70 / 78.831 / 240 (still 240 at waves 25 and 40); speed is non-decreasing across waves 1–40 and no per-wave step exceeds `ENEMY_RAMP_SPEED_GROWTH` |
| Shambler speed at wave 11 / 14 | 118 / 160 (±3) | **MET** — 118.383 / 160.595 (wave 17: 217.859) |
| Probation schedule | exactly the §3.4 table; normal schedule byte-identical to v0.1.74 when not on probation | **MET** — 103/103 checks, including full seeded `Enemies.pick` id sequences diffed against the pre-flag path, not just pool membership |
| FRESH power ÷ threat on probation, 1:30–4:00 (power-curve sim, report) | ≥ the non-probation FRESH row at every sampled minute | **NOT MET at 2 of 6 minutes** — probation vs normal: 1:30 1.56/1.14 ✓ · **2:00 0.93/1.22 ✗** · 2:30 0.96/0.84 ✓ · 3:00 1.31/0.93 ✓ · 3:30 1.12/0.95 ✓ · **4:00 0.75/0.96 ✗**. Two independent causes, neither retuned in v0.1.75 — see the note below |
| v0.1.74 §4 targets | all still pass (the threat model does not use enemy speed) | **MET** — all 44 checks pass and are byte-identical to the v0.1.74 record. Neither the speed ramp nor probation moved one |

**On the FRESH-on-probation miss.** The threat model was upgraded for this measurement: the probe's
type-mix factor was a hardcoded wave-bracket table (`MIX_FACTOR`, copied from map_difficulty.md
§1.2) that cannot see the probation schedule, so it now derives the mix **live** — the weight-weighted
mean `hp_mult` over exactly the rows `Enemies.pick()` would consider, using
`Enemies.min_wave_for(row, probation)` and the same integer weights — and applies it to both columns.
The live-derived *normal* mix matches the old bracket table to within **0.043%**, so the table was a
rounded snapshot of exactly this computation and nothing else in the probe moved. The two misses are:

1. **2:00 (wave 5) — a limit of the threat proxy, not of the shipped schedule.** Threat is "HP to
   clear per second", so each row contributes its `hp_mult`. The exploder is `hp_mult` 0.80 — one of
   only two sub-1.0 rows — so it *dilutes* the mean. Delaying it to wave 7 while the brute
   (`hp_mult` 4.0) still arrives at wave 5 leaves probation's wave-5 pool with a **higher** mean HP
   than normal's (1.1355 vs 1.0971, +3.5%). The proxy scores an exploder as *less* threat; in the
   hand it is a discrete blast (§3.1) this model does not price at all. Wave 5 is also the first boss
   wave, and that boss — the wave's dominant threat — is softened ×0.60 and is not in the trash
   threat number at all.
2. **4:00 (wave 9) — a real cost of the shipped schedule.** By 4:00 the schedules have converged
   (probation threat ÷ normal threat = 1.000, identical pools) yet the probation column is level 13
   against 14: a lighter early game pays less XP (mean gem value per spawn 1.00 vs 1.48 at 1:30,
   2.29 vs 3.56 at 3:00). Probation buys safety at about one level by 4:00, and a FRESH level is
   ~×1.28 DPS there, so one level is the whole gap.

The same lag shows in the first boss: roster-mean TTK at FRESH ×1.3 reference gear is **67.8 s**
normal and **51.8 s** on probation. ×0.60 alone would give 40.7 s — the probation player's own
one-level-lower DPS hands 11.1 s of the softening back. §7's "41 s first boss" is therefore the
*equal-DPS* figure; what a fresh hire actually gets is closer to 52 s.

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
   `take_damage` calls on a simulated 6-biter cadence. **The TTD simulation itself runs with
   `RunConfig.hardcore = true`** (*decided during implementation*) so no revive path — Second Wind,
   Second Shift, an `ability_controller` revive — can quietly extend a time-to-die; the 70% cap
   applies in HARDCORE by design (S4), so the measurement is otherwise identical in either mode. The
   flag is restored afterwards.
2. **Probation probe:** `min_wave_for` / `elite_chance` tables for both flags; `on_probation` truth table
   across mode / daily / overtime / hardcore / games_played 0, 9, 10; first-boss mult applied only on
   the wave-5 boss and only on probation; banner text, its sequencing delays, and the pay-stub line's
   9 → 10 crossing.
3. **Speed probe:** the §4 speed rows; `ENEMY_LATE_SPEED_GROWTH` gone; HP curve byte-identical to v0.1.74.
4. **Re-run** `probe_power_curve` (+ a FRESH-on-probation report row) and every existing probe; dual gate
   at parity (19 editor Busy / 0 boot script errors). **Done 2026-09-20:** every probe `fails=0` except
   `probe_power_curve`, which is `fails=1` on the new §4 report row alone (all 44 v0.1.74 checks pass);
   gate measured at exactly 19 editor Busy lines, 0 boot script errors on `Main.tscn` and `MainMenu.tscn`.
5. **Larry F5:** dash out of a surround at dawn; is the blink readable; does 5:00–6:30 feel like a slope;
   a brand-new save's first two shifts — the probation **banner** (does it read, does it collide with
   the first-run hint strip), the delayed arrivals, and the first boss (~52 s measured for a fresh
   hire, not the 41 s the ×0.6 implies — see §4); HARDCORE with the 70% cap. Also worth a look, from
   the §4 miss: does the probation opening *feel* slower to level, and does wave 5 (brutes arriving
   the same minute the softened boss does) land harder than waves 4 and 6 around it.

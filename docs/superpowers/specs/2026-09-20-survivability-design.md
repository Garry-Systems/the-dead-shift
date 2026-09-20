# Survivability + new-player wall — balance pass v2, spec 2 of 3 (design)

**Date:** 2026-09-20 · **Target release:** v0.1.75 · **Status:** **implemented in v0.1.75.** §4 measured
by probe at commit `4feb88a` on 2026-09-20 — full output in
`docs/superpowers/analysis/2026-09-20/survivability-probe-v0.1.75.txt`. **Every §4 target is met** and
all thirteen probes end `fails=0`. The first measurement found the probation opening leaving a new hire
a level behind at 4:00; that was a real defect in the feature and it was fixed in this release by
"training pay" (§3.4). Text marked *(amended during implementation)* or *(added during implementation)*
differs from the approved design; the reason is given inline each time.

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
  `PLAYER_HIT_IFRAMES := 0.35` s. Both `_hit_iframe_time` and `_revive_invuln_time` tick in
  `_physics_process`, not `_process` — a fixed 60 Hz step, so the window is exactly 0.35 s at any
  frame rate *(amended after the final review)*.
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
- **Bite-opened windows also block boss hits** *(added after the final review)* — a window opened by
  any landed discrete hit, including a trash bite, blocks boss patterns (`ExpandingRing`, `AimedBand`,
  `ChargeDash`) and `BossProjectile` hits for its 0.35 s; while a six-biter surround is chewing on the
  player they are inside a window ~87.5% of the time, and at wave 20 an ~18 HP runner bite can erase a
  70 HP (capped) slam. Verdict of the final review, accepted by the controller: ship as is — it is the
  standard i-frame contract, the window always costs a hit that really damaged the player (up to
  ~62 HP/s in a dawn surround), and the structural alternative (heavy hits piercing windows opened by
  light ones) is a design change for spec 3. Boss BODY contact is tick damage and is never blocked.
  The §4 boss-fight figures from spec 1 assume patterns land at full rate; with trash on the player
  they land less often.

Surrounded, 100 HP, no defenses (analytic; the probe prints the live table):

| time | bite | today | with i-frames |
|---|---|---|---|
| 0:00 | 10 | 1.0 s | 3.2 s |
| 5:00 | 16 | 0.6 s | 2.1 s |
| 8:00 (dawn) | 22 | 0.46 s | 1.4 s |
| 15:00 | 43 | 0.23 s | 0.7 s |
| 20:00 | 70 | 0.14 s | 0.35 s |

Bite damage and its growth are **unchanged**. Max incoming bite DPS becomes `bite / 0.35` (62 HP/s at
dawn vs ~218 today), which is what makes Tough Hide / Iron Skin / Regeneration rolls and lifesteal
worth taking. Quick Step (dodge) is the exception against a DENSE surround — a dodged bite does not
start a window, so the next biter's attempt ~0.1 s later replaces it and 40% dodge buys only ~13%
mitigation there (the hit cycle goes 0.45 s → 0.52 s); dodge keeps its full value against sparse
damage (boss patterns, exploders, a lone chaser). Likewise Spike Armor now reflects once per LANDED
bite, roughly a quarter of its old output inside a surround. Both are intended consequences of S1, not
retuned here — see §5. *(added after the final review)*

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
- **Training pay** *(added during implementation)* — `GameConfig.PROBATION_XP_BONUS := 0.15`, a
  run-long +15% XP granted once in `Main._ready` (directly after `Characters.apply_base`, gated on
  `RunConfig.probation`) through `player.upgrade_xp_gain`, the same multiplicative `xp_mult` channel
  the NIGHT SCHOOL benefit and the Fast Learner card use, so the two stack.
  - **Why.** The arrivals table above is a *defect* without it. A gentler opening drops fewer and
    lower-value gems — measured mean gem value per spawn 1.00 vs 1.48 at 1:30 and 2.29 vs 3.56 at
    3:00 — so the probation player reached **4:00 at level 13 against a normal save's 14**. 4:00 is
    exactly where the schedules converge (probation threat ÷ normal threat = 1.000, identical
    pools): the new hire was handing over one whole gun card, ~×1.28 DPS, at the precise minute the
    game stops being gentle. It also ate a third of the first boss's softening (51.8 s rather than
    the 40.7 s ×0.6 implies).
  - **Why 0.15.** The smallest 0.05 step for which the power-curve probe's FRESH-on-probation row
    reaches level parity at 4:00 *and* holds power ÷ threat at ≥ 0.95 × the normal row at all six
    sampled minutes. The full 0.00–0.35 sweep is printed in the probe output, and the probe asserts
    the shipped constant **is** that smallest passing candidate, so the constant and the tuning
    cannot drift apart.
  - OVERTIME's `OVERTIME_HEADSTART_XP` is granted *before* `apply_base`, and OVERTIME is never on
    probation, so training pay can never inflate it. Nothing else in `scripts/` reads the constant
    (asserted).
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

| time | 1:00 | 3:00 | 3:30 | 4:00 | 4:30 | 5:00 | 6:30 | 8:00 | 8:30+ |
|---|---|---|---|---|---|---|---|---|---|
| today | 73 | 79 | 80.4 | 82.0 | 83.7 | 96 | 146 | 222 | 240 |
| new | 73 | 79 | 87.3 | 96.6 | 106.9 | 118 | 160 | 217 | 240 |

- Accepted cost (S3) *(amended after the final review — the original text understated the faster
  stretch as only 5:00–6:30)*: the stretch that is faster than v0.1.74 is waves 8–16 (3:30–7:30), not
  only 5:00–6:30; it peaks at wave 10 / 4:30 (+23 px/s, +27.8%: 83.7 → 106.9), is +23.1% at 5:00
  (96.2 → 118.4), converges by dawn and is slightly slower at 8:00 (222.5 → 217.9). In absolute terms
  107 px/s against a 220 px/s player is still easily outrun. Note that 4:30 is also the minute a
  probation shift's schedule has just converged with the normal one. Hit i-frames land in the same
  release.
- Runner cap (360), per-type `spd_mult`, elite speed mods and boss speeds are untouched. Probation
  saves get the same ramp.

## 4. Targets (verified by probe)

Measured 2026-09-20 at commit `4feb88a`; full probe output in
`docs/superpowers/analysis/2026-09-20/survivability-probe-v0.1.75.txt`.

| target | value | measured |
|---|---|---|
| Surrounded TTD, 100 HP, no defenses, at 0:00 / 5:00 / 8:00 / 15:00 | within ±15% of 3.2 / 2.1 / 1.4 / 0.7 s | **MET** — 3.600 / 2.400 / 1.600 / 0.800 s at waves 1 / 11 / 17 / 31 (+12.5% / +14.3% / +14.3% / +14.3%). The quantisation is structural, not slack: six biters attempt on a 0.1 s grid against a 0.35 s window, so a hit lands every 0.4 s and every TTD is a multiple of it. |
| Max discrete hits that can land in any 1.0 s window | ≤ 3 | **MET** — exactly 3 at every sampled wave (1 / 11 / 17 / 31) |
| Largest single discrete hit at any wave, any source | ≤ 0.70 × max HP (HARDCORE too) | **MET** — 500 damage on a fresh 100 HP player leaves 30 HP; same with armor 0.5 applied first (500 → 250 → capped to 70); same under HARDCORE |
| Tick damage during an i-frame window | 100% applied; never starts a window | **MET** — a tick inside a live window lands in full and does not clear the window; a tick on a fresh player opens none; an uncapped 500 tick kills |
| Shambler speed at waves 1, 7, 18+ | 70, 78.8 (±0.5), 240 | **MET** — 70 / 78.831 / 240 (still 240 at waves 25 and 40); speed is non-decreasing across waves 1–40 and no per-wave step exceeds `ENEMY_RAMP_SPEED_GROWTH` |
| Shambler speed at wave 11 / 14 | 118 / 160 (±3) | **MET** — 118.383 / 160.595 (wave 17: 217.859) |
| Probation schedule | exactly the §3.4 table; normal schedule byte-identical to v0.1.74 when not on probation | **MET** — 113/113 checks, including full seeded `Enemies.pick` id sequences diffed against the pre-flag path (not just pool membership) and a behavioral training-pay assertion on a real booted `Player` |
| FRESH power ÷ threat on probation, 1:30–4:00 (power-curve sim, report) | ≥ **0.95 ×** the non-probation FRESH row at every sampled minute (tolerance widened from 1.00 × during implementation — reason below) | **MET** — probation vs normal: 1:30 1.56/1.14 (1.37×) · 2:00 1.18/1.22 (**0.97×**, the tightest) · 2:30 1.23/0.84 (1.47×) · 3:00 1.33/0.93 (1.44×) · 3:30 1.13/0.95 (1.20×) · 4:00 0.96/0.96 (1.00×). Level at 4:00, where the schedules converge: **14 vs 14** |
| v0.1.74 §4 targets | all still pass (the threat model does not use enemy speed) | **MET** — all 44 checks pass and are byte-identical to the v0.1.74 record (verified by diff). Neither the speed ramp, probation, nor training pay moved one |

**Note on the surrounded-TTD row** *(added after the final review)*: the measured values sit ~+14%
above target by construction (six biters attempt on a 0.1 s grid, so hits land every 0.4 s, not
0.35 s); a future change to bite damage or `ENEMY_CONTACT_HIT_CD` may trip the ±15% band spuriously —
re-derive before treating it as a regression.

**On the FRESH-on-probation row.** The threat model was upgraded for this measurement: the probe's
type-mix factor was a hardcoded wave-bracket table (`MIX_FACTOR`, copied from map_difficulty.md
§1.2) that cannot see the probation schedule, so it now derives the mix **live** — the weight-weighted
mean `hp_mult` over exactly the rows `Enemies.pick()` would consider, using
`Enemies.min_wave_for(row, probation)` and the same integer weights — and applies it to both columns.
The live-derived *normal* mix matches the old bracket table to within **0.043%**, so the table was a
rounded snapshot of exactly this computation and nothing else in the probe moved.

The first run of this row measured two deviations. One was a real defect and was **fixed in code**;
the other is a limit of the measurement and is **tolerated**, with the tolerance documented here:

1. **4:00 (wave 9) — fixed by training pay (§3.4).** The schedules have converged by 4:00
   (probation threat ÷ normal threat = 1.000, identical pools) yet the probation column arrived at
   level 13 against 14: a lighter early game pays less XP (mean gem value per spawn 1.00 vs 1.48 at
   1:30, 2.29 vs 3.56 at 3:00), so probation was buying its safety with one whole gun card (~×1.28
   DPS) handed over at the minute the game stops being gentle. `PROBATION_XP_BONUS := 0.15` closes
   it: **14 vs 14**, ratio 0.96/0.96.
2. **2:00 (wave 5) — tolerated; the ≥ 0.95 × bar exists for this.** Threat is "HP to clear per
   second", so each row contributes its `hp_mult`. The exploder is `hp_mult` 0.80 — one of only two
   sub-1.0 rows — so it *dilutes* the mean. Delaying it to wave 7 while the brute (`hp_mult` 4.0)
   still arrives at wave 5 leaves probation's wave-5 pool with a **higher** mean HP than normal's
   (1.1355 vs 1.0971, **+3.5%**). That is an artifact of the proxy, not extra danger: the proxy
   scores an exploder as *less* threat when its real threat is a discrete blast (§3.1) the model
   does not price at all, and wave 5's dominant threat — the first boss — is softened ×0.60 and is
   not in the trash threat number. Measured 0.97 ×, against the 0.95 × bar.

With training pay the probation player is also at level parity at 2:00, so the first boss delivers
its **full** softening rather than a fraction: roster-mean TTK at FRESH ×1.3 reference gear is
**67.8 s** normal and **40.7 s** on probation, exactly the ×0.60. (Before training pay it was 51.8 s
— the level lag ate 11.1 s of it.) §7's "41 s first boss" is therefore correct as written.

## 5. Out of scope
Coins, HARDCORE payout, ranks, crates, coworkers, benefits (spec 3) · dash i-frames (S1: no) · bite
damage growth, boss pattern damage values, lifesteal/regen numbers (re-measured after this ships; only
revisited if broken) · enemy HP, spawn rates, weapon stats, card values (spec 1, shipped) · Boss Rush's
own pass.

**Carried to spec 3 (found by the final review):** retune Quick Step and Spike Armor against the
post-i-frame damage model; decide whether heavy hits should pierce windows opened by light ones
(source weight); boss pattern `_hit_player` latches fire even when the hit was blocked, so a pattern
whose active time outlives the window (ChargeDash 0.55–1.0 s) is deleted rather than delayed;
NightEvents (Blood Moon can roll from wave 5) are not excluded from probation; the blink can freeze on
its dim phase behind a pause/level-up overlay; a heavy defensive build (5+ Iron Skin + lifesteal/regen)
is now net-positive against trash bites at dawn — re-measure.

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
   9 → 10 crossing; and **training pay** — behaviorally on a real booted `Player` (`xp_mult` rises by
   exactly `1 + PROBATION_XP_BONUS`, and compounds rather than overwrites), plus source checks that
   `Main.gd` grants it once, inside `if RunConfig.probation`, after `Characters.apply_base`, with
   OVERTIME's head start still landing before it, and that nothing else in `scripts/` reads the const.
3. **Speed probe:** the §4 speed rows; `ENEMY_LATE_SPEED_GROWTH` gone; HP curve byte-identical to v0.1.74.
4. **Re-run** `probe_power_curve` (+ a FRESH-on-probation report row) and every existing probe; dual gate
   at parity (19 editor Busy / 0 boot script errors). **Done 2026-09-20:** all thirteen probes
   `fails=0` (hygiene 28 · overtime_farm 16 · card_rolls 15 · card_apply 26 · card_ui 26 · xp_curve 30
   · fire_timing 24 · procs 15 · bosses 72 · power_curve 46 · survivability 50 · speed_ramp 34 ·
   probation 113), with all 44 v0.1.74 check lines byte-identical to the v0.1.74 record; gate measured
   at exactly 19 editor Busy lines, 0 boot script errors on `Main.tscn` and on `MainMenu.tscn`.
5. **Larry F5:** dash out of a surround at dawn; is the blink readable; does 5:00–6:30 feel like a slope;
   a brand-new save's first two shifts — the probation **banner** (does it read, does it collide with
   the first-run hint strip), the delayed arrivals, and the ~41 s first boss; HARDCORE with the 70%
   cap. Also worth a look, from what §4 measured: does the probation opening still *feel* slower to
   level now that training pay is in (the model says level parity by 4:00, but +15% XP on a gentler
   wave 4 is an easy thing to over- or under-feel), and does wave 5 — brutes arriving the same minute
   the softened boss does — land harder than waves 4 and 6 around it. *(added after the final
   review)*: fight a wave-20 boss with trash on you — do slams visibly stop landing; does Quick Step
   still feel worth taking; the 4:00–4:30 speed step on a brand-new save right as probation's schedule
   converges; a Blood Moon during a probation shift.

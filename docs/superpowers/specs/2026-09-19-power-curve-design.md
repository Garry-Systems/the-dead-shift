# Power Curve — balance pass v2, spec 1 of 3 (design)

**Date:** 2026-09-19 · **Target release:** v0.1.74 · **Status:** implemented in v0.1.74 (tasks 1-8). Starter
constants below carry a `tuned:` line where the Task 8 power-curve probe retuned them; probe output is
`docs/superpowers/analysis/2026-09-19/power-curve-probe-v0.1.74.txt`.

**Source:** `docs/superpowers/analysis/2026-09-19/ECONOMY-DIFFICULTY-MAP.md` (+ the four analyst reports beside it).
Balance pass v2 is split in three specs: **1 Power Curve (this)** · 2 Survivability + new-player wall
(i-frames, w11–18 speed ramp, 1:30–3:00 spike, boss attack damage) · 3 Economy/meta (HARDCORE, sinks,
ranks, basement ladder, STAFF FILE). Anything in 2 or 3 is out of scope here.

## 1. Problem

XP per kill is enemy HP/50 (grows ~12%/wave) while level cost is linear (`5 + 3L`). Result: ~level 57
at extraction, a card pick every ~6 s by dawn, every card multiplicative and uncapped → every build
out-scales the game after ~minute 8. Boss HP compounding twice past wave 10 is the only thing keeping
pace, and still gives boss fights of <5 s (mid gear) / <1 s (late gear). Per-hit talents have degenerate
cases on the flamethrower and Shatter. "+X% fire rate" is secretly ×1/(1−X).

## 2. Larry's decisions (locked)

| # | decision |
|---|---|
| D1 | ~**30 level-ups** per full shift to extraction (9:35). Today ~57. |
| D2 | Cards give an **RNG roll** on how much they benefit. **No stack caps.** |
| D3 | Rolls are **rarity-tiered**, rolled per offered card, value shown before picking. Odds Common 60 / Rare 27 / Epic 10 / Legendary 3. |
| D4 | Talent procs stay **chance per bullet**. Only constant-stream guns (flamethrower) roll **per second**. |
| D5 | On-curve boss fight = **45–60 s**. *(Unreachable as a hard target with one boss-HP base + one growth rate — §4's boss row was amended to roster mean 40–70 s / every boss 30–80 s; see the note under the §4 table.)* |
| D6 | "+X% fire rate" becomes honest (+X% shots/sec) for **cards + talents only**. Weapon **affixes keep today's math** (steep top-end rarity preserved). |
| — | Standing: talent level-gating and steep rarity stay. |

## 3. Method — target-driven tuning with a sim probe

Constants in this spec are **starters**. A headless sim probe (`.superpowers/probe_power_curve`,
boot-scene pattern so autoloads exist) reads the live constants/defs and reports, for three reference
builds, (a) level by time, (b) power ÷ threat ratio by time, (c) boss TTK per boss wave. Constants are
tuned until the probe hits the targets in §4, then Larry does a phone-feel micro-pass.

Reference builds (gear only; cards = expected value of the roll tables): **FRESH** Rusted pistol, no
meta · **MID** Lethal AK-47, 1 talent live, r3 drone ·
**LATE** Merciless AK-47, 3 talents, max benefits, good relics. Kill/pickup assumptions as in
`map_power.md` (80% / 80%), stated in the probe output.

The card **pick policy is derived, not written**: the probe replays `LevelUpUI._pick_three` (shuffle
the live pool for the level's parity, offer 3, each rolling its own tier through `CardRolls.roll`)
over a fixed-seed Monte Carlo, applies a stated priority — damage > fire rate > reload > anything
else, with the bigger headline gain taken when both DPS cards are offered — and reports the expected
per-gun-level multipliers. It asserts that every id the model can pick is in
`Weapons.upgrades_for(<build weapon>)`, so a policy that picks a card the gun does not offer (the
first pass did: it applied Extra Barrel, which is in neither reference weapon's pool) cannot recur.

A level-up reroll (`LevelUpUI._refresh_cards`) re-rolls TIERS as well as which cards are offered —
not just a reshuffle of the same rolled numbers — so SECOND OPINION and the truck's `TRUCK_REROLL_COST`
reroll charge are a stronger lever than the model assumes; the sim replays a single no-reroll offer
per level, so its expected multipliers are a **floor** on player power, not a centre.

## 4. Targets

| target | value | tolerance |
|---|---|---|
| Level at 1:00 / 3:00 / 5:00 / 8:00 / 9:35 (MID) | 5 / 12 / 18 / 25 / 29 | ±2 (9:35: 27–32) |
| Level at 15:00 / 20:00 (MID) | ~42 / ~54 | report only — **measured 38 / 42** |
| Power ÷ threat, MID, 3:00–9:35 | 1.5–3.0 | must hold at every sampled minute |
| Power ÷ threat, FRESH, 3:00–9:35 | ≥ 0.5 (today 0.27–0.42) | report; spec 2 owns the rest of the new-player wall |
| Boss TTK at reference gear — w5 FRESH-tier, w10 Lethal, w15 Savage, w20 Carnage | roster mean 40–70 s | every boss in roster within 30–80 s |

**Boss row amended by controller ruling (2026-09-20).** It was written as 45–60 s / 35–75 s. The
power-curve probe showed that is unreachable with one `BOSS_BASE_HP` + one `BOSS_HP_GROWTH`, because
the reference player's DPS does not grow geometrically — ×1.454/wave from w5→w10 (that step is a
*build* change, FRESH → MID), then ×1.262 and ×1.243 — while a single constant can only bend the
curve one way. The tuned pair (4150 / 1.31), with the Manager multiplier trimmed to 1.24 (see §5.5),
measures roster means **67.8 / 40.2 / 48.5 / 63.1 s** at w5 / w10 / w15 / w20 — all four inside the
amended 40–70 s band — and **every one of the 44 per-boss cells inside 30–80 s** (range 30.5 s, the
wave-10 Night Stocker, to 79.1 s, the wave-5 Manager). The probe is green on the amended row; the
original 45–60 / 35–75 remains out of reach without a third boss lever. The fit is *tight*, not
comfortable: the four rows span ×1.68 and the bands allow ×1.71.

Accepted consequence of steep rarity, both measured by the probe at the final constants: the LATE
build (Merciless AK, three talents, relics — the top of the gear ladder) kills a w10 boss in a
**2.7 s roster mean** and a w20 boss in 9.4 s, while the wave-5 reference (FRESH-tier ×1.3) takes a
**67.8 s roster mean**, up to 79.1 s against the Manager.

## 5. Design

### 5.1 XP curve
- `XpCurve.xp_for_level(level) = round(XP_BASE × XP_GROWTH^level)`; starters `XP_BASE = 8`,
  `XP_GROWTH = 1.17`. `XP_PER_LEVEL` is deleted. XP **income** (gem value = HP/50, cap 15, elite ×3)
  is unchanged.
  - **tuned: `XP_BASE = 11`, `XP_GROWTH = 1.16`** (probe levels 3 / 11 / 17 / 27 / 30 at 1:00 / 3:00 /
    5:00 / 8:00 / 9:35; 38 at 15:00 and 42 at 20:00). `OVERTIME_HEADSTART_XP` re-derived 124 → **160**
    to still buy exactly 8 levels. Unchanged by every retune since: the card and boss levers move
    power, not income.
  - **As implemented:** trash gems use `XpCurve.gem_value_for_hp(max_health)`; boss gems use
    `XpCurve.boss_gem_value(wave)`, which is built on top of it (see the next bullet).
- **Boss XP scales with wave**: boss gem drop is worth what ~50 s of wave-current trash would pay
  (starter: `BOSS_XP_REWARD` gems each worth the wave-current shambler gem value, under the same
  `XP_GEM_VALUE_MAX` cap, instead of 30 flat value-1 gems).
  Exact constant tuned in the probe so a boss fight is XP-neutral vs. skipping it.
  - **tuned: `BOSS_XP_REWARD = 35` (gem COUNT only) + new `XpCurve.boss_gem_value(wave)` scaled by
    new `BOSS_GEM_VALUE_MULT = 0.8`.** A flat count of *trash-valued* gems could never be neutral:
    trash income grows with the enemy's HP **and** with the spawn rate, so one gem valued off HP
    alone fell to ~0.2× of a fight's worth of income by w20. `boss_gem_value` therefore multiplies
    the wave-current trash gem value by the wave's spawn rate relative to wave 1, and is deliberately
    **not** clamped by `XP_GEM_VALUE_MAX` (that cap exists to stop elite/late *trash* gems running
    away, not boss payouts). The count stays low on purpose — more gems is screen clutter and entity
    cost, not reward.
  - **"Neutral" is 0.5-1.0, not 1.0.** A boss fight does not stop trash income, it **halves** it
    (`BOSS_SPAWN_RATE_MULT`), so one boss should pay about half of what 50 s of *normal* income would
    have paid. Probe: **w5 0.78 · w10 0.61 · w15 0.55 · w20 0.64** — all four inside 0.5-1.0.
  - **ENDLESS ONLY — Boss Rush has its own gem value.** `boss_gem_value`'s spawn-rate factor is
    calibrated for *one* boss roughly every 50 s. Boss Rush spawns 3 concurrent bosses at second zero
    and kills them continuously, while its `wave` still advances off run time — so it was inheriting
    the endless scaling on *every* kill (×2.0 per gem from ~4:45, ×3.84 from ~9:45). New
    `XpCurve.boss_rush_gem_value(wave)` = the plain wave-current **trash** gem value
    (`gem_value_for_hp`, capped by `XP_GEM_VALUE_MAX` as usual, no spawn-rate factor, no
    `BOSS_GEM_VALUE_MULT`); `BossBase._reward` picks it when `RunConfig.mode == "boss_rush"`. Values:
    w5 2 · w10 3 · w15 5 · w20 9, against endless's 2 / 5 / 13 / 29.
- **Boss spawn-suppression limit**: the ×0.5 trash spawn rate while a revealed boss lives
  (`Spawner.gd:41-42`, `BOSS_SPAWN_RATE_MULT`) applies for at most `BOSS_SUPPRESS_MAX_SECONDS = 75` per
  boss, then trash returns to the normal interval. The boss still blocks the next boss spawn (unchanged).
  Closes the "keep the boss as a pet" loop. Timer counts only revealed time (a concealed Mystery
  Shopper already doesn't suppress — v0.1.69).
  - **As implemented:** the 75 s budget is **per boss** — it pauses (does not reset) while a boss is
    alive but concealed, and resets only when no boss is alive at all, so re-cloaking never buys a
    fresh 75 s.

### 5.2 Card rolls
- Every offered card (`LevelUpUI` builds 3 from `Upgrades.cards_for_level`) independently rolls a
  **tier** then a **value** uniformly inside that tier's band. The rolled card dict carries
  `{id, title, desc, tier, value}`; `UpgradeApply.apply(player, card)` applies `value` (signature changes
  from id-only to the rolled card). No luck stat, no pity, no weighting between the three.
- Tiers + odds: Common 60 · Rare 27 · Epic 10 · Legendary 3. Colors reuse loot rarity colors:
  Common `d6d6d6` (Salvaged) · Rare `2f7bff` (Lethal) · Epic `a64bff` (Savage) · Legendary `ff7a18`
  (Merciless). Rarity colors are already exempt from the 4-color palette.
- **Anchor: Rare = today's value.** Band multipliers on the card's current value `v`:
  Common 0.5–0.8 · Rare 0.8–1.2 · Epic 1.3–1.8 · Legendary 2.2–3.0 (mean ≈ 0.9 v).
  Applies to every percent/flat-number card: Hollow Points, Hair Trigger, Overpressure, Long Barrel,
  Tighter Choke, Fast Hands, Extended Mag, Swift Feet, Tough Hide, Regeneration, Magnet, Iron Skin,
  Quick Step, Quick Reset, Fast Learner, Silver Tongue, Spike Armor (reflect mult), Incendiary (burn dps).
  - **The bands themselves are UNCHANGED** — the anchor holds for every card **except Hollow Points
    and Hair Trigger**, whose *base* values were retuned (next bullet); the bands they roll on are the
    same. Task 8's first pass
    tried a uniform ×1.82 on the bands and it was reverted: reduction-type cards apply `*= (1 - p)`,
    so `UPGRADE_RELOAD_PCT` 0.20 × a 5.5 Legendary = 1.10 would drive `reload_mult` **negative**, and
    `UPGRADE_CHOKE_PCT` 0.30 × 2.4-5.5 would drive `spread` negative. It also silently buffed every
    defensive/economy card, which belongs to specs 2 and 3. The power-curve probe now carries a
    guard: for every reduction card (armor, dash cooldown, choke, reload)
    `base × CARD_TIER_BANDS[3][1] < 1.0` must hold.
  - **tuned instead: the two PURE-DPS card bases tripled — `UPGRADE_DAMAGE_PCT` 0.20 → `0.60`,
    `UPGRADE_FIRE_RATE_PCT` 0.15 → `0.45`** (ratio held at 4:3). They pay for two things at once.
    First, ~30 level-ups now have to do the work ~57 used to do. Second — found in the review's fix
    round 1 — **a gun level is not a guaranteed damage pick**: `LevelUpUI._pick_three` offers 3 of
    the equipped weapon's 8-card pool, so Hollow Points is even *offered* only 37.5 % of the time.
    With the pick model derived from the real offer mechanics (the probe replays the shuffle and the
    rolls), a gun level takes Hollow Points ~35 % of the time, Hair Trigger ~30 %, Fast Hands ~18 %,
    and ~18 % of gun levels offer none of the three; the expected gun level is worth ×1.276 sustained
    DPS at these bases and was ×1.189 at 0.40/0.30, where the §4 MID power/threat band failed at 6 of
    the 8 sampled minutes (down to 0.62 by 9:00 — overrun). 0.60 is the ceiling the controller set
    for this lever, and the band holds with a 0.08 margin at its tightest sample. Nothing else about
    any card moved.
- **No caps** on any card. The only ceiling that remains is the existing `DODGE_CAP` 40% total dodge.
- **Integer cards** (Armor Piercing, Ricochet): Common/Rare +1 · Epic +1 and +10% damage · Legendary +2.
- **Extra Barrel**: tiers as integer cards for the count (+1/+1/+1/+2), and each barrel *added by the
  card* fires at a rolled damage share: Common 40–55% · Rare 55–70% · Epic 70–90% · Legendary 100%.
  Gun tracks bonus barrels with their share; base projectiles unaffected.
- **Kill Shot**: rolls crit **chance only** — Common +3–4 · Rare +4–6 · Epic +7–9 · Legendary +11–15
  points. `UPGRADE_CRIT_MULT_BONUS` is deleted (no +1.0 multiplier per pick); crit stays ×2 + talents.
  - **As implemented:** the FIRST Kill Shot pick of a run also grants the ×2 crit multiplier once
    (`CARD_CRIT_MULT_BONUS_ONCE`). The code's base crit multiplier is 1.0, so on a gun with no crit
    talent a chance-only card would have done literally nothing; later picks add chance only.
- **Second Wind**: no roll (one-time flag); always presented as Epic. Existing exclusions unchanged.
- **Silver Tongue / Fast Learner**: roll like any percent card, uncapped (halved pick count + geometric
  XP already tame them).
- **Presentation** (`LevelUpUI`): tier-colored border + tier label, rolled number large, band small
  (`+7% damage` / `band 5–10%`). Legendary offer plays a flash + sting. Must stay legible at phone
  width; follow existing PixelTheme.
- **Config**: all card base values, tier odds and band multipliers live in `GameConfig` (today several
  are hardcoded in `UpgradeApply.gd:9-15`). Roll logic is a pure static (`logic/CardRolls.gd`,
  autoload-free like `Upgrades.gd`) so it is probe-able with a seeded RNG.
- **Bug fixes riding along**: Incendiary card is removed from the pool on guns where it can never apply
  (Tesla); on the Flamethrower it adds to burn from pick 1 (today `maxf(30, …)` eats picks 1–3).

### 5.3 Honest fire rate (cards + talents only)
- `Gun.upgrade_fire_rate(p)`: `fire_interval /= (1 + p)` (was `*= (1 − p)`).
- Talent fire-rate effects (Rampage, Frenzy `_frenzy_mult`, Graveyard Shift, any other talent-sourced
  rate bonus) use the same `/ (1 + p)` form so the text is true.
- **Weapon affix** fire-rate math is untouched.
- **Frame-rate independence**: the fire timer carries its remainder (`_cooldown += interval`, bounded
  multi-shot per frame) instead of resetting to `fire_interval` — LMG/Nailgun stop losing ~16% at
  60 fps and 120 Hz phones stop out-DPSing 60 Hz ones.

### 5.4 Procs
- Per-bullet chance stays the rule (D4).
- **As implemented:** every **kill-gated** proc (explode / ammo / bolt / pool / spread / mine) rolls
  **unscaled** on cone guns — only per-hit procs take the `chance × tick_interval` per-second scaling.
- **Constant-stream guns** (`fire_mode == "cone"`, i.e. Flamethrower): a proc's listed chance is per
  second per target — per-tick chance = `chance × tick_interval`. On-kill procs are unaffected.
- **Shatter**: a shatter **consumes the freeze** (target thaws); re-freezing needs a fresh chance roll.
- **Execute** talents: bosses are immune (no instant kill, no callout). Trash and elites unchanged.
- **Poison**: uncapped stacking stays. The probe reports poison DPS vs. bosses; revisit only if it
  breaks the §4 boss TTK band.

### 5.5 Bosses
- `DifficultyCurve.boss_stats`: single compounding — `BOSS_BASE_HP × ENEMY_HP_GROWTH^(w−1)`; the
  `BOSS_LATE_HP_GROWTH` branch and constant are deleted.
- `BOSS_BASE_HP` is re-set by the probe to hit §4 boss TTK.
  - **Amended by controller ruling (fix round 1): bosses get their own growth constant.** Larry's
    D5 ("on-curve boss fight = 45-60 s") outranks the single-compounding *mechanism*, which the probe
    proved insufficient — at ×1.12/wave, anchoring the wave-5 fight at ~52 s leaves the w10 / w15 /
    w20 fights at ~14 / ~8 / ~5 s, and no `BOSS_BASE_HP` fixes that because the reference player's
    DPS grows ~×1.32/wave off **two** compounding
    sources (in-run cards *and* the between-run gear ladder) while trash HP only has to answer the
    first. New `BOSS_HP_GROWTH` is used by `DifficultyCurve.boss_stats` for HP only; touch damage and
    `special_mult` still ride `ENEMY_DMG_GROWTH`. It is still ONE rate at every wave — the
    `BOSS_LATE_HP_GROWTH` double-compounding branch stays deleted.
  - **tuned: `BOSS_HP_GROWTH = 1.31`, `BOSS_BASE_HP = 4150`** (×2.77 from the pre-v0.1.74 1500; the
    ten roster consts scaled by the same factor and rounded to 50 — every per-boss mult within 0.006
    of its old value, order and the 0.8-1.3 band intact), plus the Manager trim below. Probe roster
    means **w5 67.8 s · w10 40.2 s · w15 48.5 s · w20 63.1 s**, every boss 30.5-79.1 s. One geometric
    rate cannot track the reference DPS, which grows ×1.454/wave from w5→w10 (that step is a *build*
    change, FRESH → MID), ×1.262 w10→w15 and ×1.243 w15→w20. **§4's boss row was amended** (see the
    note under the §4 table) to roster mean 40–70 s / every boss 30–80 s, and the tuned pair is the
    scan optimum against those bands — the only zero-violation point on a grid of every 2-decimal
    growth rate × every base multiple of 50.
  - **`BOSS_HP_GROWTH` stops at the last scheduled boss.** New `BOSS_HP_GROWTH_LAST_WAVE = 20` (the
    wave the chopper lands on). `boss_stats(wave)` applies `BOSS_HP_GROWTH` for at most that many
    waves and `ENEMY_HP_GROWTH` for the remainder, so waves ≤ 20 are unchanged and late endless goes
    back to growing like trash. Reason: 1.31/wave is justified only while the **gear ladder** is
    still climbing; past extraction the player is off the designed run and grows from cards alone
    (~1.10/wave), so an uncapped 1.31 compounds a wave-30 boss to ~10 M HP — a wall, not a fight.
    With the cap it is 2.18 M, and the probe's report-only rows put the w25 / w30 fights at
    73 s / 85 s of MID ×2.2 gear.
  - **Boss Rush keeps its own curve.** Boss Rush is outside this spec, spawns 3 concurrent bosses at
    second zero and indexes the curve by bosses *killed* rather than by wave, and was tuned around
    the pre-v0.1.74 numbers. New `BOSS_RUSH_BASE_HP = 1500` (the historical value) and
    `DifficultyCurve.boss_rush_stats(n)` = `BOSS_RUSH_BASE_HP × ENEMY_HP_GROWTH^(n−1)` with the same
    damage/speed/special_mult shape as `boss_stats` (shared helper, not duplicated); `Spawner`'s
    boss-rush call site uses it. Each boss's `_hp_mult()` is a pure ratio
    (`<BOSS>_HP / BOSS_BASE_HP`), so the roster works unchanged on top of the Boss Rush base.
    Retuning endless can no longer silently retune Boss Rush.
- Per-boss HP multipliers narrowed from 0.73–2.0 to **0.8–1.3**, order preserved (Manager tankiest …
  Night Stocker squishiest).
  - **tuned:** nine of the ten roster consts are a flat ×2.77 rescale with `BOSS_BASE_HP`, so their
    multipliers are unchanged (max drift 0.0054, from rounding to 50). `MANAGER_HP` is the one
    deliberate exception: **trimmed 1.30 → 1.24**, still the roster max (just above Mascot's 1.229)
    and still inside the 0.8–1.3 band. At 1.30 the wave-5 Manager was the single cell of the 44
    outside the fight-length band; at 1.24 he is 79.1 s and the whole grid fits.
  - Final roster: Manager 5150 · Mascot 5100 · Tanker 4950 · Brood Mother 4700 · Fryer 4550 ·
    Heat Tyrant 4400 · Mystery Shopper 4300 · Karen 4150 · Brute 4150 (= base) · Courier 3750 ·
    Night Stocker 3350.
- Boss attack damage, speed, patterns: unchanged (spec 2).

## 6. Out of scope
I-frames, enemy speed ramp, enemy unlock timing, boss damage, lifesteal/regen values (spec 2) ·
coins, HARDCORE, ranks, crates, coworkers, benefits (spec 3) · weapon base stats, affix values, talent
level gating, rarity odds · making placed things (turret, mines, drones) scale with wave.

## 7. Save / compatibility
No save-format change: cards are per-run state; affixes untouched; talents keep their rolled numbers
(only how fire-rate numbers are *applied* changes). No commendation, challenge, or save field keys on
player level or card-pick counts (grepped 2026-09-19), so nothing persistent depends on the old pacing.

Quantified, for saved weapons that already rolled a fire-rate talent: Rampage's listed "+70%" was
`x3.33` shots/sec under the old `*= (1 − p)` math and is honestly `x1.70` under §5.3's `/ (1 + p)` —
Adrenaline ≈ −25%, Graveyard Shift ≈ −15%, Bloodrush ≈ −9% shots/sec at their rolled values. This is a
deliberate consequence of decision D6 (honest fire-rate text), not a balance regression to chase.

## 8. Testing
1. **Roll probe** (seeded): tier frequencies within ±2 pts of 60/27/10/3 over 10k rolls; every value
   inside its band; integer/Extra Barrel/Kill Shot/Second Wind special cases; apply() uses the rolled
   value.
2. **Power-curve probe**: §4 targets, all three builds, printed table; FAIL outside tolerance. Its
   pick model is derived from the real offer pools and asserts membership in the equipped weapon's
   `upgrades` list; offer rates are checked against the exact hypergeometric.
3. **Mechanics probes**: fire-rate formula (card +20% ⇒ shots/sec ×1.20; affix math byte-identical),
   timer remainder (shots in 10 s at 60 vs 120 fps within 1%), flamethrower per-second proc rate,
   Shatter thaw, boss execute immunity, 75 s suppression limit, boss HP single compounding + roster band.
4. **Gates**: editor parse gate at parity (19 known XpGem "Busy"), boot gates Main + MainMenu = 0 script
   errors, existing probes (hygiene 28/28, overtime farm 16/16) stay green.
5. **Larry F5 on phone**: card pacing feel, Legendary moment, boss length at w5/w10, flamethrower +
   minigun proc builds. Expect a micro-pass.

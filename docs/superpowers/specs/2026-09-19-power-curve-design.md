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
| D5 | On-curve boss fight = **45–60 s**. |
| D6 | "+X% fire rate" becomes honest (+X% shots/sec) for **cards + talents only**. Weapon **affixes keep today's math** (steep top-end rarity preserved). |
| — | Standing: talent level-gating and steep rarity stay. |

## 3. Method — target-driven tuning with a sim probe

Constants in this spec are **starters**. A headless sim probe (`.superpowers/probe_power_curve`,
boot-scene pattern so autoloads exist) reads the live constants/defs and reports, for three reference
builds, (a) level by time, (b) power ÷ threat ratio by time, (c) boss TTK per boss wave. Constants are
tuned until the probe hits the targets in §4, then Larry does a phone-feel micro-pass.

Reference builds (gear only; cards = expected value of the roll tables, greedy-ish pick policy stated in
the probe): **FRESH** Rusted pistol, no meta · **MID** Lethal AK-47, 1 talent live, r3 drone ·
**LATE** Merciless AK-47, 3 talents, max benefits, good relics. Kill/pickup assumptions as in
`map_power.md` (80% / 80%), stated in the probe output.

## 4. Targets

| target | value | tolerance |
|---|---|---|
| Level at 1:00 / 3:00 / 5:00 / 8:00 / 9:35 (MID) | 5 / 12 / 18 / 25 / 29 | ±2 (9:35: 27–32) |
| Level at 15:00 / 20:00 (MID) | ~42 / ~54 | report only |
| Power ÷ threat, MID, 3:00–9:35 | 1.5–3.0 | must hold at every sampled minute |
| Power ÷ threat, FRESH, 3:00–9:35 | ≥ 0.5 (today 0.27–0.42) | report; spec 2 owns the rest of the new-player wall |
| Boss TTK at reference gear — w5 FRESH-tier, w10 Lethal, w15 Savage, w20 Carnage | 45–60 s | every boss in roster within 35–75 s |

Accepted consequence of steep rarity: a Merciless gun still kills a w10 boss in ~10 s; a fresh save
takes >60 s at w5.

## 5. Design

### 5.1 XP curve
- `XpCurve.xp_for_level(level) = round(XP_BASE × XP_GROWTH^level)`; starters `XP_BASE = 8`,
  `XP_GROWTH = 1.17`. `XP_PER_LEVEL` is deleted. XP **income** (gem value = HP/50, cap 15, elite ×3)
  is unchanged.
  - **tuned: `XP_BASE = 11`, `XP_GROWTH = 1.16`** (probe levels 3 / 11 / 17 / 26 / 30 at 1:00 / 3:00 /
    5:00 / 8:00 / 9:35). `OVERTIME_HEADSTART_XP` re-derived 124 → **160** to still buy exactly 8 levels.
  - **As implemented:** boss and trash gem values share one helper, `XpCurve.gem_value_for_hp(max_health)`
    — a boss gem IS worth what a wave-current trash kill's gem is worth, under the same `XP_GEM_VALUE_MAX`
    clamp.
- **Boss XP scales with wave**: boss gem drop is worth what ~50 s of wave-current trash would pay
  (starter: `BOSS_XP_REWARD` gems each worth the wave-current shambler gem value, under the same
  `XP_GEM_VALUE_MAX` cap, instead of 30 flat value-1 gems).
  Exact constant tuned in the probe so a boss fight is XP-neutral vs. skipping it.
  - **tuned: `BOSS_XP_REWARD = 35`** — XP-neutral at the wave-5 boss (0.78× of 50 s of income) only.
    w10/w15/w20 land at 0.37 / 0.21 / 0.20 and cannot be lifted: each gem is valued off the plain
    shambler while income is the type-mix + elite-weighted mean (1.7-2.8× higher), and the 3-4× gem
    count that would close the gap adds ~12 levels by 9:35, breaking the §4 level targets.
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
  - **tuned: a uniform ×1.82 on every band — Common 0.9–1.45 · Rare 1.45–2.2 · Epic 2.4–3.3 ·
    Legendary 4.05–5.5 (mean ≈ 1.63 v).** This BREAKS the "Rare = today's value" anchor above and is
    the one place Task 8 overrode a design line: at the starter bands the §4 MID power/threat band
    (1.5–3.0, 3:00–9:35) failed at 5 of 8 sampled minutes (down to 0.56 at 9:35 — overrun), and a
    uniform band scale is the only in-scope lever that reaches it. Side effect: EVERY percent/flat
    card — Swift Feet, Tough Hide, Iron Skin, Regeneration, Fast Learner, Silver Tongue included —
    is now ~1.8× its old value. Needs Larry's phone pass; the cleaner alternative is to raise the
    DPS cards' base values (`UPGRADE_DAMAGE_PCT` etc.) instead and restore this anchor.
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
  - **tuned: `BOSS_BASE_HP = 7500` (×5; all ten roster consts scaled by the same 5, every per-boss
    mult byte-identical).** This hits 45-60 s for the **wave-5** row only (roster mean 54 s, 41-66 s).
    §4's "every boss in roster within 35-75 s" CANNOT be met at more than one boss wave with a single
    constant: over w5→w20 the reference player's DPS grows ×1.287/wave (gear ladder × compounding
    cards) while boss HP grows ×1.12/wave, so the four rows want BOSS_BASE_HP = 7.2k / 25k / 44k /
    57k. Flat TTK needs a boss-only HP growth of ≈1.29/wave — which is what the deleted double
    compounding (1.12² = 1.2544) was accidentally providing. Out of scope here; reopen §5.5 if Larry
    wants late bosses to stay 45-60 s.
- Per-boss HP multipliers narrowed from 0.73–2.0 to **0.8–1.3**, order preserved (Manager tankiest …
  Night Stocker squishiest).
- Boss attack damage, speed, patterns: unchanged (spec 2).

## 6. Out of scope
I-frames, enemy speed ramp, enemy unlock timing, boss damage, lifesteal/regen values (spec 2) ·
coins, HARDCORE, ranks, crates, coworkers, benefits (spec 3) · weapon base stats, affix values, talent
level gating, rarity odds · making placed things (turret, mines, drones) scale with wave.

## 7. Save / compatibility
No save-format change: cards are per-run state; affixes untouched; talents keep their rolled numbers
(only how fire-rate numbers are *applied* changes). No commendation, challenge, or save field keys on
player level or card-pick counts (grepped 2026-09-19), so nothing persistent depends on the old pacing.

## 8. Testing
1. **Roll probe** (seeded): tier frequencies within ±2 pts of 60/27/10/3 over 10k rolls; every value
   inside its band; integer/Extra Barrel/Kill Shot/Second Wind special cases; apply() uses the rolled
   value.
2. **Power-curve probe**: §4 targets, all three builds, printed table; FAIL outside tolerance.
3. **Mechanics probes**: fire-rate formula (card +20% ⇒ shots/sec ×1.20; affix math byte-identical),
   timer remainder (shots in 10 s at 60 vs 120 fps within 1%), flamethrower per-second proc rate,
   Shatter thaw, boss execute immunity, 75 s suppression limit, boss HP single compounding + roster band.
4. **Gates**: editor parse gate at parity (19 known XpGem "Busy"), boot gates Main + MainMenu = 0 script
   errors, existing probes (hygiene 28/28, overtime farm 16/16) stay green.
5. **Larry F5 on phone**: card pacing feel, Legendary moment, boss length at w5/w10, flamethrower +
   minigun proc builds. Expect a micro-pass.

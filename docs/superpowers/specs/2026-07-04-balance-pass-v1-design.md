# Balance Pass v1 — The Dead Shift

**Date:** 2026-07-04
**Status:** Approved design, pending implementation
**Repo:** `C:\Users\thela\Documents\mobile-game` (Godot 4.6 / GDScript)
**Scope:** Guns-vs-guns, difficulty curve, and economy — the three areas Larry flagged. Driven by a 5-agent analytical balance map (weapon DPS, enemy TTK, economy EV, rarity power ladder) cross-checked against code. Every change below was individually approved by Larry via option questions.

**Explicitly OUT of scope / intentional (do NOT change):** steep rarity drop odds (RNG is king), talent level-gating to Lv28, fixed talent counts per rarity (0/0/1/1/2/3/3/4), the 3 dev grants (separate launch-prep task), Nail Gun pin values.

---

## 1. Difficulty curve — soften the late cliff

Problem: required horde DPS (avg spawn HP × spawn rate) grows 9.4× between min 5 (~460) and min 10 (~4,300) because late HP growth stacks with the spawn-interval floor. A mid-roll T5 gun walls at min 6–8; only T6+ sees min 10, and the wall is a cliff, not a slope.

Intent: loot tier stays the main run-length driver, but a good purple run can touch minute 10.

| Constant (`scripts/logic/GameConfig.gd`) | Before | After |
|---|---|---|
| `ENEMY_LATE_HP_GROWTH` | 1.15 | **1.12** |
| `SPAWN_INTERVAL_FLOOR` | 0.20 | **0.25** |

Effect: wave-21 shambler 645 → ~479 HP; min-10 break-even DPS ~4,300 → ~2,750 (−36%).

## 2. Bosses stay the scary spike late

Problem: `DifficultyCurve.boss_stats` scales raw `1.12^(wave-1)` with no late ramp while trash gets an extra `ENEMY_LATE_HP_GROWTH^(wave-10)`; plus a live boss halves trash spawns (`BOSS_SPAWN_RATE_MULT 0.5`) and a kill grants a FULL heal + relic — late bosses are a relief valve, inverted from intent.

Changes:
- New const `BOSS_LATE_HP_GROWTH := 1.12` (GameConfig), applied in `DifficultyCurve.boss_stats()` for waves past `ENEMY_LATE_WAVE` (10), exactly mirroring the trash late-ramp shape.
- New const `BOSS_KILL_HEAL_FRAC := 0.33` — endless boss-kill heal drops from 100% to 33% of max HP (`BossBase` endless path; boss-rush keeps its existing `BOSS_RUSH_HEAL_FRAC 0.2`).
- `BOSS_SPAWN_RATE_MULT` stays 0.5 (readability during boss fights is worth it).
- Relic + coin rewards unchanged.

## 3. Enemy special damage scales with waves

Problem: spitter projectile (12), boss projectile (12), exploder blast (35), boss slam (35), heat band (30), hazard zones (18 dps) are flat constants forever. Only bites scale (`ENEMY_DMG_GROWTH 1.05^wave`). By min 10 specials are noise and the only death is converging bites.

Rule: **all enemy-dealt special damage is multiplied by the same per-wave damage multiplier already applied to touch damage** (`pow(ENEMY_DMG_GROWTH, wave-1)`), snapshotted at the dealing enemy's spawn wave (boss attacks at the boss's spawn wave; zones/projectiles inherit their creator's multiplier). Wave-1 values are unchanged — early game is untouched.

Sites (plan will pin exact wiring): `RangedEnemy` (spitter shot), `BossProjectile`, `ExploderEnemy` blast, boss slam, Heat band, enemy-created hazard zones. Player-placed hazards (Acid Cannon pools, barrel fires) are NOT affected.

## 4. Gun tuning

All in `scripts/logic/Weapons.gd` defs unless noted. DPS = sustained single-target incl. reload.

| Gun | Change | Before → After (1t / 5t) |
|---|---|---|
| **Grenade Launcher** | The enemy the shell directly contacts takes **impact damage = 50% of `damage`** IN ADDITION to the normal blast (so the contacted enemy takes 25 impact + 50 blast = 75; everyone else in radius takes 50 as today). Wired in `Bullet`'s detonate path; fires once per shell (idempotent with the existing `_detonated` guard) | 42.9 → ~64 1t; 5t 214 → ~236 |
| **Sniper** | `fire_mode: "projectile"` + **`base_pierce: 2`** (same pattern as `slug_gun`) | 5t 89.6 → ~269; 1t unchanged |
| **LMG** | `reload_time` 3.2 → **4.5** | 1t 156.9 → ~139 (still #1 real 1t; belt-dump fantasy intact) |
| **Acid Cannon** | New def key **`pool_dps: 25.0`** — pool damage decoupled from shell `damage` (35, unchanged). Rolled/upgraded damage scales the pool proportionally: effective pool dps = `pool_dps × (current damage / base damage)` | pool 35 → 25 dps; shell hit unchanged |
| **Flamethrower** | `damage` 6.0 → **5.0** per tick; `FLAME_BURN_DPS` 10 → **30**; `FLAME_BURN_TIME` 1.5 → **3.0** (GameConfig) | while-firing total ≈130 unchanged, but burn is now ~30% of output and melts for 3s after the cone sweeps off — burn becomes the identity |
| **Slug Gun** | `damage` 60 → **78** | 1t 54.5 → ~71; keeps pierce-2 identity without the 1t tax |

Category ladders after the pass (1t/5t): Sniper 89.6/269 vs Railgun 69.8/209 vs Anti-Materiel 91.4/274 — three distinct line-piercers; Heavy: GL ~64/236, Minigun 114/114, LMG 139/139.

## 5. Loot feel — signature-stat guarantee

Problem: `LootRoller` draws a random SUBSET of an affix's stats, so within-T5 power spread (2.0×–7.4×) exceeds the tier-to-tier jump — a purple that misses its multishot draw performs like a blue.

Change: every affix in `Affixes.gd` declares a **`signature`** stat key (its headline stat — e.g. multishot for brutal/heavy-family affixes, damage for razor-family). `LootRoller` ALWAYS includes the signature stat in the draw, then fills the remaining slots randomly from the rest as today. Drop odds, stat magnitudes, and slot counts unchanged; god-rolls still exist. Applies to NEW pulls only (existing inventory untouched, same convention as the talent-count change).

## 6. Economy

| Change | Where | Before → After |
|---|---|---|
| 50/50 Crate price | `Crates.gd` | 400 → **700** (parity with Titan per-T5; the gamble stays, the dominance goes) |
| Category crate floors | `Crates.gd` (`precision_pack`, `auto_case`, `standard_arms`) | `rarity_floor` 1 → **2** (a 500c crate never pays a gray) |
| **New "Specials Case" crate** | `Crates.gd` | price **650**, `rarity_floor 2` / `rarity_ceil 8`, `bases: [tesla, flamethrower, acid_cannon]` — completes the category-crate set. New 4-color icon via home-repo `gen_palette_sprites.py crates()` |
| Quit pays out | `PauseMenu.gd` quit AND restart | route through the normal `CoinReward.payout` at **75%** + `SaveManager.add_game_played()` (counts toward the 10-game reward). Death stays optimal at 100% |

## 7. Elite XP scaling

Problem: `XP_GEM_VALUE = 1` for everything from a 20-HP runner to a 2,500-HP late brute — elites are strictly worse XP-per-second than runner farming, and gem income caps at spawn rate exactly when the late game demands more cards.

Change: XP gem **value scales with the enemy's HP multiplier at spawn** — `value = clampi(roundi(hp_mult), 1, XP_GEM_VALUE_MAX)` with new const `XP_GEM_VALUE_MAX := 15` (GameConfig). Bosses keep their existing 30-gem payout. Synergizes with §1: more late cards is part of softening the wall. Implementation probe must sanity-check leveling pace (levels/minute at waves 1/11/21 before vs after) so cards don't fire-hose late.

---

## Verification plan

1. **Parse gate:** headless Godot 4.6.3 via WSL interop (`/tmp/godot46/...console.exe --path "C:\Users\thela\Documents\mobile-game" --headless --editor --quit`), grep `SCRIPT ERROR|PARSE ERROR`.
2. **DPS probe** (headless `--script`): recompute the sustained 1t DPS for all 21 guns from live defs; assert the six changed guns land within ±5% of the targets above and the other 15 are byte-identical to pre-pass values.
3. **Curve probe:** print trash HP / spawn interval / boss HP / break-even DPS at waves 1, 5, 11, 16, 21 before/after constants; assert boss HP at wave 20 > 2× the old value and wave-1 values unchanged.
4. **Loot probe:** roll 500 weapons per rarity tier; assert every rolled affix includes its signature stat; assert tier talent counts still 0/0/1/1/2/3/3/4 (regression).
5. **Economy check:** Specials Case appears in Store with icon; category crates never roll rarity < 2; 50/50 price 700 shown; quitting a run adds coins + increments `games_played` (probe `SaveManager` state).
6. **No save migration needed** anywhere (prices/consts/def keys only; new def keys read via `def.get()` per house pattern).

## Risks / notes

- §3 (special-damage scaling) is the only change touching multiple combat scripts — the plan must enumerate every damage site and keep the multiplier snapshot-at-spawn to avoid mid-life re-scaling.
- §7 could over-accelerate late leveling; `XP_GEM_VALUE_MAX` is the damper — tune on phone.
- Acid pool ratio-scaling (§4) changes `HazardZone` call plumbing; player-placed pools must keep `hurts_player=false` regression-safe.
- New crate icon requires the home-repo sprite generator run + PNG copied into `art/crates/` (same flow as the 06-20 crates).
- All numbers are Larry-approved starters — expect a phone-feel micro-pass after F5.

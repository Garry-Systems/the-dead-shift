# The Dead Shift v0.1.72 — DIFFICULTY / THREAT CURVE MAP

Read-only analysis. Repo: `/mnt/c/Users/thela/Documents/mobile-game/`. All paths below are relative to `scripts/`.
Arithmetic reproduced in python (`scratchpad/curve.py`, `curve2.py`, `curve3.py`, `curve4.py`).
`GC` = `logic/GameConfig.gd`. `w` = wave. `g(w) = 1.05^(w-1)` = the "special_mult" / damage growth factor.

---------------------------------------------------------------------------------------------------

## 0. Run structure / clock

| Thing | Value | Source |
|---|---|---|
| Wave | `wave = floor(run_time / 30) + 1` | DifficultyManager.gd:42, GC:51 |
| run_time pauses | during any tree pause (level-up, relic menu) and during `time_hold` (overtime_clock relic, 10 s per boss kill) | DifficultyManager.gd:37-42 |
| Shift clock | 22:00 -> 06:00, 1 real sec per clock minute => **dawn at t = 480 s (8:00), wave 17** | ShiftClock.gd:13-14,31-33; GC:353-355 |
| Final surge | t = 480..570 s (90 s): spawn interval forced to floor, elite chance x2 | Extraction.gd:49-53; GC:547-548 |
| Chopper | lands t = 570 s (= first frame of **wave 20**), waits 20 s; touch LZ radius 130 at (0,460) = WIN | Extraction.gd:57-77; GC:549-552 |
| After t = 590 s | chopper leaves, endless continues forever (no end condition but death) | Extraction.gd:88-92 |
| Boss cadence | every 5th wave (w5 = 2:00, w10 = 4:30, w15 = 7:00, w20 = 9:30 ...), one boss alive max | Spawner.gd:48-57; GC:67 |

So the "designed" run = 9:30-9:50, seeing bosses at w5, w10, w15; the w20 boss spawns on the exact frame the chopper arrives.

---------------------------------------------------------------------------------------------------

## 1. Exact formulas

### 1.1 Trash base stats — `DifficultyCurve.enemy_stats(wave)` (logic/DifficultyCurve.gd:7-21)

```
n     = max(wave-1, 0);  early = min(n, 9)                       # ENEMY_LATE_WAVE = 10 (GC:62)
hp    = 50  * 1.12^early   * (1.12^(wave-10) if wave>10)          # GC:41,54,63
spd   = min( 70 * 1.02^early * (1.15^(wave-10) if wave>10), 240 ) # GC:40,56,64,57
dmg   = 10  * 1.05^n                                              # GC:42,55   (never frozen, never capped)
special_mult = 1.05^n                                             # scales every flat special (blasts, projectiles, boss patterns)
```

* HP: because `ENEMY_LATE_HP_GROWTH (1.12) == ENEMY_HP_GROWTH (1.12)`, HP collapses to the pure exponential **hp = 50 * 1.12^(wave-1)**. There is NO late-wave HP knee despite the comment at GC:59-61. Uncapped.
* Speed: 70 -> 83.7 at w10 (+2%/wave), then **+15%/wave** -> 96.2, 110.6, 127.2, 146.3, 168.3, 193.5, 222.5 (w17), cap 240 from w18.
* Damage: +5%/wave, uncapped. "Damage" is per BITE, not per second (GC:42-44).

### 1.2 Per-type multipliers — `Enemies.stats_for` (logic/Enemies.gd:17-23, 70-77)

| id | hp x | spd x | dmg x | min_wave (time) | weight | notes |
|---|---|---|---|---|---|---|
| shambler | 1.0 | 1.0 | 1.0 | 1 (0:00) | 100 | |
| runner | 0.4 | 1.7 | 0.7 | 2 (0:30) | 40 | speed clamps at ENEMY_HARD_SPEED_CAP 360 (GC:234) from w17 |
| brute | 4.0 | 0.55 | 2.2 | 4 (1:30) | 15 | |
| exploder | 0.8 | 1.3 | 0 (blast 35*g, r110) | 5 (2:00) | 20 | ExploderEnemy.gd:33-41; blast is NOT is_contact -> ignores Armor |
| hive | 6.0 | 0 | 1.0 | 7 (3:00) | 8 | births 2 shamblers / 4 s, lifetime cap 8 (GC:239-241) at CURRENT-wave stats (HiveEnemy.gd:29-34) |
| spitter | 0.9 | 1.0 | 1.0 (+ projectile 12*g every 1.8 s, 320 px/s, range 700, standoff 450) | 10 (4:30) | 25 | RangedEnemy.gd:34-49; GC:227-231 |
| mutant | 3.0 | 1.2 | 1.8 | 12 (5:30) | 10 | plain Enemy.gd script |

Other unlock gates: elites w6 (2:30, GC:510) · night events first roll at w5 (NightEvents.gd:42 `wave <= 4` returns) · visitors w4 (GC:821) · basement doors w3 (GC:668). **No new trash type after 5:30.**

Spawn-mix probabilities (forecourt): w1 sham 100% · w2-3 sham 71.4 / run 28.6 · w4 64.5/25.8/brute 9.7 · w5-6 57.1/22.9/8.6/expl 11.4 · w7-9 54.6/21.9/8.2/10.9/hive 4.4 · w10-11 48.1/19.2/7.2/9.6/3.8/spit 12.0 · w12+ 45.9/18.3/6.9/9.2/3.7/11.5/mutant 4.6.

Expected HP multiplier per spawn E[hp_mult]: w1 1.000 · w2-3 0.829 · w4 1.135 · w5-6 1.097 · w7-9 1.311 (1.661 counting a full 8-shambler hive brood) · w10-11 1.262 (1.570) · w12+ 1.342 (1.635).

### 1.3 Contact damage mechanics (Enemy.gd:536-556)

* One bite = `touch_damage * (1 + alpha_buff 0.20)`, then the enemy shoves ITSELF away at 700 px/s decaying 900 px/s^2 (GC:44, Enemy.gd:10) and gets a 0.6 s bite cooldown (GC:43).
* Simulated single-enemy bite period vs a stationary player (free bounce): 70 px/s -> 3.98 s · 84 -> 3.32 · 96 -> 2.90 · 146 -> 1.92 · 222 -> 1.27 · 240 -> 1.17 · 360 -> 0.78. **The 0.6 s cooldown never binds for a free-bouncing enemy** — it only binds when the bounce is body-blocked by the crowd behind (enemies collide with each other, default layer/mask 1).
* Geometric surround cap: shambler r20 + player r24 -> 6 shamblers in simultaneous contact (8 runners r14, 4 brutes r36).
* Bosses: continuous `touch_damage * delta` per physics frame, no cooldown (BossBase.gd:193).

### 1.4 Spawn interval / count — `DifficultyCurve.spawn_interval` (logic/DifficultyCurve.gd:24-27) + DifficultyManager.gd:55-58 + Spawner.gd:35-46

```
interval = max(1.0 * 0.92^(wave-1), 0.25)            # GC:47,53,52  -> floor first reached at w18 (0.92^17 = 0.2423)
interval = 0.25                  if final surge       # DifficultyManager.gd:56-57  (REPLACES, also discards Blood Moon mult)
interval *= _spawn_interval_mult otherwise            # Blood Moon 0.5 (GC:533), HORDE 0.5 (GC:623) — applied AFTER the floor => 0.125 s possible
interval /= 0.5                  if a REVEALED boss is alive   # Spawner.gd:41-42, GC:71  (halves trash rate for the boss's whole life)
```
Exactly ONE enemy per tick (Spawner.gd:118-126). Spawn ring 1200 px from player (GC:48).

### 1.5 Max-alive cap — **NONE**
grep for any alive-count check / cull on the "enemies" group: no results. Only caps that exist: hive brood 8/hive, hazard zones 10, tanker pools 14, stocker crates 6, obstacles 24. The only trash removal besides death is Basement ascend's straggler sweep (Basement.gd:309-324).

### 1.6 Elites (logic/DifficultyCurve.gd:33-36; Spawner.gd:135-149; Enemy.gd:110-119)

```
chance(w) = 0 if w<6 else min(0.05 + 0.005*w, 0.15)     # GC:510-513 -> 8.0% at w6 (first realized value; 0.05 "base" is never seen), +0.5%/wave, cap 15% at w20
chance *= surge_mult(2.0 during final surge) * nametag(1.5 w/ cursed_nametag)   # DifficultyManager.gd:73-74 — applied AFTER the cap: 27-29% in surge, 40-43% w/ nametag
kind  = uniform of armored / volatile / splitter / alpha (exploder+volatile -> armored)
```
* All elites: HP x2.5 (GC:514). No damage/speed change on the elite itself.
* armored: -30% damage taken -> EHP x3.571 · volatile: death blast 35*1.2*g = 42*g, radius 132, 0.6 s fuse (Enemy.gd:639-642) · splitter: 2 runners, each HP = 0.5 x the ELITE's max (so 1.25x the base type's HP), total stream EHP x5.0 · alpha: +20% speed and +20% damage to every enemy within 300 px (GC:523-526).
* Mean elite EHP multiplier = (3.571+2.5+5.0+2.5)/4 = **3.39**; stream-HP factor = 1 + 2.393*p.
* Elites roll in endless + horde only; never in boss rush (Spawner.gd:136).

### 1.7 Bosses — `DifficultyCurve.boss_stats` (logic/DifficultyCurve.gd:40-49) + BossBase.configure (BossBase.gd:48-53)

```
hp    = 1500 * 1.12^(wave-1) * (1.12^(wave-10) if wave>10) * per_boss_mult     # NOTE: full exponent is NOT frozen at w10, so past w10 it compounds 1.12 * 1.12 = 1.2544 per wave
touch = 25 * 1.05^(wave-1)  DPS (continuous)
speed = 45 px/s fixed * phase speed_mult   (never scales; GC:70)
special_mult = 1.05^(wave-1) multiplies every pattern's flat damage / zone dps (patterns/AttackPattern.gd:28-31)
```

---------------------------------------------------------------------------------------------------

## 2. Computed curve at the time marks (forecourt, endless, no events, no boss alive)

| t (min) | wave | shambler HP | bite dmg | shambler speed | interval (s) | spawns/s | elite % | raw HP/s (sham HP x rate) | **effective HP/s** (type mix + full hive brood + elite EHP) | elite share of stream HP | x vs t=0 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 1 | 50.0 | 10.00 | 70.0 | 1.000 | 1.00 | 0 | 50 | 50 | 0% | 1.0 |
| 1 | 3 | 62.7 | 11.03 | 72.8 | 0.846 | 1.18 | 0 | 74 | 61 | 0% | 1.2 |
| 3 | 7 | 98.7 | 13.40 | 78.8 | 0.606 | 1.65 | 8.5 | 163 | 325 (257 w/o brood) | 24.0% | 6.5 |
| 5 | 11 | 155.3 | 16.29 | 96.2 | 0.434 | 2.30 | 10.5 | 358 | 702 | 28.5% | 14.0 |
| 8 (dawn) | 17 | 306.5 | 21.83 | 222.5 | 0.263 (surge: 0.250) | 3.80 (4.00) | 13.5 (surge 27.0) | 1164 | 2518 (surge: ~3300) | 34.6% (surge 55.6%) | 50 |
| 9.5 (chopper) | 20 | 430.6 | 25.27 | 240 (cap) | 0.250 (floor) | 4.00 | 15.0 (cap) | 1723 | 3828 | 37.5% | 77 |
| 10 | 21 | 482.3 | 26.53 | 240 | 0.250 | 4.00 | 15.0 | 1929 | 4287 | 37.5% | 86 |
| 12 | 25 | 758.9 | 32.25 | 240 | 0.250 | 4.00 | 15.0 | 3036 | 6746 | 37.5% | 135 |
| 15 | 31 | 1498 | 43.22 | 240 | 0.250 | 4.00 | 15.0 | 5992 | 13316 | 37.5% | 266 |
| 20 | 41 | 4652 | 70.40 | 240 | 0.250 | 4.00 | 15.0 | 18610 | 41357 | 37.5% | 827 |

Yardstick (other domain owns real DPS): the GameConfig base gun is 25 dmg / 0.20 s = **125 DPS at 100% uptime**; the effective stream passes 125 HP/s between w5 (120) and w6 (175).

Wave-over-wave growth of effective HP/s (normal step = 1.12/0.92 = x1.217, x1.229 with elite creep):

| wave | 2 | 3 | **4** | 5 | **6** | **7** | 8 | 9 | 10 | 11 | 12 | 13-17 | 18 | 19-20 | 21+ |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| x prev | 1.009 | 1.217 | **1.668** (brutes) | 1.176 | **1.450** (elites 0->8%) | **1.470-1.862** (hives) | 1.229 | 1.229 | 1.162-1.183 | 1.229 | 1.280-1.307 (mutants) | 1.229 | 1.191 | 1.130 | 1.120 |

Speed / reach (spawn ring 1200 px) and per-enemy contact DPS vs a stationary player:

| wave | 1 | 5 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18+ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| shambler px/s | 70 | 75.8 | 83.7 | 96.2 | 110.6 | 127.2 | 146.3 | 168.3 | 193.5 | 222.5 | 240 |
| seconds to reach player | 17.1 | 15.8 | 14.3 | 12.5 | 10.8 | 9.4 | 8.2 | 7.1 | 6.2 | 5.4 | 5.0 |
| bite period (s) | 3.98 | 3.68 | 3.33 | 2.90 | 2.52 | 2.20 | 1.92 | 1.67 | 1.45 | 1.25 | 1.17 |
| 1-shambler contact DPS | 2.5 | 3.3 | 4.65 | 5.6 | 6.8 | 8.2 | 9.8 | 11.9 | 14.3 | 17.5 | 19.65 |

First wave each type out-runs the 220 px/s player: runner **w14** (248.7), exploder w16 (251.6), mutant w16 (232.2), shambler + spitter **w17** (222.5); brute never (132 max). Runner sits at the 360 hard cap from w17. Alpha aura x1.2 is applied on top of the caps (Enemy.gd:495) -> 288 / 432 px/s.

---------------------------------------------------------------------------------------------------

## 3. Boss table

Selection: uniform random over 11, never the same boss twice in a row (logic/Bosses.gd:27-38). Spawn trigger: first frame of a wave divisible by 5 with no boss alive (Spawner.gd:48-57); if a boss is still alive through the entire 30 s window, that boss wave is skipped. No boss has an enrage or a time limit. Reward: 30 gems, heal 33% max HP, guaranteed relic choice (BossBase.gd:246-278). Pattern damage below is at special_mult = 1; multiply by g: **w5 x1.216 · w10 x1.551 · w15 x1.980 · w20 x2.527 · w25 x3.225 · w30 x4.116**. Boss touch DPS: 30.4 / 38.8 / 49.5 / 63.2 / 80.6 / 102.9. Pattern windups are clamped to 0.5-1.2 s (GC:199-200).

### 3.1 HP by boss and wave (rank by effective HP)

| # EHP | boss | HP base (mult) | w5 | w10 | w15 | w20 | w25 | w30 | chase px/s |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Manager | 3000 (2.000) | 4,721 | 8,319 | 25,838 | 80,250 | 249,244 | 774,113 | 27 |
| 2 | Mascot | 2600 (1.733) | 4,091 | 7,210 | 22,393 | 69,550 | 216,011 | 670,898 | 24.8 / 40.5 / 60.8 |
| 3 | Tanker | 2400 (1.600) | 3,776 | 6,655 | 20,671 | 64,200 | 199,395 | 619,290 | 22.5 |
| 4 | Brood Mother | 2200 (1.467) | 3,462 | 6,101 | 18,948 | 58,850 | 182,779 | 567,683 | 45 |
| 5 | Fryer | 2000 (1.333) | 3,147 | 5,546 | 17,226 | 53,500 | 166,162 | 516,075 | 45 |
| 6 | Heat Tyrant | 1900 (1.267) | 2,990 | 5,269 | 16,364 | 50,825 | 157,854 | 490,272 | 45 |
| 7 | Mystery Shopper | 1800 (1.200) + up to 3 x 45 s concealment | 2,832 | 4,992 | 15,503 | 48,150 | 149,546 | 464,468 | 15.75 concealed / 76.5 revealed |
| 8 | Karen | 1600 (1.067) + P3 "manager" add = 15x shambler HP alpha elite (1,180 / 2,080 / 3,665 / 6,460 = +47% / +47% / +27% / +15% of her own HP) | 2,518 | 4,437 | 13,780 | 42,800 | 132,930 | 412,860 | 38.25 |
| 9 | Brute | 1500 (1.000) | 2,360 | 4,160 | 12,919 | 40,125 | 124,622 | 387,057 | 45 |
| 10 | Courier | 1400 (0.933) | 2,203 | 3,882 | 12,058 | 37,450 | 116,314 | 361,253 | 58.5 |
| 11 | Night Stocker | 1100 (0.733) | 1,731 | 3,050 | 9,474 | 29,425 | 91,389 | 283,841 | 76.5 |

Kill-time yardstick @125 DPS, 100% uptime (Manager / Brute / Stocker): w5 38 / 19 / 14 s · w10 67 / 33 / 24 s · w15 **207 / 103 / 76 s** · w20 642 / 321 / 235 s · w25 1994 / 997 / 731 s.
Boss HP expressed as "seconds of the whole trash stream" (base boss x1.0): w5 19.6 s · w10 7.3 s · w15 7.7 s · w20 10.5 s · w25 18.5 s · w30 32.6 s · w40 101 s. Boss HP / shambler HP: 30 (w1-10) -> 52.9 (w15) -> 93.2 (w20) -> 164 (w25) -> 289 (w30) -> 899 (w40).

### 3.2 Kits and damage numbers (bosses/*.gd, patterns/*.gd)

| boss | phases (cadence s) and patterns | "every cast lands" direct DPS by phase | CC / adds / denial |
|---|---|---|---|
| Brute | 1 phase (4.0): RING 35 dmg r220 | 8.75 | none |
| Brood Mother | P1 (4.0) SUMMON 3, ZONE 18 dps r90 4 s on player · P2 (3.2) SUMMON 3 decoy, ZONE, EMIT ring 8x12 @180 · P3 (2.6) SUMMON 4 decoy, EMIT 10x12 @200, ZONE | 0 / 1.25 / 1.54 (+ zone 72 max per cast) | adds 0.375 -> 0.31 -> 0.51 /s; decoys steal auto-aim |
| Heat Tyrant | P1 (3.5) RING 35 r200, BAND 30 · P2 (3.0) RING, BAND, BAND · P3 (2.6) JAM 2.0 s, RING, BAND | 9.29 / 10.56 / 8.33 | jam 26% uptime in P3 |
| Manager | P1 (4.5) SUMMON 3, RING 35 r220 · P2 (3.8) SUMMON 3, JAM 2.2, RING · P3 (3.2) JAM, SUMMON 4, RING | 3.89 / 3.07 / 3.65 | adds 0.33 / 0.26 / 0.42 per s; jam 19% / 23% uptime |
| Night Stocker | P1 (3.0) CHARGE 30 (520 px/s x 0.55 s = 286 px, hit r56), CRATE · P2 (2.6) C, CRATE, C · P3 (2.2) C, C, CRATE | 5.00 / 7.69 / 9.09 | drops solid crates (max 6) |
| Fryer | P1 (3.6) ZONE 20 dps r100 4 s, BAND 26 · P2 (3.0) ZONE, BAND, BAND · P3 (2.5) ZONE, ZONE, BAND | 3.61 / 5.78 / 3.47 (+ zones 80 max each) | ground denial |
| Courier | P1 (4.0) CHARGE 30 (650 x 0.9 = 585 px), EMIT 10x12 @220 · P2 (3.4) +SLOW -40% 3 s · P3 (2.8) SLOW, CHARGE, EMIT, CHARGE | 5.25 / 4.12 / 6.43 | slow to 132 px/s |
| Karen | P1 (4.2) SCREAM 30 r240 + 600 px/s shove, SLOW -55% 2.5 s · P2 (3.6) SCREAM, 3 decoys, SLOW · P3 (3.2) on-enter 15x-HP alpha elite; SCREAM, JAM 2.2, 3 decoys | 3.57 / 2.78 / 3.12 | slow to 99 px/s, shove, jam 23%, decoys, alpha aura |
| Tanker | P1 (4.6) TRAIL dash 30 (600 x 1.0 = 600 px, ~6 pools 20 dps r70 4 s, 0.9 s ignite) · P2 (4.0) TRAIL, ZONE 20 dps r100 · P3 (3.4) JACKKNIFE 2x30 dashes (pool every 60 px, cap 14), RING **40** r260 | 6.52 / 3.75 / **14.71** | fire corridors; biggest single hit in roster |
| Mystery Shopper | concealed: 15.75 px/s, zero contact damage, no casts; reveals on 60 dmg / 120 px / 45 s timeout; re-cloaks + teleports at 66% and 33% · revealed (2.8): CHARGE 30 (480 x 0.35 = 168 px) | 10.71 (revealed only) | occupies the single boss slot; trash NOT halved while concealed |
| Mascot | L1 (4.4) RING 30 r220, SUMMON 2 · L2 (3.6) shed RING 25 r260; CHARGE 30 (585 px), RING 30 · L3 (2.0) shed RING 25; CHARGE 30 (550 x 0.3 = 165 px) | 3.41 / 8.33 / **15.00** | shrinks/accelerates; phases are equal thirds of HP |

### 3.3 Rankings

* **By effective HP (wall-ness):** Manager > Mascot > Tanker > Karen-with-manager-add (~1.57x at w<=10) > Brood Mother > Fryer > Heat Tyrant > Mystery Shopper (+ stall) > Brute > Courier > Night Stocker. Spread at equal wave = **2.73x**.
* **By lethality (direct DPS x ability to force hits x CC):** Tanker P3 (14.7 + 14 burning pools + the 40-dmg rupture) ~ Mascot L3 (15.0) > Heat Tyrant (8-10.6 + jam) > Mystery Shopper revealed (10.7, 76.5 px/s) > Night Stocker (9.1) > Fryer (zones) > Courier (slow + charges) > Karen (3 dps but slow/shove/jam + alpha 15x add — lethality is via the trash) > Brood (adds/zones) > Manager (3-3.9) > Brute.
* **Likely pushovers:** Brute (one pattern, a 220 px ring centered on a 45 px/s body — never reaches a player shooting from 600 px gun range; no CC, no adds); Night Stocker (0.73x HP, its CRATE cast is a non-attack); Courier (0.93x HP).
* **Likely walls:** Manager (2.0x HP with the LOWEST direct lethality = pure sponge; the halved trash rate during his long life makes it a breather, not a threat); Mascot at w15+ (22k+); Mystery Shopper (up to 135 s of mandatory concealment stall — at 15.75 px/s from a 1200 px spawn she needs 38 s just to enter gun range, so the 45 s timeout is the usual reveal).
* Boss contact is irrelevant to a moving player: every chase speed is 22.5-76.5 px/s vs player 220 and never scales, while trash reaches 240-360.

---------------------------------------------------------------------------------------------------

## 4. Modifiers

### Locations (logic/Locations.gd:43-66) — spawn-weight bias only, no stat multipliers
| | E[hp_mult] vs forecourt (w5 / w7 / w12+) | mix shift at w12+ | gimmick |
|---|---|---|---|
| Big Mart (rank 2) | 0.955 / 0.921 / 0.954 | runner 18.3 -> 21.9%, spitter 11.5 -> 5.1%, brute 6.9 -> 6.3% | freezer patches (50%/wave edge): slow 35% for player AND enemies, r110, 45 s (GC:740-744) |
| Parking Garage (rank 4) | 0.975 / 0.923 / 0.935 | exploder 9.2 -> 11.6%, runner 18.3 -> 15.5%, mutant 4.6 -> 3.9% | pillar lattice; car alarms TAUNT enemies within 500 px for 6 s (helps player) |
Both unlockable stores throw 5-8% LESS HP than the starter map because up-weighting shamblers dilutes brutes/hives/mutants. Daily Shift and Boss Rush force forecourt.

### Modes (RunConfig.gd, Main.gd:24-37)
* **HARDCORE** (rank 7): zero threat-side change. Player side: `heal()` is a no-op (Player.gd:435-437) -> no regen, no boss-kill heal, no lifesteal, no truck heal, no Second Shift / Union Rep (Player.gd:339,348), Second Wind + Regen cards removed from the pool (Upgrades.gd:36-43), max-HP gains don't raise current. Reward x3 coins, x2 weapon XP. Total damage budget for the run = starting HP.
* **OVERTIME** (rank 5): run_time preset to 240 s -> starts at **w9** (HP 123.8, 1.95 spawns/s, 9.5% elites, brutes/exploders/hives live) with 124 XP (~8 levels) and no relics. First boss at **0:30 of play** (w10: 4,160-8,319 HP). w5 boss never happens. Dawn arrives after 4:00 of play.
* **HORDE NIGHT** (rank 3): interval x0.5 applied after the floor -> 2.0/s at w1, 4.6/s at w11, **8.0/s from w18** (0.125 s). No bosses ever (so no relics, no 33% heals), no night events, no extraction; elites and basement/visitors still roll.
* **BOSS RUSH**: 3 concurrent bosses +1 per 5 player levels; the Nth boss spawned uses `boss_stats(N)` (Spawner.gd:60-68) — so the double-compounding HP (flag 1) is per KILL: boss #15 = 12.9k, #20 = 40k, #30 = 387k. Trash on the normal time curve, not halved, no elites. Heal 20%/kill, 30% relic chance.
* **Daily Shift**: endless + forecourt with seeded event/elite/type rolls. No stat change.

### Basement gauntlet (Basement.gd, logic/BasementLogic.gd, GC:668-689)
* Door roll: 25% per wave edge, w>=3, max 2 per run, blocked when |t-480| < 140 s (so only wave edges w3-w12 and w22+). Door lives 45 s.
* Gauntlet: 60 s, **fixed 0.55 s interval (1.82/s)**, current-wave stats and type mix, 800 px walled arena (spawns 700 px from center), 2 forced elites (3 past w10) at t = 10/20/30 s, no ambient elite roll, no boss. Then a fixed 8 s pickup window — the crate pickup does NOT shorten it (Basement.gd:217-220). Surface Spawner fully suspended (incl. `_check_boss`, Spawner.gd:25) while the clock keeps running = 68 s = 2.27 waves.
* vs surface: w3 1.54x spawn rate, w5 1.30x, w8 1.01x, **w9 0.93x, w12 0.73x, w22+ 0.45x**; elite share 1.8-2.8% vs surface 9-15%.
* On ascend every enemy > 2000 px from the surface point is freed (= the whole surface horde and the whole gauntlet) — a full screen clear; a live boss is teleported back to the spawn ring.

### Night events (NightEvents.gd; 22% per wave edge from w5, one at a time, 30 s)
* Blood Moon: interval x0.5 (can go to 0.125 s), +1 coin/kill. P(>=1 by dawn) ~ 52%. The final surge's forced-floor path ignores it (DifficultyManager.gd:56-57).
* Fog Bank (gems x2, dim), Power Surge (+2 chain jumps), Rush Hour (6-10 obstacles scattered): no threat increase.

### Visitors (GC:821-860; 20% per eligible wave edge from w4, 90 s cooldown, max 2/run, same dawn lockout)
* Drive-by: 2 s telegraph then 4 s of **80 DPS** in a 180 px-wide, 2400 px lane, hits player and enemies; flat (no wave scaling).
* Cryptid: 900 HP flat, flees at 130 px/s, 20 s, no attack. Ice cream truck: heal 30% for 150 coins.

### Ambient hazards (flat, never wave-scaled)
fire 25 dps r110 4 s · acid 18 dps r120 5 s + 45% slow · electric 15 dps r130 3 s · fuel-pump fire x1.5 (37.5 dps). Barrel bursts only damage enemies (Shockwave.blast).

---------------------------------------------------------------------------------------------------

## 5. Player survivability (base character, no upgrades)

* Base HP **100** (GC:7); Ryan 150; INSURANCE benefit +4/level (max +20). Base regen **0** (GC:8).
* **I-frames: none.** `Player.take_damage` (Player.gd:304-363) has no post-hit invulnerability; the only immunity timer is the 2.0 s post-revive window (`_revive_invuln_time`). Dash (700 px/s x 0.15 s = 105 px, 1.5 s CD) grants NO damage immunity — only immunity to Karen's shove. Every enemy has its own independent bite cooldown, boss contact and zones tick per frame.
* Heal sources: boss kill 33% max HP (every 2.5 min at best = ~0.22 HP/s) · Regeneration card +1 HP/s each · Tough Hide +20 max (and current) · relics field_kit +1.5 HP/s, vital_surge +40, blood_pact 1 HP/kill (disables all other healing) · lifesteal talents · truck heal 30% (150 coins) · Delivery Girl air drop 2x25 HP / 40 s. Mitigation: Iron Skin -15% contact only (multiplicative) · Quick Step +8% dodge (cap 40%). Death nets: Second Shift (Bob) -> Union Rep -> dead man's vest -> Second Wind, each 50% HP.

| t (min) | wave | shambler bite | hits to die 100 HP (150) | brute bite (hits) | exploder blast (hits) | volatile blast | spitter shot | lone-shambler contact DPS | **surround DPS (6 shamblers @0.6 s)** | **TTD surrounded 100 HP (150)** |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 1 | 10.0 | 10 (15) | — | — | — | — | 2.5 | 100 | 1.00 s (1.50) |
| 1 | 3 | 11.0 | 10 (14) | — | — | — | — | 2.9 | 110 | 0.91 (1.36) |
| 3 | 7 | 13.4 | 8 (12) | 29.5 (4) | 46.9 (3) | 56.3 | — | 3.8 | 134 | 0.75 (1.12) |
| 5 | 11 | 16.3 | 7 (10) | 35.8 (3) | 57.0 (2) | 68.4 | 19.5 | 5.6 | 163 | 0.61 (0.92) |
| 8 | 17 | 21.8 | 5 (7) | 48.0 (3) | 76.4 (2) | 91.7 | 26.2 | 17.5 | 218 | 0.46 (0.69) |
| 9.5 | 20 | 25.3 | 4 (6) | 55.6 (2) | 88.4 (2) | 106.1 | 30.3 | 21.7 | 253 | 0.40 (0.59) |
| 10 | 21 | 26.5 | 4 (6) | 58.4 (2) | 92.9 (2) | 111.4 | 31.8 | 22.7 | 265 | 0.38 (0.57) |
| 12 | 25 | 32.3 | 4 (5) | 71.0 (2) | 112.9 (1) | 135.5 | 38.7 | 27.6 | 323 | 0.31 (0.47) |
| 15 | 31 | 43.2 | 3 (4) | 95.1 (2) | 151.3 (1) | 181.5 | 51.9 | 37.0 | 432 | 0.23 (0.35) |
| 20 | 41 | 70.4 | 2 (3) | 154.9 (1) | 246.4 (1) | 295.7 | 84.5 | 60.3 | 704 | 0.14 (0.21) |

One-shot thresholds on a 100 HP player: volatile blast **w19 (9:00)** · Tanker rupture w20 · exploder + boss slam w23 (11:00) · band / charge w26 · brute bite w33 · mutant w37 · shambler w49. None are reduced by Iron Skin except bites and charges (is_contact).
One Regeneration card (1 HP/s) offsets 40% of ONE lone shambler at w1 and 6% at w17.

---------------------------------------------------------------------------------------------------

## 6. FLAGS — ranked, most severe first

**F1. Boss HP double-compounds past wave 10 and runs away.** `boss_stats` keeps the full `1.12^(wave-1)` exponent (DifficultyCurve.gd:42 — NOT frozen at w10 the way trash's `early` is) and THEN multiplies `BOSS_LATE_HP_GROWTH^(wave-10)` on top (DifficultyCurve.gd:47-48, GC:72) = x1.2544/wave vs trash x1.12. The code comment says "bosses ramp like trash does"; they ramp at trash's rate squared. Evidence: base boss 2,360 -> 4,160 -> **12,919** -> 40,125 -> 124,622 -> 387,057 (w5..w30); step w5->w10 x1.76, w10->w15 **x3.11**; boss/shambler HP ratio 30 -> 52.9 -> 93.2 -> 289 -> 899 (w40). Manager at w15 = 25.8k (207 s at the 125-DPS yardstick vs 67 s at w10), w20 = 80k, w30 = 774k. In Boss Rush the same curve is indexed per boss KILLED (Spawner.gd:60-68). The w15 boss is the last one an extracting player fights and it arrives 60 s before the surge.

**F2. "Pet boss" inversion: a living boss halves trash forever, bosses can't catch you, and nothing forces the kill.** Spawner.gd:41-42 doubles the interval for the boss's entire life; Spawner.gd:54 blocks any further boss while one lives; boss chase is 22.5-76.5 px/s and never scales (GC:70) vs player 220; no boss has an enrage/timer. Numbers: trash with a boss alive = 0.70/s at w5 (below the w1 rate of 1.00), 1.61/s at w15, and during the FINAL SURGE **2.0/s instead of 4.0/s — lower than the ordinary w14 rate (2.96/s)**. Leaving the w15 boss alive softens the whole surge and cancels the w20 boss. With F1 making post-dawn bosses effectively unkillable, late endless gets EASIER by ignoring them. The Brute is the ideal pet (single 220 px ring, 45 px/s).

**F3. The real cliff is the w11-w18 speed ramp, and it lands on dawn.** +15%/wave (GC:64): 83.7 -> 240 px/s = x2.87 in 4 min, against a fixed 220 px/s player who must stand still to fire (GC:18). Runners pass the player at w14 (249), exploders/mutants at w16, shamblers/spitters at w17 (222.5) = the dawn wave; runners hit 360. Time from spawn ring to player falls 14.3 s -> 5.0 s. Speed is also a hidden damage multiplier through the bite-bounce period: lone-shambler contact DPS 4.65 (w10) -> 19.65 (w18) = **x4.2, of which only x1.48 is the damage stat**. Over the same 8 waves spawn rate is +89% and HP x2.48. Everything before w10 grows speed at 2%/wave, so players get no warning.

**F4. No i-frames + no alive cap = sub-second time-to-die at every point of the run.** Player.gd:304-323 applies every hit; 6 shamblers fit around the player, each on its own 0.6 s cooldown (Enemy.gd:549-556): surround DPS = 10 x bite = 100 at w1 (TTD 1.00 s), 163 at w11 (0.61 s), 218 at w17 (0.46 s), 253 at w20 (0.40 s). "Hits to die" (10 -> 5 -> 4) looks gentle but is not the operative number. Defensive cards barely move it (Iron Skin -15%, Regen +1 HP/s vs 100-250 DPS). No max-alive cap exists anywhere (grep: none), so neither the surround nor mobile frame cost is bounded — at 4/s (8/s Horde/Blood Moon) plus hive broods and splitter children.

**F5. Triple early spike at 1:30-3:00.** Effective HP/s steps x1.668 at w4 (brutes, 4x HP at 9.7% of spawns), x1.450 at w6 (elite chance steps 0 -> 8.0%, not the documented 5% base — `0.05 + 0.005*6`, DifficultyCurve.gd:33-36), x1.47-1.86 at w7 (hives 6x HP + up to 8 shamblers each). w3 -> w7 = 61 -> 257-325 HP/s (**x4.2-5.3 in two minutes**, vs the normal x1.229/wave), and the w5 boss (2:00) sits in the middle of it. The stream crosses the 125-DPS base-gun yardstick at w5-6. Relative to the stream, the w5 boss is the biggest pre-dawn wall (19.6 s of stream; Manager 39 s) while the w10 and w15 bosses are the smallest (7.3 / 7.7 s).

**F6. Every cap converges on w18-w20, so post-extraction endless is flat.** Spawn floor w18 (DifficultyCurve.gd:27), speed cap w18 (DifficultyCurve.gd:20), elite cap w20, last new enemy type w12 (5:30), last new mechanic w10. After w20 only HP (+12%/wave) and damage (+5%) move: stream growth drops x1.229 -> x1.12 per wave and the run becomes "same 4/s horde, spongier" until burst one-shots arrive (volatile w19, rupture w20, exploder/slam w23 on 100 HP). Trash XP also flat-lines: gem value caps at 15 (Enemy.gd:655-659) once HP >= 750 = w25.

**F7. FINAL SURGE's spawn forcing is ~inert, and the "floor" is not a floor.** At dawn (w17) the natural interval is already 0.2634 s; forcing 0.25 (DifficultyManager.gd:56-57) is +5% for 30 s and exactly 0% for w18-w19. The surge's only real content is elite x2 (13.5 -> 27%, stream EHP +24%; with cursed_nametag x3 = 40.5%, +49% — multipliers are applied after the 15% cap, Spawner.gd:138). Meanwhile Blood Moon / Horde multiply AFTER the floor (DifficultyManager.gd:58) giving 0.125 s = 8/s — but a Blood Moon that overlaps the surge is silently discarded by the forced path, so the surge is the one moment a Blood Moon does nothing.

**F8. Boss roster variance exceeds five waves of scaling; several bosses are out of line.** Per-boss HP mult 0.733-2.0 on a uniform pick: a w5 Manager (4,721) out-tanks a w10 Stocker (3,050); at w15 the roll decides between 9.5k and 25.8k. Manager is the biggest sponge with the lowest lethality (3-3.9 dps direct) and his long life halves trash — a rest stop. Brute is a free kill (see F2). Tanker P3 carries the roster's largest hit (40, one-shots 100 HP at w20) plus up to 14 burning pools, on a 1.6x HP body. Mystery Shopper can hold the single boss slot through 3 x 45 s of concealment; her "slow shambler amble" is 15.75 px/s while real shamblers move 76-240 px/s (GC:784) — a glaring tell that also means the 45 s timeout, not the player, usually triggers the reveal.

**F9. Basement gauntlet inverts after w8 and can delete a boss.** Fixed 0.55 s interval (GC:679) = 1.82/s vs surface 1.95/s at w9, 2.5/s at w12, 4.0/s at w22+ (0.45x); forced elites are 1.8-2.8% of its 109 spawns vs 9-15% ambient on the surface; ascend wipes every straggler. Past w8 it is a 68 s breather with a guaranteed crate. And since the Spawner (incl. `_check_boss`) is suspended for a fixed 68 s (Spawner.gd:25, Basement.gd:212-220), descending at t in [82,120) or [232,270) spans the whole w5 / w10 boss window — that boss never spawns (Spawner.gd:51-54): no relic, no 33% heal, no 30 gems.

**F10. Splitter elites of high-HP types produce runner-speed tanks.** Children get 0.5 x the ELITE's max HP (Enemy.gd:141-163, GC:520-521) but runner speed. At w17 a normal runner has 123 HP; splitter children of a brute have **1,533 each**, of a hive **2,299 each**, of a mutant 1,149 — at 360 px/s (432 under an Alpha aura). Roughly 1 such event per ~50 s at dawn; also rollable from the basement's forced elites and amplified by the surge's elite x2.

**F11. The rank-gated Transfer Stores are easier than the starter map in HP terms.** Big Mart 0.92-0.955x, Parking Garage 0.92-0.975x expected HP per spawn (up-weighted shamblers dilute brutes/hives/mutants, Locations.gd:55,63). Mart halves spitters (11.5 -> 5.1%); Garage's car alarms taunt enemies off the player. Only Garage's exploder share (9.2 -> 11.6%) raises burst risk. No location touches any stat multiplier.

**F12. Dead / inert / mislabeled config.**
* `DEBUFF_SLOW_DURATION` (GC:213) is the only one of 641 consts never read anywhere — DebuffApplier falls back to DEBUFF_JAM_DURATION for both kinds (patterns/DebuffApplier.gd:16).
* `ENEMY_LATE_HP_GROWTH` = `ENEMY_HP_GROWTH` = 1.12: the documented "steeper late HP ramp" (GC:59-63) does not exist; only speed has a knee.
* `ENEMY_CONTACT_HIT_CD` 0.6 s never binds for a free-bouncing enemy (min natural period 0.78 s at 360 px/s).
* `ELITE_CHANCE_BASE` 0.05 is never a realized chance (min 8%).
* Boss `speed_mult`s are cosmetic against a 220 px/s player; comments disagree with the numbers: MASCOT_SPEED_MULT_L3 "faster than the player's base walk" = 60.75 px/s (GC:803); KAREN_SPEED_MULT 0.85 "quick for a boss" = 38.25 px/s, slower than the Brute's 45 (GC:398); Mascot "HP is front-loaded" but phases are equal thirds (bosses/Mascot.gd:66-90).
* Flat, never-scaled threats: Drive-by 80 DPS (4x any other ground hazard; 1.25 s TTD on 100 HP at every wave, while its 320 total damage stops killing even a plain shambler from w18 (343 HP)) and Cryptid 900 HP (12.8 shamblers' worth at w4, 1.2 at w25).
* HARDCORE changes nothing on the threat side; OVERTIME's first boss arrives at 0:30 of play.

Dependencies on other domains: every "is this too hard" judgment above needs the player DPS curve (weapons/talents/cards) — in particular F1 (can DPS grow x3.1 between 4:30 and 7:00?), F5 (DPS at 2:00-3:00) and F4 (kill rate needed = spawn rate: 1.0/s at 0:00, 2.3/s at 5:00, 3.8/s at 8:00, 4.0/s after 8:30).

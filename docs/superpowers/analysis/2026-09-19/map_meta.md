# The Dead Shift v0.1.72 — META-PROGRESSION & LOOT GRIND MAP

Read-only analysis. All paths relative to `/mnt/c/Users/thela/Documents/mobile-game/`.
Arithmetic scripts (python) live beside this file: `odds.py`, `runs.py`, `talents.py`, `affix.py`, `meta.py`, `daily.py`, `blend.py`.

Designer constraint honoured: talent level-gating and the steep rarity curve are **quantified, not flagged** as problems in themselves. Flags below are about things *around* them (dominated options, dead rewards, unreachable ladders, imperceptible rungs).

---

## 0. Player profiles used to convert "pulls" into "runs"

Coin income is another analyst's domain; I only need it to convert crates to runs. Three stated-assumption profiles (formula: `CoinReward.gd:6-10` coins = 10 + 5·wave + 25·boss + kills + bonus; weapon XP = kills + 10·wave + 50·boss, `CoinReward.gd:100-105`):

| Profile | Dies / ends | Kills | Bosses | Coins/run | Weapon XP/run | Runs/day |
|---|---|---|---|---|---|---|
| NOVICE | wave 6 | 110 | 1 | ~180 | ~220 | 3 |
| TYPICAL | wave 11 | 350 | 2 | ~500 | ~560 | 5 |
| SKILLED | extracts ~wave 20 (×1.5 pay) | 950 | 3 | ~2,250 | ~1,300 | 5 |

Sanity ceiling: total trash spawns by end of wave 5/10/15/17/20 = 178 / 449 / 860 / 1,079 / 1,439 (one spawn per interval, `1.0·0.92^(w-1)`, floor 0.25; halves while a boss lives).

Rarity name mapping used for "Rare / Epic / Legendary": the game has 9 tiers (`Rarity.gd:22-32`). By colour convention: **Lethal (4, blue) = "Rare"**, **Savage (5, purple) = "Epic"**, **Merciless (7, orange) = "Legendary"**; Carnage (6, red) sits between; Apocalypse (8, rainbow) and Armageddon (9, gold) are above.

---

## 1. CRATE / LOOT ODDS

### 1.1 The roll (`Rarity.gd:93-102`)
Start at floor; climb from tier i to i+1 with probability 1/(i+1); stop at ceil. Therefore **P(≥k | floor f) = f!/k!** exactly. No pity, no dupe protection, no bad-luck counter anywhere (`CrateOpener.gd:105` rolls once; the 5 "tease" tiles at reel index 28/40/52/64/70 are cosmetic).

### 1.2 Exact rarity table per crate (%) — `Crates.gd:9-62`

| Crate | Price | Pool | Rusted | Salvaged | Hardened | Lethal | Savage | Carnage | Merciless | Apocalypse | Armageddon |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Scrap Crate | 75 | 21 | 50 | 33.3 | 12.5 | **4.17** | – | – | – | – | – |
| Footlocker | 150 | 21 | 50 | 33.3 | 12.5 | 3.33 | 0.694 | 0.119 | 0.0174 | 0.0022 | 0.00028 |
| Munitions Cache | 600 | 21 | – | – | – | 80 | 16.7 | 2.86 | 0.417 | 0.053 | 0.0066 |
| Titan Crate | 2,500 | 21 | – | – | – | – | 83.3 | 14.3 | 2.08 | 0.265 | 0.033 |
| Apex Crate | 9,000 | 21 | – | – | – | – | – | 85.7 | 12.5 | 1.59 | 0.198 |
| Apocalypse Crate | 30,000 | 21 | – | – | – | – | – | – | 87.5 | 11.1 | 1.39 |
| Buckshot&Bolts / Full Auto / Standard Arms | 500 | 6 each | – | 66.7 | 25 | 6.67 | 1.39 | 0.238 | 0.0347 | 0.0044 | 0.00055 |
| Specials Case | 650 | 3 | – | 66.7 | 25 | 6.67 | 1.39 | 0.238 | 0.0347 | 0.0044 | 0.00055 |
| 50/50 Crate | 700 | 21 | 50 | – | – | – | **50** | – | – | – | – |

Gun pools: the 4 themed crates partition all 21 bases (6+6+6+3). All others draw uniformly from 21 (`LootRoller.gd:17-18`). Within a rarity the affix is uniform over that tier's rollable affixes (2/3/3/4/4/4/4/4/4 for r1..r9).

### 1.3 Expected crates (coins) to first ≥tier — cheapest path in **bold**

| Target | Scrap | Footlocker | Munitions | Titan | Apex | Apoc | Themed | 50/50 |
|---|---|---|---|---|---|---|---|---|
| ≥Lethal "Rare" | 24 (1,800) | 24 (3,600) | **1 (600)** | 1 | 1 | 1 | 12 (6,000) | 2 (1,400, skips to Savage) |
| ≥Savage "Epic" | never | 120 (18,000) | 5 (3,000) | 1 (2,500) | 1 | 1 | 60 (30,000) | **2 (1,400)** |
| ≥Carnage | never | 720 (108k) | 30 (18,000) | 6 (15,000) | **1 (9,000)** | 1 | 360 (180k) | never |
| ≥Merciless "Legendary" | never | 5,040 (756k) | 210 (126k) | 42 (105k) | 7 (63k) | **1 (30,000)** | 2,520 (1.26M) | never |
| ≥Apocalypse | never | 40,320 (6.0M) | 1,680 (1.0M) | 336 (840k) | 56 (504k) | **8 (240k)** | 20,160 (10M) | never |
| Armageddon | never | 362,880 (54M) | 15,120 (9.1M) | 3,024 (7.6M) | 504 (4.5M) | **72 (2.16M)** | 181,440 (91M) | never |

**Specific base gun** (multiply by pool size): 
- specific base ≥Savage: 50/50 = 42 crates / **29,400c**; Titan 52,500c; Munitions 63,000c; themed 360 crates / 180,000c; Specials 117,000c.
- specific base ≥Merciless ("a specific gun at Legendary"): Apoc crate 21 crates / **630,000c**; Apex 1.32M; themed 7.56M; Specials 4.9M.
- specific base + specific affix family at Merciless: ×4 → 2.52M coins. Specific base at Armageddon: 1,512 Apoc crates = 45.4M coins.

### 1.4 Deconstruct value of a crate (EV if you scrap the result) — `Rarity.gd:22-32` scrap bands, `Inventory.gd:97-115`

| Crate | Price | EV coins back | % back | EV SCRAP | net coins per SCRAP |
|---|---|---|---|---|---|
| Scrap Crate | 75 | 36.2 | 48% | 3.20 | 12.1 |
| Footlocker | 150 | 40.0 | 27% | 3.58 | 30.8 |
| Munitions | 600 | 269.5 | 45% | 26.5 | **12.5** |
| Titan | 2,500 | 627.7 | 25% | 62.3 | 30.0 |
| Apex | 9,000 | 1,516 | 17% | 151 | 49.5 |
| Apocalypse | 30,000 | 3,715 | 12% | 371 | 70.8 |
| Themed | 500 | 65.0 | 13% | 6.1 | 71.8 |
| Specials | 650 | 65.0 | 10% | 6.1 | 96.5 |
| 50/50 | 700 | 232.5 | 33% | 22.8 | 20.5 |

### 1.5 Crate SOURCES

**Bosses do not drop crates.** `patterns/CrateDrop.gd` is a Night-Stocker terrain pattern (drops a cover obstacle); `AirDropMarker.gd` is the Delivery Girl ability (2 health packs + 3 gems). Neither is a loot source. Every `add_crate` site in the codebase:

| Source | File:line | What | Cadence |
|---|---|---|---|
| Basement gauntlet | `BasementCratePickup.gd:43`, `BasementLogic.gd:35-51` | crate by wave floor (2 + wave/5, cap 7) | 25%/wave-edge from wave 3, max 2 doors/run, 60s gauntlet |
| Cryptid visitor | `Cryptid.gd:125` | same wave→crate map + 250c | visitor 20%/wave-edge from wave 4, max 2/run, cryptid = 1 of 3 kinds, must kill 900 HP in 20s |
| Daily login | `MainMenu.gd:1584`, `Rewards.gd:12-54` | price-weighted random crate | 1/day |
| 10-game milestone | `Rewards.gd:16-20` | 50% random crate / 50% floor-1 rolled gun | per 10 completed runs (≥120s) |
| Challenges | `Challenges.gd:34-57`, `ChallengeProgress.gd:68-91` | fixed crate per challenge | 3 active/day, full reset daily |
| Commendations | `Commendations.gd:34-69`, `GameConfig.gd:660-665` | EASY scrap crate ×5, MED munitions ×10, HARD titan ×3 | 18 one-time |
| Store | `Inventory.gd:120-130` | any | coins |

**In-run crates per run (200k-run Monte Carlo, `runs.py`):**

| Dies at wave | Ceiling (every door cleared, every cryptid killed) | Realistic (70% enter × 70% clear, 35% cryptid kill) |
|---|---|---|
| 6 | 0.83 Munitions | 0.46 |
| 10 | 1.57 Munitions | 0.81 |
| 13–20 | 1.84 Munitions | 0.92 |
| 26 (skipped extraction) | 1.84 Mun + 0.21 Apex + 0.26 Apoc | 0.92 Mun + 0.08 Apex + 0.10 Apoc |

The wave-scaled basement floor is essentially fiction in endless: doors cannot roll while |run_time − 480| < 140 (`Basement.gd:83`, `GameConfig.gd:670`) = waves 13–21; Titan needs the reward to land at wave 15–19, Apex 20–24, Apocalypse 25+. The 2-door cap (`GameConfig.gd:671`, counted at spawn even if never entered, `Basement.gd:124`) is already exhausted by wave 12 in 76% of runs. **Refined sim (random 5-45s entry delay, every door cleared): share of basement crates that are Munitions = 100% for runs ending by wave 13, 97.2% by wave 17-20 (2.8% Titan, only from a wave-12 door entered late), 85% for a wave-26 run (2.4% Titan / 3.5% Apex / 8.9% Apoc).** (BasementLogic.gd's own comment: "waves 3-14 all pay munitions_cache".)

### 1.6 Expected RUNS to each rarity milestone (all sources blended, `blend.py`)

"free" = in-run + challenges + daily + milestone. "all-in" additionally spends 100% of run coins on the cheapest path for that tier (ignores scrap-back, which would shorten the top tiers ~12–45%).

| Milestone | NOVICE free / all-in | TYPICAL free / all-in | SKILLED free / all-in |
|---|---|---|---|
| ≥Lethal "Rare" | 1 / 1 | 1 / 1 | 1 / 1 |
| ≥Savage "Epic" | 4 / 3 | 3 / 1 | 2 / 1 |
| ≥Carnage | 26 / 17 | 17 / 9 | 9 / 3 |
| ≥Merciless "Legendary" | 133 / 74 (25 d) | 90 / **36 (7 d)** | 56 / 11 (2 d) |
| ≥Apocalypse | 1,066 / 592 (197 d) | 716 / **287 (57 d)** | 446 / 86 (17 d) |
| Armageddon | 9,592 / 5,331 (4.9 yr) | 6,446 / **2,587 (517 d)** | 4,011 / 775 (155 d) |
| specific base ≥Savage | ~61 | ~31 | ~10 |
| specific base ≥Merciless | 2,026 (675 d) | **907 (181 d)** | 238 (48 d) |

Median ("50% chance by") = 0.69 × the mean, e.g. TYPICAL Armageddon median ≈ run 1,800.

---

## 2. WEAPON LEVELING + TALENTS (kept by design — numbers only)

### 2.1 XP
- Earned ONLY by the equipped instance at run end: `kills + wave·10 + bosses·50` (`CoinReward.gd:101`), × Punch Card relic 1.2, × HARDCORE 2 (`GameConfig.gd:626`). Quit path pays the same XP (no 0.75 haircut on XP).
- Curve: level L→L+1 costs `L·100` (`WeaponInstance.gd:211`). Cumulative to reach level L = 50·L·(L−1):

| Level | 3 | 5 | 8 | 10 | 12 | 15 | 18 | 20 | 25 | 28 |
|---|---|---|---|---|---|---|---|---|---|---|
| Cum XP | 300 | 1,000 | 2,800 | 4,500 | 6,600 | 10,500 | 15,300 | 19,000 | 30,000 | 37,800 |
| TYPICAL runs (560) | 0.5 | 1.8 | 5 | 8 | 12 | 19 | 27 | 34 | 54 | 68 |
| NOVICE runs (220) | 1.4 | 4.5 | 13 | 20 | 30 | 48 | 70 | 86 | 136 | 172 |
| SKILLED runs (1,300) | 0.2 | 0.8 | 2.2 | 3.5 | 5 | 8 | 12 | 15 | 23 | 29 |

- No level cap; level does nothing except gate talents (`WeaponInstance.gd:65-71`; no other reader of `inst.level` in Gun/TalentEngine/Player).

### 2.2 Talent slots and unlock levels
- Count fixed per rarity (`Rarity.gd:22-32`): r1–2 = 0, r3–4 = 1, r5 = 2, r6–7 = 3, r8 = 4, r9 = 5. Slot i draws tier min(i+1, 3); 60 talents = 15 T1 / 22 T2 / 23 T3.
- `unlock_level = randi_range(min,max)` per talent (`LootRoller.gd:68`). Ranges: T1 1–5 (avg 3.0), T2 5–18 (avg 9.3), T3 12–28 (avg 18.6; Reaper 18–28 is the top).
- Only **14.6%** of talent-bearing drops have a talent already live at pickup (unlock_level 1).

| Rarity | Talents | Full-unlock level: mean / p10 / p90 / max | Mean XP to full | NOVICE / TYPICAL / SKILLED / SKILLED+HC runs | Worst case (Lv28) runs |
|---|---|---|---|---|---|
| Hardened, Lethal | 1 | 3.0 / 1 / 5 / 5 | 373 | 2 / 1 / <1 / <1 | 5 / 2 / 1 / <1 |
| Savage | 2 | 9.3 / 6 / 12 / 18 | 4,194 | 19 / 7 / 3 / 2 | 70 / 27 / 12 / 6 |
| Carnage, Merciless | 3 | 18.6 / 14 / 23–24 / 28 | 17,040 | 77 / 30 / 13 / 7 | 172 / 68 / 29 / 15 |
| Apocalypse | 4 | 20.6 / 17 / 24 / 28 | 20,677 | 94 / 37 / 16 / 8 | same |
| Armageddon | 5 | 21.6 / 18 / 25 / 28 | 22,684 | 103 / 41 / 17 / 9 | same |

So for the TYPICAL player every new 3-talent gun is ~30 runs (6 days) from full power; ~1 tier-1 talent after ~1–2 runs, tier-2 after ~7, tier-3 after ~30. That is the gate Larry wants; the numbers show it is roughly the same length as the wait for the *next* rarity tier (Carnage→Merciless = 36 runs all-in), so a TYPICAL player rarely finishes levelling a gun before replacing it.

### 2.3 Fusion as an XP source (`Inventory.gd:194-231`, `GameConfig.gd:562`)
XP = sacrifice scrap-midpoint × 2; same base only (1 in 21 drops matches a given target).

| Sacrifice | Rusted | Salvaged | Hardened | Lethal | Savage | Carnage | Merciless | Apoc | Armageddon |
|---|---|---|---|---|---|---|---|---|---|
| XP | 30 | 60 | 180 | 360 | 900 | 2,300 | 6,000 | 15,000 | 37,000 |
| vs one TYPICAL run (560) | 5% | 11% | 32% | 64% | 1.6× | 4.1× | 10.7× | 27× | 66× |

Reroll-lowest-stat only fires if sacrifice rarity ≥ target rarity (`Inventory.gd:212`): for a Merciless target that means a second same-base Merciless+ = 21 Apoc crates = **630,000 coins per single-stat reroll**, and the reroll is a fresh uniform 0..1 (can go down on display only if it was the lowest — it replaces the lowest, so EV new = 0.5).

### 2.4 Affix roll ranges and bad-vs-god spread (`Affixes.gd:37-71`, `affix.py`)
Instance stores 0..1 quality per stat; number of stats rolled is uniform in [min_stats, max_stats]; signature stat always included. DPS multiplier below = (1+dmg%)·1/(1−fire_rate%)·(1+multishot) on a 1-projectile gun (pierce/ricochet/mag/reload/range excluded, so real spread is wider).

| Rarity | Worst possible | p10 | Median | p90 | God roll | god/worst | p90/p10 |
|---|---|---|---|---|---|---|---|
| 1 Rusted | ×1.06 | 1.07 | **1.10** | 1.14 | 1.2 | 1.1× | 1.1× |
| 2 Salvaged | ×1.00 | 1.00 | **1.13** | 1.20 | 1.2 | 1.2× | 1.2× |
| 3 Hardened | ×1.14 | 1.16 | **1.23** | 1.34 | 1.4 | 1.2× | 1.2× |
| 4 Lethal | ×1.00 | 1.23 | **1.80** | 2.72 | 2.9 | 2.9× | 2.2× |
| 5 Savage | ×1.32 | 1.95 | **3.00** | 4.84 | 7.4 | 5.6× | 2.5× |
| 6 Carnage | ×1.44 | 2.08 | **5.06** | 9.38 | 14.3 | 9.9× | 4.5× |
| 7 Merciless | ×1.64 | 3.00 | **7.07** | 15.3 | 26.7 | 16× | 5.1× |
| 8 Apocalypse | ×1.88 | 4.72 | **10.4** | 28.4 | 53.4 | 28× | 6.0× |
| 9 Armageddon | ×6.38 | 11.1 | **17.0** | 82.1 | 245 | 38× | 7.4× |

Observations (numbers, not judgement): tiers 1→3 differ by ≤13% median DPS; the first perceptible step is Lethal (×1.8), and a bad Merciless (×1.64–3.0) is weaker than a median Savage (×3.0). Flat stats round: multishot [2,4] → +2 for roll <0.25, +3 for 0.25–0.75, +4 for ≥0.75. r9 Razor/Brutal fire_rate [60,90]% means a fire interval ×0.40 → ×0.10.

---

## 3. COWORKERS (STAFF FILE) — `Coworkers.gd`, `MainMenu.gd:1534-1549`, `GameConfig.gd:692-724`

### 3.1 Correction to the brief
Traits are **not** an incremental +0.8% stat. A coworker is `{type, rarity, trait}`, rolled once, never levelled, never fused, never stacked (one equipped). Trait magnitudes are large and binary: SHARP +25% dmg, WIRED +20% rate, WIDE +25% range, STEADY +30% mannequin HP/duration, CHILLING 25% slow 1.5s, PINNING 15% pin, MAGNETIC +40% pickup radius, STUDIOUS +10% player XP. The "0.8%" figure is the **old per-pull chance of getting any trait** (1/120 = 0.83% when `COWORKER_TRAIT_MIN_RARITY` was 5). Since v0.1.67 it is rarity ≥4 → **1/24 = 4.17%**. The GameConfig comment on line 693 claims "~15% of pulls" — that is wrong by 3.6×.

### 3.2 Per-pull outcomes (800 coins, `Rarity.roll(1,9)`, type uniform 1/3)

| Rarity | P | stat_mult | DPS mult (dmg×rate) | Drone dps | Cat dps | Trait? | Pulls to ≥ this | Coins |
|---|---|---|---|---|---|---|---|---|
| Rusted | 50% | ×1.00 | ×1.00 | 8.2 | 10.0 | no | 1 | 800 |
| Salvaged | 33.3% | ×1.18 | ×1.39 | 11.4 | 13.9 | no | 2 | 1,600 |
| Hardened | 12.5% | ×1.36 | ×1.85 | 15.1 | 18.5 | no | 6 | 4,800 |
| Lethal | 3.33% | ×1.54 | ×2.37 | 19.4 | 23.7 | **yes** | 24 | 19,200 |
| Savage | 0.694% | ×1.72 | ×2.96 | 24.2 | 29.6 | yes | 120 | 96,000 |
| Carnage | 0.119% | ×1.90 | ×3.61 | 29.5 | 36.1 | yes | 720 | 576,000 |
| Merciless | 0.0174% | ×2.08 | ×4.33 | 35.4 | 43.3 | yes | 5,040 | 4.03M |
| Apocalypse | 0.0022% | ×2.26 | ×5.11 | 41.8 | 51.1 | yes | 40,320 | 32.3M |
| Armageddon | 0.00028% | ×2.44 | ×5.95 | 48.7 | 59.5 | yes | 362,880 | 290M |

- No trait at all: **95.83%** of pulls.
- Specific type + specific trait (any rarity ≥4): cat 1/432 (345,600c), drone 1/504 (403,200c), mannequin 1/288 (230,400c) → **460–800 TYPICAL runs of 100% coin income**. At rarity ≥5: 1,440–2,520 pulls (1.15–2.0M coins).
- Collect all 17 type×trait combos: mean 1,518 pulls = 1.21M coins.
- "Max" a coworker (Armageddon): 362,880 pulls = 290M coins; with chosen type+trait ≈ 5.2B coins. Roster max is not a meaningful goal.
- Context: bare pistol = 125 dps, AK 183, LMG 229. A Rusted drone = 6.5% of a bare pistol; trash HP grows ×1.12/wave (139 HP at wave 10, 430 at wave 20) and coworkers never scale with the run. A Rusted drone kills one wave-10 zombie per 17 s while the spawner emits ~36.
- Upgrade cadence for a single equipped slot: after an r1, P(next pull is better) = 50%; after r2 16.7%; after r3 4.17% (EV 19,200c); after r4 0.83% (EV 96,000c). The ladder stalls at Hardened/Lethal for everyone.
- Duplicates/unwanted pulls: scrap value = half the weapon band (`Coworkers.gd:129-134`) → EV ≈ 20 coins + ~2 scrap per 800-coin pull (**2.5% back**). No fusion, no XP, no other sink. No cap on the coworker list in the save.

---

## 4. BENEFITS / SCRAP LADDER — `Benefits.gd`, `GameConfig.gd:610-621`

SCRAP source: only deconstructs — `max(1, payout/10) × PACK RAT`, rounded (`Inventory.gd:109`; coworker twin `MainMenu.gd:935`). Avg scrap per gun: Rusted 1.1, Salvaged 2.6, Hardened 8.6, Lethal 17.6, Savage 44.6, Carnage 115, Merciless 300, Apoc 750, Armageddon 1,850.

| Track | Cap | Per level | At max | Cost per level | Total | Perceptibility |
|---|---|---|---|---|---|---|
| INSURANCE | 5 | +4 max HP | +20 HP | 25/60/140/320/700 | 1,245 | one bite = 10 HP (wave 1) → 15.5 (wave 10); +4 HP = 0.26–0.4 of a bite. Imperceptible per level; max ≈ 1.3 bites |
| COMFY SHOES | 5 | +2% move | +10% | same | 1,245 | 220 → 224.4 px/s per level: imperceptible. Max 242 px/s just clears the 240 enemy speed cap — only matters wave 18+ |
| NIGHT SCHOOL | 5 | +3% XP | +15% | same | 1,245 | +3% = **0 extra level-ups** at 200/400/1500 XP runs; max = +1 level-up per run (+2 at 1,500 XP) |
| SIGNING BONUS | 5 | +50 coins (vests over 120s, post-mult) | +250 | same | 1,245 | +10%/lvl of a TYPICAL run; +50% at max. Strong for novice/typical, 11% for skilled |
| SECOND OPINION | 3 | +1 level-up reroll | 3 rerolls | 25/60/140 | 225 | discrete, clearly felt; cheapest track |
| STRETCH BREAKS | 5 | −4% dash CD | −20% | same | 1,245 | 1.50s → 1.44s per level (−0.06s): imperceptible; max 1.20s |
| REGISTER SKIM | 5 | +2% coins | +10% | same | 1,245 | +10 coins on a 500-coin run per level = **1/5 of SIGNING BONUS at the same price**; only overtakes it above ~2,500 coins/run (or under HARDCORE ×3) |
| PACK RAT | 5 | +10% scrap | +50% | same | 1,245 | after `roundi`: L1 = ×1.000 on Rusted AND Salvaged; L2 = ×1.000 on Rusted; L3–L4 = ×1.083 on Rusted; only L5 jumps (×1.92). Nominal on Hardened+ |
| UNION REP | 1 | 1 revive/run @50% HP, 2s invuln | – | 900 | 900 | dominant; disabled in HARDCORE |

- **Total to max everything: 9,840 scrap.** Per 5-cap track, the L5 rung alone (700) is 56% of the track for the same increment as L1 — 28× the price per unit.
- Scrap income if *everything* is scrapped: NOVICE ~13/run, TYPICAL ~38/run, SKILLED ~100/run → first rung in <2 runs; UNION REP at run ~70 / ~24 / ~9; **everything maxed at run ~760 / ~260 / ~100**. Real players keep their good guns (the ones worth the most scrap), so real timelines are longer.
- Cheapest scrap per net coin: Scrap Crate 12.1 and Munitions 12.5 coins/scrap → maxing benefits purely by buying = ~123,000 net coins (~245 TYPICAL runs).
- Solved order: SECOND OPINION (225) → UNION REP (900) → SIGNING BONUS → everything else is cosmetic-scale.

---

## 5. UNLOCK TIMELINE

What actually gates what:
- **Characters**: coin price only (`Characters.gd:17-44`): Ryan 0, Bob 400, Jimbo 600, Alstar 2,400, Janitor 2,800, Delivery Girl 3,200, Jackson 3,600 → **13,000 coins total** = 26 TYPICAL / 72 NOVICE / 6 SKILLED runs if nothing else is bought.
- **Locations**: rank 2 BIG MART, rank 4 PARKING GARAGE (`GameConfig.gd:728-729`).
- **Modes**: rank 3 HORDE, rank 5 OVERTIME, rank 7 HARDCORE (`GameConfig.gd:605-607`, `Ranks.gd:11-15`).
- **Relics**: **no meta unlock at all.** All 27 relics (10 standard / 10 prototype / 7 cursed) are in the pool from run 1 (`Relics.gd:92-106` filters only held / hardcore / mode). Nothing about relics persists between runs.
- **Rank**: rank XP = coins actually paid (`GameOver.gd:195`) + commendation XP (4,500 total = 6% of the ladder).

| Rank | Threshold | Gap | NOVICE run | TYPICAL run | SKILLED run | Unlocks |
|---|---|---|---|---|---|---|
| 2 CLERK | 500 | 500 | 3 | 1 | 1 | BIG MART |
| 3 NIGHT CLERK | 1,500 | 1,000 | 8 | 3 | 1 | HORDE NIGHT |
| 4 SHIFT LEAD | 3,500 | 2,000 | 19 | 7 | 2 | PARKING GARAGE |
| 5 KEYHOLDER | 7,000 | 3,500 | 39 | 14 | 3 | OVERTIME |
| 6 ASST MANAGER | 12,000 | 5,000 | 67 | 24 | 5 | nothing |
| 7 STORE MANAGER | 20,000 | 8,000 | 111 | 40 | 9 | HARDCORE |
| 8 DISTRICT MGR | 32,000 | 12,000 | 178 | 64 | 14 | nothing |
| 9 REGIONAL DIR | 50,000 | 18,000 | 278 | 100 | 22 | nothing |
| 10 FRANCHISE OWNER | 75,000 | 25,000 | 417 | 150 | 33 (~17 with HARDCORE ×3) | nothing |

### TYPICAL player, run by run (5 runs/day)

| Run | Unlocks landing |
|---|---|
| 1 | FIRST DAY badge (+scrap crate), rank 2 → BIG MART, daily crate, starter 150c crate, first basement Munitions → first Lethal, Bob affordable |
| 1–3 | first Savage; first tier-1 talent live (≤1,000 XP); first benefit rungs; Jimbo; rank 3 → HORDE |
| 7 | rank 4 → PARKING GARAGE; first tier-2 talent on a Savage (avg Lv9.3) |
| 8 | EXTERMINATOR (2,500 kills), PEST CONTROL (100 elites) |
| ~9 | first Carnage |
| 10 | PUNCHING IN; first 10-game reward |
| 13–14 | MIDDLE MANAGEMENT (25 bosses); rank 5 → OVERTIME |
| 20–30 | RECYCLER (10 fusions); UNION REP (~run 24); rank 6 (name only); all characters if coins went there (run 26) |
| 35–40 | EMPLOYEE OF THE MONTH (calendar day 7); first Merciless (~36); BIG SPENDER (~38); first fully-unlocked 3-talent gun (~39); **rank 7 → HARDCORE (run 40) = last functional unlock in the game** |
| 50 | UPPER MANAGEMENT (100 bosses); REGULAR (calendar day 10) |
| 63–71 | TASKMASTER (25 challenges); rank 8 (name); GENOCIDE SHIFT (25,000 kills) |
| 100 | CAREER CLERK; rank 9 (name) |
| 150 | rank 10 (name) |
| ~260 | all benefits maxed |
| ~290 | first Apocalypse → OVER THE RAINBOW |
| ~2,600 | Armageddon → GOLDEN TICKET (18/18) |
| skill-gated | DAWN PATROL / WEEK ONE (1 / 5 extractions); PAYDAY (2,000 pre-mult coins in one run ≈ wave 21–23 without Janitor, i.e. *past* the extraction win; Janitor's +1 coin/kill roughly halves the requirement) |

**Front-loaded dump:** runs 1–14 (three days) deliver both locations, 2 of 3 modes, 5 badges, 2–3 characters, rarity tiers 1→6, the first benefits.
**Dead zones:** run 40→63 (one badge at 50), run 71→100, 100→150 (a rank *name*), 150→260 (L5 benefit rungs at 700 scrap each for +2–4%), **290→2,600 (nothing at all)**. For SKILLED players everything except the two top-rarity badges is finished by run ~100, ranks by run 33.

---

## 6. DAILY STREAK + CHALLENGES vs a normal run's haul

### 6.1 Daily crate (`Rewards.gd:29-92`, `GameConfig.gd:359-360`)

| Streak | P(Scrap/Footlocker) | P(Munitions) | P(Titan) | P(Apex)+P(Apoc) | P(≥Lethal) | P(≥Savage) | P(≥Merciless) | EV list price | EV scrap-back |
|---|---|---|---|---|---|---|---|---|---|
| 1–2 | 51.0% | 5.10% | 1.91% | 1.27% | 15.9% | 7.6% | 0.82% | 606 | ~114 |
| 3–6 "tier up" | 47.1% | **4.41%** | **1.47%** | 2.94% | 16.3% | 8.4% | 1.76% | 926 | ~150 |
| 7+ "floor" | 0% | 86.8% | 1.47% | 2.94% | **93.8%** | 24.0% | 2.13% | 1,190 | ~333 |

- Day-3 tier-up: the visible outcome barely moves (junk crate 51% → 47%, ≥Lethal 15.9% → 16.3%). The shift re-uses the *next* tier's smaller weight for everyone and caps at the top, so Munitions and Titan odds actually **fall**; only the 9k/30k crates rise (0.64% → 1.47% each).
- Day-7 floor is a cliff: ≥Lethal 16% → 94%. One missed day resets to 1 (`Rewards.gd:101-106`) = six more days of ~49% junk.
- Versus a TYPICAL 500-coin run: list value 1.2 / 1.9 / 2.4 runs; scrap-back value 0.23 / 0.30 / 0.67 runs.

### 6.2 10-game milestone (`Rewards.gd:16-20`)
50% random crate (streak-0 weights) / 50% floor-1 gun. **P(result ≥Lethal) ≈ 10%**; 39% of the time it is a Rusted item. EV scrap-back ≈ 77 coins per 10 runs = **1.5% of 10 TYPICAL runs' coin income**.

### 6.3 Challenges (`Challenges.gd:34-57`, 3 of 12 dealt per calendar day, all progress wiped daily)

| Challenge | Target | Reward (list) | Effort |
|---|---|---|---|
| Kill zombies | 60 | Scrap Crate (75) | first minute of any run |
| Reach 2:00 AM | 240s | Scrap Crate (75) | wave 9 |
| Kill elites | 8 | 50/50 (700) | 1 run past wave 8 |
| Survive a Blood Moon | 1 | 50/50 (700) | ~30%/run (22% event × ¼ kind per wave from w4) |
| Fire / Electric / Poison kills | 20 | 50/50 (700) | gear/card-gated |
| Defeat bosses | 3 | Munitions (600) | 2 runs |
| Power Surge kills | 15 | Munitions (600) | ~29%/run |
| **Open 3 crates** | 3 | **Titan (2,500)** | menu action, 225 coins of Scrap Crates |
| **Fuse 2 weapons** | 2 | **Titan (2,500)** | menu action, two same-base junk dupes |
| Win an extraction | 1 | Apex (9,000) | skill-gated |

- Average reward per slot = 1,571 list coins; 3/day = 4,712 if all done.
- Estimated completion: TYPICAL 2.0 crates/day ≈ **1,884 list coins/day = 75% of the day's 2,500 coin income**, yielding 0.84 Savage+/day, 1 Carnage+ per 11 days. SKILLED 2.7/day ≈ 4,185 list coins (37% of coin income), 1 Carnage+ per 3 days.
- "Open 3 crates" is a positive-EV loop on the days it is dealt (25% of days): spend 225c (get 109c back in scrap) → Titan with EV scrap-back 628c + a guaranteed Savage.

---

## 7. FLAGS — ranked, most severe first

**F1. STAFF FILE is a near-dead sink with a wrong odds comment.** 800c/pull; 95.8% of pulls carry no trait; P(trait) = 1/24 = 4.17%, not the "~15% of pulls" written at `GameConfig.gd:693`. Specific type+trait = 1 in 288–504 pulls (230k–403k coins = 460–800 TYPICAL runs). Unwanted pulls refund ~20c + 2 scrap (2.5%), with no fusion/XP/dupe sink (`Coworkers.gd:129-134`). After ~6 pulls the next upgrade costs EV 19,200c, then 96,000c. A Rusted drone (50% of pulls) is 8.2 dps = 6.5% of a bare pistol and never scales with waves. `MainMenu.gd:1541`, `Coworkers.gd:107-118`.

**F2. Basement / Cryptid wave-scaled crate ladder is unreachable.** `BasementLogic.gd:35-51` promises Titan @wave 15, Apex @20, Apocalypse @25, but `Basement.gd:83` blocks doors for run_time 340–620s (waves 13–21) and the 2-door cap (`GameConfig.gd:671`, consumed at spawn `Basement.gd:124`) is gone by wave 12 in 76% of runs. Sim: ≤2.8% of basement crates are Titan and 0% Apex/Apoc for any run ending ≤ wave 20; only a player who *declines the extraction win* and survives to wave 26 sees 0.08–0.26 Apex/Apoc per run. `BASEMENT_CRATE_FLOOR_MAX := 7` (`GameConfig.gd:683`) is effectively never exercised.

**F3. Four of eleven crates are strictly dominated, plus the default one.** Themed crates (500/650c, floor 2): for any target ≥Lethal, even for a *specific base*, Munitions/50-50/Titan are 3–6× cheaper (specific base ≥Savage: themed 180,000c vs 50/50 29,400c; ≥Lethal: 36,000c vs Munitions 12,600c). Only niche: specific base at Hardened, 9,000c vs Scrap Crate 9,450c — a wash. Worst scrap-back in the store (10–13%). Footlocker (150c) has the same odds as Scrap Crate (75c) through Lethal (3.33% vs 4.17% Lethal) and its only extra is a 1/120 Savage+, which 50/50 sells at 1/2. `Crates.gd:9-62`.

**F4. GOLDEN TICKET / OVER THE RAINBOW badges gate the wall behind 290 / 2,600 runs and pay trivia.** Armageddon = 72 Apoc crates = 2.16M coins ≈ 2,587 TYPICAL runs (517 days at 5/day), 775 SKILLED; reward = one Titan Crate (2,500c, 0.1% of spend) + 500 rank XP that is worthless because rank maxes at run 150. OVER THE RAINBOW (~287 runs / ~240k coins) is tiered MED → a 600c Munitions Cache. The rarity odds are Larry's call; the issue is the 17/18 wall and reward/feat mismatch. `Commendations.gd:58-61`, `GameConfig.gd:660-665`.

**F5. Rank ladder: 73% of the XP unlocks nothing.** Ranks 6, 8, 9, 10 grant no mode/location (`Ranks.gd:11-15`, `GameConfig.gd:604-607, 728-729`). Last functional unlock = rank 7 at 20,000 XP (TYPICAL run 40); ranks 8–10 = 55,000 XP = 110 more TYPICAL runs for three name changes. For SKILLED the whole ladder ends at run 33 (~17 with HARDCORE ×3 coins).

**F6. Benefit rungs below the perception threshold, and one that rounds to zero.** COMFY SHOES +2% (4.4 px/s), STRETCH BREAKS −0.06 s, INSURANCE +4 HP (<½ bite), NIGHT SCHOOL +3% (0 extra level-ups per run until L5), REGISTER SKIM +2% (+10c on a 500c run — one fifth of SIGNING BONUS's +50c at the identical price, `GameConfig.gd:617,620`). PACK RAT L1 is exactly ×1.000 on Rusted and Salvaged guns (83% of floor-1 drops) and L2 still ×1.000 on Rusted because of `roundi(maxi(1, payout/10) * mult)` at `Inventory.gd:109`. L5 of every track costs 700 (56% of the track) for the same increment as the 25-scrap L1. Full ladder 9,840 scrap ≈ 260 TYPICAL runs scrapping everything. Dominant: UNION REP, SECOND OPINION, SIGNING BONUS.

**F7. Weapon XP is a dead reward on most guns.** Rusted/Salvaged (83% of floor-1 drops, and all three starters, `Inventory.gd:238-257`) have 0 talent slots (`Rarity.gd:23-24`), and level gates nothing else (`WeaponInstance.gd:65-71`), so every XP point they earn does nothing. There is no level cap and no effect past the last unlock (≤Lv28) (`WeaponInstance.gd:211`). Fusion XP from junk dupes is 30/60 XP (5–11% of one TYPICAL run) and needs a same-base match (1/21) (`Inventory.gd:206`); the reroll rider on a Merciless target costs ~630,000c per single-stat reroll (`Inventory.gd:212`).

**F8. 10-game milestone reward is imperceptible.** 90% chance the payoff is sub-Lethal, 39% Rusted; EV ≈ 77 coins per 10 runs (1.5% of those runs' income). `Rewards.gd:16-20`.

**F9. Streak day-3 "tier up" is not visible and lowers mid-tier odds.** Junk crate 51.0% → 47.1%, ≥Lethal 15.9% → 16.3%; Munitions 5.10% → 4.41% and Titan 1.91% → 1.47% go *down* (`Rewards.gd:59-78`). All of the streak's value sits in the day-7 floor (≥Lethal 16% → 94%), and one missed day resets it to 1 (`Rewards.gd:106`). Comment drift: `Rewards.gd:61` lists 50/50 (700c) and implies Specials (650c) in the ≤500 tier; both actually sit in the ≤1000 weight-8 tier with Munitions.

**F10. Challenge rewards are inverted against effort.** Menu actions "Open 3 crates" (225c of Scrap Crates) and "Fuse 2 weapons" pay a Titan (2,500c); "Defeat 3 bosses" pays a Munitions (600c); "Kill 60" pays a Scrap Crate. `Challenges.gd:34-50`. Challenge crates ≈ 75% of a TYPICAL player's daily coin income in list value, so this table — not the store — is the real mid-tier loot faucet.

**F11. Inventory cap 120 with no bulk scrap.** `Inventory.gd:13`; inflow ≈ 7–9 guns/day TYPICAL (4 basement Munitions + 2 challenge + 1 daily + purchases), ~80% of cheap-crate results are r1–2 junk. Each scrap is 3 taps (tile → SCRAP → YES, `WeaponDetailPopup.gd:322-367`); when full, crate opening is refused (`CrateOpener.gd:102`, `Inventory.gd:136`) and the reward-claim flow dead-ends on "Inventory full — scrap a weapon first" (`MainMenu.gd:1690-1696`). Nothing is lost (crates bank; milestone guns convert to a crate, `MainMenu.gd:1650-1654`), but the reveal moment is blocked.

**F12. Tiers 1–3 are obsolete from run 1.** Median DPS mult Rusted ×1.10 / Salvaged ×1.13 / Hardened ×1.23 (`Affixes.gd:37-44`; `r2_longshot` line 41 can roll zero DPS stats → ×1.00). The first basement clear hands out a guaranteed Lethal (×1.8 median) on run 1, so Scrap Crate/Footlocker results (96% ≤Hardened) are scrap fodder immediately — which also makes the EASY commendation tier (Scrap Crate, `GameConfig.gd:663`) and two challenge rewards non-rewards.

**F13. Config hygiene (grep-verified).** Of 641 GameConfig consts only `DEBUFF_SLOW_DURATION` (`GameConfig.gd:213`) has zero readers anywhere in `.gd/.tscn/.tres`. Affix `min_talents`/`max_talents` fields are never read (documented legacy, `Affixes.gd:20-22`). Every `Benefits.*` getter and every meta const (RANK_*, BENEFIT_*, COMMENDATION_*, CHALLENGE_*, COWORKER_*, BASEMENT_*, DAILY_STREAK_*) is read. No relic meta-progression exists to audit.

### Modelling caveats
- Run profiles are assumptions (kills bounded by the spawn ceiling above); scale "runs" linearly if the coin analyst's income numbers differ.
- Basement enter/clear (70%/70%) and Cryptid kill (35%) rates are guesses; the ceiling column in §1.5 bounds them.
- "all-in" rows spend 100% of coins on one crate type and ignore scrap-back and character/STAFF FILE purchases.

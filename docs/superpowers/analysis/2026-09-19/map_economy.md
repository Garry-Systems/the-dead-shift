# The Dead Shift v0.1.72 — COIN ECONOMY MAP (faucets, sinks, multipliers, flags)

Read-only analysis. Repo: `/mnt/c/Users/thela/Documents/mobile-game/`. All paths below are relative to `scripts/`.
Models: `scratchpad/econ3.py` (income), `scratchpad/sinks.py` (sinks). All arithmetic done in python.

---------------------------------------------------------------------------------------------------

## 0. Structural facts (needed to read everything else)

- **Two currencies.** COINS (wallet, `SaveManager.coins`, no cap — `SaveManager.gd:139-149`) and SCRAP (`SaveManager.gd:151-162`). SCRAP's ONLY faucet is deconstructing a weapon/coworker: `max(1, coin_payout/10) x PACK RAT` (`loot/Inventory.gd:109-110`, `MainMenu.gd:935`). SCRAP's ONLY sink is the Benefits ladder (`logic/Benefits.gd:40-47`).
- **Run coins are virtual until the run ends.** Nothing is banked mid-run. The pay-stub formula (`logic/CoinReward.gd:6-10, 51-89`):

```
pre_mult  = COIN_BASE 10 + 5*wave + 25*bosses + 1*kills + bonus_coins          (GameConfig.gd:187-190)
net       = max(0, pre_mult - snacks_spent)                                      (truck spends, pre-mult)
total     = round(net * RunStats.coin_mult) + vested_signing(bonus, run_time)   (signing: linear over 120s)
if company_card: total -= 25%                                                    (CoinReward.gd:87-88)
WIN (extraction):   total = round(total * 1.5)                                   (GameOver.gd:172-173)
QUIT/RESTART:       total = int(total * 0.75)                                    (PauseMenu.gd:284)
```
- `rank_xp += total` on every exit path (`GameOver.gd:195`, `PauseMenu.gd:290`) — so every coin multiplier is also a rank multiplier.
- **Clock.** wave = floor(t/30)+1. Dawn = 480 s (wave 17). Final surge 480-570 s, chopper 570-590 s => an extraction win lands at ~t=575 s, wave 20, 3 bosses dead (w5/w10/w15; the w20 boss spawns as the chopper lands).
- Spawn rate: `1/max(0.92^(w-1), 0.25)` per second => 1.0/s (w1), 1.4 (w5), 2.1 (w10), 3.2 (w15), 3.8 (w17), **4.0 floor from w18 on**; halved while a revealed boss lives (`Spawner.gd:40-42`). HORDE = x2 spawns, no bosses, no dawn.
- Elite chance: 0 before w6, then 0.05+0.005w capped 0.15 (w20); x2 during the final surge (`DifficultyCurve.gd:33-36`, `Extraction.gd:53`).

---------------------------------------------------------------------------------------------------

## 1. FAUCETS

### 1a. Every coin source

| # | Source | Formula | Where | Goes through coin_mult? |
|---|---|---|---|---|
| F1 | Base pay | 10 flat | `CoinReward.gd:7`, `GameConfig.gd:187` | yes |
| F2 | Wave pay | 5 x wave reached | `CoinReward.gd:8` | yes |
| F3 | Boss pay | 25 x bosses killed | `CoinReward.gd:9`, `BossBase.gd:247` | yes |
| F4 | Kill pay | 1 x trash kills | `CoinReward.gd:10`, `Enemy.gd:611` | yes |
| F5 | Elite bonus | +5 per elite kill (on top of F4) | `Enemy.gd:615-616`, `GameConfig.gd:516` | yes (bonus_coins) |
| F6 | Crates / shelves | +3 per directly-shot crate or shelf; chain-fused shelves pay 0 | `Destructible.gd:316-318`, `GameConfig.gd:279` | yes |
| F7 | spare_parts relic | 10% chance of an extra +3 per crate/shelf | `RelicEffects.gd:381-382` | yes |
| F8 | Dawn bonus | +250 once at t=480 s (endless only) | `Hud.gd:242-244`, `GameConfig.gd:356` | yes |
| F9 | Blood Moon | +1/kill while active (30 s) AND spawns x2 | `Enemy.gd:629-631`, `NightEvents.gd:110-116` | yes |
| F10 | Janitor passive | +1/kill always | `Enemy.gd:613-614`, `Main.gd:67`, `GameConfig.gd:176` | yes |
| F11 | PAYDAY (Alstar JACKPOT) | +2/kill for 10 s; 1-in-4 roll on a 60 s CD => 4.2% uptime => +0.083/kill avg | `AbilityController.gd:215-226, 267` | yes |
| F12 | CLOSING TIME (Janitor) | +2/kill inside a 270 px zone for 8 s per 45 s (17.8% uptime) | `AbilityController.gd:224-225, 335` | yes |
| F13 | Cryptid bounty | +250 and a crate (`crate_id_for(wave)`) | `Cryptid.gd:124-125` | coins yes |
| F14 | Relic SKIP / dry pool / SCRAP | +100 skip, +150 dry, +100 scrap (cursed +25) | `ui/RelicChoice.gd:111,196`, `RelicBar.gd:136-144` | yes |
| F15 | Signing bonus | 50 x level (max 250), vests linearly over 120 s of run_time, added POST-mult | `CoinReward.gd:17-18, 61`, `Main.gd:44` | NO (but x0.75 quit, x1.5 win, -25% card) |
| F16 | Extraction win | whole total x1.5 | `GameOver.gd:172-173` | post |
| F17 | Weapon deconstruct | uniform in rarity band: 10-20 / 20-40 / 60-120 / 120-240 / 300-600 / 800-1500 / 2000-4000 / 5000-10000 / 12000-25000 | `loot/Inventory.gd:97-106`, `loot/Rarity.gd:23-31` | n/a (menu) |
| F18 | Coworker deconstruct | half the weapon band, floor 5 | `logic/Coworkers.gd:129-143`, `MainMenu.gd:926-936` | n/a |
| F19 | Fresh-save float | top up to 150 once | `loot/Inventory.gd:255-256` | n/a |

**In-kind faucets (crates, never coins — but crates are the main coin SINK, so they are coin-equivalent):**

| Source | Reward | Store-price value | Where |
|---|---|---|---|
| Basement gauntlet (max 2/run, 25%/wave edge from w3) | munitions (w3-14), titan (w15-19), apex (w20-24), apocalypse crate (w25+) | 600 / 2,500 / 9,000 / **30,000** | `logic/BasementLogic.gd:35-51`, `Basement.gd:268` |
| Cryptid | same table | same | `Cryptid.gd:125` |
| Daily login | weighted crate; streak>=3 shifts a tier, >=7 floors at munitions | EV 606 / 926 / 1,190 | `loot/Rewards.gd:29-92` |
| Daily challenges (3 of 12 per day) | scrap x2, 50/50 x5, munitions x2, titan x2, **apex x1** | mean 1,571 each = ~4,700/day if all done | `logic/Challenges.gd:34-57` |
| Every-10-games milestone | 50% random crate / 50% floor-1 gun | ~378 per 10 games | `loot/Rewards.gd:16-20` |
| Commendations (18, one-time) | 5 scrap + 10 munitions + 3 titan | 13,875 total | `logic/Commendations.gd` |

### 1b. Kill-rate assumptions (stated)

Kills are spawn-limited early and DPS-limited late. Model: kills/s = min(spawn backlog, DPS / avg enemy HP), enemy HP = 50 x 1.12^(w-1) x 1.34 slate mix, elites 2.5x HP, 65% of DPS goes into a live boss, un-killed backlog decays with a 60 s half-life-ish leak, player DPS grows 7%/wave from level-up cards. Three profiles by base effective DPS: **STARTER 150**, **MID 400**, **GEARED 1200**. Expected Blood Moon (5.5%/wave from w5) is blended in. Crate income assumed 1.5 paying destructibles/min forecourt, 3.3/min Big Mart (55% of Big Mart's obstacle picks are crate/shelf vs 25% in forecourt — `logic/Locations.gd:54`, `logic/Obstacles.gd:66,82`; a shelf formation chain-collapses so only the shot shelf pays — `Destructible.gd:308-318`).

### 1c. Expected coins per run (paid; N = normal x1, HC = HARDCORE x3, no benefits, no relic mults)

| Location | Profile | 5-min death (pre / N / HC) | 10-min death, chopper skipped (pre / N / HC) | Extraction win 9:35 (pre / N / HC) |
|---|---|---|---|---|
| FORECOURT | STARTER | 626 / 626 / 1,879 | 1,473 / 1,473 / 4,418 | 1,421 / 2,132 / 6,393 |
| FORECOURT | MID | 742 / 742 / 2,226 | 2,397 / 2,397 / 7,191 | 2,274 / **3,411** / 10,233 |
| FORECOURT | GEARED | 742 / 742 / 2,226 | 3,068 / 3,068 / 9,205 | 2,860 / 4,290 / 12,872 |
| BIG MART | STARTER | 653 / 653 / 1,960 | 1,527 / 1,527 / 4,580 | 1,473 / 2,210 / 6,627 |
| BIG MART | MID | 769 / 769 / 2,307 | 2,451 / 2,451 / 7,353 | 2,326 / 3,489 / 10,466 |
| BIG MART | GEARED | 769 / 769 / 2,307 | 3,122 / 3,122 / 9,367 | 2,912 / 4,368 / 13,104 |

Composition of a MID extraction (pre-mult 2,274): kills 1,090 (48%), elite bonus 625 (27%), dawn 250 (11%), base+waves 110 (5%), blood moon 81 (4%), bosses 75 (3%), crates 43 (2%).
With maxed benefits (REGISTER SKIM x1.10 + SIGNING 250): MID extraction N = (2,274x1.1+250)x1.5 = 4,127; HC = (2,274x3.3+250)x1.5 = 11,631.
Janitor (+1/kill, + CLOSING TIME ~+0.18/kill): MID extraction pre 2,274 -> ~3,560 (**+57%**). No other character touches coins.
HORDE 10 min: MID 2,524, GEARED 4,311 (no bosses, no dawn, no x1.5). OVERTIME (starts t=240, wave 9): MID extraction after only 5:35 of play = 2,720 paid => 487 coins/min vs 356/min for a normal full shift (**+37% coins/min**).

Big Mart vs forecourt: **+2 to +4%**. Shelves are economically invisible (3 coins each vs ~250-490 coins/min from kills).

### 1d. Income shape over run time (marginal pre-mult coins/min, dawn lump excluded)

| t (min) | 1 | 3 | 5 | 8 | 10 | 15 | 20 |
|---|---|---|---|---|---|---|---|
| STARTER | 83 | 156 | 141 | 112 (+250 lump) | 106 | 70 | 51 |
| MID | 83 | 167 | 248 | 283 (+250) | 252 | 158 | 107 |
| GEARED | 83 | 167 | 248 | **490** (+250) | 470 | 416 | 278 |
| spawn-limited ceiling (k=1) | 83 | 167 | 212 | 490 | 392 | 392 | 392 |

Shape: **accelerating (roughly 3x-6x) from minute 1 to minute 8-10**, because spawn rate quadruples (1->4/s) AND elite chance ramps (0->15%, x2 in the surge) and each elite is worth 6 coins. From wave 18 the spawn floor makes the ceiling **flat at ~390-420 coins/min**; real income then **decays** as enemy HP (x1.12/wave) outruns DPS. Income is never runaway-exponential; it is heavily back-loaded:
- first 5 min = 742 of a 3,411 MID extraction payout (**22%**);
- the 90 s final surge alone = 19% (MID) to 32% (GEARED) of full-run pre-mult income, 30-40% with the dawn lump;
- after the chopper, staying is a bad coin trade: GEARED 9:35 win = 4,290 (448/min) vs 15-min death = 5,403 (360/min) vs 20-min = 6,824 (341/min). The x1.5 is forfeited forever once the chopper leaves.

---------------------------------------------------------------------------------------------------

## 2. SINKS

### 2a. Coin sinks

| Sink | Price | Scaling | Cost to "max" | Where |
|---|---|---|---|---|
| Characters | Bob 400, Jimbo 600, Alstar 2,400, Janitor 2,800, Delivery Girl 3,200, Jackson 3,600 | flat, one-time | **13,000 total** — the ONLY deterministic coin sink in the game | `logic/Characters.gd:15-45`, `MainMenu.gd:1499-1506` |
| Crates (11) | 75 / 150 / 500 x3 / 600 / 650 / 700 / 2,500 / 9,000 / 30,000 | flat, infinite gacha | see 2b | `loot/Crates.gd:6-63`, `loot/Inventory.gd:120-130` |
| STAFF FILE (coworker pull) | 800 | flat, infinite gacha, rarity floor 1 | see 2c | `GameConfig.gd:692`, `MainMenu.gd:1534-1548` |
| Ice cream truck (run coins, pre-mult) | HEAL 150, REROLL 200, RELIC 400; 3 purchases per visit | flat | max 1,200/visit | `GameConfig.gd:856-860`, `ui/TruckShop.gd:142-184` |
| Location unlocks | **0 coins** — rank-gated only (Big Mart rank 2 = 500 XP, Garage rank 4 = 3,500 XP) | — | — | `GameConfig.gd:728-729`, `logic/Locations.gd:81-85` |
| Modes | 0 coins — HORDE rank 3, OVERTIME rank 5 (7,000), HARDCORE rank 7 (20,000) | — | — | `GameConfig.gd:604-607` |
| Permanent coin upgrades | **none exist.** `logic/Upgrades.gd` is the in-run level-up card catalog, not a store ladder | — | — | — |

### 2b. Crates — rarity odds, refund EV, expected cost to a tier

Rarity ladder climb chance from tier i to i+1 = 1/(i+1) (`loot/Rarity.gd:93-102`) => P(>=r | floor f) = f!/r!.

| Crate | Price | EV coins back (deconstruct) | Refund | EV SCRAP | P(>=5 Savage) | P(>=6) | P(>=7) | P(>=8) | P(9) |
|---|---|---|---|---|---|---|---|---|---|
| scrap_crate | 75 | 36 | 48% | 3.2 | 0 | 0 | 0 | 0 | 0 |
| footlocker | 150 | 40 | 27% | 3.6 | 0.83% | 0.14% | 0.020% | 0.0025% | 1/362,880 |
| gun-pool x3 | 500 | 65 | 13% | 6.1 | 1.67% | 0.28% | 0.040% | — | — |
| specials_case | 650 | 65 | **10%** | 6.1 | 1.67% | 0.28% | 0.040% | — | — |
| munitions_cache | 600 | 270 | 45% | 26.5 | 20% | 3.3% | 0.48% | 0.06% | 0.0066% |
| fiftyfifty | 700 | 233 | 33% | 22.8 | 50% | 0 | 0 | 0 | 0 |
| titan_crate | 2,500 | 628 | 25% | 62 | 100% | 16.7% | 2.4% | 0.30% | 0.033% |
| apex_crate | 9,000 | 1,517 | 17% | 151 | 100% | 100% | 14.3% | 1.8% | 0.20% |
| apocalypse_crate | 30,000 | 3,715 | 12% | 371 | 100% | 100% | 100% | 12.5% | 1.39% |

No crate has refund >= 100%, so **there is no buy->deconstruct coin loop.**

Expected gross coins to the first drop of a tier (cheapest route):
- Savage (purple, "epic"): **1,400** via 50/50 (titan 2,500; munitions 3,000)
- Carnage (red): **9,000** via apex (titan 15,000; munitions 18,000)
- Merciless (orange, "legendary"): **30,000** via apocalypse crate (apex 63,000)
- Apocalypse tier: **240,000** (apocalypse crate x8)
- Armageddon: **2,160,000** (apocalypse crate x72)

### 2c. Coworkers (STAFF FILE, 800 coins)

Same floor-1 ladder as a 150-coin Footlocker, at 5.3x the price, with a 2.5% refund (EV 20 coins back).
- P(trait) = P(rarity>=4) = **1/24 = 4.17%** (the comment at `GameConfig.gd:693` says "~15% of pulls" — wrong by 3.6x).
- one of each type (cat/drone/mannequin): 5.5 pulls = 4,400 coins
- any trait-bearing coworker: 24 pulls = **19,200 coins**
- a specific type+trait (e.g. drone+SHARP): 504 pulls = **403,200 coins**
- all 17 type x trait combos: 1,526 pulls = **1,220,586 coins**
- rarity >=5 coworker (stat_mult 1.72): 120 pulls = 96,000; >=6: 576,000; >=7: 4,032,000.

### 2d. SCRAP sink — the Benefits ladder

Costs 25/60/140/320/700 per level (`GameConfig.gd:610-611`): 1,245 per 5-cap track x 7 = 8,715; SECOND OPINION (cap 3) 225; UNION REP 900. **Total 9,840 SCRAP.** Since SCRAP = deconstruct coins/10, that is ~98,400 coins of deconstruct payouts. Bought purely with coins via the most scrap-efficient crate (scrap_crate, 12.1 net coins per scrap): ~119,000 net coins (79,000 with PACK RAT maxed early). In practice free crates carry it: a 3-run/day player deconstructing everything gets ~200 scrap/day => ~49 days to max, UNION REP alone ~4-5 days. After 9,840 SCRAP there is nothing to buy: terminal/dead currency.

### 2e. Truck snacks

HEAL 150 (30% max HP, disabled in HARDCORE), REROLL 200, RELIC 400 — paid from the run's pre-mult subtotal (`RunStats.gd:116-121`). Because the spend is deducted BEFORE coin_mult and the x1.5 win bonus, the **real** price is `cost x coin_mult x (1.5 if win)`: a 400 relic costs 400-600 final coins in normal, **1,320-1,980 in HARDCORE+skim**, up to ~3,000+ with company_card.

---------------------------------------------------------------------------------------------------

## 3. RUNS-TO-AFFORD

Reference incomes: NEW = 700/run (5-min death), MID = 2,400 (10-min death), MID-win = 3,400 (extraction), HC-geared = 10,000 (HARDCORE extraction).

| Item | Cost | NEW 700 | MID 2,400 | MID-win 3,400 | HC 10,000 |
|---|---|---|---|---|---|
| Zombie Bob | 400 | 0.6 runs | 0.2 | 0.1 | 0.0 |
| Jimbo | 600 | 0.9 | 0.2 | 0.2 | 0.1 |
| STAFF FILE pull | 800 | 1.1 | 0.3 | 0.2 | 0.1 |
| Alstar | 2,400 | 3.4 | 1.0 | 0.7 | 0.2 |
| Titan crate | 2,500 | 3.6 | 1.0 | 0.7 | 0.2 |
| Janitor | 2,800 | 4.0 | 1.2 | 0.8 | 0.3 |
| Delivery Girl | 3,200 | 4.6 | 1.3 | 0.9 | 0.3 |
| Jackson | 3,600 | 5.1 | 1.5 | 1.1 | 0.4 |
| Apex crate | 9,000 | 12.9 (1.1 h) | 3.8 (0.6 h) | 2.6 | 0.9 |
| **ALL 6 characters** | 13,000 | **18.6 runs (1.5 h)** | **5.4 runs (0.9 h)** | 3.8 | 1.3 |
| any-trait coworker (E) | 19,200 | 27 (2.3 h) | 8.0 (1.3 h) | 5.6 | 1.9 |
| Apocalypse crate = first Merciless | 30,000 | 43 (3.6 h) | 12.5 (2.1 h) | 8.8 (1.4 h) | 3.0 (0.5 h) |
| Benefits max, coin-only route (net) | ~119,000 | 170 (14 h) | 50 (8.3 h) | 35 (5.6 h) | 12 (1.9 h) |
| first Apocalypse-tier gun (E) | 240,000 | 343 (29 h) | 100 (17 h) | 71 (11 h) | 24 (3.8 h) |
| specific coworker type+trait (E) | 403,200 | 576 (48 h) | 168 (28 h) | 119 (19 h) | 40 (6.5 h) |
| all 17 coworker combos (E) | 1,220,586 | 1,744 (145 h) | 509 (85 h) | 359 (57 h) | 122 (19.5 h) |
| first Armageddon (E) | 2,160,000 | 3,086 (257 h) | 900 (150 h) | 635 (102 h) | 216 (35 h) |

Where things stall / run dry:
- **Deterministic sinks run out at 13,000 coins** — ~1-1.5 hours of play. After that every coin is a gacha ticket (crates or STAFF FILE). There is no coin-priced permanent ladder: the meta ladder (Benefits) is SCRAP-priced, locations/modes are rank-priced.
- Coins never have literally "nothing to buy" (gacha is infinite), but there is no wall either until Apocalypse-tier (240k) — and that wall is softened to irrelevance by free crates (section 1a in-kind table): one "win an extraction" challenge day pays an apex crate (9,000) = 2.6-3.8 runs of coins; one post-dawn basement pays 9,000-30,000.
- Rank pacing is mis-calibrated: the comment at `GameConfig.gd:602-603` assumes "~500-900 coins/run ... rank 7 ~30 runs, rank 10 the long chase". Actual full-shift payouts are 2,100-4,300 (HC 6,400-12,900). Rank 7 (20,000 XP, HARDCORE unlock) = ~6-8 MID full runs; rank 10 (75,000) = ~22 MID extraction wins, or **~7 HARDCORE extractions** once HC is open.

---------------------------------------------------------------------------------------------------

## 4. MULTIPLIER AUDIT

All run multipliers live in ONE accumulator, `RunStats.coin_mult`, and **all stack multiplicatively**:

| Multiplier | Value | Where | Notes |
|---|---|---|---|
| HARDCORE | x3.0 | `Main.gd:36-37`, `GameConfig.gd:625` | run start |
| REGISTER SKIM (benefit) | x1.02-1.10 | `Main.gd:40`, `Benefits.gd:68-69` | permanent |
| Silver Tongue card | x1.20 per pick, **no cap** | `logic/UpgradeApply.gd:24-25`, `RunStats.gd:83-84` | offered on odd levels, 3 of 12 cards (3 of 10 in HC) => ~25-30%/offer, ~20 odd levels in a full run => ~5-6 offers before rerolls |
| tip_jar relic | x1.15 | `logic/Relics.gd:221-223` | retroactive (applies to whole run at payout) |
| company_card relic | x2.0, then -25% of final => **net x1.5** | `RelicEffects.gd:141`, `CoinReward.gd:87-88` | retroactive; offered in HARDCORE too (only dead_mans_vest is HC-excluded, `Relics.gd:100`) |
| Extraction win | x1.5 on final total | `GameOver.gd:172-173` | post |
| Quit/restart | x0.75 | `PauseMenu.gd:284` | post |
| Additive per-kill (pre-mult, so they are multiplied by all of the above) | elite +5, Janitor +1, Blood Moon +1, PAYDAY +2, CLOSING TIME +2 | `Enemy.gd:613-636` | all stack additively with each other |
| Location | none | — | Big Mart only changes crate density (+2-4%) |
| Daily streak | none on coins | — | crate tier only |
| cursed_nametag | elite chance x1.5 (=> up to 22.5%, 45% in surge) | `DifficultyManager.gd:73-74` | indirect: ~+50% elite coin income |

Max stack (no Silver Tongue): 3 x 1.10 x 1.15 x 2.0 = **x7.59** in-accumulator; x0.75 clawback x1.5 win => **x8.54 effective**. Each Silver Tongue multiplies by another 1.2: 3 picks => x14.8, 6 picks => **x25.5 effective**.

Coins/run at max (GEARED extraction, pre-mult 2,860, signing 250):
- HC + skim + tip_jar + company_card, 0 Silver Tongue: (2,860 x 7.59 + 250) x 0.75 x 1.5 = **~24,700**
- + 2 Silver Tongue: ~35,500; + 6 Silver Tongue: **~73,000**
- Same with the Janitor (pre ~4,300): ~36,900 / ~110,000.
One such run = 1-3 Apocalypse crates. Baseline normal GEARED extraction is 4,290, so the realistic stacked ceiling is ~6-8x baseline, theoretical ~17-25x.

Farm vectors checked:
- **Instant restart loop — STILL PAYS (see FLAG 2).** The v0.1.72 gate (`PauseMenu.gd:305`) only withholds `games_played`; coins and rank XP are granted unconditionally at `PauseMenu.gd:284-290`. Normal: int(15 x 0.75) = 11 coins/loop; HARDCORE: 33/loop (40 with skim).
- **OVERTIME instant quit — bypasses BOTH hygiene gates (see FLAG 1).** `Main.gd:24-26` presets `run_time = 240`, so `vested_signing(250, 240)` = full 250 at second zero and `run_time >= 120` counts the abandon as a played game.
- Pause / level-up / truck overlays: coin windows (PAYDAY, CLOSING TIME) and Blood Moon are game-time countdowns (`AbilityController.gd:60-64`, `NightEvents.gd:34`) — pause-safe. No leak found.
- Truck arbitrage: buy relic 400 -> SCRAP 100 = -300; SKIP pays the same 100 as scrap (`GameConfig.gd:97-98`). No arb.
- Crate buy->deconstruct: best refund 48%. No loop.
- company_card / tip_jar are retroactive (the mult is applied to the whole subtotal at payout), so they can be taken at the last boss for full value; scrapping the card before the end removes both the x2 and the clawback. Not a farm, but the card has no real cost: net x1.5, always positive.
- Signing bonus in normal modes: properly vested (0 at t=0, 250 at 120 s).
- Device-clock rollover: `SaveManager.today_string()` (`SaveManager.gd:176-177`) drives daily crate, streak, and the 3-challenge rotation — changing the device date re-arms all three (apex/titan crates). Standard offline-game exposure.

---------------------------------------------------------------------------------------------------

## 5. ICE CREAM TRUCK

Arrival window: visitor rolls at wave edges t=90..330 s (20%/edge, 90 s cooldown, max 2 visitors, dawn lockout |t-480|<140 — `Visitors.gd:79`, `logic/VisitorsLogic.gd:23-38`) and again from t=630. The truck shows up pre-dawn in **~40% of runs** that reach 5:30.

Pocket (spendable pre-mult subtotal) when it can arrive:

| t (s) | 90 | 120 | 150 | 180 | 210 | 240 | 270 | 300 | 330 |
|---|---|---|---|---|---|---|---|---|---|
| STARTER | 135 | 181 | 252 | 331 | 407 | 481 | 553 | 626 | 693 |
| MID/GEARED | 135 | 181 | 253 | 333 | 420 | 515 | 620 | 742 | 868 |

Arrival-weighted expected pocket: **~380-425 coins**.
- HEAL 150: **out of reach at the most likely arrival (t=90: 135 < 150)**, affordable from t=120.
- REROLL 200: from t~130. RELIC 400: from t~205; "one of each" (750) only from t~300.
- Verdict: prices are in the right band for NORMAL mode (one item = 35-100% of pocket, ~7-18% of a full-run subtotal) — meaningful, not trivial. Early arrivals are a dead visit. In HARDCORE the visit is near-worthless: HEAL is disabled and the other two cost 660 / 1,320 real coins (x1.5 more on a win).
- **The player cannot see their balance**: neither `Hud.gd` nor `ui/TruckShop.gd` renders run coins; unaffordable buttons stay enabled and just "deny on tap" (`ui/TruckShop.gd:120-125`). The game's first mid-run spend has no visible wallet.

---------------------------------------------------------------------------------------------------

## 6. FLAGS (ranked, most severe first)

**1. OVERTIME instant pause-quit farm — defeats both v0.1.72 hygiene gates.**
`Main.gd:24-26` sets `DifficultyManager.run_time = 240` at scene load. Consequences at second zero: (a) `CoinReward.vested_signing(250, 240)` = 250, fully vested (`CoinReward.gd:17-18`, `GameConfig.gd:618`); (b) `run_time >= ABANDON_COUNTS_MIN_TIME` (120) so the abandon counts as a played game (`PauseMenu.gd:305`, `GameConfig.gd:192`); (c) wave pay is already 10+5x9 = 55. Payout per loop: int((round(55x1.1)+250) x 0.75) = **233 coins + 233 rank XP** with maxed SIGNING/SKIM, 41 with no benefits. Loop = 8 headstart level-up taps + pause + restart, ~12 s => **~1,200 coins/min, zero risk, vs 356/min for a legit MID full shift (3.3x)**, plus a free milestone crate/gun every 10 loops (~2 min) and the games-played commendations (CAREER CLERK = 100 "shifts"). The team already special-cased OVERTIME for challenges/records (`PauseMenu.gd:314-320`) but not for these two.

**2. Instant restart still pays coins + rank XP in every mode.** `PauseMenu.gd:284-290` has no minimum-time guard; only `games_played` got one. Base 10 + wave-1 5 = 15 => 11 coins/loop normal, 33-40 in HARDCORE. At a ~4-6 s pause->restart loop (no confirm dialog — `PauseMenu.gd:345-348`) that is ~110-165 coins/min normal — **equal to a STARTER's real income (117-142/min)** — and ~400-600/min in HARDCORE, above a MID player's legit normal income.

**3. In-kind crate faucets dwarf coin income; basement/cryptid crate scaling is off the chart.** `BasementLogic.crate_floor` = 2 + wave/5 (`logic/BasementLogic.gd:35-51`): wave 20-24 => apex crate (9,000), wave 25+ => apocalypse crate (**30,000 = a guaranteed Merciless = 8.8-12.5 MID runs of coins**) from one 60 s gauntlet. An entire 12-minute run to wave 25 pays only ~3,000-4,500 coins. OVERTIME makes it reachable in 8 minutes of play with >=84% odds a door is still unspent (only 3 pre-lockout wave edges). Also: daily challenge "Win an extraction" => apex crate 9,000; "Open 3 crates" => titan 2,500 for 225 coins of scrap crates (`logic/Challenges.gd:46-51`). A 3-run/day player gets ~2,000-7,000 coin-equivalent/day in free crates vs ~7,000 coins earned; crates are the main coin sink, so the coin price list for crates is largely bypassed.

**4. Deterministic coin sinks are exhausted in ~1-1.5 hours; rank pacing assumes the wrong income.** 13,000 coins buys every character (5.4 MID runs). No coin-priced permanent ladder exists (Benefits = SCRAP, locations/modes = rank). `GameConfig.gd:602-603` calibrates ranks to "500-900 coins/run"; real full-shift payouts are 2,100-4,300 and HC 6,400-12,900, so rank 7 lands in ~6-8 full runs (not ~30) and rank 10 "the long chase" is ~7 HARDCORE extractions.

**5. Multiplier stack is fully multiplicative and Silver Tongue is uncapped.** x3 x 1.10 x 1.15 x 2.0 = x7.59, x8.54 effective after clawback + win; every Silver Tongue is another x1.2 with no cap (`RunStats.gd:83-84`). One stacked GEARED HC extraction pays ~24,700 (0 ST) to ~73,000 (6 ST) vs 4,290 baseline — a single run buys 1-3 Apocalypse crates. Rank XP inherits all of it (`GameOver.gd:195`).

**6. Income is heavily back-loaded; elites and the final surge carry the run.** `ELITE_COIN_BONUS = 5` makes an elite worth 6 trash kills; at the 15% cap that is +0.75 coins/spawn, 27% of a MID extraction's subtotal. The 90 s surge (elite chance x2 => 27-29%) is 19-32% of full-run income (30-40% with the 250 dawn lump). First 5 minutes = 22% of an extraction payout: a 5-min death pays 742, surviving 4.5 more minutes pays 3,411 (4.6x). Marginal coins/min: 83 -> 248 -> 490 (GEARED). Note the surge's "forced spawn floor" is a no-op: wave-17 interval is already 0.263 s vs the 0.25 floor (+5%); only the elite x2 matters (`Extraction.gd:52-53`).

**7. The Janitor is the only coin character and he is worth +57%.** +1/kill doubles the largest term (`GameConfig.gd:176`); with CLOSING TIME a MID extraction goes 2,274 -> ~3,560 pre-mult. 2,800 coins, pays back in ~2 full runs, then strictly dominant for farming. PAYDAY by comparison is +0.083/kill (~+4%).

**8. STAFF FILE is the worst-value sink and its odds comment is wrong.** 800 coins for a floor-1 roll (a 150-coin Footlocker uses the same ladder), 2.5% refund, 95.8% of pulls carry no trait. `GameConfig.gd:693` claims "~15% of pulls" roll a trait; actual is 1/24 = 4.17% (`loot/Rarity.gd:93-102`). Any trait = 19,200 coins expected; a specific type+trait = 403,200; the full 17-combo roster = 1.22M.

**9. company_card is a "cursed" relic with no curse.** x2.0 then -25% = net x1.5 on the whole run, retroactive, also available in HARDCORE (`GameConfig.gd:127-128`, `CoinReward.gd:87-88`). Strictly better than tip_jar (x1.15), a STANDARD relic.

**10. Truck: invisible wallet, dead early visits, and a price that scales with your multiplier.** No run-coin readout in `Hud.gd` or `ui/TruckShop.gd`; at the single most likely arrival (t=90) pocket is 135 < the cheapest item (150); spends are deducted pre-mult so a 400 relic really costs 1,320-1,980 coins in HARDCORE, where HEAL is also disabled.

**11. OVERTIME is a free +37% coins/min even played honestly.** Skipping the 83-167 coins/min opening four minutes: 2,720 for 5:35 of play (487/min) vs 3,411 for 9:35 (356/min). Its only cost is record exclusion.

**12. Big Mart's coin identity does not exist.** Shelves/crates pay 3 coins; chain-collapsed shelves pay 0 (`Destructible.gd:316-317`). Net +2-4% per run. If "shelves pay coins" is meant to be a location hook, it is ~50 coins in a 2,400-coin run.

**13. SCRAP is a terminal currency.** One faucet, one sink, 9,840 total; nothing to buy afterward. PACK RAT (1,245 scrap for +50%) only pays back after ~2,490 further scrap earned, i.e. it must be bought first or never.

**14. Basement titan tier is unreachable in endless.** Waves 15-19 (t=420-570) and the wave-20/21 edges sit inside the dawn lockout 340-620 s (`Basement.gd:83`), so endless basements pay munitions (w3-12) then jump straight to apex (w22+). Titan only drops in HORDE.

**15. Small data/comment mismatches.** `loot/Rewards.gd:61` comment puts 50/50 (700) and specials (650) in the <=500 tier; they actually weigh 8, not 16. The streak>=3 tier shift more than doubles P(apex/apocalypse daily) from 1.27% to 2.94%.

**16. Config values never read.** Swept all 641 `GameConfig` consts against every `GameConfig.X` reference in `scripts/` and `scenes/`: exactly one is dead — `DEBUFF_SLOW_DURATION` (`GameConfig.gd:213`), not economy-related. Every economy const is live.

Not flagged (by design, per Larry's standing call to keep steep rarity): Apocalypse-tier 240k and Armageddon 2.16M expected cost.

# Relics Overhaul — "Lost & Found" (v0.1.66)

**Date:** 2026-07-10 · **Status:** design calls approved via buttons (3 families ~27 relics · pick-1-of-2 drops · 4 slots + mid-run scrapping · cursed only as the opt-in second choice).
**Problem:** 8 flat stat sticks, 4 slots, uniform no-dupe roll — by boss 4 the player owns half the pool and relic drops stop mattering. Relics are the last system untouched by the RNG-is-king treatment.
**Relics remain RUN-SCOPED** (no save migration; RelicBar/Menu stay the containers).

## 1. The drop moment — pick 1 of 2

Boss kills drop a `RelicPickup` as today, but collecting it opens **RELIC CHOICE**: a paused two-card overlay (LevelUpUI idiom — PROCESS_MODE_ALWAYS, PixelTheme cards, tap to take). Card A = a STANDARD or PROTOTYPE relic; Card B = another roll that MAY be CURSED (`RELIC_CURSED_CHANCE 0.35` for slot B; never slot A — cursed is always opt-in). No duplicates of held relics ever offered; if the un-held pool can't fill two cards, show one; if empty, the pickup pays `RELIC_DRY_COINS 150` instead. A SKIP button pays `RELIC_SKIP_COINS 75` (skipping is a choice, not a punishment). Full bar (4/4): the choice still opens — taking a relic prompts the swap flow (pick one to scrap, its scrap value pays out).

## 2. Slots + scrapping

`MAX_RELIC_SLOTS` stays 4. The pause RelicMenu gains **SCRAP** per held relic: pays `RELIC_SCRAP_COINS 100` into run coins (`RunStats.bonus_coins` family — pays on the stub), frees the slot, effect fully reversed via the existing apply/remove contract. Cursed relics scrap for `RELIC_CURSED_SCRAP_COINS 25` (the curse comes off cheap — you already used the power).

## 3. The pool — 27 relics, 3 families

**Family weights per card roll:** slot A = 60% STANDARD / 40% PROTOTYPE; slot B = 35% CURSED, else A's mix. Within a family, uniform over un-held.

### STANDARD (10) — the numbers, retuned (existing 8 keep their ids; two new)
| id | name | effect |
|---|---|---|
| glass_edge | Glass Edge | +25% damage |
| hairpin | Hairpin | +15% fire rate |
| long_scope | Long Scope | +30% range |
| heavy_rounds | Heavy Rounds | +30% bullet speed |
| field_kit | Field Kit | +1.5 HP/s |
| lodestone | Lodestone | +40% pickup radius |
| featherweight | Featherweight | +15% move speed |
| vital_surge | Vital Surge | +40 max HP |
| tip_jar *(new)* | Tip Jar | +15% coin gain (RunStats.coin_mult) |
| punch_card *(new)* | Punch Card | +20% weapon XP this run |

### PROTOTYPE (10) — run-rule relics ("someone left this in the back room")
| id | name | effect (hook) |
|---|---|---|
| static_soles | Static Soles | dashing leaves a 1s electric trail that zaps enemies (dash hook → player-pool HazardZone, hurts_player false) |
| double_fuse | Double Fuse | destructible bursts detonate a second time at 50% power 0.3s later (Destructible burst hook) |
| magnet_coil | Magnet Coil | every 5th kill inside a 3s streak chain-pulls ALL gems on screen (kill-streak hook → gem magnet burst) |
| intercom | The Intercom | killing an elite fears nearby trash for 1.5s (elite-death hook → existing fear status) |
| accelerant | Accelerant | burning enemies take +25% damage from everything (damage chokepoint reads is_burning) |
| overtime_clock | Broken Timeclock | each boss kill freezes the shift clock for 10s (DifficultyManager.run_time hold — waves ARE time; a real difficulty valve) |
| spare_parts | Spare Parts | crates & shelves drop +1 gem and 10% chance of a coin burst (loot-death hook) |
| rubber_soles | Rubber Soles | immune to slows (freezer/acid/review) +5% move (Player slow-stack gate) |
| adrenal_valve | Adrenal Valve | taking a hit refunds 2s of dash cooldown (player-hurt hook) |
| chain_letter | Chain Letter | +1 pierce on every gun (global gun-stat hook — verify the pierce plumbing accepts a run-level bonus) |

### CURSED (7) — devil's bargains (opt-in only, slot B; distinct card frame: C1-heavy + red-family accent? NO — palette-strict: inverted card, C4 frame on C1 fill + a ⚠ glyph; the frame treatment sells "cursed" without a new color)
| id | name | bargain |
|---|---|---|
| managers_stapler | The Manager's Stapler | +40% damage; ALL healing halved |
| expired_drink | Expired Energy Drink | +25% move & fire rate; −30 max HP (floor: can't reduce below 40) |
| company_card | Company Credit Card | coins ×2 while held; final pay-stub total −25% |
| blood_pact | Blood Pact | kills heal 1 HP; every OTHER heal source disabled |
| cursed_nametag | Cursed Nametag | elites spawn 50% more; elites drop double gems + a coin burst |
| overstocked | Overstocked | +2 relic slots (bar 4→6); −20 max HP |
| dead_mans_vest | Dead Man's Vest | survive one lethal hit per boss cycle at 1 HP; healing capped at 50% max HP while held |

HARDCORE interplay: heal-touching relics respect the heal() no-op (field_kit/blood_pact/dead_mans_vest cap text still true — healing is already zero); dead_mans_vest's cheat-death is a RELIC not a heal — allowed (parallels UNION REP being excluded? NO: UNION REP is excluded in hardcore. DECISION: dead_mans_vest is NOT OFFERED in hardcore — one-life identity wins; exclusion at roll time, like held-dupes).

## 4. Engine

- `Relics.gd` keeps the reversible stat contract for STANDARD (+ tip_jar/punch_card via existing modes where possible; coin/xp via their run-mult chokepoints with reversal ratios).
- NEW `scripts/RelicEffects.gd` (autoload-free node spawned per run, TalentEngine's little sibling): owns PROTOTYPE/CURSED hooks. Hooks bind to EXISTING chokepoints only — plan-time verification maps each (dash start, Destructible._die, kill counter, elite death, damage pipeline, run_time hold, player-hurt, slow gate, pierce plumbing, heal pipeline, elite spawn chance mult, pay-stub final). Every hook reversible on scrap (store-and-restore idiom from Relics.apply).
- RELIC CHOICE overlay: new `scripts/ui/RelicChoice.gd` (LevelUpUI idiom; two cards + SKIP; cursed card = inverted frame + ⚠; callout copy per relic in the deadpan voice — descs ≤ 70 chars).
- RelicBar renders 6 slots when overstocked is held (verify the bar's fixed-slot draw).
- Boss Rush: same choice flow at its existing (lower) relic chance.
- All numbers = GameConfig `RELIC_*` consts (starter values).

## 5. Plan-time verification

Dash-start hook (Alstar ability idiom) · Destructible burst re-entry guards (Pack v0.1.36 `hit_destructibles` lesson — double_fuse must NOT re-trigger barrel chains recursively; second blast = damage-only) · kill-streak source (RunStats kills vs a local counter) · fear status entry point · damage-pipeline read for accelerant (TalentEngine? Enemy.take_damage has no attacker context — find the choke) · run_time hold vs wave math + dawn/extraction (Broken Timeclock must not desync ShiftClock vs DifficultyManager — they may share run_time; if the hold breaks dawn timing, redesign to "waves advance 10s slower" via spawn-interval mult instead — flag) · pierce bonus plumbing · heal pipeline single choke (Player.heal) · elite chance mult (DifficultyManager.set_elite_chance_mult exists — Extraction uses it; compose, don't clobber) · pay-stub −25% (CoinReward.final_payout post-mult, vested-signing precedent) · RelicBar slot rendering.

## 6. Testing & ship

Boot-scene probes per task (pool shapes, family weights, no-dupe/no-cursed-slot-A invariants, reversibility round-trips: apply→remove leaves every stat bit-identical, hardcore exclusion) + dual gates; fable whole-branch review; VERSION 0.1.66 + tag. F5: choice moment feel (pause at boss death — annoying or delicious?), cursed pick rate, scrap usage, Broken Timeclock power level, blood_pact in a long run, overstocked bar rendering.

## Out of scope

Persistent/meta relics, relic crates/store, more than 27 relics, new WAVs, consumables, gear layer (separate future packs).

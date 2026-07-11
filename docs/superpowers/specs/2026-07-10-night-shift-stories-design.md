# Night Shift Stories — bosses + visitors (v0.1.68)

**Date:** 2026-07-10 · **Status:** picks approved via buttons (MYSTERY SHOPPER + THE MASCOT; all 3 visitors; truck = heal/reroll/relic menu).
Roster 9 → 11; a new VISITORS event class (physical arrivals, distinct from NightEvents' ambient modifiers).

## 1. THE MYSTERY SHOPPER (boss #10) — attacks target identification

Spawns **disguised**: shared shambler art, no boss bar, no SHIFT CHANGE toast — just one more body in the horde walking at trash speed. **Reveal** on: taking cumulative damage ≥ `SHOPPER_REVEAL_DAMAGE 60` OR closing to strike range (~120px) — then the bar + toast + flavor line fire and it fights: fast slash combos (`CHARGE`-style short lunges, cadence ~2.8) with runner-class speed. At phase edges (0.66 / 0.33) it **re-cloaks**: drops the bar to "???", shimmer-out draw, re-skins as a shambler and drifts INTO the current spawn population (teleport-blend: repositions to a rim point among live spawns); damaging IT re-reveals (cumulative counter resets per cloak). Combat-model exploit: you must re-FIND the boss — auto-aim keeps servicing trash, so the player reads movement patterns (its pathing is subtly straighter than trash — the fair tell).
Engine: `BossBase` gains an opt-in `concealed` state — deferred HUD-bar visibility + deferred toast (HUD reads a `revealed()` method via has_method; default true so all other bosses are untouched — byte-identity constraint). Disguise texture = the shared enemy.png; real 48px sprite (sunglasses + shopping basket) appears only revealed. Boss immune to taunt/pin as usual by class.

## 2. THE MASCOT (boss #11) — the fight accelerates

The store costume, three layers deep. **Phase = costume layer**; each threshold (0.66 / 0.33) SHEDS: a shed-burst (`RING` at the shed moment), scale shrinks (1.15 → 0.9 → 0.7 collider+sprite), move speed climbs (0.55 → 0.9 → 1.35 mult), pattern swaps:
- L1 FULL SUIT: slow, tanky presence — ground slam (`RING`) + summon 2 fans (`SUMMON`).
- L2 HALF SUIT: charges (`CHARGE`, Courier-class speed) + slam.
- L3 THE PERFORMER: tiny, runner-fast, relentless melee + short erratic dashes (`CHARGE`, short duration, low cadence ~2.0) — a duel.
HP `MASCOT_HP 2600` front-loaded (the L1 tank IS most of the bar). Sprites: 3 generator variants (mascot_a/b/c — 48px, layers visually shrinking; fallback tint-scale if art lags). Combat-model exploit: pacing — a DPS-check opener that becomes a dodge-check closer.

## 3. VISITORS — physical arrivals (new event class)

New `scripts/Visitors.gd` controller (Basement-idiom sibling; suspended while in_basement). Roll: wave-edge, gate-first then `RunConfig.rand_float()` (seeded — Daily stays deterministic), from wave ≥ 4, chance `VISITOR_CHANCE 0.20`, max 1 active, `VISITOR_COOLDOWN 90`s between visitors, ≤ 2 per run. Modes: endless + horde (flags inherit), NOT boss_rush. Which visitor: seeded uniform among the three (no repeats within a run).

### THE ICE CREAM TRUCK — the only place to spend coins mid-run
Drives in along a lane (moving solid prop, 64×32 generator sprite), parks ~600px from the player for `TRUCK_STAY 25`s, looping jingle (new WAV). Stand-in-zone (door-ring idiom) opens a paused 3-button shop overlay (RelicChoice UI idiom):
- **HEAL SCOOP** — 30% max HP, `TRUCK_HEAL_COST 150` (routes through Player.heal — hardcore's no-op makes it unbuyable there: button shows "NOT IN HARDCORE" disabled).
- **SECOND OPINION TO GO** — +1 card-reroll charge, `TRUCK_REROLL_COST 200`.
- **MYSTERY FLAVOR** — one random relic (slot-A roll: standard/prototype mix, never cursed), `TRUCK_RELIC_COST 400`; full bar → the swap flow.
**Mid-run spending mechanism (new):** `RunStats.spend_run_coins(cost) -> bool` — spendable balance = the CURRENT pre-mult subtotal (`CoinReward.pre_mult_total` at now-stats) minus prior spends; fails (deny sound) if short. Spends accumulate in `RunStats.snacks_spent`, deducted PRE-mult in `final_payout` + an itemized `SNACKS —N` stub row (the row-sum==TOTAL invariant holds; both twins via the chokepoint). Truck leaves after `TRUCK_STAY` or 3 purchases; departure honk.

### THE CRYPTID — a bounty that flees
"SOMETHING IS IN THE LOT" banner + a shimmer-drawn fast entity (runner AI with flee-from-player steering — reuse the Night Terror flee vector idiom) that never attacks; despawns after `CRYPTID_WINDOW 20`s. Kill it in time → `CRYPTID_COINS 250` + a random crate (basement crate-grant chokepoint, floor-mapped at `crate_floor(wave)`); banner "NOBODY WILL BELIEVE YOU". Miss → "IT'S GONE" + nothing. It takes full damage (no talent immunity), HP `CRYPTID_HP 900`.

### THE DRIVE-BY — a lane of consequences
Siren warning 2s (new WAV) + a telegraphed lane band across the arena (AimedBand-width telegraph), then a police car crosses at speed firing continuously: heavy damage in its lane to enemies AND the player (`DRIVEBY_DPS 80`-class ticks while in-lane; dodge = step off the line). Free horde-clear if you bait the lane. Car is untargetable (a pattern, not an entity). 6s total.

## 4. Plumbing

- Bosses.gd += shopper/mascot rows (count 11); registry/rotation/Boss Rush automatic. Flavor.gd boss lines += 2 (shopper: "she's been shopping since tuesday. nothing in the basket."; mascot: "the suit stays on. the suit has always been on."). Sprites: shopper 48px + mascot_a/b/c + truck 64×32 + a police-car 64×32 lane sprite; cryptid = shimmer-drawn (code) — generator work + controller QA iteration.
- 3 new WAVs: truck jingle (loop-ish 2s), departure honk, siren (the drive-by warning). gen_retro_audio idiom.
- Consts: all `SHOPPER_*/MASCOT_*/VISITOR_*/TRUCK_*/CRYPTID_*/DRIVEBY_*` GameConfig with ## comments (starter values).
- Concealed-boss byte-identity: every existing boss unaffected (default revealed; HUD change is has_method-guarded).
- Records/commendations: none this release (visitors feed no badges yet — future hook noted).

## 5. Plan-time verification

HUD boss-bar poll site (deferred visibility seam) · SHIFT CHANGE toast edge (defer to reveal) · scale/collider mid-fight change safety (BossBase collider resize — Godot shape resource sharing! duplicate the shape per-instance before scaling) · spawn-population blend for re-cloak (rim point among "enemies") · Night Terror flee vector reuse · truck lane pathing (straight-line mover like BossProjectile) · Player.heal hardcore gate for the scoop · pre_mult_total as the spendable base + snacks deduction in final_payout (both twins, clawback ordering) · reroll-charge grant seam (LevelUpUI `_rerolls_left` — external increment method needed) · relic grant reuse of roll/take machinery outside the pickup flow · seeded-stream contact audit (visitor rolls seeded; positions unseeded).

## 6. Testing & ship

Per-task boot-scene probes + case-insensitive parent-parity gates (19/7 baseline); fable whole-branch review; VERSION 0.1.68; CHANGELOG "**v0.1.68 — Night Shift Stories**". F5: shopper re-find fun vs frustrating; mascot pacing; truck dilemma (spend vs bank); snacks row math; cryptid chase feel; drive-by dodge readability; concealed-boss byte-identity on the old 9.

## Out of scope

Locations 3-6, evolutions, franchise, visitor badges, more visitors (bench: delivery mixup, the inspector-visitor), audio beyond the 3 WAVs.

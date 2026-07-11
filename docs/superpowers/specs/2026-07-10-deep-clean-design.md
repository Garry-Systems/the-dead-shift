# Deep Clean — the consolidation release (v0.1.67)

**Date:** 2026-07-10 · **Status:** approved batch (Larry picked Deep Clean + all 4 design calls via buttons). No new systems — every item below is a KNOWN earmark from the v0.1.60-66 ledgers. Feel-based tuning (Karen shove, puddle timing, basement difficulty, cursed pick rates) is explicitly OUT — that waits on Larry's phone time. The pre-launch dev-grant/farm-loop removals stay parked (deliberate dev tools until launch).

## A. Economy & balance (data-only, no feel judgment needed)

1. **Mart shelves — fused deaths pay no coins** *(Larry-approved)*: `Destructible` loot payout skips `CRATE_COIN_REWARD` when the death came from a chain fuse (the `chain_id` path); direct kills unchanged; gems always drop. Kills the ~+15-30%/mart-run drift (×3 hardcore).
2. **UNION REP 1500 → 900 scrap** *(controller call, reviewer-recommended range)*: the marquee benefit lands mid-season instead of ~50 runs.
3. **Coworker traits at rarity ≥ 4** *(Larry-approved)*: `COWORKER_TRAIT_MIN_RARITY` 5 → 4 (≈15% of pulls; ladder untouched — visibility, not flattening).
4. **PAYDAY measures pre-multiplier pay** *(controller call)*: `best_run_payout` (and the PAYDAY commendation's read) switches to the PRE-`coin_mult` subtotal so HARDCORE ×3 (and REGISTER SKIM/tip_jar) don't trivialize the badge. Verify what the counter currently stores; migrate = keep existing saved value (it can only have been ≥ the new measure — accept the one-time generosity, comment it).
5. **BROKEN TIMECLOCK not offered in Boss Rush** *(Larry-approved)*: exclusion at `Relics.pool/roll_choice` time keyed on `RunConfig.mode == "boss_rush"` (the dead_mans_vest-in-hardcore idiom — generalize the exclusion mechanism: a per-relic `"excluded_when": Callable/flag` field or a second hardcoded check; prefer a small data field `"not_in_modes": ["boss_rush"]`).

## B. Audio debt (new WAVs via home `gen_retro_audio.py`, wired to existing SoundManager)

6. **`car_alarm`** — a real two-tone wail loop (~1.2s), replaces the throttled `boss_roar` in `Destructible._start_wail`; keep the same throttle const.
7. **`relic_choice`** — a short "discovery" sting on the RELIC CHOICE opening; **`cursed_reveal`** — a darker sub-sting when a cursed card is present (RelicChoice plays on open; cursed variant when slot B is cursed).
8. **`basement_descend`** — a low stinger on descend (Basement plays at the fade; reuse for ascend at higher pitch if the pipeline supports pitch, else same file).
9. Wire-sites only for the above three — no other sound changes. Keep WAV budget small (4 files, ≤1s-1.5s each, same generation style as the 24-file v0.1.44 set).

## C. UI / QoL

10. **RECORDS tabs** *(Larry-approved)*: the RECORDS page splits into three tabs — RECORDS (bests incl. per-location, stats, gun kills) | BADGES (commendations wall N/18) | CHALLENGES (board + daily) — tab row under the title (PixelTheme buttons, pressed-state = current tab), one section rendered at a time, drag-scroll preserved per tab. No new hub button.
11. **XP-bar / RelicBar y-band overlap** (pre-existing, ledgered): read both HUD anchors and separate the bands (relic bar moves; the XP bar is load-bearing muscle memory).
12. **Reroll button polish**: `clip_contents = true` + height 94 (exact half), matching card buttons.
13. **`last_location` save hygiene**: when the restore guard corrects a locked id to forecourt, persist the correction back (one-line + save at the existing chokepoint).

## D. Hygiene & structural debt

14. **Delete `RelicMenu.gd`** + its Main.tscn node + any dangling refs (confirmed orphaned twice; `take_or_replace` moves to RelicBar if anything still calls it — verify).
15. **Wail dies with the car**: `Destructible._die()` clears `_wailing` + leaves "wailing_cars" (the 2-line TS-T4 fix; kills the death-frame ghost tick).
16. **Obstacles `not_in_locations` allowlist** *(the shelf-leak systemic fix)*: optional row field `"locations": []` (empty = everywhere); `Obstacles.pick` filters rows whose list excludes the current location id (threaded like the mults). Shelf row gets `"locations": ["big_mart"]`, pillar `["parking_garage"]`; the `"shelf": 0.0` pins come OUT of Locations.gd (mechanism replaced, behavior identical — probe proves the pools match).
17. **Weapon-XP payout extracted to one function** *(the twin-drift factory)*: `CoinReward.weapon_xp_payout(kills, wave, bosses) -> int` (composes `RunStats.weapon_xp_mult` × hardcore) called by BOTH GameOver and PauseMenu; the twin blocks shrink to one call each; the T1-RO textual-lockstep probe assertion updates to assert both sites call the shared function.

## Engineering notes

- Every change keeps its existing consts/idioms; no save-schema changes except reading `best_run_payout` differently (item 4 — additive interpretation, no migration).
- Probe focus: shelf fused-vs-direct payout split; trait-floor distribution; boss-rush relic exclusion; pool-parity proof for item 16; shared weapon-XP function parity on both paths (extend the lockstep probe); PAYDAY pre-mult measurement.
- Audio QA: controller listens? No — headless. Waveform sanity via file size/duration checks + Larry F5 (state in plan).
- F5 additions: new SFX character check (alarm reads as alarm, not boss); tabs navigation feel; trait pulls at rarity 4; UNION REP at 900 pacing.

## Out of scope

Everything feel-based (needs F5 data); dev-grant removal + pause-restart farm closure (pre-launch list); Night Shift Stories (next release); evolutions/franchise (benched).

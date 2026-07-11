# Deep Clean (v0.1.67) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The consolidation release — 17 known earmarks from the v0.1.60-66 ledgers: economy fixes, real SFX for the mismatches, RECORDS tabs, UI polish, dead-code removal, and two structural debt payoffs.

**Architecture:** Four implementation batches (economy / audio / UI / hygiene), each independently probe-gated; no new systems; every change keeps existing idioms.

**Tech Stack:** Godot 4.6 GDScript; home-repo `gen_retro_audio.py` (tone/noise_burst/mix/write_wav toolkit) for 4 new WAVs.

**Spec:** `docs/superpowers/specs/2026-07-10-deep-clean-design.md` (items A1-D17, all approved).

## Global Constraints

- Runner env / boot-scene probes (never `--script`) / MANDATORY DUAL GATE per task / **LITERAL RED+GREEN probe output + gate numbers in every report** / probe files deleted, new .uid tracked / master, NO push before ship — identical to the prior packs. `GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`.
- Verified facts: `best_run_payout` recorded from post-mult `earned` at GameOver.gd:248 + PauseMenu.gd:257 (twin sites — any change hits BOTH, extend the RO lockstep probe idiom); `CoinReward` already exposes pre-cut/vested seams from the clawback work — the PRE-MULT subtotal is the `(payout + bonus)` value before `* mult` (find/expose it as `CoinReward.pre_mult_total(...)` if not already separable); RECORDS = one `_records_vbox` rebuilt by `_populate_records` (MainMenu.gd:872-878); audio toolkit = `tone/noise_burst/mix/concat/gain/pad/normalize/write_wav` + per-sfx `sfx_*` functions with a seeded rng (gen_retro_audio.py) — mirror that idiom; SoundManager loads WAVs by id (grep its manifest for the wiring shape).
- Behavior-preservation invariants: item D16's allowlist mechanism must produce POOL-PARITY with the current mult-pin mechanism (probe proves same candidate pools for all 3 locations); item D17's shared function must produce identical XP on both paths (extend the lockstep probe to assert both sites call it).
- All new numbers = GameConfig consts with ## comments. Copy ≤ 70 chars.

---

### Task 1: Economy batch (spec A1-A5)

**Files:** Modify `scripts/Destructible.gd` (fused-death flag → loot payout skips coins), `scripts/logic/GameConfig.gd` (`BENEFIT_REVIVE_COST` 1500→900; `COWORKER_TRAIT_MIN_RARITY` 5→4 — update both consts' comments), `scripts/GameOver.gd` + `scripts/PauseMenu.gd` (PAYDAY: `record_best_run_payout(pre_mult)` — compute/expose the pre-mult subtotal via CoinReward; BOTH twin sites; update SaveManager.gd:60's comment; keep existing saved values — comment the one-time generosity), `scripts/logic/Relics.gd` (`"not_in_modes": ["boss_rush"]` field on overtime_clock + `pool()`/`roll_choice()` filter keyed on `RunConfig.mode` — generalize alongside the hardcore vest exclusion).

Contract details: fused-death = the `light_fuse`-initiated death path — Destructible already distinguishes it (the fuse timer kill); set a `_fused := true` at fuse-death and skip ONLY the `CRATE_COIN_REWARD` add in `_drop_loot` (gems unchanged, direct kills unchanged — including barrels' coin behavior if any: verify barrels don't pay coins today; if they do, scope the skip to `chain_id != ""` rows so barrel chains are untouched — REPORT the scoping found).

- [ ] Probe (RED first): fused vs direct shelf death coin delta (drive both paths on stubs); trait floor 4 (roll(4) trait non-empty over draws, roll(3) empty); UNION REP cost ladder 900; overtime_clock absent from 300 boss_rush-mode roll_choice draws, present in endless; PAYDAY: pre-mult < post-mult on a mult>1 case + both twin sites textual-lockstep. Gates 0/0. Commit `fix(balance): fused shelves pay gems only, union rep 900, traits at rarity 4, pre-mult PAYDAY, no timeclock in boss rush`.

---

### Task 2: Audio batch (spec B6-B9)

**Files:** Modify `/home/larryun/gen_retro_audio.py` (4 new sfx functions + manifest rows: `car_alarm` two-tone wail loop ~1.2s [alternating tone() pitches, square], `relic_choice` discovery sting ~0.8s [rising arpeggio, triangle], `cursed_reveal` dark sub-sting ~0.9s [descending minor + noise tail], `basement_descend` low stinger ~1.0s [low sweep + rumble noise]); generate to the game's audio dir (find where the 24 existing WAVs live + how SoundManager's manifest names them — mirror exactly); Modify `scripts/Destructible.gd` (wail plays `car_alarm` — same throttle const), `scripts/ui/RelicChoice.gd` (open → `relic_choice`; cursed slot B present → `cursed_reveal` layered after 0.3s), `scripts/Basement.gd` (descend fade → `basement_descend`).

- [ ] Steps: study 2 existing sfx functions first; generate; verify durations/sizes sane (python check, report table); wire the 3 sites; boot gate confirms load; probe = manifest/id existence via SoundManager (if probe-able headless — else source-text assertions, state which). Gates 0/0. Commit game `feat(audio): car alarm, relic stings, basement stinger` + home repo generator commit.

---

### Task 3: UI batch (spec C10-C13)

**Files:** Modify `scripts/MainMenu.gd` (RECORDS tabs — the big item), `scripts/Hud.gd` + `scripts/RelicBar.gd` (y-band separation: read both anchors, move the RELIC bar clear of the XP bar; report old/new offsets), `scripts/LevelUpUI.gd` (reroll button clip_contents + height 94), `scripts/MainMenu.gd` (last_location guard persists its correction — one line + the existing save chokepoint).

RECORDS tabs contract: a 3-button tab row under the title (RECORDS | BADGES | CHALLENGES, PixelTheme buttons, current tab = pressed/ACCENT state); `_populate_records` splits into `_populate_records_tab` (bests incl. per-location + stats + gun kills), `_populate_badges_tab` (commendations wall + N/18 header), `_populate_challenges_tab` (TODAY'S CHALLENGES + daily rows); one rendered at a time into the same `_records_vbox` (rebuild on tab switch); drag-scroll works per tab (same `_records_scroll` registration); default tab RECORDS; tab state resets on page open. `_guarded` on tab buttons.

- [ ] Probe: pure splits where extractable (the three populate functions build non-empty structures against a seeded save — drive off-tree if MainMenu allows, else structural source assertions, state which); reroll geometry consts; guard-persist round-trip (snapshot/restore). UI feel = review+F5. Gates 0/0. Commit `feat(ui): RECORDS tabs, bar de-overlap, reroll polish, last_location hygiene`.

---

### Task 4: Hygiene batch (spec D14-D17)

**Files:** Delete `scripts/RelicMenu.gd` (+ .uid) + its Main.tscn node + dangling refs (grep `RelicMenu|take_or_replace` — move `take_or_replace` to RelicBar ONLY if a live caller exists; report); Modify `scripts/Destructible.gd` (`_die()` clears `_wailing` + leaves "wailing_cars" — 2 lines), `scripts/logic/Obstacles.gd` + `scripts/ObstacleField.gd` + `scripts/logic/Locations.gd` (the `"locations"` allowlist: optional row field, empty/absent = everywhere; `Obstacles.pick` filters by current location id threaded like mults; shelf row → `["big_mart"]`, pillar → `["parking_garage"]`; REMOVE the `"shelf": 0.0` pins from Locations.gd — POOL-PARITY probe proves identical candidate pools per location before/after), `scripts/logic/CoinReward.gd` + `scripts/GameOver.gd` + `scripts/PauseMenu.gd` (extract `CoinReward.weapon_xp_payout(kills, wave, bosses) -> int` composing weapon_xp_mult × hardcore; both twin blocks become one call; update the lockstep comments; keep rounding identical — probe asserts parity with the old formula across a value sweep).

- [ ] Probe (RED first): pool-parity per location (old pins vs new allowlist — capture the candidate id sets both ways); weapon_xp_payout parity sweep (k/w/b grid × mult × hardcore vs the old inline formula); wail cleared on death; RelicMenu absence (boot gate is the real check — deletion breaks nothing). Gates 0/0 (boot gate especially — the .tscn node removal). Commit `chore(debt): RelicMenu deleted, wail dies with the car, locations allowlist replaces pins, shared weapon-xp payout`.

---

### Task 5: Ship v0.1.67 (controller task)

- [ ] Fable whole-branch review (base = v0.1.66 ship commit `f878a5c`): forecourt/location pool parity is THE regression risk (item 16); PAYDAY measurement change vs commendation text truth; audio wiring regressions; tabs vs the drag-scroll chain; RelicMenu deletion fallout sweep.
- [ ] Fix wave; `VERSION` → `0.1.67`; CHANGELOG "**v0.1.67 — Deep Clean**" (voice: the store finally got a quiet night to restock and fix the wobbly shelf). Push, CI green, stamp, tag, release; ledger + memory.
- [ ] F5: alarm sounds like an alarm; stings land; tabs feel; trait pulls at rarity 4 visible; UNION REP pacing; PAYDAY badge sanity on a hardcore run.

## Self-review notes (applied)

- All 17 spec items mapped: A1-5 → T1, B6-9 → T2, C10-13 → T3, D14-17 → T4.
- The two behavior-preservation proofs (pool parity, weapon-XP parity) are probe-mandated, not review-hoped.
- Type consistency: `weapon_xp_payout` signature, `"not_in_modes"`/`"locations"` field names, tab function names consistent.

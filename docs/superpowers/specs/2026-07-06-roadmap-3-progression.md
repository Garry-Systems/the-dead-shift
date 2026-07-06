# Roadmap 3 — Player progression (approved by Larry 2026-07-06)

Larry: "more things for the player to do — achievements, challenges, a player level system to unlock new game modes." Buttons: modes = HORDE NIGHT + HARDCORE + OVERTIME (no Blood Moon Shift); rank XP = coins earned per run; commendations pay rank XP + a crate.

Ships: **Pack G v0.1.58** (Employee Rank + 3 modes) → **Pack H v0.1.59** (Commendations wall).

**⚠️ MANDATORY GATES for every task (the v0.1.49 death-freeze lesson):** (1) `--headless --editor --quit` grep SCRIPT|PARSE ERROR = 0, AND (2) **boot gate**: `timeout 25 $GODOT --headless --path <proj> res://scenes/Main.tscn 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"` = 0 (catches script-load compile failures the editor gate misses).

## Pack G — Employee Rank + modes (v0.1.58)

### Employee Rank
- Save key `rank_xp` (int, lifetime, schema-extend). Rank DERIVED from XP via a pure static table (nothing stored but XP — like challenge rotation).
- `Ranks.gd` (pure, probeable): 10 ranks — 1 TRAINEE 0 · 2 CLERK 500 · 3 NIGHT CLERK 1,500 · 4 SHIFT LEAD 3,500 · 5 KEYHOLDER 7,000 · 6 ASSISTANT MANAGER 12,000 · 7 STORE MANAGER 20,000 · 8 DISTRICT MANAGER 32,000 · 9 REGIONAL DIRECTOR 50,000 · 10 FRANCHISE OWNER 75,000. (Starter values; ~500-900 coins/run ⇒ rank 3 in ~2-3 runs, rank 7 ≈ 30 runs, rank 10 = the long chase.) API: `rank_for(xp)`, `name_for(rank)`, `threshold(rank)`, `progress_in_rank(xp)`.
- XP source: the run's ACTUAL paid coins (`earned` — post-haircut, post-mult, incl. dawn/extract bonuses) added to rank_xp inside BOTH paid_out-guarded flush blocks (GameOver._finish_run + PauseMenu quit). Commendations (Pack H) add chunks through the same accessor.
- UI: hub shows `RANK 4 — SHIFT LEAD` + a thin progress bar (PixelTheme, near the coins readout; compute width vs 1080px — pack-D lesson). Pay stub gains `RANK XP +N` line; if the run crossed a threshold, a `★ PROMOTED: <NAME> ★` line + Confetti (via the FIXED _root pattern). A PROMOTED popup also queues at menu entry when a promotion happened (pending-rewards idiom) listing anything newly unlocked.
- RECORDS: rank + total rank XP rows.

### The three modes (all endless-engine variants; mode-select buttons, grayed when locked with "UNLOCKS AT <RANK NAME>")
- **HORDE NIGHT — unlocks at rank 3 (NIGHT CLERK).** `RunConfig.mode = "horde"`: Spawner skips `_check_boss` entirely; spawn interval ×`HORDE_SPAWN_MULT 0.5` (the Blood-Moon mult mechanism); elites STILL roll (extend the elite gate from `== "endless"` to endless|horde); NightEvents/Extraction/dawn stay endless-only (their existing gates already exclude "horde" — VERIFY each); clock still shown (flavor). GameOver header: "HORDE CLEANED UP". Records: `horde_best_wave`.
- **HARDCORE — unlocks at rank 7 (STORE MANAGER).** Endless + `RunConfig.hardcore = true` flag (mode STAYS "endless" so every endless gate keeps working — same pattern as `daily`): no Second Wind (card excluded from the pool for the run), `Player.heal()` no-ops (boss heals, lifesteal, all of it — one gate in heal()), `RunStats.coin_mult ×= 3` at run start, weapon XP ×2 at the flush. Pay stub header gains "— HARDCORE". Records: `hardcore_best_clockout` (seconds + display).
- **OVERTIME — unlocks at rank 5 (KEYHOLDER).** Endless + `RunConfig.overtime = true`: `DifficultyManager.run_time` pre-set to `OVERTIME_START_SECONDS 240` (2:00 AM, ~wave 9) at run start, player granted `OVERTIME_HEADSTART_XP` (enough for ~8 level-ups — compute from XpCurve, const) immediately after spawn/loadout. Dawn/extraction WORK (it's endless) — but `best_wave`/best-clockout records DON'T update from overtime runs (flag-gated at record_run — "best clock-outs only count from real shifts"). Coins pay normally. Records: `overtime_best_clockout` separately.
- Flags reset: `hardcore`/`overtime` cleared wherever `daily` clears (RunConfig — verify all mode-select paths set/clear consistently).
- Daily Shift stays endless-only (no stacking daily+hardcore etc. — mode-select buttons are mutually exclusive launches).

### Locks
- `Ranks.unlocks` table: mode id → required rank (data). Mode-select reads it; a locked button is disabled + dim with the requirement text. No lock bypass via any other path (grep launch paths).

## Pack H — Commendations (v0.1.59)

- `Commendations.gd` (pure data + check fns over SaveManager's lifetime data): ~18 one-time badges, night-shift names. Draw ONLY from counters that exist or are one-line-cheap to add at existing chokepoints (same countability rule as challenges; document swaps). Baseline set: FIRST DAY (finish 1 run) · PUNCHING IN (10 runs) · CAREER CLERK (100 runs) · EXTERMINATOR (2,500 lifetime kills) · GENOCIDE SHIFT (25,000) · PEST CONTROL (100 elites) · MIDDLE MANAGEMENT (25 bosses) · UPPER MANAGEMENT (100 bosses) · DAWN PATROL (survive 1 extraction) · WEEK ONE (5 shifts survived) · EMPLOYEE OF THE MONTH (7-day streak) · REGULAR (10 daily shifts played — needs cheap lifetime counter) · GOLDEN TICKET (pull an Armageddon) · OVER THE RAINBOW (pull an Apocalypse — needs counter at the same add() chokepoint) · BIG SPENDER (open 50 crates — counter at Inventory.open/commit_crate) · RECYCLER (10 fusions) · TASKMASTER (25 challenges completed) · PAYDAY (single run paying 2,000+ coins).
- Reward per badge: `rank_xp_grant` (tiered: 100/250/500 by difficulty) + a one-time crate (scaled: scrap→titan by difficulty). Granted via the pending-rewards idiom at menu entry (persisted earned-ids set, no double-grant — the pack-C queue lesson).
- Check point: after every run flush + at menu entry (cheap — pure fns over save data).
- UI: COMMENDATIONS section (own view or RECORDS extension — implementer judgment): badge grid/list, earned = lit with date?, unearned = dim with desc. Progress text where the counter is visible (e.g. "1,840 / 2,500").
- RECORDS row: commendations earned N/18.

## Standing rules
Roadmaps 1-2 rules + BOTH gates (editor + boot) on every task. All numbers starter values. TAB, GameConfig consts, PixelTheme, schema-extend, paid_out-guarded flushes, probes for all pure parts.

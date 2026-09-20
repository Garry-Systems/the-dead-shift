# Survivability + New-Player Wall (v0.1.75) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make getting hit readable and the first ten shifts gentler: 0.35 s hit i-frames on discrete hits, a 70%-of-max-HP cap on any single hit, a 10-shift probation period with a delayed opening, and an enemy speed ramp that climbs steadily to the same cap.

**Architecture:** `Player.take_damage` gains a defaulted `is_tick` flag that splits damage into discrete hits (i-frames + cap apply) and per-frame tick damage (neither applies); the four tick callers pass `true`. Probation is a run-scoped `RunConfig.probation` flag computed once in `Main._ready` from the existing `games_played`, threaded as a **parameter** into the pure statics (`Enemies.pick`, `DifficultyCurve.elite_chance`) so they stay probe-able. The speed curve gets its own knee constant, independent of the HP knee.

**Tech Stack:** Godot 4.6.3 GDScript. Headless probes via WSL interop.

**Spec:** `docs/superpowers/specs/2026-09-20-survivability-design.md` (decisions S1–S4 are Larry-locked — do not relitigate). Previous spec in the series (shipped as v0.1.74): `docs/superpowers/specs/2026-09-19-power-curve-design.md`.

## Global Constraints

- **Runner:** `GODOT="/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe"`, run from the repo root `/mnt/c/Users/thela/Documents/mobile-game/` (quote it). **Always redirect output to a file, then grep the file** (`timeout 240 "$GODOT" --headless --path . <scene> > out.txt 2>&1`) — never pipe the exe into grep. **Run Godot in the FOREGROUND only** (Bash tool timeout 300000 ms) and never end your turn to wait on a background run. A probe with a parse/runtime error never reaches `quit()` and hangs until the timeout — on exit=124 look for `SCRIPT ERROR` / `Parse Error` in the output file first. After adding a `class_name` file run the editor cache pass once: `timeout 300 "$GODOT" --headless --path . --editor --quit > ed.txt 2>&1`.
- **Probes = boot-scene pattern, never `--script`.** A probe is `.superpowers/probe_<name>.gd` (`extends Node`, a `check(name, ok)` helper printing `PASS  `/`FAIL  `, ending with `print("PROBE DONE fails=%d" % fails)` + `get_tree().quit(1 if fails > 0 else 0)`) plus a 5-line `.tscn` — copy `.superpowers/probe_bosses.gd/.tscn` as the template. `.superpowers/` is untracked; **never commit probes**. Every assertion must exercise production code and be able to fail; no production test hooks.
- **MANDATORY DUAL GATE per task** (paste the numbers in your report): editor gate `--editor --quit` → `grep -ciE "SCRIPT ERROR|PARSE ERROR" ed.txt` must be **≤ 19** (the 19 are known XpGem preload "Parse Error: Busy" lines); boot gate `timeout 25 "$GODOT" --headless --path . res://scenes/Main.tscn > boot.txt 2>&1` → `grep -cE "SCRIPT ERROR" boot.txt` must be **0**; same for `res://scenes/MainMenu.tscn`.
- **Regression probes stay green (`fails=0`)**: `probe_hygiene`, `probe_overtime_farm`, `probe_card_rolls`, `probe_card_apply`, `probe_card_ui`, `probe_xp_curve`, `probe_fire_timing`, `probe_procs`, `probe_bosses`, `probe_power_curve`.
- **RED before GREEN:** run each new probe before implementing and paste the failing output, then the passing output.
- Every tunable number is a `GameConfig` const with a `#` comment. Tabs. Preserve each file's existing line endings (some are CRLF).
- Strict 4-color palette: the i-frame tell is an alpha blink only — no new colors.
- Work on `master` (repo convention); one commit per task with the message given plus the co-author trailer your environment mandates; **no push until Task 6**.
- Out of scope: dash i-frames (S1: no), bite damage growth, boss pattern damage values, lifesteal/regen numbers, enemy HP, spawn rates, weapon/card values, coins, Boss Rush.

## File map

| file | change |
|---|---|
| `scripts/Player.gd` | `take_damage(amount, attacker, is_contact, is_tick)`, `_hit_iframe_time`, 70% clamp, blink |
| `scripts/HazardZone.gd`, `scripts/patterns/ZoneFill.gd`, `scripts/DrivebyLane.gd`, `scripts/BossBase.gd:193` | pass `is_tick = true` |
| `scripts/logic/GameConfig.gd` | `PLAYER_HIT_IFRAMES`, `PLAYER_MAX_HIT_FRAC`, `PLAYER_IFRAME_BLINK_HZ`, speed-knee consts, probation consts |
| `scripts/logic/DifficultyCurve.gd` | speed knee; `elite_chance(wave, probation)` |
| `scripts/logic/Enemies.gd` | `min_wave_for(row, probation)`; `pick(wave, mults, probation)` |
| `scripts/RunConfig.gd`, `scripts/Main.gd` | `probation` flag: reset + computed once at run start + callout |
| `scripts/Spawner.gd`, `scripts/Basement.gd` | thread the flag; first-boss HP mult |
| `scripts/GameOver.gd` | probation-complete pay-stub line |

---

### Task 1: Damage rules — tick flag, hit i-frames, 70% hit cap

**Files:** Modify `scripts/Player.gd` (`take_damage` ~line 305, timers in `_physics_process` ~line 115, new blink helper), `scripts/logic/GameConfig.gd` (next to `PLAYER_MAX_HEALTH`), `scripts/HazardZone.gd:108`, `scripts/patterns/ZoneFill.gd:34`, `scripts/DrivebyLane.gd:107`, `scripts/BossBase.gd:193`. Probe `.superpowers/probe_survivability.gd/.tscn`.

**Interfaces — Produces:** `Player.take_damage(amount: float, attacker = null, is_contact: bool = false, is_tick: bool = false) -> void`; `Player.hit_iframes_active() -> bool`; GameConfig `PLAYER_HIT_IFRAMES`, `PLAYER_MAX_HIT_FRAC`, `PLAYER_IFRAME_BLINK_HZ`.

Callers, verified: **tick** (`dps × delta` every frame) = `HazardZone.gd:108`, `patterns/ZoneFill.gd:34`, `DrivebyLane.gd:107`, `BossBase.gd:193` (body contact, already passes `null, true` — becomes `null, true, true`). **Discrete** (leave untouched, default `is_tick = false`) = `Enemy.gd:558` bite, `BossProjectile.gd:39`, `patterns/AimedBand.gd:43`, `patterns/ChargeDash.gd:65`, `patterns/ExpandingRing.gd:34`, `ExploderEnemy.gd:39`, `EliteVolatileBlast.gd:46`. Re-grep (`grep -rn "take_damage(" scripts | grep -i "player\|_target\|target\."`) and classify anything not in these lists by the same rule (is the amount multiplied by a frame delta?); report additions.

- [ ] **Step 1: GameConfig**

```gdscript
const PLAYER_HIT_IFRAMES := 0.35      # seconds the player ignores further DISCRETE hits after one lands (Survivability, v0.1.75). Tick damage (pools, zone fills, drive-by, boss body) neither triggers nor respects it.
const PLAYER_MAX_HIT_FRAC := 0.70     # "no one-shots from healthy": one DISCRETE hit never exceeds this fraction of max HP (after armor). Every mode, HARDCORE included.
const PLAYER_IFRAME_BLINK_HZ := 12.0  # sprite alpha blink rate while hit i-frames are active (palette-safe tell)
```

- [ ] **Step 2: Probe (RED).** Instantiate the real player (`load("res://scenes/Player.tscn").instantiate()`, add under the probe; read how `.superpowers/probe_fire_timing.gd` boots one). Use small recorder stubs (`extends Node` with a `take_damage(amount)` that counts) as `attacker`. Checks:
  - discrete hit of 10 on a 100 HP player → HP 90 and `hit_iframes_active()`; an immediate second discrete hit → HP still 90; after driving `_physics_process` for a total of `PLAYER_HIT_IFRAMES + 0.02` s → a discrete hit lands (HP 80).
  - during an active window a **tick** call (`take_damage(5.0, null, false, true)`) → HP drops by 5; a tick call on a fresh player does **not** start a window (`hit_iframes_active()` false afterwards).
  - blocked bite fires nothing: give the player thorns (`upgrade_thorns(2.0)`), land one bite from stub A (A recorded 1 reflect), then a blocked bite from stub B inside the window → B recorded 0.
  - dodge: `upgrade_dodge(1.0)` is capped at `DODGE_CAP`, so instead set the private `_dodge_chance = 1.0` directly in the probe → a dodged discrete hit leaves HP unchanged and `hit_iframes_active()` false.
  - cap: fresh 100 HP player, discrete hit of 500 → HP == 30 (±0.01); with `upgrade_armor(0.5)` and `is_contact = true`, a hit of 120 → 60 after armor → HP 40 (cap not binding); a hit of 500 contact → HP 30. With `RunConfig.hardcore = true` (restore it afterwards) the same 500 hit → HP 30. A **tick** of 500 on a fresh player → dead (cap never applies to ticks) — guard the probe so death handling (GameOver is not in this scene) cannot crash it: if `take_damage` reaching 0 HP emits a signal only, fine; if it touches scene nodes, assert `_health.current <= 0` via a 95-damage tick instead and say so.
  - TTD table: for bite values 10.0, 16.3, 21.8, 43.2 (= `DifficultyCurve.enemy_stats(w)["touch_damage"]` at waves 1, 11, 17, 31 — read them live, don't hardcode), simulate six biters each attempting a bite every `ENEMY_CONTACT_HIT_CD` with staggered phases, stepping `_physics_process(1/60)` and calling real `take_damage(bite, stub, true)`; time until HP ≤ 0 within ±15% of 3.2 / 2.1 / 1.4 / 0.7 s; and the max number of landed discrete hits in any sliding 1.0 s window ≤ 3.
  - source checks: the four tick callers pass a 4th argument `true`; `Enemy.gd`'s bite call does not.
- [ ] **Step 3: Player.gd**

```gdscript
var _hit_iframe_time := 0.0        # seconds remaining of post-hit invulnerability to DISCRETE hits (Survivability, v0.1.75)

## True while a landed discrete hit is still shielding the player from further discrete hits.
func hit_iframes_active() -> bool:
	return _hit_iframe_time > 0.0
```
In `_physics_process`, next to the `_revive_invuln_time` tick:
```gdscript
	if _hit_iframe_time > 0.0:
		_hit_iframe_time -= delta
		_update_iframe_blink()
```
```gdscript
## Alpha blink while hit i-frames run. Uses self_modulate so it cannot fight the tint tweens that
## already own `_sprite.modulate` (hurt tint, lifesteal_blip).
func _update_iframe_blink() -> void:
	if _sprite == null:
		return
	if _hit_iframe_time <= 0.0:
		_sprite.self_modulate.a = 1.0
		return
	var phase := int(_hit_iframe_time * GameConfig.PLAYER_IFRAME_BLINK_HZ * 2.0)
	_sprite.self_modulate.a = IFRAME_BLINK_ALPHA if phase % 2 == 0 else 1.0
```
`take_damage` — new signature and order (keep every existing comment that is still true; the death branch below is untouched):
```gdscript
func take_damage(amount: float, attacker = null, is_contact: bool = false, is_tick: bool = false) -> void:
	if _revive_invuln_time > 0.0:
		return
	# Hit i-frames (Survivability): a landed DISCRETE hit shields against further discrete hits for
	# PLAYER_HIT_IFRAMES. A blocked hit is a non-event — no Thorns, no hurt-nova, no relic hook.
	# Tick damage (dps x delta: pools, zone fills, drive-by, boss body) passes straight through and
	# never starts a window, or standing in a weak pool would grant bite immunity.
	if not is_tick and _hit_iframe_time > 0.0:
		return
	# ... existing Thorns block, unchanged ...
	# ... existing dodge early-return, unchanged ...
	if is_contact:
		amount *= _armor_mult
	# No one-shots from healthy (Survivability): clamp ONE discrete hit, after armor. Every mode.
	if not is_tick:
		amount = minf(amount, max_hp() * GameConfig.PLAYER_MAX_HIT_FRAC)
	_health.take_damage(amount)
	if not is_tick and amount > 0.0:
		_hit_iframe_time = GameConfig.PLAYER_HIT_IFRAMES
	# ... existing _hurt_flash / shake / relic hook / hurt-nova / death branch, unchanged ...
```
Declare `const IFRAME_BLINK_ALPHA := 0.35` at the top of `Player.gd` beside `HURT_FLASH_COOLDOWN` and use it in `_update_iframe_blink` instead of the literal. The blink must reset to 1.0 when the window ends: the helper runs on the frame the timer crosses zero because the `-=` happens before the call.
- [ ] **Step 4: tick callers** — add the 4th argument: `HazardZone.gd:108` `player.take_damage(_dps * dt * GameConfig.PLAYER_HAZARD_DMG_MULT, null, false, true)`; `ZoneFill.gd:34` `player.take_damage(_dps * delta, null, false, true)`; `DrivebyLane.gd:107` `_player.take_damage(_dps * dt, null, false, true)`; `BossBase.gd:193` `_target.take_damage(touch_damage * delta, null, true, true)`.
- [ ] **Step 5:** Probe GREEN, dual gate, regression probes. **Commit** `feat(player): hit i-frames on discrete hits, tick damage passes through, 70% single-hit cap`

---

### Task 2: Speed ramp — own knee, steady climb to the same cap

**Files:** Modify `scripts/logic/DifficultyCurve.gd:7-21`, `scripts/logic/GameConfig.gd` (~lines 86-94). Probe `.superpowers/probe_speed_ramp.gd/.tscn`.

- [ ] **Step 1: Probe (RED):** `enemy_stats(1)["move_speed"] == 70`; wave 7 == `70 × 1.02^6` (78.83 ±0.5); wave 11 within 118 ±3; wave 14 within 160 ±3; wave 17 within 217 ±3; waves 18, 25, 40 == `ENEMY_SPEED_CAP`; strictly non-decreasing for w in 1..40; per-wave ratio never exceeds `ENEMY_RAMP_SPEED_GROWTH + 0.001` (no cliff); **HP and damage unchanged:** for w in [1, 5, 10, 11, 17, 20, 31] `max_health` == `ENEMY_MAX_HEALTH × ENEMY_HP_GROWTH^min(w-1, LATE-1) × ENEMY_LATE_HP_GROWTH^max(w-LATE, 0)` and `touch_damage` == `ENEMY_TOUCH_DAMAGE × ENEMY_DMG_GROWTH^(w-1)` (±0.01); GameConfig source has no `ENEMY_LATE_SPEED_GROWTH`.
- [ ] **Step 2: GameConfig** — delete `ENEMY_LATE_SPEED_GROWTH`; add (and fix the `ENEMY_LATE_WAVE` comment so it says HP only):

```gdscript
const ENEMY_SPEED_RAMP_WAVE := 7        # speed grows at ENEMY_SPEED_GROWTH through this wave (3:00), then at ENEMY_RAMP_SPEED_GROWTH — speed has its OWN knee, independent of the HP knee (ENEMY_LATE_WAVE)
const ENEMY_RAMP_SPEED_GROWTH := 1.107  # per-wave speed multiplier past ENEMY_SPEED_RAMP_WAVE: a steady climb that reaches ENEMY_SPEED_CAP at wave 18 (8:30), same as the old 1.02-then-1.15 cliff did
```
- [ ] **Step 3: DifficultyCurve.enemy_stats** — speed term only:

```gdscript
	var spd_early := mini(w, GameConfig.ENEMY_SPEED_RAMP_WAVE - 1)
	var spd: float = GameConfig.ENEMY_MOVE_SPEED * pow(GameConfig.ENEMY_SPEED_GROWTH, spd_early)
	if wave > GameConfig.ENEMY_SPEED_RAMP_WAVE:
		spd *= pow(GameConfig.ENEMY_RAMP_SPEED_GROWTH, wave - GameConfig.ENEMY_SPEED_RAMP_WAVE)
	spd = minf(spd, GameConfig.ENEMY_SPEED_CAP)
```
Remove the `spd *= pow(ENEMY_LATE_SPEED_GROWTH, lw)` line from the late-wave block (HP keeps its line). Update the function's comment: HP freezes-then-ramps at `ENEMY_LATE_WAVE`; speed uses its own knee. Grep `scripts/` for `ENEMY_LATE_SPEED_GROWTH` and any comment citing "1.15" speed growth (e.g. near `ENEMY_SPEED_CAP`, `RUNNER_*`) and make them true.
- [ ] **Step 4:** Probe GREEN, dual gate, regression probes (`probe_power_curve` must stay `fails=0` — its threat model does not read speed; if it does, STOP and report). **Commit** `balance(enemies): speed ramp climbs steadily from 3:00 to the same 240 cap`

---

### Task 3: Probation — flag, delayed arrivals, softer first boss

**Files:** Modify `scripts/logic/GameConfig.gd`, `scripts/RunConfig.gd` (new var + `clear_mode_flags`), `scripts/Main.gd` (`_ready`, after `RunStats.reset()`), `scripts/logic/Enemies.gd` (`pick`, new `min_wave_for`), `scripts/logic/DifficultyCurve.gd` (`elite_chance`), `scripts/Spawner.gd` (`_spawn_enemy` ~142, elite roll ~159, `_check_boss` ~76), `scripts/Basement.gd:230`. Probe `.superpowers/probe_probation.gd/.tscn`.

**Interfaces — Produces:** `RunConfig.probation: bool`; `RunConfig.compute_probation(games_played: int) -> bool` (pure on its inputs + the run flags); `Enemies.min_wave_for(row: Dictionary, probation: bool) -> int`; `Enemies.pick(wave: int, mults: Dictionary = {}, probation: bool = false) -> Dictionary`; `DifficultyCurve.elite_chance(wave: int, probation: bool = false) -> float`.

- [ ] **Step 1: GameConfig**

```gdscript
# --- Probation period (Survivability, v0.1.75): a save's first shifts get a gentler opening ---
const PROBATION_SHIFTS := 10                       # completed shifts (SaveManager.games_played) before probation ends
const PROBATION_MIN_WAVE := {"brute": 5, "exploder": 7, "hive": 9}   # delayed arrival waves (normal: 4 / 5 / 7); ids not listed keep their Enemies.gd min_wave
const PROBATION_ELITE_MIN_WAVE := 8                # elites start at 3:30 on probation (normal ELITE_MIN_WAVE 6 = 2:30)
const PROBATION_FIRST_BOSS_HP_MULT := 0.6          # the wave-5 boss only; every later boss is normal
```
- [ ] **Step 2: Probe (RED).** Checks:
  - `RunConfig.compute_probation(g)` truth table — save and restore `mode/daily/hardcore/overtime` around it: endless + all flags off → true for g = 0 and 9, false for 10 and 50; false whenever `daily`, `hardcore` or `overtime` is true, or `mode` is `"horde"` / `"boss_rush"`.
  - `Enemies.min_wave_for` for every row in `Enemies.all()`: `probation = false` → exactly the row's own `min_wave` (normal schedule byte-identical); `probation = true` → brute 5, exploder 7, hive 9, every other id unchanged.
  - `Enemies.pick` statistics (seed the global RNG; 4,000 picks each): wave 4 probation → never brute; wave 4 normal → brute appears; wave 6 probation → never exploder/hive, brute appears; wave 9 probation → hive appears. Default-arg call `pick(w)` behaves as `probation = false`.
  - `elite_chance(7, true) == 0.0`, `elite_chance(7, false) > 0.0`, `elite_chance(8, true) == elite_chance(8, false)`, `elite_chance(20, true) == elite_chance(20, false)`.
  - First boss: a pure helper (below) — `Spawner.first_boss_hp_mult(5, true) == 0.6`, `(5, false) == 1.0`, `(10, true) == 1.0`; source checks that `_check_boss` applies it to `stats["max_health"]` before `_spawn_boss`, that `_spawn_enemy`, the elite roll and `Basement`'s pick pass `RunConfig.probation`, and that `_process_boss_rush` does not.
  - `RunConfig.clear_mode_flags()` resets `probation` to false.
- [ ] **Step 3: RunConfig**

```gdscript
# Probation period (Survivability, v0.1.75): computed ONCE per run in Main._ready from the save's
# completed-shift count, so nothing re-reads the save mid-run. Reset in clear_mode_flags().
var probation := false

## True when this run should use the gentler new-hire opening. Endless only; never the Daily Shift
## (scores must stay comparable) and never the rank-gated modes (belt-and-braces — a save this new
## cannot reach them).
func compute_probation(games_played: int) -> bool:
	return mode == "endless" and not daily and not hardcore and not overtime \
		and games_played < GameConfig.PROBATION_SHIFTS
```
Add `probation = false` to `clear_mode_flags()`.
- [ ] **Step 4: Main._ready** — directly after `RunStats.reset()`: `RunConfig.probation = RunConfig.compute_probation(SaveManager.games_played())` (one comment line: computed here because a mid-run RESTART reloads this scene; `games_played` only advances at run end).
- [ ] **Step 5: Enemies.gd**

```gdscript
## The wave a row becomes eligible. On probation (GameConfig.PROBATION_MIN_WAVE) a few types arrive
## later; every other row — and every non-probation run — uses the row's own min_wave unchanged.
static func min_wave_for(row: Dictionary, probation: bool) -> int:
	if probation:
		var id := String(row["id"])
		if GameConfig.PROBATION_MIN_WAVE.has(id):
			return int(GameConfig.PROBATION_MIN_WAVE[id])
	return int(row["min_wave"])
```
`pick(wave, mults = {}, probation = false)`: replace `int(e["min_wave"]) <= wave` with `min_wave_for(e, probation) <= wave`; extend the doc comment. Check every other reader of `min_wave` in the file/tree (`grep -rn "min_wave" scripts`) and route it through `min_wave_for` only where it gates spawning.
- [ ] **Step 6: DifficultyCurve.elite_chance**

```gdscript
static func elite_chance(wave: int, probation: bool = false) -> float:
	var min_wave := GameConfig.PROBATION_ELITE_MIN_WAVE if probation else GameConfig.ELITE_MIN_WAVE
	if wave < min_wave:
		return 0.0
	return minf(GameConfig.ELITE_CHANCE_BASE + GameConfig.ELITE_CHANCE_PER_WAVE * float(wave), GameConfig.ELITE_CHANCE_CAP)
```
- [ ] **Step 7: Spawner + Basement** — `Enemies.pick(DifficultyManager.wave, location_spawn_mults, RunConfig.probation)` in `Spawner._spawn_enemy` and `Basement.gd:230`; elite roll uses `DifficultyCurve.elite_chance(DifficultyManager.wave, RunConfig.probation)`; in `_check_boss`:

```gdscript
	var stats := DifficultyManager.boss_stats()
	stats["max_health"] = float(stats["max_health"]) * first_boss_hp_mult(w, RunConfig.probation)
	_spawn_boss(stats)
```
```gdscript
## Probation (Survivability): only the FIRST scheduled boss (wave BOSS_WAVE_INTERVAL) is softened.
static func first_boss_hp_mult(wave: int, probation: bool) -> float:
	return GameConfig.PROBATION_FIRST_BOSS_HP_MULT if probation and wave == GameConfig.BOSS_WAVE_INTERVAL else 1.0
```
Boss Rush (`_process_boss_rush`) is untouched. Confirm `boss_stats()` returns a fresh dict each call (it does — `DifficultyCurve` builds a literal), so mutating it is safe.
- [ ] **Step 8:** Probe GREEN, dual gate, regression probes. **Commit** `feat(probation): first 10 shifts get delayed brutes/exploders/elites/hives and a softer first boss`

---

### Task 4: Probation presentation — run-start callout + pay-stub line

> **Superseded during execution:** the run-start message shipped on the HUD banner (two lines, no dash, sequenced after the TONIGHT'S SHIFT banner), not CombatText.callout — see spec §3.4 and the SDD ledger.

**Files:** Modify `scripts/Main.gd` (after the player is positioned in `_ready`), `scripts/GameOver.gd` (pay-stub, near the `★ PROMOTED` lines ~365-372; `add_game_played()` is at ~222), `scripts/logic/GameConfig.gd` (two copy consts). Extend `.superpowers/probe_probation.gd`.

Copy (exact, house deadpan, ≤ 70 chars): callout `PROBATIONARY PERIOD — SHIFT %d OF %d` (n = `games_played + 1`, total = `PROBATION_SHIFTS`); pay-stub line `PROBATION COMPLETE. HR HAS STOPPED WATCHING.`

- [ ] **Step 1: Probe additions (RED):** plain function `RunConfig.probation_callout(games_played: int) -> String` (RunConfig is an autoload; no `static`) returns `"PROBATIONARY PERIOD — SHIFT 3 OF 10"` for 2 (format from the consts); plain function `RunConfig.probation_just_completed(played_before: int, played_after: int) -> bool` is true only for `(PROBATION_SHIFTS - 1, PROBATION_SHIFTS)`; source checks that `Main.gd` calls `CombatText.callout` with `probation_callout(...)` inside an `if RunConfig.probation` and that `GameOver.gd` adds the completion line gated on `probation_just_completed`.
- [ ] **Step 2: RunConfig** — the two functions (they read only `GameConfig`), and the two copy consts in GameConfig: `PROBATION_CALLOUT_FMT := "PROBATIONARY PERIOD — SHIFT %d OF %d"`, `PROBATION_COMPLETE_LINE := "PROBATION COMPLETE. HR HAS STOPPED WATCHING."`.
- [ ] **Step 3: Main._ready** — after the player is positioned: `if RunConfig.probation: CombatText.callout(player.global_position + Vector2(0, -90), RunConfig.probation_callout(SaveManager.games_played()), PixelTheme.ACCENT)`. `CombatText.instance` may not exist yet on the first frame — read `scripts/ui/CombatText.gd`; if the singleton registers in its own `_ready` later than Main's, defer with `call_deferred` on a small private method. Use an existing palette color (`PixelTheme.ACCENT`).
- [ ] **Step 4: GameOver** — read `games_played()` BEFORE the existing `SaveManager.add_game_played()` (~line 222) into a local, and AFTER it; in the stub builder add, above the `★ PROMOTED` block: `if RunConfig.probation_just_completed(played_before, played_after): _centered_line(_stub_vbox, GameConfig.PROBATION_COMPLETE_LINE, PixelTheme.ACCENT, 18)`. The stub is built after `_finish_run`; thread the two ints through members the way `rank_before/rank_after` already are (read that pattern and mirror it). The PauseMenu abandon path shows no pay-stub — no line there; that is fine.
- [ ] **Step 5:** Probe GREEN, dual gate, regression probes. **Commit** `feat(probation): run-start callout + probation-complete pay-stub line`

---

### Task 5: Verify against the spec targets — sim re-run + survivability report

**Files:** Extend `.superpowers/probe_power_curve.gd` (untracked); create `docs/superpowers/analysis/2026-09-20/survivability-probe-v0.1.75.txt` (tracked: concatenated final output of `probe_survivability`, `probe_speed_ramp`, `probe_probation`, and the new power-curve rows); amend `docs/superpowers/specs/2026-09-20-survivability-design.md` (§4 measured values; Status line).

- [ ] **Step 1:** Add to `probe_power_curve.gd` a report-only **FRESH-on-probation** row set: threat computed with the probation schedule (type-mix factor recomputed from `Enemies.min_wave_for(row, true)` and `elite_chance(w, true)` — if the probe's type-mix factor is a hardcoded bracket table, derive the probation variant from the live rows and weights instead, and say so) and the wave-5 boss TTK with `PROBATION_FIRST_BOSS_HP_MULT`. Print FRESH normal vs FRESH probation power÷threat at 1:30, 2:00, 2:30, 3:00, 3:30, 4:00 and both first-boss TTKs. Add one check: probation ratio ≥ normal ratio at every sampled minute.
- [ ] **Step 2:** Run all probes. Every v0.1.74 §4 check in `probe_power_curve` must still pass untouched. If the speed change or probation moved any of them, **STOP and report** — do not retune spec-1 constants in this release.
- [ ] **Step 3:** Write the analysis doc; fill spec §4's table with measured values (one "measured:" note per row); set the spec Status line to "implemented in v0.1.75". Dual gate. **Commit** `docs: survivability probe output + measured spec targets`

---

### Task 6: Ship v0.1.75

- [ ] Whole-branch review over `git diff v0.1.74..HEAD` (superpowers:requesting-code-review); ONE fix wave + one scoped re-review if it finds anything.
- [ ] `VERSION` → `0.1.75\n`. `CHANGELOG.md` top entry `## v0.1.75 — Workplace Safety (<date>)`, house voice; bullets: a moment of invulnerability after every hit (the blink) and what still hurts through it (pools, boss bodies); no single hit takes more than 70% of your health, HARDCORE included; the horde speeds up steadily from 3:00 instead of all at once after 5:00 (same top speed); PROBATIONARY PERIOD for the first 10 shifts (what arrives later, softer first boss, "you cannot quit your way out of it").
- [ ] Final gates by the controller: all probes `fails=0`, editor ≤ 19, boot Main + MainMenu 0.
- [ ] Commit `release: v0.1.75 — Workplace Safety (survivability + probation)`, `git tag v0.1.75`, `git push origin master && git push origin v0.1.75`; watch both workflows to green; confirm the GitHub release.
- [ ] Preserve the SDD ledger as `docs/superpowers/analysis/2026-09-20/survivability-sdd-ledger.md`; update memory (`project_zombie_survivor.md` ▶ block + `MEMORY.md`): shipped, constants, F5 priorities — dash out of a dawn surround, blink readability, 5:00–6:30 slope, a brand-new save's first two shifts, HARDCORE with the cap. Next: spec 3 (Economy/meta).

---

## Spec coverage check

| spec § | task |
|---|---|
| 3.1 two kinds of damage, `is_tick` | 1 |
| 3.2 hit i-frames, order, blocked-hit non-events, blink | 1 |
| 3.3 70% cap, every mode | 1 |
| 3.4 probation flag, schedule, first boss, presentation | 3, 4 |
| 3.5 speed ramp | 2 |
| §4 targets, §7 testing | per-task probes; 5 (sim + measured values) |
| §6 compatibility (defaulted param, no save change) | 1, 3 |

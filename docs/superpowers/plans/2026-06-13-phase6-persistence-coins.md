# Phase 6 — Spec 1: Persistence & Coins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make coins a real, persistent currency — every run pays out coins scaled by performance, and coins + high scores survive app restarts via a JSON save file.

**Architecture:** Two new autoloads (`SaveManager` for the persistent JSON wallet/high-scores, `RunStats` for per-run kill/boss counters) plus a pure `CoinReward` payout function. Death (`GameOver`) computes the payout, banks it, records high scores, and saves; the main menu reads the balance. No weapons, crates, or shop yet — those are Phase 6 Specs 2 and 3.

**Tech Stack:** Godot 4.6, GDScript. Persistence via `FileAccess` + `JSON` to `user://savegame.json`.

**Spec:** `docs/superpowers/specs/2026-06-13-phase6-persistence-coins-design.md`

---

## How to verify (read this first)

This project has **no GDScript unit-test runner** (GUT is deferred, and the Godot editor is GUI-driven on Windows). Verification per the project's established workflow is:

1. **Headless compile-check** — catches parse/type errors without the editor. Run from WSL:
   ```bash
   cd "/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64" && \
   timeout 150 ./Godot_v4.6.3-stable_mono_win64_console.exe --headless \
     --path "C:\Users\thela\Documents\mobile-game" --quit-after 5 2>&1 | \
   grep -iE "error|parse|invalid|nonexistent|expected" | grep -ivE "ErrorMacros" || echo "NO SCRIPT ERRORS"
   ```
   A known-benign line may appear: `Failed loading resource: res://art/menu_background.jpg` (the headless dummy renderer can't decode JPEGs). Ignore **only** that line; any GDScript parse/type error is a real failure.
2. **F5 smoke test** — Larry runs the game in the editor (final task).

Each code task ends with a commit. Task 8 is a full headless compile gate; Task 9 is the F5 smoke checklist.

**File structure (what each new file owns):**
- `scripts/SaveManager.gd` — the only code that touches disk; owns the persistent dictionary + load/save/migration + wallet/high-score API.
- `scripts/RunStats.gd` — transient per-run counters (kills, bosses). No disk, no persistence.
- `scripts/logic/CoinReward.gd` — pure payout math, no node/state dependencies (mirrors `XpCurve`/`DifficultyCurve`).

---

## Task 1: Coin config constants

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (append a new group at end of file)

- [ ] **Step 1: Add the Coins config group**

Append to the end of `scripts/logic/GameConfig.gd` (after the existing Reload group, keeping the file's `const`-per-line style):

```gdscript

# --- Coins / economy (Phase 6 Spec 1) ---
const COIN_BASE := 10          # flat coins for finishing any run
const COIN_PER_WAVE := 5       # coins per wave reached
const COIN_PER_BOSS := 25      # coins per boss defeated
const COIN_PER_KILL := 1       # coins per trash enemy killed
```

- [ ] **Step 2: Commit**

```bash
git add scripts/logic/GameConfig.gd
git commit -m "Phase 6 Spec 1: coin payout config constants"
```

---

## Task 2: CoinReward pure payout function

**Files:**
- Create: `scripts/logic/CoinReward.gd`

- [ ] **Step 1: Create the pure payout helper**

Create `scripts/logic/CoinReward.gd` with exactly:

```gdscript
class_name CoinReward
## Pure end-of-run coin payout math. No node or state dependencies
## (mirrors XpCurve / DifficultyCurve). Tunable via GameConfig.COIN_* consts.

## Coins awarded for a run: a flat base plus per-wave, per-boss, and per-kill terms.
static func payout(wave: int, bosses: int, kills: int) -> int:
	return GameConfig.COIN_BASE \
		+ GameConfig.COIN_PER_WAVE * wave \
		+ GameConfig.COIN_PER_BOSS * bosses \
		+ GameConfig.COIN_PER_KILL * kills
```

- [ ] **Step 2: Sanity-check the math (manual)**

Confirm by hand against the config defaults: `payout(3, 1, 40)` = `10 + 5*3 + 25*1 + 1*40` = `10 + 15 + 25 + 40` = `90`. (No runner; this is a reasoning check the reviewer verifies.)

- [ ] **Step 3: Commit**

```bash
git add scripts/logic/CoinReward.gd
git commit -m "Phase 6 Spec 1: CoinReward pure payout function"
```

---

## Task 3: RunStats autoload

**Files:**
- Create: `scripts/RunStats.gd`
- Modify: `project.godot` (autoload section)

- [ ] **Step 1: Create the per-run counter autoload**

Create `scripts/RunStats.gd` with exactly:

```gdscript
extends Node
## Per-run counters (kills, bosses) read by the end-of-run coin payout.
## Autoload — survives scene changes; reset() is called at the start of each run
## from Main._ready. Session-only, no persistence. No class_name: the autoload
## name is already global.

var kills := 0
var bosses_killed := 0

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0

## A trash enemy was killed.
func add_kill() -> void:
	kills += 1

## A boss was killed.
func add_boss() -> void:
	bosses_killed += 1
```

- [ ] **Step 2: Register the autoload**

In `project.godot`, find the `[autoload]` section:

```
[autoload]

DifficultyManager="*res://scripts/DifficultyManager.gd"
RunConfig="*res://scripts/RunConfig.gd"
```

Add a line so it becomes:

```
[autoload]

DifficultyManager="*res://scripts/DifficultyManager.gd"
RunConfig="*res://scripts/RunConfig.gd"
RunStats="*res://scripts/RunStats.gd"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/RunStats.gd project.godot
git commit -m "Phase 6 Spec 1: RunStats per-run counter autoload"
```

---

## Task 4: Count kills and bosses during a run

**Files:**
- Modify: `scripts/Main.gd:8`
- Modify: `scripts/Enemy.gd:92-96`
- Modify: `scripts/Boss.gd:112`

- [ ] **Step 1: Reset counters at run start**

In `scripts/Main.gd`, the `_ready()` currently begins:

```gdscript
func _ready() -> void:
	DifficultyManager.reset()
```

Change it to:

```gdscript
func _ready() -> void:
	DifficultyManager.reset()
	RunStats.reset()
```

- [ ] **Step 2: Count a trash kill on enemy death**

In `scripts/Enemy.gd`, `take_damage` currently reads:

```gdscript
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_drop_gem()
		queue_free()
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())
```

Change the death branch to add the kill count:

```gdscript
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		RunStats.add_kill()
		_drop_gem()
		queue_free()
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())
```

- [ ] **Step 3: Count a boss kill in the boss reward**

In `scripts/Boss.gd`, `_reward()` currently begins:

```gdscript
func _reward() -> void:
	# Big XP burst — scattered around the boss, enough to pop a level-up.
	if xp_gem_scene != null:
```

Insert the boss count as the first line of `_reward()`:

```gdscript
func _reward() -> void:
	RunStats.add_boss()
	# Big XP burst — scattered around the boss, enough to pop a level-up.
	if xp_gem_scene != null:
```

(Bosses count only toward `bosses_killed`, never `kills`, so the payout's per-kill and per-boss terms don't double-count.)

- [ ] **Step 4: Commit**

```bash
git add scripts/Main.gd scripts/Enemy.gd scripts/Boss.gd
git commit -m "Phase 6 Spec 1: count kills + bosses via RunStats during a run"
```

---

## Task 5: SaveManager autoload (persistent wallet + high scores)

**Files:**
- Create: `scripts/SaveManager.gd`
- Modify: `project.godot` (autoload section)

- [ ] **Step 1: Create the SaveManager autoload**

Create `scripts/SaveManager.gd` with exactly:

```gdscript
extends Node
## Owns the single persistent save file (user://savegame.json): the coin wallet
## and high scores. Loads once on boot (autoload), survives scene changes.
## Corruption-safe and forward-compatible — later specs add keys to DEFAULTS and
## old saves silently gain them. No class_name: the autoload name is already global.

const SAVE_PATH := "user://savegame.json"
const TMP_PATH := "user://savegame.tmp"
const CORRUPT_PATH := "user://savegame.corrupt.json"

## The canonical schema. Adding a key here is the ONLY change needed to extend the save.
const DEFAULTS := {
	"version": 1,
	"coins": 0,
	"best_wave": 0,
	"best_bosses": 0,
}

var _data: Dictionary = {}

func _ready() -> void:
	load_game()

## Reads the save file into _data, merging over defaults. Safe on missing/corrupt files.
func load_game() -> void:
	_data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: could not open save; using defaults")
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_handle_corrupt(text)
		return
	# Merge: copy known keys whose type matches the default, ignore everything else.
	for key in DEFAULTS:
		if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
			_data[key] = parsed[key]
	_data["version"] = DEFAULTS["version"]

## Writes _data to disk atomically (temp file, then replace). Never crashes the game.
func save_game() -> bool:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: could not open temp file for writing")
		return false
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
	var err := dir.rename("savegame.tmp", "savegame.json")
	return err == OK

func _handle_corrupt(bad_text: String) -> void:
	push_warning("SaveManager: save file corrupt; backing up and resetting to defaults")
	var f := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(bad_text)
		f.close()
	_data = DEFAULTS.duplicate(true)

# --- Public API (mutators change memory only; caller decides when to save) ---

func coins() -> int:
	return int(_data.get("coins", 0))

func add_coins(amount: int) -> void:
	_data["coins"] = coins() + maxi(amount, 0)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins() < amount:
		return false
	_data["coins"] = coins() - amount
	return true

func best_wave() -> int:
	return int(_data.get("best_wave", 0))

func best_bosses() -> int:
	return int(_data.get("best_bosses", 0))

func record_run(wave: int, bosses: int) -> void:
	_data["best_wave"] = maxi(best_wave(), wave)
	_data["best_bosses"] = maxi(best_bosses(), bosses)
```

- [ ] **Step 2: Register the autoload**

In `project.godot`, the `[autoload]` section (after Task 3) reads:

```
[autoload]

DifficultyManager="*res://scripts/DifficultyManager.gd"
RunConfig="*res://scripts/RunConfig.gd"
RunStats="*res://scripts/RunStats.gd"
```

Add `SaveManager` so it becomes:

```
[autoload]

DifficultyManager="*res://scripts/DifficultyManager.gd"
RunConfig="*res://scripts/RunConfig.gd"
RunStats="*res://scripts/RunStats.gd"
SaveManager="*res://scripts/SaveManager.gd"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/SaveManager.gd project.godot
git commit -m "Phase 6 Spec 1: SaveManager autoload (JSON wallet + high scores)"
```

---

## Task 6: Bank the payout + show it on Game Over

**Files:**
- Modify: `scripts/GameOver.gd` (`_on_player_died`)

- [ ] **Step 1: Compute, bank, and display the payout**

In `scripts/GameOver.gd`, `_on_player_died()` currently reads:

```gdscript
func _on_player_died() -> void:
	if RunConfig.mode == "boss_rush":
		var spawner := get_tree().get_first_node_in_group("spawner")
		var n := 0
		if spawner != null:
			n = int(spawner.boss_rush_count)
		_label.text = "Bosses defeated: %d" % maxi(n - 1, 0)
	else:
		_label.text = "Wave reached: %d" % DifficultyManager.wave
	_root.visible = true
```

Replace the whole function with:

```gdscript
func _on_player_died() -> void:
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	var earned := CoinReward.payout(wave, bosses, RunStats.kills)

	SaveManager.add_coins(earned)
	SaveManager.record_run(wave, bosses)
	SaveManager.save_game()

	var result := ""
	if RunConfig.mode == "boss_rush":
		result = "Bosses defeated: %d   (best %d)" % [bosses, SaveManager.best_bosses()]
	else:
		result = "Wave reached: %d   (best %d)" % [wave, SaveManager.best_wave()]

	_label.text = "%s\nCoins earned: +%d\nTotal coins: %d" % [result, earned, SaveManager.coins()]
	_root.visible = true
```

(This banks the coins exactly once — `_on_player_died` fires on the player's one-shot `died` signal. It also replaces the old Boss-Rush `boss_rush_count - 1` off-by-one with the exact `RunStats.bosses_killed`, which counts real boss deaths in both modes.)

- [ ] **Step 2: Commit**

```bash
git add scripts/GameOver.gd
git commit -m "Phase 6 Spec 1: bank coin payout + show earnings on Game Over"
```

---

## Task 7: Show the coin balance on the main menu

**Files:**
- Modify: `scripts/MainMenu.gd` (`_build_hub`)

- [ ] **Step 1: Add a coin-balance readout to the hub**

In `scripts/MainMenu.gd`, `_build_hub()` currently reads:

```gdscript
func _build_hub() -> void:
	_hub = _make_panel()
	var vbox := _card_vbox(_hub, 20)
	_make_title(vbox, "SURVIVOR", 48)
	var tagline := Label.new()
	tagline.text = "stand still. stay alive."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(tagline, 16, PixelTheme.TEXT_DIM)
	vbox.add_child(tagline)
	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", func(): _show_only(_mode_panel)))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_only(_char_panel)))
	vbox.add_child(_make_button("INVENTORY", func(): _show_only(_inv_panel)))
```

Insert a coins label between the tagline and the spacer:

```gdscript
func _build_hub() -> void:
	_hub = _make_panel()
	var vbox := _card_vbox(_hub, 20)
	_make_title(vbox, "SURVIVOR", 48)
	var tagline := Label.new()
	tagline.text = "stand still. stay alive."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(tagline, 16, PixelTheme.TEXT_DIM)
	vbox.add_child(tagline)
	var coins := Label.new()
	coins.text = "COINS: %d" % SaveManager.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 20, PixelTheme.ACCENT)
	vbox.add_child(coins)
	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", func(): _show_only(_mode_panel)))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_only(_char_panel)))
	vbox.add_child(_make_button("INVENTORY", func(): _show_only(_inv_panel)))
```

(The menu scene is re-instanced every time you return from a run, so reading `SaveManager.coins()` in `_build_hub` is always current — no live update needed.)

- [ ] **Step 2: Commit**

```bash
git add scripts/MainMenu.gd
git commit -m "Phase 6 Spec 1: show coin balance on the main menu hub"
```

---

## Task 8: Headless compile gate

**Files:** none (verification only)

- [ ] **Step 1: Compile-check the whole project headlessly**

Run:

```bash
cd "/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64" && \
timeout 150 ./Godot_v4.6.3-stable_mono_win64_console.exe --headless \
  --path "C:\Users\thela\Documents\mobile-game" --quit-after 5 2>&1 | \
grep -iE "error|parse|invalid|nonexistent|expected|autoload" | grep -ivE "ErrorMacros" || echo "NO SCRIPT ERRORS"
```

Expected: `NO SCRIPT ERRORS` (the benign `menu_background.jpg` load line may appear — ignore only that). If any GDScript parse/type error or autoload-load error appears, fix the offending file and re-run before proceeding.

- [ ] **Step 2: Confirm no uncommitted changes remain**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && git status --porcelain
```

Expected: empty output (everything from Tasks 1–7 committed).

---

## Task 9: F5 smoke test (Larry runs in the editor)

**Files:** none (manual verification by Larry)

- [ ] **Step 1: Hand off the smoke checklist**

Larry opens the project in Godot (so it imports the new scripts/autoloads) and presses F5. Verify:

1. **Fresh balance:** main-menu hub shows `COINS: <N>` (0 on a brand-new save).
2. **Earn:** play an Endless run, die → Game Over shows three lines:
   `Wave reached: W (best …)`, `Coins earned: +X`, `Total coins: Y`,
   where `X = 10 + 5*W + 25*bosses + 1*kills`.
3. **Bank + display:** Back to Menu → hub `COINS` reflects the new total.
4. **Persist:** fully close Godot, reopen, F5 → balance and bests unchanged.
5. **High score:** beat a higher wave than before → `(best …)` rises; a worse run leaves it unchanged.
6. **Boss Rush:** a Boss Rush run shows `Bosses defeated: N (best M)` and the payout includes `25*N`.
7. **Corruption safety (optional):** edit `user://savegame.json` to garbage, relaunch → game still boots at `COINS: 0` and a `savegame.corrupt.json` appears next to it.

   (To find `user://` on Windows: `%APPDATA%\Godot\app_userdata\Mobile Game\`.)

- [ ] **Step 2: Mark Spec 1 complete**

Once the checklist passes, Phase 6 Spec 1 is done. Next: Phase 6 Spec 2 (Weapon Variants & Crates).

---

## Self-review notes

- **Spec coverage:** SaveManager (§4.1) → Task 5; RunStats (§4.2) → Tasks 3–4; CoinReward (§4.3) → Task 2; GameConfig consts (§4.4) → Task 1; integration points (§5: project.godot → Tasks 3/5, Main → Task 4, Enemy → Task 4, Boss → Task 4, GameOver → Task 6, MainMenu → Task 7); edge cases (§6: corruption/migration/atomic save) → Task 5; smoke checklist (§7) → Task 9. All spec sections mapped.
- **Type consistency:** `SaveManager.coins()/add_coins/spend_coins/best_wave/best_bosses/record_run/save_game/load_game`, `RunStats.kills/bosses_killed/reset/add_kill/add_boss`, `CoinReward.payout(wave,bosses,kills)` — names are identical across the tasks that define and call them.
- **No test runner:** GDScript has no unit-test harness wired here (project decision); verification is the headless compile gate (Task 8) + F5 smoke (Task 9), consistent with Phases 1–4.

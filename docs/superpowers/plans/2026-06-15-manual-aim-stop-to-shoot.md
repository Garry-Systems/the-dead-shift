# Manual Aim (Stop-to-Shoot) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace auto-aim+auto-fire with manual aiming — the gun fires in the player's last-faced direction when stopped (smooth 360°), and `range` is repurposed as bullet travel distance.

**Architecture:** The **Player** owns the fire direction (`_last_move_dir`) and pushes it into `Gun.aim_direction` each frame; the **Gun** stops picking targets and simply fires where it's told, while moving holds fire (stop-to-shoot). `gun_range` becomes the bullet's max travel distance. Three GDScript files change; no scenes, no new files.

**Tech Stack:** Godot 4.6 (.NET edition exe, GDScript), portrait mobile project at `C:\Users\thela\Documents\mobile-game`.

**Branch:** `feat/manual-aim` (already created off `master` @ `0efaf11`; spec committed at `c79e103`).

**Spec:** `docs/superpowers/specs/2026-06-15-manual-aim-stop-to-shoot-design.md`

---

## Testing approach for this project (read first)

This project has **no automated game-test harness in WSL** — input, visuals, and
gameplay are verified by Larry pressing **F5** in the Godot editor. What CAN be run
headlessly from WSL is the **import/compile gate**, which catches GDScript parse and
type errors. Every implementation task ends with that gate. The final task is the
human F5 smoke test.

**Headless gate command** (run from anywhere; uses absolute paths):

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path 'C:\Users\thela\Documents\mobile-game' --headless --editor --quit 2>&1 \
  | grep -iE "SCRIPT ERROR|Parse Error|ERROR|error" \
  | grep -v "menu_background.jpg"
```

**Expected (PASS):** no output (the only benign line, the `menu_background.jpg`
JPEG-decode error, is filtered out). **FAIL:** any `SCRIPT ERROR` / `Parse Error` line.

> Note: GDScript is dynamically typed at the property level here; these edits touch
> existing typed vars only, so the gate is a reliable green/red signal.

---

## Task 1: Repurpose `range` → bullet travel distance

**Files:**
- Modify: `scripts/Bullet.gd` (add `max_travel` field + distance-based despawn)
- Modify: `scripts/Gun.gd` (`_spawn_bullet` passes `max_travel = gun_range`)
- Modify: `scripts/logic/GameConfig.gd` (update `GUN_RANGE` comment)

This task is safe in isolation: auto-aim still works; bullets simply gain a travel
cap. After it, longer-range weapons/loot/relic visibly reach farther.

- [ ] **Step 1: Add `max_travel` field and `_traveled` accumulator to Bullet.gd**

In `scripts/Bullet.gd`, find the speed/damage fields near the top:

```gdscript
var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := GameConfig.BULLET_DAMAGE
```

Add `max_travel` immediately after `damage`:

```gdscript
var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := GameConfig.BULLET_DAMAGE
var max_travel := INF          # px; despawn after flying this far (set to gun_range)
```

Then find the lifetime field:

```gdscript
var _life := 0.0
var _hit: Array = []           # enemies already damaged (so pierce/ricochet don't re-hit)
```

Add a `_traveled` accumulator after `_life`:

```gdscript
var _life := 0.0
var _traveled := 0.0           # total distance flown (vs max_travel)
var _hit: Array = []           # enemies already damaged (so pierce/ricochet don't re-hit)
```

- [ ] **Step 2: Despawn the bullet once it exceeds `max_travel`**

In `scripts/Bullet.gd`, replace the whole `_physics_process`:

```gdscript
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()
```

with:

```gdscript
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_traveled += speed * delta
	if _traveled >= max_travel:
		queue_free()
		return
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()
```

- [ ] **Step 3: Pass `gun_range` into spawned bullets**

In `scripts/Gun.gd`, find `_spawn_bullet`:

```gdscript
func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = damage
	bullet.pierce_count = pierce_count
	bullet.ricochet_count = ricochet_count
```

Add the `max_travel` assignment right after `bullet.damage = damage`:

```gdscript
func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = damage
	bullet.max_travel = gun_range
	bullet.pierce_count = pierce_count
	bullet.ricochet_count = ricochet_count
```

(Leave the rest of `_spawn_bullet` unchanged.)

- [ ] **Step 4: Update the `GUN_RANGE` comment in GameConfig**

In `scripts/logic/GameConfig.gd`, change line:

```gdscript
const GUN_RANGE := 600.0              # px; ignore enemies farther than this
```

to:

```gdscript
const GUN_RANGE := 600.0              # px; bullet max travel distance
```

- [ ] **Step 5: Run the headless gate**

Run the **Headless gate command** from the top of this plan.
Expected: no output (PASS).

- [ ] **Step 6: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/Bullet.gd scripts/Gun.gd scripts/logic/GameConfig.gd
git commit -m "Manual aim: repurpose gun_range as bullet travel distance

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Manual aim core — fire in the last-faced direction

**Files:**
- Modify: `scripts/Gun.gd` (remove auto-targeting; `aim_direction` becomes an input)
- Modify: `scripts/Player.gd` (face/aim from `_last_move_dir`; push to gun; spawn-fire guard)

This is the behavioral change. Gun and Player are edited together because they are
two halves of one rewiring — splitting them would leave a non-firing intermediate.

- [ ] **Step 1: Make `Gun.aim_direction` an input (update its doc + the class doc)**

In `scripts/Gun.gd`, replace the class header (top of file):

```gdscript
class_name Gun
extends Node2D
## Auto-targets the nearest enemy in range and fires bullets on an interval.
## Holds mutable per-run stats that gun upgrade cards modify.
```

with:

```gdscript
class_name Gun
extends Node2D
## Fires bullets on an interval in the direction the Player is aiming
## (aim_direction, set externally each frame — the player's last-faced direction).
## Holds mutable per-run stats that gun upgrade cards modify.
```

Then replace the `aim_direction` declaration + its doc comment:

```gdscript
## Unit vector toward the nearest enemy (Vector2.ZERO when none in range).
## Updated every frame so the player can face who it's auto-aiming at.
var aim_direction := Vector2.ZERO
```

with:

```gdscript
## Fire direction, set by the Player each frame (the last-faced / last-move
## direction). Vector2.ZERO means "no aim yet" — the gun holds fire.
var aim_direction := Vector2.ZERO
```

- [ ] **Step 2: Rewrite `Gun._process` to fire where aimed (no targeting)**

In `scripts/Gun.gd`, replace the entire `_process` function:

```gdscript
func _process(delta: float) -> void:
	_fade_muzzle(delta)
	if _frenzy_time > 0.0:
		_frenzy_time -= delta

	# Track the nearest enemy every frame (even while reloading / between shots)
	# so aim_direction stays current for the player's facing.
	var target := _find_nearest_enemy()
	aim_direction = (target.global_position - global_position).normalized() if target != null else Vector2.ZERO

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
		return

	_cooldown -= delta
	if _cooldown > 0.0 or bullet_scene == null:
		return

	if target == null:
		return

	# Standing-still-to-shoot rule: hold fire (but keep cooldown at 0) while moving,
	# so the player fires the instant they stop.
	if hold_fire:
		return

	_fire(aim_direction)
	_cooldown = (fire_interval * (1.0 - _frenzy_mult)) if _frenzy_time > 0.0 else fire_interval
	_ammo -= 1
	if _ammo <= 0:
		_start_reload()
```

with:

```gdscript
func _process(delta: float) -> void:
	_fade_muzzle(delta)
	if _frenzy_time > 0.0:
		_frenzy_time -= delta

	# aim_direction is set by the Player each frame (the last-faced direction).
	# The gun no longer picks targets — it fires where the player is looking.

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
		return

	_cooldown -= delta
	if _cooldown > 0.0 or bullet_scene == null:
		return

	# Hold fire while moving (stop-to-shoot) or before the player has aimed.
	if hold_fire or aim_direction == Vector2.ZERO:
		return

	_fire(aim_direction)
	_cooldown = (fire_interval * (1.0 - _frenzy_mult)) if _frenzy_time > 0.0 else fire_interval
	_ammo -= 1
	if _ammo <= 0:
		_start_reload()
```

- [ ] **Step 3: Delete the now-unused `_find_nearest_enemy` from Gun.gd**

In `scripts/Gun.gd`, delete this entire function:

```gdscript
func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var points: Array[Vector2] = []
	for z in enemies:
		points.append((z as Node2D).global_position)

	var idx := TargetSelector.nearest_index_in_range(global_position, points, gun_range)
	if idx < 0:
		return null
	return enemies[idx] as Node2D
```

(`scripts/logic/TargetSelector.gd` is now unused by anything — leave the file in
place; it is harmless and removing it is unnecessary churn. `gun_range` is still
used by `apply_loot` / upgrades / the Long Scope relic and is now the bullet travel
cap from Task 1.)

- [ ] **Step 4: Add a `_has_moved` spawn-fire guard to Player.gd**

In `scripts/Player.gd`, find:

```gdscript
var _last_move_dir := Vector2.RIGHT
var _last_tap_time := -999.0
var _is_dead := false
```

Add `_has_moved` after `_last_move_dir`:

```gdscript
var _last_move_dir := Vector2.RIGHT
var _has_moved := false          # true after the first move input (gates spawn fire)
var _last_tap_time := -999.0
var _is_dead := false
```

- [ ] **Step 5: Rewire Player facing + gun drive to the last-faced direction**

In `scripts/Player.gd`, inside `_physics_process`, replace this block:

```gdscript
	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()

	# Face the enemy we're auto-aiming at; fall back to movement direction.
	var face_dir: Vector2 = gun.aim_direction if (gun != null and gun.aim_direction != Vector2.ZERO) else dir
	if face_dir != Vector2.ZERO:
		_face(face_dir)

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else move_speed
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed

	# Shoot-only-while-still rule: tell the gun to hold fire whenever we're moving
	# (or dashing). It keeps aiming/facing — it just won't pull the trigger.
	if gun != null:
		gun.hold_fire = GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO
```

with:

```gdscript
	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		_has_moved = true

	# Aim = facing = the last direction we moved. The sprite snaps to the nearest
	# of 8 poses; the gun fires at the precise angle (smooth 360 aim).
	_face(_last_move_dir)

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else move_speed
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed

	# Drive the gun: fire in our faced direction, but hold fire while moving
	# (stop-to-shoot) and until the player has given a first move input (so we
	# don't auto-empty the mag facing right at spawn).
	if gun != null:
		gun.aim_direction = _last_move_dir
		gun.hold_fire = (GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO) or not _has_moved
```

(Keeping the `SHOOT_ONLY_WHILE_STILL` reference means the const still works as a
toggle: set it `false` to also fire while moving, in the move direction — a free
run-and-gun mode. Default `true` = stop-to-shoot.)

- [ ] **Step 6: Run the headless gate**

Run the **Headless gate command** from the top of this plan.
Expected: no output (PASS).

- [ ] **Step 7: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/Gun.gd scripts/Player.gd
git commit -m "Manual aim: fire in last-faced direction, drop auto-target

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: F5 smoke test (Larry)

**This task is run by Larry in the Godot editor — agents cannot drive input/visuals.**

To reach combat fast, optionally set `GameConfig.WAVE_DURATION := 6.0` temporarily,
then restore to `30.0` afterward.

- [ ] **Step 1: Open Godot (auto-imports) and press F5.** Reach a run (PLAY → mode → CLOCKING IN → Main).

- [ ] **Step 2: Movement holds fire.** While moving in any direction, the gun does NOT fire; Ryan's sprite faces the move direction.

- [ ] **Step 3: Stop = fire in last-faced direction.** The instant you stop, the gun fires continuously in the direction you were last heading, at the weapon's fire rate, draining the mag and auto-reloading on empty.

- [ ] **Step 4: Smooth 360 aim.** Face a precise diagonal between two enemies, stop, and the shot goes exactly there (sprite shows the nearest of 8 poses, shot is precise).

- [ ] **Step 5: You can miss.** Face empty space and stop — the gun fires into nothing (wastes ammo). Confirms targeting is gone.

- [ ] **Step 6: Spawn guard.** Right after the run starts, standing still without input, the gun does NOT fire until you move once.

- [ ] **Step 7: Dash unchanged.** Double-tap dashes; you do not shoot mid-dash; after the dash ends and you stop, firing resumes in the faced direction.

- [ ] **Step 8: Range reaches farther.** Equip/roll a longer-range weapon (or grab the Long Scope relic) and confirm bullets travel visibly farther before despawning; a short-range weapon fizzles sooner.

- [ ] **Step 9: Desktop parity (optional).** Release WASD → fire in the last-held direction; mouse is not needed to aim.

- [ ] **Step 10: Restore `WAVE_DURATION` to `30.0`** if you changed it, and commit that restore if needed.

**After F5 passes:** merge to master — `git checkout master && git merge feat/manual-aim`
(fast-forward, since the branch is off `master`). Then the out-of-scope follow-ups
(boss/enemy rebalancing for manual aim, optional aim-assist knob) can be scoped
separately.
```

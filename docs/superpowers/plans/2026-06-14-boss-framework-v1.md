# Boss Framework v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single hardcoded brute boss with a reusable phase/pattern engine (`BossBase` + a 6-pattern shelf) so any new boss = one phase table + maybe one new pattern; validate by porting the brute (parity) and shipping 2 new showcase bosses.

**Architecture:** A boss is a `CharacterBody2D` extending `BossBase` (carries stats/health/flash/burn/contact/chase/death-reward + a phase→pattern engine). Each boss subclass only overrides `_build_phases()`. Attack patterns are world `Node2D`s extending `AttackPattern` (telegraph → execute → free, distance-based hit detection — no Area2D). Patterns are referenced via a `Patterns` constant registry; bosses are picked at random (no immediate repeat) via a `Bosses` registry that the `Spawner` calls.

**Tech Stack:** Godot 4.6 + GDScript (no build step). Branch: `feat/boss-framework` (already merged up to master `0efaf11`).

---

## THE COMPILE GATE (run at the end of every task)

There is no Godot CLI runner in WSL for GUT and autoloads don't load in `--script` mode, so this project's verified per-task gate is the **headless editor import** (catches every parse/type error). Each task's final verification step runs:

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --quit 2>&1 \
  | grep -iE "error|parse|expected|identifier|not found|invalid" \
  | grep -v "menu_background.jpg"
```

**Expected output: empty** (the only known-benign line is the `menu_background.jpg` JPEG-decode warning, which the `grep -v` strips). Any other line = a real error to fix before committing.

## Layout created by this plan

```
scripts/
  BossBase.gd            (new) class_name BossBase — engine + carried-over brute behavior
  BossProjectile.gd      (new) enemy-side hazard (distance-hits the player)
  patterns/
    AttackPattern.gd     (new) class_name AttackPattern — telegraph/execute/free base
    ExpandingRing.gd     (new) SlamWave port (brute parity)
    AimedBand.gd         (new) snapped beam
    ZoneFill.gd          (new) acid/fire puddle
    ProjectileEmitter.gd (new) fan/ring/spiral/aimed projectile burst
    SummonSpawner.gd     (new) spawns Enemy adds (decoy = auto-aim steal)
    DebuffApplier.gd     (new) gun-jam / move-slow on the player
  bosses/
    Brute.gd             (new) parity port
    BroodMother.gd       (new) summon + zone + emitter
    HeatTyrant.gd        (new) debuff + band + ring
  logic/
    Patterns.gd          (new) class_name Patterns — preloaded pattern scene registry
    Bosses.gd            (new) class_name Bosses — boss registry + pick(last_id)
scenes/
  BossProjectile.tscn    (new)
  patterns/{ExpandingRing,AimedBand,ZoneFill,ProjectileEmitter,SummonSpawner,DebuffApplier}.tscn (new)
  bosses/{Brute,BroodMother,HeatTyrant}.tscn (new)
```

**Modified:** `scripts/logic/GameConfig.gd`, `scripts/Player.gd`, `scripts/Spawner.gd`, `scripts/Hud.gd`, `scenes/Main.tscn`.
**Removed (final task):** `scripts/Boss.gd`, `scripts/SlamWave.gd`, `scenes/Boss.tscn`, `scenes/SlamWave.tscn` (+ their `.uid`/`.import`).

## Deviations from the spec (deliberate — read before starting)

- **Contact damage uses `_touching_player()`** (a `get_slide_collision()` check), NOT the spec's "60px range". The 2026-06-14 contact-damage fix changed `Boss.gd` after the spec was written; `BossBase` carries the fixed version forward.
- **`Hud.gd:145` must change** `(boss as Boss)` → `(boss as BossBase)`. The spec claimed nothing referenced `class_name Boss`; this line does and would fail to compile once `Boss.gd` is deleted. (Task 17.)
- **No per-boss color tints.** The spec wanted red/green/orange bosses, but the locked 4-color palette (`reference_survivor_palette`) makes all enemies/bosses C3 (white `base_tint` over the C3 enemy sprite). The 3 bosses are differentiated by **scale + moveset** (and the HP bar), not color. Dedicated boss sprites are the natural follow-up. `BossBase` exposes a `_base_tint()` hook (default white) so a future per-boss tint/sprite is a one-liner.
- **Telegraphs stay warm (orange/red/green danger colors), not palette-collapsed.** They're transient functional signaling (same exemption logic as the loot rarity colors), and the ported brute slam must keep its exact orange look for parity.
- **First-pattern delay:** the old brute waited a full `SLAM_INTERVAL` (4s) before its first slam. `BossBase` casts its first pattern after `BOSS_FIRST_CAST_DELAY` (1.0s, tunable) instead — better feel when a boss appears. Flagged in the smoke checklist so Larry can revert by setting `BOSS_FIRST_CAST_DELAY := GameConfig.SLAM_INTERVAL` if he wants exact parity.

---

### Task 1: GameConfig — boss-framework constants

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (append a new block at the end of the file)

- [ ] **Step 1: Append the new constant block**

Add to the very end of `scripts/logic/GameConfig.gd` (after the coins block, line 104):

```gdscript

# --- Boss framework v1 ---
const BOSS_FIRST_CAST_DELAY := 1.0     # seconds before a boss's first pattern after spawn/phase-enter
const PATTERN_WINDUP_MIN := 0.5        # telegraph readability clamp (min seconds)
const PATTERN_WINDUP_MAX := 1.2        # telegraph readability clamp (max seconds)
const AIMED_BAND_THICKNESS := 26.0     # px half-width of an AimedBand's damaging segment
const AIMED_BAND_ACTIVE := 0.15        # seconds an AimedBand stays damaging after the telegraph
const AIMED_BAND_DAMAGE := 30.0        # default AimedBand hit damage
const AIMED_BAND_LENGTH := 1100.0      # px default beam length (crosses the 1080x1920 portrait view)
const BOSS_PROJECTILE_SPEED := 200.0   # px/sec for ProjectileEmitter hazards
const BOSS_PROJECTILE_DAMAGE := 12.0   # flat damage a boss projectile deals on hit
const BOSS_PROJECTILE_LIFETIME := 3.0  # seconds before a boss projectile despawns
const ZONE_DEFAULT_RADIUS := 90.0      # px default ZoneFill radius
const ZONE_DEFAULT_DPS := 18.0         # ZoneFill damage/sec while the player stands in it
const ZONE_DEFAULT_DURATION := 4.0     # seconds a ZoneFill puddle persists
const DEBUFF_JAM_DURATION := 2.0       # default gun-jam length (seconds)
const DEBUFF_SLOW_FACTOR := 0.5        # default move-speed cut (0.5 = half speed)
const DEBUFF_SLOW_DURATION := 2.5      # default slow length (seconds)

# Brood Mother
const BROOD_HP := 2200.0               # wave-1 HP (scales with wave like the brute)
const BROOD_SUMMON_COUNT := 3          # adds spawned per summon cast
const BROOD_ZONE_DPS := 18.0           # acid-nest damage/sec
const BROOD_RING_COUNT := 8            # projectiles in the radial spit

# Heat Tyrant
const HEAT_HP := 1900.0                # wave-1 HP
const HEAT_BAND_DAMAGE := 30.0         # solar-flare beam damage
const HEAT_JAM_DURATION := 2.0         # "Forced Vent" gun-jam length
```

- [ ] **Step 2: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/logic/GameConfig.gd
git commit -m "Boss framework: GameConfig constants (patterns/projectile/debuff/bosses)"
```

---

### Task 2: Player — debuff hooks (fire-lock + external slow)

Adds the `apply_fire_lock` / `apply_slow` hooks the `DebuffApplier` pattern needs. **Must not regress** the existing shoot-only-while-still or dash behavior when no debuff is active (with `_fire_lock_time <= 0` and `_ext_slow_factor == 1.0`, every line below is identical to today).

**Files:**
- Modify: `scripts/Player.gd`

- [ ] **Step 1: Add the debuff state vars**

In `scripts/Player.gd`, after the line `var _facing := 2 ...` (line 52), add:

```gdscript
var _fire_lock_time := 0.0   # boss "jam" debuff: gun can't fire while > 0
var _ext_slow_factor := 1.0  # boss "slow" debuff: move-speed multiplier (1.0 = none)
var _ext_slow_time := 0.0
```

- [ ] **Step 2: Decay the debuff timers each physics frame**

In `_physics_process`, the current top is:

```gdscript
func _physics_process(delta: float) -> void:
	_dash.tick(delta)
	if _flash_cd > 0.0:
		_flash_cd -= delta
```

Replace it with:

```gdscript
func _physics_process(delta: float) -> void:
	_dash.tick(delta)
	if _flash_cd > 0.0:
		_flash_cd -= delta
	if _fire_lock_time > 0.0:
		_fire_lock_time -= delta
	if _ext_slow_time > 0.0:
		_ext_slow_time -= delta
		if _ext_slow_time <= 0.0:
			_ext_slow_factor = 1.0
```

- [ ] **Step 3: Apply the slow to move speed**

Find this line in `_physics_process`:

```gdscript
	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else move_speed
```

Replace with (dash speed is intentionally NOT slowed, so dashing always escapes a slow):

```gdscript
	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else (move_speed * _ext_slow_factor)
```

- [ ] **Step 4: Apply the fire-lock to the gun's hold-fire**

Find:

```gdscript
	if gun != null:
		gun.hold_fire = GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO
```

Replace with:

```gdscript
	if gun != null:
		gun.hold_fire = (GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO) or _fire_lock_time > 0.0
```

- [ ] **Step 5: Add the two public hooks**

After `upgrade_pickup_radius` (the last function, line ~222), append:

```gdscript

## --- Boss debuff hooks (called by the DebuffApplier pattern) ---

## "Jam": the gun can't fire for `duration`s even while standing still. Longest wins.
func apply_fire_lock(duration: float) -> void:
	_fire_lock_time = maxf(_fire_lock_time, duration)

## "Slow": cut move speed by `factor` (0..1) for `duration`s. Strongest/longest wins.
func apply_slow(factor: float, duration: float) -> void:
	_ext_slow_factor = minf(_ext_slow_factor, clampf(1.0 - factor, 0.1, 1.0))
	_ext_slow_time = maxf(_ext_slow_time, duration)
```

- [ ] **Step 6: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 7: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/Player.gd
git commit -m "Boss framework: Player fire-lock + slow debuff hooks (no-regress)"
```

---

### Task 3: AttackPattern base class

The generalized SlamWave lifecycle: created in the world by a boss, draws a telegraph during a windup, fires once when the telegraph ends, runs an active phase, frees itself.

**Files:**
- Create: `scripts/patterns/AttackPattern.gd`

- [ ] **Step 1: Write the base class**

```gdscript
class_name AttackPattern
extends Node2D
## Base class for boss attack patterns. BossBase instantiates one of these into the world,
## positions it at the boss, then calls setup(). It draws its own telegraph during a windup,
## fires once when the telegraph ends, runs an active phase, then frees itself. Hit detection
## is distance-based (matching SlamWave/Enemy/Boss) — no Area2D / collision layers needed.

var boss: Node2D
var player: Node2D
var params: Dictionary = {}
var _windup := 0.8
var _aim_point := Vector2.ZERO   # player position snapshotted at telegraph start; dodge = move during windup
var _fired := false

## Called by BossBase immediately after add_child + positioning. Subclasses override and
## MUST call super.setup() first (it snapshots the aim point and clamps the windup).
func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	boss = b
	player = p
	params = cfg
	_windup = clampf(float(cfg.get("windup", 0.8)), GameConfig.PATTERN_WINDUP_MIN, GameConfig.PATTERN_WINDUP_MAX)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	_aim_point = player.global_position if (player != null and is_instance_valid(player)) else global_position

func _process(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		queue_redraw()
		if _windup <= 0.0:
			_fired = true
			_on_telegraph_end()
		return
	_active(delta)
	queue_redraw()

## One-shot when the telegraph ends (spawn the hit / emit / apply the debuff). Override.
func _on_telegraph_end() -> void:
	pass

## Per-frame after the telegraph; the subclass frees itself when done. Override.
func _active(_delta: float) -> void:
	pass

## Telegraph (during windup) + active visuals. Override.
func _draw() -> void:
	pass
```

- [ ] **Step 2: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/AttackPattern.gd
git commit -m "Boss framework: AttackPattern base (telegraph/execute/free lifecycle)"
```

---

### Task 4: BossProjectile (hazard the player can't shoot)

The existing `Bullet` only hits the `enemies` group, so bosses need their own projectile. A `Node2D` that travels, distance-hits the player once, and frees. NOT in the `enemies` group (not shootable).

**Files:**
- Create: `scripts/BossProjectile.gd`
- Create: `scenes/BossProjectile.tscn`

- [ ] **Step 1: Write the script**

`scripts/BossProjectile.gd`:

```gdscript
extends Node2D
## A boss-side hazard projectile. Travels in a direction, distance-checks the player each
## frame, deals flat `damage` once on contact, then frees. Also frees on lifetime. It is
## NOT in the "enemies" group (the player's bullets must not destroy it). Set up by
## ProjectileEmitter via setup().

const HIT_RADIUS := 22.0   # px contact radius against the player

var direction := Vector2.RIGHT
var speed := GameConfig.BOSS_PROJECTILE_SPEED
var damage := GameConfig.BOSS_PROJECTILE_DAMAGE

var _player: Node2D
var _life := 0.0

## Called by ProjectileEmitter right after add_child + positioning.
func setup(dir: Vector2, spd: float, dmg: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BOSS_PROJECTILE_LIFETIME:
		queue_free()
		return
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= HIT_RADIUS:
			_player.take_damage(damage)
			queue_free()

func _draw() -> void:
	# C3 (threat) hazard dot. Distinct from the player's C4 bullets.
	draw_circle(Vector2.ZERO, 8.0, Color(0.549, 0.522, 0.451, 1.0))
```

- [ ] **Step 2: Write the scene**

`scenes/BossProjectile.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/BossProjectile.gd" id="1"]

[node name="BossProjectile" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/BossProjectile.gd scenes/BossProjectile.tscn
git commit -m "Boss framework: BossProjectile (distance-hits the player, not shootable)"
```

---

### Task 5: ExpandingRing pattern (SlamWave port — brute parity)

A pixel-identical refactor of `SlamWave.gd` into the pattern shelf. With the brute passing the `SLAM_*` consts, this reproduces the old slam exactly.

**Files:**
- Create: `scripts/patterns/ExpandingRing.gd`
- Create: `scenes/patterns/ExpandingRing.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/ExpandingRing.gd`:

```gdscript
class_name ExpandingRing
extends AttackPattern
## A ground-slam shockwave (the SlamWave port). Telegraph = a faint filled circle at the
## full radius; then a drawn ring expands 0 -> radius; the player takes `damage` once if
## caught by the ring's leading band. Frees itself when fully expanded. Dash is the counter.

const BAND_THICKNESS := 28.0   # px width of the damaging leading edge (matches SlamWave)

var _radius := 0.0
var _max_radius := 220.0
var _expand_time := 0.5
var _damage := 35.0
var _hit_player := false

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_max_radius = float(cfg.get("radius", GameConfig.SLAM_RADIUS))
	_expand_time = float(cfg.get("expand_time", GameConfig.SLAM_EXPAND_TIME))
	_damage = float(cfg.get("damage", GameConfig.SLAM_DAMAGE))

func _active(delta: float) -> void:
	var grow_rate := _max_radius / _expand_time
	_radius += grow_rate * delta
	_check_hit()
	if _radius >= _max_radius:
		queue_free()

func _check_hit() -> void:
	if _hit_player or player == null or not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist <= _radius and dist >= _radius - BAND_THICKNESS:
		_hit_player = true
		player.take_damage(_damage)

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, _max_radius, Color(1.0, 0.3, 0.1, 0.15))
		return
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.1, 0.85), 6.0)
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/ExpandingRing.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/ExpandingRing.gd" id="1"]

[node name="ExpandingRing" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/ExpandingRing.gd scenes/patterns/ExpandingRing.tscn
git commit -m "Boss framework: ExpandingRing pattern (SlamWave port, brute parity)"
```

---

### Task 6: AimedBand pattern (snapped beam)

A line snapped through the aim point at telegraph end. Telegraph = a thin bright warning line; then a thick beam is damaging for `active_time`; the player is hit once if within `thickness` of the segment. Dodge = step off the line during the windup.

**Files:**
- Create: `scripts/patterns/AimedBand.gd`
- Create: `scenes/patterns/AimedBand.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/AimedBand.gd`:

```gdscript
class_name AimedBand
extends AttackPattern
## A snapped beam. Telegraph = a thin bright line from the boss through the aim point; on
## telegraph end the beam becomes damaging for `active_time`. The player is hit once if
## within `thickness` of the segment. Dodge = step off the line during the windup.

var _length := 1100.0
var _thickness := 26.0
var _damage := 30.0
var _active_time := 0.15
var _time_left := 0.0
var _hit_player := false
var _dir := Vector2.RIGHT

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_length = float(cfg.get("length", GameConfig.AIMED_BAND_LENGTH))
	_thickness = float(cfg.get("thickness", GameConfig.AIMED_BAND_THICKNESS))
	_damage = float(cfg.get("damage", GameConfig.AIMED_BAND_DAMAGE))
	_active_time = float(cfg.get("active_time", GameConfig.AIMED_BAND_ACTIVE))

func _on_telegraph_end() -> void:
	var aim := _aim_point - global_position
	_dir = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	_time_left = _active_time

func _active(delta: float) -> void:
	_check_hit()
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _check_hit() -> void:
	if _hit_player or player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var proj := to_player.dot(_dir)
	if proj < 0.0 or proj > _length:
		return
	var perp := (to_player - _dir * proj).length()
	if perp <= _thickness:
		_hit_player = true
		player.take_damage(_damage)

func _draw() -> void:
	var aim := _aim_point - global_position
	var d := aim.normalized() if aim.length() > 0.001 else _dir
	if _windup > 0.0:
		draw_line(Vector2.ZERO, d * _length, Color(1.0, 0.85, 0.2, 0.5), 3.0)
		return
	draw_line(Vector2.ZERO, _dir * _length, Color(1.0, 0.4, 0.1, 0.9), _thickness)
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/AimedBand.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/AimedBand.gd" id="1"]

[node name="AimedBand" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/AimedBand.gd scenes/patterns/AimedBand.tscn
git commit -m "Boss framework: AimedBand pattern (snapped beam)"
```

---

### Task 7: ZoneFill pattern (acid/fire puddle)

A puddle at the boss, the aim point, or an offset. Telegraph = a filled circle; on telegraph end it becomes a damaging zone for `duration`, ticking `dps` while the player stands in it.

**Files:**
- Create: `scripts/patterns/ZoneFill.gd`
- Create: `scenes/patterns/ZoneFill.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/ZoneFill.gd`:

```gdscript
class_name ZoneFill
extends AttackPattern
## An acid/fire puddle. Telegraph = a filled circle at a target point ("boss" = where it
## spawned, "player" = the aim point, plus an optional `offset`). On telegraph end it becomes
## a damaging zone for `duration`, ticking `dps` to the player while inside. Denies the
## "stand still and fire" spots the player relies on.

var _radius := 90.0
var _dps := 18.0
var _duration := 4.0
var _time_left := 0.0
var _armed := false

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_radius = float(cfg.get("radius", GameConfig.ZONE_DEFAULT_RADIUS))
	_dps = float(cfg.get("dps", GameConfig.ZONE_DEFAULT_DPS))
	_duration = float(cfg.get("duration", GameConfig.ZONE_DEFAULT_DURATION))
	var at := String(cfg.get("at", "boss"))
	if at == "player":
		global_position = _aim_point
	if cfg.has("offset"):
		global_position += cfg["offset"]

func _on_telegraph_end() -> void:
	_armed = true
	_time_left = _duration

func _active(delta: float) -> void:
	if not _armed:
		return
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= _radius:
			player.take_damage(_dps * delta)
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, _radius, Color(0.4, 1.0, 0.2, 0.18))
		return
	draw_circle(Vector2.ZERO, _radius, Color(0.4, 0.9, 0.2, 0.35))
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/ZoneFill.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/ZoneFill.gd" id="1"]

[node name="ZoneFill" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/ZoneFill.gd scenes/patterns/ZoneFill.tscn
git commit -m "Boss framework: ZoneFill pattern (acid/fire puddle)"
```

---

### Task 8: ProjectileEmitter pattern

Emits `BossProjectile`s in a shape: `"fan"`, `"ring"`, `"spiral"`, or `"aimed"`. Telegraph = a charge glyph on the boss.

**Files:**
- Create: `scripts/patterns/ProjectileEmitter.gd`
- Create: `scenes/patterns/ProjectileEmitter.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/ProjectileEmitter.gd`:

```gdscript
class_name ProjectileEmitter
extends AttackPattern
## Emits BossProjectile hazards. Telegraph = a charge glyph on the boss. On telegraph end
## it emits `count` projectiles in a `pattern` shape:
##   "aimed"  — one shot at the aim point
##   "fan"    — `count` shots spread across `arc`, centered on the aim point
##   "ring"   — `count` shots evenly around the full circle
##   "spiral" — `count` shots emitted over `active`s, each rotated by `spin` from the last

const PROJECTILE_SCENE := preload("res://scenes/BossProjectile.tscn")

var _count := 8
var _pattern := "ring"
var _arc := PI
var _speed := 200.0
var _damage := 0.0
var _spin := 0.4
var _active_time := 1.0
var _base_angle := 0.0
var _emitted := 0
var _emit_clock := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_count = int(cfg.get("count", 8))
	_pattern = String(cfg.get("pattern", "ring"))
	_arc = float(cfg.get("arc", PI))
	_speed = float(cfg.get("speed", GameConfig.BOSS_PROJECTILE_SPEED))
	_damage = float(cfg.get("damage", GameConfig.BOSS_PROJECTILE_DAMAGE))
	_spin = float(cfg.get("spin", 0.4))
	_active_time = float(cfg.get("active", 1.0))

func _on_telegraph_end() -> void:
	_base_angle = (_aim_point - global_position).angle()
	if _pattern == "spiral":
		return   # spiral emits over time in _active
	_emit_burst()

func _emit_burst() -> void:
	match _pattern:
		"aimed":
			_spawn(_base_angle)
		"fan":
			for i in _count:
				var t := 0.0 if _count <= 1 else float(i) / float(_count - 1)
				_spawn(_base_angle + lerpf(-_arc * 0.5, _arc * 0.5, t))
		_:   # "ring"
			for i in _count:
				_spawn(_base_angle + TAU * float(i) / float(maxi(_count, 1)))

func _spawn(angle: float) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	proj.setup(Vector2.from_angle(angle), _speed, _damage)

func _active(delta: float) -> void:
	if _pattern != "spiral":
		queue_free()   # burst shapes are one-shot
		return
	_emit_clock -= delta
	if _emit_clock <= 0.0 and _emitted < _count:
		_emit_clock = _active_time / float(maxi(_count, 1))
		_spawn(_base_angle + _spin * float(_emitted))
		_emitted += 1
	if _emitted >= _count:
		queue_free()

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.6, 0.1, 0.4))
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/ProjectileEmitter.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/ProjectileEmitter.gd" id="1"]

[node name="ProjectileEmitter" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/ProjectileEmitter.gd scenes/patterns/ProjectileEmitter.tscn
git commit -m "Boss framework: ProjectileEmitter pattern (fan/ring/spiral/aimed)"
```

---

### Task 9: SummonSpawner pattern

Spawns `Enemy` adds. Telegraph = faint circles where adds will appear. `decoy: true` spawns them right next to the player so the player's nearest-target auto-aim locks onto them (the auto-aim-steal mechanic).

**Files:**
- Create: `scripts/patterns/SummonSpawner.gd`
- Create: `scenes/patterns/SummonSpawner.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/SummonSpawner.gd`:

```gdscript
class_name SummonSpawner
extends AttackPattern
## Spawns Enemy adds. Telegraph = faint circles where the adds will appear. On telegraph
## end it spawns `count` enemies using the current wave's stats (optionally * hp_mult).
## decoy = true spawns them right next to the player so the player's nearest-target auto-aim
## locks onto them instead of the boss (the auto-aim-steal mechanic). Enemy.tscn already
## carries its own xp_gem_scene export, so adds drop XP like normal enemies.

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

var _count := 3
var _decoy := false
var _hp_mult := 1.0
var _spots: Array[Vector2] = []

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_count = int(cfg.get("count", 3))
	_decoy = bool(cfg.get("decoy", false))
	_hp_mult = float(cfg.get("hp_mult", 1.0))
	_compute_spots()

func _compute_spots() -> void:
	_spots.clear()
	var center := _aim_point if _decoy else global_position
	for i in _count:
		var a := TAU * float(i) / float(maxi(_count, 1))
		var r := randf_range(40.0, 90.0) if _decoy else randf_range(60.0, 140.0)
		_spots.append(center + Vector2(cos(a), sin(a)) * r)

func _on_telegraph_end() -> void:
	for spot in _spots:
		var stats := DifficultyManager.enemy_stats()
		stats["max_health"] = float(stats["max_health"]) * _hp_mult
		var e = ENEMY_SCENE.instantiate()
		e.configure(stats)
		get_tree().current_scene.add_child(e)
		e.global_position = spot
	queue_free()

func _draw() -> void:
	if _windup <= 0.0:
		return
	for spot in _spots:
		draw_circle(to_local(spot), 22.0, Color(0.6, 0.2, 0.8, 0.25))
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/SummonSpawner.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/SummonSpawner.gd" id="1"]

[node name="SummonSpawner" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/SummonSpawner.gd scenes/patterns/SummonSpawner.tscn
git commit -m "Boss framework: SummonSpawner pattern (adds + decoy auto-aim steal)"
```

---

### Task 10: DebuffApplier pattern

Attacks the control scheme. Follows the player so its aura stays on them. Telegraph = a colored ring around the player; on telegraph end it applies a `"jam"` (gun-lock) or `"slow"` debuff for `duration`, keeping a pulsing aura while active.

**Files:**
- Create: `scripts/patterns/DebuffApplier.gd`
- Create: `scenes/patterns/DebuffApplier.tscn`

- [ ] **Step 1: Write the script**

`scripts/patterns/DebuffApplier.gd`:

```gdscript
class_name DebuffApplier
extends AttackPattern
## Attacks the control scheme. Repositions onto the player every frame so its visuals
## follow them. Telegraph = a colored ring around the player. On telegraph end it applies a
## debuff for `duration`s: "jam" -> player.apply_fire_lock (no firing even while still),
## "slow" -> player.apply_slow. Keeps a pulsing aura (red = jam, blue = slow) while active.

var _kind := "jam"
var _duration := 2.0
var _factor := 0.5
var _time_left := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_kind = String(cfg.get("kind", "jam"))
	_duration = float(cfg.get("duration", GameConfig.DEBUFF_JAM_DURATION))
	_factor = float(cfg.get("factor", GameConfig.DEBUFF_SLOW_FACTOR))

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		global_position = player.global_position   # aura/telegraph follows the player
	super._process(delta)

func _on_telegraph_end() -> void:
	_time_left = _duration
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	if _kind == "slow":
		player.apply_slow(_factor, _duration)
	else:
		player.apply_fire_lock(_duration)

func _active(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	var col := Color(1.0, 0.2, 0.2, 0.5) if _kind == "jam" else Color(0.3, 0.5, 1.0, 0.5)
	if _windup > 0.0:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, col, 3.0)
		return
	draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, col, 5.0)
```

- [ ] **Step 2: Write the scene**

`scenes/patterns/DebuffApplier.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/DebuffApplier.gd" id="1"]

[node name="DebuffApplier" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/patterns/DebuffApplier.gd scenes/patterns/DebuffApplier.tscn
git commit -m "Boss framework: DebuffApplier pattern (gun-jam / move-slow)"
```

---

### Task 11: Patterns registry

A `class_name` registry that preloads each pattern scene as a constant, so phase tables reference `Patterns.RING` etc. without per-boss `@export` wiring (mirrors `Weapons.gd`/`Relics.gd`). All six pattern scenes from Tasks 5–10 must exist first.

**Files:**
- Create: `scripts/logic/Patterns.gd`

- [ ] **Step 1: Write the registry**

```gdscript
class_name Patterns
## Registry of boss attack-pattern scenes, preloaded so phase tables can reference them as
## Patterns.RING / Patterns.BAND / ... without per-boss @export wiring. Mirrors the
## data-registry style of Weapons.gd and Relics.gd.

const RING := preload("res://scenes/patterns/ExpandingRing.tscn")
const BAND := preload("res://scenes/patterns/AimedBand.tscn")
const ZONE := preload("res://scenes/patterns/ZoneFill.tscn")
const EMITTER := preload("res://scenes/patterns/ProjectileEmitter.tscn")
const SUMMON := preload("res://scenes/patterns/SummonSpawner.tscn")
const DEBUFF := preload("res://scenes/patterns/DebuffApplier.tscn")
```

- [ ] **Step 2: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/logic/Patterns.gd
git commit -m "Boss framework: Patterns scene registry"
```

---

### Task 12: BossBase — engine + carried-over brute behavior

Extracts everything generic from `Boss.gd` (stats/health/flash/burn/contact/chase/death-reward) and adds the phase/pattern engine. `Boss.gd` is left untouched this task (deleted in Task 17) so the project stays runnable.

**Files:**
- Create: `scripts/BossBase.gd`

- [ ] **Step 1: Write the base class**

```gdscript
class_name BossBase
extends CharacterBody2D
## Base class for all bosses. Carries the generic boss behavior (scaled stats, health, hit
## flash, incendiary burn, contact damage, chase, death reward) AND a phase/pattern engine.
## A concrete boss is just a .tscn (Sprite + Collision + the two scene exports) plus a script
## that overrides _build_phases(). It is in the "enemies" group (bullets/auto-aim hit it) and
## the "boss" group (the HUD shows its health bar).

const FLASH_SHADER := preload("res://shaders/flash.gdshader")

@export var xp_gem_scene: PackedScene
@export var relic_pickup_scene: PackedScene

var max_health := GameConfig.BOSS_BASE_HP
var move_speed := GameConfig.BOSS_MOVE_SPEED
var touch_damage := GameConfig.BOSS_TOUCH_DAMAGE

var _health: Health
var _target: Player
var _burn_dps := 0.0
var _burn_time := 0.0
var _flash_mat: ShaderMaterial

# --- Phase / pattern engine ---
var phases: Array = []     # built by _build_phases(); phases[0].at must be 1.0
var _phase_idx := -1
var _speed_mult := 1.0
var _pat_clock := 0.0      # counts down to the next pattern cast
var _pat_i := 0            # round-robin index into the current phase's patterns

## Bakes scaled stats at spawn (called by the Spawner). Applies the per-boss HP multiplier.
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"]) * _hp_mult()
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	_health = Health.new(max_health)

## Per-boss HP multiplier on the wave-scaled base (1.0 = the brute). Override per boss.
func _hp_mult() -> float:
	return 1.0

## Per-boss base flash tint (default white = show the C3 enemy art). Override to recolor.
func _base_tint() -> Color:
	return Color(1.0, 1.0, 1.0, 1.0)

## Override per boss: returns the phase table. Each entry is a Dictionary:
##   { "at": float,           # enter when health_fraction() <= at; phases[0].at MUST be 1.0
##     "patterns": Array,     # entries: { "scene": PackedScene, "params": Dictionary }
##     "cadence": float,      # seconds between casts (default 4.0)
##     "speed_mult": float,   # chase-speed multiplier this phase (default 1.0)
##     "on_enter": Callable } # optional one-shot when the phase begins
func _build_phases() -> Array:
	return []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:
		_health = Health.new(max_health)
	_setup_flash()
	phases = _build_phases()
	_enter_phase(0)

func _enter_phase(i: int) -> void:
	if i < 0 or i >= phases.size():
		return
	_phase_idx = i
	var ph: Dictionary = phases[i]
	_speed_mult = float(ph.get("speed_mult", 1.0))
	_pat_i = 0
	_pat_clock = float(ph.get("first_delay", GameConfig.BOSS_FIRST_CAST_DELAY))
	var cb = ph.get("on_enter", null)
	if cb is Callable and cb.is_valid():
		cb.call()

func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("base_tint", _base_tint())
	spr.material = _flash_mat

func flash_hit() -> void:
	if _flash_mat == null:
		return
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.12)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func ignite(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)

func _physics_process(delta: float) -> void:
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta)
		if not is_instance_valid(self):
			return

	if _target == null or not is_instance_valid(_target):
		return

	# Advance through phases whose threshold we've crossed (while, in case of a big burst).
	while _phase_idx + 1 < phases.size() and health_fraction() <= float(phases[_phase_idx + 1].get("at", 0.0)):
		_enter_phase(_phase_idx + 1)

	# Chase + contact damage. Contact uses the actual slide collision (robust vs collider
	# radii / sprite scale), matching the 2026-06-14 fix in Enemy/Boss.
	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * (move_speed * _speed_mult)
	move_and_slide()
	if _touching_player():
		_target.take_damage(touch_damage * delta)

	# Cast the next pattern when the clock runs out.
	_pat_clock -= delta
	if _pat_clock <= 0.0:
		_cast_next_pattern()
		var ph: Dictionary = phases[_phase_idx]
		_pat_clock = float(ph.get("cadence", 4.0))

func _cast_next_pattern() -> void:
	if _phase_idx < 0 or _phase_idx >= phases.size():
		return
	var pats: Array = phases[_phase_idx].get("patterns", [])
	if pats.is_empty():
		return
	var entry: Dictionary = pats[_pat_i % pats.size()]
	_pat_i += 1
	var p = (entry["scene"] as PackedScene).instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.setup(self, _target, entry.get("params", {}))

func _touching_player() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == _target:
			return true
	return false

func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_die()

func _die() -> void:
	_reward()
	queue_free()

func _reward() -> void:
	RunStats.add_boss()
	# Big XP burst — scattered around the boss, enough to pop a level-up.
	if xp_gem_scene != null:
		for i in GameConfig.BOSS_XP_REWARD:
			var gem = xp_gem_scene.instantiate()
			get_tree().current_scene.add_child(gem)
			var a := randf_range(0.0, TAU)
			gem.global_position = global_position + Vector2(cos(a), sin(a)) * randf_range(8.0, 64.0)
	# Full heal.
	if _target and is_instance_valid(_target):
		_target.full_heal()
	# Relic drop: one relic neither owned nor banned this run.
	var bar := get_tree().get_first_node_in_group("relic_bar")
	if bar != null and relic_pickup_scene != null:
		var id: String = bar.call("roll_drop")
		if id != "":
			var pickup = relic_pickup_scene.instantiate()
			pickup.relic_id = id
			get_tree().current_scene.add_child(pickup)
			pickup.global_position = global_position
```

- [ ] **Step 2: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/BossBase.gd
git commit -m "Boss framework: BossBase (phase/pattern engine + carried-over brute behavior)"
```

---

### Task 13: Brute boss (parity port)

The brute as a `BossBase` subclass: one phase, the `ExpandingRing` slam with the `SLAM_*` consts. Plays like the pre-framework boss (modulo the 1s first-cast delay noted in Deviations).

**Files:**
- Create: `scripts/bosses/Brute.gd`
- Create: `scenes/bosses/Brute.tscn`

- [ ] **Step 1: Write the script**

`scripts/bosses/Brute.gd`:

```gdscript
class_name Brute
extends BossBase
## The original brute, ported to BossBase as the parity proof. One phase: a periodic
## telegraphed ground-slam (ExpandingRing) using the SLAM_* config.

const BOSS_ID := "brute"

func _build_phases() -> Array:
	return [
		{
			"at": 1.0,
			"cadence": GameConfig.SLAM_INTERVAL,
			"patterns": [
				{ "scene": Patterns.RING, "params": {
					"radius": GameConfig.SLAM_RADIUS,
					"expand_time": GameConfig.SLAM_EXPAND_TIME,
					"damage": GameConfig.SLAM_DAMAGE,
					"windup": GameConfig.SLAM_WINDUP,
				} },
			],
		},
	]
```

- [ ] **Step 2: Write the scene** (cloned from `scenes/Boss.tscn`, minus the slam export; script → Brute.gd)

`scenes/bosses/Brute.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/bosses/Brute.gd" id="1_brute"]
[ext_resource type="Texture2D" path="res://art/enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]
[ext_resource type="PackedScene" path="res://scenes/RelicPickup.tscn" id="5_relic"]

[sub_resource type="CircleShape2D" id="CircleShape2D_brute"]
radius = 48.0

[node name="Brute" type="CharacterBody2D"]
script = ExtResource("1_brute")
xp_gem_scene = ExtResource("3_gem")
relic_pickup_scene = ExtResource("5_relic")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(2.5, 2.5)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_brute")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/bosses/Brute.gd scenes/bosses/Brute.tscn
git commit -m "Boss framework: Brute boss (BossBase parity port)"
```

---

### Task 14: Brood Mother boss

Exercises SummonSpawner + ZoneFill + ProjectileEmitter across three phases. Decoy adds steal auto-aim; acid zones deny standing-still spots; a radial spit appears at low HP.

**Files:**
- Create: `scripts/bosses/BroodMother.gd`
- Create: `scenes/bosses/BroodMother.tscn`

- [ ] **Step 1: Write the script**

`scripts/bosses/BroodMother.gd`:

```gdscript
class_name BroodMother
extends BossBase
## Exercises SummonSpawner + ZoneFill + ProjectileEmitter over three phases. Combat-model
## exploit: decoy adds hijack the player's nearest-target auto-aim so fire wanders off the
## boss; acid zones deny the stand-still firing spots.

const BOSS_ID := "brood_mother"

func _hp_mult() -> float:
	return GameConfig.BROOD_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var zone := { "radius": 90.0, "dps": GameConfig.BROOD_ZONE_DPS, "duration": 4.0, "at": "player", "windup": 0.9 }
	return [
		{
			"at": 1.0, "cadence": 4.0,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.BROOD_SUMMON_COUNT, "windup": 0.9 } },
				{ "scene": Patterns.ZONE, "params": zone },
			],
		},
		{
			"at": 0.66, "cadence": 3.2,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.BROOD_SUMMON_COUNT, "decoy": true, "windup": 0.8 } },
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.EMITTER, "params": { "count": GameConfig.BROOD_RING_COUNT, "pattern": "ring", "speed": 180.0, "windup": 0.7 } },
			],
		},
		{
			"at": 0.33, "cadence": 2.6,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": 4, "decoy": true, "windup": 0.7 } },
				{ "scene": Patterns.EMITTER, "params": { "count": 10, "pattern": "ring", "speed": 200.0, "windup": 0.6 } },
				{ "scene": Patterns.ZONE, "params": zone },
			],
		},
	]
```

- [ ] **Step 2: Write the scene** (scale 3.0, collider 56)

`scenes/bosses/BroodMother.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/bosses/BroodMother.gd" id="1_brood"]
[ext_resource type="Texture2D" path="res://art/enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]
[ext_resource type="PackedScene" path="res://scenes/RelicPickup.tscn" id="5_relic"]

[sub_resource type="CircleShape2D" id="CircleShape2D_brood"]
radius = 56.0

[node name="BroodMother" type="CharacterBody2D"]
script = ExtResource("1_brood")
xp_gem_scene = ExtResource("3_gem")
relic_pickup_scene = ExtResource("5_relic")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(3, 3)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_brood")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/bosses/BroodMother.gd scenes/bosses/BroodMother.tscn
git commit -m "Boss framework: Brood Mother boss (summon/zone/emitter, 3 phases)"
```

---

### Task 15: Heat Tyrant boss (OVERCLOX)

Exercises DebuffApplier + AimedBand + ExpandingRing. At <33% HP it periodically jams the gun, forcing a pure-movement window — directly attacking the "stand still and let the gun work" default.

**Files:**
- Create: `scripts/bosses/HeatTyrant.gd`
- Create: `scenes/bosses/HeatTyrant.tscn`

- [ ] **Step 1: Write the script**

`scripts/bosses/HeatTyrant.gd`:

```gdscript
class_name HeatTyrant
extends BossBase
## OVERCLOX, the Heat Tyrant. Exercises ExpandingRing + AimedBand + DebuffApplier over three
## phases. Combat-model exploit: the <33% "Forced Vent" gun-jam removes auto-fire for a
## window, so the player must dash/kite with no DPS — attacking the stand-still-and-fire default.

const BOSS_ID := "heat_tyrant"

func _hp_mult() -> float:
	return GameConfig.HEAT_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var ring := { "radius": 200.0, "expand_time": 0.5, "damage": GameConfig.SLAM_DAMAGE, "windup": 0.8 }
	var band := { "length": GameConfig.AIMED_BAND_LENGTH, "damage": GameConfig.HEAT_BAND_DAMAGE, "windup": 0.9 }
	return [
		{
			"at": 1.0, "cadence": 3.5,
			"patterns": [
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.66, "cadence": 3.0,
			"patterns": [
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.33, "cadence": 2.6,
			"patterns": [
				{ "scene": Patterns.DEBUFF, "params": { "kind": "jam", "duration": GameConfig.HEAT_JAM_DURATION, "windup": 0.8 } },
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
	]
```

- [ ] **Step 2: Write the scene** (scale 2.5, collider 48)

`scenes/bosses/HeatTyrant.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/bosses/HeatTyrant.gd" id="1_heat"]
[ext_resource type="Texture2D" path="res://art/enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]
[ext_resource type="PackedScene" path="res://scenes/RelicPickup.tscn" id="5_relic"]

[sub_resource type="CircleShape2D" id="CircleShape2D_heat"]
radius = 48.0

[node name="HeatTyrant" type="CharacterBody2D"]
script = ExtResource("1_heat")
xp_gem_scene = ExtResource("3_gem")
relic_pickup_scene = ExtResource("5_relic")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(2.5, 2.5)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_heat")
```

- [ ] **Step 3: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 4: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/bosses/HeatTyrant.gd scenes/bosses/HeatTyrant.tscn
git commit -m "Boss framework: Heat Tyrant boss (debuff/band/ring, 3 phases)"
```

---

### Task 16: Bosses registry + no-repeat probe

A `class_name` registry that preloads the built boss scenes and picks one at random with no immediate repeat. A headless logic probe verifies the no-repeat guarantee (`class_name` globals load in `--script` mode; autoloads do not, but `Bosses.pick` uses neither).

**Files:**
- Create: `scripts/logic/Bosses.gd`
- Create (temporary, deleted in this task): `probe_bosses.gd` at the project root

- [ ] **Step 1: Write the registry**

`scripts/logic/Bosses.gd`:

```gdscript
class_name Bosses
## Registry of built boss scenes. The Spawner picks from here (uniform random, no immediate
## repeat). Each entry is { "id": String, "scene": PackedScene } with id == the boss's BOSS_ID,
## so the picker never has to instance a node just to read an id.

const _LIST: Array[Dictionary] = [
	{ "id": "brute", "scene": preload("res://scenes/bosses/Brute.tscn") },
	{ "id": "brood_mother", "scene": preload("res://scenes/bosses/BroodMother.tscn") },
	{ "id": "heat_tyrant", "scene": preload("res://scenes/bosses/HeatTyrant.tscn") },
]

static func count() -> int:
	return _LIST.size()

## A uniform-random boss entry { id, scene }, excluding last_id when more than one boss exists.
static func pick(last_id: String) -> Dictionary:
	if _LIST.is_empty():
		return {}
	if _LIST.size() == 1:
		return _LIST[0]
	var pool: Array[Dictionary] = []
	for e in _LIST:
		if String(e["id"]) != last_id:
			pool.append(e)
	if pool.is_empty():
		pool = _LIST
	return pool[randi() % pool.size()]
```

- [ ] **Step 2: Write the probe**

`probe_bosses.gd` (project root):

```gdscript
extends SceneTree
## Headless logic probe: confirms Bosses.pick never repeats the previous boss and that all
## bosses can appear. Run with --script; class_name globals are available, autoloads are not.

func _init() -> void:
	var seen := {}
	var last := ""
	var repeats := 0
	for i in 300:
		var e := Bosses.pick(last)
		if e.is_empty():
			push_error("PROBE_FAIL empty pick")
			quit()
			return
		var id := String(e["id"])
		if id == last and Bosses.count() > 1:
			repeats += 1
		seen[id] = true
		last = id
	print("PROBE_OK distinct=", seen.size(), " count=", Bosses.count(), " immediate_repeats=", repeats)
	quit()
```

- [ ] **Step 3: Run the probe**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --script res://probe_bosses.gd 2>&1 | grep -E "PROBE_"
```

Expected: `PROBE_OK distinct=3 count=3 immediate_repeats=0`

- [ ] **Step 4: Delete the probe**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
rm -f probe_bosses.gd probe_bosses.gd.uid
```

- [ ] **Step 5: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 6: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/logic/Bosses.gd
git commit -m "Boss framework: Bosses registry + pick(last_id) (probe: no immediate repeat)"
```

---

### Task 17: Wire-up + remove the old boss — the switchover

Repoints the `Spawner`, `Hud`, and `Main.tscn` onto the registry, then deletes the old `Boss`/`SlamWave` files. After this task the project compiles and runs entirely on the framework.

**Files:**
- Modify: `scripts/Spawner.gd`
- Modify: `scripts/Hud.gd`
- Modify: `scenes/Main.tscn`
- Remove: `scripts/Boss.gd` (+ `.uid`), `scripts/SlamWave.gd` (+ `.uid`), `scenes/Boss.tscn`, `scenes/SlamWave.tscn`

- [ ] **Step 1: Spawner — drop the `boss_scene` export, pick from the registry**

In `scripts/Spawner.gd`, remove this line (line 8):

```gdscript
@export var boss_scene: PackedScene
```

After `var _last_boss_wave := 0` (line 15), add:

```gdscript
var _last_boss_id := ""
```

Replace `_process_boss_rush` (lines 53–57):

```gdscript
func _process_boss_rush() -> void:
	if boss_scene == null or _boss_alive():
		return
	boss_rush_count += 1
	_spawn_boss(DifficultyCurve.boss_stats(boss_rush_count))
```

with:

```gdscript
func _process_boss_rush() -> void:
	if _boss_alive():
		return
	boss_rush_count += 1
	_spawn_boss(DifficultyCurve.boss_stats(boss_rush_count))
```

Replace `_spawn_boss` (lines 71–79):

```gdscript
func _spawn_boss(stats: Dictionary) -> void:
	if boss_scene == null:
		return
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var boss = boss_scene.instantiate()
	boss.configure(stats)
	get_tree().current_scene.add_child(boss)
	boss.global_position = _player.global_position + offset
```

with:

```gdscript
func _spawn_boss(stats: Dictionary) -> void:
	var entry := Bosses.pick(_last_boss_id)
	if entry.is_empty():
		return
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var boss = (entry["scene"] as PackedScene).instantiate()
	boss.configure(stats)
	get_tree().current_scene.add_child(boss)
	boss.global_position = _player.global_position + offset
	_last_boss_id = String(entry["id"])
```

- [ ] **Step 2: Hud — retype the boss cast**

In `scripts/Hud.gd`, line 145, change:

```gdscript
		_boss_bar.value = (boss as Boss).health_fraction()
```

to:

```gdscript
		_boss_bar.value = (boss as BossBase).health_fraction()
```

- [ ] **Step 3: Main.tscn — remove the two `boss_scene` lines (surgical)**

In `scenes/Main.tscn`:
1. Line 1: change `[gd_scene load_steps=13 format=3]` → `[gd_scene load_steps=12 format=3]`.
2. Delete line 9 entirely: `[ext_resource type="PackedScene" path="res://scenes/Boss.tscn" id="7_boss"]`.
3. Delete line 37 entirely: `boss_scene = ExtResource("7_boss")` (under the `Spawner` node — leave `enemy_scene = ExtResource("3_zomb")` intact).

Leave everything else (Ground, Player, every CanvasLayer) byte-identical.

- [ ] **Step 4: Delete the old boss/slam files**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git rm scripts/Boss.gd scripts/SlamWave.gd scenes/Boss.tscn scenes/SlamWave.tscn
rm -f scripts/Boss.gd.uid scripts/SlamWave.gd.uid scenes/Boss.tscn.uid scenes/SlamWave.tscn.uid
```

- [ ] **Step 5: Confirm nothing still references the removed symbols**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
  grep -rn "as Boss)\|class_name Boss$\|SlamWave\|Boss\.tscn\|slam_wave\|boss_scene" scripts/ scenes/
```

Expected: **empty** (no remaining references to the deleted `Boss` class, `SlamWave`, `Boss.tscn`, or the `boss_scene` export).

- [ ] **Step 6: Run THE COMPILE GATE.** Expected: empty.

- [ ] **Step 7: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/Spawner.gd scripts/Hud.gd scenes/Main.tscn
git commit -m "Boss framework: switch Spawner/HUD/Main onto the registry; remove old Boss/SlamWave"
```

---

## F5 smoke checklist (Larry — after all tasks land)

There is no in-WSL game runner, so Larry F5s in Godot. To reach bosses fast, temporarily set `GameConfig.WAVE_DURATION := 6.0`, then restore to `30.0` after.

1. **A boss spawns at wave 5** (random of the 3): bottom-center HP bar shows, it chases, bullets/auto-aim hit it, telegraphed attacks fire.
2. **Brute:** slam telegraph (faint orange circle) → expanding orange ring → dash to avoid. Behaves like before. (First slam now ~1s after spawn, not 4s — by design; set `BOSS_FIRST_CAST_DELAY := GameConfig.SLAM_INTERVAL` if you want the exact old 4s.)
3. **Brood Mother:** spawns adds; at ≤66% the decoy adds appear next to you and your auto-aim sometimes pulls onto them; green acid zones deny ground; ring spit appears at low HP. Phase ramp visible (faster cadence as HP drops).
4. **Heat Tyrant:** meltdown rings + aimed orange beams (step off the line during the bright telegraph); at <33% the gun JAMS for ~2s (HUD can't fire, red aura on you) forcing a movement window, then resumes.
5. **Any boss death:** XP burst + full heal + relic pickup (unchanged reward).
6. **Multiple boss waves:** never the same boss twice in a row; no errors in the Godot output.
7. Restore `WAVE_DURATION := 30.0`.

**Watch items:** boss projectiles read as threats (C3 dots) vs your C4 bullets; the 3 bosses look similar (all C3, differ by size) — dedicated boss sprites are the recommended follow-up; pause-stacking on boss kill is unchanged from Phase 4 (XP→LevelUpUI + relic→RelicMenu both pause; Godot freezes the second trigger).

## Out-of-scope follow-ups (natural next specs)
- Wave-band escalation ladder (swap `Bosses.pick` for a wave-aware picker).
- Dedicated boss sprites (the cleanest way to differentiate the 3 within the palette).
- More bosses off the Boss Bible (each = a `_build_phases()` + maybe one new pattern).
- DebuffApplier extensions (dash-lock, axis-remap) + the OVERCLOX heat-meter version.
- Boss intro banner UI.

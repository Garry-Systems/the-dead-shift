# Boss Pack: THE KAREN + THE TANKER — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two bosses (roster 7 → 9): THE KAREN (scream-shove + decoys + summons a Manager-flavored elite) and THE TANKER (charge dashes that leak igniting fuel trails), shipping as v0.1.60.

**Architecture:** Each boss = one new `AttackPattern` subclass (`ScreamRing extends ExpandingRing`, `TrailDash extends ChargeDash`) + a `BossBase` subclass with a phase table + a registry row in `Bosses.gd`. Supporting edits: `Player.apply_shove` impulse, `SummonSpawner` elite promotion, `HazardZone` configurable windup/puddle-look. Sprites via the home-repo generator.

**Tech Stack:** Godot 4.6.3 GDScript (game repo `/mnt/c/Users/thela/Documents/mobile-game`), Python stdlib sprite generator (home repo `~/gen_palette_sprites.py`).

**Spec:** `docs/superpowers/specs/2026-07-09-boss-pack-karen-tanker-design.md` (approved).

## Global Constraints

- **Godot headless runner (WSL → Windows interop):**
  ```bash
  GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; [ -n "$GODOT" ] || echo "STOP: godot missing — tell controller"
  PROJ='C:\Users\thela\Documents\mobile-game'
  ```
- **MANDATORY DUAL GATE — run BOTH at the end of EVERY task** (the parse gate does NOT catch script-load compile failures — v0.1.57 lesson):
  ```bash
  "$GODOT" --path "$PROJ" --headless --editor --quit 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"   # expect 0
  timeout 25 "$GODOT" --path "$PROJ" --headless res://scenes/Main.tscn 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"   # expect 0 (timeout killing the run after 25s is fine)
  ```
  The `EditorSettings not instantiated` ERROR line is benign noise (doesn't match the grep).
- Every tunable is a `GameConfig` const with a `## comment` — no literals in behavior code. All values are STARTER values.
- Palette: sprites use ONLY C1 `#0A001A`, C2 `#3D0099`, C3 `#8C8573`, C4 `#E0E5FF`. Fire orange (`Hazards.ORANGE`) is an already-sanctioned exception for hazards.
- Probes are ephemeral: write to `res://_probe.gd` inside the game project, run, then `rm` BEFORE committing. Probes must not depend on autoloads (no `DifficultyManager.*` / `RunStats.*` calls — pure statics and off-tree instantiation only; where a tree is needed, `extends SceneTree` and set `current_scene` manually).
- Run probes with: `"$GODOT" --path "$PROJ" --headless --script res://_probe.gd` — a probe prints `PROBE PASS` or `PROBE FAIL <detail>` lines and exits.
- Do NOT push until the ship task — every push to master builds a release APK (version = CI run number).
- Commits on `master` directly (this repo's polish-loop convention), message style `feat(...)::`/`fix(...):`, docs-only commits `[skip ci]`.

---

### Task 1: `Player.apply_shove` — decaying knockback impulse

**Files:**
- Modify: `scripts/Player.gd` (vars near line 24-31; `_physics_process` near line 115; new funcs near `apply_slow` line ~439)
- Modify: `scripts/logic/GameConfig.gd` (player section)

**Interfaces:**
- Produces: `Player.apply_shove(impulse: Vector2) -> void` (no-op mid-dash; replaces any live shove), `static Player.shove_step(v: Vector2, decay: float, delta: float) -> Vector2` (pure), `GameConfig.PLAYER_SHOVE_DECAY := 1200.0`.
- Task 2's `ScreamRing` calls `player.apply_shove(dir * shove_speed)` guarded by `has_method("apply_shove")`.

- [ ] **Step 1: Write the failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
func _init() -> void:
	var fails := 0
	# 1. decay always reaches zero and never grows
	var v := Vector2(600, 0)
	var displacement := 0.0
	var steps := 0
	while v != Vector2.ZERO and steps < 600:
		displacement += v.length() * (1.0 / 60.0)
		var nv: Vector2 = Player.shove_step(v, GameConfig.PLAYER_SHOVE_DECAY, 1.0 / 60.0)
		if nv.length() > v.length():
			fails += 1; print("PROBE FAIL shove grew")
		v = nv
		steps += 1
	if v != Vector2.ZERO:
		fails += 1; print("PROBE FAIL shove never died (600 steps)")
	# 2. a 600 px/s impulse at decay 1200 must displace ~150px (spec: shove ~150px)
	if displacement < 120.0 or displacement > 180.0:
		fails += 1; print("PROBE FAIL displacement %.1f not ~150" % displacement)
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run it — expect FAIL** (`shove_step` not defined / `PLAYER_SHOVE_DECAY` missing):

```bash
"$GODOT" --path "$PROJ" --headless --script res://_probe.gd
```

- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd` (player section, near `DASH_*`):

```gdscript
const PLAYER_SHOVE_DECAY := 1200.0     # px/sec^2 linear decay of an external shove impulse (Karen's scream) — 600 px/s dies in 0.5s ≈ 150px total
```

`scripts/Player.gd` — add with the other state vars (near `_last_move_dir`, line ~25):

```gdscript
var _shove_velocity := Vector2.ZERO   # external knockback (Karen's ScreamRing); decays via shove_step, never permanent
```

Add next to `apply_slow` (line ~439):

```gdscript
## Pure decay step for the shove impulse, split out so a headless probe can prove it always
## dies out (same probe-ability idiom as ShiftClock/Ranks).
static func shove_step(v: Vector2, decay: float, delta: float) -> Vector2:
	return v.move_toward(Vector2.ZERO, decay * delta)

## Knock the player away at `impulse` px/sec, decaying to zero. Ignored mid-dash (the player's
## committed dash beats the boss's shove). REPLACES any live shove — overlapping screams must
## not compound into a cross-arena launch.
func apply_shove(impulse: Vector2) -> void:
	if _dash.is_dashing():
		return
	_shove_velocity = impulse
```

In `_physics_process`, directly after `velocity = move_dir * speed` (line 115) and BEFORE the gun-drive block:

```gdscript
	# External shove rides on top of input; while it's live, velocity != ZERO also holds fire
	# via the stop-to-shoot gate below — a scream knocking you out of your firing stance is
	# the intended disruption, not a bug.
	if _shove_velocity != Vector2.ZERO:
		velocity += _shove_velocity
		_shove_velocity = shove_step(_shove_velocity, GameConfig.PLAYER_SHOVE_DECAY, delta)
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: `rm` the probe, run BOTH gates (expect 0 / 0), commit:**

```bash
rm "/mnt/c/Users/thela/Documents/mobile-game/_probe.gd"
cd "/mnt/c/Users/thela/Documents/mobile-game" && git add scripts/Player.gd scripts/logic/GameConfig.gd && git commit -m "feat(player): apply_shove decaying knockback impulse (Karen groundwork)"
```

---

### Task 2: `ScreamRing` pattern

**Files:**
- Create: `scripts/patterns/ScreamRing.gd`, `scenes/patterns/ScreamRing.tscn`
- Modify: `scripts/logic/Patterns.gd`, `scripts/logic/GameConfig.gd`

**Interfaces:**
- Consumes: `Player.apply_shove` (Task 1), `ExpandingRing` (`_check_hit`, `_hit_player`, cfg keys `radius`/`expand_time`/`damage`/`windup`).
- Produces: `Patterns.SCREAM` (PackedScene); cfg key `shove_speed`; consts `KAREN_SCREAM_RADIUS 240.0`, `KAREN_SCREAM_DAMAGE 30.0`, `KAREN_SCREAM_SHOVE_SPEED 600.0`. Task 4 references `Patterns.SCREAM` + these consts.

- [ ] **Step 1: Write the failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
## Drives ScreamRing._check_hit via a stub player sitting inside the ring's leading band.
class PlayerStub extends Node2D:
	var damage_taken := 0.0
	var shoves: Array[Vector2] = []
	func take_damage(a: float) -> void: damage_taken += a
	func apply_shove(i: Vector2) -> void: shoves.append(i)
class NoShoveStub extends Node2D:
	func take_damage(_a: float) -> void: pass

func _init() -> void:
	var fails := 0
	var ring: ScreamRing = (load("res://scenes/patterns/ScreamRing.tscn") as PackedScene).instantiate()
	root.add_child(ring)
	ring.global_position = Vector2.ZERO
	var stub := PlayerStub.new()
	root.add_child(stub)
	stub.global_position = Vector2(100, 0)
	ring.setup(null, stub, { "radius": 240.0, "damage": 30.0, "shove_speed": 600.0 })
	ring._radius = 110.0     # band = [_radius - 28, _radius] -> stub at 100 is inside
	ring._check_hit()
	if stub.damage_taken != 30.0:
		fails += 1; print("PROBE FAIL damage %f" % stub.damage_taken)
	if stub.shoves.size() != 1:
		fails += 1; print("PROBE FAIL shove count %d" % stub.shoves.size())
	elif stub.shoves[0].distance_to(Vector2(600, 0)) > 0.5:
		fails += 1; print("PROBE FAIL shove vector %s (want 600,0 — away from center)" % str(stub.shoves[0]))
	ring._check_hit()   # hit-once: second sweep must not re-shove
	if stub.shoves.size() != 1:
		fails += 1; print("PROBE FAIL re-shove on same ring")
	# a player-shaped node WITHOUT apply_shove must not crash (has_method guard)
	var ring2: ScreamRing = (load("res://scenes/patterns/ScreamRing.tscn") as PackedScene).instantiate()
	root.add_child(ring2)
	ring2.global_position = Vector2.ZERO
	var ns := NoShoveStub.new()
	root.add_child(ns)
	ns.global_position = Vector2(100, 0)
	ring2.setup(null, ns, { "radius": 240.0, "damage": 30.0 })
	ring2._radius = 110.0
	ring2._check_hit()
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL** (ScreamRing.tscn missing).
- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd` (new "THE KAREN" block after the COURIER consts, ~line 342):

```gdscript
# --- THE KAREN (boss #8, v0.1.60) ---
const KAREN_SCREAM_RADIUS := 240.0     # scream nova max radius (slightly wider than SLAM_RADIUS)
const KAREN_SCREAM_DAMAGE := 30.0      # damage if the leading band catches the player (once per scream)
const KAREN_SCREAM_SHOVE_SPEED := 600.0  # px/sec initial shove; with PLAYER_SHOVE_DECAY 1200 ≈ 150px knockback
```

`scripts/patterns/ScreamRing.gd`:

```gdscript
class_name ScreamRing
extends ExpandingRing
## THE KAREN's scream nova. Identical telegraph/expand/damage-once to the parent ground slam —
## the parent's _check_hit already applies damage AND the boss-slam camera shake — so this
## subclass ONLY adds the knockback: a newly-hit player is shoved straight away from ring
## center via Player.apply_shove (decaying impulse; a dashing player is immune by design).

var _shove_speed := GameConfig.KAREN_SCREAM_SHOVE_SPEED

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_shove_speed = float(cfg.get("shove_speed", GameConfig.KAREN_SCREAM_SHOVE_SPEED))

func _check_hit() -> void:
	var was_hit := _hit_player
	super._check_hit()
	if _hit_player and not was_hit and player != null and is_instance_valid(player) and player.has_method("apply_shove"):
		var away := player.global_position - global_position
		var dir := away.normalized() if away.length() > 0.001 else Vector2.RIGHT
		player.apply_shove(dir * _shove_speed)
```

`scenes/patterns/ScreamRing.tscn` (mirrors ChargeDash.tscn exactly):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/ScreamRing.gd" id="1"]

[node name="ScreamRing" type="Node2D"]
script = ExtResource("1")
```

`scripts/logic/Patterns.gd` — add:

```gdscript
const SCREAM := preload("res://scenes/patterns/ScreamRing.tscn")
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.** (If it crashes inside `CameraShake.add_trauma`, the static lacks a null-instance guard — read `scripts/CameraShake.gd:50` and add `if instance == null: return` there as part of this task; its docs say it mirrors CombatText's silent no-op.)
- [ ] **Step 5: `rm` probe, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/patterns/ScreamRing.gd scenes/patterns/ScreamRing.tscn scripts/logic/Patterns.gd scripts/logic/GameConfig.gd && git commit -m "feat(patterns): ScreamRing — expanding nova that shoves the player (Karen)"
```

---

### Task 3: `SummonSpawner` elite promotion

**Files:**
- Modify: `scripts/patterns/SummonSpawner.gd`

**Interfaces:**
- Consumes: `Enemy.apply_elite(kind: String)` (multiplies max_health by `GameConfig.ELITE_HP_MULT` 2.5 itself and adds the tell-ring).
- Produces: cfg key `elite_kind` (default `""` = today's behavior, byte-identical) and `static SummonSpawner.promote(e: Node, kind: String) -> void`. Task 4 passes `{"count": 1, "hp_mult": GameConfig.KAREN_MANAGER_HP_MULT, "elite_kind": "alpha"}`.

- [ ] **Step 1: Failing probe** — `res://_probe.gd`. NOTE: first `grep -n "func configure" -A 10 scripts/Enemy.gd` and align the stats dict keys below with what `Enemy.configure` actually reads (add any missing required keys with sane values):

```gdscript
extends SceneTree
class EliteRecorder extends Node2D:
	var kinds: Array[String] = []
	func apply_elite(k: String) -> void: kinds.append(k)

func _init() -> void:
	var fails := 0
	# 1. promote() forwards to apply_elite, "" is a no-op, no-method nodes don't crash
	var r := EliteRecorder.new()
	SummonSpawner.promote(r, "alpha")
	SummonSpawner.promote(r, "")
	SummonSpawner.promote(Node2D.new(), "alpha")
	if r.kinds != ["alpha"] as Array[String]:
		fails += 1; print("PROBE FAIL promote calls: %s" % str(r.kinds))
	# 2. integration: a real Enemy ends up elite with multiplied HP
	var e = (load("res://scenes/Enemy.tscn") as PackedScene).instantiate()
	e.configure({ "max_health": 100.0, "move_speed": 80.0, "damage": 10.0, "special_mult": 1.0 })
	SummonSpawner.promote(e, "alpha")
	if not e.is_elite or e.elite_kind != "alpha":
		fails += 1; print("PROBE FAIL enemy not elite")
	if absf(e.max_health - 100.0 * GameConfig.ELITE_HP_MULT) > 0.01:
		fails += 1; print("PROBE FAIL elite hp %f (want %f)" % [e.max_health, 100.0 * GameConfig.ELITE_HP_MULT])
	e.free()
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL** (`promote` not defined).
- [ ] **Step 3: Implement.** In `SummonSpawner.gd` add a var + setup line + the static, and call it in `_on_telegraph_end` (order matches Spawner: configure → promote → add_child):

```gdscript
var _elite_kind := ""    # optional promotion of every summoned add (Karen's MANAGER ON DUTY)
```

In `setup()` after `_hp_mult`:

```gdscript
	_elite_kind = String(cfg.get("elite_kind", ""))
```

New static:

```gdscript
## Elite promotion for a freshly-configured summon. DELIBERATELY bypasses the Spawner's
## endless/horde ambient-elite gate — a boss move must work in every mode the boss fights in
## (Boss Rush included). Static + guard-heavy so a headless probe can drive it directly.
static func promote(e: Node, kind: String) -> void:
	if kind != "" and e.has_method("apply_elite"):
		e.apply_elite(kind)
```

In `_on_telegraph_end`, between `e.configure(stats)` and `get_tree().current_scene.add_child(e)`:

```gdscript
		SummonSpawner.promote(e, _elite_kind)
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: `rm` probe, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/patterns/SummonSpawner.gd && git commit -m "feat(patterns): SummonSpawner elite_kind promotion for boss-move summons"
```

---

### Task 4: THE KAREN boss

**Files:**
- Create: `scripts/bosses/Karen.gd`, `scenes/bosses/Karen.tscn`
- Modify: `scripts/logic/Bosses.gd` (registry row), `scripts/logic/GameConfig.gd` (rest of the KAREN block)

**Interfaces:**
- Consumes: `Patterns.SCREAM` (T2), SummonSpawner `elite_kind` (T3), `Patterns.DEBUFF` jam/slow, `Patterns.SUMMON` decoy, `CombatText.callout(world_pos, word, color)`, `PixelTheme.ACCENT/DARK`, phase-table `on_enter` Callable (BossBase `_enter_phase`).
- Produces: registry id `"karen"` / name `"THE KAREN"`; `Bosses.count() == 8` after this task.

- [ ] **Step 1: Failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
func _init() -> void:
	var fails := 0
	if Bosses.count() != 8:
		fails += 1; print("PROBE FAIL Bosses.count %d != 8" % Bosses.count())
	if Bosses.name_for("karen") != "THE KAREN":
		fails += 1; print("PROBE FAIL name_for karen")
	var k := Karen.new()
	var ph: Array = k._build_phases()
	if ph.size() != 3 or float(ph[0].get("at", 0.0)) != 1.0:
		fails += 1; print("PROBE FAIL phase table shape")
	for i in ph.size():
		if (ph[i].get("patterns", []) as Array).is_empty():
			fails += 1; print("PROBE FAIL empty patterns in phase %d" % i)
	var cb = ph[2].get("on_enter", null)
	if not (cb is Callable and (cb as Callable).is_valid()):
		fails += 1; print("PROBE FAIL P3 on_enter not a valid Callable")
	if absf(k._hp_mult() - GameConfig.KAREN_HP / GameConfig.BOSS_BASE_HP) > 0.001:
		fails += 1; print("PROBE FAIL hp mult")
	k.free()
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL** (Karen not defined, count 7).
- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd`, complete the KAREN block:

```gdscript
const KAREN_HP := 1600.0               # above Courier (1400), well under Manager (3000) — kit is the pressure, not the tank
const KAREN_SPEED_MULT := 0.85         # persistent chase-speed multiplier — quick for a boss
const KAREN_REVIEW_SLOW_FACTOR := 0.55 # "LEAVING A REVIEW" move-speed factor on the player
const KAREN_REVIEW_SLOW_DURATION := 2.5  # seconds the review slow lasts
const KAREN_DECOY_COUNT := 3           # decoy adds per cast (auto-aim steal, BroodMother idiom)
const KAREN_MANAGER_HP_MULT := 6.0     # MANAGER ON DUTY summon hp_mult — STACKS with apply_elite's ELITE_HP_MULT 2.5 → effective ~15x a wave-current trash zombie
```

`scripts/bosses/Karen.gd`:

```gdscript
class_name Karen
extends BossBase
## THE KAREN — the roster's first CUSTOMER (everyone else is staff or monster). Weak touch,
## quick feet; the kit attacks the player's aim and footing: ScreamRing shoves you out of your
## firing stance, "LEAVING A REVIEW" slows you, decoy summons steal your auto-aim, and at 33%
## she gets you the manager — a one-shot alpha-elite big add that buffs the staff around it,
## plus the Manager's own jam on loan. Combat-model exploit: you can never plant and fire.

const BOSS_ID := "karen"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.KAREN_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var scream := { "radius": GameConfig.KAREN_SCREAM_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.KAREN_SCREAM_DAMAGE, "windup": GameConfig.SLAM_WINDUP,
		"shove_speed": GameConfig.KAREN_SCREAM_SHOVE_SPEED }
	var review := { "kind": "slow", "duration": GameConfig.KAREN_REVIEW_SLOW_DURATION,
		"factor": GameConfig.KAREN_REVIEW_SLOW_FACTOR, "windup": 0.8 }
	var decoys := { "count": GameConfig.KAREN_DECOY_COUNT, "decoy": true, "windup": 0.9 }
	var jam := { "kind": "jam", "duration": GameConfig.MANAGER_JAM_DURATION, "windup": 0.8 }
	return [
		{
			"at": 1.0, "cadence": 4.2, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.DEBUFF, "params": review },
			],
		},
		{
			"at": 0.66, "cadence": 3.6, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.SUMMON, "params": decoys },
				{ "scene": Patterns.DEBUFF, "params": review },
			],
		},
		{
			"at": 0.33, "cadence": 3.2, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"on_enter": _call_the_manager,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.DEBUFF, "params": jam },
				{ "scene": Patterns.SUMMON, "params": decoys },
			],
		},
	]

## P3 one-shot (phase on_enter fires exactly once): the line, then the guy. NOT in the phase's
## round-robin list — the manager arrives ONCE. hp_mult stacks with apply_elite's own
## ELITE_HP_MULT; "alpha" = speed/damage aura, so the manager literally buffs the staff.
func _call_the_manager() -> void:
	CombatText.callout(global_position + Vector2(0, -60), "GET ME THE MANAGER!", PixelTheme.ACCENT)
	var p = Patterns.SUMMON.instantiate()
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.setup(self, _target, { "count": 1, "hp_mult": GameConfig.KAREN_MANAGER_HP_MULT,
		"elite_kind": "alpha", "windup": 1.0 })

## Regalia drawn OVER the shared enemy sprite until real art loads (Manager-tie idiom):
## sunglasses band + C4 glints, and a handbag on her arm. Palette C1/C4 only.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-15, -18), Vector2(30, 8)), PixelTheme.DARK)          # sunglasses band
	draw_rect(Rect2(Vector2(-10, -15), Vector2(4, 2)), PixelTheme.ACCENT)         # left lens glint
	draw_rect(Rect2(Vector2(4, -15), Vector2(4, 2)), PixelTheme.ACCENT)           # right lens glint
	var bag := Rect2(Vector2(18, 4), Vector2(13, 11))
	draw_rect(bag, PixelTheme.ACCENT)                                             # handbag
	draw_rect(bag, PixelTheme.DARK, false, 2.0)
	draw_line(Vector2(20, 4), Vector2(28, -6), PixelTheme.DARK, 2.0)              # strap
```

`scenes/bosses/Karen.tscn` (Courier.tscn clone, script swapped):

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/bosses/Karen.gd" id="1_karen"]
[ext_resource type="Texture2D" path="res://art/enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]
[ext_resource type="PackedScene" path="res://scenes/RelicPickup.tscn" id="5_relic"]

[sub_resource type="CircleShape2D" id="CircleShape2D_karen"]
radius = 46.0

[node name="Karen" type="CharacterBody2D"]
script = ExtResource("1_karen")
xp_gem_scene = ExtResource("3_gem")
relic_pickup_scene = ExtResource("5_relic")

[node name="Sprite2D" type="Sprite2D" parent="."]
z_index = -1
scale = Vector2(2.4, 2.4)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_karen")
```

`scripts/logic/Bosses.gd` — append to `_LIST` after the courier row:

```gdscript
	{ "id": "karen", "scene": preload("res://scenes/bosses/Karen.tscn"), "name": "THE KAREN" },
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: `rm` probe, BOTH gates (0/0)** — the boot gate is the important one here (a bad preload/registry row is a script-LOAD failure, the v0.1.57 class). **Commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/bosses/Karen.gd scenes/bosses/Karen.tscn scripts/logic/Bosses.gd scripts/logic/GameConfig.gd && git commit -m "feat(boss): THE KAREN — scream-shove, review slow, decoys, GET ME THE MANAGER"
```

---

### Task 5: `HazardZone` configurable windup + puddle look

**Files:**
- Modify: `scripts/HazardZone.gd` (`configure_hazard` line ~41, `_draw` line ~119)

**Interfaces:**
- Produces: cfg keys `windup` (default `GameConfig.HAZARD_WINDUP` — all 4 existing callers pass no key, byte-identical behavior) and `puddle` (default false; pre-arm telegraph draws as a dark fuel slick with a faint C4 sheen rim instead of faint hazard color). Task 6 passes `{"windup": TANKER_IGNITE_DELAY, "puddle": true}`.

- [ ] **Step 1: Failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
func _init() -> void:
	var fails := 0
	var a := HazardZone.new()
	root.add_child(a)
	a.configure_hazard({ "dps": 10.0, "radius": 50.0, "duration": 2.0 })
	if absf(a._windup - GameConfig.HAZARD_WINDUP) > 0.001:
		fails += 1; print("PROBE FAIL default windup %f" % a._windup)
	if a._puddle != false:
		fails += 1; print("PROBE FAIL default puddle")
	var b := HazardZone.new()
	root.add_child(b)
	b.configure_hazard({ "dps": 10.0, "radius": 50.0, "duration": 2.0, "windup": 0.9, "puddle": true })
	if absf(b._windup - 0.9) > 0.001:
		fails += 1; print("PROBE FAIL custom windup %f" % b._windup)
	if b._puddle != true:
		fails += 1; print("PROBE FAIL puddle flag")
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL** (`_puddle` missing; windup forced to `HAZARD_WINDUP`).
- [ ] **Step 3: Implement.** Add var near `_hurts_player`:

```gdscript
var _puddle := false    # fuel-slick pre-arm look (Tanker trail): dark slick + faint sheen instead of faint hazard color
```

In `configure_hazard`, replace `_windup = GameConfig.HAZARD_WINDUP` (keep its comment) with:

```gdscript
	_windup = float(cfg.get("windup", GameConfig.HAZARD_WINDUP))   # short arm by default; Tanker fuel passes a longer puddle→ignite delay
	_puddle = bool(cfg.get("puddle", false))
```

In `_draw`, replace the `if not _armed:` branch:

```gdscript
	if not _armed:
		if _puddle:
			draw_circle(Vector2.ZERO, _radius, Color(0.04, 0.0, 0.10, 0.6))                  # C1 fuel slick
			draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 24, Color(0.88, 0.9, 1.0, 0.25), 2.0)  # faint C4 sheen rim (dodge tell)
		else:
			draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.12))
		return
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: `rm` probe, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/HazardZone.gd && git commit -m "feat(hazards): configurable windup + fuel-puddle telegraph on HazardZone"
```

---

### Task 6: `TrailDash` pattern

**Files:**
- Create: `scripts/patterns/TrailDash.gd`, `scenes/patterns/TrailDash.tscn`
- Modify: `scripts/logic/Patterns.gd`, `scripts/logic/GameConfig.gd`

**Interfaces:**
- Consumes: `ChargeDash` internals (`_fired`, `_time_left`, `_hit_player`, `_boss_body`, `_end_charge`, `charging` flag protocol), `HazardZone` `windup`/`puddle` keys (T5), `Hazards.ORANGE`.
- Produces: `Patterns.TRAIL`; cfg keys `spacing`, `chain` (+ inherited `speed`/`duration`/`damage`/`hit_radius`/`windup`); consts `TANKER_TRAIL_SPACING 90.0`, `TANKER_TRAIL_MAX 14`, `TANKER_POOL_DPS 20.0`, `TANKER_POOL_RADIUS 70.0`, `TANKER_POOL_DURATION 4.0`, `TANKER_IGNITE_DELAY 0.9`, `TANKER_JACKKNIFE_RETELEGRAPH 0.4`. Task 7 references `Patterns.TRAIL` + these.

- [ ] **Step 1: Failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
class BossStub extends CharacterBody2D:
	var charging := false
	var special_mult := 1.0

func _init() -> void:
	var fails := 0
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene   # HazardZone spawns into current_scene
	var boss := BossStub.new()
	scene.add_child(boss)
	boss.global_position = Vector2.ZERO
	var target := Node2D.new()
	scene.add_child(target)
	target.global_position = Vector2(2000, 0)

	var td: TrailDash = (load("res://scenes/patterns/TrailDash.tscn") as PackedScene).instantiate()
	scene.add_child(td)
	td.global_position = boss.global_position
	td.setup(boss, target, { "spacing": 90.0, "chain": 1, "speed": 600.0, "duration": 1.0, "windup": 0.5 })
	td._windup = 0.0
	td._fired = true
	td._on_telegraph_end()
	if not boss.charging:
		fails += 1; print("PROBE FAIL charging not set")
	# drive one full dash: 1.0s at 600 px/s in 1/60 steps = 600px -> expect floor(600/90)=6 pools
	for i in 60:
		td._physics_process(1.0 / 60.0)
	var pools := get_nodes_in_group("tanker_fuel")
	if pools.size() < 5 or pools.size() > 7:
		fails += 1; print("PROBE FAIL pool count %d (want ~6)" % pools.size())
	# chain: dash ended -> must be RE-TELEGRAPHING, not freed; charging must STAY true
	if td._fired:
		fails += 1; print("PROBE FAIL chain did not re-telegraph")
	if absf(td._windup - GameConfig.TANKER_JACKKNIFE_RETELEGRAPH) > 0.001:
		fails += 1; print("PROBE FAIL re-telegraph windup %f" % td._windup)
	if not boss.charging:
		fails += 1; print("PROBE FAIL charging dropped between chained dashes")
	if td._hit_player:
		fails += 1; print("PROBE FAIL hit flag not reset for dash 2")
	# cap: drop-oldest keeps the live group at TANKER_TRAIL_MAX
	for i in GameConfig.TANKER_TRAIL_MAX + 3:
		td._drop_pool()
	var live := 0
	for p in get_nodes_in_group("tanker_fuel"):
		if is_instance_valid(p) and not (p as Node).is_queued_for_deletion():
			live += 1
	if live > GameConfig.TANKER_TRAIL_MAX:
		fails += 1; print("PROBE FAIL cap: %d live > %d" % [live, GameConfig.TANKER_TRAIL_MAX])
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL** (TrailDash missing).
- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd`, new "THE TANKER" block after the KAREN block:

```gdscript
# --- THE TANKER (boss #9, v0.1.60) ---
const TANKER_TRAIL_SPACING := 90.0       # px of dash travel between fuel pool drops
const TANKER_TRAIL_MAX := 14             # live fuel pools cap — drop-oldest (cap_player_pools idiom, own group)
const TANKER_POOL_DPS := 20.0            # fuel-fire pool dps (scaled by the boss's special_mult; HazardZone's ENEMY_/PLAYER_ mults apply on top)
const TANKER_POOL_RADIUS := 70.0         # px pool radius
const TANKER_POOL_DURATION := 4.0        # seconds a pool burns after igniting
const TANKER_IGNITE_DELAY := 0.9         # puddle→ignite windup: cross the wet fuel early or lose the lane
const TANKER_JACKKNIFE_RETELEGRAPH := 0.4  # pause between the two JACKKNIFE dashes (re-aims at the player)
```

`scripts/patterns/TrailDash.gd`:

```gdscript
class_name TrailDash
extends ChargeDash
## THE TANKER's leaking charge. The parent runs the whole telegraph/dash/hit protocol; this
## subclass drops a fire HazardZone every `spacing` px of dash travel (puddle first — the
## pool's windup IS the ignite delay — then flame), keeps the live-pool count under
## TANKER_TRAIL_MAX via drop-oldest on its own group, and optionally chains a second dash
## (`chain`: JACKKNIFE) that re-aims at the player's CURRENT position after a short
## re-telegraph. `charging` stays true across the whole chain so BossBase's chase never
## grabs the body between dashes; ChargeDash._exit_tree still resets it if the boss dies
## mid-chain.

const FUEL_GROUP := "tanker_fuel"

var _spacing := GameConfig.TANKER_TRAIL_SPACING
var _chain := 0
var _dist_acc := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_spacing = float(cfg.get("spacing", GameConfig.TANKER_TRAIL_SPACING))
	_chain = int(cfg.get("chain", 0))

func _on_telegraph_end() -> void:
	super._on_telegraph_end()
	_dist_acc = 0.0

func _physics_process(delta: float) -> void:
	var before := global_position
	super._physics_process(delta)   # parent moves the boss and re-anchors global_position to it
	if not _fired:
		return
	_dist_acc += global_position.distance_to(before)
	while _dist_acc >= _spacing:
		_dist_acc -= _spacing
		_drop_pool()

## One fuel pool at the current position, capped drop-oldest on FUEL_GROUP. Pools also join
## the generic "hazard_zones" group inside configure_hazard — deliberately NOT checked against
## MAX_HAZARD_ZONES here: a boss move must not be starved by ambient barrel fires.
func _drop_pool() -> void:
	var pools := get_tree().get_nodes_in_group(FUEL_GROUP)
	if pools.size() >= GameConfig.TANKER_TRAIL_MAX:
		var oldest = pools[0]   # group order == spawn order
		if is_instance_valid(oldest):
			oldest.remove_from_group(FUEL_GROUP)   # leave immediately so a same-frame recount stays accurate
			oldest.queue_free()
	var hz := HazardZone.new()
	get_tree().current_scene.add_child(hz)
	hz.global_position = global_position
	hz.configure_hazard({ "color": Hazards.ORANGE, "dps": GameConfig.TANKER_POOL_DPS * _special_mult_of(boss),
		"radius": GameConfig.TANKER_POOL_RADIUS, "duration": GameConfig.TANKER_POOL_DURATION,
		"windup": GameConfig.TANKER_IGNITE_DELAY, "puddle": true, "hurts_player": true })
	hz.add_to_group(FUEL_GROUP)

## JACKKNIFE: instead of freeing after dash 1, re-telegraph briefly and dash again at the
## player's CURRENT position. Each chained dash gets its own hit-once budget.
func _end_charge() -> void:
	if _chain > 0 and _boss_body != null and is_instance_valid(_boss_body):
		_chain -= 1
		_hit_player = false
		_fired = false
		_windup = GameConfig.TANKER_JACKKNIFE_RETELEGRAPH
		if player != null and is_instance_valid(player):
			_aim_point = player.global_position
		queue_redraw()
		return   # _boss_body.charging stays true through the re-telegraph
	super._end_charge()
```

`scenes/patterns/TrailDash.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/patterns/TrailDash.gd" id="1"]

[node name="TrailDash" type="Node2D"]
script = ExtResource("1")
```

`scripts/logic/Patterns.gd` — add:

```gdscript
const TRAIL := preload("res://scenes/patterns/TrailDash.tscn")
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.** (If pool count is off by one, check whether `super._physics_process` early-returns before moving on the final tick — adjust the probe's expected range, not the spacing logic, as long as spacing is visibly regular.)
- [ ] **Step 5: `rm` probe, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/patterns/TrailDash.gd scenes/patterns/TrailDash.tscn scripts/logic/Patterns.gd scripts/logic/GameConfig.gd && git commit -m "feat(patterns): TrailDash — charge that leaks igniting fuel pools, JACKKNIFE chain"
```

---

### Task 7: THE TANKER boss

**Files:**
- Create: `scripts/bosses/Tanker.gd`, `scenes/bosses/Tanker.tscn`
- Modify: `scripts/logic/Bosses.gd`, `scripts/logic/GameConfig.gd`

**Interfaces:**
- Consumes: `Patterns.TRAIL` (T6), `Patterns.ZONE` (Fryer's cfg shape: `radius`/`dps`/`duration`/`at`/`windup`), `Patterns.RING`.
- Produces: registry id `"tanker"` / `"THE TANKER"`; `Bosses.count() == 9`.

- [ ] **Step 1: Failing probe** — `res://_probe.gd`:

```gdscript
extends SceneTree
func _init() -> void:
	var fails := 0
	if Bosses.count() != 9:
		fails += 1; print("PROBE FAIL Bosses.count %d != 9" % Bosses.count())
	if Bosses.name_for("tanker") != "THE TANKER":
		fails += 1; print("PROBE FAIL name_for tanker")
	var t := Tanker.new()
	var ph: Array = t._build_phases()
	if ph.size() != 3 or float(ph[0].get("at", 0.0)) != 1.0:
		fails += 1; print("PROBE FAIL phase table shape")
	# P3 must contain a chained TrailDash (JACKKNIFE)
	var found_chain := false
	for entry in (ph[2].get("patterns", []) as Array):
		var params: Dictionary = entry.get("params", {})
		if int(params.get("chain", 0)) > 0:
			found_chain = true
	if not found_chain:
		fails += 1; print("PROBE FAIL P3 has no chained dash")
	if absf(t._hp_mult() - GameConfig.TANKER_HP / GameConfig.BOSS_BASE_HP) > 0.001:
		fails += 1; print("PROBE FAIL hp mult")
	t.free()
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	quit(fails)
```

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd`, complete the TANKER block:

```gdscript
const TANKER_HP := 2400.0              # second-tankiest after Manager (3000) — a truck
const TANKER_SPEED_MULT := 0.5         # crawls between bursts; the dashes ARE the mobility
const TANKER_CHARGE_SPEED := 600.0     # px/sec dash (under Courier's 650 but lasts longer)
const TANKER_CHARGE_DURATION := 1.0    # seconds per dash — a long haul so the trail matters
const TANKER_JACKKNIFE_SPACING := 60.0 # denser P3 trail (base spacing 90)
const TANKER_RUPTURE_RADIUS := 260.0   # P3 tank-rupture ExpandingRing radius
const TANKER_RUPTURE_DAMAGE := 40.0    # tank-rupture damage
```

`scripts/bosses/Tanker.gd`:

```gdscript
class_name Tanker
extends BossBase
## THE TANKER — the fuel-delivery driver who never left. Crawls between bursts; all the threat
## is in TrailDash: long charges that leak fuel puddles which ignite after a beat, carving the
## kite space into burning corridors (area denial that CHASES, vs the Fryer's static zones).
## P2 layers static fuel spills near the player; P3 is the JACKKNIFE — two chained dashes with
## a denser trail, capped with a tank-rupture ring when he stops. Combat-model exploit: the
## arena itself shrinks around your dodge lanes.

const BOSS_ID := "tanker"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.TANKER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var dash := { "speed": GameConfig.TANKER_CHARGE_SPEED, "duration": GameConfig.TANKER_CHARGE_DURATION,
		"windup": 0.9 }
	var spill := { "radius": 100.0, "dps": GameConfig.TANKER_POOL_DPS, "duration": GameConfig.TANKER_POOL_DURATION,
		"at": "player", "windup": 0.9 }
	var jackknife := { "speed": GameConfig.TANKER_CHARGE_SPEED, "duration": GameConfig.TANKER_CHARGE_DURATION,
		"windup": 0.9, "chain": 1, "spacing": GameConfig.TANKER_JACKKNIFE_SPACING }
	var rupture := { "radius": GameConfig.TANKER_RUPTURE_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.TANKER_RUPTURE_DAMAGE, "windup": GameConfig.SLAM_WINDUP }
	return [
		{
			"at": 1.0, "cadence": 4.6, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": dash },
			],
		},
		{
			"at": 0.66, "cadence": 4.0, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": dash },
				{ "scene": Patterns.ZONE, "params": spill },
			],
		},
		{
			"at": 0.33, "cadence": 3.4, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": jackknife },
				{ "scene": Patterns.RING, "params": rupture },
			],
		},
	]

## Regalia over the shared sprite until real art loads: trucker cap + a coiled hose loop with
## nozzle. Palette C2/C4/C1 only.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-14, -34), Vector2(28, 8)), PixelTheme.ACCENT_DIM)    # cap crown
	draw_rect(Rect2(Vector2(-20, -26), Vector2(40, 4)), PixelTheme.ACCENT_DIM)    # cap brim
	draw_arc(Vector2(16, 10), 12.0, 0.0, TAU, 24, PixelTheme.ACCENT, 3.0)         # coiled hose
	draw_rect(Rect2(Vector2(26, 16), Vector2(8, 4)), PixelTheme.DARK)             # nozzle
```

`scenes/bosses/Tanker.tscn`:

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/bosses/Tanker.gd" id="1_tanker"]
[ext_resource type="Texture2D" path="res://art/enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]
[ext_resource type="PackedScene" path="res://scenes/RelicPickup.tscn" id="5_relic"]

[sub_resource type="CircleShape2D" id="CircleShape2D_tanker"]
radius = 46.0

[node name="Tanker" type="CharacterBody2D"]
script = ExtResource("1_tanker")
xp_gem_scene = ExtResource("3_gem")
relic_pickup_scene = ExtResource("5_relic")

[node name="Sprite2D" type="Sprite2D" parent="."]
z_index = -1
scale = Vector2(2.4, 2.4)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_tanker")
```

`scripts/logic/Bosses.gd` — append after the karen row:

```gdscript
	{ "id": "tanker", "scene": preload("res://scenes/bosses/Tanker.tscn"), "name": "THE TANKER" },
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: `rm` probe, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm _probe.gd && git add scripts/bosses/Tanker.gd scenes/bosses/Tanker.tscn scripts/logic/Bosses.gd scripts/logic/GameConfig.gd && git commit -m "feat(boss): THE TANKER — igniting fuel trails, JACKKNIFE double dash, tank rupture"
```

---

### Task 8: Boss sprites (home repo generator → game repo art)

**Files:**
- Modify: `/home/larryun/gen_palette_sprites.py` (builders near line 552, `BOSS_SPRITES` line 617)
- Create (generated): `/mnt/c/Users/thela/Documents/mobile-game/art/bosses/karen.png`, `.../tanker.png`

**Interfaces:**
- Consumes: generator helpers `canvas/circle/rect/pset/_shade_gun/_rect_border`, palette consts `C1..C4`; `BossBase._setup_sprite` loads `art/bosses/<boss_id()>.png` — WITHOUT these PNGs every Karen/Tanker spawn push_warns (generator-drift guard).
- Produces: the two 48px PNGs; contact sheet updated (it iterates `BOSS_SPRITES`).

- [ ] **Step 1: Add builders + registry rows** to `gen_palette_sprites.py` (after `_build_boss_courier`, following the eye idiom `rect 4x4 C1 + pset C4` = sockets):

```python
def _build_boss_karen():
    w = 48
    b = canvas(w, w)
    circle(b, w, 24, 26, 13, C3)                  # body
    circle(b, w, 24, 12, 9, C3)                   # head
    _shade_gun(b, w)
    # bob haircut: C2 crown + side wedges hanging past the jaw
    circle(b, w, 24, 8, 9, C2)
    rect(b, w, 13, 8, 4, 12, C2); rect(b, w, 31, 8, 4, 12, C2)
    # sunglasses band across the face: C1 with two C4 glints
    rect(b, w, 16, 12, 16, 4, C1)
    pset(b, w, 19, 13, C4); pset(b, w, 28, 13, C4)
    # handbag at her side: C4 fill + C1 frame + strap
    rect(b, w, 34, 26, 10, 9, C4); _rect_border(b, w, 34, 26, 10, 9, C1)
    rect(b, w, 38, 20, 1, 6, C1)
    return b

def _build_boss_tanker():
    w = 48
    b = canvas(w, w)
    rect(b, w, 10, 16, 28, 22, C3)                # barrel torso (a truck of a man)
    circle(b, w, 24, 10, 7, C3)                   # head
    _shade_gun(b, w)
    rect(b, w, 20, 8, 4, 4, C1); rect(b, w, 26, 8, 4, 4, C1)   # eye sockets
    pset(b, w, 21, 9, C4); pset(b, w, 27, 9, C4)
    # trucker cap: C2 crown + brim
    circle(b, w, 24, 5, 7, C2)
    rect(b, w, 14, 7, 20, 3, C2)
    # coiled hose on the shoulder: C4 square loop + C1 nozzle
    _rect_border(b, w, 32, 20, 12, 12, C4)
    _rect_border(b, w, 34, 22, 8, 8, C4)
    rect(b, w, 40, 32, 6, 3, C1)
    return b
```

Append to `BOSS_SPRITES`:

```python
    ("karen",         _build_boss_karen,         "KAREN"),
    ("tanker",        _build_boss_tanker,        "TANKER"),
```

- [ ] **Step 2: Regenerate + contact sheet** (check the sheet function's name first: `grep -n "^def " /home/larryun/gen_palette_sprites.py | tail -5`):

```bash
cd /home/larryun && python3 -c "import gen_palette_sprites as g; g.bosses(); g.contact_sheet()"
```

- [ ] **Step 3: Multimodal QA (controller does this, not a text-only check):** Read the contact-sheet PNG. Verify: both new sprites read at a glance (bob+sunglasses+bag / cap+torso+hose), outlines clean (no ragged edges — Pack F QA lesson), features don't merge into the body, all 4 colors only. Iterate the builders if not.
- [ ] **Step 4: Boot-spawn check** — run the boot gate; expect 0 AND no `no sprite for boss id` warning in the output.
- [ ] **Step 5: Commit both repos:**

```bash
cd /home/larryun && git add gen_palette_sprites.py && git commit -m "gen_palette_sprites: karen + tanker 48px boss sprites

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
cd "/mnt/c/Users/thela/Documents/mobile-game" && git add art/bosses/karen.png art/bosses/tanker.png && git commit -m "art(bosses): THE KAREN + THE TANKER 48px palette sprites"
```

---

### Task 9: Ship v0.1.60

**Files:**
- Modify: `CHANGELOG.md` (game repo)

- [ ] **Step 1: Full-repo final gates** — BOTH gates (0/0) on a clean tree.
- [ ] **Step 2: CHANGELOG entry** (newest-first, player-facing) — write it now but commit `[skip ci]` only AFTER the push in Step 3 confirms the run number, so the version header is correct:

```markdown
## v0.1.60 — New Management Problems
- NEW BOSS: THE KAREN — she screams you out of your firing stance, films you for the review, and at the end she gets the manager. He buffs the staff.
- NEW BOSS: THE TANKER — pump 3's delivery driver. His charges leak fuel that catches. Don't stand in the wet stuff.
- Boss roster is now 9 deep; both join Endless rotation and Boss Rush.
```

- [ ] **Step 3: Push + CI:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && CODE_SHA=$(git rev-parse HEAD) && git push
gh run watch --repo Garry-Systems/the-dead-shift $(gh run list --repo Garry-Systems/the-dead-shift -L 1 --json databaseId -q '.[0].databaseId')
```

Expect GREEN. Confirm the run number (should be 60 — if not, the version below is `0.1.<run>`; adjust tag + changelog header).

- [ ] **Step 4: Tag + release** (ritual from v0.1.26 convention):

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add CHANGELOG.md && git commit -m "docs(changelog): v0.1.60 New Management Problems [skip ci]" && git push
git tag v0.1.60 "$CODE_SHA" && git push origin v0.1.60   # $CODE_SHA = the pushed code commit CI built (captured in Step 3)
gh release download android-latest --repo Garry-Systems/the-dead-shift -p '*.apk' -D /tmp/apk60
gh release create v0.1.60 /tmp/apk60/*.apk --repo Garry-Systems/the-dead-shift --title "v0.1.60 — New Management Problems" --notes "THE KAREN and THE TANKER join the staff roster. Roster 7 → 9."
```

- [ ] **Step 5: Update memory + report.** Larry's F5 checklist: Karen shove feel on touch (fair or annoying?); decoys visibly steal auto-aim; GET ME THE MANAGER callout + big alpha add shows its ring and buffs adds; jam window reads; Tanker puddles readable at wave-15 density; puddle→ignite timing dodgeable; JACKKNIFE second dash re-aims and is dodgeable; rupture ring after the double dash; no boss-bar weirdness; both bosses appear in Boss Rush. ⚠️ All numbers starter values.

---

## Self-review notes (already applied)

- Spec §1/§2 kits fully covered by T1-T7; §3 plumbing by T4/T7/T8; §5 testing folded into per-task probes + the dual gate; §6 out-of-scope respected (no lore lines in this pack).
- Type consistency: `apply_shove(Vector2)` (T1) matches ScreamRing's call (T2); `elite_kind` string key (T3) matches Karen's params (T4); `windup`/`puddle` keys (T5) match TrailDash's pool cfg (T6); `Patterns.SCREAM`/`Patterns.TRAIL` names consistent.
- Known intentional couplings: shove interrupts stop-to-shoot fire (documented in T1 comment); trail pools bypass `MAX_HAZARD_ZONES` (documented in T6 comment); elite promotion bypasses the ambient gate (documented in T3 comment).

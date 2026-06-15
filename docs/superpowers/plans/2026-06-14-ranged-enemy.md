# Ranged "Spitter" Enemy — Implementation Plan

> **For agentic workers:** small feature; executed inline with the headless compile gate after each task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a ranged "Spitter" enemy (holds distance, fires `BossProjectile`s) that mixes into ~25% of trash spawns from wave 10. Spec: `docs/superpowers/specs/2026-06-14-ranged-enemy-design.md`.

**Branch:** `feat/boss-framework`. **Gate:** the same headless command used for the boss framework (`--headless --editor --quit`, grep errors, ignore `menu_background.jpg`). Expected empty after each task.

---

### Task 1: GameConfig — ranged-enemy constants

Append to `scripts/logic/GameConfig.gd`:
```gdscript

# --- Ranged enemy (Spitter) ---
const RANGED_ENEMY_MIN_WAVE := 10        # spitters start mixing in at this wave
const RANGED_ENEMY_SPAWN_CHANCE := 0.25  # fraction of trash spawns that are spitters (wave >= min)
const RANGED_PREFERRED_DIST := 450.0     # px standoff the spitter tries to hold
const RANGED_FIRE_INTERVAL := 1.8        # seconds between shots
const RANGED_FIRE_RANGE := 700.0         # px; only fires within this range
const RANGED_PROJECTILE_SPEED := 320.0   # px/sec
const RANGED_PROJECTILE_DAMAGE := 12.0   # flat damage per hit
```
- [ ] Append, gate, commit `Ranged enemy: GameConfig constants`.

### Task 2: Enemy.gd refactor (no regression)

In `scripts/Enemy.gd`:
- [ ] Add `class_name Enemy` as the first line (above `extends CharacterBody2D`).
- [ ] In `_physics_process`, replace the chase line `var dir := (_target.global_position - global_position).normalized()` + `velocity = dir * (move_speed * _slow_factor)` with `velocity = _desired_velocity() * _slow_factor`.
- [ ] After `move_and_slide()` (before the contact-damage check), add `_act(delta)`.
- [ ] Add the two virtuals (place near the bottom, before `_touching_player` or after `_physics_process`):
```gdscript
## Base movement intent (before slow/knockback). Override per enemy. Default = chase the player.
func _desired_velocity() -> Vector2:
	var dir := (_target.global_position - global_position).normalized()
	return dir * move_speed

## Per-frame action hook (e.g. ranged firing). Default no-op. Called after movement.
func _act(_delta: float) -> void:
	pass
```
- [ ] Gate (confirm normal-enemy behavior unchanged — math is identical). Commit `Ranged enemy: extract Enemy movement + act hooks (class_name, no regression)`.

### Task 3: RangedEnemy.gd + scene

`scripts/RangedEnemy.gd`:
```gdscript
class_name RangedEnemy
extends Enemy
## A ranged "spitter": holds at a preferred distance and fires projectiles at the player on
## a cooldown. Inherits all of Enemy's health/flash/status/gem behavior; only the movement
## (keep-distance) and the fire action differ.

const PROJECTILE_SCENE := preload("res://scenes/BossProjectile.tscn")

var _fire_cd := 0.0

func _ready() -> void:
	super._ready()
	# Stagger the first shot so a group of spitters doesn't volley in unison.
	_fire_cd = randf_range(0.0, GameConfig.RANGED_FIRE_INTERVAL)

## Hold a standoff distance: approach if too far, back off if too close, else hold and shoot.
func _desired_velocity() -> Vector2:
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	if dist < 0.001:
		return Vector2.ZERO
	var dir := to_player / dist
	var pref := GameConfig.RANGED_PREFERRED_DIST
	if dist > pref * 1.1:
		return dir * move_speed
	if dist < pref * 0.9:
		return -dir * move_speed
	return Vector2.ZERO

func _act(delta: float) -> void:
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > GameConfig.RANGED_FIRE_RANGE:
		return
	_fire_cd = GameConfig.RANGED_FIRE_INTERVAL
	var dir := (_target.global_position - global_position).normalized()
	var proj = PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)
	proj.setup(dir, GameConfig.RANGED_PROJECTILE_SPEED, GameConfig.RANGED_PROJECTILE_DAMAGE)
```
`scenes/RangedEnemy.tscn` (clone of Enemy.tscn; script → RangedEnemy.gd, texture → ranged_enemy.png, keep CollisionShape radius 20 + xp_gem_scene export):
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/RangedEnemy.gd" id="1_ranged"]
[ext_resource type="Texture2D" path="res://art/ranged_enemy.png" id="2_tex"]
[ext_resource type="PackedScene" path="res://scenes/XpGem.tscn" id="3_gem"]

[sub_resource type="CircleShape2D" id="CircleShape2D_ranged"]
radius = 20.0

[node name="RangedEnemy" type="CharacterBody2D"]
script = ExtResource("1_ranged")
xp_gem_scene = ExtResource("3_gem")

[node name="Sprite2D" type="Sprite2D" parent="."]
scale = Vector2(1, 1)
texture = ExtResource("2_tex")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_ranged")
```
- [ ] Create both. NOTE: the scene references `art/ranged_enemy.png` (created in Task 4). Create Task 4's art FIRST or before the gate so the scene imports cleanly. Gate, commit `Ranged enemy: RangedEnemy (keep-distance + fire) + scene`.

### Task 4: Art — ranged_enemy.png (C3, 32x32)

In `~/gen_palette_sprites.py` add a `ranged_enemy()` function (32×32, C3 silhouette distinct from `enemy()` — e.g. a hunched body + forward spout + single eye) and call it in the main block. Run `python3 ~/gen_palette_sprites.py`. Produces `art/ranged_enemy.png`.
- [ ] Add fn + call, run, confirm `art/ranged_enemy.png` exists. (Committed together with Task 3's scene, or its own commit `Ranged enemy: C3 placeholder sprite`.)

### Task 5: Spawner + Main.tscn wiring + full gate

`scripts/Spawner.gd`:
- [ ] Add `@export var ranged_enemy_scene: PackedScene` under the existing `@export var enemy_scene`.
- [ ] Rewrite `_spawn_enemy()`:
```gdscript
func _spawn_enemy() -> void:
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var scene := enemy_scene
	if ranged_enemy_scene != null and DifficultyManager.wave >= GameConfig.RANGED_ENEMY_MIN_WAVE and randf() < GameConfig.RANGED_ENEMY_SPAWN_CHANCE:
		scene = ranged_enemy_scene
	var enemy = scene.instantiate()
	enemy.configure(DifficultyManager.enemy_stats())
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _player.global_position + offset
```
`scenes/Main.tscn` (surgical): add a `RangedEnemy.tscn` ext_resource (new id) and `ranged_enemy_scene = ExtResource("<id>")` under the `Spawner` node (next to `enemy_scene`); bump `load_steps` by 1. Leave everything else byte-identical.
- [ ] Apply both. Full gate (empty). Commit `Ranged enemy: Spawner mixes in spitters after wave 10 + Main wiring`.

### Final
- [ ] Full gate clean. Dispatch a review agent over the whole feature (Enemy no-regression, RangedEnemy logic, spawner gating, Main.tscn intact). Then it's ready for Larry's F5 (with the boss framework).

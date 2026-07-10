class_name Companion
extends Node2D
## Coworkers (T3): the equipped coworker fighting alongside the player at runtime. One
## instance per run, spawned by Main.gd's spawn-config pass (see Main._spawn_companion)
## when `SaveManager.equipped_coworker()` resolves to a live instance in
## `SaveManager.coworkers()`. Untargetable (no groups — nothing looks for a Companion the
## way it looks for "enemies"/"player") and indestructible (no take_damage method at all).
## PROCESS_MODE_INHERIT (the Node default, set explicitly below for clarity) so it pauses
## with the tree like every other gameplay node.
##
## Behaviors dispatch on `type` in `_physics_process` — see the per-type sections below.
## Every stat pulled from a GameConfig.COWORKER_* const is baked once in configure()
## (the project's "roll once, store forever" pattern) except each type's own placement/
## orbit cadence const (COWORKER_MANNEQUIN_CD, COWORKER_DRONE_ORBIT), which are flat
## positioning/cadence values the brief never asks to scale — everything ELSE (damage,
## attack interval, acquire range/taunt radius, mannequin HP & taunt duration) is
## `Coworkers.stat_mult(rarity)`-scaled, then further modified by the single rolled trait
## (mutually exclusive — a coworker carries at most one, per Coworkers.roll()).

const CAT_RADIUS_PX := 16.0
const DRONE_RADIUS_PX := 12.0
const MANNEQUIN_RADIUS_PX := 14.0
const CAT_COLOR := Color(0.549, 0.522, 0.451)     # C3 gray-tan
const DRONE_COLOR := Color(0.878, 0.898, 1.0)     # C4 lavender
const MANNEQUIN_COLOR := Color(0.239, 0.0, 0.6)   # C2 indigo

## Set by the spawn-config pass BEFORE configure() — MAGNETIC/STUDIOUS apply to this
## reference at configure()-time. Never re-assigned after spawn.
var player: Player = null

var uid := ""
var type := ""
var rarity := 1
var trait_id := ""

var _follow_angle := 0.0   # rolled once at _ready: fixed relative angle the companion hovers at

# --- Cat state ---
var _cat_interval := GameConfig.COWORKER_CAT_RATE
var _cat_damage := GameConfig.COWORKER_CAT_DAMAGE
var _cat_range := GameConfig.COWORKER_CAT_RANGE
var _cat_cd := 0.0
var _cat_state := "idle"   # idle | lunge | return
var _cat_anchor := Vector2.ZERO
var _cat_target_pos := Vector2.ZERO
var _cat_leg_t := 0.0
var _cat_facing := 1.0     # sprite-flip sign, updated toward the lunge direction

# --- Drone state ---
var _drone_interval := GameConfig.COWORKER_DRONE_RATE
var _drone_damage := GameConfig.COWORKER_DRONE_DAMAGE
var _drone_range := GameConfig.COWORKER_DRONE_RANGE
var _drone_cd := 0.0
var _drone_angle := 0.0

# --- Mannequin state ---
var _mannequin_hp := GameConfig.COWORKER_MANNEQUIN_HP
var _mannequin_radius := GameConfig.COWORKER_MANNEQUIN_TAUNT_RADIUS
var _mannequin_taunt_time := GameConfig.COWORKER_MANNEQUIN_TAUNT_TIME
var _mannequin_cd := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_follow_angle = randf() * TAU
	_drone_angle = randf() * TAU

## Reads type/rarity/trait from `inst` (the {uid,type,rarity,trait} shape T1's Coworkers.roll()
## produces) and bakes every stat this companion needs, all scaled by
## `Coworkers.stat_mult(rarity)` then the rolled trait (if any). `player` must already be set
## (the spawn-config pass assigns it before calling this) — MAGNETIC/STUDIOUS apply to it here,
## once, permanently (run-scoped; never undone, matching every other run-start perk grant in
## Characters.apply_base).
func configure(inst: Dictionary) -> void:
	uid = String(inst.get("uid", ""))
	type = String(inst.get("type", ""))
	rarity = int(inst.get("rarity", 1))
	trait_id = String(inst.get("trait", ""))

	var mult := Coworkers.stat_mult(rarity)
	var dmg_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_SHARP if trait_id == "sharp" else 0.0))
	var rate_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_WIRED if trait_id == "wired" else 0.0))
	var range_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_WIDE if trait_id == "wide" else 0.0))
	var steady_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_STEADY if trait_id == "steady" else 0.0))

	match type:
		"cat":
			_cat_interval = GameConfig.COWORKER_CAT_RATE / rate_mult
			_cat_damage = GameConfig.COWORKER_CAT_DAMAGE * dmg_mult
			_cat_range = GameConfig.COWORKER_CAT_RANGE * range_mult
			_cat_cd = _cat_interval
		"drone":
			_drone_interval = GameConfig.COWORKER_DRONE_RATE / rate_mult
			_drone_damage = GameConfig.COWORKER_DRONE_DAMAGE * dmg_mult
			_drone_range = GameConfig.COWORKER_DRONE_RANGE * range_mult
			_drone_cd = _drone_interval
		"mannequin":
			_mannequin_hp = GameConfig.COWORKER_MANNEQUIN_HP * steady_mult
			_mannequin_radius = GameConfig.COWORKER_MANNEQUIN_TAUNT_RADIUS * range_mult
			_mannequin_taunt_time = GameConfig.COWORKER_MANNEQUIN_TAUNT_TIME * steady_mult
			_mannequin_cd = GameConfig.COWORKER_MANNEQUIN_CD   # flat placement cadence — brief never asks this to scale

	if player != null and is_instance_valid(player):
		if trait_id == "magnetic":
			player.upgrade_pickup_radius(GameConfig.COWORKER_TRAIT_MAGNETIC)   # Delivery Girl's exact mechanism (Characters.gd)
		elif trait_id == "studious":
			player.upgrade_xp_gain(GameConfig.COWORKER_TRAIT_STUDIOUS)         # "Fast Learner" card's exact mechanism (Player.gd)

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	match type:
		"cat":
			_process_cat(delta)
		"drone":
			_process_drone(delta)
		"mannequin":
			_process_mannequin(delta)
	queue_redraw()

## Hover-follow: closes the gap to a fixed point trailing the player at `dist`px, at
## COWORKER_FOLLOW_SPEED. Used by cat (while idle) and mannequin (always — placing a decoy
## doesn't move the companion node itself).
func _hover_follow(delta: float, dist: float) -> void:
	var target := player.global_position + Vector2.RIGHT.rotated(_follow_angle) * dist
	global_position = global_position.move_toward(target, GameConfig.COWORKER_FOLLOW_SPEED * delta)

## Nearest "enemies"-group member (Enemy or BossBase — both add to that group) within
## `max_range`, or null. Mirrors Gun._nearest_enemy's distance-squared idiom.
func _nearest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_range * max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var node := e as Node2D
		var d: float = global_position.distance_squared_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

## CHILLING/PINNING "ride the attack" — riders applied after any cat pounce or drone shot
## lands (never mannequin, which never deals damage and whose trait pool excludes both).
## Mutually exclusive with each other (a coworker rolls exactly one trait). PINNING can only
## arrive here on a DRONE — Coworkers.TRAITS_FOR excludes it from the cat's pool, whose
## pounce already always pins (a rider there would be a dead maxf-refresh no-op).
func _apply_trait_riders(body: Node) -> void:
	if trait_id == "chilling" and body.has_method("apply_slow"):
		body.apply_slow(GameConfig.COWORKER_TRAIT_CHILLING_SLOW, GameConfig.COWORKER_TRAIT_CHILLING_DUR)
	elif trait_id == "pinning" and body.has_method("apply_pin") and randf() < GameConfig.COWORKER_TRAIT_PINNING_CHANCE:
		body.apply_pin(GameConfig.COWORKER_CAT_PIN)

# --- Cat: every _cat_interval, pounce the nearest enemy in range. LoS-free, hits instantly
# on acquire; the lunge-out/snap-back is a purely cosmetic dash animation over the frozen hit
# point (so a target that dies or wanders mid-animation can't desync the visual). ---
func _process_cat(delta: float) -> void:
	match _cat_state:
		"idle":
			_hover_follow(delta, GameConfig.COWORKER_FOLLOW_DIST)
			_cat_cd -= delta
			if _cat_cd <= 0.0:
				_cat_cd = _cat_interval
				var target := _nearest_enemy(_cat_range)
				if target != null:
					_cat_anchor = global_position
					_cat_target_pos = target.global_position
					_cat_facing = signf(_cat_target_pos.x - _cat_anchor.x) if _cat_target_pos.x != _cat_anchor.x else _cat_facing
					_resolve_cat_hit(target)
					_cat_state = "lunge"
					_cat_leg_t = 0.0
		"lunge":
			_cat_leg_t += delta
			var f := clampf(_cat_leg_t / GameConfig.COWORKER_CAT_LUNGE_TIME, 0.0, 1.0)
			global_position = _cat_anchor.lerp(_cat_target_pos, f)
			if f >= 1.0:
				_cat_state = "return"
				_cat_leg_t = 0.0
		"return":
			_cat_leg_t += delta
			var f2 := clampf(_cat_leg_t / GameConfig.COWORKER_CAT_LUNGE_TIME, 0.0, 1.0)
			global_position = _cat_target_pos.lerp(_cat_anchor, f2)
			if f2 >= 1.0:
				_cat_state = "idle"

func _resolve_cat_hit(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.take_damage(_cat_damage)
	if target.has_method("apply_pin"):
		target.apply_pin(GameConfig.COWORKER_CAT_PIN)
	_apply_trait_riders(target)

# --- Drone: continuously orbits the player; every _drone_interval, fires a CompanionBullet
# (raw take_damage, no talents/crit — Global Constraints) at the nearest enemy in range. ---
func _process_drone(delta: float) -> void:
	_drone_angle += GameConfig.COWORKER_DRONE_ORBIT_SPEED * delta
	global_position = player.global_position + Vector2.RIGHT.rotated(_drone_angle) * GameConfig.COWORKER_DRONE_ORBIT
	_drone_cd -= delta
	if _drone_cd <= 0.0:
		_drone_cd = _drone_interval
		var target := _nearest_enemy(_drone_range)
		if target != null:
			_fire_drone_shot(target)

func _fire_drone_shot(target: Node2D) -> void:
	var bullet := CompanionBullet.new()
	bullet.direction = (target.global_position - global_position).normalized()
	bullet.damage = _drone_damage
	bullet.max_travel = _drone_range
	bullet.trait_id = trait_id
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

# --- Mannequin: hover-follows like the cat (idle); every _mannequin_cd, places a fresh decoy
# at the player's position (cap 1 — MannequinDecoy.spawn frees any existing one first). ---
func _process_mannequin(delta: float) -> void:
	_hover_follow(delta, GameConfig.COWORKER_FOLLOW_DIST)
	_mannequin_cd -= delta
	if _mannequin_cd <= 0.0:
		_mannequin_cd = GameConfig.COWORKER_MANNEQUIN_CD
		MannequinDecoy.spawn(player.global_position, _mannequin_hp, _mannequin_radius, _mannequin_taunt_time, get_tree())

func _draw() -> void:
	match type:
		"cat":
			draw_circle(Vector2.ZERO, CAT_RADIUS_PX, CAT_COLOR)
			# "sprite flip toward motion": a triangle nose pointing the last horizontal direction.
			var tip := Vector2(CAT_RADIUS_PX * 1.4 * _cat_facing, 0.0)
			draw_line(Vector2.ZERO, tip, PixelTheme.DARK, 2.0)
		"drone":
			draw_circle(Vector2.ZERO, DRONE_RADIUS_PX, DRONE_COLOR)
			draw_arc(Vector2.ZERO, DRONE_RADIUS_PX + 3.0, 0.0, TAU, 16, DRONE_COLOR, 1.5)
		"mannequin":
			draw_circle(Vector2.ZERO, MANNEQUIN_RADIUS_PX, MANNEQUIN_COLOR)

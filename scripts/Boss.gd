class_name Boss
extends CharacterBody2D
## A brute boss: slow, huge HP, heavy contact damage, with a periodic telegraphed
## ground slam. Stats are baked at spawn via configure() (scaled by spawn wave). On
## death it drops a big XP burst, full-heals the player, and drops one relic. It is in
## the "enemies" group so bullets/auto-aim hit it, and the "boss" group so the HUD can
## show its health bar.

@export var xp_gem_scene: PackedScene
@export var slam_wave_scene: PackedScene
@export var relic_pickup_scene: PackedScene

var max_health := GameConfig.BOSS_BASE_HP
var move_speed := GameConfig.BOSS_MOVE_SPEED
var touch_damage := GameConfig.BOSS_TOUCH_DAMAGE

var _health: Health
var _target: Player
var _slam_cd := GameConfig.SLAM_INTERVAL
var _burn_dps := 0.0
var _burn_time := 0.0

## Bakes scaled stats at spawn (called by the Spawner).
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"])
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	_health = Health.new(max_health)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:
		_health = Health.new(max_health)

## Fraction of health remaining (0..1) for the HUD bar.
func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

## Incendiary burn from a bullet (same contract as Enemy.ignite).
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

	var dir := (_target.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

	if global_position.distance_to(_target.global_position) < 60.0:
		_target.take_damage(touch_damage * delta)

	_slam_cd -= delta
	if _slam_cd <= 0.0:
		_slam_cd = GameConfig.SLAM_INTERVAL
		_slam()

func _slam() -> void:
	if slam_wave_scene == null:
		return
	var wave = slam_wave_scene.instantiate()
	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position

func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_die()

func _die() -> void:
	_reward()
	queue_free()

func _reward() -> void:
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
	# Relic drop: one relic that is neither owned nor banned this run.
	var bar := get_tree().get_first_node_in_group("relic_bar")
	if bar != null and relic_pickup_scene != null:
		var id: String = bar.call("roll_drop")
		if id != "":
			var pickup = relic_pickup_scene.instantiate()
			pickup.relic_id = id
			get_tree().current_scene.add_child(pickup)
			pickup.global_position = global_position

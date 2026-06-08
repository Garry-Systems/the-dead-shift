extends CharacterBody2D
## An enemy: walks toward the player, has health, damages the player on contact,
## and drops an XP gem when it dies. Stats are baked once at spawn via configure()
## (the project's "roll once, store forever" pattern) so a wave-8 enemy keeps wave-8
## stats even into wave 9.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")

@export var xp_gem_scene: PackedScene

# Baked per-enemy stats (set by configure(); fall back to base config if spawned raw).
var max_health := GameConfig.ENEMY_MAX_HEALTH
var move_speed := GameConfig.ENEMY_MOVE_SPEED
var touch_damage := GameConfig.ENEMY_TOUCH_DAMAGE

var _health: Health
var _target: Player
var _burn_dps := 0.0
var _burn_time := 0.0          # seconds of burn remaining (incendiary talent)
var _flash_mat: ShaderMaterial
var _health_bar: EnemyHealthBar

## Bakes scaled stats at spawn. Called by the Spawner before/at add_child.
## Cast every Variant out of the dict explicitly to dodge the GDScript typing traps.
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"])
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	_health = Health.new(max_health)

func _ready() -> void:
	add_to_group("enemies")
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:                       # spawned without configure() -> base stats
		_health = Health.new(max_health)
	_setup_flash()
	_health_bar = EnemyHealthBar.new()
	_health_bar.position = Vector2(0, -28)
	_health_bar.z_index = 1
	add_child(_health_bar)

## Gives this sprite its own flash material so a hit flashes only this enemy.
func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	spr.material = _flash_mat

## Brief white pop on bullet impact (called by Bullet, not by burn ticks).
func flash_hit() -> void:
	if _flash_mat == null:
		return
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.12)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

## Applies (or refreshes) an incendiary burn — damage over time, set by a bullet.
func ignite(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)

## Remaining-health fraction (for the above-head bar).
func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

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

	# Deal damage-per-second while overlapping the player (simple distance check).
	if global_position.distance_to(_target.global_position) < 40.0:
		_target.take_damage(touch_damage * delta)

func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_drop_gem()
		queue_free()
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())

func _drop_gem() -> void:
	if xp_gem_scene == null:
		return
	var gem = xp_gem_scene.instantiate()
	get_tree().current_scene.add_child(gem)
	gem.global_position = global_position

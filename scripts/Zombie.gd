extends CharacterBody2D
## A zombie: walks toward the player, has health, damages the player on contact,
## and drops an XP gem when it dies.

@export var xp_gem_scene: PackedScene

var _health := Health.new(GameConfig.ZOMBIE_MAX_HEALTH)
var _target: Player
var _burn_dps := 0.0
var _burn_time := 0.0          # seconds of burn remaining (incendiary talent)

func _ready() -> void:
	add_to_group("zombies")
	_target = get_tree().get_first_node_in_group("player") as Player

## Applies (or refreshes) an incendiary burn — damage over time, set by a bullet.
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
	velocity = dir * GameConfig.ZOMBIE_MOVE_SPEED
	move_and_slide()

	# Deal damage-per-second while overlapping the player (simple distance check).
	if global_position.distance_to(_target.global_position) < 40.0:
		_target.take_damage(GameConfig.ZOMBIE_TOUCH_DAMAGE * delta)

func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_drop_gem()
		queue_free()

func _drop_gem() -> void:
	if xp_gem_scene == null:
		return
	var gem = xp_gem_scene.instantiate()
	get_tree().current_scene.add_child(gem)
	gem.global_position = global_position

extends CharacterBody2D
## A zombie: walks toward the player, has health, and damages the player on contact.

var _health := Health.new(GameConfig.ZOMBIE_MAX_HEALTH)
var _target: Player

func _ready() -> void:
	add_to_group("zombies")
	_target = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
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
		queue_free()

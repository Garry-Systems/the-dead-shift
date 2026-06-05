extends Node2D
## Spawns zombies on a timer in a ring around the player.

@export var zombie_scene: PackedScene
var _player: Node2D
var _timer := 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if _player == null or zombie_scene == null:
		return

	_timer += delta
	if _timer < GameConfig.SPAWN_INTERVAL:
		return
	_timer = 0.0

	# Random point on a ring around the player, just off-screen.
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS

	var zombie = zombie_scene.instantiate()
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = _player.global_position + offset

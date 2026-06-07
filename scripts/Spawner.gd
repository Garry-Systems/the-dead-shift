extends Node2D
## Spawns enemies on a ring around the player. The spawn rate and each enemy's stats
## come from the DifficultyManager autoload, so both ramp with the current wave.

@export var enemy_scene: PackedScene
var _player: Node2D
var _timer := 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if _player == null or enemy_scene == null:
		return

	_timer += delta
	if _timer < DifficultyManager.spawn_interval():
		return
	_timer = 0.0
	_spawn_enemy()

func _spawn_enemy() -> void:
	# Random point on a ring around the player, just off-screen.
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS

	var enemy = enemy_scene.instantiate()
	enemy.configure(DifficultyManager.enemy_stats())
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _player.global_position + offset

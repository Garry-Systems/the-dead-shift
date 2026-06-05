extends Node2D
## Auto-targets the nearest zombie in range and fires bullets on an interval.

@export var bullet_scene: PackedScene
var _cooldown := 0.0

func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0 or bullet_scene == null:
		return

	var target := _find_nearest_zombie()
	if target == null:
		return

	_fire((target.global_position - global_position).normalized())
	_cooldown = GameConfig.GUN_FIRE_INTERVAL

func _find_nearest_zombie() -> Node2D:
	var zombies := get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty():
		return null

	var points: Array[Vector2] = []
	for z in zombies:
		points.append((z as Node2D).global_position)

	var idx := TargetSelector.nearest_index_in_range(global_position, points, GameConfig.GUN_RANGE)
	if idx < 0:
		return null
	return zombies[idx] as Node2D

func _fire(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

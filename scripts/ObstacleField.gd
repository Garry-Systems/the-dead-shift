extends Node2D
## Scatters destructible obstacles around the roaming player, culls far ones (the distance
## culling enemies lack), and drops a cluster on each new wave. Mirrors Spawner's ring math.
## Self-inits from the "player" group like Spawner; lives as a sibling node in Main.tscn.

var _player: Node2D
var _spawn_t := 0.0
var _cull_t := 0.0
var _prev_wave := 1

func _ready() -> void:
	add_to_group("obstacle_field")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if DifficultyManager.wave != _prev_wave:
		_prev_wave = DifficultyManager.wave
		_drop_cluster()
	_spawn_t += delta
	if _spawn_t >= GameConfig.OBSTACLE_SPAWN_INTERVAL:
		_spawn_t = 0.0
		_ambient_topup()
	_cull_t += delta
	if _cull_t >= GameConfig.OBSTACLE_CULL_INTERVAL:
		_cull_t = 0.0
		_cull_far()

func _ambient_topup() -> void:
	var all_d := get_tree().get_nodes_in_group("destructibles")
	if all_d.size() >= GameConfig.OBSTACLE_HARD_CAP:
		return
	var keep2 := GameConfig.OBSTACLE_KEEP_RADIUS * GameConfig.OBSTACLE_KEEP_RADIUS
	var near := 0
	for d in all_d:
		if is_instance_valid(d) and (d as Node2D).global_position.distance_squared_to(_player.global_position) <= keep2:
			near += 1
	if near >= GameConfig.OBSTACLE_TARGET_COUNT:
		return
	var ang := randf_range(0.0, TAU)
	var r := randf_range(GameConfig.OBSTACLE_SPAWN_MIN_R, GameConfig.OBSTACLE_SPAWN_MAX_R)
	_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

func _drop_cluster() -> void:
	for i in GameConfig.OBSTACLE_CLUSTER_SIZE:
		if get_tree().get_nodes_in_group("destructibles").size() >= GameConfig.OBSTACLE_HARD_CAP:
			return
		var ang := randf_range(0.0, TAU)
		var r := randf_range(GameConfig.OBSTACLE_CLUSTER_MIN_R, GameConfig.OBSTACLE_CLUSTER_RADIUS)
		_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

func _spawn_at(pos: Vector2) -> void:
	var d := Destructible.new()
	d.configure(Obstacles.pick(DifficultyManager.wave))
	get_tree().current_scene.add_child(d)
	d.global_position = pos

func _cull_far() -> void:
	var cull2 := GameConfig.OBSTACLE_CULL_RADIUS * GameConfig.OBSTACLE_CULL_RADIUS
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if d.has_method("is_fusing") and d.is_fusing():
			continue   # don't cull a barrel mid chain-fuse
		if (d as Node2D).global_position.distance_squared_to(_player.global_position) > cull2:
			d.queue_free()

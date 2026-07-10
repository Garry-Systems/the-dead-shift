extends Node2D
## Scatters destructible obstacles around the roaming player, culls far ones (the distance
## culling enemies lack), and drops a cluster on each new wave. Mirrors Spawner's ring math.
## Self-inits from the "player" group like Spawner; lives as a sibling node in Main.tscn.

var _player: Node2D
var _spawn_t := 0.0
var _cull_t := 0.0
var _prev_wave := 1
var suspended := false   # THE BASEMENT (Pack E): controller pauses surface spawning/scatter while below

func _ready() -> void:
	add_to_group("obstacle_field")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave

func _process(delta: float) -> void:
	if suspended:
		return
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

## The ambient-managed destructibles only: permanent fixtures (Forecourt store/pumps, tagged
## no_cull) are excluded, so they never eat density-target or hard-cap slots.
func _managed_destructibles() -> Array:
	var out: Array = []
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if "no_cull" in d and d.no_cull:
			continue
		out.append(d)
	return out

func _ambient_topup() -> void:
	var all_d := _managed_destructibles()
	if all_d.size() >= GameConfig.OBSTACLE_HARD_CAP:
		return
	var keep2 := GameConfig.OBSTACLE_KEEP_RADIUS * GameConfig.OBSTACLE_KEEP_RADIUS
	var near := 0
	for d in all_d:
		if (d as Node2D).global_position.distance_squared_to(_player.global_position) <= keep2:
			near += 1
	if near >= GameConfig.OBSTACLE_TARGET_COUNT:
		return
	var ang := randf_range(0.0, TAU)
	var r := randf_range(GameConfig.OBSTACLE_SPAWN_MIN_R, GameConfig.OBSTACLE_SPAWN_MAX_R)
	_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

func _drop_cluster() -> void:
	for i in GameConfig.OBSTACLE_CLUSTER_SIZE:
		if _managed_destructibles().size() >= GameConfig.OBSTACLE_HARD_CAP:
			return
		var ang := randf_range(0.0, TAU)
		var r := randf_range(GameConfig.OBSTACLE_CLUSTER_MIN_R, GameConfig.OBSTACLE_CLUSTER_RADIUS)
		_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

## `row` defaults to {} = pick a weighted/wave-gated row (the ambient path); Rush Hour (below)
## passes an exact row instead so it can force car/rubble cover specifically.
func _spawn_at(pos: Vector2, row: Dictionary = {}) -> void:
	if pos.distance_squared_to(Vector2.ZERO) < GameConfig.FORECOURT_KEEPOUT_RADIUS * GameConfig.FORECOURT_KEEPOUT_RADIUS:
		return   # never scatter into the forecourt (Pack 5) — it's a fixed structure, not ambient clutter
	var d := Destructible.new()
	d.configure(row if not row.is_empty() else Obstacles.pick(DifficultyManager.wave))
	get_tree().current_scene.add_child(d)
	d.global_position = pos

## RUSH HOUR (night event, Pack A): scatters `count` extra car/rubble cover in a rough corridor
## near the player — a random facing, then jittered along/across it. Reuses this field's own
## keep-out (forecourt) + OBSTACLE_HARD_CAP via _spawn_at, and the resulting props are plain
## managed destructibles afterward (no special flag), so they're normal, cullable obstacles —
## exactly like an ambient or wave-cluster drop, just front-loaded.
func rush_hour_scatter(count: int) -> void:
	if suspended:
		return
	if _player == null or not is_instance_valid(_player):
		return
	var dir := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var perp := Vector2(-dir.y, dir.x)
	var car_row := Obstacles.by_id("car")
	var rubble_row := Obstacles.by_id("rubble")
	for i in count:
		if _managed_destructibles().size() >= GameConfig.OBSTACLE_HARD_CAP:
			return
		var along := randf_range(GameConfig.RUSH_HOUR_MIN_R, GameConfig.RUSH_HOUR_MAX_R)
		var across := randf_range(-GameConfig.RUSH_HOUR_WIDTH, GameConfig.RUSH_HOUR_WIDTH)
		var pos := _player.global_position + dir * along + perp * across
		var row := car_row if randf() < 0.5 else rubble_row
		if not row.is_empty():
			_spawn_at(pos, row)

func _cull_far() -> void:
	var cull2 := GameConfig.OBSTACLE_CULL_RADIUS * GameConfig.OBSTACLE_CULL_RADIUS
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if d.has_method("is_fusing") and d.is_fusing():
			continue   # don't cull a barrel mid chain-fuse
		if "no_cull" in d and d.no_cull:
			continue   # Forecourt fixtures (store cover / fuel pumps) are permanent, not ambient scatter
		if (d as Node2D).global_position.distance_squared_to(_player.global_position) > cull2:
			d.queue_free()

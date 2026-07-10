extends Node2D
## Scatters destructible obstacles around the roaming player, culls far ones (the distance
## culling enemies lack), and drops a cluster on each new wave. Mirrors Spawner's ring math.
## Self-inits from the "player" group like Spawner; lives as a sibling node in Main.tscn.

var _player: Node2D
var _spawn_t := 0.0
var _cull_t := 0.0
var _prev_wave := 1
var suspended := false   # THE BASEMENT (Pack E): controller pauses surface spawning/scatter while below
var location_obstacle_mults: Dictionary = {}   # TRANSFER STORES (Task 2): set once by Main.gd
# from the run's Locations row; passed straight through to Obstacles.pick(). {} (forecourt/
# default) is byte-identical to before this pack — see Obstacles._weight's mults.is_empty()
# short-circuit.
var _gimmick := ""   # BIG MART (Task 3): Locations.gd's gimmick for RunConfig.location, read ONCE
# at _ready() — the run's location is fixed for the whole run (same "read once at run start"
# pattern Main._apply_location already documents). "" (forecourt/garage) means the freezer-patch
# wave-edge roll below is always skipped; only "mart" arms it.

func _ready() -> void:
	add_to_group("obstacle_field")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave
	_gimmick = String(Locations.by_id(RunConfig.location).get("gimmick", ""))

func _process(delta: float) -> void:
	if suspended:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if DifficultyManager.wave != _prev_wave:
		_prev_wave = DifficultyManager.wave
		_drop_cluster()
		_maybe_drop_freezer()   # BIG MART (Task 3): same wave-edge moment, mart-only
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
##
## BIG MART (Task 3): if the resolved row carries `"formation": true` (mart's "shelf" row, via
## either the ambient default-arg pick OR — same as any other row — a forced `row` argument),
## `pos` is treated as the run's anchor and handed to `_spawn_formation()` instead of building a
## single Destructible here. Both callers of this function (ambient top-up + wave-cluster drop)
## get formation spawning for free since they both funnel through this one chokepoint.
func _spawn_at(pos: Vector2, row: Dictionary = {}) -> void:
	if pos.distance_squared_to(Vector2.ZERO) < GameConfig.FORECOURT_KEEPOUT_RADIUS * GameConfig.FORECOURT_KEEPOUT_RADIUS:
		return   # never scatter into the forecourt (Pack 5) — it's a fixed structure, not ambient clutter
	# TRANSFER STORES (Task 2): location_obstacle_mults biases the ambient roll ({} = untouched
	# default); Rush Hour's forced `row` above bypasses Obstacles.pick entirely, so it's unaffected.
	var picked := row if not row.is_empty() else Obstacles.pick(DifficultyManager.wave, location_obstacle_mults)
	if bool(picked.get("formation", false)):
		_spawn_formation(pos, picked)
		return
	var d := Destructible.new()
	d.configure(picked)
	get_tree().current_scene.add_child(d)
	d.global_position = pos

## BIG MART (Task 3) formation mode: an axis-aligned run of MART_FORMATION_LEN_MIN..MAX units of
## `row`, spaced `2 * SHELF_HALF_W + 6` px apart along a randomly-chosen H or V axis, centered on
## `anchor` (the position the normal ring/keep-out math in _ambient_topup()/_drop_cluster() already
## rolled — the run is placed there, not re-rolled). Each unit still gets its own forecourt
## keep-out + hard-cap check: the anchor already passed the keep-out gate above, but a run can
## drift a fixed offset away from it, and a big cluster drop can push the count right up to the
## hard cap mid-run.
func _spawn_formation(anchor: Vector2, row: Dictionary) -> void:
	var length := randi_range(GameConfig.MART_FORMATION_LEN_MIN, GameConfig.MART_FORMATION_LEN_MAX)
	var spacing := 2.0 * GameConfig.SHELF_HALF_W + 6.0
	var axis := Vector2.RIGHT if randf() < 0.5 else Vector2.DOWN   # random H/V orientation per formation
	var start := anchor - axis * spacing * float(length - 1) * 0.5   # center the run on the anchor
	var keep2 := GameConfig.FORECOURT_KEEPOUT_RADIUS * GameConfig.FORECOURT_KEEPOUT_RADIUS
	for i in length:
		var pos := start + axis * spacing * float(i)
		if pos.distance_squared_to(Vector2.ZERO) < keep2:
			continue   # this unit drifted into the forecourt keep-out — skip just this one
		if _managed_destructibles().size() >= GameConfig.OBSTACLE_HARD_CAP:
			return
		var d := Destructible.new()
		d.configure(row)
		get_tree().current_scene.add_child(d)
		d.global_position = pos

## BIG MART (Task 3) freezer patches: at every wave edge, mart-only, a plain (unseeded, position-
## flavor — NOT RunConfig.rand_float()/the Daily stream, matching Spawner's own angle/radius rolls)
## FREEZER_CHANCE_PER_WAVE roll drops a slow-only HazardZone near the player. Built the same direct
## way Player._spawn_slick()/TrailDash's puddle do (HazardZone.new() + configure_hazard(cfg)) since
## there's no Destructible/Obstacles row backing it — it's not a scatterable obstacle. Respects the
## same MAX_HAZARD_ZONES cap Destructible._die()'s hazard-zone spawn already honors, so a mart run
## dense with freezer patches can't crowd out fire/acid/electric zones (or vice versa).
func _maybe_drop_freezer() -> void:
	if _gimmick != "mart":
		return
	if randf() >= GameConfig.FREEZER_CHANCE_PER_WAVE:
		return
	var tree := get_tree()
	if tree.get_nodes_in_group("hazard_zones").size() >= GameConfig.MAX_HAZARD_ZONES:
		return
	var ang := randf_range(0.0, TAU)
	var r := randf_range(GameConfig.OBSTACLE_CLUSTER_MIN_R, GameConfig.OBSTACLE_CLUSTER_RADIUS)
	var pos := _player.global_position + Vector2(cos(ang), sin(ang)) * r
	if pos.distance_squared_to(Vector2.ZERO) < GameConfig.FORECOURT_KEEPOUT_RADIUS * GameConfig.FORECOURT_KEEPOUT_RADIUS:
		return   # don't drop one on top of MartFront's own set-piece at the origin
	var cfg := {
		"color": PixelTheme.ACCENT, "dps": 0.0, "radius": GameConfig.FREEZER_RADIUS,
		"duration": GameConfig.FREEZER_DURATION, "slow": GameConfig.FREEZER_SLOW,
		"slow_dur": GameConfig.FREEZER_SLOW_DUR, "stun": 0.0, "chain": 0, "drift": 0.0,
		"hurts_player": true,
	}
	var hz := HazardZone.new()
	tree.current_scene.add_child(hz)
	hz.global_position = pos
	hz.configure_hazard(cfg)

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

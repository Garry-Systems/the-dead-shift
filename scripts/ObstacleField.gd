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
# from the run's Locations row; passed straight through to Obstacles.pick(). This {} is just the
# pre-_ready() default — Deep Clean (item 16): forecourt's actual row value is ALSO {} now (the
# old `{"shelf": 0.0}` pin was removed once Obstacles.gd's `locations` allowlist took over keeping
# "shelf" out of forecourt), so Obstacles._weight takes its `mults.is_empty()` short-circuit for
# forecourt exactly like every other location-agnostic row always has.
var _gimmick := ""   # BIG MART (Task 3)/PARKING GARAGE (Task 4): Locations.gd's gimmick for
# RunConfig.location, read ONCE at _ready() — the run's location is fixed for the whole run (same
# "read once at run start" pattern Main._apply_location already documents). "" (forecourt) means
# neither the freezer-patch wave-edge roll nor the lattice pass/car-alarm hook below ever arm;
# "mart" arms freezer only, "garage" arms the lattice + car-alarm hook only.
var _location_id := ""   # Deep Clean (item 16): RunConfig.location, read ONCE at _ready() (same
# read-once-at-run-start moment as `_gimmick` right above, same source) and threaded into every
# Obstacles.pick() call alongside `location_obstacle_mults` so the new `locations` allowlist can
# filter shelf/pillar-family rows by the run's actual location — see Obstacles.pick()'s own doc.
var _lattice_cells: Dictionary = {}   # PARKING GARAGE (Task 4): Vector2i(gx,gy) -> spawned pillar
# Destructible. Garage-only in practice — _lattice_pass() no-ops immediately on any other
# _gimmick, so this stays empty {} for the rest of this run everywhere else. Entries are added by
# _spawn_pillar() and erased the instant _cull_far() culls that cell's pillar (NOT lazily via an
# is_instance_valid poll — see _cull_far()'s own hook) so a revisited cell always re-spawns.

func _ready() -> void:
	add_to_group("obstacle_field")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave
	_gimmick = String(Locations.by_id(RunConfig.location).get("gimmick", ""))
	_location_id = RunConfig.location

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
		_lattice_pass()   # PARKING GARAGE (Task 4): same cadence as cull — see _lattice_pass()'s own doc comment for why co-locating them keeps the spawn/cull reconcile trivially correct

## The ambient-managed destructibles only: permanent fixtures (Forecourt store/pumps, tagged
## no_cull) are excluded, so they never eat density-target or hard-cap slots.
##
## PARKING GARAGE (Task 4): lattice pillars are ALSO excluded here, for the same reason but a
## different mechanism — they're a deterministic structural feature, not ambient clutter, yet
## (unlike Forecourt fixtures) they DO need to be cullable so a revisited cell can respawn (see
## _cull_far()'s lattice_cell hook). A dense lattice can hold ~24 pillars alone at
## OBSTACLE_CULL_RADIUS — exactly OBSTACLE_HARD_CAP — so counting them here would starve every
## other ambient obstacle (car/crate/barrel) out of the garage entirely. This exclusion is
## SEPARATE from no_cull on purpose: _cull_far() below iterates the raw "destructibles" group
## directly (not this filtered list), so pillars stay fully cullable despite being exempt here.
func _managed_destructibles() -> Array:
	var out: Array = []
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if "no_cull" in d and d.no_cull:
			continue
		if d.has_meta("lattice_cell"):
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
	# Deep Clean (item 16): _location_id also threads through so the `locations` allowlist gates
	# location-exclusive rows (shelf/pillar) the same way mults gates weight -- Rush Hour's forced
	# `row` bypasses this exactly the same way it already bypasses mults, for the same reason.
	var picked := row if not row.is_empty() else Obstacles.pick(DifficultyManager.wave, location_obstacle_mults, _location_id)
	# PARKING GARAGE (Task 4): CAR ALARM gimmick hook. This is the ONE chokepoint every "car" row
	# passes through — ambient top-up, wave-cluster drop, AND Rush Hour's forced row all funnel
	# through here — so gating on `_gimmick == "garage"` here covers all three placements for
	# free, the same way formation-mode below covers both ambient/cluster callers for free.
	# duplicate() FIRST: `picked` may be the exact dict Rush Hour's `car_row` variable holds across
	# its whole scatter loop (Obstacles.by_id() called once, reused for N spawns) or a fresh dict
	# `Obstacles.pick()` just built — either way, mutating in place risks leaking "wail" onto a
	# shared reference outside this function's control, so duplicate() is cheap insurance, per the
	# brief's own literal `row = row.duplicate(); row["wail"] = true` interface.
	if _gimmick == "garage" and String(picked.get("id", "")) == "car":
		picked = picked.duplicate()
		picked["wail"] = true
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
			if d.has_meta("lattice_cell"):
				# PARKING GARAGE (Task 4): free the cell slot the INSTANT its pillar is culled
				# (not lazily via an is_instance_valid poll on the next _lattice_pass) — this is
				# the ONE place a lattice pillar's lifetime ever ends, so hooking here keeps
				# _lattice_cells authoritative with zero polling, and guarantees a revisited cell
				# re-spawns on the very next lattice pass rather than a pass or two later.
				_lattice_cells.erase(d.get_meta("lattice_cell"))
			d.queue_free()

## PARKING GARAGE (Task 4): the pillar lattice. Deterministic per-world-cell presence (hash() is
## purely position-derived — no RNG at all) means the SAME world spot always resolves the SAME
## verdict, so pillars read as a stable, revisitable dash-lane pattern rather than random scatter
## (hence the pillar row's weight:0 in Obstacles.gd — it must never ALSO roll through the normal
## ambient/cluster pick() path). Runs on the SAME cadence as _cull_far() right above (both are
## "which destructibles exist near the player right now" passes — co-locating them keeps the
## spawn/cull reconcile trivial, see _cull_far()'s lattice_cell erase). Scan radius reuses
## OBSTACLE_CULL_RADIUS rather than a new constant: using the SAME radius the culler enforces
## means a freshly-spawned pillar can never immediately fall outside cull range next tick, and a
## just-culled cell's re-entry into scan range and its cull are governed by the one same radius.
func _lattice_pass() -> void:
	if _gimmick != "garage":
		return
	var grid := GameConfig.PILLAR_GRID
	var radius := GameConfig.OBSTACLE_CULL_RADIUS
	var r2 := radius * radius
	var ppos := _player.global_position
	var gx_lo := int(floor((ppos.x - radius) / grid))
	var gx_hi := int(floor((ppos.x + radius) / grid))
	var gy_lo := int(floor((ppos.y - radius) / grid))
	var gy_hi := int(floor((ppos.y + radius) / grid))
	var keep2 := GameConfig.FORECOURT_KEEPOUT_RADIUS * GameConfig.FORECOURT_KEEPOUT_RADIUS
	var basement2 := (GameConfig.BASEMENT_RADIUS * 2.0) * (GameConfig.BASEMENT_RADIUS * 2.0)
	for gx in range(gx_lo, gx_hi + 1):
		for gy in range(gy_lo, gy_hi + 1):
			var cell := Vector2i(gx, gy)
			if _lattice_cells.has(cell):
				var existing = _lattice_cells[cell]
				if is_instance_valid(existing):
					continue   # already spawned (and not yet culled) — no double
				_lattice_cells.erase(cell)   # defensive: freed some other way than _cull_far's hook
			var pos := Vector2(float(gx) * grid, float(gy) * grid)
			if pos.distance_squared_to(ppos) > r2:
				continue
			if pos.distance_squared_to(Vector2.ZERO) < keep2:
				continue   # forecourt keep-out (unconditional, mirrors _spawn_at's own check)
			if pos.distance_squared_to(GameConfig.BASEMENT_OFFSET) < basement2:
				continue   # THE BASEMENT's gauntlet arena footprint — excluded per the brief even
				           # though ObstacleField is already `suspended` while the player is below
				           # (defense-in-depth, not the primary safety net)
			if not _pillar_present(cell):
				continue
			_spawn_pillar(cell, pos)

## Pure, deterministic per-cell presence check — hash(Vector2i) is position-derived only (no RNG
## involved), so the SAME world cell always resolves the SAME verdict regardless of when/how often
## it's queried. `PILLAR_DENSITY * 100.0` cast to int for the comparison (GDScript would otherwise
## compare an int % against a float fine too, but this keeps the intent literal/explicit).
static func _pillar_present(cell: Vector2i) -> bool:
	return hash(cell) % 100 < int(GameConfig.PILLAR_DENSITY * 100.0)

func _spawn_pillar(cell: Vector2i, pos: Vector2) -> void:
	var row := Obstacles.by_id("pillar")
	if row.is_empty():
		return   # defensive: registry row missing, skip rather than configure() on an empty dict
	var d := Destructible.new()
	d.configure(row)
	d.set_meta("lattice_cell", cell)
	get_tree().current_scene.add_child(d)
	d.global_position = pos
	_lattice_cells[cell] = d

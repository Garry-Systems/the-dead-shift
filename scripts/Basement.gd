class_name Basement
extends Node2D
## THE BASEMENT (Pack E) controller. Rolls a cellar door at each wave edge (DifficultyManager.wave
## crossing, same edge-detect idiom as NightEvents._prev_wave, NightEvents.gd:27) subject to
## BasementLogic.can_roll + a chance roll (BasementLogic.roll); places it on a ring around the
## player (BASEMENT_DOOR_MIN/MAX_DIST, rerolled up to 8 times against the forecourt keep-out —
## Spawner._pick_spawn_pos's idiom, reimplemented locally since the ring distance differs). The
## door frees itself via its own unentered-lifetime countdown (BasementDoor._lifetime); this
## controller only ever detects that via is_instance_valid, matching how Spawner/ObstacleField
## never own enemy/destructible lifetimes directly either.
##
## Task 4: the full descend -> gauntlet -> reward -> return lifecycle (Extraction.gd's own
## Phase-enum + match-in-_process shape is the closest analog in this codebase — a
## self-contained controller with its own timers, a ScreenFlash fade, and a teleport, so it's
## mirrored here). On descend the player is teleported to the FIXED BASEMENT_OFFSET arena (not
## relative to the door) and walled in by a ring of indestructible rubble cover; Spawner and
## ObstacleField are suspended so the surface goes quiet while DifficultyManager.run_time keeps
## ticking — the shift clock doesn't stop just because the player is underground. The gauntlet
## spawns its own dense trash cadence at the arena rim, forcing BasementLogic.elite_count(wave)
## elites on a fixed schedule; when the timer runs out a reward pickup (BasementCratePickup)
## appears at the arena center for a short grab window, then everything reverses (fade, free the
## wall + any gauntlet stragglers, teleport back, unsuspend).

enum Phase { NONE, GAUNTLET, REWARD }

var doors_spawned := 0
var in_basement := false
var location_spawn_mults: Dictionary = {}   # TRANSFER STORES (Task 2): set once by Main.gd from
# the run's Locations row; passed straight through to the gauntlet's own Enemies.pick() call
# below. {} (forecourt/default) is byte-identical to before this pack.

var _door: BasementDoor
var _player: Node2D
var _prev_wave := -1   # -1 = not yet synced; see the frame-1 guard in _process

# --- Task 4: gauntlet lifecycle state ---
var _phase := Phase.NONE
var _surface_pos := Vector2.ZERO
var _gauntlet_t := 0.0
var _spawn_t := 0.0
var _pickup_t := 0.0
var _elites_target := 0
var _elites_spawned := 0
var _crate: BasementCratePickup

func _ready() -> void:
	add_to_group("basement")
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	# Defensive: a player that goes invalid mid-gauntlet (dev kill, future respawn flow, etc.)
	# must never leave Spawner/ObstacleField suspended forever — hard-reset immediately rather
	# than let the suspension dangle into whatever screen comes next. A normal death just pauses
	# the tree (Player._die), which stops this _process on its own; this guard only matters for
	# the case where the player node itself goes away while the tree keeps running.
	if in_basement and (_player == null or not is_instance_valid(_player)):
		_hard_reset()
		return
	if in_basement:
		_process_gauntlet(delta)
	_check_extraction_door_free()
	var wave := DifficultyManager.wave
	if _prev_wave == -1:
		# Children ready() before Main applies its wave preset, so _ready() would have snapshotted
		# a stale wave=1 here (NightEvents._prev_wave shares this ordering weakness — left alone
		# there per the brief). The first _process frame only synchronizes to the real starting
		# wave; it must never roll a spurious wave-edge event off that stale snapshot.
		_prev_wave = wave
		return
	if wave == _prev_wave:
		return
	_prev_wave = wave
	_on_wave_edge()

## Gate check at a wave edge; only rolls the chance if the gate allows it. Kept separate from
## _roll_door so the gate (deterministic, state-driven) and the roll (chance-driven) are each
## independently probe-able.
func _on_wave_edge() -> void:
	# THE BASEMENT must never roll a door that could straddle the dawn extraction sequence (surge
	# + chopper ≈ FINAL_SURGE_SECONDS + EXTRACT_WINDOW = up to 110s): a door's own lifetime/hold/
	# gauntlet/pickup timers can run well past that on their own. Gated to endless only — Horde
	# and Boss Rush never run Extraction (Extraction.gd:30).
	if RunConfig.mode == "endless" and absf(DifficultyManager.run_time - ShiftClock.dawn_run_time()) < GameConfig.BASEMENT_DAWN_LOCKOUT:
		return
	var door_alive := _door != null and is_instance_valid(_door)
	if not BasementLogic.can_roll(DifficultyManager.wave, RunConfig.mode, doors_spawned, door_alive, in_basement):
		return
	_roll_door(RunConfig.rand_float())

## Reactive half of the dawn-window guard: _on_wave_edge's pre-roll lockout stops NEW doors from
## spawning close to dawn, but a door that was already alive when the surge hook fires would still
## sit there eating the window with its own lifetime. Once Extraction leaves Phase.WAITING (the
## surge has started), any live un-entered door is freed outright. `.get("_phase")` mirrors
## Spawner._player_level's dynamic-field idiom (Spawner.gd:78) since get_first_node_in_group
## returns a plain Node — Extraction.Phase is reachable directly via its class_name.
func _check_extraction_door_free() -> void:
	if in_basement:
		return
	if _door == null or not is_instance_valid(_door):
		return
	var extraction := get_tree().get_first_node_in_group("extraction")
	if extraction == null:
		return
	if int(extraction.get("_phase")) == Extraction.Phase.WAITING:
		return
	_door.queue_free()
	_door = null

## Internal — takes the already-rolled float (Task 3 brief) so this is probe-able with a
## stubbed rand instead of depending on live RNG. Does NOT re-check the gate; callers
## (_on_wave_edge) are responsible for gating before ever reaching here.
func _roll_door(rand01: float) -> void:
	if not BasementLogic.roll(rand01):
		return
	_spawn_door()

func _spawn_door() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_door = BasementDoor.new()
	_door.descend_requested.connect(_descend)
	get_tree().current_scene.add_child(_door)
	_door.global_position = _pick_door_pos()
	doors_spawned += 1

## A ring position BASEMENT_DOOR_MIN_DIST-MAX_DIST from the player, kept out of the forecourt.
## Mirrors Spawner._pick_spawn_pos's reroll-up-to-8 idiom (Spawner.gd:89-100) verbatim, except
## the placement distance is randomized per-candidate across the door's own min/max ring instead
## of Spawner's fixed SPAWN_RADIUS.
func _pick_door_pos() -> Vector2:
	var keep2 := GameConfig.FORECOURT_SPAWN_KEEPOUT * GameConfig.FORECOURT_SPAWN_KEEPOUT
	var pos := _player.global_position + Vector2.RIGHT * GameConfig.BASEMENT_DOOR_MIN_DIST
	for i in 8:
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(GameConfig.BASEMENT_DOOR_MIN_DIST, GameConfig.BASEMENT_DOOR_MAX_DIST)
		pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
		if pos.distance_squared_to(Vector2.ZERO) >= keep2:
			return pos
	var dir := pos.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir * GameConfig.FORECOURT_SPAWN_KEEPOUT

# --- Task 4: descend -> gauntlet -> reward -> return ---

## Fade, stash the surface position, teleport into the fixed walled arena, suspend the surface
## systems, and start the gauntlet countdown. The entered door (still `_door` — only one can be
## alive at a time, gated by can_roll's door_alive check) frees itself here; its job is done.
## The wall is built FIRST (its position is the fixed BASEMENT_OFFSET, independent of the
## player): if it can't be built, the whole descend aborts before any state changes — a wall-less
## gauntlet would just be an open field the spawns leak out of.
func _descend() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _build_wall():
		# Nothing below ran yet, so these are no-op resets — kept anyway so this abort path can
		# never leave half-set state even if the ordering above ever changes.
		_set_suspended(false)
		in_basement = false
		return
	get_tree().current_scene.add_child(ScreenFlash.new())
	_surface_pos = _player.global_position
	_player.global_position = GameConfig.BASEMENT_OFFSET
	_set_suspended(true)
	in_basement = true
	_phase = Phase.GAUNTLET
	_gauntlet_t = 0.0
	_spawn_t = 0.0
	_elites_spawned = 0
	_elites_target = BasementLogic.elite_count(DifficultyManager.wave)
	_banner("THE BASEMENT", "hold out")
	if _door != null and is_instance_valid(_door):
		_door.queue_free()
	_door = null

## SEALED ring of indestructible rubble segments (Obstacles.by_id("rubble") — hp -1 via
## GameConfig.RUBBLE_HP, the same "hp < 0 = indestructible" idiom Forecourt's store building
## uses) at BASEMENT_RADIUS around the fixed arena center. The segment count is COMPUTED from
## the ring circumference and the rubble collider's radius (BASEMENT_WALL_SEG_RADIUS, tied to
## the "rubble" row's circle size) so adjacent edges always overlap — center spacing is held to
## 90% of a segment's 2r diameter (the x0.9 overlap factor), leaving no pixel seams an enemy or
## the player could slip through (a fixed 24 segments at radius 800 left ~141px gaps). no_cull
## so ObstacleField's cull/cap passes ignore them outright (its _managed_destructibles/_cull_far
## both skip any Destructible with no_cull true) even though ObstacleField itself is suspended
## for the gauntlet's duration — belt and suspenders, same as Forecourt's permanent fixtures.
## Tagged "basement_wall" for _ascend's cleanup (Destructible has no notion of that group
## itself). Returns false (with a loud warning) if the rubble registry row is missing — the
## caller (_descend) aborts the whole descend rather than running a wall-less gauntlet.
func _build_wall() -> bool:
	var row := Obstacles.by_id("rubble")
	if row.is_empty():
		push_warning("Basement: 'rubble' row missing from Obstacles — cannot build the wall, descend aborted")
		return false
	var segs := int(ceil(TAU * GameConfig.BASEMENT_RADIUS / (2.0 * GameConfig.BASEMENT_WALL_SEG_RADIUS * 0.9)))
	for i in segs:
		var ang := float(i) / float(segs) * TAU
		var d := Destructible.new()
		d.configure(row)
		d.no_cull = true
		d.add_to_group("basement_wall")
		get_tree().current_scene.add_child(d)
		d.global_position = GameConfig.BASEMENT_OFFSET + Vector2(cos(ang), sin(ang)) * GameConfig.BASEMENT_RADIUS
	return true

func _process_gauntlet(delta: float) -> void:
	match _phase:
		Phase.GAUNTLET:
			_gauntlet_t += delta
			_spawn_t += delta
			if _spawn_t >= GameConfig.BASEMENT_SPAWN_INTERVAL:
				_spawn_t = 0.0
				_spawn_gauntlet_enemy()
			if _gauntlet_t >= GameConfig.BASEMENT_DURATION:
				_start_reward()
		Phase.REWARD:
			_pickup_t += delta
			if _pickup_t >= GameConfig.BASEMENT_PICKUP_WINDOW:
				_ascend()

## Spawner._spawn_enemy's idiom (Enemies.pick + configure(stats_for) + add_child + position),
## reimplemented locally for a rim spawn instead of a player-relative ring. Forces an elite the
## first time this fires on/after each BASEMENT_ELITE_INTERVAL boundary, up to _elites_target —
## apply_elite must run BEFORE add_child (Enemy.apply_elite's own doc comment: "called right
## after configure(), before add_child" — it scales max_health while current==max, which assumes
## the enemy hasn't taken a hit or entered the tree yet).
func _spawn_gauntlet_enemy() -> void:
	# TRANSFER STORES (Task 2): location_spawn_mults biases the gauntlet roll ({} = untouched default).
	var entry := Enemies.pick(DifficultyManager.wave, location_spawn_mults)
	var enemy = (entry["scene"] as PackedScene).instantiate()
	enemy.configure(Enemies.stats_for(entry, DifficultyManager.wave))
	if _elites_spawned < _elites_target and _gauntlet_t >= float(_elites_spawned + 1) * GameConfig.BASEMENT_ELITE_INTERVAL:
		_elites_spawned += 1
		const KINDS := ["armored", "volatile", "splitter", "alpha"]
		var kind: String = KINDS[RunConfig.rand_int() % KINDS.size()]
		# Exploders never roll Volatile (Spawner._maybe_apply_elite's own reroll rule, Spawner.gd:130):
		# their own instant _detonate would stack with the fused volatile blast into an
		# untelegraphed hit at the same spot. Same reason applies here — reroll deterministically.
		if enemy is ExploderEnemy and kind == "volatile":
			kind = "armored"
		enemy.apply_elite(kind)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _rim_pos()

## A random point on the arena rim, BASEMENT_RIM_INSET inside BASEMENT_RADIUS (matches the
## brief's "ring radius - 100").
func _rim_pos() -> Vector2:
	var ang := randf_range(0.0, TAU)
	return GameConfig.BASEMENT_OFFSET + Vector2(cos(ang), sin(ang)) * (GameConfig.BASEMENT_RADIUS - GameConfig.BASEMENT_RIM_INSET)

## Timer's up: stop spawning (Phase.REWARD's match branch above no longer calls
## _spawn_gauntlet_enemy), drop the reward at the arena center, and start the pickup-window
## countdown. The reward is a real registry CRATE (BasementLogic.crate_id_for maps the wave's
## crate_floor onto a crate id), not a rolled weapon — crates ignore the weapon-inventory cap
## and get the full store reveal/open flow.
func _start_reward() -> void:
	_phase = Phase.REWARD
	_pickup_t = 0.0
	# Task 5: BASEMENTS CLEARED — the gauntlet is won the moment the reward drops, not when the
	# player actually grabs it (a player who ignores the crate still cleared the basement). The
	# per-run counter (pay-stub row) and the lifetime save counter both bump here together; the
	# lifetime one flushes immediately (own chokepoint owns its save, same idiom as
	# add_crate_opened()/Inventory.commit_crate) since this is a mid-run grant with no guaranteed
	# later flush before a crash/force-quit could eat it.
	RunStats.add_basement_cleared()
	SaveManager.add_basement_cleared()
	SaveManager.save_game()
	_crate = BasementCratePickup.new()
	_crate.crate_id = BasementLogic.crate_id_for(DifficultyManager.wave)
	get_tree().current_scene.add_child(_crate)
	_crate.global_position = GameConfig.BASEMENT_OFFSET
	_banner("SHIFT CONTINUES", "grab it and go")

## Fade, tear down the wall + any gauntlet stragglers, teleport back to the stored surface
## position, and unsuspend the surface systems. Whether or not the crate was actually collected
## (BasementCratePickup frees itself on pickup and clears nothing here — `_crate` may already be
## invalid) it's swept up too, so an ignored reward never lingers in the walled-off arena forever.
func _ascend() -> void:
	get_tree().current_scene.add_child(ScreenFlash.new())
	_free_wall()
	_free_stragglers()
	_free_stranded_gems()
	_free_stranded_decoys()
	if _crate != null and is_instance_valid(_crate):
		_crate.queue_free()
	_crate = null
	if _player != null and is_instance_valid(_player):
		_player.global_position = _surface_pos
	_set_suspended(false)
	in_basement = false
	_phase = Phase.NONE

func _free_wall() -> void:
	for w in get_tree().get_nodes_in_group("basement_wall"):
		if is_instance_valid(w):
			w.queue_free()

## Gauntlet stragglers: any enemy still alive past BASEMENT_STRAGGLER_RADIUS from the surface
## point. Every gauntlet-spawned enemy sits near the fixed BASEMENT_OFFSET arena (24000,24000
## world units from a normal surface run), so this distance check cleanly separates "spawned in
## the gauntlet" from "was already alive on the surface near the player" without needing a
## dedicated group tag on Spawner's own enemies. Freed directly (queue_free, not take_damage/
## _die) — no kill credit, no loot drop, no XP gems; they were never actually defeated.
func _free_stragglers() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.is_in_group("boss"):
			# BossBase chases continuously (45px/s, no cull) and is tagged "enemies" too — left
			# unhandled it's always past BASEMENT_STRAGGLER_RADIUS by the time even a bare-minimum
			# gauntlet ends (68s @ 45px/s = 3060px), and queue_free below would evaporate the
			# encounter with no _die/_reward. Snap it back to a normal spawn-ring distance from the
			# surface point instead (Spawner._pick_spawn_pos's ring idiom, Spawner.gd:89-100) so the
			# fight resumes on ascend rather than vanishing.
			var ang := randf_range(0.0, TAU)
			(e as Node2D).global_position = _surface_pos + Vector2(cos(ang), sin(ang)) * GameConfig.SPAWN_RADIUS
			continue
		if (e as Node2D).global_position.distance_to(_surface_pos) > GameConfig.BASEMENT_STRAGGLER_RADIUS:
			e.queue_free()

## Uncollected gauntlet XP gems (dropped by kills at the fixed BASEMENT_OFFSET arena) have no
## despawn timer of their own — left alone they'd sit at +24000,+24000 forever. Swept the same
## distance-from-surface idiom as _free_stragglers, via XpGem's "xp_gems" group (XpGem._ready)
## rather than walking every current_scene child.
func _free_stranded_gems() -> void:
	for g in get_tree().get_nodes_in_group("xp_gems"):
		if not is_instance_valid(g):
			continue
		if (g as Node2D).global_position.distance_to(_surface_pos) > GameConfig.BASEMENT_STRAGGLER_RADIUS:
			g.queue_free()

## Uncollected gauntlet-side coworker decoys (MannequinDecoy, "coworker_decoys" group) have no
## despawn timer of their own either — same fixed-arena stranding as xp_gems above. Only one can
## ever exist at a time (MannequinDecoy.spawn's own evict-existing cap), but it's still stranded
## at +24000,+24000 on ascend if the equipped mannequin placed it during the gauntlet.
func _free_stranded_decoys() -> void:
	for d in get_tree().get_nodes_in_group("coworker_decoys"):
		if not is_instance_valid(d):
			continue
		if (d as Node2D).global_position.distance_to(_surface_pos) > GameConfig.BASEMENT_STRAGGLER_RADIUS:
			d.queue_free()

func _set_suspended(v: bool) -> void:
	var spawner := get_tree().get_first_node_in_group("spawner")
	if spawner != null:
		spawner.suspended = v
	var obstacle_field := get_tree().get_first_node_in_group("obstacle_field")
	if obstacle_field != null:
		obstacle_field.suspended = v

## Emergency unwind for the "player went invalid mid-gauntlet" guard in _process — same cleanup
## as _ascend minus the fade/teleport (there's no valid player to fade for or teleport).
func _hard_reset() -> void:
	_free_wall()
	if _crate != null and is_instance_valid(_crate):
		_crate.queue_free()
	_crate = null
	_set_suspended(false)
	in_basement = false
	_phase = Phase.NONE

## Reuses Hud's Pack 0 banner exactly as the brief specifies (_show_banner(text, sub), not the
## public show_banner(text) wrapper NightEvents/Extraction use — that wrapper drops the sub
## line, and THE BASEMENT's banners both need one). Hud has no class_name (CanvasLayer autoload-
## adjacent scene node), so this goes through the same get_tree().get_first_node_in_group("hud")
## + .call() route Extraction.gd/NightEvents.gd already use for their own banners.
func _banner(text: String, sub: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("_show_banner", text, sub)

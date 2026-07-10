class_name Basement
extends Node2D
## THE BASEMENT (Pack E) controller — door-management half only; Task 4 adds the gauntlet half
## (descend -> 60s walled gauntlet -> reward -> return). Rolls a cellar door at each wave edge
## (DifficultyManager.wave crossing, same edge-detect idiom as NightEvents._prev_wave,
## NightEvents.gd:27) subject to BasementLogic.can_roll + a chance roll (BasementLogic.roll);
## places it on a ring around the player (BASEMENT_DOOR_MIN/MAX_DIST, rerolled up to 8 times
## against the forecourt keep-out — Spawner._pick_spawn_pos's idiom, reimplemented locally
## since the ring distance differs). The door frees itself via its own unentered-lifetime
## countdown (BasementDoor._lifetime); this controller only ever detects that via
## is_instance_valid, matching how Spawner/ObstacleField never own enemy/destructible
## lifetimes directly either.

var doors_spawned := 0
var in_basement := false     # Task 4 flips this true for the gauntlet's duration

var _door: BasementDoor
var _player: Node2D
var _prev_wave := 1

func _ready() -> void:
	add_to_group("basement")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave

func _process(_delta: float) -> void:
	var wave := DifficultyManager.wave
	if wave == _prev_wave:
		return
	_prev_wave = wave
	_on_wave_edge()

## Gate check at a wave edge; only rolls the chance if the gate allows it. Kept separate from
## _roll_door so the gate (deterministic, state-driven) and the roll (chance-driven) are each
## independently probe-able.
func _on_wave_edge() -> void:
	var door_alive := _door != null and is_instance_valid(_door)
	if not BasementLogic.can_roll(DifficultyManager.wave, RunConfig.mode, doors_spawned, door_alive, in_basement):
		return
	_roll_door(RunConfig.rand_float())

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

## THE BASEMENT's descend -> gauntlet -> reward -> return lifecycle lands in Task 4. Placeholder
## per the Task 3 brief (the one sanctioned stub in this pack).
func _descend() -> void:
	push_warning("descend: T4")

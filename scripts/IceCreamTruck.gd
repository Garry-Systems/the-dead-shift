class_name IceCreamTruck
extends Node2D
## THE ICE CREAM TRUCK (Night Shift Stories, v0.1.68) — the third VISITOR kind, and the game's
## first mid-run coin-spending prop. No .tscn (mirrors Cryptid.gd/DrivebyLane.gd's own "pure
## script, builds itself" idiom): spawned by Visitors._start_truck(), which adds it as a
## get_tree().current_scene child and does NOT set its position — this file computes its own
## lane/park position in _ready(), exactly like DrivebyLane's fixed-band snapshot.
##
## Lifecycle: ARRIVING (drives in along a straight lane from TRUCK_SPAWN_DIST toward the player,
## stopping at TRUCK_PARK_DIST) -> PARKED (loops the jingle, listens for the player standing in
## TRUCK_SHOP_RING — the BasementDoor ring idiom, edge-triggered so it opens once per approach, not
## once a frame) -> DEPARTING (TRUCK_STAY elapses OR TRUCK_PURCHASE_CAP purchases hit, honks, drives
## back out along the SAME lane, then frees itself). Visitors._process's existing
## is_instance_valid() poll clears the controller's active_kind once this node frees — no signal
## needed, matching Cryptid/DrivebyLane's own "child owns its lifetime, controller just polls"
## contract.
##
## DETERMINISM (binding, per the task brief): this file must NEVER call RunConfig.rand_float()/
## rand_int() — the seeded Daily Shift stream must see ZERO draws from the truck's own lifecycle
## (the visitor-kind pick that chose "truck" already happened in Visitors._roll_visitor, before
## this node ever existed). The lane-direction roll below uses plain randf_range() (unseeded),
## the SAME choice DrivebyLane._ready() already makes for its own aim direction.
##
## Untargetable by design (no "enemies"/collider/take_damage) — like DrivebyLane's police car, this
## is a vendor prop to approach, not something to fight; "solid" in the spec's own phrasing reads
## as "a physical arrival with a body," not literally solid collision (nothing in the spec's own
## interfaces list calls for bullet-blocking or contact damage).

enum State { ARRIVING, PARKED, DEPARTING }

var _state := State.ARRIVING
var _player: Node2D
var _dir := Vector2.RIGHT
var _park_pos := Vector2.ZERO
var _away_pos := Vector2.ZERO
var _stay_t := 0.0
var _jingle_t := 0.0
var _purchases := 0
var _in_ring := false
var _sprite_loaded := false

func _ready() -> void:
	add_to_group("ice_cream_truck")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	var origin := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		origin = _player.global_position
	_pick_lane(origin)
	_away_pos = _park_pos + _dir * GameConfig.TRUCK_SPAWN_DIST
	global_position = origin + _dir * GameConfig.TRUCK_SPAWN_DIST
	_build_sprite()

## Rolls the (unseeded, cosmetic-only — see file doc) lane direction, keeping the park spot clear
## of the forecourt set-pieces near world origin: Spawner._pick_spawn_pos / Visitors._spawn_pos's
## own reroll-up-to-8 idiom, reimplemented here (this file has no dependency on either) since the
## truck derives BOTH _park_pos and _away_pos/global_position from the SAME straight-line _dir,
## not just one standalone position like those two callers. Sets `_dir`/`_park_pos` directly.
func _pick_lane(origin: Vector2) -> void:
	var keep2 := GameConfig.FORECOURT_SPAWN_KEEPOUT * GameConfig.FORECOURT_SPAWN_KEEPOUT
	for i in 8:
		var ang := randf_range(0.0, TAU)
		_dir = Vector2(cos(ang), sin(ang))
		_park_pos = origin + _dir * GameConfig.TRUCK_PARK_DIST
		if _park_pos.distance_squared_to(Vector2.ZERO) >= keep2:
			return
	# All 8 rerolls still landed inside the keep-out (Spawner's own fallback, reused): push the
	# lane's heading itself out to the keep-out distance from world origin so the WHOLE lane (not
	# just Spawner's single returned point) clears the forecourt.
	var out_dir := _park_pos.normalized()
	if out_dir == Vector2.ZERO:
		out_dir = Vector2.RIGHT
	_dir = out_dir
	_park_pos = _dir * GameConfig.FORECOURT_SPAWN_KEEPOUT

func _process(delta: float) -> void:
	match _state:
		State.ARRIVING:
			_drive(_park_pos, delta)
			if global_position.distance_to(_park_pos) < 4.0:
				global_position = _park_pos
				_state = State.PARKED
				_stay_t = GameConfig.TRUCK_STAY
				_jingle_t = 0.0   # fires the first jingle immediately on parking (WAIL_TAUNT_TICK's own idiom)
		State.PARKED:
			_stay_t -= delta
			_jingle_t -= delta
			if _jingle_t <= 0.0:
				_jingle_t = GameConfig.TRUCK_JINGLE_INTERVAL
				_play_jingle()
			_check_ring()
			if _stay_t <= 0.0:
				_depart()
		State.DEPARTING:
			_drive(_away_pos, delta)
			if global_position.distance_to(_away_pos) < 4.0:
				queue_free()
				return
	queue_redraw()

func _drive(target: Vector2, delta: float) -> void:
	global_position = global_position.move_toward(target, GameConfig.TRUCK_DRIVE_SPEED * delta)

## SoundManager.play() is a VERIFIED-safe no-op before T5 lands the WAV — DrivebyLane._play_siren's
## own doc comment traces the exact guard (_load_streams only populates ids whose file exists;
## play() early-returns on a missing id). No native loop on a pooled SFX player, so this re-triggers
## on TRUCK_JINGLE_INTERVAL while parked (Destructible's WAIL_TAUNT_TICK precedent) to simulate one.
func _play_jingle() -> void:
	SoundManager.play("truck_jingle")

## Stand-in-zone (BasementDoor ring idiom): edge-triggered (false->true only) so standing still
## inside the ring doesn't reopen the shop every frame — TruckShop.open() also pauses the tree the
## instant it opens, which halts this node's own _process anyway, but the edge-detect keeps the
## contract explicit and matches every other ring/edge idiom in this codebase (Basement/Visitors'
## own _prev_wave, Visitors' own _prev_in_basement).
func _check_ring() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var inside := _player.global_position.distance_to(global_position) <= GameConfig.TRUCK_SHOP_RING
	if inside and not _in_ring:
		_open_shop()
	_in_ring = inside

func _open_shop() -> void:
	var shop := get_tree().get_first_node_in_group("truck_shop")
	if shop != null:
		shop.call("open", self)

## Called by TruckShop.gd after EVERY successful purchase (any of the 3 kinds). Departs early once
## TRUCK_PURCHASE_CAP is reached — the honk fires immediately (SoundManager plays while paused, see
## its own _ready() doc comment), the actual drive-away animation resumes once TruckShop unpauses
## the tree and this node's _process runs again.
func register_purchase() -> void:
	_purchases += 1
	if _purchases >= GameConfig.TRUCK_PURCHASE_CAP:
		_depart()

## Read by TruckShop after register_purchase() to decide whether to close itself immediately.
func purchase_cap_hit() -> bool:
	return _purchases >= GameConfig.TRUCK_PURCHASE_CAP

func _depart() -> void:
	if _state == State.DEPARTING:
		return
	_state = State.DEPARTING
	SoundManager.play("truck_honk")

## Staged sprite idiom (DrivebyLane._build_car's own precedent): a 64x32 truck sprite if Task 5's
## art has landed, else a code-drawn fallback rect in the strict 4-color palette. Warns once per
## instance (Mascot._warned_missing_art's precedent), not once globally — each visit is fresh.
func _build_sprite() -> void:
	var path := "res://art/env/ice_cream_truck.png"
	if ResourceLoader.exists(path):
		var spr := Sprite2D.new()
		spr.texture = load(path)
		add_child(spr)
		_sprite_loaded = true
	else:
		push_warning("IceCreamTruck: no truck sprite — regenerate sprites (generator list drift?), code-drawn fallback in use")

func _draw() -> void:
	if not _sprite_loaded:
		# Box van body + a serving-window accent + a C4 cone-glyph dot — the generator's own
		# planned 64x32 composition (Task 5's brief), read here as a strict-palette placeholder.
		var body := Rect2(Vector2(-32.0, -16.0), Vector2(64.0, 32.0))
		draw_rect(body, PixelTheme.TEXT_DIM)
		draw_rect(body, PixelTheme.DARK, false, 2.0)
		draw_rect(Rect2(Vector2(6.0, -10.0), Vector2(20.0, 14.0)), PixelTheme.ACCENT_DIM)   # serving window
		draw_circle(Vector2(-20.0, -2.0), 6.0, PixelTheme.ACCENT)   # cone glyph
	if _state == State.PARKED:
		# Pulsing shop-ring telegraph — BasementDoor._draw's own interact-radius idiom.
		var alpha := 0.18 + 0.14 * sin(Time.get_ticks_msec() / 260.0)
		draw_arc(Vector2.ZERO, GameConfig.TRUCK_SHOP_RING, 0.0, TAU, 40,
			Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, alpha), 2.0, true)

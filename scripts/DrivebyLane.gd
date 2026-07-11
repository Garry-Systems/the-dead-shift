class_name DrivebyLane
extends Node2D
## THE DRIVE-BY (Night Shift Stories, v0.1.68) — a lane of consequences. A siren + a
## DRIVEBY_TELEGRAPH-second (2s) lane telegraph in the AimedBand-width-telegraph idiom
## (scripts/patterns/AimedBand.gd's band-projection math — `proj = to.dot(dir)`, clamped to the
## segment length, `perp = (to - dir*proj).length()` — reimplemented locally in _in_lane() below
## since this pattern has no boss origin to inherit AttackPattern.setup()'s windup-clamp/aim-point
## machinery from; PATTERN_WINDUP_MAX (1.2s) is tuned for BOSS telegraphs and would clip the
## spec's literal 2s siren window), THEN the lane goes live for DRIVEBY_ACTIVE seconds (4s):
## HazardZone-style HAZARD_TICK_INTERVAL (~5Hz) ticks (scripts/HazardZone.gd:75-76's idiom) of
## DRIVEBY_DPS damage to every "enemies"-group member AND the player currently within the band's
## DRIVEBY_THICKNESS. 2 + 4 = the spec's 6s total.
##
## "Band + sweep" — the brief's sanctioned simpler alternative to a moving hitbox: the damaging
## band is FIXED (aimed through the player's position snapshotted the instant this node enters the
## tree — the AimedBand "telegraph = where you were when it started, dodge = move off it during
## the windup" contract, reused verbatim), and the police car itself is a purely COSMETIC child
## Node2D that sweeps along that fixed band during the active phase — the damage math never reads
## the car's position, so a later visual speed/easing tune can never desync from the hit math.
## Untargetable: no "enemies"/"cover"/"destructibles" group membership, no collider, no
## take_damage — bullets/auto-aim pass straight through it, matching the spec's "a pattern, not an
## entity."

var _thickness := 0.0
var _dps := 0.0
var _length := 0.0
var _windup := 0.0
var _active_t := 0.0
var _tick := 0.0
var _dir := Vector2.RIGHT
var _player: Node2D
var _car: Node2D
var _car_sprite_loaded := false

func _ready() -> void:
	_thickness = GameConfig.DRIVEBY_THICKNESS
	_dps = GameConfig.DRIVEBY_DPS
	_length = GameConfig.DRIVEBY_LANE_LENGTH
	_windup = GameConfig.DRIVEBY_TELEGRAPH
	_player = get_tree().get_first_node_in_group("player")
	var ang := randf_range(0.0, TAU)
	_dir = Vector2(cos(ang), sin(ang))
	if _player != null and is_instance_valid(_player):
		global_position = (_player as Node2D).global_position   # the aim-point snapshot: fixed for this lane's whole life, no re-aim once telegraphed
	_play_siren()
	_build_car()

## SoundManager.play() is a VERIFIED-safe no-op call before T5 lands the WAV: _load_streams()
## (scripts/SoundManager.gd:76-84) only populates `_streams` for ids whose file exists on disk at
## boot, and play() (scripts/SoundManager.gd:97-99) early-returns whenever `_streams` lacks the
## id — so this line does nothing (no error, no missing-file warning) until BOTH T5 adds
## "driveby_siren" to SFX_IDS AND the WAV file is actually present. No guard needed at this call
## site; verified by reading SoundManager end to end, not assumed.
func _play_siren() -> void:
	SoundManager.play("driveby_siren")

## Staged sprite idiom (Pack F): a 64x32 police_car sprite if Task 5's art has landed, else a
## code-drawn rect with a palette-only "light bar" (two ACCENT/ACCENT_DIM tiles alternating on a
## time pulse — a flashing light bar using ONLY the strict 4-color index, no new color exception).
## Warns once per instance (Mascot._warned_missing_art's precedent) — not once globally, since
## each drive-by is its own arrival worth a fresh log line.
func _build_car() -> void:
	_car = Node2D.new()
	add_child(_car)
	_car.visible = false
	var path := "res://art/env/police_car.png"
	if ResourceLoader.exists(path):
		var spr := Sprite2D.new()
		spr.texture = load(path)
		_car.add_child(spr)
		_car_sprite_loaded = true
	else:
		push_warning("DrivebyLane: no police_car sprite — regenerate sprites (generator list drift?), code-drawn fallback in use")

func _process(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		queue_redraw()
		if _windup <= 0.0:
			_active_t = GameConfig.DRIVEBY_ACTIVE
			_car.visible = true
		return
	if _active_t <= 0.0:
		return
	_active_t -= delta
	var progress := 1.0 - clampf(_active_t / GameConfig.DRIVEBY_ACTIVE, 0.0, 1.0)   # 0 -> 1 across the active window
	_car.position = _dir * (_length * (progress - 0.5))   # sweeps from one end of the band to the other — cosmetic only, see file doc comment
	_car.rotation = _dir.angle()
	_tick += delta
	if _tick >= GameConfig.HAZARD_TICK_INTERVAL:
		_apply(_tick)
		_tick = 0.0
	queue_redraw()
	if _active_t <= 0.0:
		queue_free()

func _apply(dt: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for e in tree.get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("take_damage") and _in_lane((e as Node2D).global_position):
			e.take_damage(_dps * dt)
	if _player != null and is_instance_valid(_player) and _in_lane((_player as Node2D).global_position):
		_player.take_damage(_dps * dt)

## AimedBand._check_hit's exact band-projection math (scripts/patterns/AimedBand.gd:33-42),
## reimplemented here against a band centered on `global_position` (not anchored to one end like
## AimedBand's boss-origin beam): `proj` is the signed distance along `_dir` from center,
## clamped to +-half the lane length; `perp` is the perpendicular distance off the centerline.
func _in_lane(pos: Vector2) -> bool:
	var to := pos - global_position
	var proj := to.dot(_dir)
	if absf(proj) > _length * 0.5:
		return false
	var perp := (to - _dir * proj).length()
	return perp <= _thickness

func _draw() -> void:
	var half := _dir * _length * 0.5
	if _windup > 0.0:
		draw_line(-half, half, Color(1.0, 0.85, 0.2, 0.5), 3.0)   # AimedBand's exact telegraph color/idiom
		return
	if _active_t > 0.0:
		draw_line(-half, half, Color(1.0, 0.4, 0.1, 0.6), _thickness * 2.0)   # AimedBand's exact "live" color, band-width thick
	if not _car_sprite_loaded and _car != null and _car.visible:
		var t := Time.get_ticks_msec()
		var light_col := PixelTheme.ACCENT if int(t / 150.0) % 2 == 0 else PixelTheme.ACCENT_DIM
		var body := Rect2(_car.position - Vector2(20, 12), Vector2(40, 24))
		draw_rect(body, PixelTheme.TEXT_DIM)
		draw_rect(body, PixelTheme.DARK, false, 2.0)
		draw_rect(Rect2(_car.position - Vector2(20, 3), Vector2(40, 6)), light_col)   # light bar

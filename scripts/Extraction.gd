class_name Extraction
extends Node2D
## Dawn extraction finale (Pack A: Run variety), endless only. At the existing dawn hook
## (ShiftClock.dawn_run_time(), the same crossing Hud._process already watches for the DAWN
## banner + DAWN_BONUS_COINS — those still fire unconditionally) this starts a
## FINAL_SURGE_SECONDS window that forces the spawn floor + doubles elite odds via
## DifficultyManager, then a code-drawn chopper descends onto a fixed LZ near the forecourt.
## If the player is caught inside the LZ before the chopper's EXTRACT_WINDOW patience runs out,
## it's a WIN — routed through GameOver.trigger_win(), the SAME payout path death uses (the
## paid_out guard means a win can't double-pay, and quitting mid-surge is just a normal quit;
## PauseMenu's own abandon-payout already guards on paid_out independently of this script).
## Ignoring the chopper -> it leaves and endless continues; Boss Rush never reaches _process's
## body at all.

enum Phase { WAITING, SURGE, CHOPPER, DONE }

var _phase := Phase.WAITING
var _surge_time := 0.0
var _wait_time := 0.0
var _descend_t := 0.0
var _rotor_angle := 0.0
var _player: Node2D
var _landed := false   # one-shot: the chopper's descent has finished — fires the touchdown shake once

func _ready() -> void:
	add_to_group("extraction")
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if RunConfig.mode != "endless":
		return   # Boss Rush completely untouched
	match _phase:
		Phase.WAITING:
			if DifficultyManager.run_time >= ShiftClock.dawn_run_time():
				_start_surge()
		Phase.SURGE:
			_surge_time -= delta
			if _surge_time <= 0.0:
				_start_chopper()
		Phase.CHOPPER:
			_descend_t = minf(_descend_t + delta, GameConfig.EXTRACTION_CHOPPER_DESCEND_TIME)
			if not _landed and _descend_t >= GameConfig.EXTRACTION_CHOPPER_DESCEND_TIME:
				_landed = true
				CameraShake.add_trauma(GameConfig.SHAKE_TRAUMA_EXTRACTION)   # Pack D: touchdown
			_rotor_angle += delta * GameConfig.EXTRACTION_CHOPPER_ROTOR_HZ * TAU
			_tick_chopper(delta)
			queue_redraw()

func _start_surge() -> void:
	_phase = Phase.SURGE
	_surge_time = GameConfig.FINAL_SURGE_SECONDS
	DifficultyManager.set_surge_floor_forced(true)
	DifficultyManager.set_elite_chance_mult(GameConfig.FINAL_SURGE_ELITE_MULT)
	# Banner intentionally NOT fired here — Hud owns the dawn announcement (its reframed
	# extraction banner + sting fire at the same clock crossing); doubling it stacked scrims.

func _start_chopper() -> void:
	_phase = Phase.CHOPPER
	_wait_time = GameConfig.EXTRACT_WINDOW
	_descend_t = 0.0
	DifficultyManager.set_surge_floor_forced(false)
	DifficultyManager.set_elite_chance_mult(1.0)
	global_position = GameConfig.EXTRACTION_LZ_POS
	_banner("CHOPPER INBOUND\nREACH THE LZ")

## The chopper waits EXTRACT_WINDOW seconds; catching the player inside the LZ radius at any
## point during that window wins immediately (no continuous-dwell requirement — mobile touch
## controls make a hard "hold still for N seconds" needlessly punishing for a one-shot finale
## beat). If the window elapses first, the chopper leaves and endless continues untouched.
func _tick_chopper(delta: float) -> void:
	if _player != null and is_instance_valid(_player):
		if _player.global_position.distance_to(GameConfig.EXTRACTION_LZ_POS) <= GameConfig.EXTRACTION_LZ_RADIUS:
			_trigger_win()
			return
	_wait_time -= delta
	if _wait_time <= 0.0:
		_leave()

func _trigger_win() -> void:
	if _phase == Phase.DONE:
		return
	_phase = Phase.DONE
	queue_redraw()
	var go := get_tree().get_first_node_in_group("game_over")
	if go != null:
		go.call("trigger_win")

func _leave() -> void:
	_phase = Phase.DONE
	queue_redraw()
	# Endless continues untouched from here — the existing DAWN_BONUS_COINS already paid at the
	# 6 AM crossing (Hud._process) regardless of whether the player ever reached the chopper.

func _banner(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("show_banner", text)

func _draw() -> void:
	if _phase != Phase.CHOPPER:
		return
	draw_arc(Vector2.ZERO, GameConfig.EXTRACTION_LZ_RADIUS, 0.0, TAU, 48, PixelTheme.ACCENT, 3.0, true)
	var t := _descend_t / GameConfig.EXTRACTION_CHOPPER_DESCEND_TIME
	var body_y := lerpf(-260.0, -70.0, t)   # descends from off-screen-high to a hover height
	var body_center := Vector2(0.0, body_y)
	# Body: a chunky C3 fuselage with a C4 cockpit band — code-drawn palette shapes, no art asset.
	draw_rect(Rect2(body_center + Vector2(-34.0, -14.0), Vector2(68.0, 28.0)), PixelTheme.TEXT_DIM)
	draw_rect(Rect2(body_center + Vector2(-34.0, -14.0), Vector2(68.0, 28.0)), PixelTheme.DARK, false, 2.0)
	draw_rect(Rect2(body_center + Vector2(-16.0, -8.0), Vector2(24.0, 16.0)), PixelTheme.ACCENT)
	draw_rect(Rect2(body_center + Vector2(34.0, -3.0), Vector2(20.0, 6.0)), PixelTheme.TEXT_DIM)   # tail boom
	# Rotor: two blades spinning around the body center.
	var blade := Vector2(46.0, 0.0).rotated(_rotor_angle)
	var blade2 := Vector2(-blade.y, blade.x)   # perpendicular (same idiom as Enemy._desired_velocity's tangent)
	draw_line(body_center - blade, body_center + blade, PixelTheme.ACCENT, 3.0)
	draw_line(body_center - blade2, body_center + blade2, PixelTheme.ACCENT, 3.0)

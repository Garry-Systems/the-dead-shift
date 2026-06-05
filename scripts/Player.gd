class_name Player
extends CharacterBody2D
## The player avatar: movement (keyboard for desktop testing + joystick for mobile),
## health, contact damage, and a double-tap dash.

var _health := Health.new(GameConfig.PLAYER_MAX_HEALTH)
var _dash := DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN)
var _last_move_dir := Vector2.RIGHT
var _last_tap_time := -999.0

## Set by the VirtualJoystick. Vector2.ZERO means "no joystick input, use keyboard".
var joystick_direction := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	_dash.tick(delta)

	var dir := joystick_direction
	if dir == Vector2.ZERO:
		dir = _keyboard_dir()

	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else GameConfig.PLAYER_MOVE_SPEED
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed
	move_and_slide()

## Reads WASD / arrow keys directly (no Input Map setup needed for Phase 1 testing).
func _keyboard_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	return d.normalized()

func _unhandled_input(event: InputEvent) -> void:
	# Double-tap (touch) OR double-click (mouse) triggers a dash.
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_tap_time <= GameConfig.DASH_DOUBLE_TAP_WINDOW:
		_dash.start_dash()
		_last_tap_time = -999.0  # consume, so a 3rd tap doesn't chain
	else:
		_last_tap_time = now

## Called by zombies while they touch the player.
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_die()

func _die() -> void:
	print("PLAYER DIED — Game Over")
	get_tree().paused = true  # freeze; a proper Game Over screen comes in Phase 7

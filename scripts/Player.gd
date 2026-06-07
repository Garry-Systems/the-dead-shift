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

## Emitted each time the player gains a level (the upgrade UI listens for this).
signal leveled_up

## Mutable per-run stats (upgrade cards modify these).
var move_speed := GameConfig.PLAYER_MOVE_SPEED
var health_regen := GameConfig.PLAYER_HEALTH_REGEN

## The player's weapon node (gun upgrade cards modify it). Set in _ready.
var gun: Gun

## Progression (Phase 2). Gems grant XP; crossing a threshold levels you up.
var xp := 0
var level := 0
var pickup_radius := GameConfig.PICKUP_RADIUS
var _xp_to_next := 0

func _ready() -> void:
	add_to_group("player")
	_xp_to_next = XpCurve.xp_for_level(0)
	gun = get_node_or_null("Gun") as Gun

func _physics_process(delta: float) -> void:
	_dash.tick(delta)

	var dir := joystick_direction
	if dir == Vector2.ZERO:
		dir = _keyboard_dir()

	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else move_speed
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed
	move_and_slide()

	if health_regen > 0.0:
		_health.heal(health_regen * delta)

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

## Called by enemies while they touch the player.
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	if _health.is_dead():
		_die()

func _die() -> void:
	print("PLAYER DIED — Game Over")
	get_tree().paused = true  # freeze; a proper Game Over screen comes in Phase 7

## Grants XP and resolves any resulting level-ups.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= _xp_to_next:
		xp -= _xp_to_next
		level += 1
		_xp_to_next = XpCurve.xp_for_level(level)
		_on_level_up()

## XP needed to reach the next level (used by the HUD bar).
func xp_to_next() -> int:
	return _xp_to_next

## Restores the player to full health (called by a boss death reward).
func full_heal() -> void:
	_health.heal(_health.maxhp)

func _on_level_up() -> void:
	leveled_up.emit()

## --- Upgrade hooks (called by Upgrades.apply) ---
func upgrade_move_speed(pct: float) -> void:
	move_speed *= (1.0 + pct)

func upgrade_max_health(amount: float) -> void:
	_health.add_max(amount)

func upgrade_regen(amount: float) -> void:
	health_regen += amount

func upgrade_pickup_radius(pct: float) -> void:
	pickup_radius *= (1.0 + pct)

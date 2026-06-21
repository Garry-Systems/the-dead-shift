class_name Player
extends CharacterBody2D
## The player avatar: movement (keyboard for desktop testing + joystick for mobile),
## health, contact damage, and a double-tap dash.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const HURT_FLASH_COOLDOWN := 0.18   # min gap between red pulses (contact damage is per-frame)

## Ryan's 8 directional rotations, indexed by 45° sector of the facing angle.
## Godot 2D angles: +x = east, +y = south (down), so the order below maps
## round(angle/45) -> sprite. Index 0 = east, going clockwise.
const DIR_TEX: Array[Texture2D] = [
	preload("res://art/ryan/east.png"),        # 0
	preload("res://art/ryan/south-east.png"),  # 1
	preload("res://art/ryan/south.png"),       # 2
	preload("res://art/ryan/south-west.png"),  # 3
	preload("res://art/ryan/west.png"),        # 4
	preload("res://art/ryan/north-west.png"),  # 5
	preload("res://art/ryan/north.png"),       # 6
	preload("res://art/ryan/north-east.png"),  # 7
]

var _health := Health.new(GameConfig.PLAYER_MAX_HEALTH)
var _dash := DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN)
var _last_move_dir := Vector2.RIGHT
var _has_moved := false          # true after the first move input (gates spawn fire)
var _last_tap_time := -999.0
var _last_input_time := -999.0   # de-dupes the same-frame emulated touch/mouse pair
var _is_dead := false

## Set by the VirtualJoystick. Vector2.ZERO means "no joystick input, use keyboard".
var joystick_direction := Vector2.ZERO

## Emitted each time the player gains a level (the upgrade UI listens for this).
signal leveled_up
## Emitted once when the player dies (the GameOver overlay listens for this).
signal died

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
var _flash_mat: ShaderMaterial
var _flash_cd := 0.0
var _sprite: Sprite2D
var _facing := 2          # index into DIR_TEX; 2 = south (faces the camera at start)
var _fire_lock_time := 0.0   # boss "jam" debuff: gun can't fire while > 0
var _dash_ability := ""      # special dash effect for the chosen character ("" = plain dash); set by Main
var _ext_slow_factor := 1.0  # boss "slow" debuff: move-speed multiplier (1.0 = none)
var _ext_slow_time := 0.0

func _ready() -> void:
	add_to_group("player")
	_xp_to_next = XpCurve.xp_for_level(0)
	gun = get_node_or_null("Gun") as Gun
	_setup_flash()

## Per-instance flash material set to flash RED — the "I'm taking damage" indicator.
func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_sprite = spr
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2, 1.0))
	spr.material = _flash_mat

func _physics_process(delta: float) -> void:
	_dash.tick(delta)
	if _flash_cd > 0.0:
		_flash_cd -= delta
	if _fire_lock_time > 0.0:
		_fire_lock_time -= delta
	if _ext_slow_time > 0.0:
		_ext_slow_time -= delta
		if _ext_slow_time <= 0.0:
			_ext_slow_factor = 1.0

	var dir := joystick_direction
	if dir == Vector2.ZERO:
		dir = _keyboard_dir()

	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		_has_moved = true

	# Aim = facing = the last direction we moved. The sprite snaps to the nearest
	# of 8 poses; the gun fires at the precise angle (smooth 360 aim).
	_face(_last_move_dir)

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else (move_speed * _ext_slow_factor)
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed

	# Drive the gun: fire in our faced direction, but hold fire while moving
	# (stop-to-shoot) and until the player has given a first move input (so we
	# don't auto-empty the mag facing right at spawn).
	if gun != null:
		gun.aim_direction = _last_move_dir
		gun.hold_fire = (GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO) or not _has_moved or _fire_lock_time > 0.0

	move_and_slide()

	if health_regen > 0.0:
		_health.heal(health_regen * delta)

## Swaps Ryan's sprite to the directional rotation nearest the move vector.
func _face(dir: Vector2) -> void:
	if _sprite == null:
		return
	var idx := int(round(rad_to_deg(dir.angle()) / 45.0)) % 8
	if idx < 0:
		idx += 8
	if idx != _facing:
		_facing = idx
		_sprite.texture = DIR_TEX[idx]

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
	# With touch<->mouse emulation on, one physical press can arrive as BOTH a touch and a
	# mouse event the same frame. Ignore the second so a single tap isn't counted twice.
	if now - _last_input_time < 0.05:
		return
	_last_input_time = now

	if now - _last_tap_time <= GameConfig.DASH_DOUBLE_TAP_WINDOW:
		if _dash.start_dash():
			_on_dash_started()
		_last_tap_time = -999.0  # consume, so a 3rd tap doesn't chain
	else:
		_last_tap_time = now

## Set by Main at run start from the chosen character. "shockwave" = Alstar's dash blast.
func set_dash_ability(ability: String) -> void:
	_dash_ability = ability

## Runs the moment a dash actually begins (gated by the dash cooldown). Plain characters do
## nothing extra; Alstar drops a Shockwave at the dash's origin (push + damage + gun talents).
func _on_dash_started() -> void:
	if _dash_ability == "shockwave":
		var sw := Shockwave.new()
		get_tree().current_scene.add_child(sw)
		sw.global_position = global_position
		sw.blast(GameConfig.CHAR_ALSTAR_SHOCK_RADIUS, GameConfig.CHAR_ALSTAR_SHOCK_DAMAGE,
			GameConfig.CHAR_ALSTAR_SHOCK_FORCE, gun, self)

## Called by enemies while they touch the player.
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
	_hurt_flash()
	if _health.is_dead():
		_die()

## Throttled red pulse — contact damage calls this every frame, so we rate-limit
## it to a periodic "ouch" rather than a solid red wash.
func _hurt_flash() -> void:
	if _flash_mat == null or _flash_cd > 0.0:
		return
	_flash_cd = HURT_FLASH_COOLDOWN
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.15)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	get_tree().paused = true
	died.emit()

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

## Health readouts for the HUD (keeps _health private).
func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func hp() -> float:
	return _health.current if _health != null else 0.0

func max_hp() -> float:
	return _health.maxhp if _health != null else 0.0

## Restores the player to full health (called by a boss death reward).
func full_heal() -> void:
	_health.heal(_health.maxhp)

## Talent hook (Bloodthirst lifesteal): restore a flat amount, clamped to max by Health.
func heal(amount: float) -> void:
	if _health != null:
		_health.heal(amount)

## Relic hook: raise (or lower, when removed) max health. Reversible via a negative amount.
func relic_add_max_health(amount: float) -> void:
	_health.add_max(amount)

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

## --- Boss debuff hooks (called by the DebuffApplier pattern) ---

## "Jam": the gun can't fire for `duration`s even while standing still. Longest wins.
func apply_fire_lock(duration: float) -> void:
	_fire_lock_time = maxf(_fire_lock_time, duration)

## "Slow": cut move speed by `factor` (0..1) for `duration`s. Strongest/longest wins.
func apply_slow(factor: float, duration: float) -> void:
	_ext_slow_factor = minf(_ext_slow_factor, clampf(1.0 - factor, 0.1, 1.0))
	_ext_slow_time = maxf(_ext_slow_time, duration)

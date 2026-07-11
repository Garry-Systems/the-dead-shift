extends Control
## On-screen movement joystick for touch. Drag ANYWHERE on the screen to move; a floating
## base ring + knob is drawn at the touch point. Reports a normalized
## direction to the Player via `player.joystick_direction`.
##
## Uses _input (global) so it works regardless of mouse_filter, and finds the Player via the
## "player" group (no scene wiring needed). On desktop, enable
## input_devices/pointing/emulate_touch_from_mouse to drive this with the mouse for testing.

@export var max_radius := 120.0

var _player: Player
var _ability_button: AbilityButton
var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO   # current knob offset from origin (px, clamped to max_radius)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat UI taps (we read raw _input)
	_player = get_tree().get_first_node_in_group("player") as Player

func _notification(what: int) -> void:
	# If a drag was active when the game paused (e.g. the player tapped the pause button,
	# which we also see as a touch), the touch-up arrives while we're paused and we never
	# get it — leaving a stale touch index that would block movement. Clear it on unpause.
	if what == NOTIFICATION_UNPAUSED:
		_touch_index = -1
		_knob = Vector2.ZERO
		_set_player_dir(Vector2.ZERO)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			# Final-review fix (Finding 1a): don't claim a press that lands on the ability button —
			# this Control has no rect exclusion of its own and JoystickLayer is the LAST node in
			# Main.tscn (highest _input priority), so an unguarded claim here eats every ability tap
			# (ring flash under the button) and, worse, a thumb resting on the button locks out the
			# ONE joystick touch slot so the other thumb can't move the player at all.
			if _touch_on_ability_button(event.position):
				return
			_touch_index = event.index
			_origin = event.position
			_knob = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_knob = Vector2.ZERO
			_set_player_dir(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_knob = (event.position - _origin).limit_length(max_radius)
		_set_player_dir(_knob / max_radius)
		queue_redraw()

func _set_player_dir(dir: Vector2) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.joystick_direction = dir

## Lazily resolves the HUD ability button (cache + is_instance_valid recheck, the exact idiom
## _set_player_dir already uses for `_player` above). Null-safe by design: only 6 of 7 characters
## have a row in Abilities.gd (Hud._build_ability_button only builds the button for a non-empty
## row), and menu/probe scenes may have no Hud in the tree at all — both cases just mean "no
## exclusion zone," never a crash.
func _resolve_ability_button() -> AbilityButton:
	if _ability_button == null or not is_instance_valid(_ability_button):
		_ability_button = get_tree().get_first_node_in_group("ability_button") as AbilityButton
	return _ability_button

## True when `pos` (viewport/screen coords — an InputEventScreenTouch.position, same space this
## script already draws in) falls inside the live ability button's rect. Plain `get_global_rect()`
## is used, NOT the `get_rect()` + `get_global_transform_with_canvas()` mapping: both AbilityButton
## (a runtime child of the `Hud` CanvasLayer, Hud.gd:159) and this joystick (a scene child of
## `JoystickLayer`, Main.tscn) sit under CanvasLayers that set no `offset`/`scale`/`rotation` —
## `JoystickLayer` only sets `layer = 8` (draw order, not a transform) and `Hud` sets nothing at
## all — so `get_global_transform_with_canvas()` is the identity on both in the running tree, and
## `get_global_rect()` is already directly comparable to a raw touch position with no extra
## mapping needed (verified in the probe below by asserting both CanvasLayers' canvas transforms
## are identity). Returns false — no exclusion — when no button exists at all.
func _touch_on_ability_button(pos: Vector2) -> bool:
	var btn := _resolve_ability_button()
	if btn == null:
		return false
	return btn.get_global_rect().has_point(pos)

## Floating base ring + knob in the C4 lavender palette, only while a touch is active.
func _draw() -> void:
	if _touch_index == -1:
		return
	var base_col := Color(0.878, 0.898, 1.0, 0.22)   # C4 @ low alpha
	var knob_col := Color(0.878, 0.898, 1.0, 0.70)
	draw_circle(_origin, max_radius, base_col)
	draw_circle(_origin + _knob, max_radius * 0.42, knob_col)

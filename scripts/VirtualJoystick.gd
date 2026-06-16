extends Control
## On-screen movement joystick for touch. Drag anywhere in the LEFT HALF of the screen to
## move; a floating base ring + knob is drawn at the touch point. Reports a normalized
## direction to the Player via `player.joystick_direction`.
##
## Uses _input (global) so it works regardless of mouse_filter, and finds the Player via the
## "player" group (no scene wiring needed). On desktop, enable
## input_devices/pointing/emulate_touch_from_mouse to drive this with the mouse for testing.

@export var max_radius := 120.0

var _player: Player
var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO   # current knob offset from origin (px, clamped to max_radius)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # never eat UI taps (we read raw _input)
	_player = get_tree().get_first_node_in_group("player") as Player

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var left_half: bool = event.position.x < get_viewport_rect().size.x * 0.5
		if event.pressed and _touch_index == -1 and left_half:
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

## Floating base ring + knob in the C4 lavender palette, only while a touch is active.
func _draw() -> void:
	if _touch_index == -1:
		return
	var base_col := Color(0.878, 0.898, 1.0, 0.22)   # C4 @ low alpha
	var knob_col := Color(0.878, 0.898, 1.0, 0.70)
	draw_circle(_origin, max_radius, base_col)
	draw_circle(_origin + _knob, max_radius * 0.42, knob_col)

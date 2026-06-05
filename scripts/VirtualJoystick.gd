extends Control
## A simple on-screen movement joystick. While the player drags within the left
## half of the screen, it reports a normalized direction to the Player.

@export var player: Player
@export var knob: Control
@export var max_radius := 90.0

var _touch_index := -1
var _origin := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var left_half: bool = event.position.x < get_viewport_rect().size.x * 0.5
		if event.pressed and _touch_index == -1 and left_half:
			_touch_index = event.index
			_origin = event.position
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			if player:
				player.joystick_direction = Vector2.ZERO
			if knob:
				knob.position = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var offset: Vector2 = (event.position - _origin).limit_length(max_radius)
		if player:
			player.joystick_direction = offset / max_radius
		if knob:
			knob.position = offset

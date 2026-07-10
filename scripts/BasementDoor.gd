class_name BasementDoor
extends Node2D
## THE BASEMENT (Pack E): a code-drawn cellar-hatch floor prop. Spawned/positioned by the
## Basement controller (scripts/Basement.gd); this node only owns its own hold-to-descend
## detection and its unentered despawn timer — the controller detects the freed instance via
## is_instance_valid (same "child owns its own lifetime, controller just polls validity" idiom
## Spawner/ObstacleField use for enemies/destructibles).
##
## Standing detection: the player must be within BASEMENT_DOOR_RING of this node's position,
## continuously, for BASEMENT_DESCEND_HOLD seconds — stepping out resets the hold to zero
## instantly (no partial-credit grace window; matches the ring math everywhere else in this
## codebase — Spawner/Extraction never grant partial credit either). Fires descend_requested
## exactly once per door instance.

signal descend_requested

var _player: Node2D
var _held := 0.0
var _lifetime := 0.0
var _pulse_t := 0.0
var _emitted := false

func _ready() -> void:
	add_to_group("basement_door")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_lifetime = GameConfig.BASEMENT_DOOR_LIFETIME

func _process(delta: float) -> void:
	_pulse_t += delta
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	var inside := _player != null and is_instance_valid(_player) \
		and _player.global_position.distance_to(global_position) <= GameConfig.BASEMENT_DOOR_RING
	_held = hold_step(inside, _held, delta)
	if not _emitted and _held >= GameConfig.BASEMENT_DESCEND_HOLD:
		_emitted = true
		descend_requested.emit()
	queue_redraw()

## Pure hold-accumulation step (Task 3 brief): accrues while standing inside the ring, resets
## instantly to 0.0 the moment the player steps outside. Exposed static so the accrual math is
## probe-able without a live scene tree.
static func hold_step(inside: bool, held: float, delta: float) -> float:
	return held + delta if inside else 0.0

func _draw() -> void:
	# Hatch body: C2 indigo rect ~64x48 with a diagonal cross-hatch for texture, dark border.
	var half := Vector2(32.0, 24.0)
	var rect := Rect2(-half, half * 2.0)
	draw_rect(rect, PixelTheme.ACCENT_DIM)
	draw_rect(rect, PixelTheme.DARK, false, 2.0)
	for i in range(-2, 3):
		var ox := float(i) * 13.0
		var x0 := clampf(ox - 10.0, -half.x, half.x)
		var x1 := clampf(ox + 10.0, -half.x, half.x)
		draw_line(Vector2(x0, half.y), Vector2(x1, -half.y), PixelTheme.DARK, 2.0)
	# Handle bar: C4 lavender bar across the middle.
	draw_rect(Rect2(Vector2(-18.0, -4.0), Vector2(36.0, 8.0)), PixelTheme.ACCENT)
	# Pulsing telegraph ring at the interact radius — alpha oscillates on the time accumulator.
	var alpha := 0.22 + 0.18 * sin(_pulse_t * TAU * 0.6)
	draw_arc(Vector2.ZERO, GameConfig.BASEMENT_DOOR_RING, 0.0, TAU, 48,
		Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, alpha), 2.0, true)
	# Descend progress arc: sweeps 0 -> TAU as the hold accrues.
	if _held > 0.0:
		var frac := clampf(_held / GameConfig.BASEMENT_DESCEND_HOLD, 0.0, 1.0)
		draw_arc(Vector2.ZERO, GameConfig.BASEMENT_DOOR_RING, -PI / 2.0, -PI / 2.0 + frac * TAU, 48,
			PixelTheme.ACCENT, 4.0, true)

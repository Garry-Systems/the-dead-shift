class_name FlameCone
extends Node2D
## Transient orange flame-cone VFX for the Flamethrower: a flickering filled cone
## that fades and frees itself. Spawned each fire tick; short life so overlapping
## ticks read as a continuous stream. Orange is a deliberate exception to the
## strict 4-color palette (same as confetti / red enemy projectiles).

const CORE := Color(1.0, 0.5, 0.12)    # orange body
const TIP := Color(1.0, 0.78, 0.22)    # brighter inner core
const LIFE := 0.12

var aim := Vector2.RIGHT
var length := 280.0
var half_angle := 0.52
var _life := LIFE

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := clampf(_life / LIFE, 0.0, 1.0)
	var base := aim.angle()
	var flen := length * randf_range(0.85, 1.0)       # length flicker
	var steps := 8
	var outer := PackedVector2Array()
	outer.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := base + lerpf(-half_angle, half_angle, t)
		outer.append(Vector2.from_angle(ang) * flen * randf_range(0.9, 1.0))
	draw_colored_polygon(outer, Color(CORE.r, CORE.g, CORE.b, 0.5 * a))
	var inner := PackedVector2Array()
	inner.append(Vector2.ZERO)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := base + lerpf(-half_angle * 0.5, half_angle * 0.5, t)
		inner.append(Vector2.from_angle(ang) * flen * 0.6)
	draw_colored_polygon(inner, Color(TIP.r, TIP.g, TIP.b, 0.6 * a))

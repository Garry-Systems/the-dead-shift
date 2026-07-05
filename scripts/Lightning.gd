class_name Lightning
extends Node2D
## Transient cyan arc VFX for the Tesla Gun: draws jagged segments between the
## given world points, fades out, frees itself. Cyan is a deliberate exception
## to the strict 4-color palette (same as confetti / red enemy projectiles).

const COLOR := Color(0.2, 1.0, 1.0)   # cyan — default bolt color
const LIFE := 0.16                     # seconds visible
const SEG_LEN := 24.0                  # subdivide each span into ~this-long jagged steps
const JAG := 10.0                      # max perpendicular jitter per node

## Bolt color, mutable per-instance. Defaults to COLOR (cyan) so the Tesla Gun / HazardZone
## zap-arc are unchanged; talent-chain callers may override before add_child (electric family
## stays cyan today, so Phase 1 never actually overrides this — the var exists for later kinds).
var color := COLOR

var points: Array = []                 # world positions: [origin, target1, target2, ...]
var _life := LIFE

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := clampf(_life / LIFE, 0.0, 1.0)
	var col := Color(color.r, color.g, color.b, a)
	for i in range(points.size() - 1):
		_draw_bolt(to_local(points[i]), to_local(points[i + 1]), col)

func _draw_bolt(from: Vector2, to: Vector2, col: Color) -> void:
	var span := to - from
	var steps := maxi(1, int(span.length() / SEG_LEN))
	var perp := span.normalized().orthogonal()
	var prev := from
	for s in range(1, steps + 1):
		var t := float(s) / float(steps)
		var jitter := 0.0 if s == steps else randf_range(-JAG, JAG)
		var pt := from + span * t + perp * jitter
		draw_line(prev, pt, col, 3.0)
		prev = pt

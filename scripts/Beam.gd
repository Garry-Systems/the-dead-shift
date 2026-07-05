class_name Beam
extends Node2D
## Transient straight-line beam VFX for the Railgun: draws one thick fading line
## from `start` to `end`, then frees itself. Drawn in C4 lavender (the player color),
## so unlike Lightning (cyan) / FlameCone (orange) it stays INSIDE the strict 4-color
## palette — no new palette exception.

const COLOR := Color(0.878, 0.898, 1.0)   # C4 lavender (matches Shockwave.RING_COLOR) — default
const LIFE := 0.12                          # seconds visible
const CORE_WIDTH := 6.0                     # bright core thickness
const GLOW_WIDTH := 12.0                    # faint wide glow thickness

## Beam color, mutable per-instance. Defaults to COLOR so the Railgun is unchanged.
var color := COLOR

var start := Vector2.ZERO                    # world-space beam origin
var end := Vector2.ZERO                      # world-space beam end
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
	var s := to_local(start)
	var e := to_local(end)
	draw_line(s, e, Color(color.r, color.g, color.b, 0.25 * a), GLOW_WIDTH)
	draw_line(s, e, Color(color.r, color.g, color.b, a), CORE_WIDTH)

class_name EnemyHealthBar
extends Node2D
## A small health bar drawn above an enemy's head. Hidden until the enemy takes a
## non-fatal hit, then it reveals and tracks remaining health. A child of the enemy,
## so it follows it and is freed automatically when the enemy dies.

const WIDTH := 28.0
const HEIGHT := 4.0

var fraction := 1.0
var shown := false

## Reveal + update the bar (called by the enemy on a non-fatal hit).
func set_fraction(f: float) -> void:
	fraction = clampf(f, 0.0, 1.0)
	shown = true
	queue_redraw()

func _draw() -> void:
	if not shown:
		return
	draw_rect(Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH, HEIGHT), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH * fraction, HEIGHT), Color(0.3, 1.0, 0.3))

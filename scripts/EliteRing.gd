class_name EliteRing
extends Node2D
## The colored outline ring drawn over an elite enemy's sprite — one family color per modifier
## (Armored/Volatile/Splitter/Alpha), set by Enemy.apply_elite(). A dedicated child node rather
## than Enemy._draw() itself: Godot paints a CanvasItem's OWN _draw() calls BEFORE its children,
## so a ring drawn on the Enemy node directly would render UNDER the Sprite2D child — this sits
## alongside the sprite as a sibling with a higher z_index instead, so it always composites on
## top regardless of the enemy's own draw order (and, per the roadmap's Pack F, still reads
## correctly once enemies swap their _draw shapes for real sprite textures).

const RADIUS := 24.0
const WIDTH := 3.0
const ARC_POINTS := 32

var color := Color(1, 1, 1, 1)

func _ready() -> void:
	z_index = 5   # above EnemyHealthBar's z_index=1 and the default-z Sprite2D
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, ARC_POINTS, color, WIDTH, true)

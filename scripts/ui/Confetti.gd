class_name Confetti
extends Node2D
## A one-shot celebratory confetti burst: spawns N little spinning colored rectangles that
## fire outward + upward from the node's origin, fall under gravity, flutter, fade out, then
## the node frees itself. Everything is drawn in a single _draw pass (cheap, one node).
##
## Deliberately party-colored — a reward "pop" is the one place we step outside the run's
## strict 4-color palette. Used by the crate reveal for rare wins. Reusable anywhere:
##   var c := Confetti.new(); parent.add_child(c); c.position = mid; c.burst(110, [rarity_col])

const GRAVITY := 1100.0      # px/s^2 downward pull
const DRAG := 0.82           # horizontal velocity damping per second (the flutter settle)
const LIFETIME := 2.4        # seconds before the whole burst frees itself
const FADE_START := 1.5      # age at which pieces begin fading out

## Bright party palette; the winning rarity color gets mixed in (and weighted) per burst.
const PARTY := [
	Color("ff3b3b"), Color("ffd23b"), Color("3bff6e"),
	Color("3b9bff"), Color("c14bff"), Color("ffffff"),
]

var _parts: Array = []
var _age := 0.0

## Fire `count` confetti pieces from local origin (0,0). Any `extra` colors (e.g. the winning
## rarity color) are blended into the party palette. Call once, right after add_child + setting
## position. The node animates itself and queue_free()s when the burst ends.
func burst(count: int = 110, extra: Array = []) -> void:
	z_index = 4096   # draw above any reveal card / popup beneath us
	var palette: Array = PARTY.duplicate()
	for c in extra:
		palette.append(c)
		palette.append(c)   # weight the rarity color so the burst reads "that" color
	for i in count:
		var ang := randf_range(0.0, TAU)
		var spd := randf_range(280.0, 780.0)
		var vel := Vector2(cos(ang), sin(ang)) * spd
		vel.y -= randf_range(140.0, 420.0)   # bias upward so pieces arc up then rain down
		_parts.append({
			"pos": Vector2.ZERO,
			"vel": vel,
			"ang": randf_range(0.0, TAU),
			"spin": randf_range(-14.0, 14.0),
			"size": randf_range(11.0, 24.0),
			"agg": randf_range(0.4, 1.0),       # height-to-width ratio (strip-like confetti)
			"color": palette[randi() % palette.size()],
		})

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var damp := pow(DRAG, delta)
	for p in _parts:
		# Reassign whole Vector2s (value types) rather than mutating .x/.y through the dict —
		# in-place member writes into a container value don't reliably write back in GDScript.
		var vel: Vector2 = p["vel"]
		vel.y += GRAVITY * delta
		vel.x *= damp
		p["vel"] = vel
		p["pos"] = (p["pos"] as Vector2) + vel * delta
		p["ang"] = float(p["ang"]) + float(p["spin"]) * delta
	queue_redraw()

func _draw() -> void:
	var a := 1.0
	if _age > FADE_START:
		a = clampf(1.0 - (_age - FADE_START) / (LIFETIME - FADE_START), 0.0, 1.0)
	for p in _parts:
		var w: float = p["size"]
		var h: float = float(p["size"]) * float(p["agg"])
		var col: Color = p["color"]
		draw_set_transform(p["pos"], float(p["ang"]), Vector2.ONE)
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(col.r, col.g, col.b, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

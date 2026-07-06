class_name EliteVolatileBlast
extends Node2D
## Elite modifier "Volatile" (Pack A): on death, a telegraphed ELITE_VOLATILE_FUSE-second fuse
## (a pulsing green ring — mirrors Mine's arm-delay/blink idiom and ZoneFill's windup circle)
## then a single area blast that hurts the PLAYER ONLY (never enemies — this is the elite
## mirror of ExploderEnemy's instant self-detonate, just delayed + telegraphed, and reuses its
## blast-FX flow). Damage/radius are pre-scaled by the caller (exploder constants x
## GameConfig.ELITE_VOLATILE_MULT x the dying elite's own special_mult); this node only resolves
## the fuse and the hit.

const BLAST_FX := preload("res://art/muzzle.png")

var _dmg := 0.0
var _radius := 0.0
var _fuse := 0.0
var _detonated := false

## Spawns the fuse at `pos`. Caller does NOT add_child first (mirrors Mine.spawn).
static func spawn(pos: Vector2, dmg: float, radius: float, tree) -> void:
	if tree == null:
		return
	var b := EliteVolatileBlast.new()
	b._dmg = dmg
	b._radius = radius
	tree.current_scene.add_child(b)
	b.global_position = pos

func _ready() -> void:
	_fuse = GameConfig.ELITE_VOLATILE_FUSE

func _process(delta: float) -> void:
	if _detonated:
		return
	_fuse -= delta
	queue_redraw()
	if _fuse <= 0.0:
		_detonate()

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if global_position.distance_to((player as Node2D).global_position) <= _radius:
			player.take_damage(_dmg)
	_spawn_blast_fx()
	queue_free()

## A brief expanding, fading burst at the detonation point (independent of this freed node) —
## identical shape to ExploderEnemy._spawn_blast_fx, reused verbatim so the two blasts read the
## same way to the player.
func _spawn_blast_fx() -> void:
	var fx := Sprite2D.new()
	fx.texture = BLAST_FX
	fx.global_position = global_position
	fx.z_index = 2
	get_tree().current_scene.add_child(fx)
	var full := _radius / maxf(float(BLAST_FX.get_width()) * 0.5, 1.0)
	fx.scale = Vector2(full * 0.3, full * 0.3)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(full, full), 0.25)
	tw.tween_property(fx, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(fx.queue_free)

func _draw() -> void:
	var blink := sin(Time.get_ticks_msec() / 1000.0 * TAU * 4.0) * 0.5 + 0.5
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(Hazards.GREEN.r, Hazards.GREEN.g, Hazards.GREEN.b, 0.25 + 0.35 * blink), 3.0, true)
	draw_circle(Vector2.ZERO, 8.0, Color(Hazards.GREEN.r, Hazards.GREEN.g, Hazards.GREEN.b, 0.6))

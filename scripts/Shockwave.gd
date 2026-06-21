class_name Shockwave
extends Node2D
## Alstar Tuck's signature dash blast: an instant radial burst that shoves every nearby enemy
## away, damages them, and applies the equipped gun's on-hit weapon talents to each (reusing
## the SAME TalentEngine path bullets use — ignite/freeze/poison/slow/chain/vulnerable/etc.).
## Then it draws an expanding C4-lavender ring + flash and frees itself. Spawned by the Player
## on dash when the character has the "shockwave" dash ability. Self-contained: blast() does
## the gameplay, _process/_draw do the visual.

const RING_TIME := 0.35                       # seconds the visual ring expands + fades
const RING_COLOR := Color(0.878, 0.898, 1.0)  # C4 lavender (the player's color)

var _radius := 0.0   # blast radius, also the visual ring's final size
var _age := 0.0

## Fire the burst immediately, then start the visual. The caller sets global_position and
## adds this node to the scene BEFORE calling blast(). gun/player may be null (the burst still
## pushes + damages; it just carries no talents). Mirrors Bullet's damage→killed→process_hit.
func blast(radius: float, damage: float, force: float, gun, player) -> void:
	_radius = radius
	z_index = 50
	var payload: Dictionary = {}
	if gun != null and is_instance_valid(gun):
		payload = gun.talent_payload
	var tree := get_tree()
	var r2 := radius * radius
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var node := e as Node2D
		if node.global_position.distance_squared_to(global_position) > r2:
			continue
		var enemy_pos := node.global_position
		var dir := global_position.direction_to(enemy_pos)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		# Push everything away (reuses the enemy knockback channel).
		if e.has_method("apply_knockback"):
			e.apply_knockback(dir * force)
		# Damage, then carry the gun's on-hit talents onto the hit, exactly like a bullet impact.
		e.take_damage(damage)
		var killed := not is_instance_valid(e)
		if not payload.is_empty():
			TalentEngine.process_hit(e, enemy_pos, damage, killed, payload, {
				"player": player,
				"gun": gun,
				"dir": dir,
				"tree": tree,
			})
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= RING_TIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / RING_TIME, 0.0, 1.0)
	var fade := 1.0 - t
	# Expanding shock front: a thick ring that grows past the blast edge and fades.
	var ring_r := _radius * lerpf(0.15, 1.08, t)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
		Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, fade), 2.0 + 8.0 * fade, true)
	# Inner flash disc, fades faster than the ring.
	var disc_a := fade * fade * 0.35
	draw_circle(Vector2.ZERO, _radius * (0.4 + 0.5 * t),
		Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, disc_a))

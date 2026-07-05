class_name Shockwave
extends Node2D
## Alstar Tuck's signature dash blast: an instant radial burst that shoves every nearby enemy
## away, damages them, and applies the equipped gun's on-hit weapon talents to each (reusing
## the SAME TalentEngine path bullets use — ignite/freeze/poison/slow/chain/vulnerable/etc.).
## Then it draws an expanding C4-lavender ring + flash and frees itself. Spawned by the Player
## on dash when the character has the "shockwave" dash ability. Self-contained: blast() does
## the gameplay, _process/_draw do the visual. flash() is a visual-only variant (no damage or
## knockback) used for Ryan Ace's projectile-purge pulse.

const RING_TIME := 0.35                       # seconds the visual ring expands + fades
const RING_COLOR := Color(0.878, 0.898, 1.0)  # C4 lavender (the player's color) — default ring color

## Ring color, mutable per-instance. Defaults to RING_COLOR so every existing caller (Alstar's
## dash, Ryan's purge, barrel bursts, grenade shells) is unchanged; talent-proc callers (execute/
## vulnerable/explode/nova/shatter rings) set this to their own family color before flash()/blast().
var color := RING_COLOR

var _radius := 0.0   # blast radius, also the visual ring's final size
var _age := 0.0

## Fire the burst immediately, then start the visual. The caller sets global_position and
## adds this node to the scene BEFORE calling blast(). gun/player may be null (the burst still
## pushes + damages; it just carries no talents). Mirrors Bullet's damage→killed→process_hit.
func blast(radius: float, damage: float, force: float, gun, player, hit_destructibles := false) -> void:
	_radius = radius
	z_index = 50
	SoundManager.play("explosion")
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
		var was_alive: bool = e.has_method("health_fraction") and e.health_fraction() > 0.0
		var hampered: bool = was_alive and payload.has("cc_bonus") and e.has_method("is_hampered") and e.is_hampered()
		var roll := TalentEngine.roll_damage(TalentEngine.apply_cc_bonus(damage, payload, hampered), payload)
		e.take_damage(float(roll["damage"]))
		var killed: bool = was_alive and e.health_fraction() <= 0.0   # alive->dead transition; corpse hits are non-events
		if was_alive and bool(roll.get("crit", false)):
			CombatText.crit(enemy_pos, float(roll["damage"]), e.get_instance_id())
		if was_alive and not payload.is_empty():
			TalentEngine.process_hit(e, enemy_pos, damage, killed, payload, {
				"player": player,
				"gun": gun,
				"dir": dir,
				"tree": tree,
				"crit": bool(roll.get("crit", false)),
			})
	# Destructibles in the blast take raw damage too (barrels burst). GATED: a barrel's OWN
	# burst must not recursively detonate the field — that ripples via Destructible's fuse +
	# per-frame budget — so only outside explosions (the grenade) pass hit_destructibles = true.
	if hit_destructibles:
		for d in tree.get_nodes_in_group("destructibles"):
			if not is_instance_valid(d) or not d.has_method("take_damage"):
				continue
			if (d as Node2D).global_position.distance_squared_to(global_position) <= r2:
				d.take_damage(damage)
	queue_redraw()

## Visual-only burst (no damage / no knockback) — the expanding ring + flash on its own.
## Used for Ryan Ace's projectile-purge feedback. Caller sets position + adds to the tree first.
func flash(radius: float) -> void:
	_radius = radius
	z_index = 50
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
		Color(color.r, color.g, color.b, fade), 2.0 + 8.0 * fade, true)
	# Inner flash disc, fades faster than the ring.
	var disc_a := fade * fade * 0.35
	draw_circle(Vector2.ZERO, _radius * (0.4 + 0.5 * t),
		Color(color.r, color.g, color.b, disc_a))

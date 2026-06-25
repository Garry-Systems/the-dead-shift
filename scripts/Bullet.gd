extends Area2D
## A projectile: flies in a direction, damages enemies it overlaps, and despawns
## after a lifetime. Speed/damage and the talent payload (pierce, ricochet, burn)
## are set by the gun that fires it, so weapon talents carry through to the bullet.

var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := GameConfig.BULLET_DAMAGE
var max_travel := INF          # px; despawn after flying this far (set to gun_range)

# Talent payload (set by Gun._spawn_bullet; 0/false = vanilla bullet).
var pierce_count := 0          # extra enemies the bullet passes through
var ricochet_count := 0        # times it redirects to the next nearest enemy
var overpen_growth := 0.0      # Railbreaker: % damage gained each time the bullet pierces
var incendiary := false        # ignites enemies it hits
var burn_dps := 0.0
var burn_duration := 0.0

# Delivery-shell on-death effects (set by Gun._spawn_bullet; inert on a normal bullet).
var explode_radius := 0.0      # >0: detonate a Shockwave on death (Grenade Launcher)
var explode_force := 0.0       # knockback force for the explosion
var pool_cfg := {}             # non-empty: spawn an enemy-only HazardZone on death (Acid Cannon)
var _detonated := false        # guard: the on-death effect fires at most once

# Weapon-loot talents: resolved combat payload + the firing player (for lifesteal/frenzy).
var talent_payload := {}       # {} = no talents on this weapon
var talent_player: Player = null

var _life := 0.0
var _traveled := 0.0           # total distance flown (vs max_travel)
var _hit: Array = []           # enemies already damaged (so pierce/ricochet don't re-hit)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Detect cover (block) + destructibles (damage) in addition to enemies (default bit 1).
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)
	set_collision_mask_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_traveled += speed * delta
	if _traveled >= max_travel:
		_expire()
		return
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		_expire()

func _on_body_entered(body) -> void:
	if _is_shell():
		# Delivery shells ignore direct damage/pierce — detonate on the first solid contact.
		if body.is_in_group("cover") or body.is_in_group("destructibles") or body.is_in_group("enemies"):
			_detonate()
			queue_free()
		return
	# Solid cover damages-then-stops the bullet (cars are clearable; rubble shrugs it off).
	if body.is_in_group("cover"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	# Non-solid destructible props take raw damage (no talents); the bullet pierces or stops.
	if body.is_in_group("destructibles"):
		if body in _hit:
			return
		_hit.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if pierce_count > 0:
			pierce_count -= 1
			return
		queue_free()
		return
	if not body.is_in_group("enemies") or body in _hit:
		return

	_hit.append(body)
	var hit_pos := global_position

	# Crit (Killshot) decides the damage dealt this impact.
	var roll := TalentEngine.roll_damage(damage, talent_payload)
	body.take_damage(float(roll["damage"]))
	var killed := not is_instance_valid(body)

	if not killed:
		if body.has_method("flash_hit"):
			body.flash_hit()
		if incendiary and body.has_method("ignite"):
			body.ignite(burn_dps, burn_duration)

	# Fire talent procs: on-hit statuses, lifesteal, chain, on-kill explode/frenzy.
	if not talent_payload.is_empty():
		TalentEngine.process_hit(body, hit_pos, damage, killed, talent_payload, {
			"player": talent_player,
			"gun": (talent_player.gun if (talent_player != null and is_instance_valid(talent_player)) else null),
			"dir": direction,
			"tree": get_tree(),
		})

	# Ricochet redirects toward a fresh target; pierce keeps flying straight.
	if ricochet_count > 0:
		ricochet_count -= 1
		var next := _nearest_unhit_enemy()
		if next != null:
			direction = (next.global_position - global_position).normalized()
		return
	if pierce_count > 0:
		pierce_count -= 1
		if overpen_growth > 0.0:
			damage *= (1.0 + overpen_growth / 100.0)
		return
	queue_free()

## True when this bullet delivers an on-death effect instead of a direct hit.
func _is_shell() -> bool:
	return explode_radius > 0.0 or not pool_cfg.is_empty()

## Run the on-death effect(s) at the current position. No-op on a normal bullet.
func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	if explode_radius > 0.0:
		var blast := Shockwave.new()
		get_tree().current_scene.add_child(blast)
		blast.global_position = global_position
		var gun = (talent_player.gun if (talent_player != null and is_instance_valid(talent_player)) else null)
		blast.blast(explode_radius, damage, explode_force, gun, talent_player)
	if not pool_cfg.is_empty():
		var zone := HazardZone.new()
		get_tree().current_scene.add_child(zone)
		zone.global_position = global_position
		zone.configure_hazard(pool_cfg)

## Detonate (if a shell) then free. Used at every end-of-life exit.
func _expire() -> void:
	if _is_shell():
		_detonate()
	queue_free()

func _nearest_unhit_enemy() -> Node2D:
	var space := get_world_2d().direct_space_state
	var best: Node2D = null
	var best_dist := INF
	for z in get_tree().get_nodes_in_group("enemies"):
		if z in _hit:
			continue
		var node := z as Node2D
		if not LineOfSight.is_clear(global_position, node.global_position, space):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best

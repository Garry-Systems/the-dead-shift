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
var pin_chance := 0.0          # Nail Gun: chance to root the enemy on hit (0 = none)
var pin_dur := 0.0             # Nail Gun: root duration (seconds)

# Delivery-shell on-death effects (set by Gun._spawn_bullet; inert on a normal bullet).
var explode_radius := 0.0      # >0: detonate a Shockwave on death (Grenade Launcher)
var explode_force := 0.0       # knockback force for the explosion
var pool_cfg := {}             # non-empty: spawn an enemy-only HazardZone on death (Acid Cannon)
var impact_frac := 0.0         # >0: the directly-contacted enemy takes damage*frac before the blast
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
		# Delivery shells ignore pierce — but a direct enemy hit lands impact damage
		# (impact_frac of the shell's damage) BEFORE detonating, so the Grenade
		# Launcher isn't dead weight against a single boss. Cover/props: blast only.
		if body.is_in_group("cover") or body.is_in_group("destructibles") or body.is_in_group("enemies"):
			if not _detonated:
				if impact_frac > 0.0 and body.is_in_group("enemies") and body.has_method("take_damage"):
					body.take_damage(damage * impact_frac)
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

	# Crit (Killshot) decides the damage dealt this impact. killed = the alive->dead
	# TRANSITION this hit caused; a second same-frame hit on an already-dead body
	# (pellet fan, overlapping AoE) is a non-event: no statuses, no procs.
	var was_alive: bool = body.has_method("health_fraction") and body.health_fraction() > 0.0
	var roll := TalentEngine.roll_damage(damage, talent_payload)
	body.take_damage(float(roll["damage"]))
	var killed: bool = was_alive and body.health_fraction() <= 0.0

	if was_alive and not killed:
		if body.has_method("flash_hit"):
			body.flash_hit()
		if incendiary and body.has_method("ignite"):
			body.ignite(burn_dps, burn_duration)
		if pin_chance > 0.0 and body.has_method("apply_pin") and randf() < pin_chance:
			body.apply_pin(pin_dur)

	# Fire talent procs: on-hit statuses, lifesteal, chain, on-kill explode/frenzy.
	if was_alive and not talent_payload.is_empty():
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
		blast.blast(explode_radius, damage, explode_force, gun, talent_player, true)  # grenade blast also scorches barrels/destructibles
	if not pool_cfg.is_empty():
		_cap_player_pools()
		var zone := HazardZone.new()
		get_tree().current_scene.add_child(zone)
		zone.global_position = global_position
		zone.configure_hazard(pool_cfg)

## Enforces MAX_PLAYER_POOLS: if the "player_pools" group (Acid Cannon pools, hurts_player:false)
## is already at cap, frees the OLDEST member (group order == spawn order) before a new one
## spawns, so player-placed pools can't accumulate without bound the way enemy/world hazards
## are already capped in Destructible._die() (MAX_HAZARD_ZONES).
func _cap_player_pools() -> void:
	var pools := get_tree().get_nodes_in_group("player_pools")
	if pools.size() >= GameConfig.MAX_PLAYER_POOLS:
		var oldest = pools[0]
		if is_instance_valid(oldest):
			# queue_free is DEFERRED — the node would stay in the group for the rest of the
			# frame, so a same-frame multishot detonation would recount this corpse and
			# "evict" it again (a no-op) while still adding a fresh zone, drifting past the
			# cap. Leave the group immediately so every same-frame recount is accurate.
			oldest.remove_from_group("player_pools")
			oldest.queue_free()

## Detonate (if a shell) then free. Used at every end-of-life exit.
func _expire() -> void:
	if _is_shell():
		_detonate()
	queue_free()

## Nearest unhit enemy with a clear line of sight. Picks nearest-by-distance first (zero
## raycasts), then LoS-checks only that candidate; on failure falls through to the next-nearest,
## until one passes or none remain. Same final pick as a brute-force "LoS-check everyone, keep
## the nearest passing one" — just far fewer raycasts once most candidates are already hit.
func _nearest_unhit_enemy() -> Node2D:
	var space := get_world_2d().direct_space_state
	var candidates: Array = []
	for z in get_tree().get_nodes_in_group("enemies"):
		if z in _hit:
			continue
		var node := z as Node2D
		candidates.append([global_position.distance_squared_to(node.global_position), node])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for pair in candidates:
		var node: Node2D = pair[1]
		if LineOfSight.is_clear(global_position, node.global_position, space):
			return node
	return null

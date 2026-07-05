class_name Gun
extends Node2D
## Fires bullets on an interval in the direction the Player is aiming
## (aim_direction, set externally each frame — the player's last-faced direction).
## Holds mutable per-run stats that gun upgrade cards modify.

@export var bullet_scene: PackedScene

# Mutable per-run stats (start from config, raised by gun upgrade cards).
var damage := GameConfig.BULLET_DAMAGE
var fire_interval := GameConfig.GUN_FIRE_INTERVAL
var bullet_speed := GameConfig.BULLET_SPEED
var gun_range := GameConfig.GUN_RANGE
var projectile_count := 1
var spread := 0.0                  # total fan arc in radians across the projectiles
var fire_mode := "projectile"      # "projectile" (default) | "cone" | "lightning"
var base_pierce := 0               # pierce baked into every shot (Nail Gun)
var cone_angle := 1.05             # cone mode: total arc in radians (~60°)
var jump_count := 0                # lightning mode: max arcs after the first hit
var jump_radius := 320.0           # lightning mode: max px to the next arc target
var jump_falloff := 0.8            # lightning mode: damage x this per jump
var explode_radius := 0.0          # explosive shell blast radius (Grenade Launcher)
var explode_force := 0.0           # explosive shell knockback force
var pool_family := ""              # hazard-pool shell kind ("" = none; "acid" = Acid Cannon)
var pool_radius := 90.0
var pool_duration := 3.0
var pool_slow := 0.0
var pool_slow_dur := 0.0
var pool_dps := 0.0                # pool damage/sec at BASE damage (0 = pool dps just equals live damage)
var impact_frac := 0.0             # shells: fraction of damage dealt to the directly-hit enemy (0 = none)
var _base_damage := 0.0            # def damage before loot/cards — anchors ratio-scaled derived stats
var beam_width := 28.0             # beam mode: half-corridor width (px)

# Talent payload carried onto every bullet (raised by weapon talent cards).
var pierce_count := 0
var ricochet_count := 0
var incendiary := false
var burn_dps := 0.0
var burn_duration := 0.0
var pin_chance := 0.0              # Nail Gun: chance per hit to root the enemy (0 = none)
var pin_dur := 0.0                 # Nail Gun: pin (root) duration in seconds

# Magazine / reload (Spec 2). reload_mult is NOT reset by configure (perks apply after it).
var mag_size := 12
var reload_time := 1.1
var reload_mult := 1.0
var _ammo := 12
var _reloading := false
var _reload_timer := 0.0

var weapon_id := "pistol"         # which Weapons def is equipped (drives the talent pool)

# Weapon-loot identity (set by apply_loot; 0/"" when firing a plain base weapon).
var loot_rarity := 0
var loot_name := ""
var talent_payload := {}           # resolved active-talent effects (see TalentEngine)
var _frenzy_mult := 0.0            # Bloodrush fire-rate surge (fraction; 0 = none)
var _frenzy_time := 0.0
var _surge_pierce := 0             # Overflow: bonus pierce on the next shots
var _surge_shots := 0              # Overflow: extra pellets on the next shots
var _surge_time := 0.0
var _reload_nova := {}             # Backblast: {dmg, radius} resolved from talent_payload; {} = none
var _overpen := {}                 # Railbreaker: {pierce, growth} from talent_payload; {} = none

const MUZZLE_TIME := 0.05         # seconds the muzzle flash stays visible per shot

var _cooldown := 0.0
var _muzzle: Sprite2D
var _muzzle_time := 0.0

## Fire direction, set by the Player each frame (the last-faced / last-move
## direction). Vector2.ZERO means "no aim yet" — the gun holds fire.
var aim_direction := Vector2.ZERO

## Set by the Player each frame: true while moving, or before the first move input.
## When true the gun holds fire without consuming the cooldown (the "shoot only
## while standing still" rule).
var hold_fire := false

func _ready() -> void:
	_muzzle = Sprite2D.new()
	_muzzle.texture = preload("res://art/muzzle.png")
	_muzzle.scale = Vector2(0.75, 0.75)
	_muzzle.z_index = 1            # above the player sprite
	_muzzle.visible = false
	add_child(_muzzle)

## Loads a weapon definition from Weapons.all() as this gun's base stats.
func configure(def: Dictionary) -> void:
	weapon_id = String(def["id"])
	damage = float(def["damage"])
	_base_damage = damage
	fire_interval = float(def["fire_interval"])
	bullet_speed = float(def["bullet_speed"])
	gun_range = float(def["range"])
	projectile_count = int(def["projectiles"])
	spread = float(def["spread"])
	mag_size = int(def["mag_size"])
	reload_time = float(def["reload_time"])
	fire_mode = String(def.get("fire_mode", "projectile"))
	base_pierce = int(def.get("base_pierce", 0))
	cone_angle = float(def.get("cone_angle", 1.05))
	jump_count = int(def.get("jump_count", 0))
	jump_radius = float(def.get("jump_radius", 320.0))
	jump_falloff = float(def.get("jump_falloff", 0.8))
	explode_radius = float(def.get("explode_radius", 0.0))
	explode_force = float(def.get("explode_force", 0.0))
	pool_family = String(def.get("pool", ""))
	pool_radius = float(def.get("pool_radius", 90.0))
	pool_duration = float(def.get("pool_duration", 3.0))
	pool_slow = float(def.get("pool_slow", 0.0))
	pool_slow_dur = float(def.get("pool_slow_dur", 0.0))
	pool_dps = float(def.get("pool_dps", 0.0))
	impact_frac = float(def.get("impact_frac", 0.0))
	beam_width = float(def.get("beam_width", 28.0))
	pin_chance = float(def.get("pin_chance", 0.0))
	pin_dur = float(def.get("pin_dur", 0.0))
	_ammo = mag_size
	_reloading = false
	_reload_timer = 0.0

## Applies a rolled loot instance's stats ON TOP of the already-configured base weapon.
## Reuses the per-run upgrade_* hooks so loot and upgrade cards share one stat path.
## Call right after configure(), before Characters.apply_weapon().
func apply_loot(inst: Dictionary) -> void:
	if inst.is_empty():
		return
	loot_rarity = int(inst.get("rarity", 0))
	loot_name = WeaponInstance.display_name(inst)
	var stats := WeaponInstance.resolved_stats(inst)
	for stat_id in stats:
		var v: float = stats[stat_id]
		match stat_id:
			"damage": upgrade_damage(v / 100.0)
			"fire_rate": upgrade_fire_rate(v / 100.0)
			"bullet_speed": upgrade_bullet_speed(v / 100.0)
			"range": upgrade_range(v / 100.0)
			"reload": upgrade_reload_speed(v / 100.0)
			"mag": upgrade_mag_size(v / 100.0)
			"multishot": upgrade_add_projectile(int(v))
			"pierce": upgrade_pierce(int(v))
			"ricochet": upgrade_ricochet(int(v))
	# Resolve the talents unlocked at this weapon's level into a per-shot combat payload.
	talent_payload = TalentEngine.resolve_payload(WeaponInstance.active_talents(inst))
	_reload_nova = talent_payload.get("reload_nova", {})
	_overpen = talent_payload.get("overpen", {})
	_ammo = mag_size   # start the run with a full (boosted) magazine

## Talent (Bloodrush): temporary fire-rate surge, refreshed on each kill.
func add_frenzy(pct: float, duration: float) -> void:
	_frenzy_mult = maxf(_frenzy_mult, pct)
	_frenzy_time = maxf(_frenzy_time, duration)

## Talent (Overflow): a kill grants bonus pierce + extra pellets to the next shots.
func add_surge(pierce: int, shots: int, duration: float) -> void:
	_surge_pierce = maxi(_surge_pierce, pierce)
	_surge_shots = maxi(_surge_shots, shots)
	_surge_time = maxf(_surge_time, duration)

func _process(delta: float) -> void:
	_fade_muzzle(delta)
	if _frenzy_time > 0.0:
		_frenzy_time -= delta

	if _surge_time > 0.0:
		_surge_time -= delta
		if _surge_time <= 0.0:
			_surge_pierce = 0
			_surge_shots = 0

	# aim_direction is set by the Player each frame (the last-faced direction).
	# The gun no longer picks targets — it fires where the player is looking.

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
			if not _reload_nova.is_empty():
				TalentEngine.detonate(global_position, float(_reload_nova.get("dmg", 0.0)), float(_reload_nova.get("radius", 0.0)), get_tree())
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if fire_mode == "projectile" and bullet_scene == null:
		return

	# Hold fire while moving (stop-to-shoot) or before the player has aimed.
	if hold_fire or aim_direction == Vector2.ZERO:
		return

	if not _fire(aim_direction):
		return                      # no shot happened (e.g. Tesla with no target) — don't waste ammo/cooldown
	_cooldown = (fire_interval * (1.0 - _frenzy_mult)) if _frenzy_time > 0.0 else fire_interval
	_ammo -= 1
	if _ammo <= 0:
		_start_reload()

func _start_reload() -> void:
	_reloading = true
	_reload_timer = maxf(reload_time * reload_mult, GameConfig.RELOAD_TIME_FLOOR)

## Instantly finish any reload and refill the magazine (Ryan Ace's AK dash perk).
func instant_reload() -> void:
	_reloading = false
	_reload_timer = 0.0
	_ammo = mag_size

# --- Read access for the HUD (keeps magazine state private) ---
func ammo() -> int:
	return _ammo

func is_reloading() -> bool:
	return _reloading

func reload_progress() -> float:
	var dur := maxf(reload_time * reload_mult, GameConfig.RELOAD_TIME_FLOOR)
	return clampf(1.0 - _reload_timer / dur, 0.0, 1.0)

func _fire(dir: Vector2) -> bool:
	match fire_mode:
		"cone":      return _fire_cone(dir)
		"lightning": return _fire_lightning(dir)
		"beam":      return _fire_beam(dir)
		_:           return _fire_projectile(dir)
	return false  # unreachable; satisfies the static checker

func _fire_projectile(dir: Vector2) -> bool:
	var base_angle := dir.angle()
	_show_muzzle(base_angle)
	var count: int = projectile_count + (_surge_shots if _surge_time > 0.0 else 0)
	if count <= 1:
		var jitter: float = randf_range(-spread, spread) if spread > 0.0 else 0.0
		_spawn_bullet(Vector2.from_angle(base_angle + jitter))
		return true
	# Fan pellets evenly across the spread arc (force a small fan if a 1-shot gun gained pellets).
	var arc: float = maxf(spread, 0.20)
	for i in count:
		var t := float(i) / float(count - 1)
		var offset := lerpf(-arc * 0.5, arc * 0.5, t)
		_spawn_bullet(Vector2.from_angle(base_angle + offset))
	return true

## Pops the muzzle flash at the gun's muzzle, oriented along the shot.
func _show_muzzle(angle: float) -> void:
	if _muzzle == null:
		return
	_muzzle.position = Vector2.from_angle(angle) * 22.0
	_muzzle.rotation = angle
	_muzzle.modulate = Color(1, 1, 1, 1)
	_muzzle.visible = true
	_muzzle_time = MUZZLE_TIME

## Fades the muzzle flash out over MUZZLE_TIME; runs every frame regardless of fire state.
func _fade_muzzle(delta: float) -> void:
	if _muzzle == null or _muzzle_time <= 0.0:
		return
	_muzzle_time -= delta
	var c := _muzzle.modulate
	c.a = clampf(_muzzle_time / MUZZLE_TIME, 0.0, 1.0)
	_muzzle.modulate = c
	if _muzzle_time <= 0.0:
		_muzzle.visible = false

func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = damage
	bullet.max_travel = gun_range
	bullet.pierce_count = pierce_count + base_pierce + (_surge_pierce if _surge_time > 0.0 else 0) + int(_overpen.get("pierce", 0))
	bullet.overpen_growth = float(_overpen.get("growth", 0.0))
	bullet.ricochet_count = ricochet_count
	bullet.talent_payload = talent_payload
	bullet.talent_player = get_parent() as Player
	if incendiary:
		bullet.incendiary = true
		bullet.burn_dps = burn_dps
		bullet.burn_duration = burn_duration
	bullet.explode_radius = explode_radius
	bullet.explode_force = explode_force
	bullet.impact_frac = impact_frac
	bullet.pin_chance = pin_chance
	bullet.pin_dur = pin_dur
	if pool_family != "":
		bullet.pool_cfg = _build_pool_cfg()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

## Build the enemy-only HazardZone config for a pool-dropping shell (Acid Cannon).
## Pool dps is its own def stat (pool_dps), scaled by the gun's live/base damage ratio
## so damage cards & affixes still grow the pool — but shell hit and pool tune apart.
func _build_pool_cfg() -> Dictionary:
	var color = Hazards.GREEN if pool_family == "acid" else Hazards.ORANGE
	var dps := damage
	if pool_dps > 0.0 and _base_damage > 0.0:
		dps = pool_dps * (damage / _base_damage)
	return {
		"color": color, "dps": dps, "radius": pool_radius, "duration": pool_duration,
		"slow": pool_slow, "slow_dur": pool_slow_dur, "stun": 0.0, "chain": 0,
		"drift": 0.0, "hurts_player": false,
	}

# --- Upgrade hooks (called by Upgrades.apply) ---
func upgrade_damage(pct: float) -> void:
	damage *= (1.0 + pct)

func upgrade_fire_rate(pct: float) -> void:
	fire_interval *= (1.0 - pct)   # smaller interval = faster firing

func upgrade_bullet_speed(pct: float) -> void:
	bullet_speed *= (1.0 + pct)

func upgrade_range(pct: float) -> void:
	gun_range *= (1.0 + pct)

func upgrade_add_projectile(n: int) -> void:
	if fire_mode == "lightning":
		jump_count += n               # "+1 projectile" card = "+1 jump" for the Tesla
		return
	projectile_count += n
	if spread <= 0.0:               # give single-shot guns a small fan once they multi-fire
		spread = 0.20

func upgrade_reduce_spread(pct: float) -> void:
	spread *= (1.0 - pct)

func upgrade_pierce(n: int) -> void:
	pierce_count += n

func upgrade_ricochet(n: int) -> void:
	ricochet_count += n

func upgrade_incendiary(dps: float, duration: float) -> void:
	incendiary = true
	burn_dps += dps
	burn_duration = maxf(burn_duration, duration)

func upgrade_reload_speed(pct: float) -> void:
	reload_mult *= (1.0 - pct)        # smaller mult = faster reload

func upgrade_mag_size(pct: float) -> void:
	mag_size = int(ceil(mag_size * (1.0 + pct)))   # ceil so small mags still gain >= 1

func _fire_lightning(dir: Vector2) -> bool:
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	# Barrels/props conduct too — the bolt can target and arc through destructibles (raw damage,
	# no talents), so a torched barrel bursts via its own _die. Appended without LoS, like the cone.
	var conductors: Array = enemies.duplicate()
	conductors.append_array(get_tree().get_nodes_in_group("destructibles"))
	var first := _nearest_enemy(global_position, gun_range, conductors)  # gun_range governs initial target acquisition only; chain hops use jump_radius
	if first == null:
		return false
	_show_muzzle(dir.angle())
	var chain := _chain_targets(first, jump_count, jump_radius, conductors)
	var player := get_parent() as Player
	var points: Array = [global_position]
	var dmg := damage
	for e in chain:
		if not is_instance_valid(e):
			continue
		points.append(e.global_position)
		var hit_pos: Vector2 = e.global_position
		if not e.is_in_group("enemies"):
			if e.has_method("take_damage"):
				e.take_damage(dmg)            # destructible link: raw damage, no talents/crit
			dmg *= jump_falloff
			continue
		var was_alive: bool = e.has_method("health_fraction") and e.health_fraction() > 0.0
		var roll := TalentEngine.roll_damage(dmg, talent_payload)
		e.take_damage(float(roll["damage"]))
		var killed: bool = was_alive and e.health_fraction() <= 0.0   # alive->dead transition; corpse hits are non-events
		if was_alive and not killed and e.has_method("flash_hit"):
			e.flash_hit()
		if was_alive and not talent_payload.is_empty():
			TalentEngine.process_hit(e, hit_pos, dmg, killed, talent_payload, {
				"player": player, "gun": self, "dir": dir, "tree": get_tree(),
			})
		dmg *= jump_falloff
	_spawn_lightning(points)
	return true

func _spawn_lightning(points: Array) -> void:
	if points.size() < 2:
		return
	var bolt := Lightning.new()
	bolt.points = points
	get_tree().current_scene.add_child(bolt)

func _fire_beam(dir: Vector2) -> bool:
	_show_muzzle(dir.angle())
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	var hits := _enemies_in_beam(global_position, dir, gun_range, beam_width, enemies)
	var player := get_parent() as Player
	for e in hits:
		if not is_instance_valid(e):
			continue
		var hit_pos: Vector2 = e.global_position
		var was_alive: bool = e.has_method("health_fraction") and e.health_fraction() > 0.0
		var roll := TalentEngine.roll_damage(damage, talent_payload)
		e.take_damage(float(roll["damage"]))
		var killed: bool = was_alive and e.health_fraction() <= 0.0   # alive->dead transition; corpse hits are non-events
		if was_alive and not killed:
			if e.has_method("flash_hit"):
				e.flash_hit()
			if incendiary and e.has_method("ignite"):
				e.ignite(burn_dps, burn_duration)
		if was_alive and not talent_payload.is_empty():
			TalentEngine.process_hit(e, hit_pos, damage, killed, talent_payload, {
				"player": player, "gun": self, "dir": dir, "tree": get_tree(),
			})
	# Destructibles in the beam corridor take raw damage too (barrels burst). Same geometry,
	# no talents — matches the flame cone / a bullet hit.
	for d in _enemies_in_beam(global_position, dir, gun_range, beam_width, get_tree().get_nodes_in_group("destructibles")):
		if is_instance_valid(d) and d.has_method("take_damage"):
			d.take_damage(damage)
	_spawn_beam(dir)
	return true

func _spawn_beam(dir: Vector2) -> void:
	var beam := Beam.new()
	beam.start = global_position
	beam.end = global_position + dir * gun_range
	get_tree().current_scene.add_child(beam)

func _fire_cone(dir: Vector2) -> bool:
	_show_muzzle(dir.angle())
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	var hits := _enemies_in_cone(global_position, dir, gun_range, cone_angle * 0.5, enemies)
	var player := get_parent() as Player
	var bdps := maxf(GameConfig.FLAME_BURN_DPS, burn_dps)      # base burn, strengthened by incendiary upgrades
	var btime := maxf(GameConfig.FLAME_BURN_TIME, burn_duration)
	for e in hits:
		if not is_instance_valid(e):
			continue
		var hit_pos: Vector2 = e.global_position
		var was_alive: bool = e.has_method("health_fraction") and e.health_fraction() > 0.0
		var roll := TalentEngine.roll_damage(damage, talent_payload)
		e.take_damage(float(roll["damage"]))
		var killed: bool = was_alive and e.health_fraction() <= 0.0   # alive->dead transition; corpse hits are non-events
		if was_alive and not killed:
			if e.has_method("flash_hit"):
				e.flash_hit()
			if e.has_method("ignite"):
				e.ignite(bdps, btime)
		if was_alive and not talent_payload.is_empty():
			TalentEngine.process_hit(e, hit_pos, damage, killed, talent_payload, {
				"player": player, "gun": self, "dir": dir, "tree": get_tree(),
			})
	# The flame also scorches destructibles (barrels, drums, crates, cover) caught in the cone
	# — raw damage like a bullet hit (no talents; a torched barrel still bursts via its own
	# _die). Reuses the cone geometry on the destructibles group.
	for d in _enemies_in_cone(global_position, dir, gun_range, cone_angle * 0.5, get_tree().get_nodes_in_group("destructibles")):
		if is_instance_valid(d) and d.has_method("take_damage"):
			d.take_damage(damage)
	_spawn_flame(dir)
	return true

func _spawn_flame(dir: Vector2) -> void:
	var flame := FlameCone.new()
	flame.aim = dir
	flame.length = gun_range
	flame.half_angle = cone_angle * 0.5
	get_tree().current_scene.add_child(flame)
	flame.global_position = global_position

# --- Lightning targeting (static + pure so probes can verify selection headlessly) ---

## Nearest enemy to `origin` within `max_range`. null if none.
static func _nearest_enemy(origin: Vector2, max_range: float, enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_d := max_range * max_range
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var d: float = origin.distance_squared_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best

## Ordered arc chain starting at `first`: each next jump goes to the nearest
## not-yet-chained enemy within `jump_radius`, up to `jump_count` extra jumps.
static func _chain_targets(first: Node2D, jump_count: int, jump_radius: float, enemies: Array) -> Array:
	var chain: Array = [first]
	var current := first
	var r2 := jump_radius * jump_radius
	for _i in jump_count:
		var best: Node2D = null
		var best_d := r2
		for e in enemies:
			if e == null or not is_instance_valid(e) or e in chain:
				continue
			var d: float = current.global_position.distance_squared_to(e.global_position)
			if d <= best_d:
				best_d = d
				best = e
		if best == null:
			break
		chain.append(best)
		current = best
	return chain

## Pure geometry: is world point `p` inside the beam corridor from `origin` along `dir`?
static func _beam_contains(origin: Vector2, dir: Vector2, max_range: float, half_width: float, p: Vector2) -> bool:
	var d := dir.normalized()
	var to := p - origin
	var along := to.dot(d)
	if along < 0.0 or along > max_range:
		return false
	return absf(to.dot(d.orthogonal())) <= half_width

## Every enemy inside the beam corridor. Static + pure (delegates to _beam_contains) so a
## probe can verify selection headlessly.
static func _enemies_in_beam(origin: Vector2, dir: Vector2, max_range: float, half_width: float, enemies: Array) -> Array:
	var hits: Array = []
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if _beam_contains(origin, dir, max_range, half_width, (e as Node2D).global_position):
			hits.append(e)
	return hits

## Every enemy within `max_range` of `origin` and within `half_angle` rad of `dir`.
## Static + pure so probes can verify the cone shape headlessly.
static func _enemies_in_cone(origin: Vector2, dir: Vector2, max_range: float, half_angle: float, enemies: Array) -> Array:
	var hits: Array = []
	var r2 := max_range * max_range
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		var to: Vector2 = e.global_position - origin
		if to.length_squared() > r2:
			continue
		if absf(dir.angle_to(to)) <= half_angle:
			hits.append(e)
	return hits

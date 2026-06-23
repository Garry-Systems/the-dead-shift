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

# Talent payload carried onto every bullet (raised by weapon talent cards).
var pierce_count := 0
var ricochet_count := 0
var incendiary := false
var burn_dps := 0.0
var burn_duration := 0.0

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

	_fire(aim_direction)
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

func _fire(dir: Vector2) -> void:
	match fire_mode:
		"cone":      _fire_cone(dir)
		"lightning": _fire_lightning(dir)
		_:           _fire_projectile(dir)

func _fire_projectile(dir: Vector2) -> void:
	var base_angle := dir.angle()
	_show_muzzle(base_angle)
	var count: int = projectile_count + (_surge_shots if _surge_time > 0.0 else 0)
	if count <= 1:
		var jitter: float = randf_range(-spread, spread) if spread > 0.0 else 0.0
		_spawn_bullet(Vector2.from_angle(base_angle + jitter))
		return
	# Fan pellets evenly across the spread arc (force a small fan if a 1-shot gun gained pellets).
	var arc: float = maxf(spread, 0.20)
	for i in count:
		var t := float(i) / float(count - 1)
		var offset := lerpf(-arc * 0.5, arc * 0.5, t)
		_spawn_bullet(Vector2.from_angle(base_angle + offset))

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
	bullet.pierce_count = pierce_count + (_surge_pierce if _surge_time > 0.0 else 0) + int(_overpen.get("pierce", 0))
	bullet.overpen_growth = float(_overpen.get("growth", 0.0))
	bullet.ricochet_count = ricochet_count
	bullet.talent_payload = talent_payload
	bullet.talent_player = get_parent() as Player
	if incendiary:
		bullet.incendiary = true
		bullet.burn_dps = burn_dps
		bullet.burn_duration = burn_duration
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

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

# Stub functions for fire modes added in later tasks
func _fire_cone(dir: Vector2) -> void:
	pass

func _fire_lightning(dir: Vector2) -> void:
	pass

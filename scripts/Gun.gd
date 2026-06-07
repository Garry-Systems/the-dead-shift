class_name Gun
extends Node2D
## Auto-targets the nearest enemy in range and fires bullets on an interval.
## Holds mutable per-run stats that gun upgrade cards modify.

@export var bullet_scene: PackedScene

# Mutable per-run stats (start from config, raised by gun upgrade cards).
var damage := GameConfig.BULLET_DAMAGE
var fire_interval := GameConfig.GUN_FIRE_INTERVAL
var bullet_speed := GameConfig.BULLET_SPEED
var gun_range := GameConfig.GUN_RANGE
var projectile_count := 1
var spread := 0.0                  # total fan arc in radians across the projectiles

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

const MUZZLE_TIME := 0.05         # seconds the muzzle flash stays visible per shot

var _cooldown := 0.0
var _muzzle: Sprite2D
var _muzzle_time := 0.0

func _ready() -> void:
	_muzzle = Sprite2D.new()
	_muzzle.texture = preload("res://art/muzzle.png")
	_muzzle.scale = Vector2(1.5, 1.5)
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
	_ammo = mag_size
	_reloading = false
	_reload_timer = 0.0

func _process(delta: float) -> void:
	_fade_muzzle(delta)

	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
		return

	_cooldown -= delta
	if _cooldown > 0.0 or bullet_scene == null:
		return

	var target := _find_nearest_enemy()
	if target == null:
		return

	_fire((target.global_position - global_position).normalized())
	_cooldown = fire_interval
	_ammo -= 1
	if _ammo <= 0:
		_start_reload()

func _start_reload() -> void:
	_reloading = true
	_reload_timer = maxf(reload_time * reload_mult, GameConfig.RELOAD_TIME_FLOOR)

# --- Read access for the HUD (keeps magazine state private) ---
func ammo() -> int:
	return _ammo

func is_reloading() -> bool:
	return _reloading

func reload_progress() -> float:
	var dur := maxf(reload_time * reload_mult, GameConfig.RELOAD_TIME_FLOOR)
	return clampf(1.0 - _reload_timer / dur, 0.0, 1.0)

func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var points: Array[Vector2] = []
	for z in enemies:
		points.append((z as Node2D).global_position)

	var idx := TargetSelector.nearest_index_in_range(global_position, points, gun_range)
	if idx < 0:
		return null
	return enemies[idx] as Node2D

func _fire(dir: Vector2) -> void:
	var base_angle := dir.angle()
	_show_muzzle(base_angle)
	if projectile_count <= 1:
		var jitter: float = randf_range(-spread, spread) if spread > 0.0 else 0.0
		_spawn_bullet(Vector2.from_angle(base_angle + jitter))
		return
	# Fan multiple pellets evenly across the spread arc, centered on the aim.
	for i in projectile_count:
		var t := float(i) / float(projectile_count - 1)
		var offset := lerpf(-spread * 0.5, spread * 0.5, t)
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
	bullet.pierce_count = pierce_count
	bullet.ricochet_count = ricochet_count
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

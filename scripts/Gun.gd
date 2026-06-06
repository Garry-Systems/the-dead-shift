class_name Gun
extends Node2D
## Auto-targets the nearest zombie in range and fires bullets on an interval.
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

var weapon_id := "pistol"         # which Weapons def is equipped (drives the talent pool)

var _cooldown := 0.0

## Loads a weapon definition from Weapons.all() as this gun's base stats.
func configure(def: Dictionary) -> void:
	weapon_id = String(def["id"])
	damage = float(def["damage"])
	fire_interval = float(def["fire_interval"])
	bullet_speed = float(def["bullet_speed"])
	gun_range = float(def["range"])
	projectile_count = int(def["projectiles"])
	spread = float(def["spread"])

func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0 or bullet_scene == null:
		return

	var target := _find_nearest_zombie()
	if target == null:
		return

	_fire((target.global_position - global_position).normalized())
	_cooldown = fire_interval

func _find_nearest_zombie() -> Node2D:
	var zombies := get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty():
		return null

	var points: Array[Vector2] = []
	for z in zombies:
		points.append((z as Node2D).global_position)

	var idx := TargetSelector.nearest_index_in_range(global_position, points, gun_range)
	if idx < 0:
		return null
	return zombies[idx] as Node2D

func _fire(dir: Vector2) -> void:
	var base_angle := dir.angle()
	if projectile_count <= 1:
		var jitter: float = randf_range(-spread, spread) if spread > 0.0 else 0.0
		_spawn_bullet(Vector2.from_angle(base_angle + jitter))
		return
	# Fan multiple pellets evenly across the spread arc, centered on the aim.
	for i in projectile_count:
		var t := float(i) / float(projectile_count - 1)
		var offset := lerpf(-spread * 0.5, spread * 0.5, t)
		_spawn_bullet(Vector2.from_angle(base_angle + offset))

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

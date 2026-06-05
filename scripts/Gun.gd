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

var _cooldown := 0.0

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
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = damage
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

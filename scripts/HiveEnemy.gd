class_name HiveEnemy
extends Enemy
## A stationary "hive": doesn't chase (its registry spd_mult is 0 -> move_speed 0).
## Periodically births shambler enemies near itself, up to a lifetime cap, so it forces a
## priority kill. High HP. Inherits all of Enemy's health / flash / status / gem behavior.

# Same lazy-load rule as Enemy.runner_scene() (v0.1.77): Enemy.tscn's script is Enemy.gd, which
# THIS script extends, so preloading it here loads a scene whose script is our own base class
# while that base is still compiling. Lazy load keeps the hive out of the loader cycle.
static var _shambler_scene: PackedScene

## The shambler scene, loaded once on the hive's first birth and cached.
static func shambler_scene() -> PackedScene:
	if _shambler_scene == null:
		_shambler_scene = load("res://scenes/Enemy.tscn")
	return _shambler_scene

var _spawn_cd := 0.0
var _brood_spawned := 0

func _ready() -> void:
	super._ready()
	_spawn_cd = GameConfig.HIVE_SPAWN_INTERVAL

## Birth shamblers on a cooldown, capped. (Movement is 0 via its near-zero move_speed.)
func _act(delta: float) -> void:
	if _brood_spawned >= GameConfig.HIVE_MAX_BROOD:
		return
	_spawn_cd -= delta
	if _spawn_cd > 0.0:
		return
	_spawn_cd = GameConfig.HIVE_SPAWN_INTERVAL
	for i in GameConfig.HIVE_SPAWN_COUNT:
		if _brood_spawned >= GameConfig.HIVE_MAX_BROOD:
			break
		_spawn_one()

func _spawn_one() -> void:
	var baby = shambler_scene().instantiate()
	baby.configure(DifficultyManager.enemy_stats())
	get_tree().current_scene.add_child(baby)
	baby.global_position = global_position + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
	_brood_spawned += 1

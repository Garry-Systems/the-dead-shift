extends Node2D
## Spawns enemies on a ring around the player. Spawn rate + enemy stats scale with the
## wave (via DifficultyManager). On every Nth wave it also spawns one boss; while a boss
## is alive, normal spawns slow to BOSS_SPAWN_RATE_MULT of their rate.

@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene
var _player: Node2D
var _timer := 0.0
var _last_boss_wave := 0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if _player == null or enemy_scene == null:
		return

	_check_boss()

	_timer += delta
	var interval := DifficultyManager.spawn_interval()
	if _boss_alive():
		interval /= GameConfig.BOSS_SPAWN_RATE_MULT   # mult 0.5 -> interval doubles -> fewer
	if _timer < interval:
		return
	_timer = 0.0
	_spawn_enemy()

func _check_boss() -> void:
	var w := DifficultyManager.wave
	if w % GameConfig.BOSS_WAVE_INTERVAL != 0:
		return
	if w == _last_boss_wave or _boss_alive():
		return
	_last_boss_wave = w
	_spawn_boss()

func _boss_alive() -> bool:
	return get_tree().get_first_node_in_group("boss") != null

func _spawn_enemy() -> void:
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var enemy = enemy_scene.instantiate()
	enemy.configure(DifficultyManager.enemy_stats())
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _player.global_position + offset

func _spawn_boss() -> void:
	if boss_scene == null:
		return
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var boss = boss_scene.instantiate()
	boss.configure(DifficultyManager.boss_stats())
	get_tree().current_scene.add_child(boss)
	boss.global_position = _player.global_position + offset

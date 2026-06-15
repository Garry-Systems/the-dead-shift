extends Node2D
## Spawns enemies/bosses. Behavior depends on `mode` (set by Main.gd from RunConfig):
##  - "endless": time-based difficulty waves + a boss every BOSS_WAVE_INTERVAL waves.
##  - "boss_rush": no trash enemies; one boss at a time, back-to-back, each scaled by
##    its boss number.

@export var enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene   # "spitter"; mixed in from RANGED_ENEMY_MIN_WAVE

var mode := "endless"
var boss_rush_count := 0      # bosses spawned so far in boss_rush (drives scaling + HUD)

var _player: Node2D
var _timer := 0.0
var _last_boss_wave := 0
var _last_boss_id := ""

func _ready() -> void:
	add_to_group("spawner")
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if _player == null:
		return
	if mode == "boss_rush":
		_process_boss_rush()
		return
	_process_endless(delta)

# --- Endless ---
func _process_endless(delta: float) -> void:
	if enemy_scene == null:
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
	_spawn_boss(DifficultyManager.boss_stats())

# --- Boss Rush ---
func _process_boss_rush() -> void:
	if _boss_alive():
		return
	boss_rush_count += 1
	_spawn_boss(DifficultyCurve.boss_stats(boss_rush_count))

# --- shared ---
func _boss_alive() -> bool:
	return get_tree().get_first_node_in_group("boss") != null

func _spawn_enemy() -> void:
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	# Pick a trash enemy type from the registry (wave-gated + weighted) and bake its scaled stats.
	var entry := Enemies.pick(DifficultyManager.wave)
	var enemy = (entry["scene"] as PackedScene).instantiate()
	enemy.configure(Enemies.stats_for(entry, DifficultyManager.wave))
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _player.global_position + offset

func _spawn_boss(stats: Dictionary) -> void:
	var entry := Bosses.pick(_last_boss_id)
	if entry.is_empty():
		return
	var angle := randf_range(0.0, TAU)
	var offset := Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
	var boss = (entry["scene"] as PackedScene).instantiate()
	boss.configure(stats)
	get_tree().current_scene.add_child(boss)
	boss.global_position = _player.global_position + offset
	_last_boss_id = String(entry["id"])

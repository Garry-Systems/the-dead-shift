extends Node2D
## Spawns enemies/bosses. Behavior depends on `mode` (set by Main.gd from RunConfig):
##  - "endless": time-based difficulty waves + a boss every BOSS_WAVE_INTERVAL waves.
##  - "boss_rush": the trash-enemy slate PLUS always-N bosses on the map at once
##    (BOSS_RUSH_BASE_COUNT, +1 per BOSS_RUSH_LEVELS_PER_BOSS player levels), refilled as
##    they die — so it gets more crowded with bosses the longer you survive.

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
		_process_boss_rush(delta)
		return
	_process_endless(delta)

# --- Endless ---
func _process_endless(delta: float) -> void:
	if Enemies.all().is_empty():
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

# --- Boss Rush: always-N bosses + the trash slate ---
func _process_boss_rush(delta: float) -> void:
	# Keep the map topped up to the target boss count (3, +1 every few player levels),
	# refilling as bosses die.
	var target := GameConfig.BOSS_RUSH_BASE_COUNT + _player_level() / GameConfig.BOSS_RUSH_LEVELS_PER_BOSS
	var alive := get_tree().get_nodes_in_group("boss").size()
	while alive < target:
		boss_rush_count += 1
		_spawn_boss(DifficultyCurve.boss_stats(boss_rush_count))
		alive += 1
	# Trash enemies too, on the normal time-scaled cadence.
	if Enemies.all().is_empty():
		return
	_timer += delta
	if _timer >= DifficultyManager.spawn_interval():
		_timer = 0.0
		_spawn_enemy()

## The player's current level (0 if unavailable) — drives the Boss Rush boss count.
func _player_level() -> int:
	if _player == null or not is_instance_valid(_player):
		return 0
	return int(_player.get("level"))

# --- shared ---
func _boss_alive() -> bool:
	return get_tree().get_first_node_in_group("boss") != null

## A ring position SPAWN_RADIUS from the player, kept out of the forecourt: near the origin a
## blind random angle could drop a spawn INSIDE the store building. Dumb + deterministic — no
## physics queries: re-roll the angle up to 8 times while the candidate is within
## FORECOURT_SPAWN_KEEPOUT of world origin; if all 8 fail (player standing far into the
## keep-out), push the last candidate radially out to the keep-out distance.
func _pick_spawn_pos() -> Vector2:
	var keep2 := GameConfig.FORECOURT_SPAWN_KEEPOUT * GameConfig.FORECOURT_SPAWN_KEEPOUT
	var pos := _player.global_position + Vector2.RIGHT * GameConfig.SPAWN_RADIUS
	for i in 8:
		var angle := randf_range(0.0, TAU)
		pos = _player.global_position + Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
		if pos.distance_squared_to(Vector2.ZERO) >= keep2:
			return pos
	var dir := pos.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir * GameConfig.FORECOURT_SPAWN_KEEPOUT

func _spawn_enemy() -> void:
	# Pick a trash enemy type from the registry (wave-gated + weighted) and bake its scaled stats.
	var entry := Enemies.pick(DifficultyManager.wave)
	var enemy = (entry["scene"] as PackedScene).instantiate()
	enemy.configure(Enemies.stats_for(entry, DifficultyManager.wave))
	_maybe_apply_elite(enemy)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _pick_spawn_pos()

## Elites (Pack A): a wave-gated, capped chance to promote a freshly-configured trash spawn to
## an elite. Endless only — gated HERE (not in Enemy/Enemies) so Boss Rush's call through this
## SAME _spawn_enemy path stays completely untouched, and the Dawn Extraction final surge (which
## multiplies this same chance via DifficultyManager.elite_chance_mult()) only ever matters in
## endless too, since nothing outside endless ever sets that multiplier off 1.0.
func _maybe_apply_elite(enemy) -> void:
	if mode != "endless":
		return
	var chance := DifficultyCurve.elite_chance(DifficultyManager.wave) * DifficultyManager.elite_chance_mult()
	if randf() >= chance:
		return
	const KINDS := ["armored", "volatile", "splitter", "alpha"]
	enemy.apply_elite(KINDS[randi() % KINDS.size()])

func _spawn_boss(stats: Dictionary) -> void:
	var entry := Bosses.pick(_last_boss_id)
	if entry.is_empty():
		return
	var boss = (entry["scene"] as PackedScene).instantiate()
	boss.configure(stats)
	get_tree().current_scene.add_child(boss)
	boss.global_position = _pick_spawn_pos()
	_last_boss_id = String(entry["id"])
	SoundManager.play("boss_roar")

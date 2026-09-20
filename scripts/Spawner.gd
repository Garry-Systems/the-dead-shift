extends Node2D
## Spawns enemies/bosses. Behavior depends on `mode` (set by Main.gd from RunConfig):
##  - "endless": time-based difficulty waves + a boss every BOSS_WAVE_INTERVAL waves.
##  - "boss_rush": the trash-enemy slate PLUS always-N bosses on the map at once
##    (BOSS_RUSH_BASE_COUNT, +1 per BOSS_RUSH_LEVELS_PER_BOSS player levels), refilled as
##    they die — so it gets more crowded with bosses the longer you survive.

var mode := "endless"
var boss_rush_count := 0      # bosses spawned so far in boss_rush (drives scaling + HUD)
var suspended := false   # THE BASEMENT (Pack E): controller pauses surface spawning/scatter while below
var location_spawn_mults: Dictionary = {}   # TRANSFER STORES (Task 2): set once by Main.gd from
# the run's Locations row; passed straight through to Enemies.pick(). {} (forecourt/default) is
# byte-identical to before this pack — see Enemies._weight's mults.is_empty() short-circuit.

var _player: Node2D
var _timer := 0.0
var _last_boss_wave := 0
var _last_boss_id := ""
var _suppress_time := 0.0   # per-boss budget of REVEALED seconds spent suppressing trash spawns:
# accumulates only while the current boss is revealed; HOLDS (no accumulate, no reset) while it's
# alive but concealed (a re-cloak/re-reveal cycle must not grant a fresh 75s); resets to 0.0 only
# once no boss is alive at all (see _process_endless)

func _ready() -> void:
	add_to_group("spawner")
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if suspended:
		return
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
	var revealed := _revealed_boss_alive()
	if revealed:
		_suppress_time += delta
	elif not _boss_alive():
		_suppress_time = 0.0   # no boss at all -- next boss gets a fresh budget
	# else: a boss is alive but concealed (e.g. Mystery Shopper between reveals) -- HOLD, don't
	# reset: a re-cloak/re-reveal cycle must not grant her a fresh 75s (fix round 1).
	if suppression_active(_suppress_time, revealed):
		interval /= GameConfig.BOSS_SPAWN_RATE_MULT   # mult 0.5 -> interval doubles -> fewer
	if _timer < interval:
		return
	_timer = 0.0
	_spawn_enemy()

## Trash runs at BOSS_SPAWN_RATE_MULT only while the CURRENT boss has spent fewer than
## BOSS_SUPPRESS_MAX_SECONDS revealed (Power Curve, per-boss budget — see _suppress_time): the
## slowdown clears room for a duel; it must not reward keeping a boss alive (or, for a
## concealed/re-cloaking boss, keeping it un-killed) as a pet. The boss still blocks the next
## boss spawn either way (see _check_boss).
static func suppression_active(suppress_time: float, revealed_boss_alive: bool) -> bool:
	return revealed_boss_alive and suppress_time < GameConfig.BOSS_SUPPRESS_MAX_SECONDS

func _check_boss() -> void:
	if mode == "horde":
		return   # HORDE NIGHT (Pack G): no boss ever spawns — spawn interval instead runs faster (see Main._ready)
	var w := DifficultyManager.wave
	if w % GameConfig.BOSS_WAVE_INTERVAL != 0:
		return
	if w == _last_boss_wave or _boss_alive():
		return
	_last_boss_wave = w
	var stats := DifficultyManager.boss_stats()
	stats["max_health"] = float(stats["max_health"]) * first_boss_hp_mult(w, RunConfig.probation)
	_spawn_boss(stats)

## Probation (Survivability): only the FIRST scheduled boss (wave BOSS_WAVE_INTERVAL) is softened.
static func first_boss_hp_mult(wave: int, probation: bool) -> float:
	return GameConfig.PROBATION_FIRST_BOSS_HP_MULT if probation and wave == GameConfig.BOSS_WAVE_INTERVAL else 1.0

# --- Boss Rush: always-N bosses + the trash slate ---
func _process_boss_rush(delta: float) -> void:
	# Keep the map topped up to the target boss count (3, +1 every few player levels),
	# refilling as bosses die.
	var target := GameConfig.BOSS_RUSH_BASE_COUNT + _player_level() / GameConfig.BOSS_RUSH_LEVELS_PER_BOSS
	var alive := get_tree().get_nodes_in_group("boss").size()
	while alive < target:
		boss_rush_count += 1
		# Boss Rush rides its OWN curve (DifficultyCurve.boss_rush_stats off BOSS_RUSH_BASE_HP), not the
		# endless one the power-curve probe tunes — see the comment on boss_rush_stats.
		_spawn_boss(DifficultyCurve.boss_rush_stats(boss_rush_count))
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

## True only when a boss the player can actually SEE is alive. The while-a-boss-lives trash
## slowdown (BOSS_SPAWN_RATE_MULT) exists to clear room for an active duel; a CONCEALED Mystery
## Shopper browsing the horde is not a duel — halving spawns through her browse window just
## empties the store with no boss bar to explain why (the v0.1.69 "where did everyone go" fix).
## _check_boss deliberately still gates on plain _boss_alive(): one boss at a time, concealed
## or not — her reveal must never land on top of a freshly spawned second boss.
func _revealed_boss_alive() -> bool:
	for b in get_tree().get_nodes_in_group("boss"):
		var boss := b as BossBase
		if boss != null and boss.revealed():
			return true
	return false

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
	# TRANSFER STORES (Task 2): location_spawn_mults biases the roll ({} = untouched default).
	# PROBATION (Survivability): RunConfig.probation delays a few ids' arrival ({} mults + false
	# probation is the exact pre-existing code path).
	var entry := Enemies.pick(DifficultyManager.wave, location_spawn_mults, RunConfig.probation)
	var enemy = (entry["scene"] as PackedScene).instantiate()
	enemy.configure(Enemies.stats_for(entry, DifficultyManager.wave))
	_maybe_apply_elite(enemy)
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = _pick_spawn_pos()

## Elites (Pack A): a wave-gated, capped chance to promote a freshly-configured trash spawn to
## an elite. Endless + HORDE NIGHT only (Pack G extended the gate from endless-only to
## endless|horde — horde still rolls elites even though it never spawns a boss) — gated HERE (not
## in Enemy/Enemies) so Boss Rush's call through this SAME _spawn_enemy path stays completely
## untouched, and the Dawn Extraction final surge (which multiplies this same chance via
## DifficultyManager.elite_chance_mult()) only ever matters in endless too, since nothing outside
## endless ever sets that multiplier off 1.0 (Extraction itself is endless-only — see Extraction.gd).
func _maybe_apply_elite(enemy) -> void:
	if mode != "endless" and mode != "horde":   # HORDE NIGHT (Pack G): elites still roll there
		return
	var chance := DifficultyCurve.elite_chance(DifficultyManager.wave, RunConfig.probation) * DifficultyManager.elite_chance_mult()
	# Pack C (Daily Shift): both rolls go through RunConfig.rand_float()/rand_int(), which only
	# diverge from the plain global randf()/randi() while a Daily Shift run is active.
	if RunConfig.rand_float() >= chance:
		return
	const KINDS := ["armored", "volatile", "splitter", "alpha"]
	var kind: String = KINDS[RunConfig.rand_int() % KINDS.size()]
	# Exploders never roll Volatile: their own instant _detonate would stack with the fused
	# volatile blast into an untelegraphed ~2.2x hit at the same spot — reroll deterministically.
	if enemy is ExploderEnemy and kind == "volatile":
		kind = "armored"
	enemy.apply_elite(kind)

func _spawn_boss(stats: Dictionary) -> void:
	var entry := Bosses.pick(_last_boss_id)
	if entry.is_empty():
		return
	var boss = (entry["scene"] as PackedScene).instantiate()
	boss.configure(stats)
	get_tree().current_scene.add_child(boss)
	boss.global_position = _pick_spawn_pos()
	_last_boss_id = String(entry["id"])
	# Concealed-boss seam: a boss that spawns disguised (THE MYSTERY SHOPPER) must NOT roar on
	# spawn — the roar IS the reveal beat now, fired by the boss's own _reveal() instead (see
	# MysteryShopper._reveal). Every existing boss's revealed() is always true, so this gate is
	# byte-identical to the old unconditional play() for them.
	if (boss as BossBase).revealed():
		SoundManager.play("boss_roar")

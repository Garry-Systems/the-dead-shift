extends Node
## AUTOLOAD (registered in project.godot as "DifficultyManager"). Tracks elapsed run
## time and derives the current wave + scaled stats. run_time only advances while the
## tree is unpaused (autoloads are pausable by default), so the weapon-select screen,
## level-up menu, and relic menu do NOT inflate difficulty.

var run_time := 0.0
var wave := 1

# Temporary difficulty overrides (Pack A: Run variety) -- set by NightEvents (Blood Moon) and
# Extraction (the dawn final surge), read by Spawner. Living here (not on those scene nodes)
# means reset() below is the ONE place both get zeroed, so a run that ends (quit/death) mid-event
# can never leak an override into the NEXT run -- Main._ready() calls reset() unconditionally
# before checking mode, so this is also the safety net if a node's own end-of-event cleanup is
# ever skipped (e.g. the scene tearing down before its _process ever fires again).
var _spawn_interval_mult := 1.0     # Blood Moon: spawn_interval() x this
var _surge_floor_forced := false    # Dawn Extraction final surge: spawn_interval() forced to the floor
var _elite_chance_mult := 1.0       # Dawn Extraction final surge: elite roll chance x this

func _ready() -> void:
	reset()

## Resets to the start of a run (wave 1, no elapsed time, no leftover event overrides).
func reset() -> void:
	run_time = 0.0
	wave = 1
	_spawn_interval_mult = 1.0
	_surge_floor_forced = false
	_elite_chance_mult = 1.0

func _process(delta: float) -> void:
	run_time += delta
	wave = int(floor(run_time / GameConfig.WAVE_DURATION)) + 1

## Scaled stats for an enemy spawned right now.
func enemy_stats() -> Dictionary:
	return DifficultyCurve.enemy_stats(wave)

## Scaled stats for a boss spawned right now.
func boss_stats() -> Dictionary:
	return DifficultyCurve.boss_stats(wave)

## Seconds between spawns right now. Blood Moon multiplies the normal curve; the Dawn Extraction
## final surge instead FORCES the absolute floor (endless-only effects -- Boss Rush never touches
## either setter, so its own call through this same method is unaffected).
func spawn_interval() -> float:
	if _surge_floor_forced:
		return GameConfig.SPAWN_INTERVAL_FLOOR
	return DifficultyCurve.spawn_interval(wave) * _spawn_interval_mult

func set_spawn_interval_mult(m: float) -> void:
	_spawn_interval_mult = m

func set_surge_floor_forced(b: bool) -> void:
	_surge_floor_forced = b

func set_elite_chance_mult(m: float) -> void:
	_elite_chance_mult = m

## Current elite-roll chance multiplier (1.0 = normal). Read by Spawner.
func elite_chance_mult() -> float:
	return _elite_chance_mult

## "M:SS" elapsed run time for the HUD.
func time_string() -> String:
	var total := int(run_time)
	return "%d:%02d" % [total / 60, total % 60]

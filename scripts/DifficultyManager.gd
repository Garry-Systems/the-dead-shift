extends Node
## AUTOLOAD (registered in project.godot as "DifficultyManager"). Tracks elapsed run
## time and derives the current wave + scaled stats. run_time only advances while the
## tree is unpaused (autoloads are pausable by default), so the weapon-select screen,
## level-up menu, and relic menu do NOT inflate difficulty.

var run_time := 0.0
var wave := 1

func _ready() -> void:
	reset()

## Resets to the start of a run (wave 1, no elapsed time).
func reset() -> void:
	run_time = 0.0
	wave = 1

func _process(delta: float) -> void:
	run_time += delta
	wave = int(floor(run_time / GameConfig.WAVE_DURATION)) + 1

## Scaled stats for an enemy spawned right now.
func enemy_stats() -> Dictionary:
	return DifficultyCurve.enemy_stats(wave)

## Seconds between spawns right now.
func spawn_interval() -> float:
	return DifficultyCurve.spawn_interval(wave)

## "M:SS" elapsed run time for the HUD.
func time_string() -> String:
	var total := int(run_time)
	return "%d:%02d" % [total / 60, total % 60]

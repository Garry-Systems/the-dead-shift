extends Node
## Per-run counters (kills, bosses) read by the end-of-run coin payout.
## Autoload — survives scene changes; reset() is called at the start of each run
## from Main._ready. Session-only, no persistence. No class_name: the autoload
## name is already global.

var kills := 0
var bosses_killed := 0

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0

## A trash enemy was killed.
func add_kill() -> void:
	kills += 1

## A boss was killed.
func add_boss() -> void:
	bosses_killed += 1

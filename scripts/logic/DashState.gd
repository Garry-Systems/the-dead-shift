class_name DashState
extends RefCounted
## Pure dash state machine: tracks whether a dash is active and whether the
## cooldown has elapsed. No node dependency, so it can be unit-tested.

var _duration: float
var _cooldown: float
var _dash_time := 0.0       # time remaining in the active dash
var _cooldown_time := 0.0   # time remaining before the next dash is allowed

func _init(duration: float, cooldown: float) -> void:
	_duration = duration
	_cooldown = cooldown

func is_dashing() -> bool:
	return _dash_time > 0.0

func can_dash() -> bool:
	return _dash_time <= 0.0 and _cooldown_time <= 0.0

## Begins a dash if allowed. Returns true if a dash actually started.
func start_dash() -> bool:
	if not can_dash():
		return false
	_dash_time = _duration
	_cooldown_time = _cooldown
	return true

## Advance time by `delta` seconds.
func tick(delta: float) -> void:
	if _dash_time > 0.0:
		_dash_time -= delta
	if _cooldown_time > 0.0:
		_cooldown_time -= delta

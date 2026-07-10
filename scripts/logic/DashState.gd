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

## Upgrade card hook: shrinks the dash cooldown by `pct` (multiplicative, stacks). Does not
## touch a cooldown already counting down — takes effect on the next dash.
func upgrade_cooldown(pct: float) -> void:
	_cooldown *= (1.0 - pct)

## Relic hook (adrenal_valve): refunds `seconds` off the CURRENT cooldown countdown — never below
## zero (a dash already off cooldown just stays off cooldown; can't go "negative-ready").
func refund_cooldown(seconds: float) -> void:
	_cooldown_time = maxf(_cooldown_time - seconds, 0.0)

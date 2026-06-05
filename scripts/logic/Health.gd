class_name Health
extends RefCounted
## Pure health/damage state. No scene/node dependency, so it can be unit-tested.

var maxhp: float
var current: float

func _init(max_value: float) -> void:
	maxhp = max_value
	current = max_value

func is_dead() -> bool:
	return current <= 0.0

## Applies damage, clamped so health never drops below zero.
func take_damage(amount: float) -> void:
	if amount < 0.0:
		amount = 0.0
	current -= amount
	if current < 0.0:
		current = 0.0

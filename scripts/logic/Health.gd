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

## Restores health, never exceeding the maximum.
func heal(amount: float) -> void:
	current += amount
	if current > maxhp:
		current = maxhp

## Adds (or, with a negative amount, removes) maximum health, keeping current health
## within [1, maxhp]. Negative amounts are used when a relic is removed/swapped out.
## `raise_current` (Pack G fix round, adjudicated ruling): HARDCORE callers pass false — max
## health still grows ("you can build a bigger tank") but current does NOT rise with it ("you
## can't refill it"); the [1, maxhp] clamps still apply either way, so a negative amount still
## pulls an over-max current back down. A plain bool param (not a RunConfig read) keeps this
## class pure/probeable — the hardcore flag is read at the Player call sites, the same
## RunConfig.hardcore the heal() gate reads.
func add_max(amount: float, raise_current: bool = true) -> void:
	maxhp += amount
	if maxhp < 1.0:
		maxhp = 1.0
	if raise_current:
		current += amount
	if current > maxhp:
		current = maxhp
	if current < 1.0:
		current = 1.0

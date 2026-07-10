extends Area2D
## A relic dropped by a boss. Walking into it hands off to the RELIC CHOICE overlay
## (Relics Overhaul, Task 3) and is removed immediately — the "collect on touch" feel is
## unchanged, but the offer now queues (RelicChoice.request()) instead of auto-applying, so
## many bosses dropping relics at once (or a pickup collected mid-choice) never stack overlays,
## they just queue. RelicChoice rolls the actual pair (Relics.roll_choice) at DISPLAY time
## against the bar's THEN-current held ids, not this frame's — see RelicChoice.gd's header.
##
## `relic_id` is set by BossBase._reward()'s legacy single-roll drop-gate (it only spawns a
## pickup at all if there's at least one un-held relic at DROP time, via RelicBar.roll_drop())
## but is no longer consulted for the choice's actual content — kept only so that existing call
## site (`pickup.relic_id = id`) keeps working untouched.

var relic_id := ""
var _opened := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var choice := get_tree().get_first_node_in_group("relic_choice")
	if choice != null:
		choice.call("request")
	queue_free()

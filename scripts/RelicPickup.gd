extends Area2D
## A relic dropped by a boss. Walking into it AUTO-COLLECTS the relic (adds it to the bar)
## and removes the pickup immediately. Unwanted relics can be removed from the pause menu.
## (Auto-collect avoids the old modal's pause-stacking that left pickups stranded on the
## map — and it scales to many bosses dropping relics at once without interrupting play.)

var relic_id := ""
var _opened := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var bar := get_tree().get_first_node_in_group("relic_bar")
	if bar != null:
		bar.call("take_or_replace", relic_id)
	queue_free()

extends Area2D
## A relic dropped by a boss. Walking into it opens the RelicMenu for its relic id.
## The menu frees this pickup once the player resolves the choice.

var relic_id := ""
var _opened := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var menu := get_tree().get_first_node_in_group("relic_menu")
	if menu != null:
		menu.call("open", relic_id, self)

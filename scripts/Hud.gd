extends CanvasLayer
## Minimal top-of-screen HUD, built entirely in code (no fragile hand-made UI):
## a level label and an XP progress bar that fills as you collect gems.

var _bar: ProgressBar
var _label: Label
var _player: Player

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_right = 1.0          # stretch across the screen width
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_top = 10
	_bar.offset_bottom = 30
	add_child(_bar)

	_label = Label.new()
	_label.offset_left = 14
	_label.offset_top = 32
	add_child(_label)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_bar.max_value = _player.xp_to_next()
	_bar.value = _player.xp
	_label.text = "Level %d" % _player.level

extends CanvasLayer
## Minimal HUD, built in code: XP bar + level label (top), wave/timer (top-right),
## and a boss health bar (bottom-center, shown only while a boss is alive).

var _bar: ProgressBar
var _label: Label
var _wave_label: Label
var _boss_bar: ProgressBar
var _player: Player

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_right = 1.0
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_top = 10
	_bar.offset_bottom = 30
	add_child(_bar)

	_label = Label.new()
	_label.offset_left = 14
	_label.offset_top = 32
	add_child(_label)

	_wave_label = Label.new()
	_wave_label.anchor_left = 1.0
	_wave_label.anchor_right = 1.0
	_wave_label.offset_left = -180
	_wave_label.offset_right = -12
	_wave_label.offset_top = 36
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_wave_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 1.0
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.anchor_top = 1.0
	_boss_bar.anchor_bottom = 1.0
	_boss_bar.offset_left = -200
	_boss_bar.offset_right = 200
	_boss_bar.offset_top = -44
	_boss_bar.offset_bottom = -24
	_boss_bar.visible = false
	add_child(_boss_bar)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_bar.max_value = _player.xp_to_next()
	_bar.value = _player.xp
	_label.text = "Level %d" % _player.level
	if RunConfig.mode == "boss_rush":
		var spawner := get_tree().get_first_node_in_group("spawner")
		var n := 0
		if spawner != null:
			n = int(spawner.boss_rush_count)
		_wave_label.text = "Boss #%d" % n
	else:
		_wave_label.text = "Wave %d   %s" % [DifficultyManager.wave, DifficultyManager.time_string()]

	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null:
		_boss_bar.visible = true
		_boss_bar.value = (boss as Boss).health_fraction()
	else:
		_boss_bar.visible = false

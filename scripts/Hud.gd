extends CanvasLayer
## Minimal HUD, built in code: XP bar + level label (top), wave/timer (top-right),
## and a boss health bar (bottom-center, shown only while a boss is alive).

var _bar: ProgressBar
var _label: Label
var _wave_label: Label
var _boss_bar: ProgressBar
var _ammo_label: Label
var _reload_bar: ProgressBar
var _hp_bar: ProgressBar
var _hp_label: Label
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

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.offset_left = 14
	_hp_bar.offset_right = 214
	_hp_bar.offset_top = 54
	_hp_bar.offset_bottom = 72
	_hp_bar.modulate = Color(1.0, 0.45, 0.45)   # red-ish, distinct from the XP bar
	add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.offset_left = 18
	_hp_label.offset_top = 53
	add_child(_hp_label)

	_wave_label = Label.new()
	_wave_label.anchor_left = 1.0
	_wave_label.anchor_right = 1.0
	_wave_label.offset_left = -180
	_wave_label.offset_right = -76
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

	_ammo_label = Label.new()
	_ammo_label.anchor_top = 1.0
	_ammo_label.anchor_bottom = 1.0
	_ammo_label.offset_left = 14
	_ammo_label.offset_top = -40
	_ammo_label.offset_bottom = -16
	add_child(_ammo_label)

	_reload_bar = ProgressBar.new()
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.anchor_top = 1.0
	_reload_bar.anchor_bottom = 1.0
	_reload_bar.offset_left = 14
	_reload_bar.offset_right = 140
	_reload_bar.offset_top = -58
	_reload_bar.offset_bottom = -44
	_reload_bar.visible = false
	add_child(_reload_bar)

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_bar.max_value = _player.xp_to_next()
	_bar.value = _player.xp
	_label.text = "Level %d" % _player.level
	_hp_bar.value = _player.health_fraction()
	_hp_label.text = "HP %d / %d" % [int(_player.hp()), int(_player.max_hp())]
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

	var gun := _player.gun
	if gun != null:
		if gun.is_reloading():
			_ammo_label.text = "Reloading..."
			_reload_bar.visible = true
			_reload_bar.value = gun.reload_progress()
		else:
			_ammo_label.text = "%d / %d" % [gun.ammo(), gun.mag_size]
			_reload_bar.visible = false

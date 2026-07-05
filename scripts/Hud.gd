extends CanvasLayer
## Minimal HUD, built in code: XP bar + level label (top), wave/timer (top-right),
## and a boss health bar (bottom-center, shown only while a boss is alive).

var _bar: ProgressBar
var _label: Label
var _wave_label: Label
var _boss_bar: ProgressBar
var _ammo_label: Label
var _reload_bar: ProgressBar
var _ability_label: Label   # Ryan's purge cooldown, shown above the ammo (only when he has it)
var _hp_bar: ProgressBar
var _hp_label: Label
var _player: Player
var _hints: FirstRunHints   # first-run onboarding hint strip (no-op once SaveManager.tutorial_done())

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.anchor_right = 1.0
	_bar.offset_left = 12
	_bar.offset_right = -12
	_bar.offset_top = 10
	_bar.offset_bottom = 58
	add_child(_bar)

	_label = Label.new()
	_label.offset_left = 14
	_label.offset_top = 64
	add_child(_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 1.0
	_hp_bar.offset_left = 14
	_hp_bar.offset_right = 330
	_hp_bar.offset_top = 96
	_hp_bar.offset_bottom = 128
	add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.offset_left = 18
	_hp_label.offset_top = 100
	add_child(_hp_label)

	_wave_label = Label.new()
	_wave_label.anchor_left = 1.0
	_wave_label.anchor_right = 1.0
	_wave_label.offset_left = -260
	_wave_label.offset_right = -76
	_wave_label.offset_top = 64
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
	_ammo_label.offset_top = -96
	_ammo_label.offset_bottom = -16
	add_child(_ammo_label)

	_reload_bar = ProgressBar.new()
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.anchor_top = 1.0
	_reload_bar.anchor_bottom = 1.0
	_reload_bar.offset_left = 14
	_reload_bar.offset_right = 440
	_reload_bar.offset_top = -130
	_reload_bar.offset_bottom = -88
	_reload_bar.visible = false
	add_child(_reload_bar)

	_ability_label = Label.new()
	_ability_label.anchor_top = 1.0
	_ability_label.anchor_bottom = 1.0
	_ability_label.offset_left = 14
	_ability_label.offset_top = -184    # sits above the reload bar / ammo readout, bottom-left
	_ability_label.offset_bottom = -136
	_ability_label.visible = false
	add_child(_ability_label)

	_apply_pixel_style()

	_hints = FirstRunHints.new()
	add_child(_hints)
	_hints.setup(_player)

## Applies the shared PixelTheme look to every HUD label and bar.
func _apply_pixel_style() -> void:
	_label_px(_label, 26, PixelTheme.TEXT)
	_label_px(_hp_label, 22, PixelTheme.TEXT)
	_label_px(_wave_label, 24, PixelTheme.TEXT)
	_label_px(_ammo_label, 48, PixelTheme.ACCENT)
	_label_px(_ability_label, 28, PixelTheme.ACCENT)
	_style_bar(_bar, PixelTheme.SELECT)        # XP — C4 lavender (full-width strip up top)
	_style_bar(_hp_bar, PixelTheme.ACCENT)     # health — C4 lavender (player/action color)
	_style_bar(_boss_bar, PixelTheme.DANGER)   # boss — C3 gray-tan (the enemy/threat color)
	_style_bar(_reload_bar, PixelTheme.ACCENT) # reload — C4 lavender

## Pixel font + a hard 1px drop shadow so readouts stay legible over gameplay.
func _label_px(l: Label, size: int, col: Color) -> void:
	PixelTheme.style_label(l, size, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 0)

## Hard-cornered, anti-alias-off progress bar matching the menu styleboxes.
func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = PixelTheme.BTN_BG
	bg.border_color = PixelTheme.ACCENT_DIM
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("fill", fill)

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
		_boss_bar.value = (boss as BossBase).health_fraction()
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

	# Ryan's purge cooldown, above the ammo (hidden for characters without the ability).
	if _player.has_purge_ability():
		_ability_label.visible = true
		var cd := _player.ability_cooldown_remaining()
		if cd > 0.0:
			_ability_label.text = "PURGE  %ds" % int(ceil(cd))
			_ability_label.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
		else:
			_ability_label.text = "PURGE READY"
			_ability_label.add_theme_color_override("font_color", PixelTheme.SELECT)
	else:
		_ability_label.visible = false

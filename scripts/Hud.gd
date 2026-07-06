extends CanvasLayer
## Minimal HUD, built in code: XP bar + level label (top), wave/timer (top-right),
## and a boss health bar (bottom-center, shown only while a boss is alive).

var _bar: ProgressBar
var _label: Label
var _wave_label: Label
var _clock_label: Label     # night-shift clock (endless only), just under the wave/timer label
var _boss_bar: ProgressBar
var _boss_name_label: Label   # boss display name, shown just above the boss HP bar
var _boss_was_alive := false  # edge-detects "a boss wave starts" for the SHIFT CHANGE toast
var _last_shift_toast := -999.0   # engine-clock seconds of the last SHIFT CHANGE toast (debounce)
var _ammo_label: Label
var _reload_bar: ProgressBar
var _ability_label: Label   # Ryan's purge cooldown, shown above the ammo (only when he has it)
var _hp_bar: ProgressBar
var _hp_label: Label
var _player: Player
var _hints: FirstRunHints   # first-run onboarding hint strip (no-op once SaveManager.tutorial_done())

var _dawn_fired := false    # DAWN banner + coin bonus fire once per run (Hud is rebuilt each run)

# --- Full-screen toast banner (self-freeing, presentation-only; mirrors ScreenFlash's
# spawn-and-forget pattern). Shared by the once-per-run DAWN banner (Pack 3) and the
# once-per-boss-wave SHIFT CHANGE toast (Pack 7) via _show_banner(text) below. ---
const BANNER_HOLD := 2.6   # seconds fully visible
const BANNER_FADE := 0.4   # seconds fade-out (HOLD + FADE ~= the brief's "~3s")

func _ready() -> void:
	add_to_group("hud")
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

	# Night-shift clock — sits just under the wave/timer label, same column (right-aligned,
	# top-right); hidden entirely in Boss Rush. Clears well above FirstRunHints' strip (140-196).
	_clock_label = Label.new()
	_clock_label.anchor_left = 1.0
	_clock_label.anchor_right = 1.0
	_clock_label.offset_left = -260
	_clock_label.offset_right = -76
	_clock_label.offset_top = 100
	_clock_label.offset_bottom = 128
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.visible = false
	add_child(_clock_label)

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

	# Boss display name, sitting just above its HP bar (same horizontal span, centered).
	_boss_name_label = Label.new()
	_boss_name_label.anchor_left = 0.5
	_boss_name_label.anchor_right = 0.5
	_boss_name_label.anchor_top = 1.0
	_boss_name_label.anchor_bottom = 1.0
	_boss_name_label.offset_left = -200
	_boss_name_label.offset_right = 200
	_boss_name_label.offset_top = -74
	_boss_name_label.offset_bottom = -46
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.visible = false
	add_child(_boss_name_label)

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
	_label_px(_clock_label, 22, PixelTheme.TEXT)
	_label_px(_boss_name_label, 24, PixelTheme.ACCENT)   # C4 — boss name over the (C3 DANGER) HP bar
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
		_clock_label.visible = false
	else:
		_wave_label.text = "Wave %d   %s" % [DifficultyManager.wave, DifficultyManager.time_string()]
		_clock_label.visible = true
		_clock_label.text = ShiftClock.clock_string(DifficultyManager.run_time)
		# HORDE NIGHT (Pack G) falls into this "not boss_rush" branch too (the clock is shown there
		# as flavor, per spec) but must NOT get the dawn bonus/banner — NightEvents and Extraction
		# already gate on `mode == "endless"` directly and so already exclude horde; this block was
		# the one dawn-adjacent gate that didn't (it only checked "not boss_rush"), so it's fixed
		# here to require endless explicitly. OVERTIME/DAILY stay unaffected (mode stays "endless").
		if RunConfig.mode == "endless" and not _dawn_fired and DifficultyManager.run_time >= ShiftClock.dawn_run_time():
			_dawn_fired = true
			RunStats.add_coins(GameConfig.DAWN_BONUS_COINS)
			SoundManager.play("dawn_sting")
			CameraShake.add_trauma(GameConfig.SHAKE_TRAUMA_DAWN)   # Pack D
			_show_dawn_banner()

	var boss := get_tree().get_first_node_in_group("boss")
	if boss != null:
		_boss_bar.visible = true
		_boss_bar.value = (boss as BossBase).health_fraction()
		_boss_name_label.visible = true
		_boss_name_label.text = Bosses.name_for((boss as BossBase).boss_id())
		if not _boss_was_alive:
			_boss_was_alive = true
			# Debounced: the "no boss -> boss" edge can flicker in Boss Rush (a boss dying and
			# the refill spawning can straddle a Hud _process depending on sibling order), and
			# the toast shouldn't re-fire on every refill anyway. Engine clock, not run time —
			# monotonic and pause-proof.
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_shift_toast >= GameConfig.SHIFT_TOAST_COOLDOWN:
				_last_shift_toast = now
				_show_banner("SHIFT CHANGE")   # Spawner already fires the "boss_roar" SFX on spawn
	else:
		_boss_bar.visible = false
		_boss_name_label.visible = false
		_boss_was_alive = false

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

## Once-per-run dawn banner. Thin wrapper over _show_banner (Pack 7 extracted the node-building
## so the SHIFT CHANGE toast below can reuse it verbatim). Reframed for Dawn Extraction (Pack A):
## the DAWN_BONUS_COINS payout above still fires unconditionally at this same crossing —
## Extraction.gd (a sibling node) independently watches the same run_time threshold to start the
## final-surge/chopper sequence, so the two effects land together without this Hud knowing
## anything about Extraction's internals.
func _show_dawn_banner() -> void:
	_show_banner("RESCUE INBOUND\nSURVIVE TO EXTRACT")

## Public entry point for other scene nodes (NightEvents, Extraction — Pack A) that want the
## same full-screen toast without reaching into this Hud's internals.
func show_banner(text: String) -> void:
	_show_banner(text)

## A big C4 label over a dim scrim, held briefly then faded out, then it frees itself.
## Self-contained (spawn and forget), same shape as ScreenFlash. The run continues underneath
## it — nothing is paused. Shared by the DAWN banner (Pack 3) and the SHIFT CHANGE toast (Pack 7).
func _show_banner(text: String) -> void:
	var banner := Control.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(scrim)

	var label := Label.new()
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_title(label, 46)
	banner.add_child(label)

	var tw := create_tween()
	tw.tween_interval(BANNER_HOLD)
	tw.tween_property(banner, "modulate:a", 0.0, BANNER_FADE)
	tw.tween_callback(banner.queue_free)

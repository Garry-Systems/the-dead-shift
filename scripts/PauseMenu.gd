extends CanvasLayer
## Top-right pause button + a pause overlay (Resume / Restart Run / Back to Menu).
## PROCESS_MODE_ALWAYS so the button and overlay work while the tree is paused. The
## button is inert if something else already paused the tree (a level-up / relic menu),
## so it can't stack a second pause on top of those.

var _overlay: Control
var _pause_btn: Button
var _relics_box: VBoxContainer
var _sfx_slider: HSlider    # SFX volume 0..1 (v0.1.72; value re-synced every time the overlay opens)
var _music_slider: HSlider  # MUSIC volume 0..1
var _effects_btn: Button    # EFFECTS ON/OFF toggle — screen shake + crit-kill hit-stop (Pack D)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 15
	_build_button()
	_build_overlay()
	_overlay.visible = false

func _process(_delta: float) -> void:
	_pause_btn.visible = not get_tree().paused

func _build_button() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "II"
	PixelTheme.style_button(_pause_btn, Vector2(76, 76), 28)
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -92
	_pause_btn.offset_right = -16
	# Well below the top HUD (XP bar / wave readout); shifted by the same safe-area inset
	# the Hud applies (v0.1.72) so a notched phone can't stack the clock readout onto it.
	var inset := SafeArea.top_inset()
	_pause_btn.offset_top = 150 + inset
	_pause_btn.offset_bottom = 226 + inset
	_pause_btn.pressed.connect(_on_pause_pressed)
	add_child(_pause_btn)

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = PixelTheme.OVERLAY_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 36)
	vbox.add_child(title)
	vbox.add_child(_spacer(6))

	var relics_header := Label.new()
	relics_header.text = "RELICS"
	relics_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(relics_header, 22, PixelTheme.ACCENT)
	vbox.add_child(relics_header)
	_relics_box = VBoxContainer.new()
	_relics_box.add_theme_constant_override("separation", 12)
	vbox.add_child(_relics_box)
	vbox.add_child(_spacer(6))

	vbox.add_child(_menu_button("RESUME", _on_resume))
	vbox.add_child(_menu_button("RESTART RUN", _on_restart))
	vbox.add_child(_menu_button("BACK TO MENU", _on_back))
	vbox.add_child(_spacer(6))
	# Volume sliders (v0.1.72; MainMenu's hub has its own matching pair — keep in lockstep).
	_sfx_slider = _make_volume_slider(SaveManager.sfx_vol(), func(v: float): SoundManager.set_sfx_volume(v))
	vbox.add_child(_volume_row("SFX", _sfx_slider))
	_music_slider = _make_volume_slider(SaveManager.music_vol(), func(v: float): SoundManager.set_music_volume(v))
	vbox.add_child(_volume_row("MUSIC", _music_slider))
	_effects_btn = _menu_button(_effects_label(), _on_toggle_effects)
	vbox.add_child(_effects_btn)

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	PixelTheme.style_button(b, Vector2(420, 72), 20)
	b.pressed.connect(cb)
	return b

# --- SFX / Music volume sliders (v0.1.72; MainMenu's hub has its own matching pair) ---

## Label + slider on one row. The slider is passed in (not built here) so the caller can
## keep a reference for the overlay-open value re-sync (see _on_pause_pressed).
func _volume_row(text: String, slider: HSlider) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(110, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelTheme.style_label(lbl, 18, PixelTheme.TEXT_DIM)
	row.add_child(lbl)
	row.add_child(slider)
	return row

## Pixel-styled 0..1 volume slider. `on_change` fires live during the drag (SoundManager
## persists each step — a small JSON save, harmless at slider cadence); the release plays
## a "ui_tap" so the player hears the new SFX level immediately.
func _make_volume_slider(initial: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = initial
	s.custom_minimum_size = Vector2(300, 48)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = PixelTheme.BTN_BG
	track.border_color = PixelTheme.ACCENT_DIM
	track.set_border_width_all(2)
	track.set_corner_radius_all(0)
	track.anti_aliasing = false
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelTheme.ACCENT_DIM
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	# Hard-cornered grabber block generated in code (no grabber art asset; a filled C4 block
	# matches the hard-cornered stylebox look everywhere else).
	var img := Image.create(16, 40, false, Image.FORMAT_RGBA8)
	img.fill(PixelTheme.TEXT)
	var grabber := ImageTexture.create_from_image(img)
	s.add_theme_icon_override("grabber", grabber)
	s.add_theme_icon_override("grabber_highlight", grabber)
	s.add_theme_icon_override("grabber_disabled", grabber)
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool): SoundManager.play("ui_tap"))
	return s

# --- EFFECTS toggle (Pack D): gates screen shake AND crit-kill hit-stop together ---
func _effects_label() -> String:
	return "EFFECTS: ON" if SaveManager.shake_on() else "EFFECTS: OFF"

func _on_toggle_effects() -> void:
	SaveManager.set_shake_on(not SaveManager.shake_on())
	SaveManager.save_game()
	_effects_btn.text = _effects_label()

## Rebuilds the held-relic list: each relic's name + what it does + a SCRAP button.
## Refreshed every time the pause overlay opens (relics change during the run).
##
## Relics Overhaul (Task 4): the free no-payout REMOVE button is gone — every mid-run relic
## removal now pays out (RELIC_SCRAP_COINS / RELIC_CURSED_SCRAP_COINS by family), routed through
## `RelicBar.scrap()`, the SAME shared entry point RelicChoice's full-bar swap-flow scrap cards
## use (Task 3) — a slot can never be freed here without paying, or vice versa. The payout shown
## on the button comes from `RelicBar.scrap_value(id)`, the exact function `scrap()` itself calls
## to decide the payout, so the number on the button can never drift from what tapping it pays.
func _populate_relics() -> void:
	if _relics_box == null:
		return
	for c in _relics_box.get_children():
		c.queue_free()
	var bar := get_tree().get_first_node_in_group("relic_bar")
	var ids: Array = bar.call("held_ids") if bar != null else []
	if ids.is_empty():
		var none := Label.new()
		none.text = "No relics yet — beat a boss to earn one."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.custom_minimum_size = Vector2(440, 0)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PixelTheme.style_label(none, 16, PixelTheme.TEXT_DIM)
		_relics_box.add_child(none)
		return
	for id in ids:
		var r: Dictionary = Relics.get_relic(String(id))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var nm := Label.new()
		nm.text = String(r.get("name", id)).to_upper()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(nm, 18, PixelTheme.ACCENT)
		row.add_child(nm)
		var desc := Label.new()
		desc.text = String(r.get("desc", ""))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.custom_minimum_size = Vector2(440, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PixelTheme.style_label(desc, 14, PixelTheme.TEXT_DIM)
		row.add_child(desc)
		var sc := Button.new()
		var value: int = int(bar.call("scrap_value", String(id))) if bar != null else 0
		sc.text = "SCRAP (+%d COINS)" % value       # mirrors RelicChoice's "SKIP (+%d COINS)" idiom
		PixelTheme.style_button(sc, Vector2(220, 52), 16)
		sc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sc.add_theme_color_override("font_color", PixelTheme.TEXT)   # run-coin color idiom (GameOver TIPS row / RelicChoice's SCRAP label both use TEXT)
		var rid := String(id)
		sc.pressed.connect(func(): _on_scrap_relic(rid))
		row.add_child(sc)
		_relics_box.add_child(row)

## Scraps a held relic — RelicBar reverses its effect AND pays coins by family via the shared
## RelicBar.scrap() entry point — then refreshes the list. Sounds mirror the store's
## purchase/deny idiom (MainMenu._on_buy_benefit): "purchase" on a successful scrap, "ui_tap"
## (deny) on the defensive no-op path (no relic bar in the scene, or `id` already left `_held`
## between opening the menu and this tap — scrap() returns 0 coins in both cases).
func _on_scrap_relic(id: String) -> void:
	var bar := get_tree().get_first_node_in_group("relic_bar")
	var paid: int = int(bar.call("scrap", id)) if bar != null else 0
	SoundManager.play("purchase" if paid > 0 else "ui_tap")
	_populate_relics()

func _on_pause_pressed() -> void:
	if get_tree().paused:
		return                       # another menu owns the pause; don't stack
	_populate_relics()
	# Volume could have changed in the menu since this overlay was built — re-sync silently
	# (set_value_no_signal: a plain .value assignment would re-fire set_*_volume for nothing).
	_sfx_slider.set_value_no_signal(SaveManager.sfx_vol())
	_music_slider.set_value_no_signal(SaveManager.music_vol())
	_effects_btn.text = _effects_label()
	get_tree().paused = true
	_overlay.visible = true
	_pause_btn.visible = false

## Android lifecycle + back gesture (launch hygiene v0.1.72).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# A call / home gesture / notification shade mid-run auto-opens the pause overlay,
			# so the player never resumes into a half-lost fight. _on_pause_pressed's own
			# guard makes this a no-op when a level-up / relic choice / game-over owns the pause.
			_on_pause_pressed()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# quit_on_go_back is off (project.godot) — back never hard-quits mid-run (that
			# skipped the payout entirely). Overlay open -> resume; otherwise -> pause. When
			# another menu owns the pause (overlay hidden + tree paused) both calls no-op.
			if _overlay.visible:
				_on_resume()
			else:
				_on_pause_pressed()

func _on_resume() -> void:
	_overlay.visible = false
	_pause_btn.visible = true
	get_tree().paused = false

## Abandoning a run (restart or quit) still pays — at QUIT_PAYOUT_FRAC of the death
## payout — and counts as a played game once the run lasted ABANDON_COUNTS_MIN_TIME
## (v0.1.72), so mobile interruptions aren't punished but instant restarts don't farm.
## Mirrors GameOver._on_player_died; RunStats.paid_out guards double payment.
func _abandon_run_payout() -> void:
	if RunStats.paid_out:
		return
	RunStats.paid_out = true
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	# PAYDAY pre-mult seam (Deep Clean, item 4): extracted to locals so this twin site derives
	# `kills`/`bonus` identically to GameOver._finish_run's own locals, for CoinReward.pre_mult_total
	# below — same values as the bare RunStats reads this replaced, no behavior change here.
	var kills := RunStats.kills
	var bonus := RunStats.bonus_coins
	# int() truncates here (unchanged from before this card existed) — final_payout() itself
	# already rounds once for the coin_mult; this only re-truncates the QUIT_PAYOUT_FRAC step.
	# SIGNING BONUS (final-review fix): passes the SAME vested-at-DifficultyManager.run_time value
	# GameOver's death/win path computes — an instant quit (run_time ~= 0) vests ~0, and whatever
	# HAS vested still gets the same 0.75 QUIT_PAYOUT_FRAC haircut as the rest of final_payout,
	# same as today's behavior for every other term.
	var earned := int(CoinReward.final_payout(wave, bosses, kills, bonus, RunStats.coin_mult, RunStats.signing_bonus, DifficultyManager.run_time) * GameConfig.QUIT_PAYOUT_FRAC)
	SaveManager.add_coins(earned)
	# Rank XP (Pack G): the ACTUAL (already QUIT_PAYOUT_FRAC-haircut) amount just granted — same
	# accessor GameOver's death/win flush uses. A quit never shows the pay-stub, so any resulting
	# PROMOTED popup queues at the next menu entry instead (pending-rewards idiom) — same as every
	# other exit path.
	SaveManager.add_rank_xp(earned)
	# Records (Pack G): mirrors GameOver._finish_run's twin gating — see that function's comment
	# for why HORDE/OVERTIME are excluded from the shared best_wave/best_bosses/best_clockout.
	if RunConfig.mode != "horde" and not RunConfig.overtime:
		SaveManager.record_run(wave, bosses)
	if RunConfig.mode == "horde":
		SaveManager.record_horde_best_wave(wave)
	if RunConfig.overtime:
		SaveManager.record_overtime_best_clockout(DifficultyManager.run_time)
	if RunConfig.hardcore:
		SaveManager.record_hardcore_best_clockout(DifficultyManager.run_time)
	# Launch hygiene (v0.1.72): an abandon only counts toward games_played (the every-10-games
	# milestone + the games-played commendations) after a real shift — an instant pause-restart
	# loop was farming a free crate/gun per ~10 minutes. Death/win (GameOver) always counts;
	# a legitimate mid-run interruption past the threshold still counts here too.
	if DifficultyManager.run_time >= GameConfig.ABANDON_COUNTS_MIN_TIME:
		SaveManager.add_game_played()
	# Lifetime records (Pack D): flushed exactly once per run via the RunStats.paid_out guard
	# above (mirrors GameOver._finish_run's twin call). `earned` is the ALREADY-haircut
	# (QUIT_PAYOUT_FRAC) amount — the actual amount this quit just granted. OVERTIME suppresses
	# only the best_clockout_seconds bump (mirrors GameOver._finish_run's twin call).
	SaveManager.add_lifetime_run(RunStats.kills, bosses, RunStats.elites_killed, earned, DifficultyManager.run_time,
		String(Inventory.equipped_instance().get("base", "")), not RunConfig.overtime)
	# Challenge board (Pack C): same guarded block, mirrors GameOver._finish_run's twin call.
	# A quit/restart is never a win, so extraction_wins is always 0 here. clock_seconds is zeroed
	# on an OVERTIME run (Pack G fix round): the 240s preset already sits past the "reach 2:00 AM"
	# challenge target, which would auto-complete it on an instant quit — clock challenges only
	# count from real shifts, mirroring the best-clockout record freeze.
	SaveManager.flush_challenge_counters({
		"kills": RunStats.kills, "elite_kills": RunStats.elites_killed, "boss_kills": bosses,
		"clock_seconds": (0.0 if RunConfig.overtime else DifficultyManager.run_time),
		"blood_moons_survived": RunStats.blood_moons_survived,
		"power_surge_kills": RunStats.power_surge_kills, "extraction_wins": 0,
		"fire_kills": RunStats.fire_kills, "electric_kills": RunStats.electric_kills,
		"poison_kills": RunStats.poison_kills,
	})
	if RunConfig.daily:
		SaveManager.record_daily_score(earned)
	# Best single-run payout (Pack H: PAYDAY commendation) — mirrors GameOver._finish_run's twin
	# call. Deep Clean (item 4): PRE-coin_mult subtotal now, not the QUIT_PAYOUT_FRAC-haircut
	# `earned` — see CoinReward.pre_mult_total's doc comment. THE ICE CREAM TRUCK (Task 4): also net
	# of snacks_spent now (CoinReward.net_pre_mult_total) — same reasoning as GameOver's twin call,
	# see that file's comment. Keep in lockstep with GameOver.
	var net_pre_mult := CoinReward.net_pre_mult_total(wave, bosses, kills, bonus)
	SaveManager.record_best_run_payout(net_pre_mult)
	# Commendations (Pack H): mirrors GameOver._finish_run's twin call — same guarded block, same
	# exactly-once contract, called before this block's own save_game() below.
	SaveManager.check_and_grant_commendations()
	SaveManager.save_game()
	# Deep Clean (item 17): mirrors GameOver._finish_run's twin call — both now call the ONE
	# shared CoinReward.weapon_xp_payout (HARDCORE × Punch-Card compose-and-round-once lives
	# there now, not hand-duplicated here) with the SAME kind of (kills, wave, bosses) locals.
	var xp_amount := CoinReward.weapon_xp_payout(kills, wave, bosses)
	Inventory.add_run_xp(xp_amount)

func _on_restart() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

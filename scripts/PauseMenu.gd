extends CanvasLayer
## Top-right pause button + a pause overlay (Resume / Restart Run / Back to Menu).
## PROCESS_MODE_ALWAYS so the button and overlay work while the tree is paused. The
## button is inert if something else already paused the tree (a level-up / relic menu),
## so it can't stack a second pause on top of those.

var _overlay: Control
var _pause_btn: Button
var _relics_box: VBoxContainer

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
	_pause_btn.offset_top = 150       # well below the top HUD (XP bar / wave readout)
	_pause_btn.offset_bottom = 226
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

## Rebuilds the held-relic list: each relic's name + what it does + a REMOVE button.
## Refreshed every time the pause overlay opens (relics change during the run).
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
		var rm := Button.new()
		rm.text = "REMOVE"
		PixelTheme.style_button(rm, Vector2(220, 52), 16)
		rm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rm.add_theme_color_override("font_color", PixelTheme.DANGER)
		var rid := String(id)
		rm.pressed.connect(func(): _on_remove_relic(rid))
		row.add_child(rm)
		_relics_box.add_child(row)

## Removes a held relic (the RelicBar reverses its stat effect), then refreshes the list.
func _on_remove_relic(id: String) -> void:
	var bar := get_tree().get_first_node_in_group("relic_bar")
	if bar != null:
		bar.call("remove_relic", id)
	_populate_relics()

func _on_pause_pressed() -> void:
	if get_tree().paused:
		return                       # another menu owns the pause; don't stack
	_populate_relics()
	get_tree().paused = true
	_overlay.visible = true
	_pause_btn.visible = false

func _on_resume() -> void:
	_overlay.visible = false
	_pause_btn.visible = true
	get_tree().paused = false

## Abandoning a run (restart or quit) still pays — at QUIT_PAYOUT_FRAC of the death
## payout — and still counts as a played game, so mobile interruptions aren't punished.
## Mirrors GameOver._on_player_died; RunStats.paid_out guards double payment.
func _abandon_run_payout() -> void:
	if RunStats.paid_out:
		return
	RunStats.paid_out = true
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	var earned := int((CoinReward.payout(wave, bosses, RunStats.kills) + RunStats.bonus_coins) * GameConfig.QUIT_PAYOUT_FRAC)
	SaveManager.add_coins(earned)
	SaveManager.record_run(wave, bosses)
	SaveManager.add_game_played()
	SaveManager.save_game()
	Inventory.add_run_xp(RunStats.kills + wave * 10 + bosses * 50)

func _on_restart() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

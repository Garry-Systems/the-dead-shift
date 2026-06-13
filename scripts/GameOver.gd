extends CanvasLayer
## Death overlay. Listens for the player's `died` signal, shows a run summary + a
## Back-to-Menu button. PROCESS_MODE_ALWAYS so its button works while the tree is
## paused (death pauses the game).

var _root: Control
var _label: Label
var _player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.died.connect(_on_player_died)
	_build_ui()
	_root.visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = PixelTheme.OVERLAY_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 40)
	title.add_theme_color_override("font_color", PixelTheme.DANGER)
	vbox.add_child(title)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_label, 18, PixelTheme.TEXT)
	vbox.add_child(_label)

	vbox.add_child(_spacer(6))

	var btn := Button.new()
	btn.text = "BACK TO MENU"
	PixelTheme.style_button(btn, Vector2(420, 72), 20)
	btn.pressed.connect(_on_back_pressed)
	vbox.add_child(btn)

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _on_player_died() -> void:
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	var earned := CoinReward.payout(wave, bosses, RunStats.kills)

	SaveManager.add_coins(earned)
	SaveManager.record_run(wave, bosses)
	SaveManager.save_game()

	# Weapon-loot: award XP to the equipped weapon so its talents unlock over time.
	Inventory.add_run_xp(RunStats.kills + wave * 10 + bosses * 50)

	var result := ""
	if RunConfig.mode == "boss_rush":
		result = "Bosses defeated: %d   (best %d)" % [bosses, SaveManager.best_bosses()]
	else:
		result = "Wave reached: %d   (best %d)" % [wave, SaveManager.best_wave()]

	_label.text = "%s\nCoins earned: +%d\nTotal coins: %d" % [result, earned, SaveManager.coins()]
	_root.visible = true

func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

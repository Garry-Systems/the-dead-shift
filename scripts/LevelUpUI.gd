extends CanvasLayer
## The level-up upgrade screen, built entirely in code. When the player levels up
## it pauses the game, dims the screen, and offers 3 random cards. Odd levels offer
## player-stat cards; even levels offer gun cards. Queues multiple level-ups.

var _player: Player
var _queue: Array[int] = []        # levels waiting for an upgrade pick
var _current_cards: Array = []

var _root: Control
var _title: Label
var _buttons: Array[Button] = []
var _card_titles: Array[Label] = []
var _descs: Array[Label] = []

func _ready() -> void:
	# Keep this UI alive and clickable while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10

	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.leveled_up.connect(_on_player_leveled_up)

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
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(740, 0)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(_title, 30, PixelTheme.ACCENT)
	vbox.add_child(_title)

	# 3 big tappable cards: a chunky button with the upgrade name (pixel font) over a
	# readable (anti-aliased) description, so the choices are easy to read at a glance.
	for i in 3:
		var b := Button.new()
		b.clip_contents = true
		PixelTheme.style_button(b, Vector2(760, 188))   # pass size — the default would force 806x135 (too short)
		b.text = ""
		b.pressed.connect(_on_card_pressed.bind(i))

		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 10)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 26
		content.offset_right = -26
		content.offset_top = 14
		content.offset_bottom = -14
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(content)

		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelTheme.style_label(name_lbl, 30, PixelTheme.ACCENT)
		content.add_child(name_lbl)
		_card_titles.append(name_lbl)

		var desc := Label.new()
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(700, 0)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelTheme.readable_label(desc, 24, PixelTheme.TEXT)
		content.add_child(desc)
		_descs.append(desc)

		_buttons.append(b)
		vbox.add_child(b)

func _on_player_leveled_up() -> void:
	_queue.append(_player.level)
	if not _root.visible:
		_show_next()

func _show_next() -> void:
	var lvl: int = _queue.pop_front()
	SoundManager.play("level_up")
	_current_cards = _pick_three(lvl)
	_title.text = "LEVEL %d — choose a %s upgrade" % [lvl, Upgrades.label_for_level(lvl)]
	for i in 3:
		var c: Dictionary = _current_cards[i]
		_card_titles[i].text = String(c["title"]).to_upper()
		_descs[i].text = String(c["desc"])
	_root.visible = true
	get_tree().paused = true

func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _current_cards[index]
	UpgradeApply.apply(_player, card["id"])
	if not _queue.is_empty():
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

func _pick_three(level: int) -> Array:
	var pool := Upgrades.cards_for_level(level, _player)
	pool.shuffle()
	return pool.slice(0, 3)

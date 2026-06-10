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
	_title.custom_minimum_size = Vector2(460, 0)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(_title, 18, PixelTheme.ACCENT)
	vbox.add_child(_title)

	for i in 3:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var b := Button.new()
		PixelTheme.style_button(b, Vector2(460, 64), 20)
		b.pressed.connect(_on_card_pressed.bind(i))
		row.add_child(b)
		_buttons.append(b)
		var desc := Label.new()
		desc.custom_minimum_size = Vector2(460, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(desc, 13, PixelTheme.TEXT_DIM)
		row.add_child(desc)
		_descs.append(desc)
		vbox.add_child(row)

func _on_player_leveled_up() -> void:
	_queue.append(_player.level)
	if not _root.visible:
		_show_next()

func _show_next() -> void:
	var lvl: int = _queue.pop_front()
	_current_cards = _pick_three(lvl)
	_title.text = "LEVEL %d — choose a %s upgrade" % [lvl, Upgrades.label_for_level(lvl)]
	for i in 3:
		var c: Dictionary = _current_cards[i]
		_buttons[i].text = String(c["title"]).to_upper()
		_descs[i].text = String(c["desc"])
	_root.visible = true
	get_tree().paused = true

func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _current_cards[index]
	Upgrades.apply(_player, card["id"])
	if not _queue.is_empty():
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

func _pick_three(level: int) -> Array:
	var pool := Upgrades.cards_for_level(level, _player)
	pool.shuffle()
	return pool.slice(0, 3)

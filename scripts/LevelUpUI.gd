extends CanvasLayer
## The level-up upgrade screen, built entirely in code. When the player levels up
## it pauses the game, dims the screen, and offers 3 random upgrade cards. Picking
## one applies it and resumes. Queues multiple level-ups if they happen at once.

var _player: Player
var _pending := 0
var _current_cards: Array = []

var _root: Control
var _title: Label
var _buttons: Array[Button] = []

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
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	_title = Label.new()
	_title.text = "LEVEL UP — choose an upgrade"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 72)
		b.pressed.connect(_on_card_pressed.bind(i))
		vbox.add_child(b)
		_buttons.append(b)

func _on_player_leveled_up() -> void:
	_pending += 1
	if not _root.visible:
		_show_next()

func _show_next() -> void:
	_current_cards = _pick_three()
	for i in 3:
		var c: Dictionary = _current_cards[i]
		_buttons[i].text = "%s\n%s" % [c["title"], c["desc"]]
	_root.visible = true
	get_tree().paused = true

func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _current_cards[index]
	Upgrades.apply(_player, card["id"])
	_pending -= 1
	if _pending > 0:
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

func _pick_three() -> Array:
	var pool := Upgrades.player_cards()
	pool.shuffle()
	return pool.slice(0, 3)

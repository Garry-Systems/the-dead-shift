extends CanvasLayer
## The pre-run weapon-select screen, built entirely in code. On _ready it pauses the
## game and offers all 5 weapons from Weapons.all(). Picking one calls
## player.gun.configure(def), then unpauses to start the run.

var _player: Player
var _weapons: Array = []

var _root: Control
var _buttons: Array[Button] = []

func _ready() -> void:
	# Keep this UI alive and clickable while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11

	_player = get_tree().get_first_node_in_group("player") as Player
	_weapons = Weapons.all()

	_build_ui()
	get_tree().paused = true

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE YOUR WEAPON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for i in _weapons.size():
		var def: Dictionary = _weapons[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 64)
		b.text = "%s\n%s" % [def["name"], def["desc"]]
		b.pressed.connect(_on_weapon_pressed.bind(i))
		vbox.add_child(b)
		_buttons.append(b)

func _on_weapon_pressed(index: int) -> void:
	var def: Dictionary = _weapons[index]
	if _player and _player.gun:
		_player.gun.configure(def)
	queue_free()
	get_tree().paused = false

extends CanvasLayer
## Top-right pause button + a pause overlay (Resume / Restart Run / Back to Menu).
## PROCESS_MODE_ALWAYS so the button and overlay work while the tree is paused. The
## button is inert if something else already paused the tree (a level-up / relic menu),
## so it can't stack a second pause on top of those.

var _overlay: Control
var _pause_btn: Button

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
	_pause_btn.anchor_left = 1.0
	_pause_btn.anchor_right = 1.0
	_pause_btn.offset_left = -68
	_pause_btn.offset_right = -12
	_pause_btn.offset_top = 36
	_pause_btn.offset_bottom = 92
	_pause_btn.pressed.connect(_on_pause_pressed)
	add_child(_pause_btn)

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(title)

	vbox.add_child(_menu_button("Resume", _on_resume))
	vbox.add_child(_menu_button("Restart Run", _on_restart))
	vbox.add_child(_menu_button("Back to Menu", _on_back))

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 64)
	b.text = text
	b.pressed.connect(cb)
	return b

func _on_pause_pressed() -> void:
	if get_tree().paused:
		return                       # another menu owns the pause; don't stack
	get_tree().paused = true
	_overlay.visible = true
	_pause_btn.visible = false

func _on_resume() -> void:
	_overlay.visible = false
	_pause_btn.visible = true
	get_tree().paused = false

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

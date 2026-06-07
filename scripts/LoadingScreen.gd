extends Control
## Boot splash (the project's main_scene once Task 14 flips it). Shows the menu
## background + title + a short loading bar, then switches to the main menu.

const LOAD_TIME := 1.2       # seconds of (cosmetic) loading before the menu

var _bar: ProgressBar
var _elapsed := 0.0

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://art/menu_background.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 120
	title.add_theme_font_size_override("font_size", 64)
	add_child(title)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -150
	_bar.offset_right = 150
	_bar.offset_top = -80
	_bar.offset_bottom = -60
	add_child(_bar)

func _process(delta: float) -> void:
	_elapsed += delta
	_bar.value = clampf(_elapsed / LOAD_TIME, 0.0, 1.0)
	if _elapsed >= LOAD_TIME:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

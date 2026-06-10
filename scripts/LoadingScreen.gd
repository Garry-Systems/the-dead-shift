extends Control
## Boot splash (the project's main_scene). Shows the dusk background + pixel title
## + a short amber loading bar, then switches to the main menu.

const LOAD_TIME := 1.2       # seconds of (cosmetic) loading before the menu

var _bar: ProgressBar
var _elapsed := 0.0

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://art/menu_background.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vignette := ColorRect.new()
	vignette.color = Color(0.04, 0.03, 0.06, 0.4)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	var title := Label.new()
	title.text = "SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.offset_top = 140
	PixelTheme.style_title(title, 52)
	add_child(title)

	var loading := Label.new()
	loading.text = "loading..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.anchor_left = 0.5
	loading.anchor_right = 0.5
	loading.offset_left = -120
	loading.offset_right = 120
	loading.anchor_top = 1.0
	loading.anchor_bottom = 1.0
	loading.offset_top = -110
	loading.offset_bottom = -86
	PixelTheme.style_label(loading, 16, PixelTheme.TEXT_DIM)
	add_child(loading)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_left = -150
	_bar.offset_right = 150
	_bar.offset_top = -76
	_bar.offset_bottom = -56
	_style_bar(_bar)
	add_child(_bar)

func _style_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = PixelTheme.BTN_BG
	bg.border_color = PixelTheme.ACCENT_DIM
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelTheme.ACCENT
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("fill", fill)

func _process(delta: float) -> void:
	_elapsed += delta
	_bar.value = clampf(_elapsed / LOAD_TIME, 0.0, 1.0)
	if _elapsed >= LOAD_TIME:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

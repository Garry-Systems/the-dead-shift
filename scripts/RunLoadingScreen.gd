extends Control
## "Clocking in" splash shown when a run starts: PLAY -> (this) -> Main.tscn.
## A short themed beat (~2.5s) so starting a run feels like clocking in for your shift.
## RunConfig (autoload) already holds the chosen mode + character across the scene change,
## so nothing needs to be passed in here.

const CLOCK_IN_TIME := 2.5     # seconds the clock-in screen holds before gameplay

var _bar: ProgressBar
var _elapsed := 0.0

func _ready() -> void:
	# Same dusk background + heavy void scrim the menu uses, for a consistent look.
	var bg := TextureRect.new()
	bg.texture = load("res://art/menu_background.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = Color(0.039, 0.0, 0.102, 0.86)   # C1 void
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)

	var title := Label.new()
	title.text = "CLOCKING IN..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_right = 1.0
	title.anchor_top = 0.5
	title.offset_top = -120
	PixelTheme.style_title(title, 38)
	add_child(title)

	var mode_label := Label.new()
	mode_label.text = _mode_text()
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.anchor_right = 1.0
	mode_label.anchor_top = 0.5
	mode_label.offset_top = -50
	PixelTheme.style_label(mode_label, 18, PixelTheme.TEXT_DIM)
	add_child(mode_label)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.anchor_top = 0.5
	_bar.anchor_bottom = 0.5
	_bar.offset_left = -150
	_bar.offset_right = 150
	_bar.offset_top = 4
	_bar.offset_bottom = 24
	_style_bar(_bar)
	add_child(_bar)

## Human-readable label for the mode being started.
func _mode_text() -> String:
	if RunConfig.daily:   # Pack C: Daily Shift is endless underneath — label it distinctly anyway
		return "DAILY SHIFT"
	match RunConfig.mode:
		"boss_rush": return "BOSS RUSH"
		_: return "ENDLESS"

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
	_bar.value = clampf(_elapsed / CLOCK_IN_TIME, 0.0, 1.0)
	if _elapsed >= CLOCK_IN_TIME:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/Main.tscn")

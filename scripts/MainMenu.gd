extends Control
## Main menu hub over the dusk background. Hosts PLAY (mode picker), CHARACTERS
## (select 1 of 3 — stored in RunConfig for the session), and INVENTORY (view-only
## collection of guns + characters). All UI built in code; sub-screens are toggled
## panels in this one scene.

var _hub: Control
var _mode_panel: Control
var _char_panel: Control
var _inv_panel: Control
var _char_buttons := {}        # character id -> Button (to highlight the selected one)

func _ready() -> void:
	_add_background()
	_build_hub()
	_build_mode_panel()
	_build_char_panel()
	_build_inventory_panel()
	_show_only(_hub)

func _add_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://art/menu_background.jpg")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

# --- shared UI helpers ---
func _make_panel() -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	return p

func _centered_vbox(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	return vbox

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(360, 64)
	b.text = text
	b.pressed.connect(cb)
	return b

func _show_only(panel: Control) -> void:
	_hub.visible = panel == _hub
	_mode_panel.visible = panel == _mode_panel
	_char_panel.visible = panel == _char_panel
	_inv_panel.visible = panel == _inv_panel

# --- hub ---
func _build_hub() -> void:
	_hub = _make_panel()
	var vbox := _centered_vbox(_hub)
	var title := Label.new()
	title.text = "SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(title)
	vbox.add_child(_make_button("PLAY", func(): _show_only(_mode_panel)))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_only(_char_panel)))
	vbox.add_child(_make_button("INVENTORY", func(): _show_only(_inv_panel)))

# --- mode picker ---
func _build_mode_panel() -> void:
	_mode_panel = _make_panel()
	var vbox := _centered_vbox(_mode_panel)
	var title := Label.new()
	title.text = "SELECT MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(_make_button("Endless", func(): _start_run("endless")))
	vbox.add_child(_make_button("Boss Rush", func(): _start_run("boss_rush")))
	var soon := Label.new()
	soon.text = "More modes coming soon"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soon.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(soon)
	vbox.add_child(_make_button("Back", func(): _show_only(_hub)))

func _start_run(mode: String) -> void:
	RunConfig.mode = mode
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- character select ---
func _build_char_panel() -> void:
	_char_panel = _make_panel()
	var vbox := _centered_vbox(_char_panel)
	var title := Label.new()
	title.text = "CHOOSE CHARACTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for c in Characters.all():
		var cid: String = c["id"]
		var btn := _make_button("%s\n%s" % [c["name"], c["desc"]], func(): _select_character(cid))
		_char_buttons[cid] = btn
		vbox.add_child(btn)
	vbox.add_child(_make_button("Back", func(): _show_only(_hub)))
	_refresh_char_labels()

func _select_character(id: String) -> void:
	RunConfig.character_id = id
	_refresh_char_labels()

func _refresh_char_labels() -> void:
	for id in _char_buttons:
		var selected: bool = id == RunConfig.character_id
		(_char_buttons[id] as Button).modulate = Color(0.4, 1.0, 0.4) if selected else Color(1, 1, 1)

# --- inventory (view-only collection) ---
func _build_inventory_panel() -> void:
	_inv_panel = _make_panel()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_inv_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "INVENTORY"
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)
	vbox.add_child(_make_button("Back", func(): _show_only(_hub)))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 560)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_add_inv_header(list, "WEAPONS")
	for w in Weapons.all():
		var line: String = "%s — dmg %d · rate %.2fs · range %d · proj %d" % [
			String(w["name"]), int(w["damage"]), float(w["fire_interval"]), int(w["range"]), int(w["projectiles"])]
		_add_inv_row(list, line, String(w["desc"]))

	_add_inv_header(list, "CHARACTERS")
	for c in Characters.all():
		_add_inv_row(list, String(c["name"]), String(c["desc"]))

func _add_inv_header(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	parent.add_child(l)

func _add_inv_row(parent: VBoxContainer, head: String, sub: String) -> void:
	var l := Label.new()
	l.text = "%s\n   %s" % [head, sub]
	parent.add_child(l)

extends Control
## Main menu hub over the dusk background. Hosts PLAY (mode picker), CHARACTERS
## (select 1 of 3 — stored in RunConfig for the session), and INVENTORY (view-only
## collection of guns + characters). All UI built in code with the shared PixelTheme;
## sub-screens are toggled panels in this one scene.

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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Darken the busy farmstead so pixel text stays readable.
	var vignette := ColorRect.new()
	vignette.color = Color(0.04, 0.03, 0.06, 0.35)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

# --- shared UI helpers ---
func _make_panel() -> Control:
	var p := Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	return p

## A centered translucent card with a VBox inside it for the menu content.
func _card_vbox(parent: Control, separation: int = 18) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	card.add_child(vbox)
	return vbox

func _make_title(parent: VBoxContainer, text: String, size: int = 44) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, size)
	parent.add_child(title)

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	PixelTheme.style_button(b)
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
	var vbox := _card_vbox(_hub, 20)
	_make_title(vbox, "SURVIVOR", 48)
	var tagline := Label.new()
	tagline.text = "stand still. stay alive."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(tagline, 16, PixelTheme.TEXT_DIM)
	vbox.add_child(tagline)
	var coins := Label.new()
	coins.text = "COINS: %d" % SaveManager.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 20, PixelTheme.ACCENT)
	vbox.add_child(coins)
	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", func(): _show_only(_mode_panel)))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_only(_char_panel)))
	vbox.add_child(_make_button("INVENTORY", func(): _show_only(_inv_panel)))

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# --- mode picker ---
func _build_mode_panel() -> void:
	_mode_panel = _make_panel()
	var vbox := _card_vbox(_mode_panel)
	_make_title(vbox, "SELECT MODE", 30)
	vbox.add_child(_spacer(4))
	vbox.add_child(_make_button("ENDLESS", func(): _start_run("endless")))
	vbox.add_child(_make_button("BOSS RUSH", func(): _start_run("boss_rush")))
	var soon := Label.new()
	soon.text = "more modes coming soon"
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(soon, 14, PixelTheme.TEXT_DIM)
	vbox.add_child(soon)
	vbox.add_child(_spacer(4))
	vbox.add_child(_make_button("BACK", func(): _show_only(_hub)))

func _start_run(mode: String) -> void:
	RunConfig.mode = mode
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# --- character select ---
func _build_char_panel() -> void:
	_char_panel = _make_panel()
	var vbox := _card_vbox(_char_panel, 14)
	_make_title(vbox, "CHARACTER", 30)
	vbox.add_child(_spacer(4))
	for c in Characters.all():
		var cid: String = c["id"]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var btn := _make_button(String(c["name"]).to_upper(), func(): _select_character(cid))
		_char_buttons[cid] = btn
		row.add_child(btn)
		var desc := Label.new()
		desc.text = String(c["desc"])
		desc.custom_minimum_size = Vector2(460, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(desc, 13, PixelTheme.TEXT_DIM)
		row.add_child(desc)
		vbox.add_child(row)
	vbox.add_child(_spacer(4))
	vbox.add_child(_make_button("BACK", func(): _show_only(_hub)))
	_refresh_char_labels()

func _select_character(id: String) -> void:
	RunConfig.character_id = id
	_refresh_char_labels()

func _refresh_char_labels() -> void:
	for id in _char_buttons:
		var selected: bool = id == RunConfig.character_id
		var b := _char_buttons[id] as Button
		b.add_theme_color_override("font_color", PixelTheme.SELECT if selected else PixelTheme.TEXT)

# --- inventory (view-only collection) ---
func _build_inventory_panel() -> void:
	_inv_panel = _make_panel()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inv_panel.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	card.custom_minimum_size = Vector2(620, 760)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	_make_title(vbox, "INVENTORY", 28)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 600)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_add_inv_header(list, "WEAPONS")
	for w in Weapons.all():
		var stats: String = "dmg %d  rate %.2fs  rng %d  proj %d  -  %s" % [
			int(w["damage"]), float(w["fire_interval"]), int(w["range"]), int(w["projectiles"]), String(w["desc"])]
		_add_inv_row(list, String(w["name"]), stats)

	_add_inv_header(list, "CHARACTERS")
	for c in Characters.all():
		_add_inv_row(list, String(c["name"]), String(c["desc"]))

	vbox.add_child(_make_button("BACK", func(): _show_only(_hub)))

func _add_inv_header(parent: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	PixelTheme.style_label(l, 22, PixelTheme.ACCENT)
	parent.add_child(l)

func _add_inv_row(parent: VBoxContainer, head: String, sub: String) -> void:
	var l := Label.new()
	l.text = head
	PixelTheme.style_label(l, 16, PixelTheme.TEXT)
	parent.add_child(l)
	var s := Label.new()
	s.text = "   " + sub
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(s, 13, PixelTheme.TEXT_DIM)
	parent.add_child(s)

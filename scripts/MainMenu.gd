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
var _inv_vbox: VBoxContainer   # inventory card content (rebuilt by _populate_inventory)
var _hub_coins: Label          # hub coin readout (refreshed when returning to hub)
var _inv_from_play := false    # true when the inventory was opened by PLAY (no weapon equipped)
var _detail_popup: WeaponDetailPopup   # reused modal shown when a tile is tapped

func _ready() -> void:
	Inventory.grant_starter()  # first-launch seed so the inventory is never empty
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
	# Heavy void (C1) scrim so the background reads as the dark palette, not the photo.
	var vignette := ColorRect.new()
	vignette.color = Color(0.039, 0.0, 0.102, 0.86)
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
	if panel == _hub and _hub_coins != null:
		_hub_coins.text = "COINS: %d" % SaveManager.coins()

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
	_hub_coins = Label.new()
	_hub_coins.text = "COINS: %d" % SaveManager.coins()
	_hub_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_hub_coins, 20, PixelTheme.ACCENT)
	vbox.add_child(_hub_coins)
	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", _on_play))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_only(_char_panel)))
	vbox.add_child(_make_button("INVENTORY", func(): _show_inventory(false)))

## PLAY: only proceed to the mode picker if a weapon is equipped; otherwise force the
## player into the inventory to pick one (Cancel there returns here to the menu).
func _on_play() -> void:
	if Inventory.equipped_instance().is_empty():
		_show_inventory(true)
	else:
		_show_only(_mode_panel)

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
		# SELECT (C4 lavender) vs TEXT_DIM (C3 gray-tan) — bright = chosen, dim = not.
		b.add_theme_color_override("font_color", PixelTheme.SELECT if selected else PixelTheme.TEXT_DIM)

# --- inventory: owned rolled weapons (tap to equip) + crates ---
func _build_inventory_panel() -> void:
	_inv_panel = _make_panel()

	# The card fills the screen minus a margin, so it always fits the viewport no
	# matter how tall/short the window is (no fixed height that can overflow).
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_inv_panel.add_child(margin)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	margin.add_child(card)

	_inv_vbox = VBoxContainer.new()
	_inv_vbox.add_theme_constant_override("separation", 10)
	card.add_child(_inv_vbox)
	# Contents are (re)built on every show by _populate_inventory().

	# Reusable detail popup, layered above the panel content.
	_detail_popup = WeaponDetailPopup.new()
	_inv_panel.add_child(_detail_popup)
	_detail_popup.equip_requested.connect(_on_equip)
	_detail_popup.scrap_confirmed.connect(_on_scrap)

## Opens the inventory. from_play=true means PLAY sent us here with no weapon equipped:
## picking a weapon then proceeds to the mode picker, and the bottom button reads CANCEL.
func _show_inventory(from_play: bool) -> void:
	_inv_from_play = from_play
	_populate_inventory()
	_show_only(_inv_panel)

func _populate_inventory() -> void:
	for c in _inv_vbox.get_children():
		c.queue_free()

	_make_title(_inv_vbox, "INVENTORY", 28)

	var coins := Label.new()
	coins.text = "COINS: %d" % Inventory.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 16, PixelTheme.ACCENT)
	_inv_vbox.add_child(coins)

	if _inv_from_play:
		var prompt := Label.new()
		prompt.text = "Equip a weapon to play"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(prompt, 14, PixelTheme.SELECT)
		_inv_vbox.add_child(prompt)

	# Crate buttons (disabled when you can't afford it / inventory full).
	var crate_row := HBoxContainer.new()
	crate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crate_row.add_theme_constant_override("separation", 10)
	_inv_vbox.add_child(crate_row)
	for crate in Crates.all():
		var cb := Button.new()
		cb.text = "%s (%d)" % [String(crate["name"]).to_upper(), int(crate["price"])]
		PixelTheme.style_button(cb, Vector2(250, 50), 14)
		cb.disabled = Inventory.coins() < int(crate["price"]) or Inventory.is_full()
		cb.pressed.connect(_on_crate.bind(String(crate["id"])))
		crate_row.add_child(cb)

	# Owned weapons as a tile grid, best rarity first; tap a tile for the detail popup.
	var owned := Inventory.weapons().duplicate()
	owned.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_uid := Inventory.equipped_uid()

	if owned.is_empty():
		var none := Label.new()
		none.text = "No weapons yet — open a crate."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 14, PixelTheme.TEXT_DIM)
		_inv_vbox.add_child(none)
	else:
		# Scroll fills the remaining card height (so the grid never overflows the
		# screen), scrolls vertically only; the 3-column block is centered.
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_inv_vbox.add_child(scroll)
		var grid_center := HBoxContainer.new()
		grid_center.alignment = BoxContainer.ALIGNMENT_CENTER
		grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid_center)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid_center.add_child(grid)
		for inst in owned:
			var tile := WeaponTile.new()
			grid.add_child(tile)
			tile.setup(inst, String(inst.get("uid", "")) == equipped_uid)
			tile.tile_pressed.connect(_on_tile_pressed)

	# Bottom button: CANCEL (forced-from-PLAY) or BACK — both return to the main menu.
	_inv_vbox.add_child(_make_button("CANCEL" if _inv_from_play else "BACK", _on_inv_back))

func _on_crate(crate_id: String) -> void:
	Inventory.open_crate(crate_id)
	_populate_inventory()

func _on_equip(inst: Dictionary) -> void:
	Inventory.equip(String(inst.get("uid", "")))
	if _inv_from_play:
		_inv_from_play = false
		_show_only(_mode_panel)   # weapon chosen → continue to the mode picker
	else:
		_populate_inventory()     # browsing → just refresh the EQUIPPED highlight

## Tile tapped → open the detail popup for that instance.
func _on_tile_pressed(inst: Dictionary) -> void:
	var is_eq: bool = String(inst.get("uid", "")) == Inventory.equipped_uid()
	_detail_popup.open(inst, is_eq)

## Scrap confirmed in the popup → deconstruct for coins and refresh the grid.
func _on_scrap(inst: Dictionary) -> void:
	Inventory.deconstruct(String(inst.get("uid", "")))
	_populate_inventory()

func _on_inv_back() -> void:
	_inv_from_play = false
	_show_only(_hub)

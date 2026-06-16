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
var _store_panel: Control
var _store_vbox: VBoxContainer
var _store_result: Label
var _last_unbox := ""                       # last crate outcome, shown in the store
var _last_unbox_color: Color = PixelTheme.TEXT
var _char_vbox: VBoxContainer    # character panel content (rebuilt by _populate_characters)
var _crate_opener: CrateOpener   # reused full-screen reel, opened from a crate tile

func _ready() -> void:
	Inventory.grant_starter()  # first-launch seed so the inventory is never empty
	SaveManager.grant_dev_bonus(10000)  # DEV (for now): one-time 10k coins to test the economy
	_add_background()
	_build_hub()
	_build_mode_panel()
	_build_char_panel()
	_build_inventory_panel()
	_build_store_panel()
	_ensure_valid_character()
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
	_store_panel.visible = panel == _store_panel
	if panel == _hub and _hub_coins != null:
		_hub_coins.text = "COINS: %d" % SaveManager.coins()

# --- hub ---
func _build_hub() -> void:
	_hub = _make_panel()
	var vbox := _card_vbox(_hub, 20)
	_make_title(vbox, "THE DEAD\nSHIFT", 60)
	var tagline := Label.new()
	tagline.text = "Your shift just got a lot longer."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.custom_minimum_size = Vector2(620, 0)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(tagline, 24, PixelTheme.TEXT_DIM)
	vbox.add_child(tagline)
	_hub_coins = Label.new()
	_hub_coins.text = "COINS: %d" % SaveManager.coins()
	_hub_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_hub_coins, 30, PixelTheme.ACCENT)
	vbox.add_child(_hub_coins)
	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", _on_play))
	vbox.add_child(_make_button("STORE", func(): _show_store()))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_characters()))
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
	_make_title(vbox, "SELECT MODE", 44)
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
	# Clock in for your shift: a short themed loading beat, then gameplay.
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

# --- character select ---
func _build_char_panel() -> void:
	_char_panel = _make_panel()
	_char_vbox = _card_vbox(_char_panel, 14)
	# Contents (re)built on show by _populate_characters() so store purchases show up.

func _show_characters() -> void:
	_ensure_valid_character()
	_populate_characters()
	_show_only(_char_panel)

func _populate_characters() -> void:
	for c in _char_vbox.get_children():
		c.queue_free()
	_char_buttons.clear()
	_make_title(_char_vbox, "CHARACTER", 44)
	_char_vbox.add_child(_spacer(4))
	for c in Characters.all():
		var cid: String = c["id"]
		var unlocked: bool = SaveManager.is_character_unlocked(cid)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var label_text: String = String(c["name"]).to_upper()
		if not unlocked:
			label_text = "🔒 " + label_text
		var btn := _make_button(label_text, func(): _select_character(cid))
		btn.disabled = not unlocked
		_char_buttons[cid] = btn
		row.add_child(btn)
		var desc := Label.new()
		desc.text = String(c["desc"]) if unlocked else "Unlock in the Store"
		desc.custom_minimum_size = Vector2(600, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(desc, 20, PixelTheme.TEXT_DIM)
		row.add_child(desc)
		_char_vbox.add_child(row)
	_char_vbox.add_child(_spacer(4))
	_char_vbox.add_child(_make_button("BACK", func(): _show_only(_hub)))
	_refresh_char_labels()

func _select_character(id: String) -> void:
	if not SaveManager.is_character_unlocked(id):
		return
	RunConfig.character_id = id
	_refresh_char_labels()

## Resets the chosen character to Ryan if the current one isn't unlocked.
func _ensure_valid_character() -> void:
	if not SaveManager.is_character_unlocked(RunConfig.character_id):
		RunConfig.character_id = "ryan"

func _refresh_char_labels() -> void:
	for id in _char_buttons:
		if not SaveManager.is_character_unlocked(id):
			continue   # locked buttons are disabled — let the disabled styling show
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
	_detail_popup.closed.connect(_populate_inventory)   # refresh the grid after viewing (e.g. a crate win)

	_crate_opener = CrateOpener.new()
	_inv_panel.add_child(_crate_opener)
	_crate_opener.closed.connect(_populate_inventory)
	_crate_opener.weapon_revealed.connect(_on_crate_weapon_revealed)

## Opens the inventory. from_play=true means PLAY sent us here with no weapon equipped:
## picking a weapon then proceeds to the mode picker, and the bottom button reads CANCEL.
func _show_inventory(from_play: bool) -> void:
	_inv_from_play = from_play
	_populate_inventory()
	_show_only(_inv_panel)

func _populate_inventory() -> void:
	for c in _inv_vbox.get_children():
		c.queue_free()

	_make_title(_inv_vbox, "INVENTORY", 44)

	var coins := Label.new()
	coins.text = "COINS: %d" % Inventory.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 26, PixelTheme.ACCENT)
	_inv_vbox.add_child(coins)

	if _inv_from_play:
		var prompt := Label.new()
		prompt.text = "Equip a weapon to play"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(prompt, 22, PixelTheme.SELECT)
		_inv_vbox.add_child(prompt)

	# Grid: owned crates first, then weapons (best rarity first). Tap a crate to open it,
	# a weapon for its detail popup.
	var owned := Inventory.weapons().duplicate()
	owned.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_uid := Inventory.equipped_uid()
	var owned_crates: Dictionary = SaveManager.crates()

	if owned.is_empty() and owned_crates.is_empty():
		var none := Label.new()
		none.text = "No weapons yet — buy a crate in the Store."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 20, PixelTheme.TEXT_DIM)
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
		for crate_id in owned_crates:
			var ct := CrateTile.new()
			grid.add_child(ct)
			ct.setup(Crates.get_crate(String(crate_id)), int(owned_crates[crate_id]))
			ct.crate_pressed.connect(_on_crate_tile_pressed)
		for inst in owned:
			var tile := WeaponTile.new()
			grid.add_child(tile)
			tile.setup(inst, String(inst.get("uid", "")) == equipped_uid)
			tile.tile_pressed.connect(_on_tile_pressed)

	# Bottom button: CANCEL (forced-from-PLAY) or BACK — both return to the main menu.
	var inv_back := _make_button("CANCEL" if _inv_from_play else "BACK", _on_inv_back)
	inv_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inv_vbox.add_child(inv_back)

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

## Crate tile tapped → open the CS:GO reel for that crate.
func _on_crate_tile_pressed(crate_id: String) -> void:
	_crate_opener.open(crate_id)

## The reel landed on a weapon → show the SAME full inspect popup as tapping a gun in the grid.
func _on_crate_weapon_revealed(inst: Dictionary) -> void:
	_detail_popup.open(inst, String(inst.get("uid", "")) == Inventory.equipped_uid())

## Scrap confirmed in the popup → deconstruct for coins and refresh the grid.
func _on_scrap(inst: Dictionary) -> void:
	Inventory.deconstruct(String(inst.get("uid", "")))
	_populate_inventory()

# --- store: spend coins to unlock characters + buy crates ---
func _build_store_panel() -> void:
	_store_panel = _make_panel()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_store_panel.add_child(margin)
	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	margin.add_child(card)
	_store_vbox = VBoxContainer.new()
	_store_vbox.add_theme_constant_override("separation", 10)
	card.add_child(_store_vbox)

func _show_store() -> void:
	_last_unbox = ""
	_populate_store()
	_show_only(_store_panel)

func _store_header(parent: VBoxContainer, text: String) -> void:
	var h := Label.new()
	h.text = text
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(h, 26, PixelTheme.ACCENT)
	parent.add_child(h)

func _populate_store() -> void:
	for c in _store_vbox.get_children():
		c.queue_free()

	_make_title(_store_vbox, "STORE", 44)

	var coins := Label.new()
	coins.text = "COINS: %d" % SaveManager.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 26, PixelTheme.ACCENT)
	_store_vbox.add_child(coins)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_store_vbox.add_child(scroll)
	# Center a fixed-width column inside the full-width scroll so buttons don't stretch
	# edge-to-edge. The HBox centers; the list shrinks to its widest child (the buttons).
	var center_row := HBoxContainer.new()
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_row)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	center_row.add_child(list)

	# Characters
	_store_header(list, "CHARACTERS")
	for c in Characters.all():
		var cid: String = c["id"]
		var price: int = int(c.get("price", 0))
		var owned: bool = SaveManager.is_character_unlocked(cid)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var b := Button.new()
		if owned:
			b.text = "%s — OWNED" % String(c["name"]).to_upper()
			b.disabled = true
		else:
			b.text = "%s — UNLOCK %d" % [String(c["name"]).to_upper(), price]
			b.disabled = SaveManager.coins() < price
			b.pressed.connect(_on_buy_character.bind(cid, price))
		PixelTheme.style_button(b, Vector2(660, 92), 22)
		row.add_child(b)
		var desc := Label.new()
		desc.text = String(c["desc"])
		desc.custom_minimum_size = Vector2(660, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(desc, 18, PixelTheme.TEXT_DIM)
		row.add_child(desc)
		list.add_child(row)

	# Crates
	_store_header(list, "CRATES")
	for crate in Crates.all():
		var cb := Button.new()
		cb.text = "%s — %d" % [String(crate["name"]).to_upper(), int(crate["price"])]
		PixelTheme.style_button(cb, Vector2(660, 88), 22)
		cb.disabled = SaveManager.coins() < int(crate["price"])
		cb.pressed.connect(_on_buy_crate.bind(String(crate["id"])))
		list.add_child(cb)

	_store_result = Label.new()
	_store_result.text = _last_unbox
	_store_result.custom_minimum_size = Vector2(660, 0)
	_store_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_store_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_store_result, 18, _last_unbox_color)
	list.add_child(_store_result)

	var back := _make_button("BACK", func(): _show_only(_hub))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_store_vbox.add_child(back)

func _on_buy_character(id: String, price: int) -> void:
	if SaveManager.is_character_unlocked(id):
		return
	if not SaveManager.spend_coins(price):
		return
	SaveManager.unlock_character(id)
	SaveManager.save_game()
	_populate_store()

func _on_buy_crate(crate_id: String) -> void:
	if Inventory.buy_crate(crate_id):
		_last_unbox = "%s added to inventory." % String(Crates.get_crate(crate_id).get("name", "Crate"))
		_last_unbox_color = PixelTheme.SELECT
	else:
		_last_unbox = "Not enough coins."
		_last_unbox_color = PixelTheme.TEXT_DIM
	_populate_store()

func _on_inv_back() -> void:
	_inv_from_play = false
	_show_only(_hub)

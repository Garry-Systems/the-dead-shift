extends Control
## Main menu hub over the dusk background. Hosts PLAY (mode picker), CHARACTERS
## (select 1 of 3 — stored in RunConfig for the session), and INVENTORY (view-only
## collection of guns + characters). All UI built in code with the shared PixelTheme;
## sub-screens are toggled panels in this one scene.

var _hub: Control
var _mode_panel: Control
var _char_panel: Control
var _inv_panel: Control
var _records_panel: Control
var _records_vbox: VBoxContainer   # records list content (rebuilt by _populate_records)
var _records_scroll: ScrollContainer   # current records list scroll (null when not shown)
var _char_buttons := {}        # character id -> Button (to highlight the selected one)
var _daily_btn: Button         # DAILY SHIFT button (mode panel) — refreshed on every show (Pack C)
var _horde_btn: Button         # HORDE NIGHT button (mode panel) — locked/unlocked by rank (Pack G)
var _overtime_btn: Button      # OVERTIME button (mode panel) — locked/unlocked by rank (Pack G)
var _hardcore_btn: Button      # HARDCORE button (mode panel) — locked/unlocked by rank (Pack G)
var _hub_rank_label: Label     # hub "RANK N — NAME" readout (Pack G), refreshed alongside _hub_coins
var _hub_rank_bar: ProgressBar # hub progress-toward-next-rank bar (Pack G)
var _inv_vbox: VBoxContainer   # inventory card content (rebuilt by _populate_inventory)
var _hub_coins: Label          # hub coin readout (refreshed when returning to hub)
var _inv_from_play := false    # true when the inventory was opened by PLAY (no weapon equipped)
var _detail_popup: WeaponDetailPopup   # reused modal shown when a tile is tapped

# Drag-anywhere scrolling for the inventory grid, the store list, AND the records list: a drag
# that starts ANYWHERE on the screen (even on a tile/button) scrolls; a plain tap still selects.
# Driven from _input so the gesture is caught before the GUI consumes it. State is shared — only
# one of these lists is visible at a time.
var _inv_scroll: ScrollContainer       # current inventory grid scroll (null when grid is empty / not shown)
var _store_scroll: ScrollContainer     # current store list scroll (null when not shown)
var _inv_touch_id := -1
var _inv_touch_start := Vector2.ZERO
var _inv_dragging := false
var _inv_suppress_tap := false         # set on a drag-release so the ending touch is not a tap (inventory tiles + store buttons)
const INV_DRAG_THRESHOLD := 24.0       # px of movement before a touch becomes a scroll (vs a tap)
var _store_panel: Control
var _store_vbox: VBoxContainer
var _store_result: Label
var _inv_result: Label                      # inventory-panel counterpart of _store_result
var _last_unbox := ""                       # last crate outcome, shown in the store or inventory
var _last_unbox_color: Color = PixelTheme.TEXT
var _char_vbox: VBoxContainer    # character panel content (rebuilt by _populate_characters)
var _crate_opener: CrateOpener   # reused full-screen reel, opened from a crate tile

## A crate win at this rarity or better (Carnage/red and up) rains confetti on reveal.
const CONFETTI_MIN_RARITY := 6

var _reward_popup: RewardPopup   # reveals daily-login + every-10-games free rewards on entry
var _reward_queue: Array = []    # pending {title, reward} dicts shown one at a time
var _current_reward: Dictionary = {}   # the reward dict currently shown in _reward_popup (kind/crate_id/inst)
var _reward_flow_active := false       # true while a reward-claimed crate is spinning the reel (Pack 1)

var _sfx_btn: Button      # hub SFX ON/OFF toggle (text refreshed on press)
var _music_btn: Button    # hub MUSIC ON/OFF toggle
var _effects_btn: Button  # hub EFFECTS ON/OFF toggle — screen shake + crit-kill hit-stop (Pack D)

func _ready() -> void:
	SoundManager.music("menu_loop")
	Inventory.grant_starter()  # first-launch seed so the inventory is never empty
	SaveManager.grant_dev_bonus(30000)  # DEV (for now): one-time 30k coins to test the economy
	_add_background()
	_build_hub()
	_build_mode_panel()
	_build_char_panel()
	_build_inventory_panel()
	_build_records_panel()
	_build_store_panel()
	_build_reward_popup()
	_ensure_valid_character()
	_show_only(_hub)
	# The pay-stub's STORE button (GameOver) sets this before returning here — land straight
	# in the store instead of the hub, one-shot (consumed immediately).
	if RunConfig.open_store_on_menu:
		RunConfig.open_store_on_menu = false
		_show_store()
	# Hand out any free rewards earned since last time (daily login + every-10-games), over the hub.
	_check_free_rewards()

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

func _make_title(parent: VBoxContainer, text: String, size: int = 57) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, size)
	parent.add_child(title)

## Shared button factory for the hub/mode/character/inventory panels (the "main menu" chokepoint
## for the generic ui_tap sound — the STORE's buy buttons play "purchase"/"coin" instead, wired
## at their own call sites). `min_size`/`font_size` default to the big menu-button look; pass
## smaller ones for compact rows like the SFX/MUSIC toggles.
func _make_button(text: String, cb: Callable, min_size: Vector2 = Vector2(806, 135), font_size: int = 39) -> Button:
	var b := Button.new()
	b.text = text
	PixelTheme.style_button(b, min_size, font_size)
	b.pressed.connect(func(): SoundManager.play("ui_tap"); cb.call())
	return b

func _show_only(panel: Control) -> void:
	_hub.visible = panel == _hub
	_mode_panel.visible = panel == _mode_panel
	_char_panel.visible = panel == _char_panel
	_inv_panel.visible = panel == _inv_panel
	_records_panel.visible = panel == _records_panel
	_store_panel.visible = panel == _store_panel
	if panel == _hub and _hub_coins != null:
		_hub_coins.text = "COINS: %d" % SaveManager.coins()
		_refresh_hub_rank()

# --- hub ---
func _build_hub() -> void:
	_hub = _make_panel()
	var vbox := _card_vbox(_hub, 20)
	_make_title(vbox, "THE DEAD\nSHIFT", 78)
	var tagline := Label.new()
	tagline.text = "Your shift just got a lot longer."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.custom_minimum_size = Vector2(800, 0)
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(tagline, 31, PixelTheme.TEXT_DIM)
	vbox.add_child(tagline)
	_hub_coins = Label.new()
	_hub_coins.text = "COINS: %d" % SaveManager.coins()
	_hub_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_hub_coins, 39, PixelTheme.ACCENT)
	vbox.add_child(_hub_coins)

	# Employee Rank readout (Pack G): name label + a thin progress bar toward the next rank.
	# 806px wide — matches the PLAY button's own custom_minimum_size below (the widest element
	# already proven to fit: 806 + the card's 64px content margins = 870, inside the 1080px
	# portrait viewport — same "compute width vs 1080" check the toggle row's comment documents).
	_hub_rank_label = Label.new()
	_hub_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_hub_rank_label, 22, PixelTheme.SELECT)
	vbox.add_child(_hub_rank_label)
	_hub_rank_bar = ProgressBar.new()
	_hub_rank_bar.show_percentage = false
	_hub_rank_bar.custom_minimum_size = Vector2(806, 22)
	_hub_rank_bar.max_value = 1.0
	_style_rank_bar(_hub_rank_bar)
	vbox.add_child(_hub_rank_bar)

	vbox.add_child(_spacer(8))
	vbox.add_child(_make_button("PLAY", _on_play))
	vbox.add_child(_make_button("STORE", func(): _show_store()))
	vbox.add_child(_make_button("CHARACTERS", func(): _show_characters()))
	vbox.add_child(_make_button("INVENTORY", func(): _show_inventory(false)))
	vbox.add_child(_make_button("RECORDS", func(): _show_records()))
	vbox.add_child(_spacer(4))
	var toggle_row := HBoxContainer.new()
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_row.add_theme_constant_override("separation", 10)
	# 320px per button: 3x320 + 2x10 separation = 980px row + 64px card content margins = 1044px
	# card, inside the 1080px portrait viewport (3x360 would overflow at 1164px). The longest
	# label ("EFFECTS: OFF") is ~180px at Silkscreen 18 vs the button's 280px text space (320
	# minus 2x20 stylebox margins), so no button auto-grows past its minimum.
	_sfx_btn = _make_button(_sfx_label(), _on_toggle_sfx, Vector2(320, 68), 18)
	_music_btn = _make_button(_music_label(), _on_toggle_music, Vector2(320, 68), 18)
	_effects_btn = _make_button(_effects_label(), _on_toggle_effects, Vector2(320, 68), 18)
	toggle_row.add_child(_sfx_btn)
	toggle_row.add_child(_music_btn)
	toggle_row.add_child(_effects_btn)
	vbox.add_child(toggle_row)

## PLAY: only proceed to the mode picker if a weapon is equipped; otherwise force the
## player into the inventory to pick one (Cancel there returns here to the menu).
func _on_play() -> void:
	if Inventory.equipped_instance().is_empty():
		_show_inventory(true)
	else:
		_show_mode_panel()

## Shows the mode picker, first refreshing the DAILY SHIFT button's available/grayed state —
## the calendar day can turn over while the app sits on another panel, so this can't just be
## baked in once at _build_mode_panel() time.
func _show_mode_panel() -> void:
	_refresh_daily_button()
	_refresh_mode_lock_buttons()
	_show_only(_mode_panel)

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

# --- SFX / Music toggles (hub row; PauseMenu has its own matching pair) ---
func _sfx_label() -> String:
	return "SFX: ON" if SoundManager.sfx_on() else "SFX: OFF"

func _music_label() -> String:
	return "MUSIC: ON" if SoundManager.music_on() else "MUSIC: OFF"

func _on_toggle_sfx() -> void:
	SoundManager.set_sfx_on(not SoundManager.sfx_on())
	_sfx_btn.text = _sfx_label()

func _on_toggle_music() -> void:
	SoundManager.set_music_on(not SoundManager.music_on())
	_music_btn.text = _music_label()

# --- EFFECTS toggle (Pack D): gates screen shake AND crit-kill hit-stop together ---
func _effects_label() -> String:
	return "EFFECTS: ON" if SaveManager.shake_on() else "EFFECTS: OFF"

func _on_toggle_effects() -> void:
	SaveManager.set_shake_on(not SaveManager.shake_on())
	SaveManager.save_game()
	_effects_btn.text = _effects_label()

# --- Employee Rank hub readout (Pack G) ---

## Hard-cornered progress bar matching Hud._style_bar's look, filled in the C4 ACCENT color.
func _style_rank_bar(bar: ProgressBar) -> void:
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

## Refreshes the hub's rank name + progress bar. Called whenever the hub becomes the visible
## panel (see _show_only) — the same chokepoint the coin readout already uses.
func _refresh_hub_rank() -> void:
	if _hub_rank_label == null:
		return
	var xp := SaveManager.rank_xp()
	var rank := Ranks.rank_for(xp)
	_hub_rank_label.text = "RANK %d — %s" % [rank, Ranks.name_for(rank)]
	_hub_rank_bar.value = Ranks.progress_in_rank(xp)

# --- mode picker ---
func _build_mode_panel() -> void:
	_mode_panel = _make_panel()
	var vbox := _card_vbox(_mode_panel)
	_make_title(vbox, "SELECT MODE", 44)
	vbox.add_child(_spacer(4))
	vbox.add_child(_make_button("ENDLESS", func(): _start_run("endless")))
	vbox.add_child(_make_button("BOSS RUSH", func(): _start_run("boss_rush")))
	_daily_btn = _make_button("DAILY SHIFT", _on_daily_shift)
	vbox.add_child(_daily_btn)
	# Pack G: 3 unlockable modes, gated by Employee Rank (Ranks.UNLOCKS) — locked buttons are
	# disabled + read "<NAME> — UNLOCKS AT <RANK NAME>" (PixelTheme's disabled font color already
	# renders them dim, matching the CHARACTERS panel's locked-button look).
	_horde_btn = _make_button("HORDE NIGHT", func(): _start_run("horde"))
	vbox.add_child(_horde_btn)
	_overtime_btn = _make_button("OVERTIME", _start_overtime)
	vbox.add_child(_overtime_btn)
	_hardcore_btn = _make_button("HARDCORE", _start_hardcore)
	vbox.add_child(_hardcore_btn)
	vbox.add_child(_spacer(4))
	vbox.add_child(_make_button("BACK", func(): _show_only(_hub)))

## `mode` is "endless" | "boss_rush" | "horde" — the three mode-select launches that don't carry
## a hardcore/overtime flag. HORDE re-checks its own unlock defensively (mirrors the DAILY SHIFT
## precedent below) even though the button is already disabled while locked.
func _start_run(mode: String) -> void:
	if mode == "horde" and not Ranks.is_unlocked("horde", SaveManager.rank_xp()):
		return
	RunConfig.mode = mode
	RunConfig.clear_mode_flags()   # a normal mode pick can never inherit a stale daily/hardcore/overtime flag
	# Clock in for your shift: a short themed loading beat, then gameplay.
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

## OVERTIME (Pack G): endless underneath (RunConfig.mode stays "endless" — every endless-only
## gate keeps working), flagged via RunConfig.overtime. Re-checks its own unlock defensively.
func _start_overtime() -> void:
	if not Ranks.is_unlocked("overtime", SaveManager.rank_xp()):
		return
	RunConfig.mode = "endless"
	RunConfig.clear_mode_flags()
	RunConfig.overtime = true
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

## HARDCORE (Pack G): endless underneath, flagged via RunConfig.hardcore. Re-checks its own unlock
## defensively.
func _start_hardcore() -> void:
	if not Ranks.is_unlocked("hardcore", SaveManager.rank_xp()):
		return
	RunConfig.mode = "endless"
	RunConfig.clear_mode_flags()
	RunConfig.hardcore = true
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

## Pack C: Daily Shift — one attempt per calendar day, consumed the instant this fires (not on
## completion): quitting or dying mid-shift never refunds it. Guarded defensively even though the
## button is disabled while unavailable (_refresh_daily_button), in case this is ever wired
## elsewhere. Always endless underneath, seeded from today's date for the NightEvents/elite/
## enemy-type rolls only (see RunConfig.start_daily's doc comment) — loot/talents stay global RNG.
func _on_daily_shift() -> void:
	if not SaveManager.is_daily_shift_available():
		return
	RunConfig.mode = "endless"
	RunConfig.clear_mode_flags()   # a Daily Shift pick can never inherit a stale hardcore/overtime flag
	RunConfig.start_daily(SaveManager.today_string())
	SaveManager.mark_daily_shift_started()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

## Refreshes the DAILY SHIFT button's text/enabled state to today's availability. Called every
## time the mode panel is about to show (see _show_mode_panel) — a day boundary or a just-finished
## Daily Shift run can change this between two mode-panel visits in the same app session.
func _refresh_daily_button() -> void:
	if _daily_btn == null:
		return
	var available := SaveManager.is_daily_shift_available()
	_daily_btn.disabled = not available
	_daily_btn.text = "DAILY SHIFT" if available else "DAILY SHIFT — TOMORROW"

## Refreshes the 3 unlockable mode buttons' disabled/text state to the player's current rank.
## Called every time the mode panel is about to show (see _show_mode_panel) — a promotion earned
## since the last visit can change this between two mode-panel visits in the same app session.
func _refresh_mode_lock_buttons() -> void:
	_apply_mode_lock(_horde_btn, "horde", "HORDE NIGHT")
	_apply_mode_lock(_overtime_btn, "overtime", "OVERTIME")
	_apply_mode_lock(_hardcore_btn, "hardcore", "HARDCORE")

func _apply_mode_lock(btn: Button, mode_id: String, label: String) -> void:
	if btn == null:
		return
	var unlocked := Ranks.is_unlocked(mode_id, SaveManager.rank_xp())
	btn.disabled = not unlocked
	btn.text = label if unlocked else "%s — %s" % [label, Ranks.lock_text(mode_id)]

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
	_detail_popup.fuse_requested.connect(_on_fuse)
	_detail_popup.closed.connect(_on_detail_popup_closed)   # refresh the grid after viewing (e.g. a crate win)

	_crate_opener = CrateOpener.new()
	_inv_panel.add_child(_crate_opener)
	_crate_opener.closed.connect(_on_crate_opener_closed)
	_crate_opener.weapon_revealed.connect(_on_crate_weapon_revealed)

## Opens the inventory. from_play=true means PLAY sent us here with no weapon equipped:
## picking a weapon then proceeds to the mode picker, and the bottom button reads CANCEL.
func _show_inventory(from_play: bool) -> void:
	_inv_from_play = from_play
	_last_unbox = ""
	_populate_inventory()
	_show_only(_inv_panel)

func _populate_inventory() -> void:
	for c in _inv_vbox.get_children():
		c.queue_free()
	_inv_scroll = null   # cleared each rebuild; re-set below only when a scrollable grid exists

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
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # built-in touch scroll off; we drive it from _input so a drag anywhere (even on a tile) scrolls
		_inv_scroll = scroll
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

	_inv_result = Label.new()
	_inv_result.text = _last_unbox
	_inv_result.custom_minimum_size = Vector2(660, 0)
	_inv_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_inv_result, 18, _last_unbox_color)
	_inv_vbox.add_child(_inv_result)

	# Bottom button: CANCEL (forced-from-PLAY) or BACK — both return to the main menu.
	var inv_back := _make_button("CANCEL" if _inv_from_play else "BACK", _on_inv_back)
	inv_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inv_vbox.add_child(inv_back)

func _on_equip(inst: Dictionary) -> void:
	Inventory.equip(String(inst.get("uid", "")))
	if _inv_from_play:
		_inv_from_play = false
		_show_mode_panel()   # weapon chosen → continue to the mode picker
	else:
		_populate_inventory()     # browsing → just refresh the EQUIPPED highlight

## Drag ANYWHERE on the inventory screen to scroll the grid; a plain tap still selects a
## tile. Read at the _input stage (before the GUI) so a drag that starts on a tile still
## scrolls. We never consume the event, so taps still reach the tile Buttons — instead we
## flag _inv_suppress_tap on a drag-release so the ending touch isn't treated as a tap.
func _input(event: InputEvent) -> void:
	# Resolve which list is currently drag-scrollable (inventory or store; one at a time).
	var sc: ScrollContainer = null
	if _inv_panel.visible and _inv_scroll != null and not (_detail_popup.visible or _crate_opener.visible):
		sc = _inv_scroll
	elif _store_panel.visible and _store_scroll != null:
		sc = _store_scroll
	elif _records_panel.visible and _records_scroll != null:
		sc = _records_scroll
	if sc == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _inv_touch_id == -1:   # claim only when no touch is already tracked — a second
				_inv_touch_id = event.index          # simultaneous finger must not steal the drag
				_inv_touch_start = event.position
				_inv_dragging = false
		elif event.index == _inv_touch_id:
			_inv_suppress_tap = _inv_dragging   # a drag-release must not count as a tap
			_inv_touch_id = -1
			_inv_dragging = false
	elif event is InputEventScreenDrag and event.index == _inv_touch_id:
		if not _inv_dragging and event.position.distance_to(_inv_touch_start) > INV_DRAG_THRESHOLD:
			_inv_dragging = true
		if _inv_dragging:
			sc.scroll_vertical -= int(event.relative.y)

## Wraps a zero-arg button callback so it's a no-op when the press was actually the END of a
## scroll drag (drag-anywhere scrolling for the store list). Mirrors the inventory tap guards.
func _guarded(cb: Callable) -> Callable:
	return func() -> void:
		if _inv_suppress_tap:
			_inv_suppress_tap = false
			return
		cb.call()

## Tile tapped → open the detail popup for that instance.
func _on_tile_pressed(inst: Dictionary) -> void:
	if _inv_suppress_tap:
		_inv_suppress_tap = false
		return                                  # this "tap" was the end of a scroll drag
	var is_eq: bool = String(inst.get("uid", "")) == Inventory.equipped_uid()
	_detail_popup.open(inst, is_eq)

## Crate tile tapped → open the CS:GO reel for that crate.
func _on_crate_tile_pressed(crate_id: String) -> void:
	if _inv_suppress_tap:
		_inv_suppress_tap = false
		return                                  # this "tap" was the end of a scroll drag
	if not _crate_opener.open(crate_id):
		_last_unbox = "Inventory full — scrap a weapon first."
		_last_unbox_color = PixelTheme.TEXT_DIM
		_populate_inventory()

## Switches to the inventory panel (the CrateOpener and the WeaponDetailPopup that follows a
## win are both children of _inv_panel, so they only actually render while it's the visible
## panel) and starts the reel for `crate_id`. Shared by the store buy-path and the free-reward
## claim-path so both reuse the exact same reel/reveal flow as tapping a crate tile. Returns
## false (still navigates to the inventory so the failure message has somewhere to show) if
## the crate can't open right now — mirrors CrateOpener.open()'s own guard (not owned / the
## weapon cap is full); a reel already spinning is a no-op inside CrateOpener.open() itself.
func _open_crate_reel(crate_id: String) -> bool:
	_last_unbox = ""
	_populate_inventory()
	_show_only(_inv_panel)
	return _crate_opener.open(crate_id)

## The reel landed on a weapon → show the SAME full inspect popup as tapping a gun in the grid,
## and rain confetti over the reveal for a rare (orange+) win.
func _on_crate_weapon_revealed(inst: Dictionary) -> void:
	_last_unbox = ""   # success supersedes any earlier "Inventory full" failure message
	_detail_popup.open(inst, String(inst.get("uid", "")) == Inventory.equipped_uid())
	if int(inst.get("rarity", 1)) >= CONFETTI_MIN_RARITY:
		_celebrate(WeaponInstance.color(inst))

## CrateOpener closed WITHOUT a reveal (the only path: Inventory.commit_crate failed on
## settle, e.g. the cap filled the instant the reel landed). Refresh the grid and, if this
## reel was part of a reward claim, resume the reward queue.
func _on_crate_opener_closed() -> void:
	_populate_inventory()
	_maybe_resume_reward_queue()

## The weapon-detail popup closed (browsing a tile OR the post-reel reveal). Refresh the grid
## and, if this was the reveal for a reward-claimed crate, resume the reward queue.
func _on_detail_popup_closed() -> void:
	_populate_inventory()
	_maybe_resume_reward_queue()

## No-op unless a reward-claimed crate reel is actually in progress (a plain tile tap or a
## store buy never sets the flag) — resumes the reward queue.
func _maybe_resume_reward_queue() -> void:
	if not _reward_flow_active:
		return
	_reward_flow_active = false
	_advance_reward_queue()

## Normalizes back to the hub (undoing a crate reward's detour to the inventory panel) before
## showing the next queued reward, or before landing once the queue is empty — every reward
## popup appears over the hub, same as pre-Pack-1.
func _advance_reward_queue() -> void:
	if not _hub.visible:
		_show_only(_hub)
	_show_next_reward()

## Confetti pop over the inventory panel, tinted toward the won weapon's rarity color.
func _celebrate(rarity_color: Color) -> void:
	var c := Confetti.new()
	_inv_panel.add_child(c)
	var vp := get_viewport_rect().size
	c.position = Vector2(vp.x * 0.5, vp.y * 0.42)
	c.burst(130, [rarity_color])

## Scrap confirmed in the popup → deconstruct for coins and refresh the grid.
func _on_scrap(inst: Dictionary) -> void:
	Inventory.deconstruct(String(inst.get("uid", "")))
	_last_unbox = ""   # a slot just freed — drop a stale "Inventory full" prompt before re-render
	_populate_inventory()

## FEED confirmed in the popup (Pack B: weapon fusion) → perform the Inventory.fuse()
## mutation here (the owner), then hand the result BACK to the SAME popup so it refreshes
## in place instead of closing. The inventory grid behind it is refreshed lazily when the
## popup eventually closes, same as the crate-reveal flow's `closed` -> _populate_inventory().
func _on_fuse(inst: Dictionary, sacrifice_uid: String) -> void:
	var result := Inventory.fuse(String(inst.get("uid", "")), sacrifice_uid)
	if not result.is_empty():
		SoundManager.play("crate_win")   # reuse the crate-win sting — no new audio for fusion
		_last_unbox = ""   # a slot just freed — drop a stale "Inventory full" prompt before the popup-close re-render
	_detail_popup.show_fuse_result(result)

# --- records: lifetime stats (view-only), same card/scroll shape as the store/inventory ---
func _build_records_panel() -> void:
	_records_panel = _make_panel()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_records_panel.add_child(margin)
	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	margin.add_child(card)
	_records_vbox = VBoxContainer.new()
	_records_vbox.add_theme_constant_override("separation", 10)
	card.add_child(_records_vbox)
	# Contents are (re)built on every show by _populate_records().

func _show_records() -> void:
	_populate_records()
	_show_only(_records_panel)

## A left label (expands) + a right, right-aligned value — mirrors GameOver._row's pay-stub shape.
func _stat_row(parent: VBoxContainer, left: String, right: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = left
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelTheme.style_label(name_l, 20, PixelTheme.TEXT_DIM)
	line.add_child(name_l)
	var val_l := Label.new()
	val_l.text = right
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelTheme.style_label(val_l, 20, PixelTheme.TEXT)
	line.add_child(val_l)
	parent.add_child(line)

## One "TODAY'S CHALLENGES" row (Pack C): reward-crate icon, desc (formatted with the target if
## it has a "%d" placeholder — 3 of the 12 rows are pure booleans and have none), and a right-
## aligned progress readout. Completed rows highlight in ACCENT/SELECT instead of TEXT/TEXT_DIM.
func _challenge_row(parent: VBoxContainer, row: Dictionary) -> void:
	var completed: bool = bool(row.get("completed", false))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.texture = Crates.icon(String(row.get("reward_crate_id", "")))
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.add_child(icon)

	var desc_l := Label.new()
	desc_l.text = _challenge_desc(row)
	desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(desc_l, 18, PixelTheme.SELECT if completed else PixelTheme.TEXT)
	line.add_child(desc_l)

	var prog_l := Label.new()
	prog_l.text = "DONE" if completed else _challenge_progress_text(row)
	prog_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelTheme.style_label(prog_l, 16, PixelTheme.ACCENT if completed else PixelTheme.TEXT_DIM)
	line.add_child(prog_l)

	parent.add_child(line)

func _challenge_desc(row: Dictionary) -> String:
	var desc := String(row.get("desc", ""))
	if desc.find("%d") == -1:
		return desc
	return desc % int(row.get("target", 0))

## "reach_2am" reads better as clock times than raw seconds; everything else is a plain count.
func _challenge_progress_text(row: Dictionary) -> String:
	var target: float = float(row.get("target", 0.0))
	var progress: float = float(row.get("progress", 0.0))
	if String(row.get("counter_key", "")) == "clock_seconds":
		return "%s / %s" % [ShiftClock.clock_string(progress), ShiftClock.clock_string(target)]
	return "%d / %d" % [int(progress), int(target)]

func _populate_records() -> void:
	for c in _records_vbox.get_children():
		c.queue_free()
	_records_scroll = null   # cleared each rebuild; re-set below

	_make_title(_records_vbox, "RECORDS", 44)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # built-in touch scroll off; driven from _input like the store/inventory
	_records_scroll = scroll
	_records_vbox.add_child(scroll)
	var center_row := HBoxContainer.new()
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_row)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size = Vector2(660, 0)
	center_row.add_child(list)

	# --- Pack C: TODAY'S CHALLENGES (3 rows: desc, progress text, reward-crate icon) ---
	var challenge_header := Label.new()
	challenge_header.text = "TODAY'S CHALLENGES"
	challenge_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(challenge_header, 22, PixelTheme.ACCENT)
	list.add_child(challenge_header)
	for row in SaveManager.active_challenges():
		_challenge_row(list, row)
	list.add_child(_spacer(6))

	var best_clockout := SaveManager.best_clockout_seconds()
	var clockout_text := ShiftClock.clock_string(best_clockout) if best_clockout > 0.0 else "—"
	var best_daily := SaveManager.best_daily_score()
	var rank := Ranks.rank_for(SaveManager.rank_xp())

	_stat_row(list, "RANK", "%d — %s" % [rank, Ranks.name_for(rank)])
	_stat_row(list, "RANK XP", "%d" % SaveManager.rank_xp())
	_stat_row(list, "RUNS PLAYED", "%d" % SaveManager.games_played())
	_stat_row(list, "TOTAL KILLS", "%d" % SaveManager.total_kills())
	_stat_row(list, "BOSSES DEFEATED", "%d" % SaveManager.total_bosses())
	_stat_row(list, "ELITES DEFEATED", "%d" % SaveManager.total_elites())
	_stat_row(list, "COINS EARNED", "%d" % SaveManager.total_coins_earned())
	_stat_row(list, "SHIFTS SURVIVED", "%d" % SaveManager.shifts_survived())
	_stat_row(list, "BEST WAVE", "%d" % SaveManager.best_wave())
	_stat_row(list, "BEST BOSSES", "%d" % SaveManager.best_bosses())
	_stat_row(list, "BEST CLOCK-OUT", clockout_text)
	var horde_bw := SaveManager.horde_best_wave()
	_stat_row(list, "HORDE BEST WAVE", "%d" % horde_bw if horde_bw > 0 else "—")
	var overtime_co := SaveManager.overtime_best_clockout_seconds()
	_stat_row(list, "OVERTIME BEST CLOCK-OUT", ShiftClock.clock_string(overtime_co) if overtime_co > 0.0 else "—")
	var hardcore_co := SaveManager.hardcore_best_clockout_seconds()
	_stat_row(list, "HARDCORE BEST CLOCK-OUT", ShiftClock.clock_string(hardcore_co) if hardcore_co > 0.0 else "—")
	_stat_row(list, "ARMAGEDDONS PULLED", "%d" % SaveManager.armageddons_pulled())
	_stat_row(list, "DAILY STREAK", "%d" % SaveManager.daily_streak())
	_stat_row(list, "WEAPONS FUSED", "%d" % SaveManager.fusions())
	_stat_row(list, "CHALLENGES COMPLETED", "%d" % SaveManager.challenges_completed_total())
	_stat_row(list, "BEST DAILY SCORE", "%d" % best_daily if best_daily > 0 else "—")

	list.add_child(_spacer(6))
	var gun_header := Label.new()
	gun_header.text = "KILLS BY WEAPON"
	gun_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(gun_header, 22, PixelTheme.ACCENT)
	list.add_child(gun_header)

	var gk := SaveManager.gun_kills()
	if gk.is_empty():
		var none := Label.new()
		none.text = "No kills recorded yet."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 18, PixelTheme.TEXT_DIM)
		list.add_child(none)
	else:
		var entries: Array = []
		for id in gk:
			entries.append([String(id), int(gk[id])])
		entries.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
		for e in entries:
			_stat_row(list, String(Weapons.name_for(String(e[0]))).to_upper(), "%d" % int(e[1]))

	var back := _make_button("BACK", _guarded(func(): _show_only(_hub)))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_records_vbox.add_child(back)

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
	_store_scroll = null   # cleared each rebuild; re-set below

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
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # built-in touch scroll off; we drive it from _input so a drag anywhere (even on a button) scrolls
	_store_scroll = scroll
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
			b.pressed.connect(_guarded(_on_buy_character.bind(cid, price)))
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
		cb.pressed.connect(_guarded(_on_buy_crate.bind(String(crate["id"]))))
		list.add_child(cb)

	# DEV (temporary): instantly stock one weapon of every rarity for inspect/feel testing.
	# REMOVE before release (with the 10k-coin grant_dev_bonus in _ready).
	var dev := Button.new()
	dev.text = "DEV: GRANT ALL RARITIES"
	PixelTheme.style_button(dev, Vector2(660, 88), 20)
	dev.pressed.connect(_guarded(_on_dev_grant_all))
	list.add_child(dev)

	var dev_crates := Button.new()
	dev_crates.text = "DEV: 1 OF EACH CRATE"
	PixelTheme.style_button(dev_crates, Vector2(660, 88), 20)
	dev_crates.pressed.connect(_guarded(_on_dev_grant_crates))
	list.add_child(dev_crates)

	_store_result = Label.new()
	_store_result.text = _last_unbox
	_store_result.custom_minimum_size = Vector2(660, 0)
	_store_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_store_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_store_result, 18, _last_unbox_color)
	list.add_child(_store_result)

	var back := _make_button("BACK", _guarded(func(): _show_only(_hub)))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_store_vbox.add_child(back)

func _on_buy_character(id: String, price: int) -> void:
	if SaveManager.is_character_unlocked(id):
		return
	if not SaveManager.spend_coins(price):
		return
	SoundManager.play("purchase")
	SaveManager.unlock_character(id)
	SaveManager.save_game()
	_populate_store()

## Pack 1: a successful buy opens the reel immediately (same flow a crate-tile tap uses)
## instead of just adding the crate to the inventory silently — the "added to inventory"
## message is no longer needed on that path. A full inventory still fails the OPEN (the
## crate stays owned) and reuses the standard failure message; not enough coins never
## leaves the store.
func _on_buy_crate(crate_id: String) -> void:
	if not Inventory.buy_crate(crate_id):
		_last_unbox = "Not enough coins."
		_last_unbox_color = PixelTheme.TEXT_DIM
		_populate_store()
		return
	SoundManager.play("coin")
	if not _open_crate_reel(crate_id):
		_last_unbox = "Inventory full — scrap a weapon first."
		_last_unbox_color = PixelTheme.TEXT_DIM
		_populate_inventory()

func _on_dev_grant_all() -> void:
	var n := Inventory.grant_all_rarities()
	_last_unbox = "DEV: granted %d weapons (one of each rarity)." % n
	_last_unbox_color = PixelTheme.SELECT
	_populate_store()

func _on_dev_grant_crates() -> void:
	var n := Inventory.grant_one_of_each_crate()
	_last_unbox = "DEV: granted 1 of each crate (%d types)." % n
	_last_unbox_color = PixelTheme.SELECT
	_populate_store()

func _on_inv_back() -> void:
	if _inv_suppress_tap:
		_inv_suppress_tap = false
		return                                  # this "tap" was the end of a scroll drag
	_inv_from_play = false
	_show_only(_hub)

# --- Free rewards: daily login + every-10-games milestone ---
func _build_reward_popup() -> void:
	_reward_popup = RewardPopup.new()
	add_child(_reward_popup)   # added last → draws above every panel
	_reward_popup.claimed.connect(_on_reward_claimed)

## Grant everything owed since last menu entry, queue the reveals, then show the first.
func _check_free_rewards() -> void:
	_reward_queue.clear()
	if SaveManager.is_daily_due():
		# Streak (Pack 4): computed from the OLD last_daily_claim, before mark_daily_claimed()
		# overwrites it to today — next_streak() needs yesterday's claim date to detect a
		# consecutive-day login vs a gap.
		var streak := Rewards.next_streak(SaveManager.last_daily_claim(), SaveManager.today_string(), SaveManager.daily_streak())
		SaveManager.set_daily_streak(streak)
		var reward := _grant_reward(Rewards.roll_daily(streak))
		reward["streak"] = streak
		_reward_queue.append({ "title": "DAILY REWARD", "reward": reward })
		SaveManager.mark_daily_claimed()
	while SaveManager.pending_game_rewards() > 0:
		_reward_queue.append({ "title": "10-GAME REWARD", "reward": _grant_reward(Rewards.roll_milestone()) })
		SaveManager.mark_game_reward_given()
	# Pack C: challenge-completion crate rewards — already granted (added to SaveManager.crates())
	# at the run-end flush that completed them; this just queues the reveal, so no _grant_reward()
	# call (that function ADDS the reward — doing so again here would double-grant the crate).
	for crate_id in SaveManager.take_pending_challenge_rewards():
		_reward_queue.append({ "title": "CHALLENGE COMPLETE", "reward": { "kind": "crate", "crate_id": String(crate_id) } })
	# Employee Rank (Pack G): queues at menu entry when a run crossed a rank threshold — same
	# pending-rewards idiom as the challenge-completion crates above (persisted flag, cleared here
	# so it can never show twice). Nothing to grant (the rank XP was already added during the run's
	# flush), so this is a pure "queue the reveal" step, like the challenge-crate loop above.
	if SaveManager.has_pending_promotion():
		_reward_queue.append({ "title": "PROMOTED!", "reward": _promotion_reward() })
		SaveManager.clear_pending_promotion()
	SaveManager.save_game()
	_show_next_reward()

## Builds the PROMOTED popup's reward descriptor: the rank just reached + any mode ids whose
## unlock threshold falls strictly after the rank held before this (possibly multi-run) promotion
## window began, and at or before the rank now — covers a single payout (or several restarts in a
## row, all bypassing the menu) skipping more than one rank threshold at once.
func _promotion_reward() -> Dictionary:
	var from_rank := SaveManager.pending_promotion_from_rank()
	var to_rank := Ranks.rank_for(SaveManager.rank_xp())
	var unlocked: Array = []
	for mode_id in Ranks.UNLOCKS:
		var need := int(Ranks.UNLOCKS[mode_id])
		if need > from_rank and need <= to_rank:
			unlocked.append(String(mode_id))
	return { "kind": "rank", "rank": to_rank, "unlocked": unlocked }

## Adds the reward to the player's stuff and returns the (possibly converted) descriptor to reveal.
func _grant_reward(reward: Dictionary) -> Dictionary:
	match String(reward.get("kind", "")):
		"crate":
			SaveManager.add_crate(String(reward.get("crate_id", "")))
		"gun":
			if not Inventory.add(reward.get("inst", {})):
				# Inventory full → convert to a crate so the reward isn't lost (crates ignore the cap).
				var cid := Rewards.random_crate_id()
				SaveManager.add_crate(cid)
				return { "kind": "crate", "crate_id": cid }
	return reward

## Reveals the next queued reward, or refreshes the hub once the queue is empty.
func _show_next_reward() -> void:
	if _reward_queue.is_empty():
		_current_reward = {}
		if _hub_coins != null:
			_hub_coins.text = "COINS: %d" % SaveManager.coins()
		return
	var entry: Dictionary = _reward_queue.pop_front()
	_current_reward = entry["reward"]
	_reward_popup.open(String(entry["title"]), _current_reward)

## CLAIM pressed on the reward popup. Pack 1: a crate reward now opens the SAME reel every
## other crate-open path uses (instead of just sitting in the inventory unopened) before the
## queue continues; a gun reward (the 10-game 50/50) keeps the old behavior unchanged.
func _on_reward_claimed() -> void:
	var reward := _current_reward
	_current_reward = {}
	if String(reward.get("kind", "")) != "crate":
		_advance_reward_queue()
		return
	var crate_id := String(reward.get("crate_id", ""))
	_reward_flow_active = true
	if not _open_crate_reel(crate_id):
		# Already granted (owned unopened) — inventory's just full right now. Show the
		# standard failure message and move straight on; no reel played.
		_last_unbox = "Inventory full — scrap a weapon first."
		_last_unbox_color = PixelTheme.TEXT_DIM
		_populate_inventory()
		_maybe_resume_reward_queue()
	# else: the reel is spinning; _on_crate_weapon_revealed / _on_detail_popup_closed /
	# _on_crate_opener_closed carry the flow forward via _maybe_resume_reward_queue().

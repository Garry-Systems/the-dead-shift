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
var _records_tab := "records"   # current RECORDS-panel tab: "records" | "badges" | "challenges" — resets to "records" on page open (see _show_records)
var _benefits_panel: Control
var _benefits_vbox: VBoxContainer   # benefits list content (rebuilt by _populate_benefits)
var _benefits_scroll: ScrollContainer   # current benefits list scroll (null when not shown)
var _char_buttons := {}        # character id -> Button (to highlight the selected one)
var _daily_btn: Button         # DAILY SHIFT button (mode panel) — refreshed on every show (Pack C)
var _horde_btn: Button         # HORDE NIGHT button (mode panel) — locked/unlocked by rank (Pack G)
var _overtime_btn: Button      # OVERTIME button (mode panel) — locked/unlocked by rank (Pack G)
var _hardcore_btn: Button      # HARDCORE button (mode panel) — locked/unlocked by rank (Pack G)
var _location_btn: Button      # LOCATION: <NAME> cycling picker (mode panel, Transfer Stores Task 5) —
                                # hidden until rank >= GameConfig.LOC_MART_RANK
var _selected_location := "forecourt"   # this session's picked location id, applied to RunConfig.location
                                         # at run start (AFTER RunConfig.clear_mode_flags(), see _start_run
                                         # /_start_overtime/_start_hardcore); persisted to SaveManager.last_location
var _hub_rank_label: Label     # hub "RANK N — NAME" readout (Pack G), refreshed alongside _hub_coins
var _hub_rank_bar: ProgressBar # hub progress-toward-next-rank bar (Pack G)
var _inv_vbox: VBoxContainer   # inventory card content (rebuilt by _populate_inventory)
var _hub_coins: Label          # hub coin readout (refreshed when returning to hub)
var _inv_from_play := false    # true when the inventory was opened by PLAY (no weapon equipped)
var _detail_popup: WeaponDetailPopup   # reused modal shown when a tile is tapped
var _coworker_popup: CoworkerDetailPopup   # reused modal for a STAFF tile / STAFF FILE reveal (Task 4)

# Drag-anywhere scrolling for the inventory grid, the store list, the records list, AND the
# benefits list: a drag that starts ANYWHERE on the screen (even on a tile/button) scrolls; a
# plain tap still selects.
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
	_build_benefits_panel()
	_build_reward_popup()
	_ensure_valid_character()
	_restore_selected_location()
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
	_benefits_panel.visible = panel == _benefits_panel
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
	vbox.add_child(_make_button("BENEFITS", func(): _show_benefits()))
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
	_refresh_location_row()
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
	# LOCATION picker (Transfer Stores, Task 5): cycles UNLOCKED locations only, wraps. Hidden
	# entirely below GameConfig.LOC_MART_RANK (see _refresh_location_row) — before that rank only
	# "forecourt" exists, so the row would be pure noise.
	_location_btn = _make_button(_location_label(), _on_cycle_location)
	vbox.add_child(_location_btn)
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
	RunConfig.location = _selected_location   # Task 5: apply the picker's pick AFTER the reset above (mirrors hardcore/overtime below)
	if mode == "boss_rush":
		RunConfig.location = "forecourt"   # Transfer Stores: Boss Rush's arena is forecourt-only — the boss roster/patterns aren't tuned around mart aisles or garage pillars (overrides the picker assignment above, always wins for this one mode)
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
	RunConfig.location = _selected_location   # Task 5: apply the picker's pick AFTER the reset above
	get_tree().change_scene_to_file("res://scenes/RunLoading.tscn")

## HARDCORE (Pack G): endless underneath, flagged via RunConfig.hardcore. Re-checks its own unlock
## defensively.
func _start_hardcore() -> void:
	if not Ranks.is_unlocked("hardcore", SaveManager.rank_xp()):
		return
	RunConfig.mode = "endless"
	RunConfig.clear_mode_flags()
	RunConfig.hardcore = true
	RunConfig.location = _selected_location   # Task 5: apply the picker's pick AFTER the reset above
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
	RunConfig.location = "forecourt"   # Transfer Stores: Daily Shift stays forecourt so every player's seeded board is the same fair fight
	RunConfig.start_daily(SaveManager.today_string())
	SaveManager.mark_daily_shift_started()
	SaveManager.add_daily_played()   # lifetime counter (Pack H: REGULAR commendation) — consumed on START, mirrors mark_daily_shift_started
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

# --- LOCATION picker (Transfer Stores, Task 5) ---
# Simpler idiom than the 3 rank-locked mode buttons above (_apply_mode_lock's disabled+"UNLOCKS
# AT" text): rather than showing every location and disabling the locked ones, this ONE button
# just cycles through whichever locations are ALREADY unlocked at the player's current rank,
# wrapping — a locked location never appears as a choice at all, so there's no lock text/disabled
# state to render for it. Chosen because a cycling picker (unlike 3 separate always-visible mode
# buttons) has nowhere natural to show a disabled "locked" option in the same row; skipping locked
# entries entirely reads as "there's nothing there yet" instead of "here's a thing you can't have."

func _location_label() -> String:
	return "LOCATION: %s" % String(Locations.by_id(_selected_location).get("name", "THE FORECOURT"))

## Ordered ids (Locations.all()'s own order) unlocked at `rank` — the picker's cycle set. Pure
## data query over the existing Locations/Ranks getters; no new registry state.
func _unlocked_location_ids(rank: int) -> Array:
	var ids: Array = []
	for row in Locations.all():
		var lid := String(row["id"])
		if Locations.unlocked(lid, rank):
			ids.append(lid)
	return ids

## Restores the last-picked location at menu load. Guard: a saved id that's somehow no longer
## unlocked (hand-edited save; ranks themselves never regress) falls back to forecourt rather than
## trusting stale/invalid save data — and persists that correction back (same set_last_location +
## save_game chokepoint _on_cycle_location uses) so a stale/invalid saved id doesn't just get
## silently re-corrected in memory on every single boot forever.
func _restore_selected_location() -> void:
	var saved := SaveManager.last_location()
	var rank := Ranks.rank_for(SaveManager.rank_xp())
	if Locations.unlocked(saved, rank):
		_selected_location = saved
	else:
		_selected_location = "forecourt"
		SaveManager.set_last_location("forecourt")
		SaveManager.save_game()

## Refreshes the LOCATION row's visibility + text to the player's current rank. Called every time
## the mode panel is about to show (mirrors _refresh_daily_button/_refresh_mode_lock_buttons above
## — a promotion earned since the last visit can change the unlocked set between two visits).
func _refresh_location_row() -> void:
	if _location_btn == null:
		return
	var rank := Ranks.rank_for(SaveManager.rank_xp())
	_location_btn.visible = rank >= GameConfig.LOC_MART_RANK
	if not Locations.unlocked(_selected_location, rank):
		_selected_location = "forecourt"   # same locked→forecourt guard as _restore_selected_location
	_location_btn.text = _location_label()

## Advances to the next unlocked location, wrapping. Persists immediately (mirrors
## _on_toggle_effects's save-on-toggle idiom) so the pick survives an app restart even if the
## player never actually starts a run this session.
func _on_cycle_location() -> void:
	var rank := Ranks.rank_for(SaveManager.rank_xp())
	var ids := _unlocked_location_ids(rank)
	if ids.is_empty():
		return
	var idx := ids.find(_selected_location)
	_selected_location = String(ids[(idx + 1) % ids.size()] if idx != -1 else ids[0])
	SaveManager.set_last_location(_selected_location)
	SaveManager.save_game()
	_location_btn.text = _location_label()

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

	# STAFF (Pack C / Task 4): reused modal for both a STAFF tile tap AND the STAFF FILE
	# purchase reveal — see _reveal_coworker. A child of _inv_panel (same as the weapon
	# popup/crate opener above) so _celebrate's confetti and this popup only ever render
	# while the inventory panel is the visible one.
	_coworker_popup = CoworkerDetailPopup.new()
	_inv_panel.add_child(_coworker_popup)
	_coworker_popup.equip_requested.connect(_on_equip_coworker)
	_coworker_popup.scrap_confirmed.connect(_on_scrap_coworker)
	_coworker_popup.closed.connect(_on_coworker_popup_closed)

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

	# STAFF (Pack C / Task 4): owned coworkers, best rarity first — mirrors the weapon sort.
	var owned_coworkers: Array = SaveManager.coworkers().duplicate()
	owned_coworkers.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_coworker_uid := SaveManager.equipped_coworker()

	if owned.is_empty() and owned_crates.is_empty() and owned_coworkers.is_empty():
		var none := Label.new()
		none.text = "No weapons yet — buy a crate in the Store."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 20, PixelTheme.TEXT_DIM)
		_inv_vbox.add_child(none)
	else:
		# Scroll fills the remaining card height (so the grid never overflows the
		# screen), scrolls vertically only. Both the crates/weapons grid AND the STAFF
		# section below it live inside ONE `sections` VBox inside this single scroll, so
		# the existing drag-anywhere _input branch (keyed on _inv_scroll) already covers
		# STAFF too — no separate scroll registration needed (verified: a 5th
		# _benefits_scroll-style branch would be redundant here).
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # built-in touch scroll off; we drive it from _input so a drag anywhere (even on a tile) scrolls
		_inv_scroll = scroll
		_inv_vbox.add_child(scroll)
		var sections := VBoxContainer.new()
		sections.add_theme_constant_override("separation", 16)
		sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(sections)

		if not owned.is_empty() or not owned_crates.is_empty():
			var grid_center := HBoxContainer.new()
			grid_center.alignment = BoxContainer.ALIGNMENT_CENTER
			grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sections.add_child(grid_center)
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

		# STAFF section (Pack C / Task 4): coworker tiles, below the crates/weapons grid.
		if not owned_coworkers.is_empty():
			var staff_header := Label.new()
			staff_header.text = "STAFF"
			staff_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			PixelTheme.style_label(staff_header, 22, PixelTheme.ACCENT)
			sections.add_child(staff_header)
			var staff_center := HBoxContainer.new()
			staff_center.alignment = BoxContainer.ALIGNMENT_CENTER
			staff_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sections.add_child(staff_center)
			var staff_grid := GridContainer.new()
			staff_grid.columns = 3
			staff_grid.add_theme_constant_override("h_separation", 12)
			staff_grid.add_theme_constant_override("v_separation", 12)
			staff_center.add_child(staff_grid)
			for cw in owned_coworkers:
				var ctile := CoworkerTile.new()
				staff_grid.add_child(ctile)
				ctile.setup(cw, String(cw.get("uid", "")) == equipped_coworker_uid)
				ctile.tile_pressed.connect(_on_coworker_tile_pressed)

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
	if _inv_panel.visible and _inv_scroll != null and not (_detail_popup.visible or _crate_opener.visible or _coworker_popup.visible):
		sc = _inv_scroll
	elif _store_panel.visible and _store_scroll != null:
		sc = _store_scroll
	elif _records_panel.visible and _records_scroll != null:
		sc = _records_scroll
	elif _benefits_panel.visible and _benefits_scroll != null:
		sc = _benefits_scroll
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

## STAFF tile tapped (Task 4) → open the coworker detail popup for that instance. Mirrors
## _on_tile_pressed exactly, off SaveManager.equipped_coworker() instead of Inventory.
func _on_coworker_tile_pressed(inst: Dictionary) -> void:
	if _inv_suppress_tap:
		_inv_suppress_tap = false
		return                                  # this "tap" was the end of a scroll drag
	var is_eq: bool = String(inst.get("uid", "")) == SaveManager.equipped_coworker()
	_coworker_popup.open(inst, is_eq)

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

## EQUIP/UNEQUIP toggle for a coworker (Task 4). Coworkers use the raw SaveManager
## accessors directly (no Inventory.gd wrapper — coworkers aren't weapons; see
## SaveManager.gd's "no Inventory.gd wrapper" comment above its coworker accessor block).
## The toggle math itself lives in Coworkers.toggle_equip (pure, probe-covered) so this stays
## a one-line call, mirroring _on_scrap below routing its payout roll through Coworkers too.
func _on_equip_coworker(inst: Dictionary) -> void:
	var uid := String(inst.get("uid", ""))
	SaveManager.set_equipped_coworker(Coworkers.toggle_equip(SaveManager.equipped_coworker(), uid))
	SaveManager.save_game()
	_populate_inventory()

## Scrap confirmed in the coworker popup → pays Coworkers.roll_scrap_payout(rarity) coins
## (a roll inside the halved Coworkers.scrap_value band) + the Pack-A scrap byproduct, via
## the SAME formula Inventory.deconstruct uses (maxi(1, payout/10) * Benefits.scrap_mult())
## but NOT routed through Inventory.deconstruct itself — coworkers aren't weapons and don't
## share its weapon-cap/fusion chokepoints. Scrapping the equipped coworker unequips it first
## (guard, not just a UI note).
func _on_scrap_coworker(inst: Dictionary) -> void:
	var uid := String(inst.get("uid", ""))
	var payout := Coworkers.roll_scrap_payout(int(inst.get("rarity", 1)))
	if SaveManager.equipped_coworker() == uid:
		SaveManager.set_equipped_coworker("")
	var list: Array = SaveManager.coworkers()
	list = list.filter(func(c): return String(c.get("uid", "")) != uid)
	SaveManager.set_coworkers(list)
	SaveManager.add_coins(payout)
	SaveManager.add_scrap(roundi(maxi(1, payout / 10) * Benefits.scrap_mult()))
	SaveManager.save_game()
	_last_unbox = ""   # mirrors _on_scrap's stale-message clear
	_populate_inventory()

## The coworker popup closed (browsing a STAFF tile OR the post-buy reveal). Refresh the
## grid — mirrors _on_detail_popup_closed, minus the reward-queue hook (STAFF FILE isn't a
## reward-queue kind; see _grant_reward's "crate"/"gun" match).
func _on_coworker_popup_closed() -> void:
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
	_records_tab = "records"   # tab state resets on page open, per the RECORDS-tabs contract
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

## One COMMENDATIONS wall row (Pack H): a reward-crate icon (tier-scaled scrap/munitions/titan —
## reuses Crates.icon, zero new art, same trick as _challenge_row's crate icon above), the badge
## name + desc, and a right-aligned progress readout. Earned rows light up (SELECT name / ACCENT
## "EARNED") — the same lit/dim split _challenge_row already uses for completed/not; unearned rows
## stay dim with a live "value / target" count (every commendation counter is a plain count, unlike
## the challenge board's one clock-seconds row, so no time-format branch is needed here).
func _commendation_row(parent: VBoxContainer, row: Dictionary) -> void:
	var id := String(row.get("id", ""))
	var earned := SaveManager.is_commendation_earned(id)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tier: Dictionary = row.get("tier", {})
	var icon := TextureRect.new()
	icon.texture = Crates.icon(String(tier.get("crate_id", "")))
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(1, 1, 1, 1.0 if earned else 0.35)
	line.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = String(row.get("name", ""))
	PixelTheme.style_label(name_l, 18, PixelTheme.SELECT if earned else PixelTheme.TEXT)
	text_col.add_child(name_l)
	var desc_l := Label.new()
	desc_l.text = String(row.get("desc", ""))
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(desc_l, 14, PixelTheme.TEXT_DIM)
	text_col.add_child(desc_l)
	line.add_child(text_col)

	var prog_l := Label.new()
	prog_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_l.text = "EARNED" if earned else "%d / %d" % [SaveManager.commendation_value(id), int(row.get("target", 0))]
	PixelTheme.style_label(prog_l, 14, PixelTheme.ACCENT if earned else PixelTheme.TEXT_DIM)
	line.add_child(prog_l)

	parent.add_child(line)

## RECORDS-panel shell: title, the RECORDS/BADGES/CHALLENGES tab row, and the shared scroll+list
## wrapper (drag-scroll registration lives here, once per rebuild — same _records_scroll idiom the
## page always used). Only the ONE active tab's content function renders into `list`; switching
## tabs re-runs this whole function (see _records_tab_button), so drag-scroll is always freshly
## registered for whichever tab is now showing.
func _populate_records() -> void:
	for c in _records_vbox.get_children():
		c.queue_free()
	_records_scroll = null   # cleared each rebuild; re-set below

	_make_title(_records_vbox, "RECORDS", 44)
	_records_vbox.add_child(_records_tab_row())

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

	match _records_tab:
		"badges":
			_populate_badges_tab(list)
		"challenges":
			_populate_challenges_tab(list)
		_:
			_populate_records_tab(list)

	var back := _make_button("BACK", _guarded(func(): _show_only(_hub)))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_records_vbox.add_child(back)

## The 3-button RECORDS/BADGES/CHALLENGES tab row, under the title. The current tab renders in
## the Button's own built-in "pressed" look (toggle_mode + button_pressed=true reuses
## PixelTheme.style_button's "pressed" stylebox override — full ACCENT fill/border, DARK text —
## permanently, instead of only while physically held) so no new styling is introduced; the other
## two tabs render normal (BTN_BG fill / ACCENT_DIM border).
func _records_tab_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(_records_tab_button("RECORDS", "records"))
	row.add_child(_records_tab_button("BADGES", "badges"))
	row.add_child(_records_tab_button("CHALLENGES", "challenges"))
	return row

## One tab button. 3x312px + 2x8 separation = 952px, inside the ~968px card content width
## (1080 viewport - 2x24 MarginContainer margin - 2x32 PixelTheme.style_card content margin) —
## same "compute width vs 1080" check the hub's SFX/MUSIC/EFFECTS toggle-row comment documents.
## `_guarded` (not a plain `.pressed` connect) so a tab tap that's actually the release-end of a
## records-list scroll drag doesn't also switch tabs. Rebuilds the WHOLE records panel
## unconditionally on every tap, even a re-tap of the already-active tab: cheap (every other
## panel in this file already fully rebuilds on any state change), and it sidesteps toggle_mode's
## own press/release flip on the JUST-TAPPED button — that button gets queue_free()'d and replaced
## by a fresh one built straight from `_records_tab` a moment later, so the transient internal
## toggle-off never has a frame to render.
func _records_tab_button(label_text: String, id: String) -> Button:
	var b := Button.new()
	b.text = label_text
	PixelTheme.style_button(b, Vector2(312, 72), 22)
	b.toggle_mode = true
	b.button_pressed = _records_tab == id
	b.pressed.connect(_guarded(func():
		_records_tab = id
		_populate_records()
	))
	return b

## RECORDS tab (default): lifetime bests (incl. per-location), general stats, and kills-by-weapon.
## Everything the old single-page _populate_records had EXCEPT Pack C's TODAY'S CHALLENGES board
## (now _populate_challenges_tab) and Pack H's commendations wall (now _populate_badges_tab).
func _populate_records_tab(list: VBoxContainer) -> void:
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
	# Transfer Stores (Task 5): one dim row per unlocked non-forecourt location — mirrors the
	# per-mode best rows just above (no dedicated header, folded straight into the general list,
	# same as HORDE BEST WAVE/OVERTIME BEST CLOCK-OUT/HARDCORE BEST CLOCK-OUT). A location the
	# player hasn't unlocked yet has nothing to show and would just be noise, same reasoning as the
	# mode-panel picker row's own rank gate.
	for loc_row in Locations.all():
		var loc_id := String(loc_row["id"])
		if loc_id == "forecourt" or not Locations.unlocked(loc_id, rank):
			continue
		var lb := SaveManager.location_best(loc_id)
		_stat_row(list, String(loc_row["name"]), ("WAVE %d" % lb) if lb > 0 else "—")
	_stat_row(list, "ARMAGEDDONS PULLED", "%d" % SaveManager.armageddons_pulled())
	_stat_row(list, "DAILY STREAK", "%d" % SaveManager.daily_streak())
	_stat_row(list, "WEAPONS FUSED", "%d" % SaveManager.fusions())
	_stat_row(list, "CHALLENGES COMPLETED", "%d" % SaveManager.challenges_completed_total())
	_stat_row(list, "COMMENDATIONS", "%d/%d" % [SaveManager.commendations_earned_count(), Commendations.all().size()])
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

## BADGES tab (Pack H): the commendations wall — N/18 header + one row per badge. Folded out of
## the old single-page RECORDS body per the spec's own "own view or RECORDS extension —
## implementer judgment"; reuses the already-working scroll + drag-scroll idiom the shell
## (_populate_records) sets up, and the icon+desc+progress row shape _challenge_row already
## proved fits inside the shared 660px list.
func _populate_badges_tab(list: VBoxContainer) -> void:
	var comm_header := Label.new()
	comm_header.text = "COMMENDATIONS %d/%d" % [SaveManager.commendations_earned_count(), Commendations.all().size()]
	comm_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(comm_header, 22, PixelTheme.ACCENT)
	list.add_child(comm_header)
	for row in Commendations.all():
		_commendation_row(list, row)

## CHALLENGES tab (Pack C): TODAY'S CHALLENGES header + the daily board rows (desc, progress
## text, reward-crate icon per row via _challenge_row).
func _populate_challenges_tab(list: VBoxContainer) -> void:
	var challenge_header := Label.new()
	challenge_header.text = "TODAY'S CHALLENGES"
	challenge_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(challenge_header, 22, PixelTheme.ACCENT)
	list.add_child(challenge_header)
	for row in SaveManager.active_challenges():
		_challenge_row(list, row)

# --- benefits: spend scrap on permanent QoL tracks (Employee Benefits Pack A) ---
func _build_benefits_panel() -> void:
	_benefits_panel = _make_panel()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_benefits_panel.add_child(margin)
	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	margin.add_child(card)
	_benefits_vbox = VBoxContainer.new()
	_benefits_vbox.add_theme_constant_override("separation", 10)
	card.add_child(_benefits_vbox)
	# Contents are (re)built on every show by _populate_benefits().

func _show_benefits() -> void:
	_populate_benefits()
	_show_only(_benefits_panel)

## One track row: NAME + flavor (readable-dim idiom — ACCENT.darkened(0.45), matching
## RewardPopup's streak subtitle) on the left, level pips (filled/empty) on the right, and a
## buy button underneath. Mirrors _commendation_row's name+desc / right-readout shape, but the
## action needs its own Button rather than an inline label.
func _benefit_row(parent: VBoxContainer, track: Dictionary) -> void:
	var id := String(track.get("id", ""))
	var cap := int(track.get("cap", 0))
	var lvl := Benefits.level(id)
	var cost := Benefits.cost(id, lvl + 1)
	var maxed := cost < 0   # cost() returns -1 once level == cap

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = String(track.get("name", ""))
	PixelTheme.style_label(name_l, 22, PixelTheme.ACCENT)
	text_col.add_child(name_l)
	var flavor_l := Label.new()
	flavor_l.text = String(track.get("flavor", ""))
	flavor_l.custom_minimum_size = Vector2(460, 0)
	flavor_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(flavor_l, 16, PixelTheme.ACCENT.darkened(0.45))
	text_col.add_child(flavor_l)
	top.add_child(text_col)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	for i in range(cap):
		var pip := Label.new()
		pip.text = "●" if i < lvl else "○"
		PixelTheme.style_label(pip, 20, PixelTheme.ACCENT if i < lvl else PixelTheme.ACCENT_DIM)
		pips.add_child(pip)
	top.add_child(pips)
	row.add_child(top)

	var buy := Button.new()
	buy.text = "MAXED" if maxed else "%d SCRAP" % cost
	PixelTheme.style_button(buy, Vector2(660, 80), 22)
	buy.disabled = maxed or SaveManager.scrap() < cost
	if not maxed:
		buy.pressed.connect(_guarded(_on_buy_benefit.bind(id)))
	row.add_child(buy)

	parent.add_child(row)

func _populate_benefits() -> void:
	for c in _benefits_vbox.get_children():
		c.queue_free()
	_benefits_scroll = null   # cleared each rebuild; re-set below

	_make_title(_benefits_vbox, "BENEFITS", 44)

	var balance := Label.new()
	balance.text = "SCRAP: %d" % SaveManager.scrap()
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(balance, 26, PixelTheme.ACCENT)
	_benefits_vbox.add_child(balance)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE   # built-in touch scroll off; driven from _input like the store/records
	_benefits_scroll = scroll
	_benefits_vbox.add_child(scroll)
	var center_row := HBoxContainer.new()
	center_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center_row)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.custom_minimum_size = Vector2(660, 0)
	center_row.add_child(list)

	for t in Benefits.TRACKS:
		_benefit_row(list, t)

	var back := _make_button("BACK", _guarded(func(): _show_only(_hub)))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_benefits_vbox.add_child(back)

## Buy pressed → try_buy validates cost/cap/wallet itself; a full repopulate refreshes every
## row's pips/cost AND the balance line in one shot, mirroring _on_buy_character/_on_buy_crate's
## own full _populate_store() refresh after a purchase attempt (success or fail).
func _on_buy_benefit(id: String) -> void:
	if Benefits.try_buy(id):
		SoundManager.play("purchase")
	else:
		SoundManager.play("ui_tap")
	_populate_benefits()

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

	# STAFF (Pack C / Task 4): one row — buys and immediately rolls a coworker (no crate,
	# no reel; see _on_buy_coworker's reveal popup).
	_store_header(list, "STAFF")
	var staff_row := VBoxContainer.new()
	staff_row.add_theme_constant_override("separation", 2)
	var staff_btn := Button.new()
	staff_btn.text = "STAFF FILE — %d" % GameConfig.COWORKER_CRATE_PRICE
	PixelTheme.style_button(staff_btn, Vector2(660, 88), 22)
	staff_btn.disabled = SaveManager.coins() < GameConfig.COWORKER_CRATE_PRICE
	staff_btn.pressed.connect(_guarded(_on_buy_coworker))
	staff_row.add_child(staff_btn)
	var staff_desc := Label.new()
	staff_desc.text = "personnel are a renewable resource. hire someone."
	staff_desc.custom_minimum_size = Vector2(660, 0)
	staff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(staff_desc, 18, PixelTheme.TEXT_DIM)
	staff_row.add_child(staff_desc)
	list.add_child(staff_row)

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

## STAFF FILE (Pack C / Task 4): mirrors _on_buy_crate's spend-then-reveal shape (spend
## coins, play the same "coin" purchase sound), but there's no cap check (coworkers have no
## inventory-full guard, unlike weapons) and no CrateOpener reel — a coworker has no
## multi-stage reel tease, so it goes straight to _reveal_coworker's popup (sanctioned
## divergence from the crate-buy flow, per the brief). Rarity rolls via the exact same
## generic-crate default LootRoller._crate_rarity() falls through to for a crate with no
## `special` flag: Rarity.roll(floor, ceil) with no bias (floor 1, ceil MAX_ID) — this isn't
## a premium crate, so no floor/ceil override.
func _on_buy_coworker() -> void:
	if not SaveManager.spend_coins(GameConfig.COWORKER_CRATE_PRICE):
		_last_unbox = "Not enough coins."
		_last_unbox_color = PixelTheme.TEXT_DIM
		_populate_store()
		return
	SoundManager.play("coin")
	var inst := Coworkers.roll(Rarity.roll(1, Rarity.MAX_ID))
	var list: Array = SaveManager.coworkers()
	list.append(inst)
	SaveManager.set_coworkers(list)
	SaveManager.save_game()
	_last_unbox = ""
	_populate_inventory()
	_show_only(_inv_panel)
	_reveal_coworker(inst)

## Reveal popup for a freshly-rolled coworker: crate_win sting (there's no reel to play it
## for us here, unlike a weapon crate — see CrateOpener.gd:255) + the existing confetti
## idiom for a rare-enough pull (mirrors _on_crate_weapon_revealed's own threshold/tint).
func _reveal_coworker(inst: Dictionary) -> void:
	SoundManager.play("crate_win")
	var is_eq: bool = String(inst.get("uid", "")) == SaveManager.equipped_coworker()
	_coworker_popup.open(inst, is_eq, true)
	var rarity := int(inst.get("rarity", 1))
	if rarity >= CONFETTI_MIN_RARITY:
		_celebrate(Rarity.display_color(rarity))

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
	# Commendations (Pack H): pure checks run here (menu entry) AND at every run flush (GameOver/
	# PauseMenu, inside their paid_out guard) — menu entry additionally catches lifetime counters
	# that only change BETWEEN runs (crates opened, weapons fused, challenges completed, daily
	# streak). Reward XP/crate are already granted by check_and_grant_commendations (same dict
	# math as SaveManager.add_rank_xp/add_crate); this loop only queues the reveal, mirroring the
	# challenge-crate loop above. This MUST run before the pending_promotion check below: a
	# commendation's rank-XP grant can itself cross a rank threshold, and doing this first lets a
	# commendation-driven promotion (first noticed right here, at menu time) queue its own PROMOTED
	# popup in the SAME pass, right after the COMMENDATION EARNED popup(s) — see
	# CommendationProgress._add_rank_xp's doc comment for the full trace.
	SaveManager.check_and_grant_commendations()
	for id in SaveManager.take_pending_commendation_rewards():
		_reward_queue.append({ "title": "COMMENDATION EARNED", "reward": { "kind": "commendation", "id": String(id) } })
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
	# Transfer Stores (Task 5): mirrors the mode-unlock loop above exactly, but over Locations
	# instead of Ranks.UNLOCKS (forecourt's rank_unlock is 0, so `need > from_rank` already excludes
	# it — no explicit "skip forecourt" needed). Pre-formatted "TRANSFER APPROVED: <NAME>" strings
	# go in their own array (not merged into `unlocked`, which RewardPopup maps through
	# Ranks.mode_display_name — these aren't mode ids) so RewardPopup can append them to the same
	# "Unlocked: ..." line without misinterpreting them as a mode id lookup.
	var transfers: Array = []
	for row in Locations.all():
		var need := int(row["rank_unlock"])
		if need > from_rank and need <= to_rank:
			transfers.append("TRANSFER APPROVED: %s" % String(row["name"]))
	return { "kind": "rank", "rank": to_rank, "unlocked": unlocked, "transfers": transfers, "blurb": Flavor.rank_blurb(to_rank) }

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
## queue continues; a gun reward (the 10-game 50/50) keeps the old behavior unchanged. Pack H:
## a commendation reward carries a tier crate (already granted into SaveManager.crates() at
## check_and_grant time), so its CLAIM resolves that crate id and rides the identical reel path
## below — including the inventory-full failure behavior. The reward queue already serializes
## popups one at a time, so several commendations earned in one flush just play out as
## reel -> settle -> next popup, no overlap.
func _on_reward_claimed() -> void:
	var reward := _current_reward
	_current_reward = {}
	var crate_id := ""
	match String(reward.get("kind", "")):
		"crate":
			crate_id = String(reward.get("crate_id", ""))
		"commendation":
			var tier: Dictionary = Commendations.by_id(String(reward.get("id", ""))).get("tier", {})
			crate_id = String(tier.get("crate_id", ""))
	if crate_id == "":
		_advance_reward_queue()   # gun / rank / unknown kinds: no crate to reel, queue moves on
		return
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

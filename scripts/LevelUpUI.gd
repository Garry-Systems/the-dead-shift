extends CanvasLayer
## The level-up upgrade screen, built entirely in code. When the player levels up
## it pauses the game, dims the screen, and offers 3 random cards. Odd levels offer
## player-stat cards; even levels offer gun cards. Queues multiple level-ups.

# --- Layout (Power Curve, Task 3): named so the same dimension isn't hardcoded independently
# in _build_ui() (initial style) and _paint_cards() (repainted every offer/reroll). ---
const CARD_SIZE := Vector2(760, 214)          # one offered card: tier / title / rolled number / band
const REROLL_SIZE := Vector2(760, 107)        # SECOND OPINION button: exactly half a card's height
const TIER_FONT_SIZE := 20
const ROLLED_FONT_SIZE := 30                  # the rolled number is the headline
const BAND_FONT_SIZE := 18

var _player: Player
var _queue: Array[int] = []        # levels waiting for an upgrade pick
var _current_cards: Array = []
var _current_level: int = 0        # level of the offer currently on screen (needed to redraw on reroll)

var _root: Control
var _title: Label
var _buttons: Array[Button] = []
var _card_titles: Array[Label] = []
var _tier_labels: Array[Label] = []
var _descs: Array[Label] = []
var _bands: Array[Label] = []
var _reroll_btn: Button

# Power Curve (Task 3): every offered card is rolled through CardRolls.roll, which needs an
# RNG. A per-instance member (randomized once in _ready) instead of a fresh local created
# inside _pick_three each call — this UI is rebuilt fresh every run (see _rerolls_left above),
# so a _ready()-time randomize is still effectively per-run, just without re-instantiating a
# RandomNumberGenerator on every card offer/reroll.
var _rng := RandomNumberGenerator.new()

# SECOND OPINION (Employee Benefits Pack A): per-run reroll charges. Read ONCE here at
# _ready() — Main.tscn (and this UI with it) is reloaded fresh at the start of every run
# (including a mid-run "RESTART RUN", per Main.gd), so a _ready()-time read is per-run,
# never persisted or re-rolled mid-run.
var _rerolls_left: int = 0

func _ready() -> void:
	# Keep this UI alive and clickable while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	# THE ICE CREAM TRUCK (Night Shift Stories, Task 4): "level_up_ui" group so TruckShop.gd can
	# reach add_reroll_charge() below via the SAME group + dynamic .call() idiom RelicBar/
	# RelicChoice already use everywhere in this codebase (this file has no class_name).
	add_to_group("level_up_ui")

	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.leveled_up.connect(_on_player_leveled_up)

	_rng.randomize()
	_build_ui()
	_rerolls_left = Benefits.reroll_charges()
	_update_reroll_button()
	_root.visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = PixelTheme.OVERLAY_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.custom_minimum_size = Vector2(740, 0)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(_title, 30, PixelTheme.ACCENT)
	vbox.add_child(_title)

	# 3 big tappable cards: a chunky button with the upgrade name (pixel font) over a
	# readable (anti-aliased) description, so the choices are easy to read at a glance.
	for i in 3:
		var b := Button.new()
		b.clip_contents = true
		# CARD_SIZE (Power Curve, Task 3): fits the tier/title/desc/band 4-row stack. Actual
		# border color comes from PixelTheme.style_tier_button in _paint_cards — this initial
		# style_button call is overwritten before the card is ever shown (root starts hidden;
		# _show_next always repaints via _refresh_cards -> _paint_cards first).
		PixelTheme.style_button(b, CARD_SIZE)
		b.text = ""
		b.pressed.connect(_on_card_pressed.bind(i))

		var content := VBoxContainer.new()
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 10)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 26
		content.offset_right = -26
		content.offset_top = 14
		content.offset_bottom = -14
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(content)

		# Tier label (Power Curve): COMMON/RARE/EPIC/LEGENDARY, tinted to match the card's
		# rolled rarity color in _paint_cards.
		var tier_lbl := Label.new()
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelTheme.style_label(tier_lbl, TIER_FONT_SIZE, PixelTheme.TEXT_DIM)
		content.add_child(tier_lbl)
		_tier_labels.append(tier_lbl)

		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelTheme.style_label(name_lbl, 30, PixelTheme.ACCENT)
		content.add_child(name_lbl)
		_card_titles.append(name_lbl)

		var desc := Label.new()
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(700, 0)
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ROLLED_FONT_SIZE (Power Curve, Task 3): the rolled number IS the headline now (was 24).
		PixelTheme.readable_label(desc, ROLLED_FONT_SIZE, PixelTheme.TEXT)
		content.add_child(desc)
		_descs.append(desc)

		# Band label (Power Curve): the tier's roll range in small text, e.g. "band 10-16%".
		# Hidden for cards that never roll (band == "", e.g. Second Wind).
		var band_lbl := Label.new()
		band_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		band_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelTheme.readable_label(band_lbl, BAND_FONT_SIZE, PixelTheme.TEXT_DIM)
		content.add_child(band_lbl)
		_bands.append(band_lbl)

		_buttons.append(b)
		vbox.add_child(b)

	# SECOND OPINION: half-height pixel button under the card row. Hidden whenever the
	# player has no charges left (default 0 charges = never shown, matching every other
	# unowned Benefits track reading as absent rather than as a dead/disabled control).
	# Deep Clean (v0.1.67): clip_contents=true + exact-half height of the card buttons above
	# (matching their own clip_contents=true). REROLL_SIZE (Power Curve, Task 3) stays exactly
	# half of CARD_SIZE.
	_reroll_btn = Button.new()
	_reroll_btn.clip_contents = true
	PixelTheme.style_button(_reroll_btn, REROLL_SIZE, 24)
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	vbox.add_child(_reroll_btn)

func _on_player_leveled_up() -> void:
	_queue.append(_player.level)
	if not _root.visible:
		_show_next()

func _show_next() -> void:
	_current_level = _queue.pop_front()
	SoundManager.play("level_up")
	_title.text = "LEVEL %d — choose a %s upgrade" % [_current_level, Upgrades.label_for_level(_current_level)]
	_refresh_cards()
	_root.visible = true
	get_tree().paused = true

## Rolls a fresh `_pick_three` draw for `_current_level`, repaints the 3 cards, and syncs the
## reroll button. Shared by the initial offer (`_show_next`) and a reroll (`_on_reroll_pressed`)
## — both just need the SAME offer parity redrawn, repeats allowed (a reroll re-rolls tiers and
## values too — intended).
func _refresh_cards() -> void:
	_current_cards = _pick_three(_current_level)
	_paint_cards()
	_update_reroll_button()

## Paints the 3 already-rolled `_current_cards` onto the card buttons: tier label + colored
## border (rolled rarity), title, the rolled number as the headline `desc`, and the small-text
## roll `band` (hidden for cards that never roll, e.g. Second Wind). A Legendary among the three
## gets a sting + a full-screen white flash — same trigger for the initial offer and a reroll,
## since both go through here.
func _paint_cards() -> void:
	var best_tier := 0
	for i in 3:
		var c: Dictionary = _current_cards[i]
		var tier := int(c.get("tier", 0))
		best_tier = maxi(best_tier, tier)
		var col: Color = GameConfig.CARD_TIER_COLORS[tier]
		PixelTheme.style_tier_button(_buttons[i], col, CARD_SIZE)
		_tier_labels[i].text = String(GameConfig.CARD_TIER_NAMES[tier])
		_tier_labels[i].add_theme_color_override("font_color", col)
		_card_titles[i].text = String(c["title"]).to_upper()
		_descs[i].text = String(c["desc"])
		_bands[i].text = String(c.get("band", ""))
		_bands[i].visible = _bands[i].text != ""
	if best_tier == 3:
		SoundManager.play("relic_choice")   # Legendary offer sting (existing SFX id)
		# ScreenFlash (scripts/ScreenFlash.gd) has no static flash(tree,color) helper and no
		# color param — it's always a white full-screen flash, and `alpha` must be set BEFORE
		# add_child (read in its own _ready()). It's PROCESS_MODE_ALWAYS, so it still fades out
		# while this screen has the tree paused. Parented on current_scene, same as every other
		# ScreenFlash call site (AbilityController/Basement/Player/Gun) — not under this
		# CanvasLayer — with a self-fallback so a headless probe (no current_scene) still works.
		var f := ScreenFlash.new()
		f.alpha = GameConfig.CARD_LEGENDARY_FLASH_ALPHA
		var scene := get_tree().current_scene
		if scene != null:
			scene.add_child(f)
		else:
			add_child(f)

func _update_reroll_button() -> void:
	_reroll_btn.visible = _rerolls_left > 0
	_reroll_btn.text = "REROLL (%d)" % _rerolls_left

## THE ICE CREAM TRUCK's "SECOND OPINION TO GO" (Night Shift Stories, Task 4): grants one extra
## reroll charge from OUTSIDE the normal Benefits.reroll_charges() _ready()-time read — the one
## external mutation point for _rerolls_left. Reached via the "level_up_ui" group + dynamic .call()
## from TruckShop.gd. Safe to call whether or not the level-up card overlay is currently open/
## visible — _update_reroll_button() only touches the (already-built) button, never the paused/
## root-visible state, so a mid-run purchase can't accidentally pop the level-up screen.
func add_reroll_charge() -> void:
	_rerolls_left += 1
	_update_reroll_button()

func _on_reroll_pressed() -> void:
	if _rerolls_left <= 0:
		return
	_rerolls_left -= 1
	SoundManager.play("ui_tap")
	_refresh_cards()

func _on_card_pressed(index: int) -> void:
	var card: Dictionary = _current_cards[index]
	UpgradeApply.apply(_player, card)
	if not _queue.is_empty():
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

func _pick_three(level: int) -> Array:
	var pool := Upgrades.cards_for_level(level, _player, RunConfig.hardcore)
	pool.shuffle()
	return pool.slice(0, 3).map(func(c): return CardRolls.roll(c, _rng))

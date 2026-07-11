extends CanvasLayer
## The level-up upgrade screen, built entirely in code. When the player levels up
## it pauses the game, dims the screen, and offers 3 random cards. Odd levels offer
## player-stat cards; even levels offer gun cards. Queues multiple level-ups.

var _player: Player
var _queue: Array[int] = []        # levels waiting for an upgrade pick
var _current_cards: Array = []
var _current_level: int = 0        # level of the offer currently on screen (needed to redraw on reroll)

var _root: Control
var _title: Label
var _buttons: Array[Button] = []
var _card_titles: Array[Label] = []
var _descs: Array[Label] = []
var _reroll_btn: Button

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
		PixelTheme.style_button(b, Vector2(760, 188))   # pass size — the default would force 806x135 (too short)
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
		PixelTheme.readable_label(desc, 24, PixelTheme.TEXT)
		content.add_child(desc)
		_descs.append(desc)

		_buttons.append(b)
		vbox.add_child(b)

	# SECOND OPINION: half-height pixel button under the card row. Hidden whenever the
	# player has no charges left (default 0 charges = never shown, matching every other
	# unowned Benefits track reading as absent rather than as a dead/disabled control).
	# Deep Clean (Task 3): clip_contents=true + height 94 (exact half of the 188px card buttons
	# above, matching their own clip_contents=true) — was 92 (uncropped, off by 2 from "exact half").
	_reroll_btn = Button.new()
	_reroll_btn.clip_contents = true
	PixelTheme.style_button(_reroll_btn, Vector2(760, 94), 24)
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

## Populates the 3 card labels from a fresh `_pick_three` draw for `_current_level`, and
## syncs the reroll button. Shared by the initial offer (`_show_next`) and a reroll
## (`_on_reroll_pressed`) — both just need the SAME offer parity redrawn, repeats allowed.
func _refresh_cards() -> void:
	_current_cards = _pick_three(_current_level)
	for i in 3:
		var c: Dictionary = _current_cards[i]
		_card_titles[i].text = String(c["title"]).to_upper()
		_descs[i].text = String(c["desc"])
	_update_reroll_button()

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
	UpgradeApply.apply(_player, card["id"])
	if not _queue.is_empty():
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

func _pick_three(level: int) -> Array:
	var pool := Upgrades.cards_for_level(level, _player, RunConfig.hardcore)
	pool.shuffle()
	return pool.slice(0, 3)

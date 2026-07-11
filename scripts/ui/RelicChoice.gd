extends CanvasLayer
## RELIC CHOICE — the pick-1-of-2 overlay opened when the player collects a boss-dropped relic
## (Relics Overhaul, Task 3). Built on LevelUpUI's paused-overlay idiom EXACTLY: PROCESS_MODE_
## ALWAYS so it stays interactive while `get_tree().paused` is true, a dim scrim + centered
## PixelTheme card stack, and a request QUEUE so a pickup collected while another choice (or
## anything else — a level-up, the pause menu) already owns the pause never stacks a second
## overlay on top — it just waits, same as LevelUpUI's own `_queue` of pending levels.
##
## Unlike LevelUpUI (which queues the LEVEL and re-derives its 3 cards at display time), every
## queued entry here is identical — "a relic pickup was collected" — so the queue is just a
## count (`_pending`). The actual `Relics.roll_choice()` draw happens at DISPLAY time
## (`_show_next`) against the bar's THEN-current held ids, never at collection time, so an
## earlier queued pickup resolving first can't leave a later card offering something already
## taken.
##
## Serialization with other paused overlays reuses the SAME mechanism PauseMenu's own pause
## button already relies on (`if get_tree().paused: return  # another menu owns the pause; don't
## stack`, PauseMenu.gd:175): `_process()` only opens the next queued offer when
## `get_tree().paused` is currently false. Since the player (and every Area2D collision) is
## itself frozen while ANY paused overlay (LevelUpUI, GameOver, PauseMenu, ...) is on screen, a
## relic pickup literally cannot get collected while one of those is open — the reverse
## direction (a level-up interrupting an OPEN RelicChoice) is not separately guarded, but is
## equally structurally blocked: XP only accrues from gem pickups, which need player movement,
## which is frozen the instant RelicChoice pauses the tree. No changes were needed to LevelUpUI.gd.
##
## Two phases share the same card list (built via the RelicMenu `_clear_vbox`/`_add_*` idiom):
##   CHOICE — 1-2 cards (A is never cursed, B may be) + a SKIP button (pays RELIC_SKIP_COINS),
##            styled like LevelUpUI's reroll button (secondary, sits under the cards).
##   SCRAP  — shown only when the bar is full and a card was taken: one card per SCRAPPABLE held
##            relic (see _scrap_candidates — Overstocked is excluded whenever scrapping it would
##            leave the bar still over capacity and strand the pending take), labelled with its
##            scrap payout. Tapping one frees its slot (RelicBar.scrap() — the SAME shared
##            function Task 4's pause-menu SCRAP button will call) and immediately applies the
##            relic that was taken, completing the swap; if the bar is somehow STILL full after
##            the scrap, the phase re-enters with refreshed candidates instead of dropping the
##            pick (see _on_scrap). No SKIP in this phase — the take is already committed; only
##            which relic to give up is left to choose.
## A roll that comes back empty (nothing left un-held) pays RELIC_DRY_COINS instead of opening
## anything — the overlay never flashes on screen for a dry pickup.
##
## Equipping routes entirely through RelicBar.take()/scrap() — this file never touches
## Relics.apply/RelicEffects.equip directly, so the bar stays the single place a relic's family
## (STANDARD vs PROTOTYPE/CURSED) gets resolved.

var _bar

var _pending := 0            # queued, not-yet-shown offers (mirrors LevelUpUI's `_queue` count)
var _phase := ""             # "" (idle) | "choice" | "scrap"
var _a_id := ""
var _b_id := ""
var _swap_take_id := ""      # relic waiting to be applied once a scrap frees a slot

var _root: Control
var _vbox: VBoxContainer

const _CHOICE_CARD_SIZE := Vector2(700, 180)
const _SCRAP_CARD_SIZE := Vector2(700, 120)

func _ready() -> void:
	# Keep this UI alive and clickable while the rest of the tree is paused (LevelUpUI idiom).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11              # above LevelUpUI (10) / RelicBar (9), below PauseMenu (15)
	add_to_group("relic_choice")
	_bar = get_tree().get_first_node_in_group("relic_bar")
	_build_root()
	_root.visible = false

func _build_root() -> void:
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

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 14)
	card.add_child(_vbox)

func _process(_delta: float) -> void:
	# Nothing else owns the pause -> safe to show the next queued offer (see header doc).
	if _phase == "" and _pending > 0 and not get_tree().paused:
		_show_next()

## Called by RelicPickup on collection. Enqueues one request; _process() shows it as soon as
## nothing else is on screen. Fire-and-forget — the pickup frees itself immediately either way.
func request() -> void:
	_pending += 1

func _show_next() -> void:
	_pending -= 1
	if _bar == null:
		_advance()          # no relic bar in scene -> nothing to offer; discard safely
		return
	var held: Array = _bar.call("held_ids")
	var choice: Array = Relics.roll_choice(held, RunConfig.hardcore, RunConfig.mode)
	if choice.is_empty():
		RunStats.add_coins(GameConfig.RELIC_DRY_COINS)
		_advance()           # dry pickups never open anything — check the next one immediately
		return
	_a_id = choice[0]
	_b_id = choice[1] if choice.size() > 1 else ""
	_phase = "choice"
	_rebuild_choice()
	_root.visible = true
	get_tree().paused = true

func _rebuild_choice() -> void:
	_clear_vbox()
	_add_title("RELIC CHOICE — pick one")
	_add_relic_card(_a_id, func(): _on_take(_a_id))
	if _b_id != "":
		_add_relic_card(_b_id, func(): _on_take(_b_id))
	_add_skip_button()

func _on_take(id: String) -> void:
	if _bar != null and bool(_bar.call("is_full")):
		_swap_take_id = id
		_open_scrap()
	else:
		if _bar != null:
			_bar.call("take", id)
		_advance()

func _open_scrap() -> void:
	_phase = "scrap"
	_rebuild_scrap()
	_root.visible = true
	get_tree().paused = true

func _rebuild_scrap() -> void:
	_clear_vbox()
	_add_title("BAR FULL — scrap one to make room")
	for id in _scrap_candidates():
		var hid := String(id)
		_add_scrap_card(hid, func(): _on_scrap(hid))

## Swap-phase scrap candidates: every held id EXCEPT any whose removal would leave the bar STILL
## over capacity — concretely, Overstocked (the capacity relic) whenever held-1 > MAX_RELIC_SLOTS:
## scrapping it mid-swap shrinks the bar 6->4 while 5 relics are still held, so the pending
## take() would no-op on the still-full bar and the player's chosen relic would silently vanish.
## Scrap Overstocked from the pause manager instead (Task 4), where no take is pending.
func _scrap_candidates() -> Array:
	var held: Array = _bar.call("held_ids") if _bar != null else []
	var out: Array = []
	for id in held:
		if String(id) == "overstocked" and held.size() - 1 > GameConfig.MAX_RELIC_SLOTS:
			continue
		out.append(id)
	return out

func _on_scrap(id: String) -> void:
	if _bar != null:
		_bar.call("scrap", id)
		if bool(_bar.call("is_full")):
			# Belt-and-suspenders behind _scrap_candidates' filter: the scrap somehow left the
			# bar still at/over capacity (a capacity relic slipped through, or the bar was forced
			# over capacity externally). NEVER silently drop the pending pick — it is only ever
			# consumed by a successful take() — so re-enter the swap phase with refreshed
			# candidates and let the player keep scrapping down until the take fits.
			_rebuild_scrap()
			return
		_bar.call("take", _swap_take_id)
	_advance()

func _on_skip_pressed() -> void:
	RunStats.add_coins(GameConfig.RELIC_SKIP_COINS)
	_advance()

## Closes the current phase and either shows the next queued offer immediately (no unpause
## flicker in between, mirroring LevelUpUI._on_card_pressed's synchronous chain) or unpauses.
func _advance() -> void:
	_phase = ""
	_swap_take_id = ""
	if _pending > 0:
		_show_next()
	else:
		_root.visible = false
		get_tree().paused = false

# --- tiny UI builders (RelicMenu's clear/rebuild-vbox idiom + LevelUpUI's rich card content) ---

func _clear_vbox() -> void:
	for c in _vbox.get_children():
		c.queue_free()

func _add_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(700, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.style_label(l, 26, PixelTheme.ACCENT)
	_vbox.add_child(l)

## Choice-phase card: name + family tag ("STANDARD"/"PROTOTYPE"/"⚠ CURSED") + full desc.
func _add_relic_card(id: String, cb: Callable) -> void:
	var r := Relics.get_relic(id)
	var cursed := String(r.get("family", "")) == "cursed"
	var b := _make_card_button(cursed, _CHOICE_CARD_SIZE, 22)
	b.pressed.connect(cb)
	var content := _card_content(b)
	_add_card_label(content, String(r.get("name", id)).to_upper(), 22, PixelTheme.ACCENT)
	_add_card_label(content, _family_tag(r, cursed), 14, PixelTheme.TEXT_DIM)
	_add_card_desc(content, String(r.get("desc", "")))
	_vbox.add_child(b)

## Scrap-phase card: name + family tag + scrap value (cursed relics scrap cheap — the power
## already got used). Value comes straight from RelicBar.scrap_value(id) — the SAME function
## scrap() itself calls to decide the payout (PauseMenu._populate_relics' idiom, PauseMenu.gd:165)
## — never re-derived here, so this card's number can never drift from what tapping it pays.
func _add_scrap_card(id: String, cb: Callable) -> void:
	var r := Relics.get_relic(id)
	var cursed := String(r.get("family", "")) == "cursed"
	var value: int = int(_bar.call("scrap_value", id)) if _bar != null else 0
	var b := _make_card_button(cursed, _SCRAP_CARD_SIZE, 20)
	b.pressed.connect(cb)
	var content := _card_content(b)
	_add_card_label(content, String(r.get("name", id)).to_upper(), 20, PixelTheme.ACCENT)
	_add_card_label(content, _family_tag(r, cursed), 13, PixelTheme.TEXT_DIM)
	_add_card_label(content, "SCRAP +%d COINS" % value, 16, PixelTheme.TEXT)
	_vbox.add_child(b)

func _family_tag(r: Dictionary, cursed: bool) -> String:
	return "⚠ CURSED" if cursed else String(r.get("family", "")).to_upper()

## SKIP: half-height, secondary-styled button under the card list — the reroll-button precedent
## (LevelUpUI._reroll_btn: a smaller, distinct action button beneath the main choices).
func _add_skip_button() -> void:
	var b := Button.new()
	b.text = "SKIP (+%d COINS)" % GameConfig.RELIC_SKIP_COINS
	PixelTheme.style_button(b, Vector2(700, 92), 22)
	b.pressed.connect(_on_skip_pressed)
	_vbox.add_child(b)

func _make_card_button(cursed: bool, size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.clip_contents = true
	b.text = ""
	if cursed:
		PixelTheme.style_cursed_button(b, size, font_size)
	else:
		PixelTheme.style_button(b, size, font_size)
	return b

func _card_content(b: Button) -> VBoxContainer:
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 20
	content.offset_right = -20
	content.offset_top = 10
	content.offset_bottom = -10
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(content)
	return content

func _add_card_label(content: VBoxContainer, text: String, size: int, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(l, size, col)
	content.add_child(l)

func _add_card_desc(content: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.readable_label(l, 16, PixelTheme.TEXT)
	content.add_child(l)

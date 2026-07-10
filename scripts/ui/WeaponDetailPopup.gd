class_name WeaponDetailPopup
extends Control
## A modal weapon detail card over a dim scrim. Built once and reused; open(inst, eq)
## rebuilds its contents. Emits intent signals — the owner (MainMenu) performs the
## Inventory mutation and repopulates the grid. SCRAP uses an inline two-step confirm.
## FEED (Pack B: weapon fusion) is the one exception to "mutation happens in the owner and
## the popup closes": the owner still performs the Inventory.fuse() mutation, but hands the
## result BACK to this same popup via show_fuse_result() so the card refreshes in place
## (stats/level/talents/FEED-eligibility) instead of closing.

signal equip_requested(inst: Dictionary)
signal scrap_confirmed(inst: Dictionary)
signal fuse_requested(inst: Dictionary, sacrifice_uid: String)
signal closed()

var _inst: Dictionary
var _is_equipped := false
var _card_vbox: VBoxContainer
var _action_row: Control
var _confirm_row: Control
var _feed_row: Control
var _scroll: ScrollContainer
var _inner: VBoxContainer
var _card_w: float = 720.0
var _title_lbl: Label
const RAINBOW_REFRESH := 0.1   # seconds between title repaints for an Apocalypse-rarity weapon
var _rainbow_accum := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP    # block the grid behind
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	# Cap width to the viewport so the modal fits a narrow (portrait) screen too.
	_card_w = minf(720.0, get_viewport_rect().size.x - 48.0)
	card.custom_minimum_size = Vector2(_card_w, 0)
	PixelTheme.style_card(card)
	center.add_child(card)
	_card_vbox = VBoxContainer.new()
	_card_vbox.add_theme_constant_override("separation", 14)
	card.add_child(_card_vbox)

func open(inst: Dictionary, is_equipped: bool) -> void:
	_inst = inst
	_is_equipped = is_equipped
	_rebuild()
	visible = true

func _rebuild() -> void:
	for c in _card_vbox.get_children():
		c.queue_free()

	# Title — weapon name, rarity-colored (the one kept color exception).
	var title := Label.new()
	title.text = WeaponInstance.display_name(_inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 28)
	title.add_theme_color_override("font_color", WeaponInstance.color(_inst))
	_card_vbox.add_child(title)
	_title_lbl = title
	_rainbow_accum = 0.0

	# Subtitle — rarity name · level.
	var sub := Label.new()
	sub.text = "%s  ·  Level %d" % [WeaponInstance.rarity_name(_inst), int(_inst.get("level", 1))]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(sub, 18, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(sub)

	# XP bar.
	_card_vbox.add_child(_build_xp_row())

	# Scrollable stats + talents (so a max-roll weapon can't overflow the card).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner = VBoxContainer.new()
	_inner.add_theme_constant_override("separation", 12)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_inner)
	_build_stats_section(_inner)
	_build_talents_section(_inner)
	_card_vbox.add_child(_scroll)
	_fit_scroll()   # cap scroll height to content (deferred a frame for layout)

	# Actions (unchanged behavior).
	_action_row = _build_action_row()
	_card_vbox.add_child(_action_row)

## Cheap visible-only repaint of just the title color for the rainbow (Apocalypse) tier — the
## rest of the card is a static snapshot taken at _rebuild() time (rebuilding the whole card
## every 0.1s would be wasteful); only the title color animates while the popup is on screen.
func _process(delta: float) -> void:
	if not visible or not Rarity.is_animated(int(_inst.get("rarity", 1))):
		return
	_rainbow_accum += delta
	if _rainbow_accum < RAINBOW_REFRESH:
		return
	_rainbow_accum = 0.0
	if is_instance_valid(_title_lbl):
		_title_lbl.add_theme_color_override("font_color", WeaponInstance.color(_inst))

# Sizes the scroll region to its content, capped at half the viewport height so short cards
# don't pad and tall ones scroll. Deferred one frame so child labels have reported min sizes.
func _fit_scroll() -> void:
	# Two layout passes: the first lets the scroll/card establish width, the second lets the
	# autowrapping talent labels report their final wrapped height before we cap the scroll.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_scroll) or not is_instance_valid(_inner):
		return
	var cap: float = get_viewport_rect().size.y * 0.5
	_scroll.custom_minimum_size.y = minf(_inner.get_combined_minimum_size().y + 4.0, cap)

func _build_xp_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prog := WeaponInstance.xp_progress(_inst)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, float(prog.needed))
	bar.value = float(prog.xp)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = PixelTheme.DARK
	bg.border_color = PixelTheme.ACCENT_DIM
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelTheme.ACCENT
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	var lbl := Label.new()
	lbl.text = "%d / %d XP" % [int(prog.xp), int(prog.needed)]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(lbl, 16, PixelTheme.TEXT_DIM)
	box.add_child(lbl)
	return box

func _build_stats_section(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("STATS"))
	for row in WeaponInstance.full_stats(_inst):
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := Label.new()
		name_l.text = String(row.label)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelTheme.readable_label(name_l, 18, PixelTheme.TEXT_DIM)
		line.add_child(name_l)
		var val_l := Label.new()
		val_l.text = String(row.value)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelTheme.readable_label(val_l, 18, PixelTheme.TEXT)
		line.add_child(val_l)
		if String(row.bonus) != "":
			var bonus_l := Label.new()
			bonus_l.text = String(row.bonus)
			bonus_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			PixelTheme.readable_label(bonus_l, 16, PixelTheme.SELECT)
			line.add_child(bonus_l)
		block.add_child(line)
		if row.has("roll"):
			block.add_child(_stat_quality_line(row))
		parent.add_child(block)

func _build_talents_section(parent: VBoxContainer) -> void:
	var talents := WeaponInstance.talent_details(_inst)
	if talents.is_empty():
		return
	parent.add_child(_divider())   # a line separating STATS from TALENTS
	parent.add_child(_section_header("TALENTS"))
	for t in talents:
		var locked: bool = bool(t.locked)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Label.new()
		var suffix: String = ("  (LOCKED — LV%d)" % int(t.unlock_level)) if locked else ""
		nm.text = String(t.name).to_upper() + suffix
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelTheme.readable_label(nm, 18, PixelTheme.TEXT_DIM if locked else PixelTheme.ACCENT)
		head.add_child(nm)
		var q: float = float(t.get("quality", 0.0))
		var ql := Label.new()
		ql.text = "%s %d%%" % [String(t.get("quality_label", "")), int(round(q * 100.0))]
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelTheme.readable_label(ql, 14, PixelTheme.TEXT_DIM if locked else (PixelTheme.ACCENT if q >= 0.75 else PixelTheme.SELECT))
		head.add_child(ql)
		row.add_child(head)
		var qbar := _mini_bar(q)
		qbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(qbar)
		var eff := Label.new()
		eff.text = String(t.effect)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.custom_minimum_size = Vector2(maxf(200.0, _card_w - 80.0), 0)
		PixelTheme.readable_label(eff, 16, PixelTheme.TEXT_DIM)
		row.add_child(eff)
		parent.add_child(row)

func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	PixelTheme.readable_label(l, 18, PixelTheme.SELECT)
	return l

## A thin horizontal divider line (separates the STATS and TALENTS sections).
func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = PixelTheme.ACCENT_DIM
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line

## A thin quality bar styled like the XP bar (C4 fill on a C1 track, C2 border).
func _mini_bar(frac: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 8)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PixelTheme.DARK
	bg.border_color = PixelTheme.ACCENT_DIM
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelTheme.ACCENT
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## The lo / bar / hi / flag line under a rolled stat. Added only when row.has("roll").
func _stat_quality_line(row: Dictionary) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(row.get("fixed", false)):
		var maxed := Label.new()
		maxed.text = "MAX"
		PixelTheme.readable_label(maxed, 14, PixelTheme.SELECT)
		hb.add_child(maxed)
		var fbar := _mini_bar(1.0)
		fbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(fbar)
		return hb
	var q := float(row.roll)
	var lo := Label.new()
	lo.text = String(row.lo)
	PixelTheme.readable_label(lo, 14, PixelTheme.TEXT_DIM)
	hb.add_child(lo)
	var bar := _mini_bar(q)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(bar)
	var hi := Label.new()
	hi.text = String(row.hi)
	PixelTheme.readable_label(hi, 14, PixelTheme.TEXT_DIM)
	hb.add_child(hi)
	var flag := Label.new()
	flag.text = ("★ " + WeaponInstance.quality_label(q)) if q >= 0.95 else WeaponInstance.quality_label(q)
	PixelTheme.readable_label(flag, 14, PixelTheme.ACCENT if q >= 0.75 else PixelTheme.TEXT_DIM)
	hb.add_child(flag)
	return hb

func _build_action_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var equip_btn := Button.new()
	equip_btn.text = "EQUIPPED" if _is_equipped else "EQUIP"
	PixelTheme.style_button(equip_btn, Vector2(0, 68), 22)
	equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_btn.disabled = _is_equipped
	equip_btn.pressed.connect(func():
		equip_requested.emit(_inst)
		_close())
	row.add_child(equip_btn)

	var dupes := Inventory.eligible_fusion_sacrifices(String(_inst.get("uid", "")))
	var feed_btn := Button.new()
	feed_btn.text = "FEED"
	PixelTheme.style_button(feed_btn, Vector2(0, 62), 20)
	feed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_btn.disabled = dupes.is_empty()
	feed_btn.pressed.connect(_show_feed_picker)
	row.add_child(feed_btn)
	if dupes.is_empty():
		var hint := Label.new()
		hint.text = "No duplicates to feed."   # mirrors the "Inventory full" dim-hint idiom
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.readable_label(hint, 14, PixelTheme.TEXT_DIM)
		row.add_child(hint)

	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	var scrap_btn := Button.new()
	scrap_btn.text = "SCRAP (%d-%d)" % [int(band[0]), int(band[1])]
	PixelTheme.style_button(scrap_btn, Vector2(0, 62), 20)
	scrap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrap_btn.disabled = _is_equipped
	scrap_btn.add_theme_color_override("font_color", PixelTheme.DANGER)
	scrap_btn.pressed.connect(_show_scrap_confirm)
	row.add_child(scrap_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	PixelTheme.style_button(close_btn, Vector2(0, 62), 20)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(_close)
	row.add_child(close_btn)
	return row

func _show_scrap_confirm() -> void:
	_action_row.visible = false
	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	# EMPLOYEE BENEFITS (Pack A): a deconstruct also banks SCRAP (coin payout / 10, min 1,
	# PACK RAT-multiplied — see Inventory.deconstruct). The scrap flow shows no post-payout
	# result feedback (MainMenu._on_scrap just repopulates the grid), so the byproduct is
	# previewed on the YES confirm button — as a band, like the coin question above it,
	# because the exact payout only rolls at deconstruct time.
	var s_lo := roundi(maxi(1, int(band[0]) / 10) * Benefits.scrap_mult())
	var s_hi := roundi(maxi(1, int(band[1]) / 10) * Benefits.scrap_mult())
	var scrap_note := ("+%d SCRAP" % s_lo) if s_lo == s_hi else ("+%d-%d SCRAP" % [s_lo, s_hi])
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 10)
	_confirm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q := Label.new()
	q.text = "Scrap for %d-%d coins?" % [int(band[0]), int(band[1])]
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(q, 18, PixelTheme.DANGER)
	_confirm_row.add_child(q)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := Button.new()
	yes.text = "YES (%s)" % scrap_note
	PixelTheme.style_button(yes, Vector2(0, 62), 20)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		scrap_confirmed.emit(_inst)
		_close())
	hb.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	PixelTheme.style_button(no, Vector2(0, 62), 20)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func():
		_confirm_row.visible = false
		_confirm_row.queue_free()
		_confirm_row = null
		_action_row.visible = true)
	hb.add_child(no)
	_confirm_row.add_child(hb)
	_card_vbox.add_child(_confirm_row)

## FEED step 1: a scrollable list of eligible same-base duplicates (rarity-colored, with
## level) to pick a sacrifice from. Only reachable via the FEED button, which is itself
## disabled whenever this list would be empty (see _build_action_row).
func _show_feed_picker() -> void:
	_action_row.visible = false
	if is_instance_valid(_feed_row):   # re-entry from the confirm step's NO — replace that row
		_feed_row.visible = false       # hide NOW; queue_free is deferred (no one-frame overlap)
		_feed_row.queue_free()
	var dupes := Inventory.eligible_fusion_sacrifices(String(_inst.get("uid", "")))
	_feed_row = VBoxContainer.new()
	_feed_row.add_theme_constant_override("separation", 10)
	_feed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "FEED — choose a duplicate to consume"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(title, 16, PixelTheme.SELECT)
	_feed_row.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, minf(280.0, float(dupes.size()) * 62.0 + 8.0))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for dup in dupes:
		list.add_child(_feed_candidate_row(dup))
	_feed_row.add_child(scroll)

	var cancel := Button.new()
	cancel.text = "CANCEL"
	PixelTheme.style_button(cancel, Vector2(0, 56), 18)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_feed_row)
	_feed_row.add_child(cancel)

	_card_vbox.add_child(_feed_row)

## One selectable row in the FEED picker: rarity-colored name + level. Tapping goes straight
## to the confirm step (_show_feed_confirm) — no separate "select" step.
func _feed_candidate_row(dup: Dictionary) -> Button:
	var b := Button.new()
	b.text = "%s  ·  Lv%d  ·  %s" % [WeaponInstance.display_name(dup), int(dup.get("level", 1)), WeaponInstance.rarity_name(dup)]
	PixelTheme.style_button(b, Vector2(0, 56), 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_color_override("font_color", WeaponInstance.color(dup))
	b.pressed.connect(func(): _show_feed_confirm(dup))
	return b

## FEED step 2: final YES/NO before the sacrifice is actually consumed (mirrors the scrap
## confirm's shape). YES emits fuse_requested — the OWNER (MainMenu) performs the
## Inventory.fuse() mutation and calls show_fuse_result() back on this popup; the popup does
## NOT close, so the result renders in the same card. NO backs out to the picker list.
func _show_feed_confirm(dup: Dictionary) -> void:
	if is_instance_valid(_feed_row):
		_feed_row.visible = false   # hide NOW; queue_free is deferred (no one-frame overlap)
		_feed_row.queue_free()
	_feed_row = VBoxContainer.new()
	_feed_row.add_theme_constant_override("separation", 10)
	_feed_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var q := Label.new()
	q.text = "Feed %s (Lv%d) into %s? It will be consumed." % [
		WeaponInstance.display_name(dup), int(dup.get("level", 1)), WeaponInstance.display_name(_inst)]
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(q, 18, PixelTheme.SELECT)
	_feed_row.add_child(q)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := Button.new()
	yes.text = "YES"
	PixelTheme.style_button(yes, Vector2(0, 62), 20)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		var sac_uid := String(dup.get("uid", ""))
		_close_feed_row()
		fuse_requested.emit(_inst, sac_uid))
	hb.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	PixelTheme.style_button(no, Vector2(0, 62), 20)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func(): _show_feed_picker())   # back to the candidate list
	hb.add_child(no)
	_feed_row.add_child(hb)
	_card_vbox.add_child(_feed_row)

func _close_feed_row() -> void:
	if is_instance_valid(_feed_row):
		_feed_row.visible = false   # hide NOW; queue_free is deferred (no one-frame overlap)
		_feed_row.queue_free()
	_feed_row = null
	_action_row.visible = true

## Called by the owner (MainMenu) right after it performs the Inventory.fuse() mutation.
## Rebuilds the whole card — stats/xp/level/talents/FEED-eligibility all reflect the fused
## instance because `_inst` is the SAME Dictionary Inventory.fuse() just mutated in place
## (the same aliasing add_run_xp's "it is a reference into the saved array" comment relies
## on) — then appends a result banner just above the (freshly rebuilt) action row.
## `result` is Inventory.fuse()'s return value; {} means the fusion was rejected by a guard
## (shouldn't happen from this popup's own picker, but handled defensively — no banner shown).
func show_fuse_result(result: Dictionary) -> void:
	_rebuild()
	if result.is_empty():
		return
	var lines: Array[String] = []
	lines.append("+%d WEAPON XP" % int(result.get("xp_gained", 0)))
	if bool(result.get("leveled_up", false)):
		lines.append("LEVEL UP — now Lv%d" % int(result.get("new_level", 1)))
	var unlocked: Array = result.get("unlocked", [])
	if not unlocked.is_empty():
		lines.append("New talent%s unlocked: %s" % ["s" if unlocked.size() > 1 else "", ", ".join(unlocked)])
	var rerolled: Dictionary = result.get("rerolled", {})
	if not rerolled.is_empty():
		# Resolved through the affix ranges (real +N / +X.X% values), never the raw 0..1 rolls.
		lines.append(WeaponInstance.reroll_line(_inst, rerolled))

	var banner := Label.new()
	banner.text = "\n".join(lines)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelTheme.readable_label(banner, 18, PixelTheme.SELECT)
	_card_vbox.add_child(banner)
	_card_vbox.move_child(banner, _action_row.get_index())   # above the action row

func _close() -> void:
	visible = false
	closed.emit()

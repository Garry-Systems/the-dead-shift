class_name CoworkerDetailPopup
extends Control
## A lean coworker detail card over a dim scrim — Task 4's sanctioned divergence from
## WeaponDetailPopup.gd: that popup is built deeply around WeaponInstance (XP bar, rolled-
## stat quality bars with lo/hi bands, talents, FEED/fusion), none of which a coworker
## instance {uid,type,rarity,trait} has, and forcing it to tolerate a non-weapon shape
## would mean stripping most of its own body. This is a new, smaller popup that mirrors its
## STRUCTURE (scrim, centered PanelContainer card, rarity-colored title with the same
## Apocalypse/Armageddon per-frame repaint, action row, inline two-step SCRAP confirm) but
## with coworker-shaped content: name / icon / flavor / trait / a short stat summary.
## Built once and reused; open(inst, eq) rebuilds its contents. Emits intent signals — the
## owner (MainMenu) performs the SaveManager mutation and repopulates the grid, exactly like
## WeaponDetailPopup's equip/scrap contract.
##
## EQUIP diverges from WeaponDetailPopup on purpose: a coworker can be un-equipped entirely
## (equipped_coworker == "" is a normal, supported state — Companion.gd only spawns when it
## resolves to a live instance), so the button stays live and toggles UNEQUIP when already
## equipped, instead of disabling like the weapon popup's EQUIP does.

signal equip_requested(inst: Dictionary)
signal scrap_confirmed(inst: Dictionary)
signal closed()

var _inst: Dictionary
var _is_equipped := false
var _from_reveal := false   # true only for a fresh STAFF FILE purchase (see open()'s 3rd arg)
var _card_vbox: VBoxContainer
var _action_row: Control
var _confirm_row: Control
var _title_lbl: Label
const RAINBOW_REFRESH := 0.1   # seconds between title repaints for an Apocalypse/Armageddon-rarity coworker
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
	var card_w: float = minf(620.0, get_viewport_rect().size.x - 48.0)
	card.custom_minimum_size = Vector2(card_w, 0)
	PixelTheme.style_card(card)
	center.add_child(card)
	_card_vbox = VBoxContainer.new()
	_card_vbox.add_theme_constant_override("separation", 12)
	card.add_child(_card_vbox)

## `from_reveal` (default false, unchanged for the existing STAFF-tile-tap browse call) is true
## only for MainMenu._reveal_coworker's fresh-purchase call — that's the one case that gets the
## art/crates/staff_file.png icon in the header (Task 3's dead-art wiring: the crate rows
## themselves are text-only Buttons with no icon slot, so the reveal-popup header is the route).
func open(inst: Dictionary, is_equipped: bool, from_reveal: bool = false) -> void:
	_inst = inst
	_is_equipped = is_equipped
	_from_reveal = from_reveal
	_rebuild()
	visible = true

func _rebuild() -> void:
	for c in _card_vbox.get_children():
		c.queue_free()
	var type := String(_inst.get("type", ""))
	var rarity := int(_inst.get("rarity", 1))

	# Title — coworker name, rarity-colored (the one kept color exception, same as the
	# weapon popup's title).
	var title := Label.new()
	title.text = Coworkers.name_for(type)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 26)
	title.add_theme_color_override("font_color", Rarity.display_color(rarity))
	_title_lbl = title
	_rainbow_accum = 0.0

	# Task 3 (dead-art wiring): a fresh STAFF FILE reveal gets the crate's own icon next to the
	# title — the STAFF FILE store row itself is a text-only Button (see the CRATES row loop
	# right above it in MainMenu._populate_store), so this header is the only place it can go.
	if _from_reveal and Crates.icon("staff_file") != null:
		var header := HBoxContainer.new()
		header.alignment = BoxContainer.ALIGNMENT_CENTER
		header.add_theme_constant_override("separation", 8)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var staff_icon := TextureRect.new()
		staff_icon.texture = Crates.icon("staff_file")
		staff_icon.custom_minimum_size = Vector2(32, 32)
		staff_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		staff_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		staff_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		staff_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(staff_icon)
		header.add_child(title)
		_card_vbox.add_child(header)
	else:
		_card_vbox.add_child(title)

	var sub := Label.new()
	sub.text = Rarity.tier_name(rarity)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(sub, 18, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(sub)

	var icon_center := CenterContainer.new()
	icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_center.add_child(_build_icon(type, Vector2(110, 110)))
	_card_vbox.add_child(icon_center)

	var flavor := Label.new()
	flavor.text = Coworkers.flavor(type)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.custom_minimum_size = Vector2(480, 0)
	PixelTheme.readable_label(flavor, 16, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(flavor)

	var trait_id := String(_inst.get("trait", ""))
	if trait_id != "":
		_card_vbox.add_child(_divider())
		var tname := Label.new()
		tname.text = Coworkers.trait_name(trait_id)
		tname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.readable_label(tname, 18, PixelTheme.SELECT)
		_card_vbox.add_child(tname)
		var tdesc := Label.new()
		tdesc.text = Coworkers.trait_desc(trait_id)
		tdesc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tdesc.custom_minimum_size = Vector2(480, 0)
		PixelTheme.readable_label(tdesc, 16, PixelTheme.TEXT_DIM)
		_card_vbox.add_child(tdesc)

	_card_vbox.add_child(_divider())
	_card_vbox.add_child(_section_header("STATS"))
	for line in _stat_lines(type, rarity, trait_id):
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.readable_label(l, 16, PixelTheme.TEXT)
		_card_vbox.add_child(l)

	_action_row = _build_action_row()
	_card_vbox.add_child(_action_row)

## Cheap visible-only repaint of just the title color for the rainbow/molten tier — mirrors
## WeaponDetailPopup._process exactly (rest of the card is a static snapshot from _rebuild).
func _process(delta: float) -> void:
	if not visible or not Rarity.is_animated(int(_inst.get("rarity", 1))):
		return
	_rainbow_accum += delta
	if _rainbow_accum < RAINBOW_REFRESH:
		return
	_rainbow_accum = 0.0
	if is_instance_valid(_title_lbl):
		_title_lbl.add_theme_color_override("font_color", Rarity.display_color(int(_inst.get("rarity", 1))))

## KEEP IN SYNC with Companion.configure()'s scaling block (Companion.gd) — same formula,
## no shared seam by convention (Companion.gd has no autoload-free extraction point).
##
## Effective per-type stat lines shown in the STATS section. Mirrors Companion.configure()'s
## stat_mult()-then-single-trait scaling formula exactly (a browsing-time preview of the
## SAME numbers the companion will actually run with) — kept in sync by hand since
## Companion.gd's math is runtime-only. MAGNETIC/STUDIOUS are player-side buffs already
## covered by the trait line above, not a companion combat stat, so they're excluded here.
func _stat_lines(type: String, rarity: int, trait_id: String) -> Array[String]:
	var mult := Coworkers.stat_mult(rarity)
	var dmg_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_SHARP if trait_id == "sharp" else 0.0))
	var rate_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_WIRED if trait_id == "wired" else 0.0))
	var range_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_WIDE if trait_id == "wide" else 0.0))
	var steady_mult := mult * (1.0 + (GameConfig.COWORKER_TRAIT_STEADY if trait_id == "steady" else 0.0))
	match type:
		"cat":
			return [
				"DAMAGE %d" % roundi(GameConfig.COWORKER_CAT_DAMAGE * dmg_mult),
				"ATTACKS EVERY %.1fs" % (GameConfig.COWORKER_CAT_RATE / rate_mult),
				"RANGE %d" % roundi(GameConfig.COWORKER_CAT_RANGE * range_mult),
			]
		"drone":
			return [
				"DAMAGE %d" % roundi(GameConfig.COWORKER_DRONE_DAMAGE * dmg_mult),
				"ATTACKS EVERY %.1fs" % (GameConfig.COWORKER_DRONE_RATE / rate_mult),
				"RANGE %d" % roundi(GameConfig.COWORKER_DRONE_RANGE * range_mult),
			]
		"mannequin":
			return [
				"DECOY HP %d" % roundi(GameConfig.COWORKER_MANNEQUIN_HP * steady_mult),
				"TAUNT RADIUS %d" % roundi(GameConfig.COWORKER_MANNEQUIN_TAUNT_RADIUS * range_mult),
				"TAUNT DURATION %.1fs" % (GameConfig.COWORKER_MANNEQUIN_TAUNT_TIME * steady_mult),
			]
		_:
			return []

## The card icon: per-type art if it exists, else the same drawn-glyph fallback as
## CoworkerTile._build_icon (small, intentional duplication — see that file's own comment).
func _build_icon(type: String, size: Vector2) -> Control:
	var tex := Coworkers.icon(type)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = size
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var col := Coworkers.glyph_color(type)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.25)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = Coworkers.glyph_letter(type)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(lbl, int(size.y * 0.45), col)
	panel.add_child(lbl)
	return panel

func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.readable_label(l, 18, PixelTheme.SELECT)
	return l

## A thin horizontal divider line — identical to WeaponDetailPopup._divider.
func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = PixelTheme.ACCENT_DIM
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line

func _build_action_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# EQUIP/UNEQUIP: one at a time (the owner enforces this by simply overwriting
	# equipped_coworker) — re-tapping the equipped coworker's EQUIP button unequips it
	# (sets equipped_coworker to ""), so the button is never disabled here.
	var equip_btn := Button.new()
	equip_btn.text = "UNEQUIP" if _is_equipped else "EQUIP"
	PixelTheme.style_button(equip_btn, Vector2(0, 68), 22)
	equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_btn.pressed.connect(func():
		equip_requested.emit(_inst)
		_close())
	row.add_child(equip_btn)

	var band := Coworkers.scrap_value(int(_inst.get("rarity", 1)))
	var scrap_btn := Button.new()
	scrap_btn.text = "SCRAP (%d-%d)" % [int(band[0]), int(band[1])]
	PixelTheme.style_button(scrap_btn, Vector2(0, 62), 20)
	scrap_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

## Inline two-step confirm — mirrors WeaponDetailPopup._show_scrap_confirm's shape
## (coin-band question + a scrap-byproduct-banded YES button), but the byproduct band is
## computed from Coworkers.scrap_value()'s (already halved) band, and the equipped case
## gets an extra "(will unequip)" note since SCRAP is never disabled here.
func _show_scrap_confirm() -> void:
	_action_row.visible = false
	var band := Coworkers.scrap_value(int(_inst.get("rarity", 1)))
	var s_lo := roundi(maxi(1, int(band[0]) / 10) * Benefits.scrap_mult())
	var s_hi := roundi(maxi(1, int(band[1]) / 10) * Benefits.scrap_mult())
	var scrap_note := ("+%d SCRAP" % s_lo) if s_lo == s_hi else ("+%d-%d SCRAP" % [s_lo, s_hi])
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 10)
	_confirm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q := Label.new()
	q.text = "Scrap for %d-%d coins?" % [int(band[0]), int(band[1])]
	if _is_equipped:
		q.text += " (will unequip)"
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func _close() -> void:
	visible = false
	closed.emit()

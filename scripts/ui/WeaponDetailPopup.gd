class_name WeaponDetailPopup
extends Control
## A modal weapon detail card over a dim scrim. Built once and reused; open(inst, eq)
## rebuilds its contents. Emits intent signals — the owner (MainMenu) performs the
## Inventory mutation and repopulates the grid. SCRAP uses an inline two-step confirm.

signal equip_requested(inst: Dictionary)
signal scrap_confirmed(inst: Dictionary)
signal closed()

var _inst: Dictionary
var _is_equipped := false
var _card_vbox: VBoxContainer
var _action_row: Control
var _confirm_row: Control

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
	card.custom_minimum_size = Vector2(560, 0)
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

	var title := Label.new()
	title.text = WeaponInstance.display_name(_inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 26)
	title.add_theme_color_override("font_color", WeaponInstance.color(_inst))
	_card_vbox.add_child(title)

	var stats := Label.new()
	stats.text = "%s  ·  %s" % [WeaponInstance.rarity_name(_inst), WeaponInstance.stat_summary(_inst)]
	stats.custom_minimum_size = Vector2(500, 0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(stats, 14, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(stats)

	var tsum: String = WeaponInstance.talent_summary(_inst)
	if tsum != "":
		var tlabel := Label.new()
		tlabel.text = "⟡ " + tsum
		tlabel.custom_minimum_size = Vector2(500, 0)
		tlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(tlabel, 13, PixelTheme.ACCENT)
		_card_vbox.add_child(tlabel)

	_action_row = _build_action_row()
	_card_vbox.add_child(_action_row)

func _build_action_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var equip_btn := Button.new()
	equip_btn.text = "EQUIPPED" if _is_equipped else "EQUIP"
	PixelTheme.style_button(equip_btn, Vector2(480, 60), 18)
	equip_btn.disabled = _is_equipped
	equip_btn.pressed.connect(func():
		equip_requested.emit(_inst)
		_close())
	row.add_child(equip_btn)

	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	var scrap_btn := Button.new()
	scrap_btn.text = "SCRAP (%d-%d)" % [int(band[0]), int(band[1])]
	PixelTheme.style_button(scrap_btn, Vector2(480, 56), 16)
	scrap_btn.disabled = _is_equipped
	scrap_btn.add_theme_color_override("font_color", PixelTheme.DANGER)
	scrap_btn.pressed.connect(_show_scrap_confirm)
	row.add_child(scrap_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	PixelTheme.style_button(close_btn, Vector2(480, 56), 16)
	close_btn.pressed.connect(_close)
	row.add_child(close_btn)
	return row

func _show_scrap_confirm() -> void:
	_action_row.visible = false
	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 10)
	var q := Label.new()
	q.text = "Scrap for %d-%d coins?" % [int(band[0]), int(band[1])]
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(q, 16, PixelTheme.DANGER)
	_confirm_row.add_child(q)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	var yes := Button.new()
	yes.text = "YES"
	PixelTheme.style_button(yes, Vector2(220, 56), 16)
	yes.pressed.connect(func():
		scrap_confirmed.emit(_inst)
		_close())
	hb.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	PixelTheme.style_button(no, Vector2(220, 56), 16)
	no.pressed.connect(func():
		_confirm_row.queue_free()
		_action_row.visible = true)
	hb.add_child(no)
	_confirm_row.add_child(hb)
	_card_vbox.add_child(_confirm_row)

func _close() -> void:
	visible = false
	closed.emit()

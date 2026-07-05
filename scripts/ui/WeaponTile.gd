class_name WeaponTile
extends Button
## A square inventory tile for one rolled weapon instance: rarity-colored border (via
## PixelTheme.style_tile), a per-weapon icon, the weapon name + rarity, and an EQUIPPED
## badge. Emits tile_pressed(inst) when tapped. Content overlays the Button as
## mouse-ignoring children so the Button still receives the press. Built in code.

signal tile_pressed(inst: Dictionary)

const TILE_SIZE := Vector2(273, 273)
const ICON_SIZE := Vector2(169, 169)
const RAINBOW_REFRESH := 0.1   # seconds between repaints for an Apocalypse-rarity tile

var _inst: Dictionary
var _rarity_lbl: Label
var _rainbow := false          # true when this instance's rarity is the animated Apocalypse tier
var _rainbow_accum := 0.0

## Builds the tile for an instance. Call once right after instancing.
func setup(inst: Dictionary, is_equipped: bool) -> void:
	_inst = inst
	custom_minimum_size = TILE_SIZE
	clip_contents = true
	text = ""
	PixelTheme.style_tile(self, WeaponInstance.color(inst))
	_rainbow = int(inst.get("rarity", 1)) == Rarity.RAINBOW_ID
	pressed.connect(func(): tile_pressed.emit(_inst))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = WeaponInstance.icon(inst)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(WeaponInstance.base_def(inst).get("name", "?"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(name_lbl, 20, PixelTheme.TEXT)
	box.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = WeaponInstance.rarity_name(inst)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(rarity_lbl, 14, WeaponInstance.color(inst))
	box.add_child(rarity_lbl)
	_rarity_lbl = rarity_lbl

	if is_equipped:
		_add_equipped_badge()

## Cheap visible-only repaint for the rainbow (Apocalypse) tier: re-reads WeaponInstance.color
## (which animates for that one rarity) every RAINBOW_REFRESH seconds, only while this tile is
## actually on screen. Every other rarity is a flat color set once in setup() — no per-frame cost.
func _process(delta: float) -> void:
	if not _rainbow or not is_visible_in_tree():
		return
	_rainbow_accum += delta
	if _rainbow_accum < RAINBOW_REFRESH:
		return
	_rainbow_accum = 0.0
	var col := WeaponInstance.color(_inst)
	PixelTheme.style_tile(self, col)
	if is_instance_valid(_rarity_lbl):
		_rarity_lbl.add_theme_color_override("font_color", col)

## A small green "EQ" badge pinned to the top-right corner.
func _add_equipped_badge() -> void:
	var badge_panel := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = PixelTheme.SELECT
	bsb.set_corner_radius_all(0)
	bsb.anti_aliasing = false
	bsb.content_margin_left = 4
	bsb.content_margin_right = 4
	bsb.content_margin_top = 1
	bsb.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", bsb)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Label.new()
	badge.text = "EQ"
	badge.add_theme_font_override("font", PixelTheme.body_font())
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", PixelTheme.DARK)
	badge_panel.add_child(badge)
	add_child(badge_panel)
	# Pin to the top-right corner with an explicit small rect (anchors all at the
	# parent's top-right; offsets define a real ~34x22 box). Avoids the zero-size
	# trap of equal left/right offsets; mirrors the corner-element pattern elsewhere.
	badge_panel.anchor_left = 1.0
	badge_panel.anchor_top = 0.0
	badge_panel.anchor_right = 1.0
	badge_panel.anchor_bottom = 0.0
	badge_panel.offset_left = -40
	badge_panel.offset_top = 6
	badge_panel.offset_right = -6
	badge_panel.offset_bottom = 28

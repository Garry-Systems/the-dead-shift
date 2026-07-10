class_name CoworkerTile
extends Button
## A square inventory tile for one rolled coworker instance — mirrors WeaponTile.gd exactly
## (rarity-colored border via PixelTheme.style_tile, an icon, name + rarity, an EQUIPPED
## badge, and the same Apocalypse/Armageddon per-frame repaint), but reads the coworker
## {uid,type,rarity,trait} shape via Coworkers/Rarity directly instead of WeaponInstance —
## both just resolve a "rarity" int off the instance dict, so the repaint logic is the same
## one-liner WeaponInstance.color() already wraps (Rarity.display_color), just called
## straight instead of through a weapon-specific helper. Emits tile_pressed(inst) on tap.

signal tile_pressed(inst: Dictionary)

const TILE_SIZE := Vector2(273, 273)
const ICON_SIZE := Vector2(169, 169)
const RAINBOW_REFRESH := 0.1   # seconds between repaints for an Apocalypse/Armageddon-rarity tile

var _inst: Dictionary
var _rarity_lbl: Label
var _rainbow := false          # true when this instance's rarity animates (rainbow / molten gold)
var _rainbow_accum := 0.0

## Builds the tile for a coworker instance. Call once right after instancing.
func setup(inst: Dictionary, is_equipped: bool) -> void:
	_inst = inst
	custom_minimum_size = TILE_SIZE
	clip_contents = true
	text = ""
	var rarity := int(inst.get("rarity", 1))
	PixelTheme.style_tile(self, Rarity.display_color(rarity))
	_rainbow = Rarity.is_animated(rarity)
	set_process(_rainbow)   # only rainbow-tier tiles pay a per-frame callback
	pressed.connect(func(): tile_pressed.emit(_inst))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	box.add_child(_build_icon(String(inst.get("type", "")), ICON_SIZE))

	var name_lbl := Label.new()
	name_lbl.text = Coworkers.name_for(String(inst.get("type", "")))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(name_lbl, 18, PixelTheme.TEXT)
	box.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = Rarity.tier_name(rarity)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(rarity_lbl, 14, Rarity.display_color(rarity))
	box.add_child(rarity_lbl)
	_rarity_lbl = rarity_lbl

	if is_equipped:
		_add_equipped_badge()

## Cheap visible-only repaint for the rainbow/molten tier — re-reads Rarity.display_color
## every RAINBOW_REFRESH seconds, only while this tile is actually on screen. Every other
## rarity is a flat color set once in setup() — no per-frame cost. Mirrors WeaponTile._process.
func _process(delta: float) -> void:
	if not _rainbow or not is_visible_in_tree():
		return
	_rainbow_accum += delta
	if _rainbow_accum < RAINBOW_REFRESH:
		return
	_rainbow_accum = 0.0
	var col := Rarity.display_color(int(_inst.get("rarity", 1)))
	PixelTheme.style_tile(self, col)
	if is_instance_valid(_rarity_lbl):
		_rarity_lbl.add_theme_color_override("font_color", col)

## The tile icon: per-type art if it exists (res://art/coworkers/<type>.png, not shipped
## until Task 5), else a drawn-glyph fallback — a colored bordered box with the type's
## single-letter glyph, using Companion.gd's own runtime palette (Coworkers.glyph_color)
## so the placeholder and the in-run companion sprite read as the same "thing".
func _build_icon(type: String, size: Vector2) -> Control:
	var tex := Coworkers.icon(type)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = size
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return r
	var col := Coworkers.glyph_color(type)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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

## A small green "EQ" badge pinned to the top-right corner. Identical to WeaponTile's.
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
	badge_panel.anchor_left = 1.0
	badge_panel.anchor_top = 0.0
	badge_panel.anchor_right = 1.0
	badge_panel.anchor_bottom = 0.0
	badge_panel.offset_left = -40
	badge_panel.offset_top = 6
	badge_panel.offset_right = -6
	badge_panel.offset_bottom = 28

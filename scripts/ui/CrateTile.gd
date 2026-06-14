class_name CrateTile
extends Button
## An inventory-grid tile for an owned (unopened) crate type: crate icon + name + an xN
## count badge, C2 indigo border. Emits crate_pressed(crate_id). Mirrors WeaponTile.

signal crate_pressed(crate_id: String)

const TILE_SIZE := Vector2(170, 170)
const ICON_SIZE := Vector2(96, 96)

var _crate_id := ""

func setup(crate: Dictionary, count: int) -> void:
	_crate_id = String(crate.get("id", ""))
	custom_minimum_size = TILE_SIZE
	clip_contents = true
	text = ""
	PixelTheme.style_tile(self, PixelTheme.ACCENT_DIM)   # C2 indigo border (crates have no rarity)
	pressed.connect(func(): crate_pressed.emit(_crate_id))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = Crates.icon(_crate_id)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(crate.get("name", "Crate"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(name_lbl, 13, PixelTheme.TEXT)
	box.add_child(name_lbl)

	if count > 1:
		_add_count_badge(count)

## A green "xN" badge pinned to the top-right corner (explicit rect, like WeaponTile's EQ).
func _add_count_badge(count: int) -> void:
	var badge_panel := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = PixelTheme.ACCENT
	bsb.set_corner_radius_all(0)
	bsb.anti_aliasing = false
	bsb.content_margin_left = 4
	bsb.content_margin_right = 4
	bsb.content_margin_top = 1
	bsb.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", bsb)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Label.new()
	badge.text = "x%d" % count
	badge.add_theme_font_override("font", PixelTheme.body_font())
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", PixelTheme.DARK)
	badge_panel.add_child(badge)
	add_child(badge_panel)
	badge_panel.anchor_left = 1.0
	badge_panel.anchor_top = 0.0
	badge_panel.anchor_right = 1.0
	badge_panel.anchor_bottom = 0.0
	badge_panel.offset_left = -44
	badge_panel.offset_top = 6
	badge_panel.offset_right = -6
	badge_panel.offset_bottom = 28

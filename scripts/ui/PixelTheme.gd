class_name PixelTheme
## Shared 32x32-style pixel UI kit: crisp (anti-alias-off) pixel fonts plus chunky,
## hard-cornered button / card styleboxes in the game's dusk + amber palette.
## Call the style_* helpers on any Control to give the menus a cohesive retro look.

# --- Palette (strict 4-color index: C1 void / C2 indigo / C3 gray-tan / C4 lavender) ---
const ACCENT      := Color(0.878, 0.898, 1.0)      # C4 lavender-white — titles, borders, pressed
const ACCENT_DIM  := Color(0.239, 0.0, 0.6)        # C2 indigo — resting borders
const TEXT        := Color(0.878, 0.898, 1.0)      # C4 — body text (high contrast on the void)
const TEXT_DIM    := Color(0.549, 0.522, 0.451)    # C3 gray-tan — secondary / unselected text
const SELECT      := Color(0.878, 0.898, 1.0)      # C4 — selected/active highlight (vs C3 dim)
const PANEL_BG    := Color(0.039, 0.0, 0.102, 0.92) # C1 void — translucent card
const BTN_BG      := Color(0.13, 0.0, 0.33, 0.96)  # C2 darkened — button fill
const BTN_HOVER   := Color(0.30, 0.05, 0.66, 0.98) # C2 brighter — hover
const DARK        := Color(0.039, 0.0, 0.102)      # C1 — text on a bright (C4) background
const DANGER      := Color(0.549, 0.522, 0.451)    # C3 gray-tan — destructive accents (in-palette "threat")
const OVERLAY_DIM := Color(0.039, 0.0, 0.102, 0.82) # C1 — full-screen scrim behind in-run menus

const TITLE_FONT_PATH := "res://fonts/PressStart2P-Regular.ttf"
const BODY_FONT_PATH  := "res://fonts/Silkscreen-Bold.ttf"

static var _title_font: FontFile
static var _body_font: FontFile

## Press Start 2P, configured for crisp pixel rendering (no anti-aliasing).
static func title_font() -> FontFile:
	if _title_font == null:
		_title_font = _pixelize(load(TITLE_FONT_PATH))
	return _title_font

## Silkscreen Bold, configured for crisp pixel rendering — readable at small sizes.
static func body_font() -> FontFile:
	if _body_font == null:
		_body_font = _pixelize(load(BODY_FONT_PATH))
	return _body_font

static func _pixelize(f: FontFile) -> FontFile:
	if f == null:
		return null
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f

# --- Styleboxes ---
static func _box(bg: Color, border: Color, bw: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)        # hard pixel corners
	sb.anti_aliasing = false           # no rounded-edge smoothing
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

## Big, touch-friendly pixel button with hover/press states.
static func style_button(b: Button, min_size: Vector2 = Vector2(460, 80), font_size: int = 22) -> void:
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _box(BTN_BG, ACCENT_DIM))
	b.add_theme_stylebox_override("hover", _box(BTN_HOVER, ACCENT))
	b.add_theme_stylebox_override("pressed", _box(ACCENT, ACCENT))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", DARK)
	b.add_theme_color_override("font_focus_color", TEXT)

## Title text: Press Start 2P, amber, with a hard 1:1 pixel drop shadow.
static func style_title(l: Label, size: int = 40) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 0)

## Section heading / body label in Silkscreen.
static func style_label(l: Label, size: int = 22, col: Color = TEXT) -> void:
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)

## Turns a PanelContainer into the translucent dark "card" the menu content sits on.
static func style_card(p: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = ACCENT_DIM
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_content_margin_all(32)
	p.add_theme_stylebox_override("panel", sb)

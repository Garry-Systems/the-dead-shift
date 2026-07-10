class_name Forecourt
extends Node2D
## The gas-station forecourt: the world structure the player spawns on (endless AND boss_rush —
## both modes run on the same Main.tscn/Spawner, so there is no separate boss-rush arena to
## gate this to). Instanced once from Main.tscn at world origin (0,0). Builds itself out of
## the same building blocks ObstacleField scatters (Destructible subclasses), so it gets
## bullet/cover/chain behavior for free, but with a distinct code-drawn look:
##   - one large indestructible cover body (the store) — blocks movement/bullets/LoS
##   - 3 "fuel_pump" Destructibles in a row — explosive, chain like barrels, bigger blast
##   - a tall GAS price sign — pure decoration, no collision
## ObstacleField is told to keep its scatter/cull away from this footprint (see its
## FORECOURT_KEEPOUT_RADIUS check + the no_cull flag read on every Destructible).

func _ready() -> void:
	# TRANSFER STORES (Task 3): this fixed structure is forecourt-only. Non-forecourt locations
	# (big_mart/parking_garage) build their OWN origin set-piece instead (MartFront.gd, etc.) —
	# Forecourt must no-op rather than overlay its own store+pumps+sign on top of theirs.
	if RunConfig.location != "forecourt":
		return
	add_to_group("forecourt")
	_build_store()
	_build_pumps()
	_build_sign()
	queue_redraw()

## One big indestructible cover body — mirrors a Destructible "cover" row (bit4, hp -1, group
## "cover") but with a custom rect size + a distinct drawn look (walls / band / door), plus a
## real "OPEN 24H" Label on the front band (same approach as the GAS sign's text).
func _build_store() -> void:
	var sb := StoreBuilding.new()
	sb.half_size = GameConfig.FORECOURT_STORE_HALF_SIZE
	sb.configure({
		"kind": "cover", "shape": "rect", "size": sb.half_size.x, "solid": true, "hp": -1.0,
		"hazard_id": "", "loot": "", "gem_count": 0, "color": PixelTheme.ACCENT_DIM,
	})
	sb.no_cull = true
	add_child(sb)
	sb.position = GameConfig.FORECOURT_STORE_POS
	var band := Label.new()
	band.text = "OPEN 24H"
	band.add_theme_font_override("font", PixelTheme.body_font())
	band.add_theme_font_size_override("font_size", 20)
	band.add_theme_color_override("font_color", PixelTheme.DARK)   # C1 text on the C4 band
	band.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	band.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.size = Vector2(sb.half_size.x * 2.0, GameConfig.FORECOURT_STORE_BAND_HEIGHT)
	band.position = Vector2(-sb.half_size.x, sb.half_size.y - GameConfig.FORECOURT_STORE_BAND_HEIGHT)
	sb.add_child(band)

## 3 fuel pumps in a row, using the shared "fuel_pump" Obstacles row verbatim (same hp/blast/
## fire-pool tuning + chain-fuse behavior as an ambient-scattered pump).
func _build_pumps() -> void:
	var row := Obstacles.by_id("fuel_pump")
	if row.is_empty():
		return   # defensive: registry row missing, skip rather than configure() on an empty dict
	for i in GameConfig.FORECOURT_PUMP_COUNT:
		var pump := FuelPump.new()
		pump.configure(row)
		pump.no_cull = true
		add_child(pump)
		pump.position = Vector2(
			GameConfig.FORECOURT_PUMP_START_X + float(i) * GameConfig.FORECOURT_PUMP_SPACING,
			GameConfig.FORECOURT_PUMP_Y
		)

## Tall pole + panel, non-colliding decoration. The pole/panel are drawn in _draw(); the price
## text is a plain Label child (Destructible draws no text at all, so there's no shape-drawing
## convention to mirror here — a label is the simplest correct option).
func _build_sign() -> void:
	var label := Label.new()
	label.text = "GAS 9.99"
	label.add_theme_font_override("font", PixelTheme.body_font())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", PixelTheme.ACCENT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = GameConfig.FORECOURT_SIGN_PANEL_SIZE
	label.position = GameConfig.FORECOURT_SIGN_POS - GameConfig.FORECOURT_SIGN_PANEL_SIZE * 0.5
	add_child(label)

func _draw() -> void:
	var panel_size := GameConfig.FORECOURT_SIGN_PANEL_SIZE
	var panel_pos := GameConfig.FORECOURT_SIGN_POS
	var pole_top := Vector2(panel_pos.x, panel_pos.y + panel_size.y * 0.5)
	var pole_bottom := Vector2(panel_pos.x, 0.0)
	draw_line(pole_top, pole_bottom, PixelTheme.DARK, GameConfig.FORECOURT_SIGN_POLE_WIDTH)
	var panel_rect := Rect2(panel_pos - panel_size * 0.5, panel_size)
	draw_rect(panel_rect, PixelTheme.DARK)          # C1 backing — "C4 on C1"
	draw_rect(panel_rect, PixelTheme.ACCENT, false, 3.0)   # C4 border

## The store cover body. Extends Destructible so it gets the collision-layer/group/health
## plumbing for free (hp -1 = indestructible, same as rubble); only the shape build + draw are
## overridden since the base class only knows squares/circles and a plain fill.
class StoreBuilding extends Destructible:
	var half_size := Vector2(170.0, 150.0)

	func _build_shape() -> void:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = half_size * 2.0
		cs.shape = rect
		add_child(cs)

	func _draw() -> void:
		var w := half_size.x
		var h := half_size.y
		var band_h := GameConfig.FORECOURT_STORE_BAND_HEIGHT
		var door_w := GameConfig.FORECOURT_STORE_DOOR_WIDTH
		var wall_rect := Rect2(Vector2(-w, -h), Vector2(w * 2.0, h * 2.0))
		draw_rect(wall_rect, color)                                                  # C2 walls
		# C4 "OPEN 24H" band on the SOUTH/front wall — player-facing (the apron + spawn are
		# south of the store). The text itself is a Label child added by Forecourt._build_store.
		draw_rect(Rect2(Vector2(-w, h - band_h), Vector2(w * 2.0, band_h)), PixelTheme.ACCENT)
		# Door gap (visual only — the body stays one solid collider): a C1 notch through the
		# front band, offset east of center so it doesn't sit under the band's label text.
		draw_rect(Rect2(Vector2(w * 0.6 - door_w * 0.5, h - band_h), Vector2(door_w, band_h)), PixelTheme.DARK)
		draw_rect(wall_rect, PixelTheme.DARK, false, 3.0)   # outline

## A fuel pump. Extends Destructible unmodified except for the look — the base rect/fill/
## outline is still correct (super._draw()), we just add pump-specific detail on top.
class FuelPump extends Destructible:
	func _draw() -> void:
		super._draw()
		var half := size
		# Hose detail (C1) — a short diagonal off the pump's side.
		draw_line(Vector2(half * 0.5, -half * 0.1), Vector2(half * 1.3, half * 0.5), PixelTheme.DARK, 3.0)
		# Price window (C4) on the pump's face.
		var win_size := Vector2(half * 1.0, half * 0.6)
		var win_rect := Rect2(Vector2(-win_size.x * 0.5, -half * 0.7), win_size)
		draw_rect(win_rect, PixelTheme.ACCENT)
		draw_rect(win_rect, PixelTheme.DARK, false, 1.5)
		# Flammable cap — the sanctioned hazard-orange accent, so the pump reads as explosive.
		draw_rect(Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 0.25)), Hazards.ORANGE)

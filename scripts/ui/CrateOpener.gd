class_name CrateOpener
extends Control
## CS:GO-style crate reveal: a VERTICAL reel of weapon tiles scrolls fast from the top of the
## screen toward the bottom, eases out, and snaps centered on a pre-rolled winner under a
## horizontal reticle; then a settle flash + reveal. The winner is committed (award + consume
## crate) on settle. Full-screen overlay, built in code, hidden by default.

signal closed()
signal weapon_revealed(inst: Dictionary)   # reel landed + committed → owner shows the full inspect

const TILE_W := 672.0        # reel tiles at ~80% of the old size (20% smaller per Larry 2026-06-27)
const TILE_H := 496.0
const ITEM_PX := 505.6       # TILE_H + ~10 gap — the VERTICAL pitch (reel runs top→bottom)
const REEL_COUNT := 80
const LAND_INDEX := 21       # winner slot near the TOP of the strip: the reel scrolls DOWN onto it,
                             # so tiles 22..79 stream through the reticle first and 0..20 buffer the overshoot
const START_INDEX := 73      # tile centered when the spin starts — sets the spin length (73→21 ≈ 52 tiles)
const FAST_SPEED := 7616.0   # px/sec linear phase (scales WITH the pitch so the ~2.5s spin feel is unchanged)
const SLOW_DIST := 8304.0    # begin ease-out this far from target — long, drawn-out decel
const SLOWDOWN := 0.9        # mid ease-out lerp factor (per-sec rate; unitless, unchanged by tile size) — kept
                            # so the reel decelerates smoothly instead of speeding up at the ease-out
const CRAWL_DIST := 1176.0   # final crawl begins ~2.3 tiles out — the tease zone
const CRAWL_SLOWDOWN := 0.82  # ultra-gentle final creep (per-sec rate; unchanged by tile size)
const TICK_PX := 505.6       # one tile-height per tick
const TICK_CD := 0.03        # min seconds between ticks
const TRIPLE_TAP_WINDOW := 0.6   # 3 taps within this many seconds skips the spin to the result

var _crate_id := ""
var _winner := {}
var _scroll_y := 0.0
var _target_y := 0.0
var _animating := false
var _last_tick_y := 0.0
var _tick_cd := 0.0
var _tap_count := 0           # taps landed inside the current TRIPLE_TAP_WINDOW
var _tap_window := 0.0        # seconds left to land the next tap of a triple
var _rainbow_tiles: Array = []   # {sb, rarity} for reel tiles at an ANIMATED rarity (rainbow/gold) — repainted every frame while spinning

var _mask: Control
var _reel: Control
var _flash_rect: ColorRect
var _tick_player: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 1.0)        # opaque black — full focus on the reel
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	# A full-height column (one tile wide, centered) that the reel scrolls down through.
	_mask = Control.new()
	_mask.clip_contents = true
	_mask.anchor_top = 0.0
	_mask.anchor_bottom = 1.0
	_mask.anchor_left = 0.5
	_mask.anchor_right = 0.5
	_mask.offset_left = -TILE_W / 2.0
	_mask.offset_right = TILE_W / 2.0
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_reel)

	# Horizontal reticle across the vertical center — the landing line.
	var reticle := ColorRect.new()
	reticle.color = PixelTheme.ACCENT
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_top = -3
	reticle.offset_bottom = 3
	reticle.offset_left = -TILE_W / 2.0 - 8.0
	reticle.offset_right = TILE_W / 2.0 + 8.0
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)

	_tick_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/tick.wav"):
		_tick_player.stream = load("res://audio/tick.wav")
	add_child(_tick_player)

## Starts the reel for an owned crate. Returns false (and starts nothing) if the crate isn't
## owned or the inventory has no room for the winner, so the caller (MainMenu) can report the
## failure instead of the tap silently doing nothing. A re-tap while already spinning is
## silently ignored (returns true — the open already succeeded, just not a new one).
func open(crate_id: String) -> bool:
	if visible:
		return true                 # already opening/spinning — ignore re-taps (no reel corruption)
	if SaveManager.crate_count(crate_id) <= 0 or Inventory.is_full():
		return false
	_crate_id = crate_id
	_winner = LootRoller.roll_from_crate(Crates.get_crate(crate_id))
	_flash_rect.color = Color(1, 1, 1, 0)
	_build_reel()
	visible = true
	_start_spin()
	return true

func _build_reel() -> void:
	for ch in _reel.get_children():
		ch.queue_free()
	_rainbow_tiles.clear()
	var crate := Crates.get_crate(_crate_id)
	var ceil_rarity := int(crate.get("rarity_ceil", Rarity.MAX_ID))
	# Salt the reel with top-of-crate "tease" tiles among those that stream PAST before the
	# winner lands (the "so close" heartbreak as a special rolls through the reticle early).
	# The winner's immediate neighbors (LAND_INDEX ± 1) are deliberately left as ordinary
	# crate rolls — a forced rare sitting right beside the landing slot would telegraph the
	# result before it settles, so we never seed one there.
	var tease := {28: true, 40: true, 52: true, 64: true, 70: true}
	for i in REEL_COUNT:
		var inst: Dictionary
		if i == LAND_INDEX:
			inst = _winner
		elif tease.has(i):
			inst = LootRoller.roll(ceil_rarity, "")   # a top-of-crate decoy to tease with
		else:
			inst = LootRoller.roll_from_crate(crate)
		var tile := _reel_tile(inst)
		tile.position = Vector2(0.0, i * ITEM_PX)
		_reel.add_child(tile)

func _reel_tile(inst: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(TILE_W, TILE_H)
	p.size = Vector2(TILE_W, TILE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PixelTheme.BTN_BG
	sb.border_color = WeaponInstance.color(inst)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	if Rarity.is_animated(int(inst.get("rarity", 1))):
		# repainted every frame while the reel spins — see _update_rainbow_tiles()
		_rainbow_tiles.append({ "sb": sb, "rarity": int(inst.get("rarity", 1)) })
	var icon := TextureRect.new()
	icon.texture = WeaponInstance.icon(inst)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 32
	icon.offset_top = 32
	icon.offset_right = -32
	icon.offset_bottom = -32
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	return p

func _start_spin() -> void:
	var view_h := get_viewport_rect().size.y
	var winner_center := LAND_INDEX * ITEM_PX + TILE_H / 2.0
	_target_y = view_h / 2.0 - winner_center + randf_range(-30.0, 30.0)
	# Begin with START_INDEX centered, then scroll DOWN (increasing y) onto the winner.
	var start_center := START_INDEX * ITEM_PX + TILE_H / 2.0
	_scroll_y = view_h / 2.0 - start_center
	_reel.position = Vector2(0.0, _scroll_y)
	_last_tick_y = _scroll_y
	_tick_cd = 0.0
	_tap_count = 0
	_tap_window = 0.0
	_animating = true

## Triple-tap ANYWHERE during the spin to skip straight to the result. We count only
## InputEventScreenTouch presses: the project has emulate_touch_from_mouse on, so an editor
## mouse click also arrives as exactly one touch (and on-device the emulated mouse is a
## separate type we ignore) — one count per real tap, no double-counting. MainMenu's
## drag-scroll _input already bails out while this overlay is visible, so taps don't leak.
func _input(event: InputEvent) -> void:
	if not visible or not _animating:
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	if _tap_window <= 0.0:
		_tap_count = 0
	_tap_count += 1
	_tap_window = TRIPLE_TAP_WINDOW
	get_viewport().set_input_as_handled()    # swallow the tap so nothing behind reacts
	if _tap_count >= 3:
		_tap_count = 0
		_tap_window = 0.0
		_skip_to_result()

## Snap the reel onto the pre-rolled winner and run the normal settle (flash → commit →
## reveal), so an impatient triple-tap lands the SAME result, just instantly.
func _skip_to_result() -> void:
	if not _animating:
		return
	_scroll_y = _target_y
	_reel.position.y = _scroll_y
	_animating = false
	_on_settle()

func _process(delta: float) -> void:
	if not _animating:
		return
	_update_rainbow_tiles()
	if _tap_window > 0.0:
		_tap_window -= delta
	_tick_cd = maxf(0.0, _tick_cd - delta)
	var dist := _target_y - _scroll_y
	var ad := absf(dist)
	if ad > SLOW_DIST:
		_scroll_y += signf(dist) * FAST_SPEED * delta
	elif ad > CRAWL_DIST:
		_scroll_y = lerpf(_scroll_y, _target_y, clampf(SLOWDOWN * delta, 0.0, 1.0))
	else:
		_scroll_y = lerpf(_scroll_y, _target_y, clampf(CRAWL_SLOWDOWN * delta, 0.0, 1.0))
	if absf(_scroll_y - _last_tick_y) >= TICK_PX and _tick_cd <= 0.0:
		_play_tick()
		_last_tick_y = _scroll_y
		_tick_cd = TICK_CD
	_reel.position.y = _scroll_y
	if absf(_scroll_y - _target_y) < 1.0:
		_scroll_y = _target_y
		_reel.position.y = _scroll_y
		_animating = false
		_on_settle()

## Free rainbow animation: the reel's _process already runs every frame while spinning, so
## repainting the handful of Apocalypse-rarity tile borders here costs nothing extra. Only runs
## while _animating — the settle beat (flash → commit → reveal) freezes on the last color, same
## as any other one-shot snapshot context.
func _update_rainbow_tiles() -> void:
	if _rainbow_tiles.is_empty():
		return
	for entry in _rainbow_tiles:
		(entry["sb"] as StyleBoxFlat).border_color = Rarity.display_color(int(entry["rarity"]))

func _play_tick() -> void:
	if _tick_player.stream != null:
		_tick_player.play()

func _on_settle() -> void:
	_flash(WeaponInstance.color(_winner))
	# Only proceed if the award actually committed (consume crate + add weapon). Guards
	# against a false reward if the commit ever fails (e.g. inventory full).
	if not Inventory.commit_crate(_crate_id, _winner):
		_close()
		return
	SoundManager.play("crate_win")
	# Brief beat to enjoy the landed tile + flash, then hand off to the full weapon inspect
	# (the SAME popup as tapping a gun in the inventory). The owner (MainMenu) opens it.
	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(self):
		return
	visible = false
	weapon_revealed.emit(_winner)

func _flash(col: Color) -> void:
	_flash_rect.color = Color(col.r, col.g, col.b, 0.5)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color", Color(col.r, col.g, col.b, 0.0), 0.4)

func _close() -> void:
	visible = false
	closed.emit()

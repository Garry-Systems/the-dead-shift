class_name CrateOpener
extends Control
## CS:GO-style crate reveal: a horizontal reel of weapon tiles scrolls fast, eases out,
## and snaps centered on a pre-rolled winner under a reticle; then a settle flash + reveal
## card. The winner is committed (award + consume crate) on settle. Ported from AfterDark's
## CrateSpinner. Full-screen overlay, built in code, hidden by default.

signal closed()

const TILE_W := 140.0
const TILE_H := 180.0
const ITEM_PX := 148.0      # TILE_W + 8 gap
const REEL_COUNT := 50
const LAND_INDEX := 42      # winner slot (7 decoys trail it)
const FAST_SPEED := 3000.0   # px/sec linear phase
const SLOW_DIST := 2400.0    # begin ease-out this far from target — long, drawn-out decel
const SLOWDOWN := 2.0        # mid ease-out lerp factor (x delta)
const CRAWL_DIST := 280.0    # final crawl begins ~1.9 tiles out — the tease zone
const CRAWL_SLOWDOWN := 1.5  # very gentle final creep — slow-rolls past the flanking special
const TICK_PX := 148.0      # one tile-width per tick
const TICK_CD := 0.03       # min seconds between ticks

var _crate_id := ""
var _winner := {}
var _scroll_x := 0.0
var _target_x := 0.0
var _animating := false
var _last_tick_x := 0.0
var _tick_cd := 0.0

var _mask: Control
var _reel: Control
var _reveal_card: PanelContainer
var _reveal_vbox: VBoxContainer
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

	_mask = Control.new()
	_mask.clip_contents = true
	_mask.anchor_left = 0.0
	_mask.anchor_right = 1.0
	_mask.anchor_top = 0.5
	_mask.anchor_bottom = 0.5
	_mask.offset_top = -TILE_H / 2.0
	_mask.offset_bottom = TILE_H / 2.0
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_reel)

	var reticle := ColorRect.new()
	reticle.color = PixelTheme.ACCENT
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_left = -3
	reticle.offset_right = 3
	reticle.offset_top = -TILE_H / 2.0 - 8.0
	reticle.offset_bottom = TILE_H / 2.0 + 8.0
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_reveal_card = PanelContainer.new()
	PixelTheme.style_card(_reveal_card)
	_reveal_card.custom_minimum_size = Vector2(minf(520.0, get_viewport_rect().size.x - 48.0), 0)
	_reveal_card.visible = false
	center.add_child(_reveal_card)
	_reveal_vbox = VBoxContainer.new()
	_reveal_vbox.add_theme_constant_override("separation", 14)
	_reveal_card.add_child(_reveal_vbox)

	_tick_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/tick.wav"):
		_tick_player.stream = load("res://audio/tick.wav")
	add_child(_tick_player)

func open(crate_id: String) -> void:
	if visible:
		return                      # already opening/spinning — ignore re-taps (no reel corruption)
	if SaveManager.crate_count(crate_id) <= 0 or Inventory.is_full():
		return
	_crate_id = crate_id
	_winner = LootRoller.roll_from_crate(Crates.get_crate(crate_id))
	_reveal_card.visible = false
	_flash_rect.color = Color(1, 1, 1, 0)
	_build_reel()
	visible = true
	_start_spin()

func _build_reel() -> void:
	for ch in _reel.get_children():
		ch.queue_free()
	var crate := Crates.get_crate(_crate_id)
	var ceil_rarity := int(crate.get("rarity_ceil", Rarity.MAX_ID))
	# Salt the reel with top-of-crate "tease" tiles: a few fly by as eye candy, plus ones
	# flanking the winner so a special slowly rolls THROUGH the reticle right before the
	# real drop lands (the "so close" heartbreak), with another sitting just off-center.
	var tease := {10: true, 19: true, 28: true, 36: true, (LAND_INDEX - 1): true, (LAND_INDEX + 1): true}
	for i in REEL_COUNT:
		var inst: Dictionary
		if i == LAND_INDEX:
			inst = _winner
		elif tease.has(i):
			inst = LootRoller.roll(ceil_rarity, "")   # a top-of-crate decoy to tease with
		else:
			inst = LootRoller.roll_from_crate(crate)
		var tile := _reel_tile(inst)
		tile.position = Vector2(i * ITEM_PX, 0.0)
		_reel.add_child(tile)

func _reel_tile(inst: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(TILE_W, TILE_H)
	p.size = Vector2(TILE_W, TILE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PixelTheme.BTN_BG
	sb.border_color = WeaponInstance.color(inst)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = WeaponInstance.icon(inst)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	return p

func _start_spin() -> void:
	var view_w := get_viewport_rect().size.x
	var winner_center := LAND_INDEX * ITEM_PX + TILE_W / 2.0
	_target_x = view_w / 2.0 - winner_center + randf_range(-30.0, 30.0)
	_scroll_x = 0.0
	_reel.position = Vector2(0.0, 0.0)
	_last_tick_x = 0.0
	_tick_cd = 0.0
	_animating = true

func _process(delta: float) -> void:
	if not _animating:
		return
	_tick_cd = maxf(0.0, _tick_cd - delta)
	var dist := _target_x - _scroll_x
	var ad := absf(dist)
	if ad > SLOW_DIST:
		_scroll_x += signf(dist) * FAST_SPEED * delta
	elif ad > CRAWL_DIST:
		_scroll_x = lerpf(_scroll_x, _target_x, clampf(SLOWDOWN * delta, 0.0, 1.0))
	else:
		_scroll_x = lerpf(_scroll_x, _target_x, clampf(CRAWL_SLOWDOWN * delta, 0.0, 1.0))
	if absf(_scroll_x - _last_tick_x) >= TICK_PX and _tick_cd <= 0.0:
		_play_tick()
		_last_tick_x = _scroll_x
		_tick_cd = TICK_CD
	_reel.position.x = _scroll_x
	if absf(_scroll_x - _target_x) < 1.0:
		_scroll_x = _target_x
		_reel.position.x = _scroll_x
		_animating = false
		_on_settle()

func _play_tick() -> void:
	if _tick_player.stream != null:
		_tick_player.play()

func _on_settle() -> void:
	_flash(WeaponInstance.color(_winner))
	# Only reveal if the award actually committed (consume crate + add weapon). Guards
	# against a false reward if the commit ever fails (e.g. inventory full).
	if Inventory.commit_crate(_crate_id, _winner):
		_show_reveal(_winner)
	else:
		_close()

func _flash(col: Color) -> void:
	_flash_rect.color = Color(col.r, col.g, col.b, 0.5)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color", Color(col.r, col.g, col.b, 0.0), 0.4)

func _show_reveal(inst: Dictionary) -> void:
	for c in _reveal_vbox.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = WeaponInstance.display_name(inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 24)
	title.add_theme_color_override("font_color", WeaponInstance.color(inst))
	_reveal_vbox.add_child(title)
	var stats := Label.new()
	stats.text = "%s  ·  %s" % [WeaponInstance.rarity_name(inst), WeaponInstance.stat_summary(inst)]
	stats.custom_minimum_size = Vector2(460, 0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(stats, 14, PixelTheme.TEXT_DIM)
	_reveal_vbox.add_child(stats)
	var tsum: String = WeaponInstance.talent_summary(inst)
	if tsum != "":
		var tl := Label.new()
		tl.text = "⟡ " + tsum
		tl.custom_minimum_size = Vector2(460, 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(tl, 13, PixelTheme.ACCENT)
		_reveal_vbox.add_child(tl)
	var cont := Button.new()
	cont.text = "CONTINUE"
	PixelTheme.style_button(cont, Vector2(0, 60), 18)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.pressed.connect(_close)
	_reveal_vbox.add_child(cont)
	_reveal_card.visible = true

func _close() -> void:
	visible = false
	closed.emit()

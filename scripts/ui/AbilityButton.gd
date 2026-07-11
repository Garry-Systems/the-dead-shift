class_name AbilityButton
extends Button
## The HUD ability-cast button: a fixed-size square, bottom-right anchored, that shows this run's
## character's signature ability and its live cooldown as a bottom-up fill. Built + owned by
## Hud.gd (only when Abilities.for_character(RunConfig.character_id) is non-empty) — Hud polls
## AbilityController.cooldown_fraction() every frame via set_cooldown_fraction() and wires
## `pressed` to a try_cast() call of its own; this class never reaches for the controller itself.

const READY_FLASH_WIDTH := 4.0    # px outline thickness of the ready flash
const COOLDOWN_FILL_ALPHA := 0.35 # C4 lavender @ low alpha — cooling veil
const READY_FLASH_ALPHA := 0.9    # C4 bright outline — ability ready
const NUDGE_PX := 10.0            # px horizontal offset of the denied-press nudge
const NUDGE_TIME := 0.1           # seconds total (spec: "a small 0.1s button nudge")

var _row: Dictionary = {}         # this run's ability row (Abilities.for_character result)
var _fraction := 0.0              # 0 ready ... 1 just cast, set every frame by Hud
var _rest_offset_left := 0.0      # resting anchor offset the nudge tween returns to

## Final-review fix (Finding 1a): joins "ability_button" so VirtualJoystick/Player can resolve
## this button by group lookup (the same pattern every cross-system read in this codebase already
## uses — see VirtualJoystick._resolve_ability_button, Player._unhandled_input) without either
## needing a direct scene reference to a node Hud builds and owns at runtime.
func _ready() -> void:
	add_to_group("ability_button")

## Positions + styles this button for `row` (an Abilities.for_character() result) and resolves
## its icon (real art if T9 has landed it, else a staged initial-letter fallback). Call once,
## right after `AbilityButton.new()`.
func setup(row: Dictionary) -> void:
	_row = row
	custom_minimum_size = Vector2(GameConfig.ABILITY_BUTTON_SIZE, GameConfig.ABILITY_BUTTON_SIZE)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	# Bottom-right, starter placement (F5 pass adjusts these against real thumbs) — the box is
	# pinned to GameConfig.ABILITY_BUTTON_SIZE so a future size change keeps it square.
	offset_right = -48.0
	offset_left = offset_right - GameConfig.ABILITY_BUTTON_SIZE
	offset_bottom = -332.0
	offset_top = offset_bottom - GameConfig.ABILITY_BUTTON_SIZE
	_rest_offset_left = offset_left
	PixelTheme.style_button(self, Vector2(GameConfig.ABILITY_BUTTON_SIZE, GameConfig.ABILITY_BUTTON_SIZE), 20)
	_setup_icon()

## art/abilities/<id>.png via ResourceLoader.exists (T9 lands the 7 real icons); until then, the
## button falls back to a big centered label showing the ability name's first letter.
func _setup_icon() -> void:
	var id := String(_row.get("id", ""))
	var path := "res://art/abilities/%s.png" % id
	if ResourceLoader.exists(path):
		icon = load(path)
		return
	var ability_name := String(_row.get("name", ""))
	var letter := ability_name.substr(0, 1) if ability_name != "" else "?"
	var letter_label := Label.new()
	letter_label.text = letter
	letter_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_title(letter_label, 64)
	add_child(letter_label)

## Called every frame by Hud with the controller's live cooldown_fraction() (0 ready .. 1 just
## cast). Only redraws when the value actually changed. Plays "ability_ready" exactly once, on
## the cooling->ready transition edge (T9) — this is the natural place for it: the button
## already owns `_fraction` and this is the only site that sees both the old and new value, so
## no separate flag is needed. `was_cooling` guards the very first call too (boot's _fraction
## starts at 0.0, so an already-ready ability at spawn never fires a false ping).
func set_cooldown_fraction(f: float) -> void:
	if is_equal_approx(_fraction, f):
		return
	var was_cooling := _fraction > 0.0
	_fraction = f
	queue_redraw()
	if was_cooling and _fraction <= 0.0:
		SoundManager.play("ability_ready")

## Small denial nudge for a press while still cooling (spec: "no spam" — no sound, just a brief
## visual no). Hud calls this when try_cast() returns false.
func nudge() -> void:
	var tw := create_tween()
	tw.tween_property(self, "offset_left", _rest_offset_left - NUDGE_PX, NUDGE_TIME * 0.5)
	tw.tween_property(self, "offset_left", _rest_offset_left, NUDGE_TIME * 0.5)

## Bottom-up cooldown fill (a lavender veil rising as the cooldown drains) + a bright outline
## flash once fully ready. Overlays on top of the button's own normal/hover/pressed stylebox —
## it doesn't replace it.
func _draw() -> void:
	var box_size := Vector2(GameConfig.ABILITY_BUTTON_SIZE, GameConfig.ABILITY_BUTTON_SIZE)
	var fill_h := box_size.y * _fraction
	if fill_h > 0.0:
		var fill_col := Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, COOLDOWN_FILL_ALPHA)
		draw_rect(Rect2(0.0, box_size.y - fill_h, box_size.x, fill_h), fill_col)
	if _fraction <= 0.0:
		var flash_col := Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, READY_FLASH_ALPHA)
		draw_rect(Rect2(Vector2.ZERO, box_size), flash_col, false, READY_FLASH_WIDTH)

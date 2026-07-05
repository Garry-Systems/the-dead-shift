class_name CombatText
extends Node2D
## Pooled floating combat text: gold crit-damage numbers + headline-proc callout words. ONE
## node, instanced into the run scene only (scenes/Main.tscn) — NOT an autoload, so menu scenes
## pay nothing. A PREALLOCATED fixed pool of GameConfig.COMBAT_TEXT_SLOTS plain-dict entries is
## drawn in a SINGLE _draw pass (draw_string_outline + draw_string, one cached font); push()
## never allocates once _ready has run — it only overwrites scalars in an existing dict.
##
## Access via the static `instance` (set in _ready, cleared in _exit_tree): CombatText.crit(...)
## / CombatText.callout(...) are safe to call from anywhere in gameplay code and are a silent
## no-op before the run scene attaches this node (or after it tears down) — exactly the pattern
## a headless probe needs too.
##
## RULES (see the Talent Overhaul design doc, "Combat text system"):
##  (a) NUMBERS = crit damage ONLY, gold, roundi(damage), per-enemy ICD.
##  (b) CALLOUTS = headline-proc words only, family color.
##  (c) An identical LIVE callout word refreshes in place (reset age) instead of taking a slot.
##  (d) 16 slots, max 4 new pops/frame (excess silently dropped); on exhaustion steal the
##      lowest-priority oldest entry (callouts outrank crit numbers).
##  (e) No per-hit damage numbers, no heal text — small procs are tints/motes/rings only.

const OUTLINE_COLOR := Color(0.039, 0.0, 0.102)   # C1 void
const GOLD := Color(1.0, 0.843, 0.0)              # crit numbers (matches Hazards.GOLD)

const PRIORITY_CRIT := 0
const PRIORITY_CALLOUT := 1

static var instance: CombatText = null

var _slots: Array = []
var _font: FontFile
var _pop_frame := -1
var _pop_count := 0

func _ready() -> void:
	z_index = 90
	_font = PixelTheme.body_font()
	_slots.clear()
	for i in GameConfig.COMBAT_TEXT_SLOTS:
		_slots.append({
			"pos": Vector2.ZERO, "age": 0.0, "text": "", "color": Color.WHITE,
			"size": GameConfig.COMBAT_TEXT_CRIT_SIZE, "priority": PRIORITY_CRIT,
			"kind": "", "x_off": 0.0, "alive": false,
		})
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

## The one per-hit number the game shows: a gold crit-damage popup. Spatially deduped against
## any still-live crit number within COMBAT_TEXT_CRIT_DEDUPE_RADIUS inside COMBAT_TEXT_CRIT_ICD
## seconds — the API takes no enemy handle, so proximity to an existing gold number stands in
## for "same enemy" (a beam/cone re-crit on one target within the ICD can't stack a column).
static func crit(world_pos: Vector2, amount: float) -> void:
	if instance == null:
		return
	instance._push_crit(world_pos, amount)

## A headline-proc word (FRENZY, SHATTER, EXECUTED, ...). Refreshes an existing live entry with
## the same word (reset age, small re-pop) instead of taking a new slot.
static func callout(world_pos: Vector2, word: String, color: Color) -> void:
	if instance == null:
		return
	instance._push_callout(world_pos, word, color)

func _push_crit(pos: Vector2, amount: float) -> void:
	for s in _slots:
		if not bool(s["alive"]) or String(s["kind"]) != "crit":
			continue
		if float(s["age"]) >= GameConfig.COMBAT_TEXT_CRIT_ICD:
			continue
		var d := GameConfig.COMBAT_TEXT_CRIT_DEDUPE_RADIUS
		if (s["pos"] as Vector2).distance_squared_to(pos) <= d * d:
			return   # per-enemy ICD: drop, don't stack a second gold column
	_push(pos, str(roundi(amount)), GOLD, GameConfig.COMBAT_TEXT_CRIT_SIZE, PRIORITY_CRIT, "crit")

func _push_callout(pos: Vector2, word: String, color: Color) -> void:
	for s in _slots:
		if bool(s["alive"]) and String(s["kind"]) == "callout" and String(s["text"]) == word \
				and float(s["age"]) < GameConfig.COMBAT_TEXT_CALLOUT_DEDUPE:
			s["age"] = 0.0
			s["pos"] = pos
			return   # refresh in place — dedupe-by-word, not position
	_push(pos, word, color, GameConfig.COMBAT_TEXT_CALLOUT_SIZE, PRIORITY_CALLOUT, "callout")

## Shared slot-claim: writes into a preallocated dict (never allocates). Frame-capped and
## priority-evicting per rule (d).
func _push(pos: Vector2, text: String, color: Color, size: int, priority: int, kind: String) -> void:
	var frame := Engine.get_process_frames()
	if _pop_frame != frame:
		_pop_frame = frame
		_pop_count = 0
	if _pop_count >= GameConfig.COMBAT_TEXT_MAX_POPS_PER_FRAME:
		return   # excess silently dropped, never queued
	var slot = _find_slot()
	if slot == null:
		return
	_pop_count += 1
	slot["pos"] = pos
	slot["age"] = 0.0
	slot["text"] = text
	slot["color"] = color
	slot["size"] = size
	slot["priority"] = priority
	slot["kind"] = kind
	slot["alive"] = true
	slot["x_off"] = randf_range(-GameConfig.COMBAT_TEXT_X_JITTER, GameConfig.COMBAT_TEXT_X_JITTER)
	queue_redraw()

## A dead slot if one exists; else the lowest-priority, oldest live slot (callouts outrank crit
## numbers; ties broken by age — closest to death goes first). Never null once the pool exists.
func _find_slot() -> Variant:
	for s in _slots:
		if not bool(s["alive"]):
			return s
	if _slots.is_empty():
		return null
	var worst: Dictionary = _slots[0]
	for s in _slots:
		if int(s["priority"]) < int(worst["priority"]):
			worst = s
		elif int(s["priority"]) == int(worst["priority"]) and float(s["age"]) > float(worst["age"]):
			worst = s
	return worst

func _process(delta: float) -> void:
	var any_alive := false
	for s in _slots:
		if not bool(s["alive"]):
			continue
		s["age"] = float(s["age"]) + delta
		if float(s["age"]) >= GameConfig.COMBAT_TEXT_LIFE:
			s["alive"] = false
			continue
		any_alive = true
	if any_alive:
		queue_redraw()

func _draw() -> void:
	if _font == null:
		return
	for s in _slots:
		if bool(s["alive"]):
			_draw_entry(s)

func _draw_entry(s: Dictionary) -> void:
	var age: float = s["age"]
	var life := GameConfig.COMBAT_TEXT_LIFE
	var scale := 1.0
	if age < GameConfig.COMBAT_TEXT_POP_TIME:
		scale = lerpf(1.15, 1.0, age / GameConfig.COMBAT_TEXT_POP_TIME)
	var alpha := 1.0
	var fade_start := life - GameConfig.COMBAT_TEXT_FADE_TIME
	if age > fade_start:
		alpha = clampf((life - age) / GameConfig.COMBAT_TEXT_FADE_TIME, 0.0, 1.0)
	var rise := GameConfig.COMBAT_TEXT_RISE_PX * (age / life)
	var local := to_local(s["pos"]) + Vector2(float(s["x_off"]), -rise)
	var size := int(round(int(s["size"]) * scale))
	var col: Color = s["color"]
	var text: String = s["text"]
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var draw_pos := local - Vector2(text_size.x * 0.5, 0.0)
	draw_string_outline(_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2,
		Color(OUTLINE_COLOR.r, OUTLINE_COLOR.g, OUTLINE_COLOR.b, alpha))
	draw_string(_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(col.r, col.g, col.b, alpha))

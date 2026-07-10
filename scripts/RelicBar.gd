extends CanvasLayer
## Top-center relic bar (4 slots normally, 6 while Overstocked is held). Owns the run's relic
## state (held relics) and renders the held slots. Found via the "relic_bar" group. Process mode
## ALWAYS so RelicChoice/PauseMenu can mutate it while the tree is paused.
##
## Relics Overhaul (Task 3): the bar is the ONE place a relic's effect gets turned on/off, routed
## by family so every caller (RelicChoice's take/swap flow, PauseMenu's SCRAP button) can just
## call take()/remove_relic()/scrap() with an id and never care whether it's STANDARD
## (Relics.apply/remove — reversible delta/ratio) or PROTOTYPE/CURSED (RelicEffects.equip/unequip
## — hook owns its own reversal state). See _apply_held/_reverse_held.
##
## Task 4: rendering is now slot-count-driven (_rebuild_slots(), called from _build_ui() and
## again from set_slot_count() on a real capacity change) instead of a fixed
## GameConfig.MAX_RELIC_SLOTS loop — see _rebuild_slots()/_refresh() below for the overstocked
## 6-slot draw and the over-capacity render-clamp.

var _player: Player
var _labels: Array[Label] = []
var _hbox: HBoxContainer

# Run state.
var _held: Array = []          # each entry: {"id": String, "delta": float} (delta unused/0.0 for hook-mode ids)
var _slot_count := GameConfig.MAX_RELIC_SLOTS   # capacity; Overstocked raises this via set_slot_count()

func _ready() -> void:
	add_to_group("relic_bar")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	center.offset_top = 34
	center.offset_bottom = 80
	add_child(center)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 8)
	center.add_child(_hbox)

	_rebuild_slots()

## Slot-count-driven (Task 4): tears down and redraws the Panel/Label row for the CURRENT
## `_slot_count` (4 normally, 6 while Overstocked is held). Called once from _build_ui() and
## again from set_slot_count() whenever the count actually changes, so equipping/unequipping
## Overstocked mid-run grows/shrinks the bar cleanly instead of the old fixed 4-slot loop.
## `queue_free()`-then-immediately-repopulate mirrors this codebase's existing rebuild idiom
## (PauseMenu._populate_relics / RelicChoice._clear_vbox) — a stale label may still be in the
## tree for the remainder of this frame, but _labels is already repointed at the new ones.
func _rebuild_slots() -> void:
	if _hbox == null:
		return
	for c in _hbox.get_children():
		c.queue_free()
	_labels.clear()
	for i in _slot_count:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)
		_hbox.add_child(slot)
		var lbl := Label.new()
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(lbl)
		_labels.append(lbl)

## Iterates `_labels.size()` (the CURRENT slot count), never a fixed constant, and never reads
## `_held[i]` past `_held.size()`. This is also the over-capacity safety valve: if `_held.size()`
## is ever momentarily greater than `_slot_count` (e.g. mid-scrap of Overstocked itself — its
## `RelicEffects.unequip` -> `set_slot_count(4)` call lands before that same scrap() call has
## removed the id from `_held`), the loop simply stops at the last real slot and the extra held
## relic(s) just don't get an icon this frame — a visual clamp, not a crash. Their effects stay
## fully active regardless; T3's swap flow is what actually prevents the bar from being LEFT in
## that state (see RelicChoice._scrap_candidates/_on_scrap).
func _refresh() -> void:
	for i in _labels.size():
		if i < _held.size():
			var id: String = _held[i]["id"]
			var r := Relics.get_relic(id)
			_labels[i].text = String(r["name"]).substr(0, 2) if not r.is_empty() else ""
		else:
			_labels[i].text = ""

# --- run-state API (called by RelicChoice + PauseMenu + Boss drop) ---

## Reverses all held effects and clears state (for a future in-place restart).
func reset() -> void:
	for entry in _held:
		_reverse_held(entry)
	_held.clear()
	_refresh()

func is_full() -> bool:
	return _held.size() >= _slot_count

func held_ids() -> Array:
	var ids: Array = []
	for e in _held:
		ids.append(e["id"])
	return ids

func has_relic(id: String) -> bool:
	return id in held_ids()

## Adds a relic and applies its effect via the correct family path (records whatever
## _reverse_held() needs later). No-op if full or already owned.
func take(id: String) -> void:
	if is_full() or has_relic(id):
		return
	var delta := _apply_held(id)
	_held.append({"id": id, "delta": delta})
	_refresh()

## Removes a held relic and reverses its effect via the correct family path.
func remove_relic(id: String) -> void:
	for i in _held.size():
		if _held[i]["id"] == id:
			_reverse_held(_held[i])
			_held.remove_at(i)
			_refresh()
			return

## Frees a held relic's slot (reverses its effect, same as remove_relic) AND pays its scrap
## value to run coins (RunStats.add_coins): RELIC_CURSED_SCRAP_COINS for a held CURSED relic,
## RELIC_SCRAP_COINS otherwise. Returns the coins paid (0 if `id` isn't currently held). The ONE
## shared scrap entry point — RelicChoice's full-bar swap flow (Task 3) and the pause-menu SCRAP
## button (Task 4) both route through this so a slot is never freed without its payout, or vice
## versa.
func scrap(id: String) -> int:
	for i in _held.size():
		if _held[i]["id"] == id:
			_reverse_held(_held[i])
			_held.remove_at(i)
			_refresh()
			var coins := scrap_value(id)
			RunStats.add_coins(coins)
			return coins
	return 0

## Coins scrap() will pay for `id`, by family (RELIC_CURSED_SCRAP_COINS for CURSED,
## RELIC_SCRAP_COINS otherwise). Pure lookup — `id` doesn't need to be currently held, so this
## also doubles as the label source for a not-yet-tapped SCRAP button. scrap() itself calls this
## SAME function (see above), so the pause-menu SCRAP button (Task 4) can read the exact number
## scrap() is about to pay and the two can never drift apart.
func scrap_value(id: String) -> int:
	return GameConfig.RELIC_CURSED_SCRAP_COINS if Relics.family_of(id) == "cursed" else GameConfig.RELIC_SCRAP_COINS

## Takes a relic; if the bar is full, replaces the oldest held one. No-op if already owned.
## Superseded by RelicChoice's player-driven "pick one to scrap" swap flow (Task 3) — kept only
## because RelicMenu.gd (orphaned since the auto-collect refactor; nothing calls RelicMenu.open()
## today, see RelicPickup.gd) still references it directly.
func take_or_replace(id: String) -> void:
	if has_relic(id):
		return
	if is_full() and not _held.is_empty():
		remove_relic(_held[0]["id"])
	take(id)

## Rolls one relic id that is not already owned; "" if none available. Superseded by
## Relics.roll_choice() (Task 1) for the RELIC CHOICE overlay's pair draw — kept only for
## BossBase.gd's existing single-roll drop-gate call (see RelicPickup.gd's header comment).
func roll_drop() -> String:
	var candidates: Array = []
	for r in Relics.all():
		var id: String = r["id"]
		if not has_relic(id):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	candidates.shuffle()
	return candidates[0]

## Updates the bar's held-relic capacity (Overstocked: MAX_RELIC_SLOTS -> +RELIC_OVERSTOCK_SLOTS,
## reversed back on unequip). is_full()/the swap-flow gate read `_slot_count` immediately.
## Task 4: now ALSO drives the on-screen slot row — a real capacity change (n != current)
## triggers `_rebuild_slots()` (redraws the Panel/Label row for the new count) + `_refresh()`
## (repaints held icons into it), so growing to 6 or shrinking back to 4 redraws cleanly with no
## leftover/missing slots. No-ops if `n` matches the current count (avoids a pointless rebuild on
## a redundant call). Called by RelicEffects (has_method-guarded) when Overstocked is
## equipped/unequipped.
func set_slot_count(n: int) -> void:
	if n == _slot_count:
		return
	_slot_count = n
	_rebuild_slots()
	_refresh()

# --- family routing (STANDARD -> Relics.apply/remove; PROTOTYPE/CURSED -> RelicEffects.equip/
# unequip) — the one place take()/remove_relic()/reset()/scrap() decide which path to use, so
# the bar can store every held id uniformly regardless of family. ---

## Applies `id`'s effect via the correct family path and returns the value _reverse_held() needs
## later. Hook-mode ids (PROTOTYPE/CURSED) store 0.0 — RelicEffects tracks its own reversal state
## internally, keyed by id; Relics.apply() would just no-op+warn on these anyway (T1's guard).
func _apply_held(id: String) -> float:
	if Relics.family_of(id) == "standard":
		return Relics.apply(_player, id)
	RelicEffects.equip(id)
	return 0.0

## Reverses one `_held` entry via the same family routing.
func _reverse_held(entry: Dictionary) -> void:
	var id: String = entry["id"]
	if Relics.family_of(id) == "standard":
		Relics.remove(_player, id, entry["delta"])
	else:
		RelicEffects.unequip(id)

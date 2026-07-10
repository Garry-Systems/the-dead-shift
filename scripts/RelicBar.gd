extends CanvasLayer
## Top-center 4-slot relic bar. Owns the run's relic state (held relics) and renders the
## held slots. Found via the "relic_bar" group. Process mode ALWAYS so RelicChoice/PauseMenu
## can mutate it while the tree is paused.
##
## Relics Overhaul (Task 3): the bar is now the ONE place a relic's effect gets turned on/off,
## routed by family so every caller (RelicChoice's take/swap flow, PauseMenu's REMOVE, a future
## SCRAP button) can just call take()/remove_relic()/scrap() with an id and never care whether
## it's STANDARD (Relics.apply/remove — reversible delta/ratio) or PROTOTYPE/CURSED
## (RelicEffects.equip/unequip — hook owns its own reversal state). See _apply_held/_reverse_held.

var _player: Player
var _labels: Array[Label] = []

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

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	center.add_child(hbox)

	for i in GameConfig.MAX_RELIC_SLOTS:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)
		hbox.add_child(slot)
		var lbl := Label.new()
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(lbl)
		_labels.append(lbl)

func _refresh() -> void:
	for i in GameConfig.MAX_RELIC_SLOTS:
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
			var cursed := Relics.family_of(id) == "cursed"
			var coins := GameConfig.RELIC_CURSED_SCRAP_COINS if cursed else GameConfig.RELIC_SCRAP_COINS
			RunStats.add_coins(coins)
			return coins
	return 0

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
## reversed back on unequip). Bookkeeping only: is_full()/the swap-flow gate read this
## immediately, but the bar's on-screen slot rendering (_build_ui/_refresh's fixed
## GameConfig.MAX_RELIC_SLOTS loop) is UNCHANGED here — that visual piece is Task 4's job per the
## plan ("verify the bar's draw is slot-count-driven or fix it to be"). A 5th/6th held relic's
## effect is fully active even before its slot icon renders. Called by RelicEffects
## (has_method-guarded) when Overstocked is equipped/unequipped.
func set_slot_count(n: int) -> void:
	_slot_count = n

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

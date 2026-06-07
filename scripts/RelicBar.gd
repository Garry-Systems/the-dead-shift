extends CanvasLayer
## Top-center 4-slot relic bar. Owns the run's relic state (held relics + banned ids)
## and renders the held slots. Found via the "relic_bar" group. Process mode ALWAYS so
## the RelicMenu can mutate it while the tree is paused.

var _player: Player
var _labels: Array[Label] = []

# Run state.
var _held: Array = []          # each entry: {"id": String, "delta": float}
var _banned := {}              # id -> true

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

# --- run-state API (called by RelicMenu + Boss drop) ---

## Reverses all held effects and clears state (for a future in-place restart).
func reset() -> void:
	for entry in _held:
		Relics.remove(_player, entry["id"], entry["delta"])
	_held.clear()
	_banned.clear()
	_refresh()

func is_full() -> bool:
	return _held.size() >= GameConfig.MAX_RELIC_SLOTS

func held_ids() -> Array:
	var ids: Array = []
	for e in _held:
		ids.append(e["id"])
	return ids

func has_relic(id: String) -> bool:
	return id in held_ids()

func is_banned(id: String) -> bool:
	return _banned.has(id)

## Adds a relic and applies its effect (records the delta). No-op if full or owned.
func take(id: String) -> void:
	if is_full() or has_relic(id):
		return
	var delta := Relics.apply(_player, id)
	_held.append({"id": id, "delta": delta})
	_refresh()

func ban(id: String) -> void:
	_banned[id] = true

## Removes a held relic and reverses its effect.
func remove_relic(id: String) -> void:
	for i in _held.size():
		if _held[i]["id"] == id:
			Relics.remove(_player, id, _held[i]["delta"])
			_held.remove_at(i)
			_refresh()
			return

## Replaces a held relic with a new one (full-bar swap).
func swap(old_id: String, new_id: String) -> void:
	remove_relic(old_id)
	take(new_id)

## Rolls one relic id that is neither owned nor banned; "" if none available.
func roll_drop() -> String:
	var candidates: Array = []
	for r in Relics.all():
		var id: String = r["id"]
		if not has_relic(id) and not is_banned(id):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	candidates.shuffle()
	return candidates[0]

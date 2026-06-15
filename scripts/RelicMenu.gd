extends CanvasLayer
## Opened when the player walks over a relic pickup. Pauses the game and offers a simple
## Take / Skip choice. If the relic bar is full, Take replaces the oldest held relic.
## Found via "relic_menu".

var _player: Player
var _bar                       # RelicBar (CanvasLayer)
var _root: Control
var _vbox: VBoxContainer
var _new_id := ""
var _pickup: Node              # the RelicPickup that opened us (freed on resolve)

func _ready() -> void:
	add_to_group("relic_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	_player = get_tree().get_first_node_in_group("player") as Player
	_bar = get_tree().get_first_node_in_group("relic_bar")
	_build_root()
	_root.visible = false

func _build_root() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = PixelTheme.OVERLAY_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 12)
	card.add_child(_vbox)

## Called by a RelicPickup when the player walks into it.
func open(new_id: String, pickup: Node) -> void:
	if _root.visible:
		return                  # already resolving one pickup
	if _bar == null:
		pickup.queue_free()    # no relic bar in scene -> can't take; discard safely
		return
	_new_id = new_id
	_pickup = pickup
	_clear_vbox()

	var r := Relics.get_relic(new_id)
	_add_label("%s\n%s" % [r.get("name", new_id), r.get("desc", "")])
	if _bar.is_full():
		_add_label("Bar full — Take replaces your oldest relic.")

	_add_button("Take", func(): _bar.take_or_replace(_new_id); _close())
	_add_button("Skip", func(): _close())

	_root.visible = true
	get_tree().paused = true

func _close() -> void:
	if _pickup and is_instance_valid(_pickup):
		_pickup.queue_free()
	_root.visible = false
	get_tree().paused = false

# --- tiny UI helpers ---
func _clear_vbox() -> void:
	for c in _vbox.get_children():
		c.queue_free()

func _add_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(440, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(l, 16, PixelTheme.TEXT)
	_vbox.add_child(l)

func _add_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text.to_upper()
	PixelTheme.style_button(b, Vector2(440, 64), 18)
	b.pressed.connect(cb)
	_vbox.add_child(b)

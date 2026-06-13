extends CanvasLayer
## The pre-run weapon-select screen, built in code. Now backed by the weapon-loot
## inventory: it lists the player's OWNED rolled weapons (rarity-coloured, with their
## rolled stats), lets them open coin crates to roll more, and on pick configures the
## gun from the instance's base + applies the rolled stats, then starts the run.

var _player: Player
var _root: Control

func _ready() -> void:
	# Keep this UI alive and clickable while the rest of the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11

	_player = get_tree().get_first_node_in_group("player") as Player
	Inventory.grant_starter()        # first-launch seed so the list is never empty

	_refresh()
	get_tree().paused = true

## Tears down and rebuilds the whole screen (called after opening a crate).
func _refresh() -> void:
	if _root != null:
		_root.queue_free()
	_build_ui()

func _build_ui() -> void:
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
	card.custom_minimum_size = Vector2(560, 760)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE YOUR WEAPON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 26)
	vbox.add_child(title)

	# Coins + crate buttons.
	var coins := Label.new()
	coins.text = "COINS: %d" % Inventory.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 16, PixelTheme.TEXT_DIM)
	vbox.add_child(coins)

	var crate_row := HBoxContainer.new()
	crate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crate_row.add_theme_constant_override("separation", 10)
	vbox.add_child(crate_row)
	for crate in Crates.all():
		var cb := Button.new()
		cb.text = "%s (%d)" % [String(crate["name"]).to_upper(), int(crate["price"])]
		PixelTheme.style_button(cb, Vector2(225, 52), 15)
		cb.disabled = Inventory.coins() < int(crate["price"]) or Inventory.is_full()
		cb.pressed.connect(_on_crate_pressed.bind(String(crate["id"])))
		crate_row.add_child(cb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 560)
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# Owned weapons, best rarity first.
	var owned := Inventory.weapons().duplicate()
	owned.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_uid := Inventory.equipped_uid()

	for inst in owned:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var b := Button.new()
		var is_equipped: bool = String(inst.get("uid", "")) == equipped_uid
		b.text = WeaponInstance.display_name(inst).to_upper() + ("  ◀" if is_equipped else "")
		PixelTheme.style_button(b, Vector2(460, 60), 18)
		b.add_theme_color_override("font_color", WeaponInstance.color(inst))
		b.pressed.connect(_on_weapon_pressed.bind(inst))
		row.add_child(b)

		var desc := Label.new()
		var dtext := "%s  ·  %s" % [WeaponInstance.rarity_name(inst), WeaponInstance.stat_summary(inst)]
		var tsum: String = WeaponInstance.talent_summary(inst)
		if tsum != "":
			dtext += "\n⟡ " + tsum
		desc.text = dtext
		desc.custom_minimum_size = Vector2(460, 0)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(desc, 12, PixelTheme.TEXT_DIM)
		row.add_child(desc)

		list.add_child(row)

func _on_crate_pressed(crate_id: String) -> void:
	var inst := Inventory.open_crate(crate_id)
	# inst is the freshly rolled weapon (or {} if it failed). Rebuild to show it.
	_refresh()

func _on_weapon_pressed(inst: Dictionary) -> void:
	if _player and _player.gun:
		var base := WeaponInstance.base_def(inst)
		if not base.is_empty():
			_player.gun.configure(base)
			_player.gun.apply_loot(inst)
			Characters.apply_weapon(_player, RunConfig.character_id)
			Inventory.equip(String(inst.get("uid", "")))
	queue_free()
	get_tree().paused = false

class_name RewardPopup
extends Control
## A full-screen reward reveal: scrim + card with a title, the reward's icon + name, and a
## CLAIM button. Used by MainMenu for the daily-login crate and the every-10-games reward.
## The reward is already granted before this shows — the popup is just the reveal. Reusable
## per reward in a queue (open() rebuilds its content); emits claimed() when CLAIM is pressed.

signal claimed()

var _title: Label
var _icon: TextureRect
var _name: Label
var _sub: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP   # block taps to the menu behind
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(_title, 40)
	vbox.add_child(_title)

	var free := Label.new()
	free.text = "FREE REWARD!"
	free.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(free, 22, PixelTheme.SELECT)
	vbox.add_child(free)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(220, 220)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_icon)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_name, 30, PixelTheme.TEXT)
	vbox.add_child(_name)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_sub, 20, PixelTheme.TEXT_DIM)
	vbox.add_child(_sub)

	vbox.add_child(_spacer(4))

	var btn := Button.new()
	btn.text = "CLAIM"
	PixelTheme.style_button(btn, Vector2(440, 100), 32)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_claim)
	vbox.add_child(btn)

## Reveal one already-granted reward. `title` = the source ("DAILY REWARD" / "10-GAME REWARD").
## reward = { kind:"crate", crate_id } or { kind:"gun", inst }.
func open(title: String, reward: Dictionary) -> void:
	_title.text = title
	match String(reward.get("kind", "")):
		"crate":
			var cid := String(reward.get("crate_id", ""))
			_icon.texture = Crates.icon(cid)
			_name.text = String(Crates.get_crate(cid).get("name", "Crate")).to_upper()
			_name.add_theme_color_override("font_color", PixelTheme.ACCENT)
			_sub.text = "Crate added to your inventory"
		"gun":
			var inst: Dictionary = reward.get("inst", {})
			_icon.texture = WeaponInstance.icon(inst)
			_name.text = WeaponInstance.display_name(inst).to_upper()
			_name.add_theme_color_override("font_color", WeaponInstance.color(inst))
			_sub.text = WeaponInstance.rarity_name(inst) + " — added to your inventory"
	visible = true

func _on_claim() -> void:
	visible = false
	claimed.emit()

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

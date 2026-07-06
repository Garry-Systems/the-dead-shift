class_name RewardPopup
extends Control
## A full-screen reward reveal: scrim + card with a title, the reward's icon + name, and a
## CLAIM button. Used by MainMenu for the daily-login crate and the every-10-games reward.
## The reward is already granted before this shows — the popup is just the reveal. Reusable
## per reward in a queue (open() rebuilds its content); emits claimed() when CLAIM is pressed.

signal claimed()

var _title: Label
var _streak: Label
var _free_label: Label   # "FREE REWARD!" — hidden for a PROMOTED reveal (Pack G), which isn't a "reward" claim
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

	# Daily-streak line (Pack 4): small, dimmed C4 lavender (PixelTheme.ACCENT darkened) so it
	# reads as a subtitle under the bright full-ACCENT title above. Hidden unless open() is
	# given a reward with a "streak" entry (currently: the daily-login reward only).
	_streak = Label.new()
	_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_streak, 18, PixelTheme.ACCENT.darkened(0.45))
	_streak.visible = false
	vbox.add_child(_streak)

	_free_label = Label.new()
	_free_label.text = "FREE REWARD!"
	_free_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_free_label, 22, PixelTheme.SELECT)
	vbox.add_child(_free_label)

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

## Reveal one already-granted reward. `title` = the source ("DAILY REWARD" / "10-GAME REWARD" /
## "PROMOTED!" / "COMMENDATION EARNED"). reward = { kind:"crate", crate_id } or { kind:"gun", inst }
## or (Pack G) { kind:"rank", rank, unlocked: Array[String] } or (Pack H) { kind:"commendation",
## id } — optionally with a "streak" int (Pack 4, daily reward only) that shows a "STREAK: DAY N"
## line under the title.
func open(title: String, reward: Dictionary) -> void:
	_title.text = title
	if reward.has("streak"):
		_streak.text = "STREAK: DAY %d" % int(reward["streak"])
		_streak.visible = true
	else:
		_streak.visible = false
	_free_label.visible = true
	_icon.visible = true
	match String(reward.get("kind", "")):
		"crate":
			_icon.texture = Crates.icon(String(reward.get("crate_id", "")))
			_name.text = String(Crates.get_crate(String(reward.get("crate_id", ""))).get("name", "Crate")).to_upper()
			_name.add_theme_color_override("font_color", PixelTheme.ACCENT)
			_sub.text = "Crate added to your inventory"
		"gun":
			var inst: Dictionary = reward.get("inst", {})
			_icon.texture = WeaponInstance.icon(inst)
			_name.text = WeaponInstance.display_name(inst).to_upper()
			_name.add_theme_color_override("font_color", WeaponInstance.color(inst))
			_sub.text = WeaponInstance.rarity_name(inst) + " — added to your inventory"
		"rank":
			# Employee Rank promotion (Pack G) — not a "free reward" claim, so the icon + that
			# label are hidden entirely (Control layout skips invisible children, so the card just
			# shrinks around the remaining rows instead of leaving a blank gap).
			_free_label.visible = false
			_icon.visible = false
			var rank := int(reward.get("rank", 1))
			_name.text = "RANK %d — %s" % [rank, Ranks.name_for(rank)]
			_name.add_theme_color_override("font_color", PixelTheme.ACCENT)
			var unlocked: Array = reward.get("unlocked", [])
			if unlocked.is_empty():
				_sub.text = "Keep grinding — more modes ahead."
			else:
				var names: Array[String] = []
				for id in unlocked:
					names.append(Ranks.mode_display_name(String(id)))
				_sub.text = "Unlocked: %s" % ", ".join(names)
		"commendation":
			# Commendations wall (Pack H) — reads as an achievement badge, not a "free reward":
			# the FREE REWARD! label is hidden (mirrors the "rank" kind above) but the icon stays
			# (the tier crate art) since a crate + rank XP genuinely was just handed over.
			_free_label.visible = false
			var comm_row := Commendations.by_id(String(reward.get("id", "")))
			var comm_tier: Dictionary = comm_row.get("tier", {})
			var crate_id := String(comm_tier.get("crate_id", ""))
			_icon.texture = Crates.icon(crate_id)
			_name.text = String(comm_row.get("name", "COMMENDATION"))
			_name.add_theme_color_override("font_color", PixelTheme.ACCENT)
			var crate_name := String(Crates.get_crate(crate_id).get("name", "Crate")).to_upper()
			_sub.text = "+%d RANK XP · %s awarded" % [int(comm_tier.get("rank_xp", 0)), crate_name]
	visible = true

func _on_claim() -> void:
	visible = false
	claimed.emit()

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

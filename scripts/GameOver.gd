extends CanvasLayer
## Death overlay. Listens for the player's `died` signal and shows a "SHIFT'S OVER" pay-stub
## recap (endless) — itemized coin lines matching CoinReward's math, a "Clocked out" night-
## shift time, a NEW BEST celebration, and the equipped weapon's run XP — plus Back-to-Menu
## and Store buttons. Boss Rush keeps its "YOU DIED" header (no clock/dawn there) but reuses
## the same itemized layout, which reads naturally for it too (bosses/kills are its whole game).
## PROCESS_MODE_ALWAYS so its buttons work while the tree is paused (death pauses the game).

var _root: Control
var _title: Label               # header label; text/color flip for a WIN (Pack A: Dawn Extraction)
var _stub_vbox: VBoxContainer   # itemized pay-stub rows, (re)built once per finish
var _player: Player

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	add_to_group("game_over")   # Extraction.gd calls trigger_win() on this via the group
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		_player.died.connect(_on_player_died)
	_build_ui()
	_root.visible = false

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
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_title = Label.new()
	_title.text = "YOU DIED" if RunConfig.mode == "boss_rush" else "SHIFT'S OVER"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(_title, 40)
	_title.add_theme_color_override("font_color", PixelTheme.DANGER)
	vbox.add_child(_title)

	vbox.add_child(_spacer(4))

	_stub_vbox = VBoxContainer.new()
	_stub_vbox.add_theme_constant_override("separation", 6)
	_stub_vbox.custom_minimum_size = Vector2(620, 0)
	vbox.add_child(_stub_vbox)

	vbox.add_child(_spacer(6))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	var back_btn := Button.new()
	back_btn.text = "BACK TO MENU"
	PixelTheme.style_button(back_btn, Vector2(300, 72), 18)
	back_btn.pressed.connect(_on_back_pressed)
	btn_row.add_child(back_btn)
	var store_btn := Button.new()
	store_btn.text = "STORE"
	PixelTheme.style_button(store_btn, Vector2(300, 72), 18)
	store_btn.pressed.connect(_on_store_pressed)
	btn_row.add_child(store_btn)
	vbox.add_child(btn_row)

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

## A left label (expands) + a right, right-aligned value — the pay-stub's itemized row shape
## (mirrors WeaponDetailPopup's stat-row layout so numbers line up in a column).
func _row(parent: VBoxContainer, left: String, right: String, color: Color = PixelTheme.TEXT, size: int = 20) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_l := Label.new()
	name_l.text = left
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelTheme.style_label(name_l, size, color)
	line.add_child(name_l)
	var val_l := Label.new()
	val_l.text = right
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelTheme.style_label(val_l, size, color)
	line.add_child(val_l)
	parent.add_child(line)

func _centered_line(parent: VBoxContainer, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(l, size, color)
	parent.add_child(l)

func _on_player_died() -> void:
	_finish_run(false)

## Public entry point for a WIN (Dawn Extraction's chopper LZ, Pack A) — called by Extraction.gd
## via the "game_over" group, NOT via a Player signal, so nothing on Player needs to change.
## Pauses the tree itself (mirrors Player._die()'s get_tree().paused = true) since a win is a
## run end exactly like death is; routes through the SAME _finish_run the death path uses, so the
## RunStats.paid_out guard makes a double-pay (or a death arriving the same frame) impossible.
func trigger_win() -> void:
	get_tree().paused = true
	_finish_run(true)

func _finish_run(is_win: bool) -> void:
	if RunStats.paid_out:
		return
	RunStats.paid_out = true
	SoundManager.play("dawn_sting" if is_win else "death_sting")
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	var kills := RunStats.kills
	var bonus := RunStats.bonus_coins
	var mult := RunStats.coin_mult
	var earned := CoinReward.final_payout(wave, bosses, kills, bonus, mult)
	if is_win:
		earned = int(round(float(earned) * GameConfig.EXTRACT_PAY_MULT))

	# NEW BEST must compare against what stood BEFORE this run — read it before record_run
	# mutates best_wave/best_bosses (record_run takes maxi(existing, this run's value)).
	var prev_best_wave := SaveManager.best_wave()
	var prev_best_bosses := SaveManager.best_bosses()
	var is_new_best: bool = (bosses > prev_best_bosses) if RunConfig.mode == "boss_rush" else (wave > prev_best_wave)

	SaveManager.add_coins(earned)
	SaveManager.record_run(wave, bosses)
	SaveManager.add_game_played()   # counts toward the every-10-games free reward (granted at the menu)
	if is_win:
		SaveManager.add_shift_survived()
	SaveManager.save_game()

	# Weapon-loot: award XP to the equipped weapon so its talents unlock over time, then read
	# the refreshed instance back for the pay-stub's XP line (post-gain level/talent state).
	var equipped_uid := Inventory.equipped_uid()
	var xp_amount := kills + wave * 10 + bosses * 50
	Inventory.add_run_xp(xp_amount)
	var inst := Inventory.get_item(equipped_uid)

	if is_win:
		_title.text = "SHIFT SURVIVED\nCLOCKED OUT ALIVE"
		_title.add_theme_color_override("font_color", PixelTheme.ACCENT)

	_populate_stub(wave, bosses, kills, bonus, mult, earned, is_new_best, inst, xp_amount, is_win)
	_root.visible = true
	if is_new_best or is_win:
		_celebrate()

## Fills the pay-stub: itemized coin lines (same terms CoinReward.final_payout computes — no
## magic numbers), a clocked-out timestamp (endless only), NEW BEST, and the weapon XP line.
func _populate_stub(wave: int, bosses: int, kills: int, bonus: int, mult: float, earned: int,
		is_new_best: bool, inst: Dictionary, xp_amount: int, is_win: bool = false) -> void:
	for c in _stub_vbox.get_children():
		c.queue_free()

	var base_pay := GameConfig.COIN_BASE
	var wave_pay := GameConfig.COIN_PER_WAVE * wave
	var boss_pay := GameConfig.COIN_PER_BOSS * bosses
	var kill_pay := GameConfig.COIN_PER_KILL * kills

	_row(_stub_vbox, "BASE PAY", "+%d" % base_pay)
	_row(_stub_vbox, "WAVES %d×%d" % [wave, GameConfig.COIN_PER_WAVE], "+%d" % wave_pay)
	_row(_stub_vbox, "BOSSES %d×%d" % [bosses, GameConfig.COIN_PER_BOSS], "+%d" % boss_pay)
	_row(_stub_vbox, "KILLS %d×%d" % [kills, GameConfig.COIN_PER_KILL], "+%d" % kill_pay)
	_row(_stub_vbox, "TIPS", "+%d" % bonus)
	# The subtotal above (base+waves+bosses+kills+tips) is exactly CoinReward.payout(...)+bonus;
	# CoinReward.final_payout multiplies that subtotal by RunStats.coin_mult and rounds once —
	# showing the same factor here keeps the stub's math identical to what actually got paid.
	if not is_equal_approx(mult, 1.0):
		_row(_stub_vbox, "SHIFT BONUS", "x%.2f" % mult, PixelTheme.SELECT)
	if is_win:
		_row(_stub_vbox, "EXTRACTION BONUS", "x%.2f" % GameConfig.EXTRACT_PAY_MULT, PixelTheme.SELECT)

	var rule := Label.new()
	rule.text = "══════════════"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelTheme.style_label(rule, 16, PixelTheme.ACCENT_DIM)
	_stub_vbox.add_child(rule)

	_row(_stub_vbox, "TOTAL", "+%d" % earned, PixelTheme.ACCENT, 26)
	_row(_stub_vbox, "WALLET", "%d" % SaveManager.coins(), PixelTheme.TEXT_DIM, 16)

	if RunConfig.mode != "boss_rush":
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "Clocked out: %s" % ShiftClock.clock_string(DifficultyManager.run_time), PixelTheme.TEXT_DIM, 18)

	if is_new_best:
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "★ NEW BEST ★", PixelTheme.ACCENT, 28)

	if not inst.is_empty():
		_stub_vbox.add_child(_spacer(4))
		var xp_line := "%s +%d XP" % [WeaponInstance.display_name(inst), xp_amount]
		var next_lvl := WeaponInstance.next_locked_talent_level(inst)
		if next_lvl > 0:
			xp_line += " — next talent at LV%d" % next_lvl
		_centered_line(_stub_vbox, xp_line, PixelTheme.TEXT_DIM, 16)

## Confetti pop over the pay-stub card for a NEW BEST (mirrors MainMenu's crate-win
## _celebrate — Confetti is a self-contained Node2D, no scene dependency, so it works fine
## parented under this different scene's overlay).
func _celebrate() -> void:
	var c := Confetti.new()
	_root.add_child(c)
	var vp := get_viewport_rect().size
	c.position = Vector2(vp.x * 0.5, vp.y * 0.4)
	c.burst(130, [PixelTheme.ACCENT])

func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Same navigation as Back, but flags the menu to open directly into the store.
func _on_store_pressed() -> void:
	RunConfig.open_store_on_menu = true
	_on_back_pressed()

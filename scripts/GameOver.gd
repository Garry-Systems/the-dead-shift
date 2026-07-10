extends CanvasLayer
## Death overlay. Listens for the player's `died` signal and shows a "SHIFT'S OVER" pay-stub
## recap (endless) — itemized coin lines matching CoinReward's math, a "Clocked out" night-
## shift time, a NEW BEST celebration, and the equipped weapon's run XP — plus Back-to-Menu
## and Store buttons. Boss Rush keeps its "YOU DIED" header (no clock/dawn there) but reuses
## the same itemized layout, which reads naturally for it too (bosses/kills are its whole game).
## PROCESS_MODE_ALWAYS so its buttons work while the tree is paused (death pauses the game).

var _root: Control
var _title: Label               # header label; text/color flip for a WIN (Pack A: Dawn Extraction)
var _daily_header: Label        # "DAILY SHIFT — <date>" subheader, shown only when RunConfig.daily (Pack C)
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
	_title.text = _title_text()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(_title, 40)
	_title.add_theme_color_override("font_color", PixelTheme.DANGER)
	vbox.add_child(_title)

	# Pack C: Daily Shift subheader — built hidden, shown/labeled in _finish_run only when
	# RunConfig.daily is true; a normal Endless/Boss Rush run never touches it.
	_daily_header = Label.new()
	_daily_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(_daily_header, 18, PixelTheme.SELECT)
	_daily_header.visible = false
	vbox.add_child(_daily_header)

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

## Header text for the current mode/outcome (Pack G): boss_rush keeps "YOU DIED"; HORDE NIGHT gets
## its own "HORDE CLEANED UP" flavor (it never wins via extraction, so this is always its death
## text); everything else is "SHIFT'S OVER", overridden to the win text when `is_win`. HARDCORE
## appends its own suffix regardless of which of the above was chosen — used both at _ready()
## (is_win always false there, the outcome isn't known yet) and again in _finish_run() once it is.
func _title_text(is_win: bool = false) -> String:
	var t := "SHIFT'S OVER"
	if RunConfig.mode == "boss_rush":
		t = "YOU DIED"
	elif RunConfig.mode == "horde":
		t = "HORDE CLEANED UP"
	if is_win:
		t = "SHIFT SURVIVED\nCLOCKED OUT ALIVE"
	if RunConfig.hardcore:
		t += "\n— HARDCORE —"
	return t

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
	var basements := RunStats.basements_cleared
	# SIGNING BONUS (final-review fix): DifficultyManager.run_time is the run's elapsed-seconds
	# clock (same source ShiftClock's "Clocked out" line and the OVERTIME/HARDCORE best-clockout
	# records below already read) — vested() below feeds the pay-stub's dedicated row.
	var run_time := DifficultyManager.run_time
	var vested := CoinReward.vested_signing(RunStats.signing_bonus, run_time)
	var earned := CoinReward.final_payout(wave, bosses, kills, bonus, mult, RunStats.signing_bonus, run_time)
	# Relics Overhaul (company_card): the itemized stub must show the clawback final_payout just
	# applied, or the visible rows would sum past TOTAL. Same inputs, same CoinReward seams
	# (pre_cut_total/clawback are exactly what final_payout composes internally), so this number
	# can never drift from what was actually cut.
	var clawback := 0
	if RelicEffects.company_card:
		clawback = CoinReward.clawback(CoinReward.pre_cut_total(wave, bosses, kills, bonus, mult, RunStats.signing_bonus, run_time))
	if is_win:
		earned = int(round(float(earned) * GameConfig.EXTRACT_PAY_MULT))

	# NEW BEST must compare against what stood BEFORE this run — read each best before the record
	# writes below mutate it (they take maxi(existing, this run's value)). Each mode compares
	# against ITS OWN record track (fix round: horde previously compared against the shared
	# endless best_wave, so a real horde record wouldn't banner and a horde run merely beating the
	# endless best would false-flag). OVERTIME never participates (its preset headstart would
	# inflate the comparison unfairly) — see the record-gating block below for the same reasoning
	# applied to the actual record writes.
	var is_new_best := false
	if not RunConfig.overtime:
		if RunConfig.mode == "boss_rush":
			is_new_best = bosses > SaveManager.best_bosses()
		elif RunConfig.mode == "horde":
			is_new_best = wave > SaveManager.horde_best_wave()
		else:
			is_new_best = wave > SaveManager.best_wave()

	# Rank XP (Pack G): the ACTUAL earned payout, added from the rank held BEFORE this flush so a
	# threshold crossing can be detected for the pay-stub's PROMOTED line + confetti below.
	var rank_before := Ranks.rank_for(SaveManager.rank_xp())
	SaveManager.add_coins(earned)
	SaveManager.add_rank_xp(earned)
	var rank_after := Ranks.rank_for(SaveManager.rank_xp())
	var promoted := rank_after > rank_before

	# Records (Pack G): HORDE plays a different game entirely (no boss ever spawns) so it never
	# touches the shared best_wave/best_bosses — it gets its own horde_best_wave instead. OVERTIME's
	# preset headstart would inflate the same comparison unfairly, so it's excluded too, with its
	# own dedicated best-clockout track. HARDCORE keeps mode == "endless", so the shared records
	# apply to it normally, PLUS its own best-clockout track.
	if RunConfig.mode != "horde" and not RunConfig.overtime:
		SaveManager.record_run(wave, bosses)
		# Transfer Stores (Task 5): per-location best wave, SAME guard family as best_wave above
		# (never horde, never overtime — its preset headstart would inflate the comparison
		# unfairly, exactly like the shared best_wave/best_bosses records it sits beside), plus
		# its own forecourt exclusion (forecourt already has best_wave; a redundant per-location
		# record for it would just be noise). Boss Rush/Daily Shift never reach this branch with a
		# non-forecourt location since both force RunConfig.location back to "forecourt" at their
		# own launch sites (MainMenu._start_run / _on_daily_shift).
		if RunConfig.location != "forecourt":
			SaveManager.set_location_best(RunConfig.location, wave)
	if RunConfig.mode == "horde":
		SaveManager.record_horde_best_wave(wave)
	if RunConfig.overtime:
		SaveManager.record_overtime_best_clockout(DifficultyManager.run_time)
	if RunConfig.hardcore:
		SaveManager.record_hardcore_best_clockout(DifficultyManager.run_time)

	SaveManager.add_game_played()   # counts toward the every-10-games free reward (granted at the menu)
	if is_win:
		SaveManager.add_shift_survived()
	# Lifetime records (Pack D): flushed exactly once per run — this whole block only runs past
	# the RunStats.paid_out guard above, the same guard the coin payout relies on. `earned` is the
	# actual amount just granted (already haircut on the quit path in PauseMenu's twin of this).
	# OVERTIME suppresses only the best_clockout_seconds bump (its own dedicated record above
	# covers that instead) — kills/bosses/elites/coins_earned/gun_kills still flow through, per spec.
	SaveManager.add_lifetime_run(kills, bosses, RunStats.elites_killed, earned, DifficultyManager.run_time,
		String(Inventory.equipped_instance().get("base", "")), not RunConfig.overtime)
	# Challenge board (Pack C): same guarded block, same "flush exactly once" guarantee. Run-scoped
	# counters only — crates_opened/fusions_done are bumped immediately at their own menu-action
	# chokepoints (Inventory.commit_crate / Inventory.fuse, not here). clock_seconds is zeroed on
	# an OVERTIME run (Pack G fix round): its 240s preset already sits past the "reach 2:00 AM"
	# challenge target, which would auto-complete it on an instant quit — clock challenges only
	# count from real shifts, mirroring the best-clockout record freeze.
	SaveManager.flush_challenge_counters({
		"kills": kills, "elite_kills": RunStats.elites_killed, "boss_kills": bosses,
		"clock_seconds": (0.0 if RunConfig.overtime else DifficultyManager.run_time),
		"blood_moons_survived": RunStats.blood_moons_survived,
		"power_surge_kills": RunStats.power_surge_kills, "extraction_wins": (1 if is_win else 0),
		"fire_kills": RunStats.fire_kills, "electric_kills": RunStats.electric_kills,
		"poison_kills": RunStats.poison_kills,
	})
	if RunConfig.daily:
		SaveManager.record_daily_score(earned)
	# Best single-run payout (Pack H: PAYDAY commendation) — max() at the SAME guarded flush,
	# mirrors record_daily_score's shape but ungated (every run's actual payout counts, not only
	# Daily Shift runs).
	SaveManager.record_best_run_payout(earned)
	# Commendations (Pack H): checked + granted (rank XP + crate) here, inside the SAME
	# RunStats.paid_out guard as every other lifetime counter above, and BEFORE the save_game()
	# below so a granted badge is part of the same atomic flush write — see
	# CommendationProgress.check_and_grant's doc comment for the exactly-once contract.
	SaveManager.check_and_grant_commendations()
	SaveManager.save_game()

	# Weapon-loot: award XP to the equipped weapon so its talents unlock over time, then read
	# the refreshed instance back for the pay-stub's XP line (post-gain level/talent state).
	# HARDCORE doubles this at the flush (Pack G); the "Punch Card" relic (Relics Overhaul)
	# composes into the SAME multiplier via RunStats.weapon_xp_mult — both round together, once,
	# mirroring CoinReward.final_payout's single int(round(float * mult)) idiom — the one
	# Inventory.add_run_xp chokepoint.
	var equipped_uid := Inventory.equipped_uid()
	var xp_amount := kills + wave * 10 + bosses * 50
	var xp_mult := RunStats.weapon_xp_mult
	if RunConfig.hardcore:
		xp_mult *= GameConfig.HARDCORE_WEAPON_XP_MULT
	xp_amount = int(round(float(xp_amount) * xp_mult))
	Inventory.add_run_xp(xp_amount)
	var inst := Inventory.get_item(equipped_uid)

	_title.text = _title_text(is_win)
	if is_win:
		_title.add_theme_color_override("font_color", PixelTheme.ACCENT)

	_daily_header.visible = RunConfig.daily
	if RunConfig.daily:
		_daily_header.text = "DAILY SHIFT — %s" % SaveManager.today_string()

	_populate_stub(wave, bosses, kills, bonus, mult, vested, earned, is_new_best, inst, xp_amount, is_win, promoted, rank_after, basements, clawback)
	_root.visible = true
	if is_new_best or is_win or promoted:
		_celebrate()

## Fills the pay-stub: itemized coin lines (same terms CoinReward.final_payout computes — no
## magic numbers), a clocked-out timestamp (endless only), NEW BEST, RANK XP + PROMOTED (Pack G),
## and the weapon XP line.
func _populate_stub(wave: int, bosses: int, kills: int, bonus: int, mult: float, vested: int, earned: int,
		is_new_best: bool, inst: Dictionary, xp_amount: int, is_win: bool = false,
		promoted: bool = false, rank_after: int = 0, basements: int = 0, clawback: int = 0) -> void:
	for c in _stub_vbox.get_children():
		c.queue_free()

	var base_pay := GameConfig.COIN_BASE
	var wave_pay := GameConfig.COIN_PER_WAVE * wave
	var boss_pay := GameConfig.COIN_PER_BOSS * bosses
	var kill_pay := GameConfig.COIN_PER_KILL * kills

	_row(_stub_vbox, "BASE PAY", "+%d" % base_pay)
	_row(_stub_vbox, "WAVES %d×%d" % [wave, GameConfig.COIN_PER_WAVE], "+%d" % wave_pay)
	_row(_stub_vbox, "BOSSES %d×%d" % [bosses, GameConfig.COIN_PER_BOSS], "+%d" % boss_pay)
	# Task 5: BASEMENTS CLEARED — INFORMATIONAL only (no coin rate, no "+" value; the "×%d" form
	# reads as a count, not a payout line) so it can't be mistaken for a term that feeds the
	# subtotal above. Sits next to WAVES/BOSSES since it's the same kind of run-progress fact,
	# not a coin-math one. Hidden entirely on a 0-basement run.
	if basements > 0:
		_row(_stub_vbox, "BASEMENTS CLEARED", "×%d" % basements)
	_row(_stub_vbox, "KILLS %d×%d" % [kills, GameConfig.COIN_PER_KILL], "+%d" % kill_pay)
	_row(_stub_vbox, "TIPS", "+%d" % bonus)
	# The subtotal above (base+waves+bosses+kills+tips) is exactly CoinReward.payout(...)+bonus;
	# CoinReward.final_payout multiplies that subtotal by RunStats.coin_mult and rounds once —
	# showing the same factor here keeps the stub's math identical to what actually got paid.
	if not is_equal_approx(mult, 1.0):
		_row(_stub_vbox, "SHIFT BONUS", "x%.2f" % mult, PixelTheme.SELECT)
	# SIGNING BONUS (final-review fix): the vested amount is added POST-mult inside
	# CoinReward.final_payout — it does NOT get multiplied by SHIFT BONUS above — so this row sits
	# AFTER that multiplier row, mirroring the actual order of operations (subtotal*mult, then
	# +vested, then, if a win, *EXTRACTION BONUS below) rather than before it, which would imply
	# the bonus itself got the SHIFT BONUS multiplier when it never does.
	if vested > 0:
		_row(_stub_vbox, "SIGNING BONUS", "+%d" % vested, PixelTheme.SELECT)
	# Relics Overhaul (company_card): CORPORATE CLAWBACK — the cut CoinReward.final_payout applied
	# inside the paid total. Sits AFTER the SIGNING BONUS row and BEFORE the EXTRACTION BONUS row,
	# mirroring the actual order of operations (subtotal×mult, +vested, −clawback, then ×extract on
	# a win) — the same placement reasoning the SIGNING BONUS comment above already documents. The
	# amount comes from the SAME CoinReward.clawback/pre_cut_total seams final_payout composes, so
	# the itemized rows always sum exactly to TOTAL, rounding included.
	if clawback > 0:
		_row(_stub_vbox, "CORPORATE CLAWBACK", "-%d" % clawback, PixelTheme.DANGER)
	if is_win:
		_row(_stub_vbox, "EXTRACTION BONUS", "x%.2f" % GameConfig.EXTRACT_PAY_MULT, PixelTheme.SELECT)

	var rule := Label.new()
	rule.text = "══════════════"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelTheme.style_label(rule, 16, PixelTheme.ACCENT_DIM)
	_stub_vbox.add_child(rule)

	_row(_stub_vbox, "TOTAL", "+%d" % earned, PixelTheme.ACCENT, 26)
	_row(_stub_vbox, "WALLET", "%d" % SaveManager.coins(), PixelTheme.TEXT_DIM, 16)
	# Pack G: rank XP is always the same amount as the coin payout above (see GameOver._finish_run
	# / SaveManager.add_rank_xp — both flush blocks feed the run's ACTUAL earned coins).
	_row(_stub_vbox, "RANK XP", "+%d" % earned, PixelTheme.SELECT, 16)

	if RunConfig.mode != "boss_rush":
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "Clocked out: %s" % ShiftClock.clock_string(DifficultyManager.run_time), PixelTheme.TEXT_DIM, 18)

	if is_new_best:
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "★ NEW BEST ★", PixelTheme.ACCENT, 28)

	if promoted:
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "★ PROMOTED: %s ★" % Ranks.name_for(rank_after), PixelTheme.ACCENT, 28)
		var promo_blurb := Flavor.rank_blurb(rank_after)
		if promo_blurb != "":
			_centered_line(_stub_vbox, promo_blurb, PixelTheme.ACCENT.darkened(0.45), 16)

	if not inst.is_empty():
		_stub_vbox.add_child(_spacer(4))
		var xp_line := "%s +%d XP" % [WeaponInstance.display_name(inst), xp_amount]
		var next_lvl := WeaponInstance.next_locked_talent_level(inst)
		if next_lvl > 0:
			xp_line += " — next talent at LV%d" % next_lvl
		_centered_line(_stub_vbox, xp_line, PixelTheme.TEXT_DIM, 16)

	# Death quip (Pack 0 lore flavor) — only on an actual death, never an extraction win.
	if not is_win:
		_stub_vbox.add_child(_spacer(4))
		_centered_line(_stub_vbox, "\"%s\"" % Flavor.death_quip(), PixelTheme.ACCENT.darkened(0.45), 16)

## Confetti pop over the pay-stub card for a NEW BEST (mirrors MainMenu's crate-win
## _celebrate — Confetti is a self-contained Node2D, no scene dependency, so it works fine
## parented under this different scene's overlay). NOTE: get_viewport_rect() is a CanvasItem
## method and this node is a CanvasLayer — call it on _root (a full-rect Control), or the
## whole script fails to compile and `died` never connects (the v0.1.49–56 death freeze).
func _celebrate() -> void:
	var c := Confetti.new()
	_root.add_child(c)
	var vp := _root.get_viewport_rect().size
	c.position = Vector2(vp.x * 0.5, vp.y * 0.4)
	c.burst(130, [PixelTheme.ACCENT])

func _on_back_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Same navigation as Back, but flags the menu to open directly into the store.
func _on_store_pressed() -> void:
	RunConfig.open_store_on_menu = true
	_on_back_pressed()

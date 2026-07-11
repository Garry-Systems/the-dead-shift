extends CanvasLayer
## THE ICE CREAM TRUCK's shop overlay (Night Shift Stories, Task 4) — the game's first mid-run
## coin-spending UI. Built on RelicChoice/LevelUpUI's paused-overlay idiom EXACTLY: PROCESS_MODE_
## ALWAYS, a dim scrim + centered PixelTheme card, shown/hidden via _root.visible + get_tree().
## paused. Persistent Main.tscn sibling (built once in _ready(), like every other paused overlay in
## this codebase), opened via open(truck) — a dynamic .call() from IceCreamTruck's own ring-trigger
## (this file has no class_name dependency on IceCreamTruck, matching how RelicBar/RelicChoice are
## always reached via group + .call(), never a typed reference — and IceCreamTruck.gd has no
## dependency on this file's type either).
##
## Unlike LevelUpUI/RelicChoice (which close automatically on a single pick), this overlay STAYS
## OPEN across multiple purchases — up to GameConfig.TRUCK_PURCHASE_CAP (3) per truck visit, any
## mix of the 3 items — so the player can buy more than one thing in the same stop; only the LEAVE
## button or the purchase cap (via IceCreamTruck.purchase_cap_hit(), checked after every buy)
## closes it.
##
## Three items, each independently gated + priced (GameConfig.TRUCK_*_COST):
##   HEAL SCOOP        — 30% max HP via player.heal(); disabled ("NOT IN HARDCORE") under
##                        RunConfig.hardcore (heal()'s own no-op gate would make it a no-op charge
##                        anyway — this disables the button outright, per spec, belt and suspenders).
##   SECOND OPINION TO GO — +1 LevelUpUI reroll charge via the "level_up_ui" group + add_reroll_charge().
##   MYSTERY FLAVOR     — one random relic via Relics._roll_a() (card-A's own 60/40 standard/
##                        prototype mix, NEVER cursed — the exact helper RelicChoice's card A
##                        already reuses for its own never-cursed draw), granted via
##                        RelicBar.take() (the bar's shared take path — the SAME chokepoint
##                        RelicChoice/PauseMenu's SCRAP button route every relic mutation through).
##                        Full bar -> "NO ROOM" disabled state (see the header note below on why
##                        RelicChoice's swap flow was NOT reused here).
##
## MYSTERY FLAVOR + the full-bar case (task brief's own REPORTed judgment call): RelicChoice's
## scrap/swap phase is tightly coupled to ITS OWN paused-overlay state machine (_phase/
## _swap_take_id/_open_scrap/_advance) with no external "take this ALREADY-rolled specific id, then
## swap if full" entry point — reusing it here would mean either (a) closing/reopening two stacked
## paused overlays with a hand-rolled hand-off signal neither file currently has, or (b) forking a
## near-duplicate scrap UI into this file. Both are more surface area/risk than this feature is
## worth. Per the brief's own sanctioned fallback ("if reuse is tangled, a simple disabled state is
## sanctioned"), a full bar simply disables the button with "NO ROOM" — no charge, no roll, no
## partial state. REPORTED, per the brief's instruction.

var _root: Control
var _heal_btn: Button
var _reroll_btn: Button
var _relic_btn: Button
var _truck: IceCreamTruck

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11   # RelicChoice's own layer — the two can never both be open (RelicChoice pauses the
	             # tree too, and open() below refuses whenever the tree is already paused)
	add_to_group("truck_shop")
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

	var title := Label.new()
	title.text = "ICE CREAM TRUCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 30)
	vbox.add_child(title)

	_heal_btn = _shop_button()
	_heal_btn.pressed.connect(_on_heal_pressed)
	vbox.add_child(_heal_btn)

	_reroll_btn = _shop_button()
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	vbox.add_child(_reroll_btn)

	_relic_btn = _shop_button()
	_relic_btn.pressed.connect(_on_relic_pressed)
	vbox.add_child(_relic_btn)

	var leave_btn := Button.new()
	leave_btn.text = "LEAVE"
	PixelTheme.style_button(leave_btn, Vector2(620, 80), 22)
	leave_btn.pressed.connect(_on_leave_pressed)
	vbox.add_child(leave_btn)

func _shop_button() -> Button:
	var b := Button.new()
	b.clip_contents = true
	PixelTheme.style_button(b, Vector2(620, 110), 20)
	return b

## Called by IceCreamTruck on the ring's false->true edge. Refuses (no-op) if another paused
## overlay already owns the pause — the SAME "get_tree().paused: return" guard PauseMenu's own
## pause button uses (PauseMenu.gd:187-188) — so a shop can't stack on top of a level-up card or
## RelicChoice offer mid-approach; the player simply has to step into the ring again once whatever
## else is showing clears.
func open(truck: IceCreamTruck) -> void:
	if get_tree().paused:
		return
	_truck = truck
	_refresh()
	_root.visible = true
	get_tree().paused = true

## Refreshes all 3 buttons' labels/disabled state from CURRENT run state — called on open() and
## again after every purchase, so a HEAL SCOOP buy that leaves the player unable to afford another
## relic immediately reflects that, same as RelicBar's own _refresh() re-paint idiom.
func _refresh() -> void:
	if RunConfig.hardcore:
		_heal_btn.text = "NOT IN HARDCORE"
		_heal_btn.disabled = true
	else:
		_heal_btn.text = "HEAL SCOOP — 30%% MAX HP (%d coins)" % GameConfig.TRUCK_HEAL_COST
		_heal_btn.disabled = false
	_reroll_btn.text = "SECOND OPINION TO GO — +1 REROLL (%d coins)" % GameConfig.TRUCK_REROLL_COST
	_reroll_btn.disabled = false
	var bar := get_tree().get_first_node_in_group("relic_bar")
	var bar_full := bar != null and bool(bar.call("is_full"))
	if bar_full:
		_relic_btn.text = "NO ROOM"
	else:
		_relic_btn.text = "MYSTERY FLAVOR — random relic (%d coins)" % GameConfig.TRUCK_RELIC_COST
	_relic_btn.disabled = bar_full

func _on_heal_pressed() -> void:
	if RunConfig.hardcore:
		return   # belt and suspenders — the button is already disabled in this state
	if not RunStats.spend_run_coins(GameConfig.TRUCK_HEAL_COST):
		SoundManager.play("ui_tap")
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.heal(player.max_hp() * GameConfig.TRUCK_HEAL_FRAC)
	SoundManager.play("purchase")
	_on_purchased()

func _on_reroll_pressed() -> void:
	if not RunStats.spend_run_coins(GameConfig.TRUCK_REROLL_COST):
		SoundManager.play("ui_tap")
		return
	var lvl := get_tree().get_first_node_in_group("level_up_ui")
	if lvl != null:
		lvl.call("add_reroll_charge")
	SoundManager.play("purchase")
	_on_purchased()

## Roll BEFORE charging (dry-pool guard, RelicChoice's own dry-pickup precedent): Relics._roll_a is
## a pure unseeded draw with no side effect, so trying it first and only spending coins on a real
## hit means a (practically unreachable, since is_full() already gates this button — see the header
## note) exhausted pool never silently eats a purchase. Grant routes through RelicBar.take() — the
## bar's own take path, per the brief.
func _on_relic_pressed() -> void:
	var bar := get_tree().get_first_node_in_group("relic_bar")
	if bar == null or bool(bar.call("is_full")):
		SoundManager.play("ui_tap")
		return
	var held: Array = bar.call("held_ids")
	var id := Relics._roll_a(held, RunConfig.hardcore, RunConfig.mode)
	if id == "":
		SoundManager.play("ui_tap")
		return
	if not RunStats.spend_run_coins(GameConfig.TRUCK_RELIC_COST):
		SoundManager.play("ui_tap")
		return
	bar.call("take", id)
	SoundManager.play("purchase")
	_on_purchased()

## Shared post-purchase tail: refresh the 3 buttons' state, tell the truck (purchase-cap tracking +
## possible early departure), and close immediately if that purchase was the cap-hitting 3rd one.
func _on_purchased() -> void:
	_refresh()
	if _truck == null or not is_instance_valid(_truck):
		return
	_truck.register_purchase()
	if _truck.purchase_cap_hit():
		_close()

func _on_leave_pressed() -> void:
	SoundManager.play("ui_tap")
	_close()

func _close() -> void:
	_root.visible = false
	get_tree().paused = false
	_truck = null

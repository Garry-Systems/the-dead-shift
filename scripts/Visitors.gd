class_name Visitors
extends Node2D
## VISITORS (Night Shift Stories, v0.1.68): physical arrivals — a new event class, distinct from
## NightEvents' ambient modifiers. Main.tscn sibling, wired the same way NightEvents/Basement are
## (a plain Node2D with this script attached, parent "."). Rolls at each wave edge
## (DifficultyManager.wave crossing — the SAME _prev_wave + frame-1-sentinel idiom NightEvents.gd:
## 20-27/38-41 and Basement.gd:34/62-69 both use, and both those files' comments explain why: a
## child's _ready() runs before Main applies its wave preset, so snapshotting the wave at _ready()
## would see a stale wave=1 and could roll a spurious visitor off it — the first _process() frame
## only ever SYNCS to the real starting wave, never rolls). GATE-FIRST (VisitorsLogic.can_roll)
## THEN a chance roll (RunConfig.rand_float() < VISITOR_CHANCE — Daily Shift stays deterministic).
## Which visitor = a seeded uniform pick among the not-yet-seen-this-run kinds
## (VisitorsLogic.pick, backed by RunConfig.rand_int()) — no repeats within a run.
##
## THE ICE CREAM TRUCK is the third visitor kind (Task 4 implements it in full); this task wires
## it into the pick pool/rotation/no-repeat bookkeeping so that shape is already correct, but
## _start_truck() itself is a push_warning STUB — the one sanctioned stub in this task, per the
## brief. Picking it still counts against VISITOR_MAX_PER_RUN and the no-repeat set (so an
## endless run that happens to roll the truck this task doesn't get a "free" extra
## cryptid/drive-by later — Task 4 replaces this one function body and nothing else changes).

const VISITOR_CRYPTID := "cryptid"
const VISITOR_DRIVEBY := "driveby"
const VISITOR_TRUCK := "truck"
const _ALL_VISITORS := [VISITOR_CRYPTID, VISITOR_DRIVEBY, VISITOR_TRUCK]

## "" = no visitor active. Read-only from the outside; only _start_visitor/_process mutate it.
var active_kind := ""
var count_this_run := 0

var _seen: Array = []
var _cooldown := 0.0
var _prev_wave := -1
var _prev_in_basement := false   # descent EDGE detector (false->true) for the visitor refund below
var _active_node: Node2D
var _player: Node2D

func _ready() -> void:
	add_to_group("visitors")
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)
	# Poll idiom (mirrors Basement._door / BasementDoor lifetime tracking): the active visitor
	# owns its own despawn/kill/timeout lifecycle and frees itself; this just notices the
	# instance went invalid and clears the controller's own state so the NEXT wave-edge is
	# gate-eligible again (subject to the cooldown started in _start_visitor below).
	if _active_node != null and not is_instance_valid(_active_node):
		_active_node = null
		active_kind = ""
	# Basement-descent EDGE (in_basement false -> true): the visitor departs immediately and the
	# slot is refunded — the truck doesn't wait for people in basements. A descent's gauntlet
	# (BASEMENT_DURATION 60s + pickup window ≈ 68s+) exceeds every visitor's own window
	# (CRYPTID_WINDOW 20s / DRIVEBY 6s / TRUCK_STAY 25s), so a visitor left running would always
	# expire unseen at the fixed +24k arena offset — burning one of the VISITOR_MAX_PER_RUN slots
	# with zero interaction chance is pure feel-bad. Refund instead (adjudicated, review item 2).
	var in_b := _in_basement()
	if in_b and not _prev_in_basement and active_kind != "":
		_refund_active_visitor()
	_prev_in_basement = in_b
	var wave := DifficultyManager.wave
	if _prev_wave == -1:
		_prev_wave = wave
		return
	if wave == _prev_wave:
		return
	_prev_wave = wave
	_on_wave_edge()

## Gate check at a wave edge; only rolls the chance if the gate allows it. Kept separate from
## _roll_visitor so the gate (deterministic, state-driven) and the roll (chance-driven) are each
## independently probe-able — mirrors Basement._on_wave_edge/_roll_door's exact split.
func _on_wave_edge() -> void:
	# Dawn lockout (mirrors Basement._on_wave_edge's own pre-roll lockout, Basement.gd:79-84,
	# rationale verbatim): a visitor must never roll close enough to dawn to straddle the
	# extraction sequence (surge + chopper ≈ up to 110s). Gated to endless only by construction —
	# Horde and Boss Rush never run Extraction (Extraction.gd:30), and horde has no dawn.
	var near_dawn := RunConfig.mode == "endless" and absf(DifficultyManager.run_time - ShiftClock.dawn_run_time()) < GameConfig.VISITOR_DAWN_LOCKOUT
	if not VisitorsLogic.can_roll(DifficultyManager.wave, RunConfig.mode, active_kind != "", _cooldown, count_this_run, _in_basement(), near_dawn):
		return
	_roll_visitor(RunConfig.rand_float())

## Internal — takes the already-rolled float (mirrors Basement._roll_door) so this is probe-able
## with a stubbed rand instead of depending on live RNG. Does NOT re-check the gate; callers
## (_on_wave_edge) are responsible for gating before ever reaching here.
func _roll_visitor(rand01: float) -> void:
	if not VisitorsLogic.roll(rand01):
		return
	_start_visitor(VisitorsLogic.pick(_ALL_VISITORS, _seen, RunConfig.rand_int()))

## Read via the "basement" group (Basement.gd:47's add_to_group), same dynamic-field idiom
## Basement._check_extraction_door_free uses to read Extraction's own `_phase` (Basement.gd:104:
## `int(extraction.get("_phase"))`) — a plain get_first_node_in_group() return has no static type
## to read `in_basement` off directly, and this file has no dependency on the Basement class.
func _in_basement() -> bool:
	var b := get_tree().get_first_node_in_group("basement")
	return b != null and bool(b.get("in_basement"))

## Dispatch + bookkeeping. The count/seen/cooldown consumption happens AFTER a successful
## dispatch (Basement._spawn_door's own "state only mutates once the spawn actually happened"
## ordering, review item 4): each _start_* dispatcher returns whether the visitor actually
## arrived, and a failed dispatch (e.g. the null-player bail) consumes NOTHING — no slot, no
## no-repeat entry, no cooldown.
func _start_visitor(kind: String) -> void:
	if kind == "":
		return
	var started := false
	match kind:
		VISITOR_CRYPTID:
			started = _start_cryptid()
		VISITOR_DRIVEBY:
			started = _start_driveby()
		VISITOR_TRUCK:
			started = _start_truck()
	if not started:
		return
	count_this_run += 1
	_seen.append(kind)
	_cooldown = GameConfig.VISITOR_COOLDOWN
	# The truck stub "arrives" with no node (see _start_truck) — active_kind only latches when
	# there's a live entity to track (the invalid-poll in _process clears it when that node
	# frees); a node-less arrival explicitly clears it rather than leaving whatever was there.
	active_kind = kind if _active_node != null else ""

func _start_cryptid() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	_banner("SOMETHING IS IN THE LOT", "")
	var c := Cryptid.new()
	get_tree().current_scene.add_child(c)
	c.global_position = _spawn_pos()
	_active_node = c
	return true

func _start_driveby() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var lane := DrivebyLane.new()
	get_tree().current_scene.add_child(lane)
	_active_node = lane
	return true

## THE ICE CREAM TRUCK (Task 4's own visitor). Stubbed here ONLY so the pick pool/rotation is
## already the right shape (3 kinds, no-repeat, per-run cap) before Task 4's real implementation
## lands — the ONE sanctioned stub in this task, per the task brief. Returns true (the slot IS
## consumed, per the brief — Task 4 replaces this body and nothing else changes) but leaves
## _active_node null, so active_kind never latches (nothing was actually spawned).
func _start_truck() -> bool:
	push_warning("Visitors: THE ICE CREAM TRUCK not yet implemented (Task 4) — visitor consumed with no arrival")
	_active_node = null
	return true

## Basement-descent refund (review item 2, adjudicated): the active visitor departs immediately
## and its slot is fully refunded — count decremented, its kind removed from the no-repeat set
## (it may re-roll later this run), active state cleared, entity freed with NO death/despawn
## side effects (a direct queue_free skips Cryptid._die entirely: no banner, no bounty). The
## group membership is dropped immediately (queue_free is deferred — Destructible._die's own
## "dead-frame ghost" precedent, Destructible.gd:251-256) so no same-frame "enemies" iteration
## sees the departing corpse. The cooldown deliberately keeps ticking un-refunded: it's spacing
## between ARRIVALS, and this visitor genuinely arrived.
func _refund_active_visitor() -> void:
	count_this_run = maxi(count_this_run - 1, 0)
	_seen.erase(active_kind)
	active_kind = ""
	if _active_node != null and is_instance_valid(_active_node):
		if _active_node.is_in_group("enemies"):
			_active_node.remove_from_group("enemies")
		_active_node.queue_free()
	_active_node = null

## A ring position VISITOR_SPAWN_DIST from the player, kept out of the forecourt. Mirrors
## Spawner._pick_spawn_pos's reroll-up-to-8 idiom (Spawner.gd:89-100) verbatim, reimplemented
## locally (this file has no dependency on Spawner) since the placement distance differs.
func _spawn_pos() -> Vector2:
	var keep2 := GameConfig.FORECOURT_SPAWN_KEEPOUT * GameConfig.FORECOURT_SPAWN_KEEPOUT
	var pos := _player.global_position + Vector2.RIGHT * GameConfig.VISITOR_SPAWN_DIST
	for i in 8:
		var angle := randf_range(0.0, TAU)
		pos = _player.global_position + Vector2(cos(angle), sin(angle)) * GameConfig.VISITOR_SPAWN_DIST
		if pos.distance_squared_to(Vector2.ZERO) >= keep2:
			return pos
	var dir := pos.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir * GameConfig.FORECOURT_SPAWN_KEEPOUT

## Reuses Hud's Pack 0 banner exactly as the brief specifies (_show_banner(text, sub)) — same
## get_first_node_in_group("hud") + .call() route NightEvents/Extraction/Basement already use for
## their own banners (Hud has no class_name; see Basement.gd:369-372's identical wrapper).
func _banner(text: String, sub: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("_show_banner", text, sub)

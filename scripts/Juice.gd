class_name Juice
extends Node
## Crit-kill hit-stop (Pack D: Stats + juice, v0.1.51): a brief real-time freeze
## (Engine.time_scale -> JUICE_HITSTOP_SCALE) on a critical killing blow. A plain scene node
## instanced only into scenes/Main.tscn — NOT an autoload — so menu scenes pay nothing (mirrors
## CombatText's shape). Call sites reach it via the static `instance`; Juice.on_crit_kill() is a
## silent no-op before the run scene attaches this node or after it tears down.
##
## Re-entry: NOT stacked. Each call re-arms a fresh JUICE_HITSTOP_DURATION and bumps a token;
## only the LAST-armed restore timer's token still matches when it fires, so a flurry of crit-
## kills keeps extending the freeze instead of an earlier, shorter-lived timer prematurely ending
## it. The restore timer is built with SceneTree.create_timer's process_always=true AND
## ignore_time_scale=true, so it counts down in real time regardless of the very time_scale freeze
## it created, AND keeps ticking even if the tree pauses (death overlay) during the stop.
## _exit_tree() is a last-resort safety net: if this node is ever freed mid-stop (scene change),
## time_scale is force-restored so the game can never be left frozen.
##
## base_scale (Company Equipment, v0.1.70; sole-owner again since v0.1.71): originally the shared
## baseline between hit-stop and Jimbo's DEAD EYE bullet-time window (the two-owner design).
## DEAD EYE became AIMBOT in v0.1.71 (no time_scale involvement at all), so Juice is once more
## the only Engine.time_scale writer in the game — base_scale stays as the restore-target seam
## (_on_timer_done restores to it, _ready/_exit_tree reset it) so any future slow-time feature
## can plug back in without re-deriving this contract.

static var instance: Juice = null
static var base_scale := 1.0   # the target Engine.time_scale for "not mid-hitstop" — 1.0 unless
                                # a future slow-time owner writes the seam (none since v0.1.71)

var _stop_token := 0   # bumped on every (re)arm; a stale timer's callback checks this before restoring

func _ready() -> void:
	# No process_mode override needed: this node has no _process/_physics_process, and the restore
	# timer is a tree-level SceneTreeTimer whose pause immunity comes from its OWN process_always
	# flag in create_timer() below — a node-level PROCESS_MODE_ALWAYS here would be dead weight.
	#
	# base_scale reset: GDScript statics are class-level, not node-level, so they survive scene
	# reloads (the RelicEffects lesson — RO Task 2 shipped a run-ending-mid-equip bug from exactly
	# this gap). No writer besides Juice exists since v0.1.71, but the reset stays: it is the
	# guarantee that a fresh run always starts from the un-slowed baseline no matter what any
	# future seam user did to the static.
	base_scale = 1.0
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null
	# Scene teardown is a true reset, not a handoff: force BOTH the live scale and the restore
	# target back to baseline so nothing downstream (a stale hit-stop timer, another Juice
	# instance next run) can inherit a frozen or slowed world.
	Engine.time_scale = 1.0
	base_scale = 1.0

## Call when a single hit is BOTH a crit AND a kill (the alive->dead transition) — see the call
## sites in Bullet.gd / Gun.gd (x3) / Shockwave.gd (`killed and bool(roll.get("crit", false))`)
## plus TalentEngine._resolve_echo (a Double Tap echo kill counts: the echo only exists because
## the original hit crit). No-op if the hard switch (GameConfig.JUICE_HITSTOP_ENABLED) or the
## save-level EFFECTS toggle (SaveManager.shake_on()) is off, or before/after the run scene owns
## a live Juice node.
static func on_crit_kill() -> void:
	if instance == null or not GameConfig.JUICE_HITSTOP_ENABLED or not SaveManager.shake_on():
		return
	instance._start_hitstop()

func _start_hitstop() -> void:
	Engine.time_scale = GameConfig.JUICE_HITSTOP_SCALE
	_stop_token += 1
	var my_token := _stop_token
	var timer := get_tree().create_timer(GameConfig.JUICE_HITSTOP_DURATION, true, false, true)
	timer.timeout.connect(_on_timer_done.bind(my_token))

## Only the timer armed by the MOST RECENT on_crit_kill() call still matches _stop_token when it
## fires — every earlier, superseded timer's callback is a no-op instead of restoring early.
## Restores to base_scale, NOT a hardcoded 1.0: the seam that let a slow-time owner (DEAD EYE,
## v0.1.70) have hit-stop relax back INTO its window instead of cancelling it. No such owner
## exists since v0.1.71 (base_scale is always 1.0), but restoring through the seam keeps that
## contract alive for free.
func _on_timer_done(token: int) -> void:
	if token != _stop_token:
		return
	Engine.time_scale = base_scale

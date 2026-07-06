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

static var instance: Juice = null

var _stop_token := 0   # bumped on every (re)arm; a stale timer's callback checks this before restoring

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null
	Engine.time_scale = 1.0   # safety net: never leave the game frozen if this node goes away mid-stop

## Call when a single hit is BOTH a crit AND a kill (the alive->dead transition) — see the call
## sites in Bullet.gd / Gun.gd / Shockwave.gd: `killed and bool(roll.get("crit", false))`. No-op
## if the hard switch (GameConfig.JUICE_HITSTOP_ENABLED) or the save-level EFFECTS toggle
## (SaveManager.shake_on()) is off, or before/after the run scene owns a live Juice node.
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
func _on_timer_done(token: int) -> void:
	if token != _stop_token:
		return
	Engine.time_scale = 1.0

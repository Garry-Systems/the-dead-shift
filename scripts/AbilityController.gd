class_name AbilityController
extends Node
## Run-scoped ability controller: the cooldown machine + cast dispatch for this run's character
## signature ability (Abilities.gd registry). ONE instance, added as a scenes/Main.tscn sibling
## (the Juice/Visitors idiom) — NOT an autoload, so menu scenes pay nothing. Reached via the
## "ability_controller" group (T7's kill_coin_bonus() static query needs a group lookup, not a
## direct reference — mirrors NightEvents.blood_moon_coins' own idiom).
##
## Every `_cast_*` body below is CALLOUT-ONLY this task — the cooldown machine + HUD button are
## fully playable, but the actual gameplay effect lands in the task named in each doc comment.

var _row: Dictionary = {}     # this run's ability row (Abilities.for_character result); {} = none
var _cd_remaining := 0.0      # seconds left before try_cast() can succeed again

## Debug/probe visibility only (the `_last_shift_toast` idiom): records which `_cast_*` body most
## recently ran, so a probe can confirm the match in try_cast() dispatched to the RIGHT handler
## without needing real gameplay side effects to observe (every body is a staged callout-only
## stub this task).
var _last_cast_id := ""

func _ready() -> void:
	add_to_group("ability_controller")
	_row = Abilities.for_character(RunConfig.character_id)

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining -= delta

## This run's ability row (Abilities.for_character result); `{}` if the character has none.
func ability_row() -> Dictionary:
	return _row

## True once the cooldown has fully drained. Independent of whether this character even HAS an
## ability (`_cd_remaining` never arms without one) — try_cast() is the gate that also checks
## `_row`, so the HUD button (only built for a non-empty row) never needs to care about the split.
func is_ready() -> bool:
	return _cd_remaining <= 0.0

## 0.0 = ready, 1.0 = just cast, linear drain in between. 0.0 for a character with no ability
## (cd is 0 — matches is_ready()'s corresponding true) so a stray poll can never divide by zero.
func cooldown_fraction() -> float:
	var cd := float(_row.get("cd", 0.0))
	if cd <= 0.0:
		return 0.0
	return clampf(_cd_remaining / cd, 0.0, 1.0)

## Attempts to cast this run's ability. False while cooling, or if this character has none at
## all. On success: restarts the cooldown, pops the generic name callout + staged SFX, then
## `match`-dispatches to the specific `_cast_<id>()` handler.
func try_cast() -> bool:
	if _row.is_empty() or not is_ready():
		return false
	_cd_remaining = float(_row.get("cd", 0.0))

	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null and is_instance_valid(player):
		CombatText.callout(player.global_position, "%s!" % String(_row.get("name", "")), PixelTheme.ACCENT)

	# STAGED: T9 lands the real "ability_ready"-family SFX ids (one per ability). "ui_tap" stands
	# in for all 7 until then.
	SoundManager.play("ui_tap")

	match String(_row.get("id", "")):
		"clear_out":
			_cast_clear_out(player)
		"turret":
			_cast_turret()
		"dead_eye":
			_cast_dead_eye()
		"ghost":
			_cast_ghost()
		"jackpot":
			_cast_jackpot()
		"closing_time":
			_cast_closing_time()
		"air_drop":
			_cast_air_drop()
	return true

## CLEAR OUT (Ryan Ace): zero-damage map-wide projectile purge + radial knockback push. Frees
## every "enemy_projectiles" node, then shoves every "enemies" node within ABILITY_CLEAROUT_RADIUS
## of the player (has_method-guarded — a boss without the knockback channel is skipped free, not
## damaged). Hand-rolled instead of Shockwave.blast — blast() always deals damage, and this
## ability never does. Visuals + SFX are the exact purge-FX recipe the old dash-purge used
## (ScreenFlash + Shockwave.flash + "purge"), now triggered from here instead of the dash.
func _cast_clear_out(player: Player) -> void:
	_last_cast_id = "clear_out"
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p):
			p.queue_free()
	SoundManager.play("purge")
	if player == null or not is_instance_valid(player):
		return
	var origin := player.global_position
	var r2 := GameConfig.ABILITY_CLEAROUT_RADIUS * GameConfig.ABILITY_CLEAROUT_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var node := e as Node2D
		if node.global_position.distance_squared_to(origin) > r2:
			continue
		var dir := origin.direction_to(node.global_position)
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT
		if e.has_method("apply_knockback"):
			e.apply_knockback(dir * GameConfig.ABILITY_CLEAROUT_FORCE)
	get_tree().current_scene.add_child(ScreenFlash.new())
	var fx := Shockwave.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = origin
	fx.flash(GameConfig.CHAR_RYAN_PURGE_FX_RADIUS)

## SENTRY TURRET (Jackson Killa): cap-1 auto-turret, talent-free CompanionBullet fire.
## Callout-only this task — effect lands in Task 4.
func _cast_turret() -> void:
	_last_cast_id = "turret"

## DEAD EYE (Jimbo James): bullet time via a Juice.base_scale owner + a move-speed/frenzy comp.
## Callout-only this task — effect lands in Task 5.
func _cast_dead_eye() -> void:
	_last_cast_id = "dead_eye"

## ONE OF THEM (Zombie Bob): the horde loses target lock on him for a window.
## Callout-only this task — effect lands in Task 6.
func _cast_ghost() -> void:
	_last_cast_id = "ghost"

## JACKPOT (Alstar Tuck): four-roll slot machine — NUKE / DEEP FREEZE / PAYDAY / TRIGGER HAPPY.
## Callout-only this task — effect lands in Task 7.
func _cast_jackpot() -> void:
	_last_cast_id = "jackpot"

## CLOSING TIME (The Janitor): one giant slick + a per-kill coin window inside it.
## Callout-only this task — effect lands in Task 8.
func _cast_closing_time() -> void:
	_last_cast_id = "closing_time"

## AIR DROP (The Delivery Girl): telegraphed blast + a healing/gem care package.
## Callout-only this task — effect lands in Task 8.
func _cast_air_drop() -> void:
	_last_cast_id = "air_drop"

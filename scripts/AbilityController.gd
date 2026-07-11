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

## DEAD EYE window state. `_dead_eye_active` is the idempotency guard — three independent nets
## (the end timer, player.died, this controller's own _exit_tree) can all fire for the same
## window, and only the first may act. `_dead_eye_player`/`_dead_eye_move_ratio` are the cast-time
## snapshot needed for an exact revert (`move_speed /= ratio`, not `/= GameConfig...` re-read —
## the multiply/divide pair must use the SAME value so it commutes cleanly with any move-speed
## upgrade card taken mid-window).
var _dead_eye_active := false
var _dead_eye_player: Player = null
var _dead_eye_move_ratio := 1.0

## JACKPOT PAYDAY (this task) / CLOSING TIME zone (Task 8) coin-window state — the seam
## Enemy.gd's kill-coin site queries through the static kill_coin_bonus() below. Instance
## fields, NOT static (the RelicEffects statics lesson: per-run gameplay state lives on the
## per-run controller instance, reached via the SAME group lookup as every other cross-system
## read). Engine-clock seconds — the Hud._last_shift_toast idiom (Time.get_ticks_msec() /
## 1000.0), not RunStats/wall-clock time.
var _coin_window_until := 0.0          # PAYDAY: bonus active while now < this
var _coin_zone_center := Vector2.ZERO  # CLOSING TIME (Task 8 arms this): zone center
var _coin_zone_radius := 0.0           # CLOSING TIME (Task 8 arms this): 0 = never armed
var _coin_zone_until := 0.0            # CLOSING TIME (Task 8 arms this): zone bonus active while now < this

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
	# JACKPOT replaces this generic name callout with its OWN per-roll callout ("JACKPOT: DEEP
	# FREEZE!") — smallest-diff suppress: one extra id check on the existing compound condition,
	# no new field/signature needed (matches the _cast_dead_eye compound-`and` style already in
	# this file).
	if player != null and is_instance_valid(player) and String(_row.get("id", "")) != "jackpot":
		CombatText.callout(player.global_position, "%s!" % String(_row.get("name", "")), PixelTheme.ACCENT)

	# STAGED: T9 lands the real "ability_ready"-family SFX ids (one per ability). "ui_tap" stands
	# in for all 7 until then.
	SoundManager.play("ui_tap")

	match String(_row.get("id", "")):
		"clear_out":
			_cast_clear_out(player)
		"turret":
			_cast_turret(player)
		"dead_eye":
			_cast_dead_eye(player)
		"ghost":
			_cast_ghost(player)
		"jackpot":
			_cast_jackpot(player)
		"closing_time":
			_cast_closing_time(player)
		"air_drop":
			_cast_air_drop(player)
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

## SENTRY TURRET (Jackson Killa): cap-1 auto-turret, talent-free CompanionBullet fire
## (Turret.gd, Task 4). Same null-guard idiom as _cast_clear_out — the whole effect is anchored
## on the player's position, so there's nothing to do at all without a valid one.
func _cast_turret(player: Player) -> void:
	_last_cast_id = "turret"
	if player == null or not is_instance_valid(player):
		return
	Turret.spawn(player.global_position, get_tree())

## DEAD EYE (Jimbo James): 3-second bullet time. Owns Engine.time_scale jointly with Juice's
## crit hit-stop via the shared `Juice.base_scale` field (see Juice.gd's header comment) — this
## is the only ability that touches global time_scale, so it carries four independent safety
## nets against ever stranding the game slowed: the end timer below, `player.died` (this func,
## connected once per cast), `_exit_tree` (quitting to menu mid-window), and
## `GameOver._finish_run` (a WIN mid-window — terminal pause, none of the other three fire).
##
## Move-speed comp is multiplicative and reverted with the exact ratio stored at cast time, so it
## commutes cleanly with a move-speed upgrade card taken mid-window (base -> x2.5 (cast) -> x1.2
## (card) -> /2.5 (end) == base x1.2, regardless of order). Frenzy uses gun.add_frenzy's
## maxf-merge semantics (Gun.gd) — safe to overlap with Bloodrush or a second DEAD EYE re-cast
## with no revert needed; it self-expires on its own duration.
func _cast_dead_eye(player: Player) -> void:
	_last_cast_id = "dead_eye"
	Juice.base_scale = GameConfig.ABILITY_DEADEYE_SCALE
	Engine.time_scale = GameConfig.ABILITY_DEADEYE_SCALE
	_dead_eye_active = true
	_dead_eye_player = null
	if player != null and is_instance_valid(player):
		_dead_eye_move_ratio = GameConfig.ABILITY_DEADEYE_MOVE_COMP
		player.move_speed *= _dead_eye_move_ratio
		_dead_eye_player = player
		if player.gun != null and is_instance_valid(player.gun):
			player.gun.add_frenzy(GameConfig.ABILITY_DEADEYE_FRENZY, GameConfig.ABILITY_DEADEYE_DURATION)
		# Safety net #2: connected once per Player instance (is_connected-guarded — try_cast()
		# re-fetches `player` fresh from the group every cast, and re-casting DEAD EYE on the SAME
		# player before this connection is ever cleared must not stack duplicate calls). Fires on
		# the alive->dead transition so a mid-window kill can never leave the game at 0.3x forever.
		if not player.died.is_connected(_end_dead_eye):
			player.died.connect(_end_dead_eye)
	# Safety net #1: process_always=false is the deliberate pause contract (the double_fuse-echo
	# precedent, RelicEffects.gd) — a level-up card / pause menu opening mid-window HOLDS the
	# window open instead of burning it down behind the overlay; ignore_time_scale=true means the
	# 3.0 is REAL seconds, not 3 seconds of the slowed time_scale it itself created (which would
	# actually be 10 wall-clock seconds at 0.3x).
	get_tree().create_timer(GameConfig.ABILITY_DEADEYE_DURATION, false, false, true).timeout.connect(_end_dead_eye)

## Idempotent close for the DEAD EYE window — guarded by `_dead_eye_active` since the timer,
## `player.died`, `_exit_tree`, and GameOver._finish_run (the win path — see its comment) can
## all reach here for the same cast. Always writes BOTH
## `Juice.base_scale` and `Engine.time_scale` back to 1.0 unconditionally: if a crit hit-stop is
## mid-flight when the window closes, its own token-guarded `_on_timer_done` will later restore
## `Engine.time_scale = base_scale`, which is already 1.0 by then — a harmless re-write, not a
## conflict. This is the simplest rule that's still correct, so no cross-token bookkeeping with
## Juice is needed here.
func _end_dead_eye() -> void:
	if not _dead_eye_active:
		return
	_dead_eye_active = false
	if _dead_eye_player != null and is_instance_valid(_dead_eye_player):
		_dead_eye_player.move_speed /= _dead_eye_move_ratio
	_dead_eye_player = null
	Juice.base_scale = 1.0
	Engine.time_scale = 1.0

## Safety net #3: this controller is a scenes/Main.tscn sibling (Juice/Visitors idiom) that goes
## away on scene teardown (quit to menu, run end) — mirrors Juice.gd's own _exit_tree net so a
## torn-down controller mid-DEAD-EYE-window can never leave Engine.time_scale stuck at 0.3.
## No-op via the idempotency guard if the window already ended normally.
func _exit_tree() -> void:
	_end_dead_eye()

## ONE OF THEM (Zombie Bob): the horde loses target lock on him for ABILITY_GHOST_DURATION
## seconds — regular enemies and elites stop re-aiming their chase and hold their bite/fire
## (Enemy._target_ghosted, RangedEnemy._act). All state lives on the Player instance itself
## (Player.set_ghost/is_ghost), not here — every enemy reads `_target.is_ghost()` directly, so
## there's nothing else for this controller to own or revert. Bosses are unaffected by
## construction (BossBase never defines _target_ghosted). Same null-guard idiom as
## _cast_clear_out/_cast_turret — nothing to do at all without a valid player.
func _cast_ghost(player: Player) -> void:
	_last_cast_id = "ghost"
	if player == null or not is_instance_valid(player):
		return
	player.set_ghost(GameConfig.ABILITY_GHOST_DURATION)

## Per-kill coin bonus at `pos`, right now — the seam JACKPOT's PAYDAY (this task) and CLOSING
## TIME's zone (Task 8) both pay into. STATIC + "ability_controller" group lookup, mirroring
## NightEvents.blood_moon_coins EXACTLY in shape: the Enemy.gd kill site holds no reference to
## any specific controller instance and must degrade to 0 harmlessly if one isn't in the tree at
## all (e.g. a corpse's take_damage() resolving mid scene-teardown, run already over — the same
## null-tree-safe contract blood_moon_coins already honors). Windows stack additively — a kill
## landed during an open PAYDAY window AND inside an open CLOSING TIME zone pays both.
static func kill_coin_bonus(pos: Vector2, tree) -> int:
	if tree == null:
		return 0
	var ac := tree.get_first_node_in_group("ability_controller") as AbilityController
	if ac == null:
		return 0
	var now := Time.get_ticks_msec() / 1000.0
	var bonus := 0
	if now < ac._coin_window_until:
		bonus += GameConfig.ABILITY_JACKPOT_PAYDAY_COINS
	if now < ac._coin_zone_until and pos.distance_to(ac._coin_zone_center) <= ac._coin_zone_radius:
		bonus += GameConfig.ABILITY_CLOSING_COINS
	return bonus

## JACKPOT (Alstar Tuck): four-roll slot machine — NUKE / DEEP FREEZE / PAYDAY / TRIGGER HAPPY.
## `randi() % 4` is UN-SEEDED BY DESIGN (the loot-RNG rule — every player-triggered roll is
## un-seeded; this never touches the Daily's own pre-seeded RNG, so Daily determinism is
## unaffected). The roll itself is split into `_roll_jackpot` so a probe can drive all 4 arms
## directly without depending on RNG.
func _cast_jackpot(player: Player) -> void:
	_last_cast_id = "jackpot"
	var word := _roll_jackpot(randi() % 4, player)
	if player != null and is_instance_valid(player):
		CombatText.callout(player.global_position, "JACKPOT: %s!" % word, _jackpot_callout_color(word))

## Resolves one roll (0-3) to its effect, returns the callout word. `player` is null-guarded
## per-arm (same idiom as _cast_clear_out/_cast_turret/_cast_ghost) — a roll must never crash
## just because it landed with no valid player reference.
func _roll_jackpot(roll: int, player: Player) -> String:
	match roll:
		0:
			# NUKE — Shockwave.blast WITH the equipped gun's talents (the kept Alstar crit-blast
			# precedent, Player._spawn_shockwave's own idiom). Gun is null-guarded to null; blast()
			# already handles a null gun (no talents carried, still pushes + damages).
			var fx := Shockwave.new()
			get_tree().current_scene.add_child(fx)
			var gun: Gun = null
			if player != null and is_instance_valid(player):
				fx.global_position = player.global_position
				gun = player.gun
			fx.blast(GameConfig.ABILITY_JACKPOT_NUKE_RADIUS, GameConfig.ABILITY_JACKPOT_NUKE_DAMAGE,
				GameConfig.ABILITY_JACKPOT_NUKE_FORCE, gun, player, true)
			return "NUKE"
		1:
			# DEEP FREEZE — every "enemies" node that has the freeze channel. Bosses lack
			# apply_freeze entirely (BossBase never defines it) — has_method-skipped, immune free.
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and e.has_method("apply_freeze"):
					e.apply_freeze(GameConfig.ABILITY_JACKPOT_FREEZE_DUR)
			return "DEEP FREEZE"
		2:
			# PAYDAY — arms the coin-window seam kill_coin_bonus() queries above.
			_coin_window_until = Time.get_ticks_msec() / 1000.0 + GameConfig.ABILITY_JACKPOT_PAYDAY_DURATION
			return "PAYDAY"
		_:
			# TRIGGER HAPPY — instant reload + a frenzy fire-rate window. Fully null-guarded:
			# no player/gun means no effect at all, not a crash.
			if player != null and is_instance_valid(player) and player.gun != null and is_instance_valid(player.gun):
				player.gun.instant_reload()
				player.gun.add_frenzy(GameConfig.ABILITY_JACKPOT_FRENZY, GameConfig.ABILITY_JACKPOT_FRENZY_DUR)
			return "TRIGGER HAPPY"

## Callout color per JACKPOT roll — reuses this file's existing color families instead of a new
## one-off (checked every CombatText.callout usage first): Hazards.BLOOD_RED (damage, matches
## TalentEngine's "EXECUTED"), Enemy.FROZEN_TINT (freeze, matches "SHATTER"/"BLACK FRIDAY"),
## Hazards.GOLD (== the sanctioned "ffd700" gold for PAYDAY, matches the crit/mark family),
## Hazards.ORANGE (fire/frenzy, matches Gun.gd's own FRENZY_ORANGE callout for the same buff).
func _jackpot_callout_color(word: String) -> Color:
	match word:
		"NUKE":
			return Hazards.BLOOD_RED
		"DEEP FREEZE":
			return Enemy.FROZEN_TINT
		"PAYDAY":
			return Hazards.GOLD
		_:
			return Hazards.ORANGE

## CLOSING TIME (The Janitor): one giant slick + a per-kill coin window inside it. The cfg dict
## is Player._spawn_slick's OWN cfg, copied verbatim, except radius (SLICK_RADIUS x the ability's
## RADIUS_MULT) and duration (ABILITY_CLOSING_DURATION) — same "hurts nobody, only slows" shape
## as the Janitor's own dash puddle (dps 0 / hurts_player false / slow+slow_dur reused as-is).
##
## Deliberately does NOT call HazardZone.cap_player_pools(): this ability is already capped to
## one cast per ABILITY_CLOSING_CD (45s) by try_cast()'s own cooldown gate — the cooldown IS its
## cap, so it can never itself flood the shared player_pools group. Calling cap_player_pools()
## here would only evict some UNRELATED existing pool member (an Acid Cannon shell, or one of the
## Janitor's own smaller dash slicks) for no reason — the TrailDash precedent (its own "own-group"
## fuel-pool cap, HazardZone.gd) for a spawn site that already has its own natural cap not riding
## the shared eviction too. The zone still JOINS "player_pools" via configure_hazard's own
## unconditional add (hurts_player == false) — that membership is unavoidable/harmless and
## unrelated to this cap-call omission; it just means a LATER Janitor dash slick could eventually
## evict this zone the same way any two player_pools members can evict each other, which is
## existing, expected behavior this ability doesn't change.
func _cast_closing_time(player: Player) -> void:
	_last_cast_id = "closing_time"
	if player == null or not is_instance_valid(player):
		return
	var radius := GameConfig.CHAR_JANITOR_SLICK_RADIUS * GameConfig.ABILITY_CLOSING_RADIUS_MULT
	var cfg := {
		"color": PixelTheme.ACCENT, "dps": 0.0, "radius": radius,
		"duration": GameConfig.ABILITY_CLOSING_DURATION,
		"slow": GameConfig.CHAR_JANITOR_SLICK_SLOW, "slow_dur": GameConfig.CHAR_JANITOR_SLICK_SLOW_DUR,
		"stun": 0.0, "chain": 0, "drift": 0.0, "hurts_player": false,
	}
	var zone := HazardZone.new()
	get_tree().current_scene.add_child(zone)
	zone.global_position = player.global_position
	zone.configure_hazard(cfg)
	# Arms the T7 kill_coin_bonus() seam for the SAME area + duration as the zone itself —
	# engine-clock seconds, the Hud._last_shift_toast idiom (matches _coin_window_until above).
	_coin_zone_center = player.global_position
	_coin_zone_radius = radius
	_coin_zone_until = Time.get_ticks_msec() / 1000.0 + GameConfig.ABILITY_CLOSING_DURATION

## AIR DROP (The Delivery Girl): drops a telegraphed AirDropMarker at a SNAPSHOT of the player's
## position at cast time. The marker is a get_tree().current_scene child, not a child of (or
## reference-holding on) the player — see AirDropMarker.gd's own header comment — so the drop
## lands on schedule ABILITY_AIRDROP_DELAY seconds later even if the caster dies, dashes away, or
## the run otherwise moves on mid-telegraph.
func _cast_air_drop(player: Player) -> void:
	_last_cast_id = "air_drop"
	if player == null or not is_instance_valid(player):
		return
	var marker: Node2D = preload("res://scripts/AirDropMarker.gd").new()
	get_tree().current_scene.add_child(marker)
	marker.global_position = player.global_position

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

## SECOND SHIFT (Zombie Bob, v0.1.71): the once-per-run passive revive charge. Armed in _ready()
## for the character whose row is passive; consumed by try_second_shift() below (static +
## group-lookup — Player.take_damage's death chain calls it FIRST, before UNION REP). Instance
## field, NOT static (the RelicEffects statics lesson: per-run gameplay state lives on the
## per-run controller instance).
var _second_shift_available := false

## JACKPOT PAYDAY (this task) / CLOSING TIME zone (Task 8) coin-window state — the seam
## Enemy.gd's kill-coin site queries through the static kill_coin_bonus() below. Instance
## fields, NOT static (the RelicEffects statics lesson: per-run gameplay state lives on the
## per-run controller instance, reached via the SAME group lookup as every other cross-system
## read).
##
## Final-review fix wave (v0.1.70, Finding 2): these were originally Time.get_ticks_msec()-stamped
## absolute deadlines (the Hud._last_shift_toast idiom — fine for a cosmetic toast, WRONG here).
## These windows are ECONOMY, not cosmetics: LevelUpUI/RelicChoice/TruckShop/PauseMenu all pause
## the tree, and wall-clock time keeps advancing behind the overlay regardless — a PAYDAY (10s) or
## CLOSING TIME (8s) window could silently expire while the player reads a card, while the paired
## CLOSING zone (a HazardZone, whose own `_time_left` is a game-time countdown) kept slowing
## enemies for free after its coin window had already died behind the pause. Now countdown floats,
## decremented in AbilityController._process(delta) — pause-correct (this controller sets no
## process_mode override, so it stays PROCESS_MODE_INHERIT and simply stops ticking with the rest
## of the tree, same as every other un-overridden node here; verified in the probe below) and
## time_scale-coherent (DEAD EYE's own 0.3x window doesn't stretch these either, matching
## HazardZone's `_active(delta)` tick). Mirrors two existing precedents exactly: HazardZone's own
## `_time_left -= delta` (scripts/HazardZone.gd:78 — the very zone CLOSING TIME rides) and
## NightEvents' Blood Moon `_process` countdown (scripts/NightEvents.gd:34,
## `_time_left -= delta`), both chosen for the same "this is a live gameplay window, not a fire-
## and-forget stamp" reasoning.
var _coin_window_left := 0.0           # PAYDAY: bonus active while > 0.0
var _coin_zone_center := Vector2.ZERO  # CLOSING TIME (Task 8 arms this): zone center
var _coin_zone_radius := 0.0           # CLOSING TIME (Task 8 arms this): 0 = never armed
var _coin_zone_left := 0.0             # CLOSING TIME (Task 8 arms this): zone bonus active while > 0.0

func _ready() -> void:
	add_to_group("ability_controller")
	_row = Abilities.for_character(RunConfig.character_id)
	# SECOND SHIFT: a passive row spawns pre-armed — there is no cast moment to arm it later.
	_second_shift_available = bool(_row.get("passive", false))

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		_cd_remaining -= delta
	# Finding 2: pause-safe economy-window countdowns — see the field doc comment above.
	if _coin_window_left > 0.0:
		_coin_window_left = maxf(0.0, _coin_window_left - delta)
	if _coin_zone_left > 0.0:
		_coin_zone_left = maxf(0.0, _coin_zone_left - delta)

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
## Passive rows (SECOND SHIFT) repurpose the same scale as a binary state the button already
## renders correctly with zero new code: armed = 0.0 (bright ready outline), spent = 1.0 (full
## cooling veil, forever — there is no recharge).
func cooldown_fraction() -> float:
	if bool(_row.get("passive", false)):
		return 0.0 if _second_shift_available else 1.0
	var cd := float(_row.get("cd", 0.0))
	if cd <= 0.0:
		return 0.0
	return clampf(_cd_remaining / cd, 0.0, 1.0)

## Attempts to cast this run's ability. False while cooling, or if this character has none at
## all. On success: restarts the cooldown, pops the generic name callout + this ability's cast
## SFX (Abilities.gd's "sfx" key, T9), then `match`-dispatches to the specific `_cast_<id>()`
## handler.
func try_cast() -> bool:
	# SECOND SHIFT: passive rows have no tap-cast at all — the button press just nudges (Hud's
	# existing false-path), which is the intended "this one works on its own" communication.
	if bool(_row.get("passive", false)):
		return false
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

	# T9: per-ability cast SFX, read straight off the registry row (Abilities.gd's "sfx" key).
	# CLEAR OUT's row carries "" — _cast_clear_out plays "purge" itself below, so a generic
	# play() here would double up (the Task 2 ui_tap+purge bug this wiring closes).
	var cast_sfx := String(_row.get("sfx", ""))
	if cast_sfx != "":
		SoundManager.play(cast_sfx)

	match String(_row.get("id", "")):
		"clear_out":
			_cast_clear_out(player)
		"turret":
			_cast_turret(player)
		"dead_eye":
			_cast_dead_eye(player)
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

## AIMBOT (Jimbo James, v0.1.71 — replaced DEAD EYE's bullet time; the internal id stays
## "dead_eye" because the icon and cast SFX assets are keyed by it): arms the Player's aimbot
## window — for ABILITY_AIMBOT_DURATION the gun aims itself at the nearest "enemies" member in
## gun range and fires even while moving (Player's gun-drive site bypasses the stop-to-shoot/
## _has_moved gates while a target exists). All state lives on the Player instance
## (set_aimbot/_aimbot_time — the set_ghost idiom), ticked in _physics_process, so a pause holds
## the window with zero extra machinery and there is NOTHING here to revert. The old DEAD EYE
## Engine.time_scale two-owner apparatus (4 safety nets, _end_dead_eye, _exit_tree) died with the
## ability — Juice is the sole time_scale owner again (its base_scale restore-target seam stays).
func _cast_dead_eye(player: Player) -> void:
	_last_cast_id = "dead_eye"
	if player == null or not is_instance_valid(player):
		return
	player.set_aimbot(GameConfig.ABILITY_AIMBOT_DURATION)

## SECOND SHIFT (Zombie Bob, v0.1.71 — replaced ONE OF THEM): consumes the once-per-run passive
## revive charge, if this run's controller has one armed. STATIC + "ability_controller" group
## lookup — the kill_coin_bonus() contract exactly: Player.take_damage's death chain must degrade
## to false harmlessly when no controller is in the tree (scene teardown, non-run scenes).
## HARDCORE is gated at the call site alongside UNION REP's own gate (one-life identity — this
## controller never needs to know). The revive itself lives on Player
## (ability_second_shift_revive — the UNION REP direct-_health-write recipe); this side only owns
## the charge, so the once-per-run guarantee has exactly one owner.
static func try_second_shift(player: Player, tree) -> bool:
	if player == null or tree == null:
		return false
	var ac := tree.get_first_node_in_group("ability_controller") as AbilityController
	if ac == null or not ac._second_shift_available:
		return false
	ac._second_shift_available = false
	ac._last_cast_id = "second_shift"
	player.ability_second_shift_revive()
	return true

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
	var bonus := 0
	if ac._coin_window_left > 0.0:
		bonus += GameConfig.ABILITY_JACKPOT_PAYDAY_COINS
	if ac._coin_zone_left > 0.0 and pos.distance_to(ac._coin_zone_center) <= ac._coin_zone_radius:
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
			# PAYDAY — arms the coin-window seam kill_coin_bonus() queries above. Game-time
			# countdown (Finding 2 fix) — ticked in _process, so it can't burn down behind a pause.
			_coin_window_left = GameConfig.ABILITY_JACKPOT_PAYDAY_DURATION
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
## Deliberately does NOT interact with the shared player_pools cap AT ALL — neither calling
## HazardZone.cap_player_pools() nor staying a member of the group (the remove_from_group below):
## this ability is already capped to one live zone by try_cast()'s own ABILITY_CLOSING_CD gate
## (45s cooldown ≫ 8s duration — the cooldown IS its cap), the boss TrailDash own-pool precedent
## (HazardZone.gd) for a spawn site whose natural cap means it never rides the shared eviction.
## Calling cap_player_pools() would evict an UNRELATED pool member (an Acid Cannon shell, one of
## the Janitor's own smaller dash slicks) for no reason; STAYING in the group would be worse —
## acid/bile churn hitting MAX_PLAYER_POOLS could evict this zone mid-window (group order ==
## spawn order, and a long-lived 8s zone quickly becomes "oldest"), killing the visual + slow
## while the T7 coin window below kept paying — a silent desync between what the player sees and
## what kills earn.
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
	# Exempt the ability zone from the shared player-pool cap (configure_hazard auto-joins every
	# hurts_player==false zone): joining would let acid/bile churn evict it mid-window while the
	# coin zone below kept paying — see the header comment. It rides its own rule instead: the
	# 45s cooldown means at most one ever exists.
	zone.remove_from_group("player_pools")
	# Arms the T7 kill_coin_bonus() seam for the SAME area + duration as the zone itself — a
	# game-time countdown now (Finding 2 fix), ticked in _process right alongside the zone's own
	# HazardZone._time_left, so the coin window and its paired visual/slow can never drift apart
	# behind a pause (matches _coin_window_left above).
	_coin_zone_center = player.global_position
	_coin_zone_radius = radius
	_coin_zone_left = GameConfig.ABILITY_CLOSING_DURATION

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

extends Node2D
## Root of the gameplay scene. On entry it resets the persistent difficulty autoload
## (it survives scene changes, so each run must start fresh), applies the chosen
## character's always-on perks, and tells the Spawner which mode to run. Choices come
## from the RunConfig autoload (defaults make launching this scene directly work in dev).

func _ready() -> void:
	SoundManager.music("run_loop")
	DifficultyManager.reset()
	# OVERTIME (Pack G): preset run_time AND the derived wave BEFORE any wave-reading system's
	# first tick (Spawner's boss/elite gates, NightEvents' wave-diff check) — set explicitly here
	# rather than waiting a frame for DifficultyManager's own _process to recompute wave, so
	# nothing can ever observe the pre-headstart wave-1 state, not even for a single frame.
	if RunConfig.overtime:
		DifficultyManager.run_time = GameConfig.OVERTIME_START_SECONDS
		DifficultyManager.wave = int(floor(DifficultyManager.run_time / GameConfig.WAVE_DURATION)) + 1
	# HORDE NIGHT (Pack G): reuses the exact Blood-Moon spawn-interval-mult mechanism. Safe because
	# NightEvents — the only OTHER writer of this same multiplier — is gated off entirely outside
	# mode == "endless", so it can never also touch this during a horde run. reset() above already
	# zeroed it to 1.0 first (the cross-run safety net a leftover override relies on).
	if RunConfig.mode == "horde":
		DifficultyManager.set_spawn_interval_mult(GameConfig.HORDE_SPAWN_MULT)
	RunStats.reset()
	# HARDCORE (Pack G): x3 the whole run's coin payout. Multiplies the SAME coin_mult the
	# "Silver Tongue" level-up card raises later, so the two compose as one multiplicative number.
	if RunConfig.hardcore:
		RunStats.coin_mult *= GameConfig.HARDCORE_COIN_MULT
	# EMPLOYEE BENEFITS (Pack A): permanent tracks applied once per run, all through existing
	# chokepoints. Multiplies the SAME RunStats.coin_mult hardcore already touches above.
	RunStats.coin_mult *= Benefits.coin_mult()
	# SIGNING BONUS (final-review fix): its OWN post-mult, time-vested field — NOT bonus_coins —
	# so an instant pause-quit can't farm it at full value x HARDCORE x3 x REGISTER SKIM. See
	# CoinReward.vested_signing / GameConfig.SIGNING_BONUS_VEST_TIME.
	RunStats.signing_bonus = Benefits.start_cash()
	# Pack C: Daily Shift — re-arm a FRESH seeded generator every time this scene loads while
	# RunConfig.daily is true (covers a mid-run "RESTART RUN" from PauseMenu, which reloads
	# Main.tscn directly, bypassing MainMenu's mode picker entirely) so a restart replays the
	# exact same deterministic event/elite/enemy-type sequence instead of continuing the old
	# generator's already-advanced state. A no-op for every normal (non-daily) run.
	if RunConfig.daily:
		RunConfig.start_daily(SaveManager.today_string())

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.global_position = GameConfig.FORECOURT_PLAYER_SPAWN   # the forecourt apron, clear of the store + pump row
		# OVERTIME (Pack G, final-review fix): headstart XP BEFORE Characters.apply_base — that call
		# multiplies player.xp_mult by NIGHT SCHOOL's Benefits.xp_mult(), and OVERTIME_HEADSTART_XP is
		# calibrated assuming xp_mult == 1.0 (see its doc comment). Granting it after apply_base let
		# NIGHT SCHOOL inflate the headstart into a free extra level. player.xp_mult is still its
		# freshly-spawned default (1.0) here, so add_xp() applies the raw, uninflated amount. Any
		# resulting level-ups queue in LevelUpUI (its _ready already connected `leveled_up` before this
		# runs — children ready before their parent, and LevelUpUI is a sibling child of this scene
		# root) and show once the run's first frame renders — expected behavior, not a bug.
		if RunConfig.overtime:
			player.add_xp(GameConfig.OVERTIME_HEADSTART_XP)
		Characters.apply_base(player, RunConfig.character_id)
		RunStats.coins_per_kill = Characters.coin_per_kill_bonus(RunConfig.character_id)   # Pack E: the Janitor's passive
		player.set_dash_ability(Characters.dash_ability(RunConfig.character_id))
		_equip_loadout(player)
		_spawn_companion(player)

	var spawner := get_tree().get_first_node_in_group("spawner")
	if spawner != null:
		spawner.mode = RunConfig.mode

## Configures the gun from the player's equipped loot weapon, then applies the character's
## weapon-specific perk (this is what the old weapon-select StartUI used to do). The menu
## guarantees a weapon is equipped before a run starts; the grant_starter fallback only
## matters when launching Main.tscn directly in the editor.
func _equip_loadout(player: Player) -> void:
	if player.gun == null:
		return
	var inst := Inventory.equipped_instance()
	if inst.is_empty():
		# Direct editor launch (bypassing the menu's equip gate): seed + take the first gun.
		Inventory.grant_starter()
		var owned := Inventory.weapons()
		if not owned.is_empty():
			Inventory.equip(String(owned[0].get("uid", "")))
		inst = Inventory.equipped_instance()
	if not inst.is_empty():
		var base := WeaponInstance.base_def(inst)
		if not base.is_empty():
			player.gun.configure(base)
			player.gun.apply_loot(inst)
	Characters.apply_weapon(player, RunConfig.character_id)

## Coworkers (T3): spawns the player's equipped coworker, if any. `equipped_coworker()` is a
## uid — resolve it against the live `coworkers()` list (a save can go stale if the coworker
## was later deconstructed while still equipped) rather than trusting the uid alone.
func _spawn_companion(player: Player) -> void:
	var uid := SaveManager.equipped_coworker()
	if uid == "":
		return
	var inst := {}
	for c in SaveManager.coworkers():
		if String(c.get("uid", "")) == uid:
			inst = c
			break
	if inst.is_empty():
		return
	var companion := Companion.new()
	companion.player = player
	get_tree().current_scene.add_child(companion)
	companion.global_position = player.global_position
	companion.configure(inst)

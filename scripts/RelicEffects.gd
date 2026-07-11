class_name RelicEffects
extends Node
## Relics Overhaul "Lost & Found" — the run-scoped owner of the 17 PROTOTYPE/CURSED "hook"-mode
## relics (Relics.gd's "mode": "hook" rows; apply()/remove() there deliberately no-op on them).
## Spawned once per run as a plain sibling of Main.tscn's other run-scoped controllers (Basement,
## CombatText, Extraction — same idiom: a Node with a static `instance` handle, resolved in
## _ready(), cleared in _exit_tree()) — NOT an autoload, so menu scenes pay nothing.
##
## Public surface is entirely STATIC so every call site (existing seams below, and the future
## bar/choice/scrap flows in Task 3/4) is a safe no-op before a run scene attaches this node or
## after it tears down — the exact CombatText.crit()/callout() contract:
##   RelicEffects.equip(id) / RelicEffects.unequip(id)   — idempotent, fully reversible
##   RelicEffects.on_kill(pos) / on_elite_kill(pos) / on_boss_kill() / on_dash_started(player) /
##     on_player_hurt(player) / on_hazard_burst(pos, radius, damage, force) / on_crate_loot(pos) /
##     try_vest_save(player) -> bool
##
## Hot-path reads (Enemy.take_damage, Player.apply_slow, DifficultyManager.elite_chance_mult,
## CoinReward.final_payout, Enemy._drop_gem) read STATIC class-level flags directly — no instance
## needed, no node dependency, always default to "no effect" so a relic-free run is byte-identical:
##   accelerant                    (bool)  — Enemy.take_damage: +% dmg to burning enemies
##   slow_immune                   (bool)  — Player.apply_slow: early-return, no slow ever lands
##   company_card                  (bool)  — CoinReward.final_payout: post-mult pay-stub cut
##   healing_disabled_except_kills (bool)  — Player.heal: no-op (relic_kill_heal bypasses it)
##   healing_factor                (float) — Player.heal: multiplies every heal (composable, 1.0 = none)
##   healing_cap_frac              (float) — Player.heal: caller's heal can't push current above this
##                                            fraction of max HP (1.0 = no cap)
##   nametag_mult                  (float) — DifficultyManager.elite_chance_mult(): composed
##                                            (multiplied), never clobbers Extraction's own surge value
##   nametag_gem_mult              (float) — Enemy._drop_gem(): elite gem-value multiplier
##
## Reversibility (hard invariant, per the plan): every equip() stores whatever remove() needs
## (ratios for multiplicative stats, exact deltas for HP loss — measured or floor-clamped, never a
## re-derived nominal amount) in `_state`, mirroring Relics.gd's own apply()/remove() contract.

static var instance: RelicEffects = null

# --- Static hot-path flags (see the doc block above) ---
static var accelerant := false
static var slow_immune := false
static var company_card := false
static var healing_disabled_except_kills := false
static var healing_factor := 1.0
static var healing_cap_frac := 1.0
static var nametag_mult := 1.0
static var nametag_gem_mult := 1.0

## Every hook-mode relic id this file owns — mirrors Relics.gd's PROTOTYPE (10) + CURSED (7) rows
## exactly (same ids, same order). equip()/unequip() only ever track ids in this list.
const HOOK_IDS := [
	"static_soles", "double_fuse", "magnet_coil", "intercom", "accelerant",
	"overtime_clock", "spare_parts", "rubber_soles", "adrenal_valve", "chain_letter",
	"managers_stapler", "expired_drink", "company_card", "blood_pact", "cursed_nametag",
	"overstocked", "dead_mans_vest",
]

const _XP_GEM_SCENE := preload("res://scenes/XpGem.tscn")   # spare_parts (mirrors Destructible._XP_GEM_SCENE)

var _player: Player
var _held: Dictionary = {}     # id -> true, currently-equipped hook relics
var _state: Dictionary = {}    # id-scoped reversal data (ratios / exact deltas) for equip/unequip

# magnet_coil: sliding kill-streak (see _tick_magnet_streak).
var _magnet_streak := 0
var _magnet_window := 0.0

# dead_mans_vest: per-boss-cycle cheat-death arm/consume flag (reset in _on_boss_kill()).
var _vest_ready := true

func _ready() -> void:
	## statics persist across scene reloads (class-level, not node-level) — a run ending mid-equip
	## would poison every later run; a fresh instance therefore ALWAYS starts from defaults
	## (DifficultyManager.reset idiom). This block MUST cover every gameplay static above — all 8;
	## `instance` is a lifecycle handle (set below, cleared in _exit_tree), HOOK_IDS/_XP_GEM_SCENE
	## are consts, and everything else in this file is per-instance (fresh each run by construction).
	accelerant = false
	slow_immune = false
	company_card = false
	healing_disabled_except_kills = false
	healing_factor = 1.0
	healing_cap_frac = 1.0
	nametag_mult = 1.0
	nametag_gem_mult = 1.0
	add_to_group("relic_effects")
	_player = get_tree().get_first_node_in_group("player") as Player
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(delta: float) -> void:
	if _magnet_window > 0.0:
		_magnet_window = maxf(_magnet_window - delta, 0.0)

# =====================================================================================
# Equip / unequip — idempotent, fully reversible. Static wrappers per the CombatText idiom.
# =====================================================================================

static func equip(id: String) -> void:
	if instance != null:
		instance._equip(id)

static func unequip(id: String) -> void:
	if instance != null:
		instance._unequip(id)

## True while `id` is currently equipped (internal bookkeeping; harmless to call from a probe too).
func held(id: String) -> bool:
	return _held.has(id)

func _equip(id: String) -> void:
	if not (id in HOOK_IDS) or held(id):
		return
	match id:
		"magnet_coil":
			_magnet_streak = 0
			_magnet_window = 0.0
		"accelerant":
			accelerant = true
		"rubber_soles":
			slow_immune = true
			if _player != null and is_instance_valid(_player):
				_state["rubber_soles_ratio"] = _mul_stat(_player, "move_speed", GameConfig.RELIC_RUBBER_MOVE_PCT)
		"chain_letter":
			var g := _gun()
			if g != null:
				g.bonus_pierce += GameConfig.RELIC_CHAIN_PIERCE
		"managers_stapler":
			var g2 := _gun()
			if g2 != null:
				_state["stapler_ratio"] = _mul_stat(g2, "damage", GameConfig.RELIC_STAPLER_DMG_PCT)
			healing_factor *= GameConfig.RELIC_STAPLER_HEAL_FACTOR
		"expired_drink":
			if _player != null and is_instance_valid(_player):
				_state["drink_move_ratio"] = _mul_stat(_player, "move_speed", GameConfig.RELIC_DRINK_SPEED_PCT)
				_state["drink_hp_delta"] = _apply_hp_loss_floored(GameConfig.RELIC_DRINK_HP_LOSS, GameConfig.RELIC_DRINK_HP_FLOOR)
			var g3 := _gun()
			if g3 != null:
				_state["drink_fire_ratio"] = _mul_stat_neg(g3, "fire_interval", GameConfig.RELIC_DRINK_SPEED_PCT)
		"company_card":
			RunStats.coin_mult *= GameConfig.RELIC_CARD_COIN_MULT
			company_card = true
		"blood_pact":
			healing_disabled_except_kills = true
		"cursed_nametag":
			nametag_mult *= GameConfig.RELIC_NAMETAG_ELITE_MULT
			nametag_gem_mult *= GameConfig.RELIC_NAMETAG_GEM_MULT
		"overstocked":
			if _player != null and is_instance_valid(_player):
				_state["overstock_hp_delta"] = _apply_hp_loss_measured(GameConfig.RELIC_OVERSTOCK_HP_LOSS)
			_set_bar_slot_count(GameConfig.MAX_RELIC_SLOTS + GameConfig.RELIC_OVERSTOCK_SLOTS)
		"dead_mans_vest":
			healing_cap_frac = GameConfig.RELIC_VEST_HEAL_CAP
			_vest_ready = true
		_:
			pass   # static_soles / double_fuse / intercom / overtime_clock / spare_parts /
			       # adrenal_valve: pure seam-driven, no equip-time state to store.
	_held[id] = true

func _unequip(id: String) -> void:
	if not held(id):
		return
	match id:
		"accelerant":
			accelerant = false
		"rubber_soles":
			slow_immune = false
			if _player != null and is_instance_valid(_player) and _state.has("rubber_soles_ratio"):
				_unmul_stat(_player, "move_speed", float(_state["rubber_soles_ratio"]))
			_state.erase("rubber_soles_ratio")
		"chain_letter":
			var g := _gun()
			if g != null:
				g.bonus_pierce -= GameConfig.RELIC_CHAIN_PIERCE
		"managers_stapler":
			var g2 := _gun()
			if g2 != null and _state.has("stapler_ratio"):
				_unmul_stat(g2, "damage", float(_state["stapler_ratio"]))
			_state.erase("stapler_ratio")
			healing_factor /= GameConfig.RELIC_STAPLER_HEAL_FACTOR
		"expired_drink":
			if _player != null and is_instance_valid(_player):
				if _state.has("drink_move_ratio"):
					_unmul_stat(_player, "move_speed", float(_state["drink_move_ratio"]))
				if _state.has("drink_hp_delta"):
					_player.relic_add_max_health(-float(_state["drink_hp_delta"]))
			var g3 := _gun()
			if g3 != null and _state.has("drink_fire_ratio"):
				_unmul_stat(g3, "fire_interval", float(_state["drink_fire_ratio"]))
			_state.erase("drink_move_ratio")
			_state.erase("drink_fire_ratio")
			_state.erase("drink_hp_delta")
		"company_card":
			RunStats.coin_mult /= GameConfig.RELIC_CARD_COIN_MULT
			company_card = false
		"blood_pact":
			healing_disabled_except_kills = false
		"cursed_nametag":
			nametag_mult /= GameConfig.RELIC_NAMETAG_ELITE_MULT
			nametag_gem_mult /= GameConfig.RELIC_NAMETAG_GEM_MULT
		"overstocked":
			if _player != null and is_instance_valid(_player) and _state.has("overstock_hp_delta"):
				_player.relic_add_max_health(-float(_state["overstock_hp_delta"]))
			_state.erase("overstock_hp_delta")
			_set_bar_slot_count(GameConfig.MAX_RELIC_SLOTS)
		"dead_mans_vest":
			healing_cap_frac = 1.0
		_:
			pass
	_held.erase(id)

# =====================================================================================
# Seam entry points — static wrappers (safe no-op absent), called from the verified chokepoints.
# =====================================================================================

## Enemy.take_damage's kill branch (magnet_coil's streak counter, blood_pact's kill-heal).
static func on_kill(pos: Vector2) -> void:
	if instance != null:
		instance._on_kill(pos)

## Enemy.take_damage's is_elite kill branch (intercom's fear-nearby-trash).
static func on_elite_kill(pos: Vector2) -> void:
	if instance != null:
		instance._on_elite_kill(pos)

## BossBase._reward(), right after RunStats.add_boss() (overtime_clock's hold, vest's per-cycle reset).
static func on_boss_kill() -> void:
	if instance != null:
		instance._on_boss_kill()

## Player._on_dash_started() (static_soles' electric trail).
static func on_dash_started(player: Player) -> void:
	if instance != null:
		instance._on_dash_started(player)

## Player.take_damage(), alongside the CameraShake trauma gate (adrenal_valve's cooldown refund).
static func on_player_hurt(player: Player) -> void:
	if instance != null:
		instance._on_player_hurt(player)

## Destructible._die()'s "fire" (hazard burst) branch, right after the first Shockwave (double_fuse's echo).
static func on_hazard_burst(pos: Vector2, radius: float, damage: float, force: float) -> void:
	if instance != null:
		instance._on_hazard_burst(pos, radius, damage, force)

## Destructible._die()'s "loot == gems" branch (spare_parts' extra gem + coin-burst chance).
static func on_crate_loot(pos: Vector2) -> void:
	if instance != null:
		instance._on_crate_loot(pos)

## Player.take_damage()'s death branch, AFTER UNION REP, BEFORE Second Wind (dead_mans_vest).
## Returns true if the cheat-death fired (caller must `return` immediately, like the other saves).
static func try_vest_save(player: Player) -> bool:
	if instance == null:
		return false
	return instance._try_vest_save(player)

func _on_kill(pos: Vector2) -> void:
	if held("magnet_coil"):
		_tick_magnet_streak(pos)
	if held("blood_pact") and _player != null and is_instance_valid(_player):
		_player.relic_kill_heal(GameConfig.RELIC_PACT_HEAL_PER_KILL)

## magnet_coil: a sliding kill-streak — each kill inside RELIC_MAGNET_WINDOW of the PREVIOUS kill
## extends the chain; a gap longer than the window resets it to 1. Hitting RELIC_MAGNET_STREAK
## pulls every on-screen gem to the player and resets the counter (a longer chain can trigger the
## pull more than once, but never twice for the "same" 5). Behavioral/juice-facing — reviewed +
## F5'd per the plan, not runtime-probed beyond the counter math itself.
func _tick_magnet_streak(pos: Vector2) -> void:
	if _magnet_window > 0.0:
		_magnet_streak += 1
	else:
		_magnet_streak = 1
	_magnet_window = GameConfig.RELIC_MAGNET_WINDOW
	if _magnet_streak >= GameConfig.RELIC_MAGNET_STREAK:
		_magnet_streak = 0
		_pull_all_gems()

func _pull_all_gems() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var tree := get_tree()
	if tree == null:
		return
	for g in tree.get_nodes_in_group("xp_gems"):
		if is_instance_valid(g):
			(g as Node2D).global_position = _player.global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))

## intercom: fears every nearby TRASH enemy (elites excluded — the payoff is thinning the crowd
## around the elite you just dropped, not fearing the elite itself, which is already dead). Reuses
## ELITE_ALPHA_RADIUS (the closest existing "an elite's aura reach" magnitude in GameConfig — no
## dedicated intercom radius const was authored in Task 1) as the fear radius.
func _on_elite_kill(pos: Vector2) -> void:
	if not held("intercom"):
		return
	var tree := get_tree()
	if tree == null:
		return
	var r2 := GameConfig.ELITE_ALPHA_RADIUS * GameConfig.ELITE_ALPHA_RADIUS
	for e in tree.get_nodes_in_group("enemies"):
		if not (e is Enemy) or not is_instance_valid(e):
			continue
		var enemy := e as Enemy
		if enemy.is_elite:
			continue
		if enemy.global_position.distance_squared_to(pos) <= r2:
			enemy.apply_fear(GameConfig.RELIC_INTERCOM_FEAR)

func _on_boss_kill() -> void:
	if held("overtime_clock"):
		# maxf-refresh, not additive — mirrors every other status-refresh idiom in this codebase
		# (apply_slow/apply_fear/etc.) so back-to-back Boss Rush kills can't stack an ever-growing hold.
		DifficultyManager.time_hold = maxf(DifficultyManager.time_hold, GameConfig.RELIC_TIMECLOCK_HOLD)
	if held("dead_mans_vest"):
		_vest_ready = true

## static_soles: a player-pool HazardZone (dps > 0, hurts_player false — it never hurts the
## player themself) at the dash origin, mirroring Player._spawn_slick()'s exact construction
## (same cap_player_pools() shared-eviction group). CYAN — Hazards' sanctioned "electric" exception.
func _on_dash_started(player: Player) -> void:
	if not held("static_soles") or player == null or not is_instance_valid(player):
		return
	var tree := get_tree()
	if tree == null:
		return
	HazardZone.cap_player_pools(tree)
	var cfg := {
		"color": Hazards.CYAN, "dps": GameConfig.RELIC_STATIC_TRAIL_DPS,
		"radius": GameConfig.CHAR_JANITOR_SLICK_RADIUS, "duration": GameConfig.RELIC_STATIC_TRAIL_DUR,
		"slow": 0.0, "slow_dur": 0.0, "stun": 0.0, "chain": 0, "drift": 0.0, "hurts_player": false,
	}
	var zone := HazardZone.new()
	tree.current_scene.add_child(zone)
	zone.global_position = player.global_position
	zone.configure_hazard(cfg)

func _on_player_hurt(player: Player) -> void:
	if not held("adrenal_valve") or player == null or not is_instance_valid(player):
		return
	player.relic_refund_dash_cooldown(GameConfig.RELIC_ADRENAL_REFUND)

## double_fuse: schedules ONE echo — a static callback (bound only to value args, never to `self`
## or the dying Destructible) so a run ending / this node freeing before the delay elapses can't
## fire a method on a freed instance. Damage-only: no light_fuse, no loot, no second hazard zone —
## just a second Shockwave.blast() at RELIC_DOUBLE_FUSE_PCT power, hit_destructibles=false (the
## v0.1.36 recursion lesson — an echo must never re-trigger the barrel/shelf chain).
## process_always=false: the echo honors the pause contract every Destructible fuse honors — a
## crate popped right before a pause menu / level-up / RELIC CHOICE freezes the tree must not keep
## ticking down and detonating behind the paused overlay.
func _on_hazard_burst(pos: Vector2, radius: float, damage: float, force: float) -> void:
	if not held("double_fuse"):
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(GameConfig.RELIC_DOUBLE_FUSE_DELAY, false).timeout.connect(
		_static_echo_blast.bind(tree, pos, radius, damage, force))

static func _static_echo_blast(tree: SceneTree, pos: Vector2, radius: float, damage: float, force: float) -> void:
	if tree == null or tree.current_scene == null:
		return
	var sw := Shockwave.new()
	tree.current_scene.add_child(sw)
	sw.global_position = pos
	sw.blast(radius, damage * GameConfig.RELIC_DOUBLE_FUSE_PCT, force * GameConfig.RELIC_DOUBLE_FUSE_PCT, null, null, false)

## spare_parts: +RELIC_SPARE_GEMS gems (own XpGem instances, mirrors Destructible._drop_loot's
## spawn shape) plus a RELIC_SPARE_COIN_CHANCE roll for a CRATE_COIN_REWARD coin burst — reuses
## the same magnitude the crate's own "coins" drop already pays (no dedicated spare_parts coin
## const was authored in Task 1).
func _on_crate_loot(pos: Vector2) -> void:
	if not held("spare_parts"):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for i in GameConfig.RELIC_SPARE_GEMS:
		var gem = _XP_GEM_SCENE.instantiate()
		tree.current_scene.add_child(gem)
		gem.global_position = pos + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	if randf() < GameConfig.RELIC_SPARE_COIN_CHANCE:
		RunStats.add_coins(GameConfig.CRATE_COIN_REWARD)

## dead_mans_vest: cheat death once per boss cycle. Defensive hardcore gate even though T1's roll
## already excludes the relic from ever being offered in hardcore (never trust that alone).
func _try_vest_save(player: Player) -> bool:
	if RunConfig.hardcore:
		return false
	if not held("dead_mans_vest") or not _vest_ready or player == null or not is_instance_valid(player):
		return false
	_vest_ready = false
	player.relic_vest_revive()
	return true

# =====================================================================================
# Small internal helpers
# =====================================================================================

func _gun() -> Gun:
	if _player == null or not is_instance_valid(_player):
		return null
	return _player.gun

## "+pct" ratio (mirrors Relics.gd's "pct" mode). Returns the ratio for exact reversal.
func _mul_stat(obj: Object, prop: String, pct: float) -> float:
	var ratio := 1.0 + pct
	obj.set(prop, float(obj.get(prop)) * ratio)
	return ratio

## "pct_neg" ratio (mirrors Relics.gd's "pct_neg" mode — smaller multiplier = faster fire rate).
func _mul_stat_neg(obj: Object, prop: String, pct: float) -> float:
	var ratio := 1.0 - pct
	obj.set(prop, float(obj.get(prop)) * ratio)
	return ratio

## Reverses either of the above: divide the SAME ratio back out (never a stale subtract), so an
## upgrade card touching the same stat mid-run can't drift the reversal — same reasoning as
## Relics.remove()'s "pct"/"pct_neg" branch.
func _unmul_stat(obj: Object, prop: String, ratio: float) -> void:
	if ratio == 0.0:
		return
	obj.set(prop, float(obj.get(prop)) / ratio)

## expired_drink: max-HP loss clamped so max_health never drops below `floor_hp`, via the SAME
## Player.relic_add_max_health gated path vital_surge/upgrade cards already use (hardcore: max
## still shrinks, current doesn't). Returns the exact (negative-or-zero) delta actually applied,
## so unequip can reverse it exactly regardless of the floor clamp.
func _apply_hp_loss_floored(nominal: float, floor_hp: float) -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var desired := minf(nominal, maxf(0.0, _player.max_hp() - floor_hp))
	if desired <= 0.0:
		return 0.0
	_player.relic_add_max_health(-desired)
	return -desired

## overstocked: max-HP loss with no per-relic floor beyond Health.add_max's own generic [1, maxhp]
## safety clamp (no dedicated floor const was authored for this relic) — measures the ACTUAL delta
## observed (before/after) so reversal is exact even if that internal clamp ever kicks in.
func _apply_hp_loss_measured(nominal: float) -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	var before := _player.max_hp()
	_player.relic_add_max_health(-nominal)
	return _player.max_hp() - before

## overstocked: 4->6 slot bar rendering is Task 4's job — has_method-guarded stub until it lands
## (an absent/older RelicBar just keeps its 4-slot draw; the relic's HP-loss half still applies).
func _set_bar_slot_count(n: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var bar := tree.get_first_node_in_group("relic_bar")
	if bar != null and bar.has_method("set_slot_count"):
		bar.call("set_slot_count", n)

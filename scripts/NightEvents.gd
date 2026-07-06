class_name NightEvents
extends Node2D
## Endless-only random night-shift events (Pack A: Run variety): one active at a time, rolled at
## each new wave past NIGHT_EVENT_MIN_WAVE if none is currently active, lasting ~1 wave. Every
## magnitude an event grants gets restored the instant it ends (spawn interval, coin_mult, the
## CanvasModulate tint, chain bonus) — the run keeps going past the event (endless doesn't
## reload the scene between waves), so this script's own _end_event() is the primary cleanup.
## DifficultyManager.reset() (called every Main._ready()) is the second, cross-run safety net —
## it's an autoload, so a run that's torn down mid-event (quit) would otherwise leak an override
## into the NEXT run; RunStats.coin_mult resets the same way via RunStats.reset().

const KIND_NONE := ""
const KIND_BLOOD_MOON := "blood_moon"
const KIND_FOG_BANK := "fog_bank"
const KIND_POWER_SURGE := "power_surge"
const KIND_RUSH_HOUR := "rush_hour"
const _KINDS := [KIND_BLOOD_MOON, KIND_FOG_BANK, KIND_POWER_SURGE, KIND_RUSH_HOUR]
const _NEUTRAL_TINT := Color(1, 1, 1, 1)

var active_kind := KIND_NONE
var _time_left := 0.0
var _prev_wave := 1
var _tint: CanvasModulate

func _ready() -> void:
	add_to_group("night_events")
	_prev_wave = DifficultyManager.wave
	_tint = get_tree().current_scene.get_node_or_null("NightTint") as CanvasModulate

func _process(delta: float) -> void:
	if RunConfig.mode != "endless":
		return   # Boss Rush completely untouched
	if active_kind != KIND_NONE:
		_time_left -= delta
		if _time_left <= 0.0:
			_end_event()
		return
	var wave := DifficultyManager.wave
	if wave == _prev_wave:
		return
	_prev_wave = wave
	if wave <= GameConfig.NIGHT_EVENT_MIN_WAVE:
		return
	if randf() < GameConfig.NIGHT_EVENT_CHANCE:
		_start_event(_KINDS[randi() % _KINDS.size()])

func _start_event(kind: String) -> void:
	active_kind = kind
	_time_left = GameConfig.NIGHT_EVENT_DURATION
	SoundManager.play("dawn_sting")
	_banner(_display_name(kind))
	# String-literal cases (not the bare KIND_* const names) — GDScript's match treats a bare
	# unqualified identifier as a new variable BINDING, not a value comparison, so matching
	# against the consts directly here would silently always take the first case.
	match kind:
		"blood_moon":
			DifficultyManager.set_spawn_interval_mult(GameConfig.BLOOD_MOON_SPAWN_MULT)
			RunStats.adjust_coin_mult(GameConfig.BLOOD_MOON_COIN_MULT_BONUS)
			_set_tint(Color(1, 1, 1, 1).lerp(Hazards.BLOOD_RED, GameConfig.BLOOD_MOON_TINT_STRENGTH))
		"fog_bank":
			_set_tint(Color(1, 1, 1, 1).lerp(Color(0, 0, 0, 1), GameConfig.FOG_BANK_DIM))
		"power_surge":
			pass   # a pure read (chain_bonus()) below; nothing to set up or tear down
		"rush_hour":
			var field := get_tree().get_first_node_in_group("obstacle_field")
			if field != null:
				field.call("rush_hour_scatter", randi_range(GameConfig.RUSH_HOUR_MIN_COUNT, GameConfig.RUSH_HOUR_MAX_COUNT))

func _end_event() -> void:
	match active_kind:
		"blood_moon":
			DifficultyManager.set_spawn_interval_mult(1.0)
			RunStats.adjust_coin_mult(-GameConfig.BLOOD_MOON_COIN_MULT_BONUS)
	_set_tint(_NEUTRAL_TINT)
	active_kind = KIND_NONE
	_banner("ALL CLEAR")

func _set_tint(c: Color) -> void:
	if _tint != null:
		_tint.color = c

func _banner(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("show_banner", text)

static func _display_name(kind: String) -> String:
	match kind:
		"blood_moon":
			return "BLOOD MOON"
		"fog_bank":
			return "FOG BANK"
		"power_surge":
			return "POWER SURGE"
		"rush_hour":
			return "RUSH HOUR"
		_:
			return ""

## Fog Bank: XP gem value multiplier (1.0 = normal). Read by Enemy._drop_gem via a plain group
## lookup, like every other cross-system read in this project (Spawner/boss/player/etc.) — no
## static-singleton pointer to keep in sync.
static func gem_value_mult(tree) -> float:
	if tree == null:
		return 1.0
	var n: Node = tree.get_first_node_in_group("night_events")
	if n == null or n.active_kind != KIND_FOG_BANK:
		return 1.0
	return GameConfig.FOG_BANK_GEM_MULT

## Power Surge: + chain jumps (1.0's additive sibling — 0 = normal), consumed at the exact point
## jumps resolve (Gun._fire_lightning's own fire path + TalentEngine._chain, shared by both the
## "chain" and "bolt" talent procs).
static func chain_bonus(tree) -> int:
	if tree == null:
		return 0
	var n: Node = tree.get_first_node_in_group("night_events")
	if n == null or n.active_kind != KIND_POWER_SURGE:
		return 0
	return GameConfig.POWER_SURGE_CHAIN_BONUS

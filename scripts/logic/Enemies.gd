class_name Enemies
## Registry of trash enemy types. The Spawner picks from here each spawn (wave-gated,
## weighted random). Adding an enemy = one data row + its scene. Final stats = the wave's
## base DifficultyCurve.enemy_stats scaled by this row's hp/spd/dmg multipliers (the
## "config over code" rule — tuning lives here + in GameConfig, not in the spawner).
##
## Row fields:
##   id        : String  unique key
##   scene     : PackedScene  enemy scene to instance
##   hp_mult   : float  multiplier on the wave's base max_health
##   spd_mult  : float  multiplier on the wave's base move_speed (then clamped to ENEMY_HARD_SPEED_CAP)
##   dmg_mult  : float  multiplier on the wave's base touch_damage
##   min_wave  : int    not eligible until this wave (the intro schedule)
##   weight    : int    relative spawn weight among the currently-eligible types

const _LIST: Array[Dictionary] = [
	{ "id": "shambler", "scene": preload("res://scenes/Enemy.tscn"),       "hp_mult": 1.0, "spd_mult": 1.0, "dmg_mult": 1.0, "min_wave": 1,  "weight": 100 },
	{ "id": "runner",   "scene": preload("res://scenes/Runner.tscn"),       "hp_mult": 0.4, "spd_mult": 1.7, "dmg_mult": 0.7, "min_wave": 2,  "weight": 40 },
	{ "id": "brute",    "scene": preload("res://scenes/Brute.tscn"),        "hp_mult": 4.0, "spd_mult": 0.55,"dmg_mult": 2.2, "min_wave": 4,  "weight": 15 },
	{ "id": "exploder", "scene": preload("res://scenes/Exploder.tscn"),     "hp_mult": 0.8, "spd_mult": 1.3, "dmg_mult": 0.0, "min_wave": 5,  "weight": 20 },
	{ "id": "hive",     "scene": preload("res://scenes/Hive.tscn"),         "hp_mult": 6.0, "spd_mult": 0.0, "dmg_mult": 1.0, "min_wave": 7,  "weight": 8 },
	{ "id": "spitter",  "scene": preload("res://scenes/RangedEnemy.tscn"), "hp_mult": 0.9, "spd_mult": 1.0, "dmg_mult": 1.0, "min_wave": 10, "weight": 25 },
	{ "id": "mutant",   "scene": preload("res://scenes/MutatedElite.tscn"), "hp_mult": 3.0, "spd_mult": 1.2, "dmg_mult": 1.8, "min_wave": 12, "weight": 10 },
]

## Full registry (read-only use). Returned by reference — do not mutate.
static func all() -> Array:
	return _LIST

## A weighted-random row among types whose min_wave <= wave. Never empty for wave >= 1
## (the shambler is always eligible); falls back to the shambler row otherwise.
static func pick(wave: int) -> Dictionary:
	var pool: Array[Dictionary] = []
	var total := 0
	for e in _LIST:
		if int(e["min_wave"]) <= wave:
			pool.append(e)
			total += int(e["weight"])
	if pool.is_empty() or total <= 0:
		return _LIST[0]
	# Pack C (Daily Shift): RunConfig.rand_int() uses the date-seeded generator only while a
	# Daily Shift run is active, falling back to the plain global randi() otherwise — so a normal
	# run's enemy-type roll is byte-identical to before this pack.
	var roll := RunConfig.rand_int() % total
	for e in pool:
		roll -= int(e["weight"])
		if roll < 0:
			return e
	return pool[pool.size() - 1]

## Ready-to-bake stats for one spawn of `entry` on `wave`: the wave's base enemy_stats
## times this row's per-type multipliers (move speed hard-capped).
static func stats_for(entry: Dictionary, wave: int) -> Dictionary:
	var base := DifficultyCurve.enemy_stats(wave)
	return {
		"max_health": float(base["max_health"]) * float(entry["hp_mult"]),
		"move_speed": minf(float(base["move_speed"]) * float(entry["spd_mult"]), GameConfig.ENEMY_HARD_SPEED_CAP),
		"touch_damage": float(base["touch_damage"]) * float(entry["dmg_mult"]),
		"special_mult": float(base["special_mult"]),
	}

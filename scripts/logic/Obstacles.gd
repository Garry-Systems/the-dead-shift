class_name Obstacles
## Registry of destructible obstacles the ObstacleField scatters around the player.
## Mirrors Enemies.gd: weighted + wave-gated pick(). The ObstacleField builds one
## parameterized Destructible node per picked row (obstacles are uniform — no per-type
## scene/art needed for v1; the Destructible draws itself).
##
## Row fields:
##   id        : String  unique key
##   kind      : String  "hazard" | "cover" | "loot"
##   shape     : String  "circle" | "rect"
##   size      : float   circle radius, or rect half-extent (px)
##   solid     : bool    true = on the cover layer (blocks movement + bullets + line of sight)
##   hp        : float   < 0 = indestructible
##   hazard_id : String  "" | "fire" | "acid" | "electric" (spawned on death)
##   loot      : String  "" | "gems"
##   gem_count : int     gems dropped when loot == "gems"
##   color     : Color   body fill (palette C3, or hazard accent so the player can read it)
##   weight    : int     relative spawn weight among eligible rows
##   min_wave  : int     not eligible until this wave

const C3 := Color(0.549, 0.522, 0.451)   # gray-tan props (palette)
# Body tints so the player reads a hazard prop at a glance — the 3 sanctioned exceptions.
const FIRE_TINT := Color(0.85, 0.45, 0.2)   # palette exception (orange = fire barrel)
const ACID_TINT := Color(0.4, 0.8, 0.2)     # palette exception (green = chem drum)
const ELEC_TINT := Color(0.2, 0.8, 0.85)    # palette exception (cyan = transformer)

## Built fresh each call (rows reference GameConfig consts) — small + read-only by use.
static func all() -> Array:
	return [
		{ "id":"barrel",      "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.BARREL_HP,      "hazard_id":"fire",     "loot":"",     "gem_count":0,                       "color":FIRE_TINT, "weight":30, "min_wave":1 },
		{ "id":"chem_drum",   "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.DRUM_HP,        "hazard_id":"acid",     "loot":"",     "gem_count":0,                       "color":ACID_TINT, "weight":25, "min_wave":2 },
		{ "id":"transformer", "kind":"hazard", "shape":"rect",   "size":20.0, "solid":false, "hp":GameConfig.TRANSFORMER_HP, "hazard_id":"electric", "loot":"",     "gem_count":0,                       "color":ELEC_TINT, "weight":20, "min_wave":3 },
		{ "id":"crate",       "kind":"loot",   "shape":"rect",   "size":16.0, "solid":false, "hp":GameConfig.CRATE_HP,       "hazard_id":"",         "loot":"gems", "gem_count":GameConfig.CRATE_GEM_COUNT, "color":C3,                    "weight":40, "min_wave":1 },
		{ "id":"car",         "kind":"cover",  "shape":"rect",   "size":48.0, "solid":true,  "hp":GameConfig.COVER_CAR_HP,   "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":18, "min_wave":1 },
		{ "id":"rubble",      "kind":"cover",  "shape":"circle", "size":34.0, "solid":true,  "hp":GameConfig.RUBBLE_HP,      "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":15, "min_wave":1 },
	]

## A weighted-random row among types whose min_wave <= wave. Falls back to the first row.
static func pick(wave: int) -> Dictionary:
	var rows := all()
	var pool: Array = []
	var total := 0
	for e in rows:
		if int(e["min_wave"]) <= wave:
			pool.append(e)
			total += int(e["weight"])
	if pool.is_empty() or total <= 0:
		return rows[0]
	var roll := randi() % total
	for e in pool:
		roll -= int(e["weight"])
		if roll < 0:
			return e
	return pool[pool.size() - 1]

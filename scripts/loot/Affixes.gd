class_name Affixes
## Weapon affix ("prefix") templates — the random rolled-stat layer that sits on top of
## a base Weapons def. An affix declares which stats it CAN roll and the min/max range
## for each; a rolled instance stores only a 0..1 quality per stat and the final value is
## recomputed as min + (max-min)*roll. Pure data (mirrors Weapons.gd).
##
## Stat ids map 1:1 onto the existing Gun.upgrade_* hooks, so applying loot reuses the
## proven per-run stat path:
##   damage,fire_rate,bullet_speed,range,reload,mag  -> percent (% better)
##   multishot,pierce,ricochet                       -> flat (+N)
const PCT_STATS := ["damage", "fire_rate", "bullet_speed", "range", "reload", "mag"]
const FLAT_STATS := ["multishot", "pierce", "ricochet"]

## One affix per rarity for v1. Each: id, display prefix, rarity, how many stats roll,
## and the per-stat ranges. Add more affixes per rarity later — the roller picks randomly
## among all affixes whose rarity matches the rolled tier.
static func all() -> Array:
	return [
		{
			"id": "rusted", "name": "Rusted", "rarity": 1, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 0,
			"stats": { "damage": [2, 6], "reload": [2, 8] },
		},
		{
			"id": "salvaged", "name": "Salvaged", "rarity": 2, "min_stats": 2, "max_stats": 2,
			"min_talents": 0, "max_talents": 1,
			"stats": { "damage": [5, 10], "fire_rate": [5, 10], "range": [5, 12] },
		},
		{
			"id": "hardened", "name": "Hardened", "rarity": 3, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 1,
			"stats": { "damage": [8, 14], "fire_rate": [6, 12], "range": [8, 16], "mag": [8, 16] },
		},
		{
			"id": "lethal", "name": "Lethal", "rarity": 4, "min_stats": 3, "max_stats": 4,
			"min_talents": 1, "max_talents": 2,
			"stats": {
				"damage": [10, 18], "fire_rate": [8, 14], "range": [10, 20],
				"mag": [10, 20], "reload": [8, 16], "pierce": [1, 1],
			},
		},
		{
			"id": "savage", "name": "Savage", "rarity": 5, "min_stats": 3, "max_stats": 5,
			"min_talents": 2, "max_talents": 2,
			"stats": {
				"damage": [14, 22], "fire_rate": [10, 18], "bullet_speed": [10, 20],
				"mag": [12, 24], "reload": [10, 20], "pierce": [1, 1], "multishot": [1, 1],
			},
		},
		{
			"id": "merciless", "name": "Merciless", "rarity": 6, "min_stats": 4, "max_stats": 6,
			"min_talents": 2, "max_talents": 3,
			"stats": {
				"damage": [16, 26], "fire_rate": [12, 22], "range": [14, 28], "bullet_speed": [12, 24],
				"mag": [15, 30], "reload": [12, 24], "pierce": [1, 2], "multishot": [1, 1],
			},
		},
		{
			"id": "carnage", "name": "Carnage", "rarity": 7, "min_stats": 5, "max_stats": 7,
			"min_talents": 3, "max_talents": 3,
			"stats": {
				"damage": [20, 32], "fire_rate": [15, 26], "range": [18, 34], "bullet_speed": [15, 28],
				"mag": [20, 40], "reload": [15, 30], "pierce": [1, 2], "multishot": [1, 2], "ricochet": [1, 1],
			},
		},
	]

static func get_affix(id: String) -> Dictionary:
	for a in all():
		if a["id"] == id:
			return a
	return {}

## All affixes of a given rarity (the roller picks one at random from this set).
static func of_rarity(rarity: int) -> Array:
	var out: Array = []
	for a in all():
		if a["rarity"] == rarity:
			out.append(a)
	return out

static func is_flat(stat_id: String) -> bool:
	return FLAT_STATS.has(stat_id)

## Convert a stored 0..1 roll into the real value for a stat on this affix.
##   range [14,23], roll 0.5 -> 18.5 (a +18.5% or +N stat)
static func resolve(affix: Dictionary, stat_id: String, roll: float) -> float:
	var r: Array = affix.get("stats", {}).get(stat_id, [0, 0])
	return r[0] + (r[1] - r[0]) * roll

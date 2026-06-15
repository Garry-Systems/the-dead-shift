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
##
## TUNED 2026-06-15 ("go nuts — RNG is king"): steep ladder, clearly-separated tiers, wide
## god-roll spreads, and multishot/pierce/ricochet pushed hard at the top so a high-rarity
## drop is transformative. % stats are "+X% better"; flat stats are "+N". fire_rate/reload
## are reductions applied multiplicatively (kept <100% so they can never zero an interval).
static func all() -> Array:
	return [
		{
			"id": "rusted", "name": "Rusted", "rarity": 1, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 0,
			"stats": { "damage": [4, 12], "reload": [3, 10] },
		},
		{
			"id": "salvaged", "name": "Salvaged", "rarity": 2, "min_stats": 2, "max_stats": 3,
			"min_talents": 0, "max_talents": 1,
			"stats": { "damage": [10, 22], "fire_rate": [6, 14], "range": [8, 18] },
		},
		{
			"id": "hardened", "name": "Hardened", "rarity": 3, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 1,
			"stats": { "damage": [18, 36], "fire_rate": [10, 20], "range": [14, 26], "mag": [12, 28] },
		},
		{
			"id": "lethal", "name": "Lethal", "rarity": 4, "min_stats": 3, "max_stats": 4,
			"min_talents": 1, "max_talents": 2,
			"stats": {
				"damage": [30, 55], "fire_rate": [16, 28], "range": [20, 36],
				"mag": [18, 36], "reload": [12, 28], "multishot": [1, 1], "pierce": [1, 1],
			},
		},
		{
			"id": "savage", "name": "Savage", "rarity": 5, "min_stats": 4, "max_stats": 5,
			"min_talents": 2, "max_talents": 2,
			"stats": {
				"damage": [45, 80], "fire_rate": [22, 36], "bullet_speed": [15, 40],
				"range": [28, 48], "mag": [25, 50], "reload": [18, 36], "multishot": [1, 2], "pierce": [1, 2],
			},
		},
		{
			"id": "merciless", "name": "Merciless", "rarity": 6, "min_stats": 4, "max_stats": 6,
			"min_talents": 2, "max_talents": 3,
			"stats": {
				"damage": [60, 105], "fire_rate": [28, 44], "range": [36, 60], "bullet_speed": [25, 55],
				"mag": [35, 70], "reload": [25, 45], "multishot": [2, 3], "pierce": [1, 3], "ricochet": [1, 1],
			},
		},
		{
			"id": "carnage", "name": "Carnage", "rarity": 7, "min_stats": 5, "max_stats": 7,
			"min_talents": 3, "max_talents": 3,
			"stats": {
				"damage": [80, 140], "fire_rate": [35, 55], "range": [45, 75], "bullet_speed": [40, 80],
				"mag": [50, 100], "reload": [35, 60], "multishot": [2, 4], "pierce": [2, 4], "ricochet": [1, 2],
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

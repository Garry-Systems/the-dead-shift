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
## NOTE: the `min_talents`/`max_talents` fields below are LEGACY and no longer read — the
## talent COUNT per weapon is now fixed per rarity in Rarity.TIERS[].talents (see
## LootRoller._roll_talents). Left in place only so old data/tools don't choke on missing keys.
##
## TUNED 2026-06-15 ("go nuts — RNG is king"): steep ladder, clearly-separated tiers, wide
## god-roll spreads, and multishot/pierce/ricochet pushed hard at the top so a high-rarity
## drop is transformative. % stats are "+X% better"; flat stats are "+N". fire_rate/reload
## are reductions applied multiplicatively (kept <100% so they can never zero an interval).
static func all() -> Array:
	return [
		{ "id": "rusted", "name": "Rusted", "rarity": 1, "min_stats": 1, "max_stats": 2, "min_talents": 0, "max_talents": 0, "legacy": true, "stats": { "damage": [4, 12], "reload": [3, 10] } },
		{ "id": "salvaged", "name": "Salvaged", "rarity": 2, "min_stats": 2, "max_stats": 3, "min_talents": 0, "max_talents": 1, "legacy": true, "stats": { "damage": [10, 22], "fire_rate": [6, 14], "range": [8, 18] } },
		{ "id": "hardened", "name": "Hardened", "rarity": 3, "min_stats": 2, "max_stats": 3, "min_talents": 1, "max_talents": 1, "legacy": true, "stats": { "damage": [18, 36], "fire_rate": [10, 20], "range": [14, 26], "mag": [12, 28] } },
		{ "id": "lethal", "name": "Lethal", "rarity": 4, "min_stats": 3, "max_stats": 4, "min_talents": 1, "max_talents": 2, "legacy": true, "stats": { "damage": [30, 55], "fire_rate": [16, 28], "range": [20, 36], "mag": [18, 36], "reload": [12, 28], "multishot": [1, 1], "pierce": [1, 1] } },
		{ "id": "savage", "name": "Savage", "rarity": 5, "min_stats": 4, "max_stats": 5, "min_talents": 2, "max_talents": 2, "legacy": true, "stats": { "damage": [45, 80], "fire_rate": [22, 36], "bullet_speed": [15, 40], "range": [28, 48], "mag": [25, 50], "reload": [18, 36], "multishot": [1, 2], "pierce": [1, 2] } },
		{ "id": "merciless", "name": "Merciless", "rarity": 6, "min_stats": 4, "max_stats": 6, "min_talents": 2, "max_talents": 3, "legacy": true, "stats": { "damage": [60, 105], "fire_rate": [28, 44], "range": [36, 60], "bullet_speed": [25, 55], "mag": [35, 70], "reload": [25, 45], "multishot": [2, 3], "pierce": [1, 3], "ricochet": [1, 1] } },
		{ "id": "carnage", "name": "Carnage", "rarity": 7, "min_stats": 5, "max_stats": 7, "min_talents": 3, "max_talents": 3, "legacy": true, "stats": { "damage": [80, 140], "fire_rate": [35, 55], "range": [45, 75], "bullet_speed": [40, 80], "mag": [50, 100], "reload": [35, 60], "multishot": [2, 4], "pierce": [2, 4], "ricochet": [1, 2] } },
		{ "id": "r1_razor", "name": "Razor", "rarity": 1, "min_stats": 1, "max_stats": 1, "min_talents": 0, "max_talents": 0, "stats": { "damage": [6, 14] } },
		{ "id": "r1_rapid", "name": "Rapid", "rarity": 1, "min_stats": 1, "max_stats": 2, "min_talents": 0, "max_talents": 0, "stats": { "fire_rate": [6, 14], "reload": [3, 10] } },
		{ "id": "r2_razor", "name": "Razor", "rarity": 2, "min_stats": 1, "max_stats": 2, "min_talents": 0, "max_talents": 1, "stats": { "damage": [12, 24], "range": [8, 18] } },
		{ "id": "r2_rapid", "name": "Rapid", "rarity": 2, "min_stats": 1, "max_stats": 2, "min_talents": 0, "max_talents": 1, "stats": { "fire_rate": [8, 16], "reload": [6, 14] } },
		{ "id": "r2_longshot", "name": "Longshot", "rarity": 2, "min_stats": 1, "max_stats": 2, "min_talents": 0, "max_talents": 1, "stats": { "range": [12, 24], "bullet_speed": [10, 28] } },
		{ "id": "r3_razor", "name": "Razor", "rarity": 3, "min_stats": 2, "max_stats": 2, "min_talents": 1, "max_talents": 1, "stats": { "damage": [20, 40], "range": [14, 26] } },
		{ "id": "r3_rapid", "name": "Rapid", "rarity": 3, "min_stats": 2, "max_stats": 2, "min_talents": 1, "max_talents": 1, "stats": { "fire_rate": [12, 22], "reload": [10, 22] } },
		{ "id": "r3_heavy", "name": "Heavy", "rarity": 3, "min_stats": 2, "max_stats": 2, "min_talents": 1, "max_talents": 1, "stats": { "mag": [14, 30], "damage": [14, 28] } },
		{ "id": "r4_razor", "name": "Razor", "rarity": 4, "min_stats": 2, "max_stats": 3, "min_talents": 1, "max_talents": 2, "stats": { "damage": [32, 58], "range": [20, 36], "fire_rate": [12, 22] } },
		{ "id": "r4_heavy", "name": "Heavy", "rarity": 4, "min_stats": 2, "max_stats": 3, "min_talents": 1, "max_talents": 2, "stats": { "mag": [20, 40], "multishot": [1, 1], "damage": [24, 44] } },
		{ "id": "r4_hollow", "name": "Hollow", "rarity": 4, "min_stats": 2, "max_stats": 3, "min_talents": 1, "max_talents": 2, "stats": { "pierce": [1, 1], "multishot": [1, 1], "damage": [20, 40] } },
		{ "id": "r4_longshot", "name": "Longshot", "rarity": 4, "min_stats": 2, "max_stats": 3, "min_talents": 1, "max_talents": 2, "stats": { "range": [24, 42], "bullet_speed": [18, 40], "damage": [20, 40] } },
		{ "id": "r5_razor", "name": "Razor", "rarity": 5, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 2, "stats": { "damage": [48, 84], "fire_rate": [18, 30], "range": [28, 48], "bullet_speed": [15, 40] } },
		{ "id": "r5_heavy", "name": "Heavy", "rarity": 5, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 2, "stats": { "mag": [28, 55], "multishot": [1, 2], "damage": [36, 64], "reload": [15, 30] } },
		{ "id": "r5_hollow", "name": "Hollow", "rarity": 5, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 2, "stats": { "pierce": [1, 2], "multishot": [1, 2], "damage": [32, 60], "range": [24, 44] } },
		{ "id": "r5_brutal", "name": "Brutal", "rarity": 5, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 2, "stats": { "damage": [40, 72], "multishot": [1, 2], "pierce": [1, 2], "fire_rate": [18, 30] } },
		{ "id": "r6_razor", "name": "Razor", "rarity": 6, "min_stats": 3, "max_stats": 5, "min_talents": 2, "max_talents": 3, "stats": { "damage": [64, 110], "fire_rate": [28, 44], "range": [36, 60], "bullet_speed": [25, 55], "reload": [25, 45] } },
		{ "id": "r6_heavy", "name": "Heavy", "rarity": 6, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 3, "stats": { "mag": [38, 75], "multishot": [2, 3], "damage": [48, 88], "reload": [25, 45] } },
		{ "id": "r6_hollow", "name": "Hollow", "rarity": 6, "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 3, "stats": { "pierce": [1, 3], "multishot": [2, 3], "damage": [44, 84], "ricochet": [1, 1] } },
		{ "id": "r6_brutal", "name": "Brutal", "rarity": 6, "min_stats": 4, "max_stats": 5, "min_talents": 2, "max_talents": 3, "stats": { "damage": [56, 100], "multishot": [2, 3], "pierce": [1, 3], "ricochet": [1, 1], "fire_rate": [28, 44] } },
		{ "id": "r7_razor", "name": "Razor", "rarity": 7, "min_stats": 4, "max_stats": 6, "min_talents": 3, "max_talents": 3, "stats": { "damage": [85, 145], "fire_rate": [35, 55], "range": [45, 75], "bullet_speed": [40, 80], "reload": [35, 60], "mag": [40, 80] } },
		{ "id": "r7_heavy", "name": "Heavy", "rarity": 7, "min_stats": 4, "max_stats": 5, "min_talents": 3, "max_talents": 3, "stats": { "mag": [55, 105], "multishot": [2, 4], "damage": [70, 120], "reload": [35, 60], "pierce": [2, 4] } },
		{ "id": "r7_hollow", "name": "Hollow", "rarity": 7, "min_stats": 4, "max_stats": 5, "min_talents": 3, "max_talents": 3, "stats": { "pierce": [2, 4], "multishot": [2, 4], "damage": [64, 116], "ricochet": [1, 2], "range": [45, 75] } },
		{ "id": "r7_brutal", "name": "Brutal", "rarity": 7, "min_stats": 5, "max_stats": 6, "min_talents": 3, "max_talents": 3, "stats": { "damage": [80, 140], "multishot": [2, 4], "pierce": [2, 4], "ricochet": [1, 2], "fire_rate": [35, 55], "bullet_speed": [40, 80] } },
		{ "id": "r8_razor",  "name": "Razor",  "rarity": 8, "min_stats": 5, "max_stats": 6, "min_talents": 3, "max_talents": 3, "stats": { "damage": [115, 195], "fire_rate": [45, 68], "range": [58, 95], "bullet_speed": [52, 100], "reload": [45, 72], "mag": [55, 105] } },
		{ "id": "r8_heavy",  "name": "Heavy",  "rarity": 8, "min_stats": 4, "max_stats": 5, "min_talents": 3, "max_talents": 3, "stats": { "mag": [72, 135], "multishot": [3, 5], "damage": [95, 160], "reload": [45, 72], "pierce": [3, 5] } },
		{ "id": "r8_hollow", "name": "Hollow", "rarity": 8, "min_stats": 4, "max_stats": 5, "min_talents": 3, "max_talents": 3, "stats": { "pierce": [3, 5], "multishot": [3, 5], "damage": [88, 155], "ricochet": [1, 3], "range": [58, 95] } },
		{ "id": "r8_brutal", "name": "Brutal", "rarity": 8, "min_stats": 5, "max_stats": 6, "min_talents": 3, "max_talents": 3, "stats": { "damage": [110, 185], "multishot": [3, 5], "pierce": [3, 5], "ricochet": [2, 3], "fire_rate": [45, 68], "bullet_speed": [52, 100] } },
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

## Affixes of a rarity that the loot roller may pick (themed only - legacy excluded).
static func rollable_of_rarity(rarity: int) -> Array:
	var out: Array = []
	for a in all():
		if a["rarity"] == rarity and not a.get("legacy", false):
			out.append(a)
	return out

static func is_flat(stat_id: String) -> bool:
	return FLAT_STATS.has(stat_id)

## Convert a stored 0..1 roll into the real value for a stat on this affix.
##   range [14,23], roll 0.5 -> 18.5 (a +18.5% or +N stat)
static func resolve(affix: Dictionary, stat_id: String, roll: float) -> float:
	var r: Array = affix.get("stats", {}).get(stat_id, [0, 0])
	return r[0] + (r[1] - r[0]) * roll

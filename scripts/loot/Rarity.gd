class_name Rarity
## Rarity tiers for the weapon-loot system. Pure data + the roll algorithm — no node
## or state (mirrors Weapons / Characters / XpCurve). A weapon's affix carries a rarity
## id; this maps it to a name, name colour, and a coin payout range for deconstructing.

## id -> tier. `weight` drives the factorial-decay roll; higher tiers are exponentially
## rarer with zero weight tables to maintain. `scrap` is the deconstruct coin range.
const TIERS := [
	{ "id": 1, "name": "Rusted",    "weight": 1,   "scrap": [10, 20],      "color": Color("6e6e6e") },
	{ "id": 2, "name": "Salvaged",  "weight": 2,   "scrap": [20, 40],      "color": Color("d6d6d6") },
	{ "id": 3, "name": "Hardened",  "weight": 3,   "scrap": [60, 120],     "color": Color("2ecc40") },
	{ "id": 4, "name": "Lethal",    "weight": 4,   "scrap": [120, 240],    "color": Color("2f7bff") },
	{ "id": 5, "name": "Savage",    "weight": 5,   "scrap": [300, 600],    "color": Color("a64bff") },
	{ "id": 6, "name": "Merciless", "weight": 6,   "scrap": [800, 1500],   "color": Color("ff7a18") },
	{ "id": 7, "name": "Carnage",   "weight": 7,   "scrap": [2000, 4000],  "color": Color("ff2d2d") },
	{ "id": 8, "name": "Apocalypse","weight": 8,   "scrap": [5000, 10000], "color": Color("00ffff") },
]

const MAX_ID := 8

## Returns the tier dict for a rarity id (clamped to valid range).
static func tier(id: int) -> Dictionary:
	return TIERS[clampi(id, 1, MAX_ID) - 1]

static func tier_name(id: int) -> String:
	return tier(id).name

static func color(id: int) -> Color:
	return tier(id).color

## Factorial-decay ladder. Start at `floor_id`, try to climb each step; the chance to
## climb from tier i is 1/(i+1). Cascaded from floor 1 this yields roughly:
## Worn ~50%, Standard ~33%, Specialized ~12.5%, Superior ~3.3%, High-End ~0.7%, etc.
## Raise `floor_id` for better sources (a premium crate floors higher).
static func roll(floor_id: int = 1, ceil_id: int = MAX_ID) -> int:
	floor_id = clampi(floor_id, 1, MAX_ID)
	ceil_id = clampi(ceil_id, floor_id, MAX_ID)
	var chosen := floor_id
	for i in range(floor_id, ceil_id):
		var next_weight: int = TIERS[i].weight    # TIERS is 0-indexed; TIERS[i] is tier id i+1
		if randi_range(1, next_weight) != next_weight:
			return chosen
		chosen = TIERS[i].id
	return chosen

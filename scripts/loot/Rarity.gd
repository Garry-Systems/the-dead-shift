class_name Rarity
## Rarity tiers for the weapon-loot system. Pure data + the roll algorithm — no node
## or state (mirrors Weapons / Characters / XpCurve). A weapon's affix carries a rarity
## id; this maps it to a name, name colour, and a coin payout range for deconstructing.

## id -> tier. `weight` drives the factorial-decay roll; higher tiers are exponentially
## rarer with zero weight tables to maintain. `scrap` is the deconstruct coin range.
## `talents` = the FIXED number of talent slots a weapon of this rarity always rolls
## (Larry — "set talents amount per rarity"; Orange/Red 3, Apocalypse locked at 4). Slot i
## pulls a random talent of tier min(i+1, Talents.MAX_TIER) with NO duplicates, so the first
## three slots are one talent of each tier and any extra slot (Apocalypse's 4th) adds another
## top-tier talent. WHICH talents fill the slots is RNG; only the COUNT is locked. Supersedes
## the per-affix min/max_talents (now unused).
const TIERS := [
	{ "id": 1, "name": "Rusted",    "weight": 1,   "scrap": [10, 20],      "color": Color("6e6e6e"), "talents": 0 },
	{ "id": 2, "name": "Salvaged",  "weight": 2,   "scrap": [20, 40],      "color": Color("d6d6d6"), "talents": 0 },
	{ "id": 3, "name": "Hardened",  "weight": 3,   "scrap": [60, 120],     "color": Color("2ecc40"), "talents": 1 },
	{ "id": 4, "name": "Lethal",    "weight": 4,   "scrap": [120, 240],    "color": Color("2f7bff"), "talents": 1 },
	{ "id": 5, "name": "Savage",    "weight": 5,   "scrap": [300, 600],    "color": Color("a64bff"), "talents": 2 },
	{ "id": 6, "name": "Merciless", "weight": 6,   "scrap": [800, 1500],   "color": Color("ff7a18"), "talents": 3 },
	{ "id": 7, "name": "Carnage",   "weight": 7,   "scrap": [2000, 4000],  "color": Color("ff2d2d"), "talents": 3 },
	{ "id": 8, "name": "Apocalypse","weight": 8,   "scrap": [5000, 10000], "color": Color("00ffff"), "talents": 4 },
]

const MAX_ID := 8

## Returns the tier dict for a rarity id (clamped to valid range).
static func tier(id: int) -> Dictionary:
	return TIERS[clampi(id, 1, MAX_ID) - 1]

static func tier_name(id: int) -> String:
	return tier(id).name

static func color(id: int) -> Color:
	return tier(id).color

## The fixed number of talent slots a weapon of this rarity always rolls (see TIERS).
static func talent_count(id: int) -> int:
	return int(tier(id).get("talents", 0))

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

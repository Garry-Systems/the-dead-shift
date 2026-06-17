class_name Crates
## Crate definitions. A crate is just a coin price + the rarity band it rolls within.
## Opening one (Inventory.open_crate) spends coins and rolls a weapon instance via
## LootRoller. Pure data (mirrors Weapons.gd).

static func all() -> Array:
	return [
		{
			"id": "footlocker", "name": "Footlocker", "price": 150,
			"rarity_floor": 1, "rarity_ceil": 7,
			"desc": "Any gun, any rarity — a real gamble.",
		},
		{
			"id": "munitions_cache", "name": "Munitions Cache", "price": 600,
			"rarity_floor": 4, "rarity_ceil": 7,
			"desc": "Lethal and up — a real shot at Carnage.",
		},
		{
			"id": "precision_pack", "name": "Buckshot & Bolts", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 7, "bases": ["sniper", "shotgun"],
			"desc": "Snipers & shotguns. Any rarity up to Carnage.",
		},
		{
			"id": "auto_case", "name": "Full Auto Case", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 7, "bases": ["smg", "ak47"],
			"desc": "SMGs & AK-47s. Any rarity up to Carnage.",
		},
		{
			"id": "standard_arms", "name": "Standard Arms", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 7, "bases": ["pistol", "rifle", "minigun"],
			"desc": "Pistols, rifles & miniguns. Any rarity up to Carnage.",
		},
	]

static func get_crate(id: String) -> Dictionary:
	for c in all():
		if c["id"] == id:
			return c
	return {}

## Tile icon for a crate (per-crate art if present, else the shared placeholder).
static func icon(id: String) -> Texture2D:
	var path := "res://art/crates/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://art/crates/_crate.png")

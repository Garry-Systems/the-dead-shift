class_name Crates
## Crate definitions. A crate is just a coin price + the rarity band it rolls within.
## Opening one (Inventory.open_crate) spends coins and rolls a weapon instance via
## LootRoller. Pure data (mirrors Weapons.gd).

static func all() -> Array:
	return [
		{
			"id": "scrap_crate", "name": "Scrap Crate", "price": 75,
			"rarity_floor": 1, "rarity_ceil": 4,
			"desc": "Scavenged junk. Rusted to Lethal, nothing better.",
		},
		{
			"id": "footlocker", "name": "Footlocker", "price": 150,
			"rarity_floor": 1, "rarity_ceil": 8,
			"desc": "Any gun, any rarity — even a 1-in-40k Apocalypse.",
		},
		{
			"id": "munitions_cache", "name": "Munitions Cache", "price": 600,
			"rarity_floor": 4, "rarity_ceil": 8,
			"desc": "Lethal and up — a real shot at Carnage, a sliver at Apocalypse.",
		},
		{
			"id": "titan_crate", "name": "Titan Crate", "price": 2500,
			"rarity_floor": 5, "rarity_ceil": 8,
			"desc": "Savage and up. Real Merciless odds, a long shot at Apocalypse.",
		},
		{
			"id": "apex_crate", "name": "Apex Crate", "price": 9000,
			"rarity_floor": 6, "rarity_ceil": 8,
			"desc": "Merciless guaranteed. Strong Carnage odds, a sliver at Apocalypse.",
		},
		{
			"id": "apocalypse_crate", "name": "Apocalypse Crate", "price": 30000,
			"rarity_floor": 7, "rarity_ceil": 8,
			"desc": "Carnage guaranteed. The only real shot at an Apocalypse weapon.",
		},
		{
			"id": "precision_pack", "name": "Buckshot & Bolts", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 8, "bases": ["sniper", "shotgun"],
			"desc": "Snipers & shotguns. Any rarity up to Apocalypse.",
		},
		{
			"id": "auto_case", "name": "Full Auto Case", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 8, "bases": ["smg", "ak47"],
			"desc": "SMGs & AK-47s. Any rarity up to Apocalypse.",
		},
		{
			"id": "standard_arms", "name": "Standard Arms", "price": 500,
			"rarity_floor": 1, "rarity_ceil": 8, "bases": ["pistol", "rifle", "minigun"],
			"desc": "Pistols, rifles & miniguns. Any rarity up to Apocalypse.",
		},
		{
			"id": "fiftyfifty", "name": "50/50 Crate", "price": 400,
			"rarity_floor": 1, "rarity_ceil": 5, "special": "5050",
			"desc": "All or nothing: half Savage, half Rusted.",
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

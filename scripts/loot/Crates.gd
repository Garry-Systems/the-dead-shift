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
			"rarity_floor": 1, "rarity_ceil": 9,
			"desc": "Any gun, any rarity — even a 1-in-360k Armageddon.",
		},
		{
			"id": "munitions_cache", "name": "Munitions Cache", "price": 600,
			"rarity_floor": 4, "rarity_ceil": 9,
			"desc": "Lethal and up — a real shot at Merciless, a sliver at Armageddon.",
		},
		{
			"id": "titan_crate", "name": "Titan Crate", "price": 2500,
			"rarity_floor": 5, "rarity_ceil": 9,
			"desc": "Savage and up. Real Carnage odds, a long shot at Armageddon.",
		},
		{
			"id": "apex_crate", "name": "Apex Crate", "price": 9000,
			"rarity_floor": 6, "rarity_ceil": 9,
			"desc": "Carnage guaranteed. Strong Merciless odds, a sliver at Armageddon.",
		},
		{
			"id": "apocalypse_crate", "name": "Apocalypse Crate", "price": 30000,
			"rarity_floor": 7, "rarity_ceil": 9,
			"desc": "Merciless guaranteed. The only real shot at an Armageddon weapon.",
		},
		{
			"id": "precision_pack", "name": "Buckshot & Bolts", "price": 500,
			"rarity_floor": 2, "rarity_ceil": 9, "bases": ["sniper", "shotgun", "auto_shotgun", "slug_gun", "railgun", "anti_materiel"],
			"desc": "Snipers & shotguns. Salvaged or better, up to Armageddon.",
		},
		{
			"id": "auto_case", "name": "Full Auto Case", "price": 500,
			"rarity_floor": 2, "rarity_ceil": 9, "bases": ["smg", "ak47", "nailgun", "pdw", "machine_pistol", "lmg"],
			"desc": "SMGs & AK-47s. Salvaged or better, up to Armageddon.",
		},
		{
			"id": "standard_arms", "name": "Standard Arms", "price": 500,
			"rarity_floor": 2, "rarity_ceil": 9, "bases": ["pistol", "rifle", "minigun", "magnum", "battle_rifle", "grenade_launcher"],
			"desc": "Pistols, rifles & miniguns. Salvaged or better, up to Armageddon.",
		},
		{
			"id": "specials_case", "name": "Specials Case", "price": 650,
			"rarity_floor": 2, "rarity_ceil": 9, "bases": ["tesla", "flamethrower", "acid_cannon"],
			"desc": "Weird science: Tesla, flame & acid. Salvaged or better, up to Armageddon.",
		},
		{
			"id": "fiftyfifty", "name": "50/50 Crate", "price": 700,
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

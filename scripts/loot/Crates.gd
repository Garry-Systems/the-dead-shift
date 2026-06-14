class_name Crates
## Crate definitions. A crate is just a coin price + the rarity band it rolls within.
## Opening one (Inventory.open_crate) spends coins and rolls a weapon instance via
## LootRoller. Pure data (mirrors Weapons.gd).

static func all() -> Array:
	return [
		{
			"id": "footlocker", "name": "Footlocker", "price": 150,
			"rarity_floor": 1, "rarity_ceil": 4,
			"desc": "Rusted to Lethal. Scrounged gear.",
		},
		{
			"id": "munitions_cache", "name": "Munitions Cache", "price": 600,
			"rarity_floor": 3, "rarity_ceil": 7,
			"desc": "Hardened and up — a shot at Carnage.",
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

class_name Weapons
## The weapon roster. Each weapon is a dictionary of base stats plus a "talents" list
## of card ids that form its flat upgrade pool (drawn at even levels). The Gun loads
## one via Gun.configure(); Upgrades resolves the talent ids into cards.

static func all() -> Array:
	return [
		{
			"id": "pistol", "name": "Pistol", "desc": "Balanced all-rounder",
			"damage": 25.0, "fire_interval": 0.20, "bullet_speed": 800.0,
			"range": 600.0, "projectiles": 1, "spread": 0.0,
			"talents": ["damage", "fire_rate", "range", "bullet_speed", "ricochet", "pierce"],
		},
		{
			"id": "smg", "name": "SMG", "desc": "Very fast, weak, slight spray",
			"damage": 12.0, "fire_interval": 0.08, "bullet_speed": 850.0,
			"range": 550.0, "projectiles": 1, "spread": 0.06,
			"talents": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce"],
		},
		{
			"id": "shotgun", "name": "Shotgun", "desc": "5-pellet spread, brutal up close",
			"damage": 15.0, "fire_interval": 0.65, "bullet_speed": 750.0,
			"range": 380.0, "projectiles": 5, "spread": 0.45,
			"talents": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary"],
		},
		{
			"id": "rifle", "name": "Rifle", "desc": "Slow, huge damage, long range",
			"damage": 70.0, "fire_interval": 0.55, "bullet_speed": 1100.0,
			"range": 900.0, "projectiles": 1, "spread": 0.0,
			"talents": ["damage", "fire_rate", "range", "pierce", "ricochet", "incendiary"],
		},
		{
			"id": "minigun", "name": "Minigun", "desc": "Fastest fire, tiny damage, sprays",
			"damage": 8.0, "fire_interval": 0.05, "bullet_speed": 820.0,
			"range": 520.0, "projectiles": 1, "spread": 0.14,
			"talents": ["damage", "fire_rate", "choke", "bullet_speed", "incendiary", "ricochet"],
		},
	]

## The talent id-list for a given weapon id (empty if unknown).
static func talents_for(id: String) -> Array:
	for def in all():
		if def["id"] == id:
			return def["talents"]
	return []

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
			"mag_size": 12, "reload_time": 1.1,
			"talents": ["damage", "fire_rate", "range", "bullet_speed", "ricochet", "pierce", "reload", "mag"],
		},
		{
			"id": "smg", "name": "SMG", "desc": "Very fast, weak, slight spray",
			"damage": 12.0, "fire_interval": 0.08, "bullet_speed": 850.0,
			"range": 550.0, "projectiles": 1, "spread": 0.06,
			"mag_size": 30, "reload_time": 1.6,
			"talents": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
		},
		{
			"id": "shotgun", "name": "Shotgun", "desc": "5-pellet spread, brutal up close",
			"damage": 15.0, "fire_interval": 0.65, "bullet_speed": 750.0,
			"range": 380.0, "projectiles": 5, "spread": 0.45,
			"mag_size": 6, "reload_time": 2.0,
			"talents": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "rifle", "name": "Rifle", "desc": "Slow, huge damage, long range",
			"damage": 70.0, "fire_interval": 0.55, "bullet_speed": 1100.0,
			"range": 900.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 8, "reload_time": 1.8,
			"talents": ["damage", "fire_rate", "range", "pierce", "ricochet", "incendiary", "reload", "mag"],
		},
		{
			"id": "minigun", "name": "Minigun", "desc": "Fastest fire, tiny damage, sprays",
			"damage": 8.0, "fire_interval": 0.05, "bullet_speed": 820.0,
			"range": 520.0, "projectiles": 1, "spread": 0.14,
			"mag_size": 150, "reload_time": 3.0,
			"talents": ["damage", "fire_rate", "choke", "bullet_speed", "incendiary", "ricochet", "reload", "mag"],
		},
		{
			"id": "ak47", "name": "AK-47", "desc": "Assault rifle — fast, punchy, slight kick",
			"damage": 22.0, "fire_interval": 0.12, "bullet_speed": 900.0,
			"range": 650.0, "projectiles": 1, "spread": 0.04,
			"mag_size": 30, "reload_time": 1.7,
			"talents": ["damage", "fire_rate", "range", "bullet_speed", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "sniper", "name": "Sniper", "desc": "Bolt-action — devastating, slow, extreme range",
			"damage": 120.0, "fire_interval": 0.90, "bullet_speed": 1500.0,
			"range": 1200.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 5, "reload_time": 2.2,
			"talents": ["damage", "fire_rate", "range", "pierce", "ricochet", "incendiary", "reload", "mag"],
		},
	]

## The talent id-list for a given weapon id (empty if unknown).
static func talents_for(id: String) -> Array:
	for def in all():
		if def["id"] == id:
			return def["talents"]
	return []

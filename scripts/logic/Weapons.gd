class_name Weapons
## The weapon roster. Each weapon is a dictionary of base stats. The Gun loads one
## of these via Gun.configure(). Phase 3 step 2 adds per-weapon talent trees.

static func all() -> Array:
	return [
		{
			"id": "pistol", "name": "Pistol", "desc": "Balanced all-rounder",
			"damage": 25.0, "fire_interval": 0.20, "bullet_speed": 800.0,
			"range": 600.0, "projectiles": 1, "spread": 0.0,
		},
		{
			"id": "smg", "name": "SMG", "desc": "Very fast, weak, slight spray",
			"damage": 12.0, "fire_interval": 0.08, "bullet_speed": 850.0,
			"range": 550.0, "projectiles": 1, "spread": 0.06,
		},
		{
			"id": "shotgun", "name": "Shotgun", "desc": "5-pellet spread, brutal up close",
			"damage": 15.0, "fire_interval": 0.65, "bullet_speed": 750.0,
			"range": 380.0, "projectiles": 5, "spread": 0.45,
		},
		{
			"id": "rifle", "name": "Rifle", "desc": "Slow, huge damage, long range",
			"damage": 70.0, "fire_interval": 0.55, "bullet_speed": 1100.0,
			"range": 900.0, "projectiles": 1, "spread": 0.0,
		},
		{
			"id": "minigun", "name": "Minigun", "desc": "Fastest fire, tiny damage, sprays",
			"damage": 8.0, "fire_interval": 0.05, "bullet_speed": 820.0,
			"range": 520.0, "projectiles": 1, "spread": 0.14,
		},
	]

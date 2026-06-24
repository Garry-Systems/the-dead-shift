class_name Weapons
## The weapon roster. Each weapon is a dictionary of base stats plus an "upgrades" list
## of card ids that form its flat upgrade pool (drawn at even levels). The Gun loads
## one via Gun.configure(); Upgrades resolves the upgrade ids into cards.
## (Distinct from loot "talents" — the rolled combat procs in scripts/loot/.)

static func all() -> Array:
	return [
		{
			"id": "pistol", "name": "Pistol", "desc": "Balanced all-rounder", "category": "Pistol",
			"damage": 25.0, "fire_interval": 0.20, "bullet_speed": 800.0,
			"range": 600.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 12, "reload_time": 1.1,
			"upgrades": ["damage", "fire_rate", "range", "bullet_speed", "ricochet", "pierce", "reload", "mag"],
		},
		{
			"id": "smg", "name": "SMG", "desc": "Very fast, weak, slight spray", "category": "SMG",
			"damage": 12.0, "fire_interval": 0.08, "bullet_speed": 850.0,
			"range": 550.0, "projectiles": 1, "spread": 0.06,
			"mag_size": 30, "reload_time": 1.6,
			"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
		},
		{
			"id": "shotgun", "name": "Shotgun", "desc": "5-pellet spread, brutal up close", "category": "Shotgun",
			"damage": 15.0, "fire_interval": 0.65, "bullet_speed": 750.0,
			"range": 380.0, "projectiles": 5, "spread": 0.45,
			"mag_size": 6, "reload_time": 2.0,
			"upgrades": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "rifle", "name": "Rifle", "desc": "Slow, huge damage, long range", "category": "Rifle",
			"damage": 70.0, "fire_interval": 0.55, "bullet_speed": 1100.0,
			"range": 900.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 8, "reload_time": 1.8,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "ricochet", "incendiary", "reload", "mag"],
		},
		{
			"id": "minigun", "name": "Minigun", "desc": "Fastest fire, tiny damage, sprays", "category": "Heavy",
			"damage": 8.0, "fire_interval": 0.05, "bullet_speed": 820.0,
			"range": 520.0, "projectiles": 1, "spread": 0.14,
			"mag_size": 150, "reload_time": 3.0,
			"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "incendiary", "ricochet", "reload", "mag"],
		},
		{
			"id": "ak47", "name": "AK-47", "desc": "Assault rifle — fast, punchy, slight kick", "category": "Rifle",
			"damage": 22.0, "fire_interval": 0.12, "bullet_speed": 900.0,
			"range": 650.0, "projectiles": 1, "spread": 0.04,
			"mag_size": 30, "reload_time": 1.7,
			"upgrades": ["damage", "fire_rate", "range", "bullet_speed", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "sniper", "name": "Sniper", "desc": "Bolt-action — devastating, slow, extreme range", "category": "Sniper",
			"damage": 120.0, "fire_interval": 0.90, "bullet_speed": 1500.0,
			"range": 1200.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 5, "reload_time": 2.2,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "ricochet", "incendiary", "reload", "mag"],
		},
		{
			"id": "nailgun", "name": "Nail Gun", "desc": "Hardware-aisle rapid-fire — cheap, pierces", "category": "SMG",
			"fire_mode": "projectile", "base_pierce": 1,
			"damage": 9.0, "fire_interval": 0.07, "bullet_speed": 950.0,
			"range": 500.0, "projectiles": 1, "spread": 0.05,
			"mag_size": 25, "reload_time": 1.3,
			"upgrades": ["damage", "fire_rate", "pierce", "bullet_speed", "choke", "ricochet", "reload", "mag"],
		},
		{
			"id": "tesla", "name": "Tesla Gun", "desc": "Arc lightning — chains through the horde", "category": "Special",
			"fire_mode": "lightning", "jump_count": 4, "jump_radius": 320.0, "jump_falloff": 0.8,
			"damage": 30.0, "fire_interval": 0.35, "bullet_speed": 0.0,
			"range": 600.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 20, "reload_time": 1.8,
			"upgrades": ["damage", "fire_rate", "range", "projectile", "incendiary", "reload", "mag"],
		},
		{
			"id": "flamethrower", "name": "Flamethrower", "desc": "Fuel-hose cone — always burns", "category": "Special",
			"fire_mode": "cone", "cone_angle": 1.05,
			"damage": 6.0, "fire_interval": 0.05, "bullet_speed": 0.0,
			"range": 280.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 100, "reload_time": 2.5,
			"upgrades": ["damage", "fire_rate", "range", "incendiary", "reload", "mag"],
		},
		{
			"id": "magnum", "name": "Magnum", "desc": "Hand cannon — slow, brutal, punches through", "category": "Pistol",
			"fire_mode": "projectile", "base_pierce": 1,
			"damage": 55.0, "fire_interval": 0.45, "bullet_speed": 950.0,
			"range": 700.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 6, "reload_time": 1.4,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
		},
		{
			"id": "machine_pistol", "name": "Machine Pistol", "desc": "Full-auto sidearm — spray it", "category": "Pistol",
			"damage": 14.0, "fire_interval": 0.09, "bullet_speed": 850.0,
			"range": 480.0, "projectiles": 1, "spread": 0.10,
			"mag_size": 18, "reload_time": 1.2,
			"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
		},
		{
			"id": "pdw", "name": "PDW", "desc": "Compact PDW — blistering fire rate, deep mag", "category": "SMG",
			"damage": 10.0, "fire_interval": 0.06, "bullet_speed": 900.0,
			"range": 500.0, "projectiles": 1, "spread": 0.07,
			"mag_size": 40, "reload_time": 1.5,
			"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
		},
		{
			"id": "auto_shotgun", "name": "Auto Shotgun", "desc": "Semi-auto — keeps the lead coming", "category": "Shotgun",
			"damage": 12.0, "fire_interval": 0.30, "bullet_speed": 800.0,
			"range": 360.0, "projectiles": 4, "spread": 0.40,
			"mag_size": 8, "reload_time": 1.9,
			"upgrades": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "slug_gun", "name": "Slug Gun", "desc": "Solid slug — a shotgun that reaches out and pierces", "category": "Shotgun",
			"fire_mode": "projectile", "base_pierce": 2,
			"damage": 60.0, "fire_interval": 0.70, "bullet_speed": 1000.0,
			"range": 650.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 5, "reload_time": 2.0,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
		},
		{
			"id": "battle_rifle", "name": "Battle Rifle", "desc": "Marksman DMR — fast, accurate, hits hard", "category": "Rifle",
			"damage": 45.0, "fire_interval": 0.28, "bullet_speed": 1200.0,
			"range": 850.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 12, "reload_time": 1.7,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
		},
		{
			"id": "railgun", "name": "Railgun", "desc": "Magnetic rail — instant beam, pierces everything in line", "category": "Sniper",
			"fire_mode": "beam", "beam_width": 28.0,
			"damage": 90.0, "fire_interval": 0.85, "bullet_speed": 0.0,
			"range": 1100.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 5, "reload_time": 2.2,
			"upgrades": ["damage", "fire_rate", "range", "incendiary", "reload", "mag"],
		},
		{
			"id": "anti_materiel", "name": "Anti-Materiel Rifle", "desc": ".50 cal — devastating, line-piercing, painfully slow", "category": "Sniper",
			"fire_mode": "projectile", "base_pierce": 3,
			"damage": 160.0, "fire_interval": 1.10, "bullet_speed": 1600.0,
			"range": 1300.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 4, "reload_time": 2.6,
			"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
		},
		{
			"id": "grenade_launcher", "name": "Grenade Launcher", "desc": "Lobbed shells detonate in a crowd-clearing blast", "category": "Heavy",
			"fire_mode": "projectile", "explode_radius": 130.0, "explode_force": 600.0,
			"damage": 50.0, "fire_interval": 0.80, "bullet_speed": 650.0,
			"range": 600.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 6, "reload_time": 2.2,
			"upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
		},
		{
			"id": "lmg", "name": "LMG", "desc": "Belt-fed — more punch than the minigun, less spray", "category": "Heavy",
			"damage": 16.0, "fire_interval": 0.07, "bullet_speed": 880.0,
			"range": 600.0, "projectiles": 1, "spread": 0.09,
			"mag_size": 100, "reload_time": 3.2,
			"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "pierce", "incendiary", "reload", "mag"],
		},
		{
			"id": "acid_cannon", "name": "Acid Cannon", "desc": "Caustic shells leave a melting acid pool — area denial", "category": "Special",
			"fire_mode": "projectile", "pool": "acid",
			"pool_radius": 90.0, "pool_duration": 3.5, "pool_slow": 0.4, "pool_slow_dur": 1.0,
			"damage": 35.0, "fire_interval": 0.55, "bullet_speed": 700.0,
			"range": 520.0, "projectiles": 1, "spread": 0.0,
			"mag_size": 10, "reload_time": 2.0,
			"upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
		},
	]

## The upgrade-card id-list for a given weapon id (empty if unknown).
static func upgrades_for(id: String) -> Array:
	for def in all():
		if def["id"] == id:
			return def["upgrades"]
	return []

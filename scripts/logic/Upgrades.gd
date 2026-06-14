class_name Upgrades
## Defines the upgrade-card pools and applies a chosen card to the player.
## Level-ups alternate: odd levels draw player-stat cards, even levels draw gun cards.

## Player-stat cards. Each card is a dictionary {id, title, desc}.
static func player_cards() -> Array:
	return [
		{"id": "move_speed", "title": "Swift Feet", "desc": "+10% Move Speed"},
		{"id": "max_health", "title": "Tough Hide", "desc": "+20 Max Health"},
		{"id": "regen", "title": "Regeneration", "desc": "+1 Health / sec"},
		{"id": "pickup", "title": "Magnet", "desc": "+25% Pickup Radius"},
	]

## The full library of gun upgrade cards, keyed by id. Each weapon's "upgrades" list
## (in Weapons.gd) selects a subset of these into its flat per-weapon pool.
static func gun_card(id: String) -> Dictionary:
	match id:
		"damage":
			return {"id": "damage", "title": "Hollow Points", "desc": "+20% Damage"}
		"fire_rate":
			return {"id": "fire_rate", "title": "Hair Trigger", "desc": "+15% Fire Rate"}
		"bullet_speed":
			return {"id": "bullet_speed", "title": "Overpressure", "desc": "+15% Bullet Speed"}
		"range":
			return {"id": "range", "title": "Long Barrel", "desc": "+15% Range"}
		"projectile":
			return {"id": "projectile", "title": "Extra Barrel", "desc": "+1 Projectile"}
		"choke":
			return {"id": "choke", "title": "Tighter Choke", "desc": "-30% Spread"}
		"pierce":
			return {"id": "pierce", "title": "Armor Piercing", "desc": "Bullets pierce +1 enemy"}
		"ricochet":
			return {"id": "ricochet", "title": "Ricochet", "desc": "Bullets bounce to +1 enemy"}
		"incendiary":
			return {"id": "incendiary", "title": "Incendiary Rounds", "desc": "Hits set enemies on fire"}
		"reload":
			return {"id": "reload", "title": "Fast Hands", "desc": "-20% Reload Time"}
		"mag":
			return {"id": "mag", "title": "Extended Mag", "desc": "+50% Magazine"}
	return {"id": id, "title": id, "desc": ""}

## The equipped weapon's upgrade-card pool, resolved from its upgrade ids into cards.
static func gun_cards(player: Player) -> Array:
	var cards: Array = []
	if player and player.gun:
		for id in Weapons.upgrades_for(player.gun.weapon_id):
			cards.append(gun_card(id))
	return cards

## Returns the right pool for a given level (odd = player stats, even = equipped gun).
static func cards_for_level(level: int, player: Player) -> Array:
	return player_cards() if level % 2 == 1 else gun_cards(player)

## Human label for the level's upgrade type (used in the screen title).
static func label_for_level(level: int) -> String:
	return "stat" if level % 2 == 1 else "weapon"

## Applies a card (by id) to the player or its gun.
static func apply(player: Player, id: String) -> void:
	match id:
		"move_speed":
			player.upgrade_move_speed(0.10)
		"max_health":
			player.upgrade_max_health(20.0)
		"regen":
			player.upgrade_regen(1.0)
		"pickup":
			player.upgrade_pickup_radius(0.25)
		"damage":
			player.gun.upgrade_damage(GameConfig.UPGRADE_DAMAGE_PCT)
		"fire_rate":
			player.gun.upgrade_fire_rate(GameConfig.UPGRADE_FIRE_RATE_PCT)
		"bullet_speed":
			player.gun.upgrade_bullet_speed(GameConfig.UPGRADE_BULLET_SPEED_PCT)
		"range":
			player.gun.upgrade_range(GameConfig.UPGRADE_RANGE_PCT)
		"projectile":
			player.gun.upgrade_add_projectile(1)
		"choke":
			player.gun.upgrade_reduce_spread(GameConfig.UPGRADE_CHOKE_PCT)
		"pierce":
			player.gun.upgrade_pierce(1)
		"ricochet":
			player.gun.upgrade_ricochet(1)
		"incendiary":
			player.gun.upgrade_incendiary(GameConfig.UPGRADE_BURN_DPS, GameConfig.UPGRADE_BURN_DURATION)
		"reload":
			player.gun.upgrade_reload_speed(GameConfig.UPGRADE_RELOAD_PCT)
		"mag":
			player.gun.upgrade_mag_size(GameConfig.UPGRADE_MAG_PCT)

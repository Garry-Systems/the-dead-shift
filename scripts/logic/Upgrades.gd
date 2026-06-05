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

## Gun cards. Improve the currently equipped weapon.
static func gun_cards() -> Array:
	return [
		{"id": "damage", "title": "Hollow Points", "desc": "+20% Damage"},
		{"id": "fire_rate", "title": "Hair Trigger", "desc": "+15% Fire Rate"},
		{"id": "bullet_speed", "title": "Overpressure", "desc": "+15% Bullet Speed"},
		{"id": "range", "title": "Long Barrel", "desc": "+15% Range"},
	]

## Returns the right pool for a given level (odd = stats, even = gun).
static func cards_for_level(level: int) -> Array:
	return player_cards() if level % 2 == 1 else gun_cards()

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
			player.gun.upgrade_damage(0.20)
		"fire_rate":
			player.gun.upgrade_fire_rate(0.15)
		"bullet_speed":
			player.gun.upgrade_bullet_speed(0.15)
		"range":
			player.gun.upgrade_range(0.15)

class_name Upgrades
## Defines the upgrade-card pools and applies a chosen card to the player.
## Step 2 ships the player-stat pool; Step 3 adds the gun pool + alternation.

## Player-stat cards. Each card is a dictionary {id, title, desc}.
static func player_cards() -> Array:
	return [
		{"id": "move_speed", "title": "Swift Feet", "desc": "+10% Move Speed"},
		{"id": "max_health", "title": "Tough Hide", "desc": "+20 Max Health"},
		{"id": "regen", "title": "Regeneration", "desc": "+1 Health / sec"},
		{"id": "pickup", "title": "Magnet", "desc": "+25% Pickup Radius"},
	]

## Applies a card (by id) to the player.
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

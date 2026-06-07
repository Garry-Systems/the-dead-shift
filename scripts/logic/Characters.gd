class_name Characters
## The playable-character roster. Characters are passive: always-on perks plus perks
## that only apply when wielding a specific weapon. All applied through the existing
## Player/Gun upgrade hooks. The double-tap Dash is universal (not part of this data).

static func all() -> Array:
	return [
		{
			"id": "ryan", "name": "Ryan Ace",
			"desc": "Starts with 150 HP. Bonus damage & fire rate with the AK-47.",
		},
		{
			"id": "jimbo", "name": "Jimbo James",
			"desc": "+50% move speed. Bonus damage & fire rate with snipers.",
		},
		{
			"id": "bob", "name": "Zombie Bob",
			"desc": "+25% XP pickup radius (magnet).",
		},
	]

static func get_character(id: String) -> Dictionary:
	for c in all():
		if c["id"] == id:
			return c
	return {}

## Always-on perks — applied at run start (Main.gd), before the weapon pick.
static func apply_base(player: Player, id: String) -> void:
	if player == null:
		return
	match id:
		"ryan":
			player.upgrade_max_health(GameConfig.CHAR_RYAN_HP_BONUS)
		"jimbo":
			player.upgrade_move_speed(GameConfig.CHAR_JIMBO_SPEED_PCT)
		"bob":
			player.upgrade_pickup_radius(GameConfig.CHAR_BOB_MAGNET_PCT)

## Weapon-conditional perks — applied after the gun is configured (StartUI), and only
## if the equipped weapon matches.
static func apply_weapon(player: Player, id: String) -> void:
	if player == null or player.gun == null:
		return
	var weapon_id: String = player.gun.weapon_id
	match id:
		"ryan":
			if weapon_id == "ak47":
				player.gun.upgrade_damage(GameConfig.CHAR_RYAN_AK_DMG_PCT)
				player.gun.upgrade_fire_rate(GameConfig.CHAR_RYAN_AK_FIRE_PCT)
		"jimbo":
			if weapon_id == "sniper":
				player.gun.upgrade_damage(GameConfig.CHAR_JIMBO_SNIPER_DMG_PCT)
				player.gun.upgrade_fire_rate(GameConfig.CHAR_JIMBO_SNIPER_FIRE_PCT)
				player.gun.upgrade_reload_speed(GameConfig.CHAR_JIMBO_SNIPER_RELOAD_PCT)
		"bob":
			pass

class_name Characters
## The playable-character roster. Characters are passive: always-on perks plus perks
## that only apply when wielding a specific weapon. All applied through the existing
## Player/Gun upgrade hooks. The double-tap Dash is universal (not part of this data).

static func all() -> Array:
	return [
		{
			"id": "ryan", "name": "Ryan Ace", "price": 0,
			"desc": "Starts with 150 HP. Bonus damage & fire rate with the AK-47. DASH wipes every enemy projectile off the map — and instantly reloads an equipped AK.",
		},
		{
			"id": "jimbo", "name": "Jimbo James", "price": 600,
			"desc": "+50% move speed. Bonus damage & fire rate with snipers.",
		},
		{
			"id": "bob", "name": "Zombie Bob", "price": 400,
			"desc": "+25% XP pickup radius (magnet).",
		},
		{
			"id": "alstar", "name": "Alstar Tuck", "price": 2400,
			"desc": "Double-tap DASH unleashes a shockwave: knocks back & damages nearby enemies and hits them with your gun's talents. +30% fire rate with Savage (purple) guns or better.",
		},
	]

static func get_character(id: String) -> Dictionary:
	for c in all():
		if c["id"] == id:
			return c
	return {}

## Coin price to unlock this character (0 = free starter).
static func price(id: String) -> int:
	return int(get_character(id).get("price", 0))

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
		"alstar":
			pass   # no always-on stat — his kit is the shockwave dash + the purple-gun fire-rate perk

## Weapon-conditional perks — applied after the gun is configured (Main.gd), and only
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
		"alstar":
			# +fire rate whenever the equipped gun is purple (Savage) or better.
			if player.gun.loot_rarity >= GameConfig.CHAR_ALSTAR_PURPLE_MIN_RARITY:
				player.gun.upgrade_fire_rate(GameConfig.CHAR_ALSTAR_PURPLE_FIRE_PCT)

## The special double-tap dash ability for a character, or "" for the plain dash. Read by
## the Player at run start (via Main) to decide what a dash does beyond the movement.
static func dash_ability(id: String) -> String:
	match id:
		"ryan":
			return "purge"        # clear every enemy projectile (+ instant AK reload)
		"alstar":
			return "shockwave"
		_:
			return ""

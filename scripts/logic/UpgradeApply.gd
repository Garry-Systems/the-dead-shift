class_name UpgradeApply
## Applies a chosen upgrade card (by id) to the player, its gun, or (coin_gain) RunStats.
## Split out of Upgrades.gd on purpose: this is the one file allowed to touch autoloads
## (RunStats) — see the header comment on Upgrades.gd for why the card catalog itself
## stays autoload-free.
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
		"armor":
			player.upgrade_armor(GameConfig.UPGRADE_ARMOR_PCT)
		"dodge":
			player.upgrade_dodge(GameConfig.UPGRADE_DODGE_PCT)
		"dash_cooldown":
			player.upgrade_dash_cooldown(GameConfig.UPGRADE_DASH_CD_PCT)
		"xp_gain":
			player.upgrade_xp_gain(GameConfig.UPGRADE_XP_PCT)
		"coin_gain":
			RunStats.add_coin_mult(GameConfig.UPGRADE_COIN_PCT)
		"crit":
			player.gun.upgrade_crit(GameConfig.UPGRADE_CRIT_CHANCE_PCT, GameConfig.UPGRADE_CRIT_MULT_BONUS)
		"thorns":
			player.upgrade_thorns(GameConfig.UPGRADE_THORNS_MULT)
		"second_wind":
			player.upgrade_second_wind()
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

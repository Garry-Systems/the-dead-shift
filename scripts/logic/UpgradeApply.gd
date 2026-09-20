class_name UpgradeApply
## Applies a ROLLED upgrade card (CardRolls.roll output: id + value/amount) to the player, its gun,
## or (coin_gain) RunStats. Split out of Upgrades.gd on purpose: this is the one file allowed to
## touch autoloads (RunStats) — see the header comment on Upgrades.gd for why the card catalog
## itself stays autoload-free.
static func apply(player: Player, card: Dictionary) -> void:
	var v := float(card.get("value", 0.0))
	var n := int(card.get("amount", 0))
	match String(card["id"]):
		"move_speed":    player.upgrade_move_speed(v)
		"max_health":    player.upgrade_max_health(v)
		"regen":         player.upgrade_regen(v)
		"pickup":        player.upgrade_pickup_radius(v)
		"armor":         player.upgrade_armor(v)
		"dodge":         player.upgrade_dodge(v)
		"dash_cooldown": player.upgrade_dash_cooldown(v)
		"xp_gain":       player.upgrade_xp_gain(v)
		"coin_gain":     RunStats.add_coin_mult(v)
		"crit":          player.gun.upgrade_crit(v)
		"thorns":        player.upgrade_thorns(v)
		"second_wind":   player.upgrade_second_wind()
		"damage":        player.gun.upgrade_damage(v)
		"fire_rate":     player.gun.upgrade_fire_rate_card(v)
		"bullet_speed":  player.gun.upgrade_bullet_speed(v)
		"range":         player.gun.upgrade_range(v)
		"projectile":    player.gun.upgrade_add_barrel(n, v)
		"choke":         player.gun.upgrade_reduce_spread(v)
		"pierce":
			player.gun.upgrade_pierce(n)
			if v > 0.0: player.gun.upgrade_damage(v)
		"ricochet":
			player.gun.upgrade_ricochet(n)
			if v > 0.0: player.gun.upgrade_damage(v)
		"incendiary":    player.gun.upgrade_incendiary(v, GameConfig.UPGRADE_BURN_DURATION)
		"reload":        player.gun.upgrade_reload_speed(v)
		"mag":           player.gun.upgrade_mag_size(v)

class_name Upgrades
## Defines the upgrade-card pools (catalog only — see UpgradeApply.apply() for the
## dispatch that actually mutates the player/gun/RunStats). Level-ups alternate: odd
## levels draw player-stat cards, even levels draw gun cards.
##
## Kept free of autoload references (RunStats, SaveManager, ...) on purpose: a headless
## `--script` probe compiles this whole file as one unit to read the card catalog, and
## autoload singletons aren't registered yet in that harness — an autoload reference
## anywhere in this file would make EVERY function here fail to resolve ("Nonexistent
## function") even though only one card cares about RunStats. That one card's apply
## case lives in UpgradeApply.gd instead, which the probe never needs to touch.

## Player-stat cards. Each card is a dictionary {id, title, desc}. `player` (optional) gates
## Second Wind out of the pool once it's already been taken this run — see cards_for_level.
## `hardcore` (Pack G, v0.1.58) excludes it unconditionally for the whole run — passed in by the
## caller (LevelUpUI, via RunConfig.hardcore) rather than read here, since this file is
## deliberately kept free of autoload references (see the header comment).
static func player_cards(player: Player = null, hardcore: bool = false) -> Array:
	var cards: Array = [
		{"id": "move_speed", "title": "Swift Feet", "desc": "+10% Move Speed"},
		{"id": "max_health", "title": "Tough Hide", "desc": "+20 Max Health"},
		{"id": "regen", "title": "Regeneration", "desc": "+1 Health / sec"},
		{"id": "pickup", "title": "Magnet", "desc": "+25% Pickup Radius"},
		{"id": "armor", "title": "Iron Skin", "desc": "-%d%% Contact Damage Taken" % int(round(GameConfig.UPGRADE_ARMOR_PCT * 100.0))},
		{"id": "dodge", "title": "Quick Step", "desc": "+%d%% Dodge Chance (cap %d%%)" % [int(round(GameConfig.UPGRADE_DODGE_PCT * 100.0)), int(round(GameConfig.DODGE_CAP * 100.0))]},
		{"id": "dash_cooldown", "title": "Quick Reset", "desc": "-%d%% Dash Cooldown" % int(round(GameConfig.UPGRADE_DASH_CD_PCT * 100.0))},
		{"id": "xp_gain", "title": "Fast Learner", "desc": "+%d%% XP Gain" % int(round(GameConfig.UPGRADE_XP_PCT * 100.0))},
		{"id": "coin_gain", "title": "Silver Tongue", "desc": "+%d%% Coin Payout" % int(round(GameConfig.UPGRADE_COIN_PCT * 100.0))},
		{"id": "crit", "title": "Kill Shot", "desc": "+%d%% Crit Chance (2x Damage)" % int(round(GameConfig.UPGRADE_CRIT_CHANCE_PCT))},
		{"id": "thorns", "title": "Spike Armor", "desc": "Biters Take %dx Their Own Damage" % int(round(GameConfig.UPGRADE_THORNS_MULT))},
		{"id": "second_wind", "title": "Second Wind", "desc": "Cheat Death Once: Revive at %d%% HP" % int(round(GameConfig.SECOND_WIND_HP_FRAC * 100.0))},
	]
	# Excluded once TAKEN (not just once consumed) — a second pick would be a wasted no-op,
	# since has_second_wind is a flag, not a stacking counter. Also excluded for the entire run
	# under HARDCORE (Pack G): no cheat-death safety net.
	if (player != null and player.has_second_wind) or hardcore:
		cards = cards.filter(func(c): return String(c["id"]) != "second_wind")
	return cards

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
static func cards_for_level(level: int, player: Player, hardcore: bool = false) -> Array:
	return player_cards(player, hardcore) if level % 2 == 1 else gun_cards(player)

## Human label for the level's upgrade type (used in the screen title).
static func label_for_level(level: int) -> String:
	return "stat" if level % 2 == 1 else "weapon"

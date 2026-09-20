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
	# NOTE: these descs are never shown to the player — cards_for_level's output always runs
	# through CardRolls.roll (see LevelUpUI._pick_three), which overwrites "desc" with the rolled
	# tier's actual number, EXCEPT for "second_wind" (CardRolls.spec's only "fixed"-kind card,
	# which roll() never rewrites). Every desc that would otherwise show a hardcoded number is kept
	# number-free here so a stale one can never leak through; second_wind's is live (computed from
	# GameConfig.SECOND_WIND_HP_FRAC each call) so it stays accurate and is left as-is.
	var cards: Array = [
		{"id": "move_speed", "title": "Swift Feet", "desc": "Faster Move Speed"},
		{"id": "max_health", "title": "Tough Hide", "desc": "More Max Health"},
		{"id": "regen", "title": "Regeneration", "desc": "Heals Over Time"},
		{"id": "pickup", "title": "Magnet", "desc": "Bigger Pickup Radius"},
		{"id": "armor", "title": "Iron Skin", "desc": "Less Contact Damage Taken"},
		{"id": "dodge", "title": "Quick Step", "desc": "More Dodge Chance"},
		{"id": "dash_cooldown", "title": "Quick Reset", "desc": "Shorter Dash Cooldown"},
		{"id": "xp_gain", "title": "Fast Learner", "desc": "More XP Gain"},
		{"id": "coin_gain", "title": "Silver Tongue", "desc": "Bigger Coin Payout"},
		{"id": "crit", "title": "Kill Shot", "desc": "More Crit Chance"},
		{"id": "thorns", "title": "Spike Armor", "desc": "Biters Take Extra Damage"},
		{"id": "second_wind", "title": "Second Wind", "desc": "Cheat Death Once: Revive at %d%% HP" % int(round(GameConfig.SECOND_WIND_HP_FRAC * 100.0))},
	]
	# Excluded once TAKEN (not just once consumed) — a second pick would be a wasted no-op,
	# since has_second_wind is a flag, not a stacking counter. Also excluded for the entire run
	# under HARDCORE (Pack G): no cheat-death safety net.
	if (player != null and player.has_second_wind) or hardcore:
		cards = cards.filter(func(c): return String(c["id"]) != "second_wind")
	# HARDCORE also drops Regeneration (Pack G fix round): the regen tick routes through
	# Player.heal(), which no-ops under hardcore — offering the card would be a fully dead pick
	# (a player trap), same mechanism as the Second Wind exclusion above. The Field Kit relic
	# stays offerable by adjudication (gating boss-drop rerolls was accepted scope creep).
	if hardcore:
		cards = cards.filter(func(c): return String(c["id"]) != "regen")
	return cards

## The full library of gun upgrade cards, keyed by id. Each weapon's "upgrades" list
## (in Weapons.gd) selects a subset of these into its flat per-weapon pool.
## (See the NOTE on player_cards() above: these descs are dead — CardRolls.roll overwrites them
## with the rolled tier's real number for every kind it handles — so every one that would
## otherwise show a hardcoded number is number-free here. "pierce"/"ricochet"/"incendiary" are
## left as-is: no number that can go stale.)
static func gun_card(id: String) -> Dictionary:
	match id:
		"damage":
			return {"id": "damage", "title": "Hollow Points", "desc": "More Damage"}
		"fire_rate":
			return {"id": "fire_rate", "title": "Hair Trigger", "desc": "Faster Fire Rate"}
		"bullet_speed":
			return {"id": "bullet_speed", "title": "Overpressure", "desc": "Faster Bullet Speed"}
		"range":
			return {"id": "range", "title": "Long Barrel", "desc": "Longer Range"}
		"projectile":
			return {"id": "projectile", "title": "Extra Barrel", "desc": "Extra Projectile"}
		"choke":
			return {"id": "choke", "title": "Tighter Choke", "desc": "Tighter Spread"}
		"pierce":
			return {"id": "pierce", "title": "Armor Piercing", "desc": "Bullets pierce +1 enemy"}
		"ricochet":
			return {"id": "ricochet", "title": "Ricochet", "desc": "Bullets bounce to +1 enemy"}
		"incendiary":
			return {"id": "incendiary", "title": "Incendiary Rounds", "desc": "Hits set enemies on fire"}
		"reload":
			return {"id": "reload", "title": "Fast Hands", "desc": "Faster Reload"}
		"mag":
			return {"id": "mag", "title": "Extended Mag", "desc": "Bigger Magazine"}
	return {"id": id, "title": id, "desc": ""}

## The equipped weapon's upgrade-card pool, resolved from its upgrade ids into cards.
static func gun_cards(player: Player) -> Array:
	var cards: Array = []
	if player and player.gun:
		var lightning: bool = player.gun.fire_mode == "lightning"
		for id in Weapons.upgrades_for(player.gun.weapon_id):
			var card := gun_card(id)
			# Tesla "Extra Barrel" adds chain jumps at full strength, not a damage-shared pellet —
			# retitle + flag it so CardRolls.roll's "barrel" branch can describe it truthfully.
			if lightning and id == "projectile":
				card["title"] = "Extra Arc"
				card["lightning"] = true
			cards.append(card)
	return cards

## Returns the right pool for a given level (odd = player stats, even = equipped gun).
static func cards_for_level(level: int, player: Player, hardcore: bool = false) -> Array:
	return player_cards(player, hardcore) if level % 2 == 1 else gun_cards(player)

## Human label for the level's upgrade type (used in the screen title).
static func label_for_level(level: int) -> String:
	return "stat" if level % 2 == 1 else "weapon"

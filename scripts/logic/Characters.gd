class_name Characters
## The playable-character roster. Characters are passive: always-on perks plus perks
## that only apply when wielding a specific weapon. All applied through the existing
## Player/Gun upgrade hooks. The double-tap Dash is universal (not part of this data).
##
## KEEP THIS FILE AUTOLOAD-FREE (GameConfig/Player/Gun/Benefits-only — Benefits is a pure
## class_name, like GameConfig; it reads SaveManager internally but that's its own file's
## concern, not a stray autoload reference here). A perk that needs to touch an
## autoload (RunStats, SaveManager, ...) directly from apply_base()/apply_weapon() should instead
## return a value via a pure static function for the (already autoload-aware) caller to apply —
## see coin_per_kill_bonus() below. GDScript compiles this whole file on load, so a single stray
## autoload reference anywhere in it breaks `--headless --script` probing of EVERY function here,
## not just the offending one (cost real debugging time in Pack E — don't reintroduce it).

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
		{
			"id": "janitor", "name": "The Janitor", "price": 2800,
			"desc": "DASH leaves a mop-bucket slick that slows every enemy standing in it — never you. +1 coin per kill; mess is money.",
		},
		{
			"id": "delivery_girl", "name": "The Delivery Girl", "price": 3200,
			"desc": "DASH drops an armed parcel mine. +20% pickup radius — the packages find you.",
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
	# EMPLOYEE BENEFITS (Pack A): INSURANCE joins the spawn baseline (same adjudicated
	# hardcore-exempt rule as Ryan's bonus — see grant_base_max_health's doc), the rest are
	# plain run-start multipliers. Applies to every character, outside the match below.
	if Benefits.hp_bonus() > 0.0:
		player.grant_base_max_health(Benefits.hp_bonus())
	player.move_speed *= Benefits.speed_mult()
	player.xp_mult *= Benefits.xp_mult()
	# UNION REP: set here (spawn-config time), not at Player field-init, so a save bought
	# mid-session applies next run predictably.
	player._union_rep_available = Benefits.has_revive()
	match id:
		"ryan":
			# Via the spawn-baseline hook, NOT the upgrade-card hook: under HARDCORE the card
			# path stops raising current with max (adjudicated "no refill" rule), but a spawn
			# baseline applied at full health is starting tank size, not a refill — see
			# Player.grant_base_max_health's doc comment.
			player.grant_base_max_health(GameConfig.CHAR_RYAN_HP_BONUS)
		"jimbo":
			player.upgrade_move_speed(GameConfig.CHAR_JIMBO_SPEED_PCT)
		"bob":
			player.upgrade_pickup_radius(GameConfig.CHAR_BOB_MAGNET_PCT)
		"alstar":
			pass   # no always-on stat — his kit is the shockwave dash + the purple-gun fire-rate perk
		"janitor":
			pass   # coin-per-kill is read by Main via coin_per_kill_bonus() below (RunStats write
			       # stays out of this file — see that function's doc for why)
		"delivery_girl":
			player.upgrade_pickup_radius(GameConfig.CHAR_DELIVERY_PICKUP_PCT)

## The Janitor's passive: flat bonus coins added to every trash kill (0 = no character bonus).
## Returned here rather than written straight to RunStats.coins_per_kill so this whole file stays
## autoload-free (a class_name-only, --script-probable module, like every other lookup here) —
## Main.gd (already autoload-aware; it also owns RunStats.reset()) applies the result at run start.
static func coin_per_kill_bonus(id: String) -> float:
	match id:
		"janitor":
			return GameConfig.CHAR_JANITOR_COIN_PER_KILL
		_:
			return 0.0

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
		"janitor":
			pass   # no weapon-conditional perk — the slick dash + coin passive are weapon-agnostic
		"delivery_girl":
			pass   # no weapon-conditional perk — the mine dash + pickup passive are weapon-agnostic

## The special double-tap dash ability for a character, or "" for the plain dash. Read by
## the Player at run start (via Main) to decide what a dash does beyond the movement.
static func dash_ability(id: String) -> String:
	match id:
		"ryan":
			return "purge"        # clear every enemy projectile (+ instant AK reload)
		"alstar":
			return "shockwave"
		"janitor":
			return "slick"        # drop the mop-bucket slow-slick
		"delivery_girl":
			return "mine"         # drop an armed parcel mine
		_:
			return ""

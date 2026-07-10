class_name Coworkers
## The coworker registry — companions with the game's RNG DNA (roadmap-4 Pack C, v0.1.64).
## Pure data + roll algorithm (mirrors LootRoller/Rarity/Talents — no autoload references,
## so this file stays safe for headless `--script`/boot-scene probing). STAFF FILE store
## purchases roll one of these; the equipped coworker fights alongside the player at
## runtime (see Companion.gd, Task 3).
##
## Instance shape: { uid, type, rarity, trait } — trait is "" below
## COWORKER_TRAIT_MIN_RARITY (Savage/purple, rarity 5, and up). Type is uniform-random on
## every roll; rarity is supplied by the caller (the store rolls it via Rarity.roll — see
## MainMenu, Task 4).

const TYPES := ["cat", "drone", "mannequin"]

const TRAITS := [
	"sharp", "wired", "wide", "steady", "chilling", "pinning", "magnetic", "studious",
]

## Display name for a coworker type.
static func name_for(type: String) -> String:
	match type:
		"cat":
			return "STORE CAT"
		"drone":
			return "DELIVERY DRONE"
		"mannequin":
			return "FLOOR MANNEQUIN"
		_:
			return ""

## Flavor line shown under a coworker's name (authored copy).
static func flavor(type: String) -> String:
	match type:
		"cat":
			return "she was here before you. she'll be here after."
		"drone":
			return "the app says your order is 6 minutes away. forever."
		"mannequin":
			return "it volunteered. don't ask how."
		_:
			return ""

## Display name for a trait id.
static func trait_name(t: String) -> String:
	match t:
		"sharp":
			return "SHARP"
		"wired":
			return "WIRED"
		"wide":
			return "WIDE"
		"steady":
			return "STEADY"
		"chilling":
			return "CHILLING"
		"pinning":
			return "PINNING"
		"magnetic":
			return "MAGNETIC"
		"studious":
			return "STUDIOUS"
		_:
			return ""

## Criterion-clear one-liner for a trait id (authored copy, always <=70 chars). The actual
## application of these effects (damage/rate/radius/etc. multipliers) lives in Companion.gd
## (Task 3) — this function is display text only.
static func trait_desc(t: String) -> String:
	match t:
		"sharp":
			return "+25% damage"
		"wired":
			return "+20% attack rate"
		"wide":
			return "+25% radius & range"
		"steady":
			return "+30% mannequin HP & duration"
		"chilling":
			return "Hits slow enemies 25% for 1.5s"
		"pinning":
			return "15% chance to pin on hit, 0.45s"
		"magnetic":
			return "+40% coin pickup radius aura"
		"studious":
			return "+10% player XP while alive"
		_:
			return ""

## Rolls a full coworker instance at the given rarity. Type is uniform-random; a trait only
## rolls at COWORKER_TRAIT_MIN_RARITY (5, Savage/purple) and above — see GameConfig.
static func roll(rarity: int) -> Dictionary:
	var t := ""
	if rarity >= GameConfig.COWORKER_TRAIT_MIN_RARITY:
		t = TRAITS[randi() % TRAITS.size()]
	return {
		"uid": _uid(),
		"type": TYPES[randi() % TYPES.size()],
		"rarity": rarity,
		"trait": t,
	}

## Single stat-scaling curve shared by every coworker type: 1.0 at rarity 1, +18% per tier
## above that (GameConfig.COWORKER_STAT_PER_RARITY). Companion.gd multiplies every base stat
## (damage/rate/HP/etc.) by this.
static func stat_mult(rarity: int) -> float:
	return 1.0 + float(rarity - 1) * GameConfig.COWORKER_STAT_PER_RARITY

## Deconstruct payout range for a coworker of this rarity: the Rarity tier's own scrap coin
## band, halved (coworkers are cheaper to mint than a weapon crate, so they scrap for less),
## floored at 5 coins per side.
static func scrap_value(rarity: int) -> Array:
	var band: Array = Rarity.tier(rarity).scrap
	return [
		maxi(int(band[0]) / 2, 5),
		maxi(int(band[1]) / 2, 5),
	]

## Unique-enough-for-local-single-player uid, mirroring LootRoller._uid()'s time+randi()
## idiom (a "cw_" prefix keeps coworker uids visually distinct from weapon uids at a glance).
static func _uid() -> String:
	return "cw_%d_%d" % [Time.get_ticks_usec(), randi()]

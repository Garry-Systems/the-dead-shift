class_name Coworkers
## The coworker registry — companions with the game's RNG DNA (roadmap-4 Pack C, v0.1.64).
## Pure data + roll algorithm (mirrors LootRoller/Rarity/Talents — no autoload references,
## so this file stays safe for headless `--script`/boot-scene probing). STAFF FILE store
## purchases roll one of these; the equipped coworker fights alongside the player at
## runtime (see Companion.gd, Task 3).
##
## Instance shape: { uid, type, rarity, trait } — trait is "" below
## COWORKER_TRAIT_MIN_RARITY (Savage/purple, rarity 5, and up), and always drawn from the
## rolled type's own TRAITS_FOR pool (no dead rolls). Type is uniform-random on every roll;
## rarity is supplied by the caller (the store rolls it via Rarity.roll — see MainMenu,
## Task 4).

const TYPES := ["cat", "drone", "mannequin"]

const TRAITS := [
	"sharp", "wired", "wide", "steady", "chilling", "pinning", "magnetic", "studious",
]

## Per-type trait pools — every trait in a pool does something REAL for that type (the
## coworker version of the affix signature guarantee: no dead rolls, ever). Excluded per
## type: cat drops "pinning" (its pounce already always pins — a maxf-refresh no-op) and
## "steady" (mannequin-only); drone drops "steady"; mannequin keeps only the four traits
## that touch a decoy-placer at all (STEADY = HP/duration, WIDE = taunt radius,
## MAGNETIC/STUDIOUS = player-side, type-agnostic). The flat TRAITS list above stays as
## the iteration/desc-lookup surface.
const TRAITS_FOR := {
	"cat":       ["sharp", "wired", "wide", "chilling", "magnetic", "studious"],
	"drone":     ["sharp", "wired", "wide", "chilling", "pinning", "magnetic", "studious"],
	"mannequin": ["steady", "wide", "magnetic", "studious"],
}

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

## Rolls a full coworker instance at the given rarity. Type is uniform-random and rolls
## FIRST; a trait only rolls at COWORKER_TRAIT_MIN_RARITY (5, Savage/purple) and above — see
## GameConfig — and draws from the rolled TYPE's own pool (TRAITS_FOR), never the flat list,
## so a rolled trait is always live for its carrier (no dead rolls).
static func roll(rarity: int) -> Dictionary:
	var type: String = TYPES[randi() % TYPES.size()]
	var t := ""
	if rarity >= GameConfig.COWORKER_TRAIT_MIN_RARITY:
		var pool: Array = TRAITS_FOR[type]
		t = pool[randi() % pool.size()]
	return {
		"uid": _uid(),
		"type": type,
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

## A single coin payout for scrapping a coworker of this rarity — one fresh roll inside
## scrap_value()'s (already-halved) band. Pure (no autoload dependency), so MainMenu's SCRAP
## flow and a headless probe can both call the exact same code path — the Pack-A scrap
## byproduct (maxi(1, payout/10) * Benefits.scrap_mult()) is computed by the caller, not
## here, since Benefits pulls SaveManager transitively and this file stays autoload-free.
static func roll_scrap_payout(rarity: int) -> int:
	var band := scrap_value(rarity)
	return randi_range(int(band[0]), int(band[1]))

## EQUIP/UNEQUIP toggle: given the currently-equipped uid and the uid just tapped, returns
## the NEW equipped_coworker value. Re-tapping the already-equipped uid clears it ("") —
## coworkers, unlike weapons, support being fully unequipped (Companion.gd only spawns when
## equipped_coworker resolves to a live instance). Pure so MainMenu's EQUIP flow and a
## headless probe can both call the exact same code path.
static func toggle_equip(current_equipped: String, uid: String) -> String:
	return "" if current_equipped == uid else uid

## Unique-enough-for-local-single-player uid, mirroring LootRoller._uid()'s time+randi()
## idiom (a "cw_" prefix keeps coworker uids visually distinct from weapon uids at a glance).
static func _uid() -> String:
	return "cw_%d_%d" % [Time.get_ticks_usec(), randi()]

## The type's art icon, if it exists (res://art/coworkers/<type>.png — not shipped until
## Task 5). Mirrors WeaponInstance.icon()'s existence-check idiom, but returns null instead
## of a shared placeholder texture: there is no "_placeholder.png" for coworkers yet, so the
## caller (CoworkerTile / CoworkerDetailPopup) falls back to a drawn glyph — see
## glyph_letter/glyph_color below — instead of a placeholder image.
static func icon(type: String) -> Texture2D:
	var path := "res://art/coworkers/%s.png" % type
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Pre-art fallback glyph: a single letter for the type, used by CoworkerTile /
## CoworkerDetailPopup when icon() returns null.
static func glyph_letter(type: String) -> String:
	match type:
		"cat":
			return "C"
		"drone":
			return "D"
		"mannequin":
			return "M"
		_:
			return "?"

## Pre-art fallback glyph color: mirrors Companion.gd's own runtime-sprite palette
## (CAT_COLOR gray-tan / DRONE_COLOR lavender / MANNEQUIN_COLOR indigo) so the placeholder
## glyph and the in-run companion sprite read as the same "thing" even with zero art.
static func glyph_color(type: String) -> Color:
	match type:
		"cat":
			return Color(0.549, 0.522, 0.451)     # C3 gray-tan
		"drone":
			return Color(0.878, 0.898, 1.0)       # C4 lavender
		"mannequin":
			return Color(0.239, 0.0, 0.6)         # C2 indigo
		_:
			return Color(1, 1, 1)

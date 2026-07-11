class_name Abilities
## The special-abilities registry: character id -> this run's signature active-ability row.
## Pure data + lookup, no gameplay side effects — Company Equipment (v0.1.70)'s T1 seam every
## later task (AbilityController, the HUD button) reads through for_character().
##
## KEEP THIS FILE AUTOLOAD-FREE (GameConfig-only), same header discipline as Characters.gd:
## GDScript compiles the whole file on load, so a single stray autoload reference anywhere here
## breaks `--headless` boot-scene probing of every function in it, not just the offending one.

## Returns the ability row for `id`, or `{}` for an id with no ability (unknown/future ids).
## Row shape: `{"id": String, "name": String, "cd": float}` — `id` matches the
## `AbilityController._cast_<id>()` handler name, `name` is the HUD/callout display string, `cd`
## is the flat cooldown in seconds (GameConfig.ABILITY_*_CD). Nothing here is rolled or stored —
## the row is re-derived from RunConfig.character_id fresh every call.
static func for_character(id: String) -> Dictionary:
	match id:
		"ryan":
			return {"id": "clear_out", "name": "CLEAR OUT", "cd": GameConfig.ABILITY_CLEAROUT_CD}
		"jackson":
			return {"id": "turret", "name": "SENTRY TURRET", "cd": GameConfig.ABILITY_TURRET_CD}
		"jimbo":
			return {"id": "dead_eye", "name": "DEAD EYE", "cd": GameConfig.ABILITY_DEADEYE_CD}
		"bob":
			return {"id": "ghost", "name": "ONE OF THEM", "cd": GameConfig.ABILITY_GHOST_CD}
		"alstar":
			return {"id": "jackpot", "name": "JACKPOT", "cd": GameConfig.ABILITY_JACKPOT_CD}
		"janitor":
			return {"id": "closing_time", "name": "CLOSING TIME", "cd": GameConfig.ABILITY_CLOSING_CD}
		"delivery_girl":
			return {"id": "air_drop", "name": "AIR DROP", "cd": GameConfig.ABILITY_AIRDROP_CD}
		_:
			return {}

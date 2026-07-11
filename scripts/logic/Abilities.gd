class_name Abilities
## The special-abilities registry: character id -> this run's signature active-ability row.
## Pure data + lookup, no gameplay side effects — Company Equipment (v0.1.70)'s T1 seam every
## later task (AbilityController, the HUD button) reads through for_character().
##
## KEEP THIS FILE AUTOLOAD-FREE (GameConfig-only), same header discipline as Characters.gd:
## GDScript compiles the whole file on load, so a single stray autoload reference anywhere here
## breaks `--headless` boot-scene probing of every function in it, not just the offending one.

## Returns the ability row for `id`, or `{}` for an id with no ability (unknown/future ids).
## Row shape: `{"id": String, "name": String, "cd": float, "sfx": String}` — `id` matches the
## `AbilityController._cast_<id>()` handler name, `name` is the HUD/callout display string, `cd`
## is the flat cooldown in seconds (GameConfig.ABILITY_*_CD), `sfx` is the SoundManager id
## try_cast()'s generic dispatch plays on a successful cast (T9). CLEAR OUT's `sfx` is "" —
## `_cast_clear_out` plays "purge" itself, so the generic dispatch must stay silent for it
## (playing anything there would double up, the Task 2 bug this wiring closes). CLOSING TIME
## reuses "dash", the exact SFX already tied to Player._spawn_slick (the same puddle cfg this
## ability scales up) — no new WAV needed, same reuse precedent as CLEAR OUT/"purge". Nothing
## here is rolled or stored — the row is re-derived from RunConfig.character_id fresh every call.
static func for_character(id: String) -> Dictionary:
	match id:
		"ryan":
			return {"id": "clear_out", "name": "CLEAR OUT", "cd": GameConfig.ABILITY_CLEAROUT_CD, "sfx": ""}
		"jackson":
			return {"id": "turret", "name": "SENTRY TURRET", "cd": GameConfig.ABILITY_TURRET_CD, "sfx": "ability_turret"}
		"jimbo":
			return {"id": "dead_eye", "name": "DEAD EYE", "cd": GameConfig.ABILITY_DEADEYE_CD, "sfx": "ability_deadeye"}
		"bob":
			return {"id": "ghost", "name": "ONE OF THEM", "cd": GameConfig.ABILITY_GHOST_CD, "sfx": "ability_ghost"}
		"alstar":
			return {"id": "jackpot", "name": "JACKPOT", "cd": GameConfig.ABILITY_JACKPOT_CD, "sfx": "ability_jackpot"}
		"janitor":
			return {"id": "closing_time", "name": "CLOSING TIME", "cd": GameConfig.ABILITY_CLOSING_CD, "sfx": "dash"}
		"delivery_girl":
			return {"id": "air_drop", "name": "AIR DROP", "cd": GameConfig.ABILITY_AIRDROP_CD, "sfx": "ability_airdrop"}
		_:
			return {}

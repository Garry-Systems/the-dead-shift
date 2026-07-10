class_name BasementLogic
## Pure gate/math for THE BASEMENT (Pack E). Controller = scripts/Basement.gd; keeping the
## decisions pure keeps them probe-able (Characters.gd lesson).
##
## Mode representation (verified against RunConfig.gd/Spawner.gd, roadmap-4 Pack G v0.1.58):
## OVERTIME, HARDCORE, and DAILY are all flags layered on top of `RunConfig.mode == "endless"`
## (`overtime`/`hardcore`/`daily` bools) — they never change the `mode` string itself. Only
## HORDE NIGHT is its own top-level `mode` value ("horde"), and BOSS RUSH is "boss_rush". So the
## allowed list only needs the two real mode strings the basement should ever roll under; the
## endless-flag runs inherit "endless" for free and need no separate flag-check here.
const ALLOWED_MODES := ["endless", "horde"]

## Gate for rolling a cellar door at a wave-edge: wave floor met, mode allowed, per-run cap not
## hit, no door already alive, and the player isn't already inside a gauntlet.
static func can_roll(wave: int, mode: String, doors_spawned: int, door_alive: bool, in_basement: bool) -> bool:
	if wave < GameConfig.BASEMENT_MIN_WAVE:
		return false
	if not ALLOWED_MODES.has(mode):
		return false
	if doors_spawned >= GameConfig.BASEMENT_MAX_PER_RUN:
		return false
	if door_alive:
		return false
	if in_basement:
		return false
	return true

## Chance roll for whether a cellar door actually spawns once can_roll() allows it. Caller passes
## RunConfig.rand_float() (daily-seeded when a Daily Shift run is active).
static func roll(rand01: float) -> bool:
	return rand01 < GameConfig.BASEMENT_DOOR_CHANCE

## Reward crate rarity floor for a gauntlet cleared on the given wave: rises with wave, capped
## at the apex floor (never guarantees the animated tiers).
static func crate_floor(wave: int) -> int:
	return mini(GameConfig.BASEMENT_CRATE_FLOOR_BASE + wave / GameConfig.BASEMENT_CRATE_FLOOR_WAVES, GameConfig.BASEMENT_CRATE_FLOOR_MAX)

## Reward crate id for the gauntlet at `wave`, mapping crate_floor's rarity floor onto the
## closest real crate in the registry (Crates.gd). The registry has no generic floor-2/3 crate,
## so early floors round UP to munitions_cache (floor 4) — a floor guarantee must never
## under-deliver. Flagged as a tuning note: waves 3-14 all pay munitions_cache.
## (Local is `floor_id`, not `floor` — that name would shadow the global floor() built-in.)
static func crate_id_for(wave: int) -> String:
	var floor_id := crate_floor(wave)
	if floor_id >= 7:
		return "apocalypse_crate"
	if floor_id >= 6:
		return "apex_crate"
	if floor_id >= 5:
		return "titan_crate"
	return "munitions_cache"

## Guaranteed elite count for a gauntlet run on the given wave: the base count (BASEMENT_ELITES),
## +1 past wave 10 — a later, harder gauntlet forces one more forced elite into its spawn cadence.
static func elite_count(wave: int) -> int:
	return GameConfig.BASEMENT_ELITES + (1 if wave > 10 else 0)

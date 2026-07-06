class_name Challenges
## The challenge-board pool + daily rotation (Pack C: Challenges + daily shift, v0.1.53). Pure
## data + pure date math — mirrors Crates.gd/Characters.gd's "all() returns a fresh Array" shape,
## no Node/autoload dependency (safe to call from a headless probe or from ChallengeProgress).
##
## Each row: { id, desc (Larry-facing, "%d" for the target where relevant), counter_key,
## agg ("sum" adds this run's tally, "max" keeps the larger of stored-vs-this-run), target,
## reward_crate_id }. `counter_key` must match exactly what a flush site supplies:
##   - Run-scoped rows (kills, elite_kills, boss_kills, clock_seconds, blood_moons_survived,
##     power_surge_kills, extraction_wins, fire_kills, electric_kills, poison_kills) are flushed
##     together via SaveManager.flush_challenge_counters() at GameOver/PauseMenu's existing
##     RunStats.paid_out-guarded payout blocks.
##   - Menu-action rows (crates_opened, fusions_done) are NOT part of a run payout at all — a
##     crate is opened and a weapon is fused entirely from the main menu, so each real action
##     bumps SaveManager.bump_challenge_counter() directly, once, at its own atomic chokepoint
##     (Inventory.commit_crate / Inventory.fuse) — no paid_out guard needed because each call
##     already corresponds to exactly one real action (no death-vs-quit double-fire race exists
##     for a menu button press). Documented swap from the spec's more exotic suggestions (e.g. a
##     "no-dash to midnight" row) toward counters that are cleanly, cheaply countable off systems
##     that already exist.
##
## Rotation: CHALLENGE_ACTIVE_COUNT ids, PURELY a function of the date string — see
## active_ids_for()'s doc comment and ChallengeProgress's "simplest honest model" writeup for why
## nothing about *which* ids are active is ever persisted.

static func all() -> Array:
	return [
		{ "id": "kill_zombies", "desc": "Kill %d zombies", "counter_key": "kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_KILLS_TARGET, "reward_crate_id": "scrap_crate" },
		{ "id": "kill_elites", "desc": "Kill %d elite zombies", "counter_key": "elite_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_ELITE_KILLS_TARGET, "reward_crate_id": "fiftyfifty" },
		{ "id": "defeat_bosses", "desc": "Defeat %d bosses", "counter_key": "boss_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_BOSS_KILLS_TARGET, "reward_crate_id": "munitions_cache" },
		{ "id": "reach_2am", "desc": "Reach 2:00 AM in a single shift", "counter_key": "clock_seconds", "agg": "max",
			"target": ShiftClock.run_time_for_hour(GameConfig.CHALLENGE_CLOCK_HOUR), "reward_crate_id": "scrap_crate" },
		{ "id": "survive_blood_moon", "desc": "Survive a Blood Moon", "counter_key": "blood_moons_survived", "agg": "sum",
			"target": GameConfig.CHALLENGE_BLOOD_MOON_TARGET, "reward_crate_id": "fiftyfifty" },
		{ "id": "power_surge_kills", "desc": "Kill %d enemies during a Power Surge", "counter_key": "power_surge_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_POWER_SURGE_KILLS_TARGET, "reward_crate_id": "munitions_cache" },
		{ "id": "open_crates", "desc": "Open %d crates", "counter_key": "crates_opened", "agg": "sum",
			"target": GameConfig.CHALLENGE_CRATES_TARGET, "reward_crate_id": "titan_crate" },
		{ "id": "fuse_weapons", "desc": "Fuse %d weapons", "counter_key": "fusions_done", "agg": "sum",
			"target": GameConfig.CHALLENGE_FUSIONS_TARGET, "reward_crate_id": "titan_crate" },
		{ "id": "win_extraction", "desc": "Win an extraction", "counter_key": "extraction_wins", "agg": "sum",
			"target": GameConfig.CHALLENGE_EXTRACTION_TARGET, "reward_crate_id": "apex_crate" },
		{ "id": "fire_kills", "desc": "Kill %d enemies while they're burning", "counter_key": "fire_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_FIRE_KILLS_TARGET, "reward_crate_id": "fiftyfifty" },
		{ "id": "electric_kills", "desc": "Kill %d enemies with chain lightning", "counter_key": "electric_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_ELECTRIC_KILLS_TARGET, "reward_crate_id": "fiftyfifty" },
		{ "id": "poison_kills", "desc": "Kill %d enemies with poison", "counter_key": "poison_kills", "agg": "sum",
			"target": GameConfig.CHALLENGE_POISON_KILLS_TARGET, "reward_crate_id": "fiftyfifty" },
	]

## First row matching `id`, or {} if unknown (a stale id from a since-edited pool, defensively).
static func by_id(id: String) -> Dictionary:
	for row in all():
		if String(row["id"]) == id:
			return row
	return {}

## Deterministic pick of GameConfig.CHALLENGE_ACTIVE_COUNT DISTINCT challenge ids for `date_str`
## ("YYYY-MM-DD"). A partial Fisher-Yates shuffle seeded off the date string's hash: the same
## date always produces the same seed, which always produces the same draw order, which always
## produces the same result — nothing about the rotation is ever stored; calling this twice for
## the same date (even across app restarts) reproduces the identical 3 ids every time. Two
## different dates are extremely likely (but not mathematically guaranteed) to differ — a hash
## collision would just mean two different days share a rotation, which is harmless.
static func active_ids_for(date_str: String) -> Array:
	var pool := all()
	var n := pool.size()
	var count := mini(GameConfig.CHALLENGE_ACTIVE_COUNT, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(date_str)
	var idx: Array = range(n)
	var out: Array = []
	for i in count:
		var j: int = i + rng.randi_range(0, n - i - 1)
		var tmp = idx[i]
		idx[i] = idx[j]
		idx[j] = tmp
		out.append(String(pool[idx[i]]["id"]))
	return out

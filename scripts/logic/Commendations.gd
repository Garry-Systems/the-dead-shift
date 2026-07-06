class_name Commendations
## The Commendations wall's data: 18 one-time lifetime badges (Pack H: v0.1.59), night-shift
## flavor names. Pure data + pure check/read functions over a save-data Dictionary (the exact
## shape of SaveManager's own `_data`) — no Node/autoload dependency, mirrors Challenges.gd's row
## shape (id/desc/counter_key/target) so a headless probe can verify every boundary directly
## against a synthetic Dictionary.
##
## Countability rule (same discipline as the challenge board): every counter_key below is either
## an EXISTING SaveManager key (games_played, total_kills, total_elites, total_bosses,
## shifts_survived, daily_streak, armageddons_pulled, fusions, challenges_completed_total) or one
## of FOUR new one-line-cheap lifetime counters added this pack at an existing chokepoint — see
## each new SaveManager key's own doc comment for exactly where it's bumped:
##   apocalypse_pulled   — Inventory.add(), rarity == Rarity.RAINBOW_ID (8)
##   crates_opened_total — Inventory.commit_crate() (LIFETIME, distinct from the challenge board's
##                         per-rotation "crates_opened" counter, which wipes on a date change)
##   dailies_played      — MainMenu._on_daily_shift() (consumed on START, mirrors the existing
##                         last_daily_shift_date "consumed on start, not completion" semantics)
##   best_run_payout     — GameOver._finish_run() / PauseMenu._abandon_run_payout(), max() at the
##                         same paid_out-guarded flush every other lifetime record uses
## No badge references a counter that doesn't exist by one of these two routes.
##
## Every target is a GameConfig const (house rule, mirrors CHALLENGE_*_TARGET). Reward tiers scale
## scrap -> titan by difficulty (rank_xp_grant 100/250/500 + a one-time crate).

const TIER_EASY := { "rank_xp": GameConfig.COMMENDATION_TIER_EASY_XP, "crate_id": GameConfig.COMMENDATION_TIER_EASY_CRATE }
const TIER_MED  := { "rank_xp": GameConfig.COMMENDATION_TIER_MED_XP,  "crate_id": GameConfig.COMMENDATION_TIER_MED_CRATE }
const TIER_HARD := { "rank_xp": GameConfig.COMMENDATION_TIER_HARD_XP, "crate_id": GameConfig.COMMENDATION_TIER_HARD_CRATE }

## Each row: { id, name (badge title, Larry-facing), desc (Larry-facing), counter_key (a save-data
## key read directly off the dict — see the countability rule above), target, tier (one of the
## TIER_* dicts above) }.
static func all() -> Array:
	return [
		{ "id": "first_day", "name": "FIRST DAY", "desc": "Finish your first shift.",
			"counter_key": "games_played", "target": GameConfig.COMMENDATION_FIRST_DAY_TARGET, "tier": TIER_EASY },
		{ "id": "punching_in", "name": "PUNCHING IN", "desc": "Finish 10 shifts.",
			"counter_key": "games_played", "target": GameConfig.COMMENDATION_PUNCHING_IN_TARGET, "tier": TIER_EASY },
		{ "id": "career_clerk", "name": "CAREER CLERK", "desc": "Finish 100 shifts.",
			"counter_key": "games_played", "target": GameConfig.COMMENDATION_CAREER_CLERK_TARGET, "tier": TIER_MED },
		{ "id": "exterminator", "name": "EXTERMINATOR", "desc": "Kill 2,500 zombies (lifetime).",
			"counter_key": "total_kills", "target": GameConfig.COMMENDATION_EXTERMINATOR_TARGET, "tier": TIER_EASY },
		{ "id": "genocide_shift", "name": "GENOCIDE SHIFT", "desc": "Kill 25,000 zombies (lifetime).",
			"counter_key": "total_kills", "target": GameConfig.COMMENDATION_GENOCIDE_SHIFT_TARGET, "tier": TIER_HARD },
		{ "id": "pest_control", "name": "PEST CONTROL", "desc": "Kill 100 elite zombies (lifetime).",
			"counter_key": "total_elites", "target": GameConfig.COMMENDATION_PEST_CONTROL_TARGET, "tier": TIER_MED },
		{ "id": "middle_management", "name": "MIDDLE MANAGEMENT", "desc": "Defeat 25 bosses (lifetime).",
			"counter_key": "total_bosses", "target": GameConfig.COMMENDATION_MIDDLE_MANAGEMENT_TARGET, "tier": TIER_MED },
		{ "id": "upper_management", "name": "UPPER MANAGEMENT", "desc": "Defeat 100 bosses (lifetime).",
			"counter_key": "total_bosses", "target": GameConfig.COMMENDATION_UPPER_MANAGEMENT_TARGET, "tier": TIER_HARD },
		{ "id": "dawn_patrol", "name": "DAWN PATROL", "desc": "Survive 1 Dawn Extraction.",
			"counter_key": "shifts_survived", "target": GameConfig.COMMENDATION_DAWN_PATROL_TARGET, "tier": TIER_EASY },
		{ "id": "week_one", "name": "WEEK ONE", "desc": "Survive 5 shifts via Dawn Extraction.",
			"counter_key": "shifts_survived", "target": GameConfig.COMMENDATION_WEEK_ONE_TARGET, "tier": TIER_MED },
		{ "id": "employee_of_the_month", "name": "EMPLOYEE OF THE MONTH", "desc": "Reach a 7-day login streak.",
			"counter_key": "daily_streak", "target": GameConfig.COMMENDATION_EMPLOYEE_OF_MONTH_TARGET, "tier": TIER_MED },
		{ "id": "regular", "name": "REGULAR", "desc": "Play 10 Daily Shifts.",
			"counter_key": "dailies_played", "target": GameConfig.COMMENDATION_REGULAR_TARGET, "tier": TIER_MED },
		{ "id": "golden_ticket", "name": "GOLDEN TICKET", "desc": "Pull an Armageddon-rarity weapon.",
			"counter_key": "armageddons_pulled", "target": GameConfig.COMMENDATION_GOLDEN_TICKET_TARGET, "tier": TIER_HARD },
		{ "id": "over_the_rainbow", "name": "OVER THE RAINBOW", "desc": "Pull an Apocalypse-rarity weapon.",
			"counter_key": "apocalypse_pulled", "target": GameConfig.COMMENDATION_OVER_THE_RAINBOW_TARGET, "tier": TIER_MED },
		{ "id": "big_spender", "name": "BIG SPENDER", "desc": "Open 50 crates (lifetime).",
			"counter_key": "crates_opened_total", "target": GameConfig.COMMENDATION_BIG_SPENDER_TARGET, "tier": TIER_MED },
		{ "id": "recycler", "name": "RECYCLER", "desc": "Fuse 10 weapons (lifetime).",
			"counter_key": "fusions", "target": GameConfig.COMMENDATION_RECYCLER_TARGET, "tier": TIER_EASY },
		{ "id": "taskmaster", "name": "TASKMASTER", "desc": "Complete 25 challenges (lifetime).",
			"counter_key": "challenges_completed_total", "target": GameConfig.COMMENDATION_TASKMASTER_TARGET, "tier": TIER_MED },
		{ "id": "payday", "name": "PAYDAY", "desc": "Earn 2,000+ coins in a single run.",
			"counter_key": "best_run_payout", "target": GameConfig.COMMENDATION_PAYDAY_TARGET, "tier": TIER_MED },
	]

## First row matching `id`, or {} if unknown.
static func by_id(id: String) -> Dictionary:
	for row in all():
		if String(row["id"]) == id:
			return row
	return {}

## The live counter value for `row`, read directly off `data` (the save-data dict) — 0 if absent.
static func value_for(row: Dictionary, data: Dictionary) -> float:
	if row.is_empty():
		return 0.0
	return float(data.get(String(row.get("counter_key", "")), 0))

## True once `row`'s counter has reached its target in `data` — the ONE boundary a headless probe
## needs to verify per row (locked one below target, earned exactly at target).
static func is_earned(row: Dictionary, data: Dictionary) -> bool:
	if row.is_empty():
		return false
	return value_for(row, data) >= float(row.get("target", 0))

extends Node
## Owns the single persistent save file (user://savegame.json): the coin wallet
## and high scores. Loads once on boot (autoload), survives scene changes.
## Corruption-safe and forward-compatible — later specs add keys to DEFAULTS and
## old saves silently gain them. No class_name: the autoload name is already global.

const SAVE_PATH := "user://savegame.json"
const TMP_PATH := "user://savegame.tmp"
const CORRUPT_PATH := "user://savegame.corrupt.json"

## The canonical schema. Adding a key here is the ONLY change needed to extend the save.
const DEFAULTS := {
	"version": 1,
	"coins": 0,
	"best_wave": 0,
	"best_bosses": 0,
	"weapons": [],            # rolled weapon-loot instances (see LootRoller)
	"equipped_weapon": "",    # uid of the equipped instance
	"coworkers": [],          # rolled coworker instances (see Coworkers.gd, Pack C)
	"equipped_coworker": "",  # uid of the equipped coworker ("" = none)
	"unlocked_characters": ["ryan"],   # character ids the player owns (Ryan free)
	"crates": {},             # owned unopened crates: crate_id -> count
	"scrap": 0,               # EMPLOYEE BENEFITS currency — byproduct of deconstructs (Pack A)
	"benefits": {},           # benefit track id -> purchased level (Pack A)
	"dev_bonus_granted": false,     # DEV (legacy): the old 10k one-time bonus flag (superseded)
	"dev_bonus_v2_granted": false,  # DEV (temporary): the 30k start bonus already given?
	"last_daily_claim": "",   # "YYYY-MM-DD" of the last claimed daily-login reward ("" = never)
	"daily_streak": 0,        # consecutive daily claims (Rewards.next_streak); resets on a missed day
	"games_played": 0,        # completed runs (game-over count) — drives the every-10-games reward
	"game_rewards_given": 0,  # how many 10-game milestone rewards have already been handed out
	"tutorial_done": false,   # first-run HUD hint sequence (move/shoot/dash) already completed?
	"sfx_on": true,           # SoundManager: SFX bus enabled?
	"music_on": true,         # SoundManager: Music bus enabled?
	"shifts_survived": 0,     # Pack A: runs that WON via the Dawn Extraction chopper LZ (not just reaching dawn)
	"total_kills": 0,           # Pack D: lifetime kills, flushed at payout (see LifetimeRecords.merge_run)
	"total_bosses": 0,          # Pack D: lifetime boss kills
	"total_elites": 0,          # Pack D: lifetime elite-modifier kills
	"total_coins_earned": 0,    # Pack D: lifetime coins actually earned (post-haircut on the quit path)
	"best_clockout_seconds": 0.0,  # Pack D: highest run_time (seconds) ever reached at payout
	"armageddons_pulled": 0,    # Pack D: rarity-9 (Armageddon) instances added to the inventory
	"gun_kills": {},            # Pack D: base weapon id -> lifetime kill count (equipped-at-kill-time gun)
	"shake_on": true,           # Pack D: EFFECTS toggle — screen shake + crit-kill hit-stop
	"fusions": 0,               # Pack B: lifetime count of successful weapon-fusion feeds (Inventory.fuse)
	"challenge_date": "",              # Pack C: date ("YYYY-MM-DD") the current 3-challenge rotation + its progress belongs to
	"challenge_progress": {},          # Pack C: challenge_id -> accumulated counter value, valid only for challenge_date's rotation
	"challenge_completed": [],         # Pack C: challenge ids already completed+claimed within challenge_date's rotation
	"challenges_completed_total": 0,   # Pack C: lifetime completed-challenge count (RECORDS row)
	"pending_challenge_rewards": [],   # Pack C: crate ids already granted by a completed challenge, awaiting reveal at the next menu entry
	"last_daily_shift_date": "",       # Pack C: date of the last STARTED Daily Shift attempt (consumed on START, not completion)
	"best_daily_score": 0,             # Pack C: highest coin payout ever earned from a Daily Shift run
	"rank_xp": 0,                        # Pack G: lifetime Employee Rank XP; rank itself is DERIVED (Ranks.rank_for), never stored
	"pending_promotion": false,          # Pack G: a run crossed a rank threshold; queues the PROMOTED popup at the next menu entry
	"pending_promotion_from_rank": 1,    # Pack G: the rank held BEFORE the still-unshown promotion window began (for the "newly unlocked" list)
	"horde_best_wave": 0,                # Pack G: HORDE NIGHT's own best-wave record (never touched by endless/boss_rush/overtime runs)
	"overtime_best_clockout_seconds": 0.0,  # Pack G: OVERTIME's own best clock-out (the shared best_clockout_seconds must NOT move on an overtime run)
	"hardcore_best_clockout_seconds": 0.0,  # Pack G: HARDCORE's own best clock-out
	"apocalypse_pulled": 0,              # Pack H: rarity-8 (Apocalypse) instances added to the inventory — same Inventory.add() chokepoint as armageddons_pulled
	"crates_opened_total": 0,            # Pack H: LIFETIME crates opened — distinct from the challenge board's per-rotation "crates_opened" counter (wipes on a date change); bumped at the Inventory.commit_crate chokepoint
	"dailies_played": 0,                 # Pack H: lifetime count of Daily Shift attempts STARTED (mirrors last_daily_shift_date's "consumed on start, not completion" semantics)
	"best_run_payout": 0,                # Pack H: highest single-run actual coin payout (`earned`) ever, across every run — max() at the same paid_out-guarded flush as everything else, both exit paths
	"commendations_earned": [],          # Pack H: ids of one-time Commendations badges already earned (persisted; never un-earned)
	"pending_commendation_rewards": [],  # Pack H: commendation ids already granted (rank XP + crate), awaiting reveal at the next menu entry
	"basements_cleared": 0,              # Pack E (THE BASEMENT), Task 5: LIFETIME gauntlets survived to the reward
	                                      # drop — never resets; bumped at the SAME Basement._start_reward() chokepoint
	                                      # that flushes it (mirrors crates_opened_total's "chokepoint owns its save" idiom)
}

var _data: Dictionary = {}

func _ready() -> void:
	load_game()

## Reads the save file into _data, merging over defaults. Safe on missing/corrupt files.
func load_game() -> void:
	_data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("SaveManager: could not open save; using defaults")
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_handle_corrupt(text)
		return
	# Merge known keys, coercing numbers to the default's type. JSON has no int/float
	# distinction, so Godot parses whole numbers back as float — without coercion an
	# int default would reject every saved value and silently reset progress.
	for key in DEFAULTS:
		if not parsed.has(key):
			continue
		var def_val = DEFAULTS[key]
		var val = parsed[key]
		match typeof(def_val):
			TYPE_INT:
				if val is int or val is float:
					_data[key] = int(val)
			TYPE_FLOAT:
				if val is int or val is float:
					_data[key] = float(val)
			_:
				if typeof(val) == typeof(def_val):
					_data[key] = val
	_data["version"] = DEFAULTS["version"]

## Writes _data to disk atomically (temp file, then replace). Never crashes the game.
func save_game() -> bool:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: could not open temp file for writing")
		return false
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	# rename() replaces the destination directly (no delete-then-rename window), so a
	# process kill mid-write can never leave the save file missing.
	var err := dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file())
	return err == OK

func _handle_corrupt(bad_text: String) -> void:
	push_warning("SaveManager: save file corrupt; backing up and resetting to defaults")
	var f := FileAccess.open(CORRUPT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(bad_text)
		f.close()
	_data = DEFAULTS.duplicate(true)

# --- Public API (mutators change memory only; caller decides when to save) ---

func coins() -> int:
	return int(_data.get("coins", 0))

func add_coins(amount: int) -> void:
	_data["coins"] = coins() + maxi(amount, 0)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins() < amount:
		return false
	_data["coins"] = coins() - amount
	return true

func scrap() -> int:
	return int(_data.get("scrap", 0))

func add_scrap(amount: int) -> void:
	_data["scrap"] = scrap() + maxi(amount, 0)

## False (and no mutation) when the wallet is short or the amount is not positive.
func spend_scrap(amount: int) -> bool:
	if amount <= 0 or amount > scrap():
		return false
	_data["scrap"] = scrap() - amount
	return true

func benefit_level(id: String) -> int:
	var b: Dictionary = _data.get("benefits", {})
	return int(b.get(id, 0))

func set_benefit_level(id: String, lvl: int) -> void:
	var b: Dictionary = _data.get("benefits", {})
	b[id] = lvl
	_data["benefits"] = b

## DEV (temporary): grant a one-time coin bonus so the store/economy is testable. Grants
## once per save (the flag persists + is saved), so the player can still spend normally.
func grant_dev_bonus(amount: int) -> void:
	if bool(_data.get("dev_bonus_v2_granted", false)):
		return
	_data["dev_bonus_v2_granted"] = true
	add_coins(amount)
	save_game()

# --- Free rewards: daily login + every-10-games milestone (mutators are memory-only; save after) ---

## Local calendar date as "YYYY-MM-DD" — the daily reward resets on a new local day.
func today_string() -> String:
	return Time.get_date_string_from_system(false)

## True if today's daily-login reward hasn't been claimed yet.
func is_daily_due() -> bool:
	return String(_data.get("last_daily_claim", "")) != today_string()

## The raw "YYYY-MM-DD" of the last claimed daily reward ("" = never claimed). Read this
## BEFORE calling mark_daily_claimed() when computing the new streak (Rewards.next_streak) —
## mark_daily_claimed() overwrites it to today.
func last_daily_claim() -> String:
	return String(_data.get("last_daily_claim", ""))

func mark_daily_claimed() -> void:
	_data["last_daily_claim"] = today_string()

## Current consecutive daily-login streak (0 = never claimed / streak lost).
func daily_streak() -> int:
	return int(_data.get("daily_streak", 0))

func set_daily_streak(n: int) -> void:
	_data["daily_streak"] = maxi(n, 0)

func games_played() -> int:
	return int(_data.get("games_played", 0))

## Count one completed run (called from GameOver). Caller saves.
func add_game_played() -> void:
	_data["games_played"] = games_played() + 1

## How many every-10-games milestone rewards are still owed (handles multiples / missed menus).
func pending_game_rewards() -> int:
	return maxi(int(games_played() / 10) - int(_data.get("game_rewards_given", 0)), 0)

func mark_game_reward_given() -> void:
	_data["game_rewards_given"] = int(_data.get("game_rewards_given", 0)) + 1

func best_wave() -> int:
	return int(_data.get("best_wave", 0))

func best_bosses() -> int:
	return int(_data.get("best_bosses", 0))

func record_run(wave: int, bosses: int) -> void:
	_data["best_wave"] = maxi(best_wave(), wave)
	_data["best_bosses"] = maxi(best_bosses(), bosses)

# --- Employee Rank + per-mode records (Pack G: v0.1.58) ---

func rank_xp() -> int:
	return int(_data.get("rank_xp", 0))

## Adds lifetime rank XP (the run's ACTUAL paid coins) and queues a PROMOTED popup if this pushed
## the player past one or more rank thresholds. Called from BOTH paid_out-guarded flush blocks
## (GameOver._finish_run / PauseMenu._abandon_run_payout) with the run's real `earned` value — see
## Ranks.gd for the pure threshold math. Memory only; caller saves.
func add_rank_xp(amount: int) -> void:
	if amount <= 0:
		return
	var before := Ranks.rank_for(rank_xp())
	_data["rank_xp"] = rank_xp() + amount
	var after := Ranks.rank_for(rank_xp())
	if after > before:
		# Only stamp "from_rank" the FIRST time a promotion window opens — a player can restart
		# straight back into Main.tscn (bypassing the menu) across several runs before ever seeing
		# the popup, so a later, already-pending promotion must not overwrite the earlier start
		# point (that would hide modes unlocked in between from the "newly unlocked" list).
		if not has_pending_promotion():
			_data["pending_promotion_from_rank"] = before
		_data["pending_promotion"] = true

func has_pending_promotion() -> bool:
	return bool(_data.get("pending_promotion", false))

## The rank held before the still-unshown promotion window began (1 if never set / already shown).
func pending_promotion_from_rank() -> int:
	return int(_data.get("pending_promotion_from_rank", 1))

## Pops the queued PROMOTED popup flag (memory only; caller saves) — mirrors
## take_pending_challenge_rewards()'s one-shot consume idiom.
func clear_pending_promotion() -> void:
	_data["pending_promotion"] = false

## HORDE NIGHT's own best-wave record — horde never touches the shared best_wave/best_bosses
## above (a different game: no boss ever spawns), so it gets a dedicated track instead.
func horde_best_wave() -> int:
	return int(_data.get("horde_best_wave", 0))

func record_horde_best_wave(wave: int) -> void:
	_data["horde_best_wave"] = maxi(horde_best_wave(), wave)

## OVERTIME's own best clock-out — kept separate because OVERTIME's preset run_time headstart
## would otherwise unfairly inflate a shared "best clock-out reached" comparison.
func overtime_best_clockout_seconds() -> float:
	return float(_data.get("overtime_best_clockout_seconds", 0.0))

func record_overtime_best_clockout(run_time: float) -> void:
	_data["overtime_best_clockout_seconds"] = maxf(overtime_best_clockout_seconds(), run_time)

## HARDCORE's own best clock-out (HARDCORE keeps mode == "endless", so the shared best_wave/
## best_bosses/best_clockout records above still apply to it normally; this is an ADDITIONAL
## dedicated track, not a replacement).
func hardcore_best_clockout_seconds() -> float:
	return float(_data.get("hardcore_best_clockout_seconds", 0.0))

func record_hardcore_best_clockout(run_time: float) -> void:
	_data["hardcore_best_clockout_seconds"] = maxf(hardcore_best_clockout_seconds(), run_time)

## Pack A: lifetime count of runs WON via the Dawn Extraction chopper LZ.
func shifts_survived() -> int:
	return int(_data.get("shifts_survived", 0))

## Called once from GameOver.trigger_win(). Caller saves.
func add_shift_survived() -> void:
	_data["shifts_survived"] = shifts_survived() + 1

# --- Lifetime records (Pack D: Stats + juice, v0.1.51) ---
# Flushed exactly once per run, from GameOver._finish_run (death/win) or PauseMenu's
# _abandon_run_payout (quit/restart) — both already gate their ENTIRE payout block behind
# RunStats.paid_out, so add_lifetime_run() below rides that same once-per-run guarantee (it has
# no guard of its own — see LifetimeRecords.merge_run's doc comment). "runs played" and "shifts
# survived" are deliberately NOT duplicated here — games_played()/shifts_survived() above already
# track those; the RECORDS view reads them directly instead of a redundant counter that could drift.

func total_kills() -> int:
	return int(_data.get("total_kills", 0))

func total_bosses() -> int:
	return int(_data.get("total_bosses", 0))

func total_elites() -> int:
	return int(_data.get("total_elites", 0))

func total_coins_earned() -> int:
	return int(_data.get("total_coins_earned", 0))

## Highest run_time (seconds) ever reached at payout, 0.0 if no run has ever paid out yet.
## Display via ShiftClock.clock_string(best_clockout_seconds()).
func best_clockout_seconds() -> float:
	return float(_data.get("best_clockout_seconds", 0.0))

func armageddons_pulled() -> int:
	return int(_data.get("armageddons_pulled", 0))

## Adds a rarity-9 (Armageddon) pull. Called from the single Inventory.add() chokepoint, so every
## path that can hand the player a weapon instance (crate opens, daily/milestone gun rewards, DEV
## grants, and any future path — e.g. Pack B's weapon fusion — that ends up calling Inventory.add)
## is covered automatically. Caller saves.
func add_armageddon_pulled() -> void:
	_data["armageddons_pulled"] = armageddons_pulled() + 1

## Base weapon id -> lifetime kill count, for the equipped-at-kill-time gun (see RunStats.kills /
## LifetimeRecords.merge_run doc comments for why a single run-wide counter is enough).
func gun_kills() -> Dictionary:
	return _data.get("gun_kills", {})

## Lifetime count of successful weapon-fusion feeds (Pack B, v0.1.52).
func fusions() -> int:
	return int(_data.get("fusions", 0))

## Called once per successful Inventory.fuse() call. Caller saves.
func add_fusion() -> void:
	_data["fusions"] = fusions() + 1

# --- Challenge board + Daily Shift (Pack C, v0.1.53) ---
# Rotation/progress math is pure (scripts/logic/ChallengeProgress.gd, mirrors LifetimeRecords) —
# these wrappers just read/write _data and persist, the same shape as add_lifetime_run() above.

func challenge_date() -> String:
	return String(_data.get("challenge_date", ""))

func challenge_progress() -> Dictionary:
	return _data.get("challenge_progress", {})

func challenge_completed() -> Array:
	return _data.get("challenge_completed", [])

## Lifetime count of completed challenges (RECORDS row).
func challenges_completed_total() -> int:
	return int(_data.get("challenges_completed_total", 0))

func pending_challenge_rewards() -> Array:
	return _data.get("pending_challenge_rewards", [])

## Pops every queued challenge-completion crate reward (already granted to the inventory — see
## ChallengeProgress._grant_crate) for the caller to reveal. Memory only; caller saves.
func take_pending_challenge_rewards() -> Array:
	var out: Array = pending_challenge_rewards().duplicate()
	_data["pending_challenge_rewards"] = []
	return out

## Run-scoped flush: call from GameOver._finish_run / PauseMenu._abandon_run_payout, inside the
## SAME RunStats.paid_out guard that already protects the coin payout + Pack D's lifetime
## records — see ChallengeProgress.apply_counters' doc comment for why that guard matters here
## too. `counters` = { counter_key: this run's tally } — see Challenges.gd's row docs for keys.
func flush_challenge_counters(counters: Dictionary) -> void:
	_data = ChallengeProgress.apply_counters(_data, counters, today_string())

## Immediate single-action bump (crate opened / weapon fused) — one-shot menu actions, not run
## payouts, so callers hit this directly at their own chokepoint with no paid_out guard needed.
func bump_challenge_counter(counter_key: String, amount: int = 1) -> void:
	_data = ChallengeProgress.bump_counter(_data, counter_key, float(amount), today_string())

## Today's active challenges, each row annotated with its live progress/completed state — for
## the RECORDS view's "TODAY'S CHALLENGES" section. Read-only: rotation itself is a pure function
## of the date (Challenges.active_ids_for), so this never needs to mutate _data — if today's
## rotation hasn't been touched by a flush yet, progress simply reads as 0/not-completed (the
## honest state), rather than showing yesterday's stale numbers.
func active_challenges() -> Array:
	var today := today_string()
	var stale := challenge_date() != today
	var progress: Dictionary = {} if stale else challenge_progress()
	var completed: Array = [] if stale else challenge_completed()
	var out: Array = []
	for id in Challenges.active_ids_for(today):
		var row: Dictionary = Challenges.by_id(id).duplicate()
		if row.is_empty():
			continue
		row["progress"] = float(progress.get(id, 0.0))
		row["completed"] = id in completed
		out.append(row)
	return out

## Daily Shift: one attempt per calendar day, consumed the moment the run STARTS (not on
## completion) — quitting or dying mid-shift does not refund the attempt (see MainMenu._on_daily_shift).
func is_daily_shift_available() -> bool:
	return String(_data.get("last_daily_shift_date", "")) != today_string()

func mark_daily_shift_started() -> void:
	_data["last_daily_shift_date"] = today_string()

func best_daily_score() -> int:
	return int(_data.get("best_daily_score", 0))

## Called at the same paid_out-guarded flush as everything else, both exit paths, whenever
## RunConfig.daily is true. Caller saves.
func record_daily_score(score: int) -> void:
	_data["best_daily_score"] = maxi(best_daily_score(), score)

## Flushes one run's lifetime-record deltas (memory only; caller saves). See the section header
## above for the exactly-once guarantee — this function itself is NOT idempotent. `update_clockout`
## (Pack G) defaults true for every existing caller; OVERTIME runs pass false so their preset
## run_time headstart can't inflate the shared best_clockout_seconds record (they get their own
## overtime_best_clockout_seconds instead — see record_overtime_best_clockout above). kills/
## bosses/elites/coins_earned/gun_kills are unaffected by this flag either way.
func add_lifetime_run(kills: int, bosses: int, elites: int, coins_earned: int, run_time: float, weapon_base_id: String, update_clockout: bool = true) -> void:
	_data = LifetimeRecords.merge_run(_data, kills, bosses, elites, coins_earned, run_time, weapon_base_id, update_clockout)

## EFFECTS toggle: screen shake + crit-kill hit-stop (Juice.gd / CameraShake.gd both read this
## directly — no manager autoload needed for two settings this small).
func shake_on() -> bool:
	return bool(_data.get("shake_on", true))

func set_shake_on(on: bool) -> void:
	_data["shake_on"] = on

# --- Owned crates (unopened) ---

func crates() -> Dictionary:
	return _data.get("crates", {})

func crate_count(id: String) -> int:
	return int(crates().get(id, 0))

func add_crate(id: String) -> void:
	var c: Dictionary = crates()
	c[id] = crate_count(id) + 1
	_data["crates"] = c

func remove_crate(id: String) -> bool:
	if crate_count(id) <= 0:
		return false
	var c: Dictionary = crates()
	var n := crate_count(id) - 1
	if n <= 0:
		c.erase(id)
	else:
		c[id] = n
	_data["crates"] = c
	return true

# --- Character unlocks ---

func unlocked_characters() -> Array:
	return _data.get("unlocked_characters", ["ryan"])

func is_character_unlocked(id: String) -> bool:
	return id in unlocked_characters()

## Adds an id to the owned set (memory only; caller saves). No-op if already owned.
func unlock_character(id: String) -> void:
	var list: Array = _data.get("unlocked_characters", [])
	if id not in list:
		list.append(id)
		_data["unlocked_characters"] = list

# --- Weapon-loot inventory (managed by the Inventory autoload) ---

func weapons_raw() -> Array:
	return _data.get("weapons", [])

func set_weapons(list: Array) -> void:
	_data["weapons"] = list

func equipped_weapon() -> String:
	return String(_data.get("equipped_weapon", ""))

func set_equipped_weapon(uid: String) -> void:
	_data["equipped_weapon"] = uid

# --- Coworker inventory (Pack C, v0.1.64) — mirrors the weapon-loot accessors above verbatim;
# no Inventory.gd wrapper, since coworkers aren't weapons and don't share its cap/scrap chokepoints.

func coworkers() -> Array:
	return _data.get("coworkers", [])

func set_coworkers(list: Array) -> void:
	_data["coworkers"] = list

func equipped_coworker() -> String:
	return String(_data.get("equipped_coworker", ""))

func set_equipped_coworker(uid: String) -> void:
	_data["equipped_coworker"] = uid

# --- First-run onboarding hints ---

## True once the player has cleared all three first-run HUD hints (move/shoot/dash).
func tutorial_done() -> bool:
	return bool(_data.get("tutorial_done", false))

## Marks the hint sequence complete. Memory only — deliberately does NOT save_game();
## the existing end-of-run payout save (GameOver / PauseMenu quit) persists it, so a run
## that ends mid-tutorial (e.g. the player dies) leaves the flag false and hints replay
## next run, by design.
func set_tutorial_done() -> void:
	_data["tutorial_done"] = true

# --- Audio settings (read by SoundManager on boot; toggled from PauseMenu/MainMenu) ---

func sfx_on() -> bool:
	return bool(_data.get("sfx_on", true))

func set_sfx_on(on: bool) -> void:
	_data["sfx_on"] = on

func music_on() -> bool:
	return bool(_data.get("music_on", true))

func set_music_on(on: bool) -> void:
	_data["music_on"] = on

# --- Commendations wall (Pack H: v0.1.59) ---
# Pure check/grant math lives in Commendations.gd (data) + CommendationProgress.gd (merge math,
# mirrors ChallengeProgress.gd's zero-autoload-dependency shape) — these wrappers just read/write
# _data and persist, the same shape as the challenge-board wrappers above.

func apocalypse_pulled() -> int:
	return int(_data.get("apocalypse_pulled", 0))

## Adds a rarity-8 (Apocalypse) pull. Called from the SAME Inventory.add() chokepoint as
## add_armageddon_pulled() above (see that doc comment for the "every weapon-granting path is
## covered" reasoning — it applies identically here). Caller saves.
func add_apocalypse_pulled() -> void:
	_data["apocalypse_pulled"] = apocalypse_pulled() + 1

## LIFETIME crates opened — distinct from the challenge board's "crates_opened" counter
## (ChallengeProgress/bump_challenge_counter above), which belongs to one day's rotation and wipes
## on a date change. This one never resets; it exists solely for the BIG SPENDER commendation.
func crates_opened_total() -> int:
	return int(_data.get("crates_opened_total", 0))

## Called once per real crate settle, from the SAME Inventory.commit_crate chokepoint that already
## bumps the daily challenge-board counter. Caller saves.
func add_crate_opened() -> void:
	_data["crates_opened_total"] = crates_opened_total() + 1

## Lifetime count of Daily Shift attempts STARTED (mirrors is_daily_shift_available/
## mark_daily_shift_started's "consumed on start, not completion" semantics above) — for the
## REGULAR commendation. Caller saves.
func dailies_played() -> int:
	return int(_data.get("dailies_played", 0))

func add_daily_played() -> void:
	_data["dailies_played"] = dailies_played() + 1

## Highest single-run actual coin payout (`earned`) ever, across EVERY run (contrast
## best_daily_score above, which is Daily-Shift-only). Flushed at the same paid_out-guarded blocks
## as everything else, both exit paths. For the PAYDAY commendation.
func best_run_payout() -> int:
	return int(_data.get("best_run_payout", 0))

func record_best_run_payout(earned: int) -> void:
	_data["best_run_payout"] = maxi(best_run_payout(), earned)

## LIFETIME THE BASEMENT gauntlets cleared (Pack E, Task 5) — never resets. Distinct from
## RunStats.basements_cleared, which is the per-run count read by the pay-stub row.
func basements_cleared() -> int:
	return int(_data.get("basements_cleared", 0))

## Called once per real gauntlet clear, from Basement._start_reward() — the SAME chokepoint
## that owns its own save_game() flush, mirroring add_crate_opened()'s idiom above (a mid-run
## grant with no guaranteed later flush before a crash/force-quit, so it flushes immediately
## rather than waiting for the paid_out-guarded end-of-run block). Caller saves.
func add_basement_cleared() -> void:
	_data["basements_cleared"] = basements_cleared() + 1

## Ids of one-time Commendation badges already earned (persisted; never un-earned once granted).
func commendations_earned() -> Array:
	return _data.get("commendations_earned", [])

func is_commendation_earned(id: String) -> bool:
	return id in commendations_earned()

## Count of badges earned so far — the RECORDS wall's "N/18" readout (denominator is
## Commendations.all().size(), the single source of truth for the badge count).
func commendations_earned_count() -> int:
	return commendations_earned().size()

## The live counter value backing one commendation row (e.g. the "1,840" half of "1,840 / 2,500")
## — wraps Commendations.value_for so the wall UI never touches the raw save dict directly
## (mirrors active_challenges()'s read-only wrapper shape above).
func commendation_value(id: String) -> int:
	return int(Commendations.value_for(Commendations.by_id(id), _data))

func pending_commendation_rewards() -> Array:
	return _data.get("pending_commendation_rewards", [])

## Pops every queued commendation-earned reveal (already granted — see
## check_and_grant_commendations below) for the caller to reveal. Memory only; caller saves.
## Mirrors take_pending_challenge_rewards() above.
func take_pending_commendation_rewards() -> Array:
	var out: Array = pending_commendation_rewards().duplicate()
	_data["pending_commendation_rewards"] = []
	return out

## Checks every Commendation row against the current save data and grants (rank XP + crate) any
## newly crossed one exactly once — see CommendationProgress.check_and_grant's doc comment for the
## full idempotence/exactly-once contract (identical guarantees to add_lifetime_run/
## flush_challenge_counters above). Call at BOTH the run-flush chokepoints (GameOver._finish_run /
## PauseMenu._abandon_run_payout, inside their RunStats.paid_out guard, right before that block's
## own save_game()) AND at menu entry (MainMenu._check_free_rewards) — the latter catches lifetime
## counters that only change between runs (crates opened, weapons fused, challenges completed).
## Memory only; caller saves.
func check_and_grant_commendations() -> void:
	_data = CommendationProgress.check_and_grant(_data)

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
	"unlocked_characters": ["ryan"],   # character ids the player owns (Ryan free)
	"crates": {},             # owned unopened crates: crate_id -> count
	"dev_bonus_granted": false,     # DEV (legacy): the old 10k one-time bonus flag (superseded)
	"dev_bonus_v2_granted": false,  # DEV (temporary): the 30k start bonus already given?
	"last_daily_claim": "",   # "YYYY-MM-DD" of the last claimed daily-login reward ("" = never)
	"games_played": 0,        # completed runs (game-over count) — drives the every-10-games reward
	"game_rewards_given": 0,  # how many 10-game milestone rewards have already been handed out
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

func mark_daily_claimed() -> void:
	_data["last_daily_claim"] = today_string()

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

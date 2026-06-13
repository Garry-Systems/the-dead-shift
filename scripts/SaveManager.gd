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
	# Merge: copy known keys whose type matches the default, ignore everything else.
	for key in DEFAULTS:
		if parsed.has(key) and typeof(parsed[key]) == typeof(DEFAULTS[key]):
			_data[key] = parsed[key]
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
	if dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
	var err := dir.rename("savegame.tmp", "savegame.json")
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

func best_wave() -> int:
	return int(_data.get("best_wave", 0))

func best_bosses() -> int:
	return int(_data.get("best_bosses", 0))

func record_run(wave: int, bosses: int) -> void:
	_data["best_wave"] = maxi(best_wave(), wave)
	_data["best_bosses"] = maxi(best_bosses(), bosses)

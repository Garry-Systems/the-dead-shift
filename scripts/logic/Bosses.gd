class_name Bosses
## Registry of built boss scenes. The Spawner picks from here (uniform random, no immediate
## repeat). Each entry is { "id": String, "scene": PackedScene, "name": String } with
## id == the boss's BOSS_ID, so the picker never has to instance a node just to read an id.
## "name" is pure display data (the HUD's boss bar via name_for()) — no behavior is keyed off it.

const _LIST: Array[Dictionary] = [
	{ "id": "brute", "scene": preload("res://scenes/bosses/Brute.tscn"), "name": "THE BRUTE" },
	{ "id": "brood_mother", "scene": preload("res://scenes/bosses/BroodMother.tscn"), "name": "THE BROOD MOTHER" },
	{ "id": "heat_tyrant", "scene": preload("res://scenes/bosses/HeatTyrant.tscn"), "name": "OVERCLOX, THE HEAT TYRANT" },
	# Night-shift staff (Pack 7)
	{ "id": "manager", "scene": preload("res://scenes/bosses/Manager.tscn"), "name": "THE MANAGER" },
	{ "id": "night_stocker", "scene": preload("res://scenes/bosses/NightStocker.tscn"), "name": "THE NIGHT STOCKER" },
	{ "id": "fryer", "scene": preload("res://scenes/bosses/Fryer.tscn"), "name": "THE FRYER" },
	{ "id": "courier", "scene": preload("res://scenes/bosses/Courier.tscn"), "name": "THE COURIER" },
	{ "id": "karen", "scene": preload("res://scenes/bosses/Karen.tscn"), "name": "THE KAREN" },
	{ "id": "tanker", "scene": preload("res://scenes/bosses/Tanker.tscn"), "name": "THE TANKER" },
	# Night Shift Stories (v0.1.68)
	{ "id": "mystery_shopper", "scene": preload("res://scenes/bosses/MysteryShopper.tscn"), "name": "THE MYSTERY SHOPPER" },
	{ "id": "mascot", "scene": preload("res://scenes/bosses/Mascot.tscn"), "name": "THE MASCOT" },
]

static func count() -> int:
	return _LIST.size()

## A uniform-random boss entry { id, scene, name }, excluding last_id when more than one boss exists.
static func pick(last_id: String) -> Dictionary:
	if _LIST.is_empty():
		return {}
	if _LIST.size() == 1:
		return _LIST[0]
	var pool: Array[Dictionary] = []
	for e in _LIST:
		if String(e["id"]) != last_id:
			pool.append(e)
	if pool.is_empty():
		pool = _LIST
	return pool[randi() % pool.size()]

## Display name for `id` (used by the HUD's boss bar), or "" if not found.
static func name_for(id: String) -> String:
	for e in _LIST:
		if String(e["id"]) == id:
			return String(e.get("name", ""))
	return ""

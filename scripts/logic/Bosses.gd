class_name Bosses
## Registry of built boss scenes. The Spawner picks from here (uniform random, no immediate
## repeat). Each entry is { "id": String, "scene": PackedScene } with id == the boss's BOSS_ID,
## so the picker never has to instance a node just to read an id.

const _LIST: Array[Dictionary] = [
	{ "id": "brute", "scene": preload("res://scenes/bosses/Brute.tscn") },
	{ "id": "brood_mother", "scene": preload("res://scenes/bosses/BroodMother.tscn") },
	{ "id": "heat_tyrant", "scene": preload("res://scenes/bosses/HeatTyrant.tscn") },
]

static func count() -> int:
	return _LIST.size()

## A uniform-random boss entry { id, scene }, excluding last_id when more than one boss exists.
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

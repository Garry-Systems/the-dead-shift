class_name LeechMote
extends Node2D
## Pooled VFX for lifesteal talents (Bloodthirst/Leech, later Mosquito): a small blood-red mote
## that lerps from the hit position to the player's (live) position over LEECH_MOTE_LIFE seconds,
## then frees itself. Capped at GameConfig.MAX_LEECH_MOTES concurrent motes — oldest evicted —
## mirroring the project's other capped-VFX idiom (Bullet/HazardZone's player_pools cap,
## Destructible's chain-detonation budget). No text: heal numbers are deliberately not part of
## the combat-text system (see CombatText.gd rule (e)); the mote + the player's rim blip are
## the whole tell.

const GROUP := "leech_motes"

var _from := Vector2.ZERO
var _target: Node2D = null   # tracked live so a moving player still reads as a clean lerp
var _to := Vector2.ZERO      # last-known target position (fallback once _target frees)
var _age := 0.0

## Spawns a (capped) mote flying from `from_pos` to `target`'s live position. Caller does NOT
## add_child first — spawn() owns placement into `tree.current_scene`.
static func spawn(from_pos: Vector2, target: Node2D, tree) -> void:
	if tree == null:
		return
	_evict_oldest(tree)
	var mote := LeechMote.new()
	mote._from = from_pos
	mote._target = target
	mote._to = target.global_position if is_instance_valid(target) else from_pos
	mote.global_position = from_pos
	mote.z_index = 20
	mote.add_to_group(GROUP)
	tree.current_scene.add_child(mote)

## Enforces MAX_LEECH_MOTES: frees the OLDEST live mote (group order == spawn order) before a
## new one spawns, same eviction shape as Bullet/HazardZone.cap_player_pools.
static func _evict_oldest(tree) -> void:
	var motes: Array = tree.get_nodes_in_group(GROUP)
	if motes.size() >= GameConfig.MAX_LEECH_MOTES:
		var oldest = motes[0]
		if is_instance_valid(oldest):
			oldest.remove_from_group(GROUP)
			oldest.queue_free()

func _process(delta: float) -> void:
	_age += delta
	if _age >= GameConfig.LEECH_MOTE_LIFE:
		queue_free()
		return
	if is_instance_valid(_target):
		_to = _target.global_position
	global_position = _from.lerp(_to, _age / GameConfig.LEECH_MOTE_LIFE)
	queue_redraw()

func _draw() -> void:
	var a := 1.0 - (_age / GameConfig.LEECH_MOTE_LIFE)
	draw_circle(Vector2.ZERO, GameConfig.LEECH_MOTE_RADIUS,
		Color(Hazards.BLOOD_RED.r, Hazards.BLOOD_RED.g, Hazards.BLOOD_RED.b, a))

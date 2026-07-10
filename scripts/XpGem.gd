extends Node2D
## An XP gem dropped by a dead enemy. When the player is within pickup range it
## drifts toward them; on contact it grants XP and disappears.

var value := GameConfig.XP_GEM_VALUE
var _player: Player

func _ready() -> void:
	# THE BASEMENT (Pack E): _ascend sweeps stranded gauntlet gems by group — the same
	# get_tree().get_nodes_in_group idiom every other cross-node lookup in this codebase already
	# uses — rather than walking every child of current_scene and type-checking each one.
	add_to_group("xp_gems")
	_player = get_tree().get_first_node_in_group("player") as Player

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist <= GameConfig.GEM_COLLECT_DISTANCE:
		SoundManager.play("gem")
		_player.add_xp(value)
		queue_free()
		return

	if dist <= _player.pickup_radius:
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * GameConfig.GEM_DRIFT_SPEED * delta

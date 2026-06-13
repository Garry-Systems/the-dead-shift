extends Node2D
## Root of the gameplay scene. On entry it resets the persistent difficulty autoload
## (it survives scene changes, so each run must start fresh), applies the chosen
## character's always-on perks, and tells the Spawner which mode to run. Choices come
## from the RunConfig autoload (defaults make launching this scene directly work in dev).

func _ready() -> void:
	DifficultyManager.reset()
	RunStats.reset()

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		Characters.apply_base(player, RunConfig.character_id)

	var spawner := get_tree().get_first_node_in_group("spawner")
	if spawner != null:
		spawner.mode = RunConfig.mode

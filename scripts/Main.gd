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
		player.global_position = GameConfig.FORECOURT_PLAYER_SPAWN   # the forecourt apron, clear of the store + pump row
		Characters.apply_base(player, RunConfig.character_id)
		player.set_dash_ability(Characters.dash_ability(RunConfig.character_id))
		_equip_loadout(player)

	var spawner := get_tree().get_first_node_in_group("spawner")
	if spawner != null:
		spawner.mode = RunConfig.mode

## Configures the gun from the player's equipped loot weapon, then applies the character's
## weapon-specific perk (this is what the old weapon-select StartUI used to do). The menu
## guarantees a weapon is equipped before a run starts; the grant_starter fallback only
## matters when launching Main.tscn directly in the editor.
func _equip_loadout(player: Player) -> void:
	if player.gun == null:
		return
	var inst := Inventory.equipped_instance()
	if inst.is_empty():
		# Direct editor launch (bypassing the menu's equip gate): seed + take the first gun.
		Inventory.grant_starter()
		var owned := Inventory.weapons()
		if not owned.is_empty():
			Inventory.equip(String(owned[0].get("uid", "")))
		inst = Inventory.equipped_instance()
	if not inst.is_empty():
		var base := WeaponInstance.base_def(inst)
		if not base.is_empty():
			player.gun.configure(base)
			player.gun.apply_loot(inst)
	Characters.apply_weapon(player, RunConfig.character_id)

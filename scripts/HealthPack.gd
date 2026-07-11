extends Node2D
## The game's FIRST HealthPack — dropped by AIR DROP (The Delivery Girl). Structurally
## XpGem.gd copied verbatim (drift-then-collect at the same GEM_COLLECT_DISTANCE, same
## pickup_radius drift gate), swapping add_xp() for player.heal(). Group "health_packs", NOT
## "xp_gems" — kept separate so a future basement/straggler sweep (the group-based cleanup idiom
## XpGem.gd's own header comment documents for gauntlet gems) can target one drop type without
## the other. No class_name (AirDropMarker instantiates it via a plain preload/new, per this
## task's scope — nothing else needs a cross-file static reference to this type). No .tscn:
## XpGem uses a Sprite2D + XpGem.tscn, but this is a pure-code Node2D (_draw below) since a
## 2-shape flat-color icon doesn't need a scene resource.

var _player: Player

func _ready() -> void:
	add_to_group("health_packs")
	_player = get_tree().get_first_node_in_group("player") as Player

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var dist := global_position.distance_to(_player.global_position)
	if dist <= GameConfig.GEM_COLLECT_DISTANCE:
		# heal()'s own hardcore/blood_pact gates decide whether this actually restores HP — NO
		# special-casing here, exactly like every other heal source in the codebase (see
		# Player.heal's own header comment: every live heal source routes through that one gate).
		_player.heal(GameConfig.ABILITY_AIRDROP_HEAL)
		SoundManager.play("gem")   # STAGED: T9 lands a dedicated pickup SFX id (this pack's convention — every ability effect plays "ui_tap"/"gem"/etc. until T9)
		queue_free()
		return

	if dist <= _player.pickup_radius:
		var dir := (_player.global_position - global_position).normalized()
		global_position += dir * GameConfig.GEM_DRIFT_SPEED * delta

func _draw() -> void:
	# Static icon, drawn once automatically on entering the tree (the Turret.gd fallback-shape
	# precedent — no queue_redraw() needed for content that never changes). Palette-strict:
	# PixelTheme.TEXT_DIM == C3 gray-tan (#8C8573) box, PixelTheme.ACCENT == C4 lavender-white
	# (#E0E5FF) cross — the brief's exact hexes, reusing the named constants instead of literals.
	draw_rect(Rect2(-10.0, -10.0, 20.0, 20.0), PixelTheme.TEXT_DIM)
	draw_rect(Rect2(-2.0, -7.0, 4.0, 14.0), PixelTheme.ACCENT)
	draw_rect(Rect2(-7.0, -2.0, 14.0, 4.0), PixelTheme.ACCENT)

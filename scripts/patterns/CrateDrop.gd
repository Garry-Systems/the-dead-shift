class_name CrateDrop
extends AttackPattern
## Not a player-damaging telegraph — a terrain pattern. After a brief windup (the shared
## PATTERN_WINDUP_MIN clamp gives it a short "drop it" beat) the boss leaves a solid cover
## obstacle behind its own direction of travel, then frees itself immediately. Reuses the
## Destructible class exactly like ObstacleField's ambient scatter (see Obstacles.gd), just a
## one-off solid "crate" row instead of a registry pick — and respects the SAME arena-wide
## GameConfig.OBSTACLE_HARD_CAP ObstacleField enforces, so a fast boss can't flood the arena with
## cover. no_cull stays false (Destructible's default) so ObstacleField culls it like any other
## ambient prop once it's far from the player.

func _on_telegraph_end() -> void:
	_drop()
	queue_free()

func _drop() -> void:
	if get_tree().get_nodes_in_group("destructibles").size() >= GameConfig.OBSTACLE_HARD_CAP:
		return
	var behind := Vector2.RIGHT
	if boss != null and is_instance_valid(boss) and "velocity" in boss:
		var v: Vector2 = boss.velocity
		if v.length() > 1.0:
			behind = -v.normalized()
	var row := {
		"kind": "cover", "shape": "rect", "size": GameConfig.STOCKER_CRATE_SIZE, "solid": true,
		"hp": GameConfig.CRATE_HP, "hazard_id": "", "loot": "", "gem_count": 0, "color": Obstacles.C3,
	}
	var d := Destructible.new()
	d.configure(row)
	get_tree().current_scene.add_child(d)
	d.global_position = global_position + behind * GameConfig.STOCKER_CRATE_DROP_DIST

func _draw() -> void:
	if _windup > 0.0:
		var s := GameConfig.STOCKER_CRATE_SIZE
		draw_rect(Rect2(Vector2(-s, -s), Vector2(s * 2.0, s * 2.0)), Color(0.549, 0.522, 0.451, 0.35))

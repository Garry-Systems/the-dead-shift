class_name CrateDrop
extends AttackPattern
## Not a player-damaging telegraph — a terrain pattern. After a brief windup (the shared
## PATTERN_WINDUP_MIN clamp gives it a short "drop it" beat) the boss leaves a solid cover
## obstacle behind its own direction of travel, then frees itself immediately. Reuses the
## Destructible class exactly like ObstacleField's ambient scatter (see Obstacles.gd), just a
## one-off solid "crate" row instead of a registry pick. no_cull stays false (Destructible's
## default) so ObstacleField culls it like any other ambient prop once it's far from the player.
##
## Two caps guard the drop:
## 1. The arena-wide GameConfig.OBSTACLE_HARD_CAP, counted over the no_cull-EXCLUDED baseline —
##    the same filter as ObstacleField._managed_destructibles() (replicated here rather than
##    reused: ObstacleField has no class_name, so its helper isn't reachable without a scene
##    lookup) — so permanent forecourt fixtures don't eat the boss's drop budget.
## 2. A dedicated STOCKER_CRATE_MAX on this boss's own crates ("stocker_crates" group): crates
##    dropped mid-fight near the player never distance-cull, so without this a long fight could
##    slowly wall the player in. At cap the OLDEST crate is evicted first (same immediate
##    remove_from_group + queue_free pattern as Bullet._cap_player_pools, so a same-frame
##    recount never sees the freed corpse).

func _on_telegraph_end() -> void:
	_drop()
	queue_free()

func _drop() -> void:
	_cap_stocker_crates()
	if _managed_destructible_count() >= GameConfig.OBSTACLE_HARD_CAP:
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
	d.add_to_group("stocker_crates")
	d.global_position = global_position + behind * GameConfig.STOCKER_CRATE_DROP_DIST

## Ambient-managed destructibles only — the same no_cull exclusion ObstacleField uses for its
## density/cap math, so this cap and ObstacleField's count the identical baseline.
func _managed_destructible_count() -> int:
	var n := 0
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if "no_cull" in d and d.no_cull:
			continue
		n += 1
	return n

## Enforces STOCKER_CRATE_MAX: at cap, evict the OLDEST stocker crate (group order == spawn
## order) before a new one lands. Groups are left immediately (queue_free is deferred) so any
## same-frame recount — this group's or the destructibles baseline above — stays accurate.
func _cap_stocker_crates() -> void:
	var crates := get_tree().get_nodes_in_group("stocker_crates")
	if crates.size() < GameConfig.STOCKER_CRATE_MAX:
		return
	var oldest = crates[0]
	if is_instance_valid(oldest):
		oldest.remove_from_group("stocker_crates")
		oldest.remove_from_group("destructibles")
		oldest.queue_free()

func _draw() -> void:
	if _windup > 0.0:
		var s := GameConfig.STOCKER_CRATE_SIZE
		draw_rect(Rect2(Vector2(-s, -s), Vector2(s * 2.0, s * 2.0)), Color(0.549, 0.522, 0.451, 0.35))

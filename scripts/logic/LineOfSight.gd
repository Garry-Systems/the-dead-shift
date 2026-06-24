class_name LineOfSight
## Stateless line-of-sight test against the solid-cover physics layer ONLY, so
## enemies/player/bullets never self-block. Used by LoS-aware target pickers and by
## projectiles that cover should absorb. No node state — unit-friendly.

## True if nothing on the cover layer blocks the segment from -> to (or if space is null).
static func is_clear(from: Vector2, to: Vector2, space: PhysicsDirectSpaceState2D) -> bool:
	if space == null:
		return true
	var q := PhysicsRayQueryParameters2D.create(from, to, GameConfig.COVER_MASK)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return space.intersect_ray(q).is_empty()

## The subset of `nodes` (each a Node2D) visible from `from` (not blocked by cover).
static func filter_visible(from: Vector2, nodes: Array, space: PhysicsDirectSpaceState2D) -> Array:
	var out: Array = []
	for n in nodes:
		if n == null or not is_instance_valid(n):
			continue
		if is_clear(from, (n as Node2D).global_position, space):
			out.append(n)
	return out

class_name TargetSelector
## Pure nearest-target math. No node dependency, so it can be unit-tested.

## Returns the index of the nearest point to `origin` within `max_range`,
## or -1 if the list is empty or nothing is in range. Uses squared distance
## (no sqrt) for speed.
static func nearest_index_in_range(origin: Vector2, points: Array[Vector2], max_range: float) -> int:
	var best := -1
	var best_sq := max_range * max_range
	for i in points.size():
		var d := points[i] - origin
		var sq := d.length_squared()
		if sq <= best_sq:
			best_sq = sq
			best = i
	return best

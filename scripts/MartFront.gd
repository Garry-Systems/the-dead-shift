class_name MartFront
extends Node2D
## BIG MART's set-piece (Transfer Stores, Task 3): the storefront the player spawns in front of
## when RunConfig.location == "big_mart". Instanced once from Main.tscn at world origin (0,0) as
## a sibling of Forecourt — same structural pattern (self-gates on its own location in _ready(),
## builds Destructible-based fixtures tagged no_cull so ObstacleField's scatter/cull never touches
## them, footprint sized to stay inside the existing FORECOURT_KEEPOUT_RADIUS/
## FORECOURT_SPAWN_KEEPOUT — both checks are unconditional, not forecourt-gated, so they already
## protect any location's origin set-piece for free) — but a different shape:
##   - one indestructible rubble-tint slab (the storefront) — blocks movement/bullets/LoS
##   - 2 checkout lanes of 3 "shelf" Destructibles each — same registry row as ambient/formation
##     shelves, so they chain-domino (chain_id "shelf") and drop gems exactly like any other shelf
## Unlike Forecourt's StoreBuilding, the slab needs no custom subclass: Destructible's rect shape
## already supports an independent half-height via `size_y` (T1's seam), so a plain Destructible
## configured with a wide/short rect row does the job.

func _ready() -> void:
	if RunConfig.location != "big_mart":
		return   # inactive location: no footprint, no cost (mirrors Forecourt's own gate)
	add_to_group("mart_front")
	_build_slab()
	_build_checkout_lane(-1)   # left lane
	_build_checkout_lane(1)    # right lane

## One big indestructible cover body — a plain rect Destructible (hp -1, "cover" kind, solid),
## tinted in the rubble/car cover family (Obstacles.C3) rather than Forecourt's store's C2 accent,
## so BIG MART reads as a distinct structure at a glance.
func _build_slab() -> void:
	var slab := Destructible.new()
	slab.configure({
		"kind": "cover", "shape": "rect",
		"size": GameConfig.MART_SLAB_HALF_SIZE.x, "size_y": GameConfig.MART_SLAB_HALF_SIZE.y,
		"solid": true, "hp": -1.0, "hazard_id": "", "loot": "", "gem_count": 0,
		"color": Obstacles.C3,
	})
	slab.no_cull = true
	add_child(slab)
	slab.position = GameConfig.MART_SLAB_POS

## 3 "shelf" Destructibles in a vertical run, offset `side` (-1 left / 1 right) of center — the
## checkout lane divider. Uses the SAME "shelf" row every ambient/formation shelf uses (by_id, not
## a hand-rolled dict), so these fixtures chain-domino + drop gems identically to any other shelf.
func _build_checkout_lane(side: int) -> void:
	var row := Obstacles.by_id("shelf")
	if row.is_empty():
		return   # defensive: registry row missing, skip rather than configure() on an empty dict
	var spacing := 2.0 * GameConfig.SHELF_HALF_W + 6.0   # same spacing formula as the formation pass
	var x := GameConfig.MART_LANE_X * float(side)
	for i in GameConfig.MART_LANE_SHELF_COUNT:
		var shelf := Destructible.new()
		shelf.configure(row)
		shelf.no_cull = true
		add_child(shelf)
		shelf.position = Vector2(x, GameConfig.MART_LANE_START_Y + float(i) * spacing)

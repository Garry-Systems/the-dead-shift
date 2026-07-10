class_name GarageBooth
extends Node2D
## THE PARKING GARAGE's set-piece (Transfer Stores, Task 4): the attendant booth + barrier arms
## the player spawns in front of when RunConfig.location == "parking_garage". Instanced once from
## Main.tscn at world origin (0,0) as a sibling of Forecourt/MartFront — same self-gating _ready()
## pattern (mirrors MartFront.gd, which itself mirrors Forecourt.gd): builds Destructible-based
## fixtures tagged no_cull so ObstacleField's scatter/cull/lattice never touches them, footprint
## sized to stay inside the existing FORECOURT_KEEPOUT_RADIUS/FORECOURT_SPAWN_KEEPOUT — both
## checks are unconditional, not location-gated, so they already protect any location's origin
## set-piece for free (the same fact MartFront's own doc comment establishes).
##   - one indestructible booth (solid "cover" rect, Obstacles.C2 concrete-family tint — the
##     garage's own family, distinct from MartFront's C3 rubble-tint slab)
##   - 2 barrier arms either side (soft "cover" rects — solid:false, size_y — a plain
##     Destructible already supports an independent rect half-height via T1's seam, so neither
##     fixture needs a custom subclass, exactly like MartFront's slab)
## Neither fixture is a registered Obstacles row (same as MartFront's slab/Forecourt's store) —
## they're one-off ad hoc dicts, not reused elsewhere, unlike MartFront's checkout-lane shelves
## which deliberately reuse the shared "shelf" row for chain-domino behavior. The booth/arms have
## no gameplay hook to share, so there's nothing to gain from a registry row here.

func _ready() -> void:
	if RunConfig.location != "parking_garage":
		return   # inactive location: no footprint, no cost (mirrors Forecourt's/MartFront's own gate)
	add_to_group("garage_booth")
	_build_booth()
	_build_arm(-1)   # left arm
	_build_arm(1)    # right arm

## One indestructible cover body — the attendant booth. Plain rect Destructible (hp -1, "cover"
## kind, solid), tinted Obstacles.C2 (the pillar/concrete family) so THE PARKING GARAGE reads as
## visually distinct from both the forecourt's store and BIG MART's slab.
func _build_booth() -> void:
	var booth := Destructible.new()
	booth.configure({
		"kind": "cover", "shape": "rect",
		"size": GameConfig.GARAGE_BOOTH_HALF_SIZE.x, "size_y": GameConfig.GARAGE_BOOTH_HALF_SIZE.y,
		"solid": true, "hp": -1.0, "hazard_id": "", "loot": "", "gem_count": 0,
		"color": Obstacles.C2,
	})
	booth.no_cull = true
	add_child(booth)
	booth.position = GameConfig.GARAGE_BOOTH_POS

## A single barrier arm, offset `side` (-1 left / 1 right) of center. Non-solid (the player walks
## through it — it's a gate-arm READ, not a physical chokepoint) rect using size_y, same "soft
## rect" idiom the brief calls for.
func _build_arm(side: int) -> void:
	var arm := Destructible.new()
	arm.configure({
		"kind": "cover", "shape": "rect",
		"size": GameConfig.GARAGE_ARM_HALF_SIZE.x, "size_y": GameConfig.GARAGE_ARM_HALF_SIZE.y,
		"solid": false, "hp": -1.0, "hazard_id": "", "loot": "", "gem_count": 0,
		"color": Obstacles.C2,
	})
	arm.no_cull = true
	add_child(arm)
	arm.position = Vector2(GameConfig.GARAGE_ARM_OFFSET_X * float(side), GameConfig.GARAGE_ARM_Y)

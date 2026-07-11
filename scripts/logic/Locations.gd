class_name Locations
## Registry of selectable run locations (Transfer Stores, v0.1.65). Pure data, no autoload
## dependency — mirrors Enemies.gd/Obstacles.gd so a headless boot-scene probe can verify every
## row and getter directly. Each location is a DATA PALETTE over the existing procedural arena
## (ground-tile swap + obstacle/spawn weight bias + one gimmick switch + copy) — no new tilemap,
## no new scene, no per-location code path in the base spawn/obstacle loop.
##
## Row fields:
##   id             : String      unique key
##   name           : String      display name (mode-panel picker, run-start banner, PROMOTED
##                                 popup's "TRANSFER APPROVED:" line, RECORDS best-row label)
##   rank_unlock    : int         Ranks.rank_for() value required to select this location
##                                 (0 = always unlocked — forecourt)
##   banner_sub     : String      run-start banner sub-line for non-forecourt locations (Task 2)
##   memo           : String      flavor copy for this location (may be "")
##   ground         : String      res:// path to this location's ground tile texture
##   obstacle_mults : Dictionary  Obstacles row id -> spawn-weight multiplier. Missing key = 1.0
##                                (no bias); 0.0 = that row never spawns here. Consumed by
##                                Obstacles.pick()'s optional `mults` param.
##   spawn_mults    : Dictionary  Enemies row id -> spawn-weight multiplier, same missing/0.0
##                                rule. Consumed by Enemies.pick()'s optional `mults` param.
##   gimmick        : String      "" | "mart" | "garage" — location-specific set-piece/rule
##                                switch read by ObstacleField/Destructible in later tasks.
##
## forecourt's obstacle_mults/spawn_mults were BOTH empty {} on purpose: every getter below
## resolves a missing dict entry to 1.0, so forecourt runs are byte-identical to today's arena
## (the #1 regression risk of this pack) — nothing about forecourt's actual spawn behavior
## changes by this registry existing.
## TASK 3 CATCH (superseded by Deep Clean item 16 — kept for history): Task 3 added a 7th row
## ("shelf", weight 55 — nonzero, since it must be pickable via the normal weighted roll in
## big_mart) to the SAME shared Obstacles.all() pool every location draws from. A missing dict
## entry defaults to mult 1.0, so back then this file pinned "shelf" to 0.0 in every non-mart
## location's obstacle_mults to keep it out — a footgun any FUTURE globally-weighted,
## location-exclusive row would have had to remember to repeat. Deep Clean (item 16) replaced
## that mechanism: Obstacles.gd rows now carry their own optional `locations` allowlist
## (`"shelf": ["big_mart"]`, `"pillar": ["parking_garage"]`), checked by Obstacles.pick() against
## the location_id ObstacleField threads through — the exclusion now lives with the row it
## protects, not scattered across every OTHER location that must opt it out. forecourt's
## obstacle_mults is back to {} (byte-identical to the pre-Task-3 registry), and parking_garage's
## dict no longer carries a "shelf" entry either — both rely on the allowlist instead. Pool-parity
## verified: the probe captures forecourt/big_mart/parking_garage's candidate row-id sets under
## both mechanisms and asserts they match exactly.
const _LIST: Array[Dictionary] = [
	{
		"id": "forecourt", "name": "THE FORECOURT", "rank_unlock": 0,
		"banner_sub": "", "memo": "",
		"ground": "res://art/ground.png",
		"obstacle_mults": {}, "spawn_mults": {}, "gimmick": "",
	},
	{
		"id": "big_mart", "name": "BIG MART", "rank_unlock": GameConfig.LOC_MART_RANK,
		"banner_sub": "attention shoppers.", "memo": "please disregard the shoppers.",
		"ground": "res://art/ground_mart.png",
		"obstacle_mults": { "barrel": 0.4, "car": 0.3, "transformer": 0.5, "shelf": 1.0 },
		"spawn_mults": { "shambler": 1.2, "runner": 1.3, "spitter": 0.5 },
		"gimmick": "mart",
	},
	{
		"id": "parking_garage", "name": "THE PARKING GARAGE", "rank_unlock": GameConfig.LOC_GARAGE_RANK,
		"banner_sub": "level 3 stays closed.", "memo": "level 3 has been closed for a while.",
		"ground": "res://art/ground_garage.png",
		"obstacle_mults": { "car": 2.2, "transformer": 0.0, "crate": 0.6, "pillar": 1.0 },
		"spawn_mults": { "shambler": 1.3, "exploder": 1.5 },
		"gimmick": "garage",
	},
]

## Full registry (read-only use). Returned by reference — do not mutate.
static func all() -> Array:
	return _LIST

## The row matching `id`, or {} if unknown.
static func by_id(id: String) -> Dictionary:
	for row in _LIST:
		if String(row["id"]) == id:
			return row
	return {}

## True if a player at `rank` (Ranks.rank_for()'s 1-indexed value) may select location `id`.
## Unknown id -> false (fail closed, never silently unlocks something that isn't registered).
static func unlocked(id: String, rank: int) -> bool:
	var row := by_id(id)
	if row.is_empty():
		return false
	return rank >= int(row["rank_unlock"])

## `obstacle_mults[row_id]` for location `id`. 1.0 ("no bias") if the location or the row id is
## missing from its dict — matches Obstacles.pick()'s missing-key default exactly.
static func obstacle_mult(id: String, row_id: String) -> float:
	var row := by_id(id)
	if row.is_empty():
		return 1.0
	var mults: Dictionary = row["obstacle_mults"]
	return float(mults.get(row_id, 1.0))

## `spawn_mults[enemy_id]` for location `id`. 1.0 ("no bias") if the location or the enemy id is
## missing from its dict — matches Enemies.pick()'s missing-key default exactly.
static func spawn_mult(id: String, enemy_id: String) -> float:
	var row := by_id(id)
	if row.is_empty():
		return 1.0
	var mults: Dictionary = row["spawn_mults"]
	return float(mults.get(enemy_id, 1.0))

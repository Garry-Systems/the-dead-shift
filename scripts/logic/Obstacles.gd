class_name Obstacles
## Registry of destructible obstacles the ObstacleField scatters around the player.
## Mirrors Enemies.gd: weighted + wave-gated pick(). The ObstacleField builds one
## parameterized Destructible node per picked row (obstacles are uniform — no per-type
## scene/art needed for v1; the Destructible draws itself).
##
## Row fields:
##   id        : String  unique key
##   kind      : String  "hazard" | "cover" | "loot"
##   shape     : String  "circle" | "rect"
##   size      : float   circle radius, or rect half-extent (px)
##   solid     : bool    true = on the cover layer (blocks movement + bullets + line of sight)
##   hp        : float   < 0 = indestructible
##   hazard_id : String  "" | "fire" | "acid" | "electric" (spawned on death)
##   loot      : String  "" | "gems"
##   gem_count : int     gems dropped when loot == "gems"
##   color     : Color   body fill (palette C3, or hazard accent so the player can read it)
##   weight    : int     relative spawn weight among eligible rows
##   min_wave  : int     not eligible until this wave
##   chain_id  : String  (optional, Transfer Stores Task 3) absent/"" = no chain; on death a
##                       destructible carrying this ALSO lights same-chain_id neighbors within
##                       SHELF_CHAIN_RADIUS (mart's "shelf" row) — a second, independent chain
##                       trigger alongside the pre-existing barrel (hazard_id == "fire") chain,
##                       sharing the same fuse timer + per-frame CHAIN_MAX_PER_TICK budget. See
##                       Destructible.light_fuse()/_die().
##   formation : bool    (optional, Transfer Stores Task 3) absent/false = scattered singly as
##                       today; true = ObstacleField spawns this row as an axis-aligned run of
##                       MART_FORMATION_LEN_MIN..MAX units instead of one instance. See
##                       ObstacleField._spawn_formation().
##   wail      : bool    (optional, Transfer Stores Task 4) absent/false = a normal car; true =
##                       this Destructible starts a WAIL_TIME "car alarm" wail on its first
##                       non-lethal take_damage — every WAIL_TAUNT_TICK it taunts nearby enemies
##                       toward itself, pulses a C4 ring, and plays a throttled alarm sting. NEVER
##                       baked into the "car" row itself (every non-garage car stays plain) — the
##                       garage's gimmick hook (ObstacleField._spawn_at) duplicates a picked "car"
##                       row and injects this flag only when gimmick == "garage". See
##                       Destructible._start_wail()/_taunt_nearby().
##   locations : Array[String] (optional, Deep Clean item 16) absent/empty = spawns at every
##                       location; non-empty = spawns ONLY at these Locations.gd ids. Checked by
##                       Obstacles.pick() against the `location_id` it's called with, alongside
##                       (not instead of) the existing wave/mults gates. Replaces the old
##                       mechanism of pinning a globally-weighted row to 0.0 in every OTHER
##                       location's obstacle_mults (Locations.gd used to do this for "shelf") —
##                       a systemic footgun future locations would have had to remember to repeat.
##                       "pillar" also carries this field for documentation parity even though its
##                       weight:0 already keeps it out of pick()'s pool regardless (lattice-only,
##                       fetched via by_id() — see that row's own comment).

const C3 := Color(0.549, 0.522, 0.451)   # gray-tan props (palette)
# PARKING GARAGE (Transfer Stores, Task 4): pillar/concrete family. The SAME hex as
# PixelTheme.ACCENT_DIM / MannequinDecoy's own "C2 indigo" comment — no new hue invented (palette
# strict), reused directly the same way C3 already covers crate/car/rubble/shelf regardless of
# their otherwise-unrelated roles.
const C2 := Color(0.239, 0.0, 0.6)       # C2 indigo (palette) — pillar row + GarageBooth fixtures
# Body tints so the player reads a hazard prop at a glance — the 3 sanctioned exceptions.
const FIRE_TINT := Color(0.85, 0.45, 0.2)   # palette exception (orange = fire barrel)
const ACID_TINT := Color(0.4, 0.8, 0.2)     # palette exception (green = chem drum)
const ELEC_TINT := Color(0.2, 0.8, 0.85)    # palette exception (cyan = transformer)

## Built fresh each call (rows reference GameConfig consts) — small + read-only by use.
static func all() -> Array:
	return [
		{ "id":"barrel",      "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.BARREL_HP,      "hazard_id":"fire",     "loot":"",     "gem_count":0,                       "color":FIRE_TINT, "weight":30, "min_wave":1 },
		{ "id":"chem_drum",   "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.DRUM_HP,        "hazard_id":"acid",     "loot":"",     "gem_count":0,                       "color":ACID_TINT, "weight":25, "min_wave":2 },
		{ "id":"transformer", "kind":"hazard", "shape":"rect",   "size":20.0, "solid":false, "hp":GameConfig.TRANSFORMER_HP, "hazard_id":"electric", "loot":"",     "gem_count":0,                       "color":ELEC_TINT, "weight":20, "min_wave":3 },
		{ "id":"crate",       "kind":"loot",   "shape":"rect",   "size":16.0, "solid":false, "hp":GameConfig.CRATE_HP,       "hazard_id":"",         "loot":"gems", "gem_count":GameConfig.CRATE_GEM_COUNT, "color":C3,                    "weight":40, "min_wave":1 },
		{ "id":"car",         "kind":"cover",  "shape":"rect",   "size":48.0, "solid":true,  "hp":GameConfig.COVER_CAR_HP,   "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":18, "min_wave":1 },
		{ "id":"rubble",      "kind":"cover",  "shape":"circle", "size":34.0, "solid":true,  "hp":GameConfig.RUBBLE_HP,      "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":15, "min_wave":1 },
		# Fuel pump (Pack 5): a bigger, meaner barrel — ~1.5x hp/blast radius/fire pool, chains
		# through the same fuse mechanic (hazard_id "fire"). Also fetched verbatim via by_id() to
		# place the 3 fixed forecourt pumps.
		{ "id":"fuel_pump",   "kind":"hazard", "shape":"rect",   "size":GameConfig.FUEL_PUMP_SIZE, "solid":false, "hp":GameConfig.FUEL_PUMP_HP,   "hazard_id":"fire",     "loot":"",     "gem_count":0,                       "color":FIRE_TINT, "weight":10, "min_wave":4,
			"burst_radius":GameConfig.FUEL_PUMP_BURST_RADIUS, "burst_damage":GameConfig.FUEL_PUMP_BURST_DAMAGE, "burst_force":GameConfig.FUEL_PUMP_BURST_FORCE, "hazard_scale":GameConfig.FUEL_PUMP_HAZARD_SCALE },
		# BIG MART (Transfer Stores, Task 3): soft, non-solid loot cover -- walk-through, gem
		# drop on death, chains via chain_id (NOT hazard_id -- hazard_id stays "" so it never
		# blasts or spawns a hazard zone, see Destructible._die()'s chain_id branch), and
		# spawns as a run of units via ObstacleField's formation pass (both ambient + cluster
		# paths -- see ObstacleField._spawn_formation()). weight 55 matters everywhere the
		# `locations` allowlist below permits -- Deep Clean (item 16) confines it to big_mart via
		# that field instead of the old "pin every OTHER location's mult to 0.0" mechanism.
		# min_wave 1 like crate/barrel (no gating beyond location).
		{ "id":"shelf", "kind":"loot", "shape":"rect", "size":GameConfig.SHELF_HALF_W, "size_y":GameConfig.SHELF_HALF_H, "solid":false, "hp":GameConfig.SHELF_HP, "hazard_id":"", "loot":"gems", "gem_count":GameConfig.SHELF_GEMS, "color":C3, "weight":55, "min_wave":1, "chain_id":"shelf", "formation":true, "locations":["big_mart"] },
		# PARKING GARAGE (Transfer Stores, Task 4): weight 0 -- this row can NEVER be returned by
		# pick()'s weighted roll (see pick()'s `if w <= 0: continue`; _weight() returns 0 for a
		# 0-weight row regardless of `mults`, so even a future non-empty mults dict can't turn it
		# on by accident). Pillars exist ONLY via ObstacleField._lattice_pass()'s deterministic
		# per-world-cell placement, which fetches this row directly via by_id() and configure()s a
		# plain Destructible with it -- pick()'s pool never sees it. Indestructible (hp -1) circle
		# cover, same "solid":true family as car/rubble. `locations` kept parallel to shelf's for
		# data-model consistency even though weight:0 already makes it moot for pick()'s pool.
		{ "id":"pillar", "kind":"cover", "shape":"circle", "size":GameConfig.PILLAR_RADIUS, "solid":true, "hp":-1.0, "hazard_id":"", "loot":"", "gem_count":0, "color":C2, "weight":0, "min_wave":1, "locations":["parking_garage"] },
	]

## A weighted-random row among types whose min_wave <= wave. Falls back to the first row.
##
## `mults` (Transfer Stores, v0.1.65): optional Locations.obstacle_mults-shaped Dictionary,
## row id -> weight multiplier. Default {} is the exact pre-existing code path (no per-row
## multiply, byte-identical weights/roll/total to today). A non-empty dict re-weights
## `roundi(weight * mult)` per eligible row (missing id = mult 1.0); a row that rounds to <= 0
## is excluded from the pool entirely (0.0 = "never spawns here" per the registry's contract).
##
## `location_id` (Deep Clean, item 16): the CURRENT run's Locations.gd id, threaded through the
## same way `mults` already is (ObstacleField is the one caller, both params set once at run
## start). A row carrying a non-empty `locations` field is excluded from the pool unless
## `location_id` is one of its entries — checked BEFORE the weight/mults gate below, same
## short-circuit shape as the min_wave check right above it. Default "" is the pre-existing
## code path for every row whose `locations` field is absent/empty (every row except shelf/
## pillar) -- those rows' eligibility is completely unaffected by this param.
static func pick(wave: int, mults: Dictionary = {}, location_id: String = "") -> Dictionary:
	var rows := all()
	var pool: Array = []
	var total := 0
	for e in rows:
		if int(e["min_wave"]) > wave:
			continue
		var locs: Array = e.get("locations", [])
		if not locs.is_empty() and not locs.has(location_id):
			continue
		var w := _weight(e, mults)
		if w <= 0:
			continue
		pool.append(e)
		total += w
	if pool.is_empty() or total <= 0:
		return rows[0]
	var roll := randi() % total
	for e in pool:
		roll -= _weight(e, mults)
		if roll < 0:
			return e
	return pool[pool.size() - 1]

## Effective spawn weight for row `e` under `mults`. Empty `mults` short-circuits to the row's
## plain int weight (no float roundtrip at all) — the default-arg call path stays byte-identical.
static func _weight(e: Dictionary, mults: Dictionary) -> int:
	var w := int(e["weight"])
	if mults.is_empty():
		return w
	return roundi(float(w) * float(mults.get(String(e["id"]), 1.0)))

## The row matching `id`, or {} if not found. Used for a fixed placement (Forecourt's fuel
## pumps) that wants the exact row rather than a weighted/wave-gated pick.
static func by_id(id: String) -> Dictionary:
	for e in all():
		if String(e["id"]) == id:
			return e
	return {}

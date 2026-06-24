# Environmental Hazards + Destructible Cover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add destructible obstacles that scatter around the roaming player and, when destroyed, burst into lingering hazard zones (fire/acid/electric) damaging both player and enemies — plus solid cover that blocks movement, bullets, and line of sight.

**Architecture:** Two stateless registries cloned from `Enemies.gd` (`Obstacles` = destructibles, `Hazards` = zone tuning). One code-built `Destructible` (`StaticBody2D`, drawn via `_draw`, no art) parameterized by a row. Lingering pools are a `HazardZone` built on the existing `AttackPattern` lifecycle (the both-sides, throttled cousin of `ZoneFill`). Barrel blasts reuse `Shockwave.blast()` verbatim; chains use a per-node fuse (deferred ripple, never recursion). A new `ObstacleField` node scatters/culls obstacles and drops wave clusters. The project's first 2 physics layers (cover, destructible) are added with the single-bit API so the all-on-layer-1 model is preserved.

**Tech Stack:** Godot 4.6 + GDScript. No unit-test harness in this project — **verification is the headless compile gate + a logic probe** (the project's established workflow).

## Global Constraints

- **Config over code:** every tunable number lives in `scripts/logic/GameConfig.gd` as a `const`; registries reference those consts, never inline literals.
- **Palette:** strict 4-color (void `#0A001A`, indigo `#3D0099`, gray-tan `#8C8573`, lavender `#E0E5FF`) **plus exactly 3 gameplay-color exceptions** declared as consts with a `# palette exception` comment: orange (fire), cyan (electric), green (toxic).
- **Hazards damage BOTH the player and enemies**; anti-herding levers are `ENEMY_HAZARD_DMG_MULT` / `PLAYER_HAZARD_DMG_MULT` + flat (non-wave-scaling) dps.
- **Collision layers:** set per-bit with `set_collision_*_value(bit, true)` ONLY — never assign `collision_mask =` (would wipe the default bit 1 and silently kill enemy contact damage).
- **Chain reactions deferred** (per-node fuse), never synchronous recursion.
- **Mobile caps:** ≤`OBSTACLE_HARD_CAP` destructibles and ≤`MAX_HAZARD_ZONES` zones; ~5 Hz throttled hazard ticks.

### Verification commands (used by every task)

**Compile gate** (run from WSL bash; the Windows binary runs via interop). Expected: **no output** (two benign lines are excluded: the `menu_background.jpg` JPEG-decode line and the `shutdown_adb_on_exit` EditorSettings line emitted on every headless quit):

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --quit 2>&1 \
  | grep -iE "error|SCRIPT ERROR|Parse Error" | grep -v "menu_background.jpg" | grep -v "shutdown_adb_on_exit"
```

**Logic probe** (Task 15 only):

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --script res://probe_obstacles.gd 2>&1 \
  | grep -iE "PROBE|error" | grep -v "shutdown_adb_on_exit"
```

### File map

| File | Responsibility | Tasks |
|---|---|---|
| `scripts/logic/GameConfig.gd` | all tuning consts + layer bits | 1 |
| `project.godot` | name the 2 new physics layers | 2 |
| `scripts/logic/Obstacles.gd` | destructible registry (data) | 3 |
| `scripts/logic/Hazards.gd` | hazard-zone tuning registry (data) | 4 |
| `scripts/logic/LineOfSight.gd` | stateless cover-only LoS test | 5 |
| `scripts/RunStats.gd`, `scripts/GameOver.gd` | crate coin tally | 6 |
| `scripts/HazardZone.gd` | lingering both-sides pool (fire/acid/electric) | 7 |
| `scripts/Destructible.gd` | code-built obstacle: damage, death dispatch, chain, draw | 8 |
| `scripts/Bullet.gd` | cover-block + destructible-hit + ricochet LoS | 9 |
| `scripts/Enemy.gd` | cover mask + anti-wedge steering | 10 |
| `scripts/Player.gd` | cover mask | 11 |
| `scripts/Gun.gd` | LoS-filter the lightning/cone target pools | 12 |
| `scripts/BossProjectile.gd` | cover absorbs enemy projectiles | 13 |
| `scripts/ObstacleField.gd`, `scenes/Main.tscn` | scatter / cull / wave drops (turns the system ON) | 14 |
| `probe_obstacles.gd` | throwaway logic probe | 15, 16 |

**Ordering note:** integration edits (Tasks 9-13) land *before* the spawner (`ObstacleField`, Task 14), so no obstacle exists until every system that touches one is ready. The game compiles and runs after every task; obstacle behavior simply isn't visible until Task 14.

---

## Task 1: GameConfig — all hazard tunables + layer bits

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (append a new block at the end of the file)

- [ ] **Step 1: Append the const block**

At the end of `scripts/logic/GameConfig.gd`, add:

```gdscript

# --- Environmental hazards: collision layers (the project's first) ---
const COVER_LAYER_BIT := 4              # solid cover (cars/rubble) physics layer (1-indexed)
const DESTRUCTIBLE_LAYER_BIT := 5       # non-solid props (barrels/drums/crates) physics layer
const COVER_MASK := 1 << 3              # bitmask for layer 4, for raycast line-of-sight queries

# --- Obstacles: placement & caps ---
const OBSTACLE_TARGET_COUNT := 12       # destructibles to keep near the player (ambient density)
const OBSTACLE_HARD_CAP := 24           # max destructibles alive at once
const MAX_HAZARD_ZONES := 10            # max lingering hazard pools at once
const OBSTACLE_SPAWN_INTERVAL := 0.4    # seconds between ambient top-up spawns
const OBSTACLE_SPAWN_MIN_R := 1000.0    # ambient spawn ring inner radius (just off-screen)
const OBSTACLE_SPAWN_MAX_R := 1300.0    # ambient spawn ring outer radius
const OBSTACLE_KEEP_RADIUS := 1400.0    # destructibles within this count toward the target density
const OBSTACLE_CULL_RADIUS := 1800.0    # free destructibles beyond this from the player
const OBSTACLE_CULL_INTERVAL := 1.0     # seconds between cull passes
const OBSTACLE_CLUSTER_SIZE := 4        # obstacles dropped at each new wave
const OBSTACLE_CLUSTER_RADIUS := 500.0  # spread of a wave-drop cluster around the player

# --- Obstacle HP (flat; no wave scaling) + crate loot ---
const BARREL_HP := 60.0
const DRUM_HP := 70.0
const TRANSFORMER_HP := 90.0
const COVER_CAR_HP := 400.0             # tanky but clearable
const RUBBLE_HP := -1.0                 # < 0 = indestructible
const CRATE_HP := 25.0
const CRATE_GEM_COUNT := 5
const CRATE_COIN_REWARD := 3            # coins added to the run tally when a crate is smashed

# --- Barrel burst (reuses Shockwave) + chain ---
const BARREL_BURST_DAMAGE := 60.0
const BARREL_BURST_RADIUS := 140.0
const BARREL_BURST_FORCE := 900.0
const BARREL_CHAIN_RADIUS := 160.0      # neighboring barrels within this get a chain fuse
const CHAIN_DELAY := 0.1                # seconds before a fused barrel detonates (a time-spread ripple)
const CHAIN_MAX_PER_TICK := 3           # max fused barrels that may detonate in one frame (excess slips to the next)

# --- Hazard zones (lingering pools) ---
const HAZARD_WINDUP := 0.12             # brief arm/telegraph for a destructible-spawned zone (bypasses the boss PATTERN_WINDUP clamp)
const HAZARD_TICK_INTERVAL := 0.2       # ~5 Hz both-sides damage tick (not per-frame)
const ENEMY_HAZARD_DMG_MULT := 1.0      # anti-herding lever (lower if herding dominates)
const PLAYER_HAZARD_DMG_MULT := 1.0     # keep area-denial genuinely risky to the player
const FIRE_DPS := 25.0
const FIRE_RADIUS := 110.0
const FIRE_DURATION := 4.0
const ACID_DPS := 18.0
const ACID_RADIUS := 120.0
const ACID_DURATION := 5.0
const ACID_SLOW_FACTOR := 0.45          # acid slows whatever stands in it
const ACID_SLOW_DURATION := 0.5         # refreshed each tick while inside
const ACID_DRIFT_SPEED := 20.0          # px/sec gentle cloud drift
const ELEC_DPS := 15.0
const ELEC_RADIUS := 130.0
const ELEC_DURATION := 3.0
const ELEC_STUN_DURATION := 0.4         # electric stuns enemies (reuses freeze); refreshed each tick
const ELEC_CHAIN_COUNT := 4             # enemies the field arcs to per tick (visual + in-radius)

# --- Enemy anti-wedge steering around cover ---
const ENEMY_COVER_STEER := 0.8          # tangential nudge strength when a chasing enemy hits cover
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/logic/GameConfig.gd
git commit -m "Hazards: GameConfig tunables + cover/destructible layer bits"
```

---

## Task 2: project.godot — name the 2 new physics layers

**Files:**
- Modify: `project.godot` (add a `[layer_names]` section)

- [ ] **Step 1: Add the section**

In `project.godot`, after the `[input_devices]` section (before `[dotnet]`), add:

```
[layer_names]

2d_physics/layer_4="cover"
2d_physics/layer_5="destructible"
```

(Cosmetic — names the bits in the editor; the gameplay reads `GameConfig.COVER_LAYER_BIT` etc.)

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "Hazards: name cover/destructible physics layers"
```

---

## Task 3: Obstacles.gd — destructible registry

**Files:**
- Create: `scripts/logic/Obstacles.gd`

**Interfaces:**
- Produces: `Obstacles.all() -> Array` (rows), `Obstacles.pick(wave: int) -> Dictionary`. Row keys: `id, kind, shape, size, solid, hp, hazard_id, loot, gem_count, color, weight, min_wave`.

- [ ] **Step 1: Write the file**

Create `scripts/logic/Obstacles.gd`:

```gdscript
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

const C3 := Color(0.549, 0.522, 0.451)   # gray-tan props (palette)

## Built fresh each call (rows reference GameConfig consts) — small + read-only by use.
static func all() -> Array:
	return [
		{ "id":"barrel",      "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.BARREL_HP,      "hazard_id":"fire",     "loot":"",     "gem_count":0,                       "color":Color(0.85,0.45,0.2), "weight":30, "min_wave":1 },
		{ "id":"chem_drum",   "kind":"hazard", "shape":"circle", "size":18.0, "solid":false, "hp":GameConfig.DRUM_HP,        "hazard_id":"acid",     "loot":"",     "gem_count":0,                       "color":Color(0.4,0.8,0.2),   "weight":25, "min_wave":2 },
		{ "id":"transformer", "kind":"hazard", "shape":"rect",   "size":20.0, "solid":false, "hp":GameConfig.TRANSFORMER_HP, "hazard_id":"electric", "loot":"",     "gem_count":0,                       "color":Color(0.2,0.8,0.85),  "weight":20, "min_wave":3 },
		{ "id":"crate",       "kind":"loot",   "shape":"rect",   "size":16.0, "solid":false, "hp":GameConfig.CRATE_HP,       "hazard_id":"",         "loot":"gems", "gem_count":GameConfig.CRATE_GEM_COUNT, "color":C3,                    "weight":40, "min_wave":1 },
		{ "id":"car",         "kind":"cover",  "shape":"rect",   "size":48.0, "solid":true,  "hp":GameConfig.COVER_CAR_HP,   "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":18, "min_wave":1 },
		{ "id":"rubble",      "kind":"cover",  "shape":"circle", "size":34.0, "solid":true,  "hp":GameConfig.RUBBLE_HP,      "hazard_id":"",         "loot":"",     "gem_count":0,                       "color":C3,                    "weight":15, "min_wave":1 },
	]

## A weighted-random row among types whose min_wave <= wave. Falls back to the first row.
static func pick(wave: int) -> Dictionary:
	var rows := all()
	var pool: Array = []
	var total := 0
	for e in rows:
		if int(e["min_wave"]) <= wave:
			pool.append(e)
			total += int(e["weight"])
	if pool.is_empty() or total <= 0:
		return rows[0]
	var roll := randi() % total
	for e in pool:
		roll -= int(e["weight"])
		if roll < 0:
			return e
	return pool[pool.size() - 1]
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/logic/Obstacles.gd
git commit -m "Hazards: Obstacles registry (barrel/drum/transformer/crate/car/rubble)"
```

---

## Task 4: Hazards.gd — hazard-zone tuning registry

**Files:**
- Create: `scripts/logic/Hazards.gd`

**Interfaces:**
- Produces: `Hazards.stats_for(hazard_id: String) -> Dictionary` with keys `color, dps, radius, duration, slow, slow_dur, stun, chain, drift`. Empty dict for unknown ids. Also `Hazards.ORANGE/GREEN/CYAN` color consts.

- [ ] **Step 1: Write the file**

Create `scripts/logic/Hazards.gd`:

```gdscript
class_name Hazards
## Lookup-only registry of hazard-zone tuning (like Bosses.gd). A Destructible reads
## stats_for(hazard_id) on death and hands it to a HazardZone. Numbers live in GameConfig.

# The 3 sanctioned gameplay-color exceptions to the strict 4-color palette
# (alongside FlameCone orange / Lightning cyan). Do NOT replace with palette lookups.
const ORANGE := Color(1.0, 0.55, 0.1)   # fire     — palette exception
const GREEN  := Color(0.4, 1.0, 0.2)    # toxic    — palette exception
const CYAN   := Color(0.2, 1.0, 1.0)    # electric — palette exception (matches Lightning.COLOR)

## Tuning dict for a hazard family, or {} for an unknown id.
static func stats_for(hazard_id: String) -> Dictionary:
	match hazard_id:
		"fire":
			return { "color":ORANGE, "dps":GameConfig.FIRE_DPS, "radius":GameConfig.FIRE_RADIUS, "duration":GameConfig.FIRE_DURATION,
				"slow":0.0, "slow_dur":0.0, "stun":0.0, "chain":0, "drift":0.0 }
		"acid":
			return { "color":GREEN, "dps":GameConfig.ACID_DPS, "radius":GameConfig.ACID_RADIUS, "duration":GameConfig.ACID_DURATION,
				"slow":GameConfig.ACID_SLOW_FACTOR, "slow_dur":GameConfig.ACID_SLOW_DURATION, "stun":0.0, "chain":0, "drift":GameConfig.ACID_DRIFT_SPEED }
		"electric":
			return { "color":CYAN, "dps":GameConfig.ELEC_DPS, "radius":GameConfig.ELEC_RADIUS, "duration":GameConfig.ELEC_DURATION,
				"slow":0.0, "slow_dur":0.0, "stun":GameConfig.ELEC_STUN_DURATION, "chain":GameConfig.ELEC_CHAIN_COUNT, "drift":0.0 }
		_:
			return {}
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/logic/Hazards.gd
git commit -m "Hazards: zone-tuning registry + the 3 exception colors"
```

---

## Task 5: LineOfSight.gd — stateless cover-only LoS test

**Files:**
- Create: `scripts/logic/LineOfSight.gd`

**Interfaces:**
- Produces: `LineOfSight.is_clear(from: Vector2, to: Vector2, space: PhysicsDirectSpaceState2D) -> bool`; `LineOfSight.filter_visible(from: Vector2, nodes: Array, space: PhysicsDirectSpaceState2D) -> Array`.

- [ ] **Step 1: Write the file**

Create `scripts/logic/LineOfSight.gd`:

```gdscript
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
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/logic/LineOfSight.gd
git commit -m "Hazards: LineOfSight helper (cover-only raycast)"
```

---

## Task 6: Crate coins — RunStats counter + payout

**Files:**
- Modify: `scripts/RunStats.gd`
- Modify: `scripts/GameOver.gd:69`

**Interfaces:**
- Produces: `RunStats.add_coins(n: int)`, `RunStats.bonus_coins: int`. (Lands before Task 8, which calls `add_coins`.)

- [ ] **Step 1: Add the counter to RunStats**

In `scripts/RunStats.gd`, replace:

```gdscript
var kills := 0
var bosses_killed := 0

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0
```

with:

```gdscript
var kills := 0
var bosses_killed := 0
var bonus_coins := 0     # coins from in-world sources (e.g. smashed crates), added to the run payout

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0
	bonus_coins = 0
```

- [ ] **Step 2: Add the accessor**

At the end of `scripts/RunStats.gd`, add:

```gdscript

## Add coins earned from an in-world source (smashed crate, etc.).
func add_coins(n: int) -> void:
	bonus_coins += n
```

- [ ] **Step 3: Fold bonus coins into the payout**

In `scripts/GameOver.gd`, replace the line (69):

```gdscript
	var earned := CoinReward.payout(wave, bosses, RunStats.kills)
```

with:

```gdscript
	var earned := CoinReward.payout(wave, bosses, RunStats.kills) + RunStats.bonus_coins
```

- [ ] **Step 4: Compile gate** — Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add scripts/RunStats.gd scripts/GameOver.gd
git commit -m "Hazards: RunStats.bonus_coins (crate loot) folded into run payout"
```

---

## Task 7: HazardZone.gd — lingering both-sides pool

**Files:**
- Create: `scripts/HazardZone.gd`

**Interfaces:**
- Consumes: `Hazards.stats_for` dict; `AttackPattern` base (setup/_process lifecycle); `Lightning` (electric arcs); enemy/player `take_damage`/`apply_slow`/`apply_freeze`.
- Produces: `HazardZone.configure_hazard(cfg: Dictionary)`. Group `"hazard_zones"`.

- [ ] **Step 1: Write the file**

Create `scripts/HazardZone.gd`:

```gdscript
class_name HazardZone
extends AttackPattern
## A lingering area-denial pool (fire/acid/electric) spawned by a destructible on death.
## The both-sides, throttled cousin of ZoneFill: damages enemies AND the player on a ~5 Hz
## tick (not every frame), refreshes slow (acid) / stun (electric), and arcs cyan bolts for
## electric. Built on AttackPattern for the telegraph -> active -> free lifecycle (ZoneFill is
## left untouched so the boss acid nest is unaffected). Draws one fading circle in the family's
## sanctioned exception color. Self-frees after `duration`.

var _color := Hazards.ORANGE
var _dps := 0.0
var _radius := 0.0
var _duration := 0.0
var _slow := 0.0
var _slow_dur := 0.0
var _stun := 0.0
var _chain := 0
var _drift := 0.0
var _drift_dir := Vector2.ZERO
var _armed := false
var _time_left := 0.0
var _tick := 0.0

## Configure from a Hazards.stats_for() dict. Caller sets global_position + add_child FIRST.
func configure_hazard(cfg: Dictionary) -> void:
	_color = cfg.get("color", Hazards.ORANGE)
	_dps = float(cfg.get("dps", 0.0))
	_radius = float(cfg.get("radius", 100.0))
	_duration = float(cfg.get("duration", 3.0))
	_slow = float(cfg.get("slow", 0.0))
	_slow_dur = float(cfg.get("slow_dur", 0.0))
	_stun = float(cfg.get("stun", 0.0))
	_chain = int(cfg.get("chain", 0))
	_drift = float(cfg.get("drift", 0.0))
	add_to_group("hazard_zones")
	setup(null, null, {})                  # AttackPattern grabs the player from the group
	_windup = GameConfig.HAZARD_WINDUP     # short arm, bypassing the boss PATTERN_WINDUP clamp
	var ang := randf_range(0.0, TAU)
	_drift_dir = Vector2(cos(ang), sin(ang))

func _on_telegraph_end() -> void:
	_armed = true
	_time_left = _duration

func _active(delta: float) -> void:
	if not _armed:
		return
	if _drift > 0.0:
		global_position += _drift_dir * _drift * delta
	_tick += delta
	if _tick >= GameConfig.HAZARD_TICK_INTERVAL:
		_apply(_tick)
		_tick = 0.0
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _apply(dt: float) -> void:
	var r2 := _radius * _radius
	var tree := get_tree()
	var enemies := tree.get_nodes_in_group("enemies")
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_squared_to(global_position) > r2:
			continue
		e.take_damage(_dps * dt * GameConfig.ENEMY_HAZARD_DMG_MULT)
		if not is_instance_valid(e):
			continue
		if _slow > 0.0 and e.has_method("apply_slow"):
			e.apply_slow(_slow, _slow_dur)
		if _stun > 0.0 and e.has_method("apply_freeze"):
			e.apply_freeze(_stun)
	if _chain > 0:
		_zap_arc(enemies)
	var player := tree.get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if (player as Node2D).global_position.distance_squared_to(global_position) <= r2:
			player.take_damage(_dps * dt * GameConfig.PLAYER_HAZARD_DMG_MULT)
			if _slow > 0.0 and player.has_method("apply_slow"):
				player.apply_slow(_slow, _slow_dur)

## Cosmetic cyan arcs to a few in-radius enemies (electric flavor; damage/stun already applied).
func _zap_arc(enemies: Array) -> void:
	var points: Array = [global_position]
	var r2 := _radius * _radius
	for e in enemies:
		if points.size() > _chain:
			break
		if e == null or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_squared_to(global_position) <= r2:
			points.append((e as Node2D).global_position)
	if points.size() >= 2:
		var bolt := Lightning.new()
		bolt.points = points
		get_tree().current_scene.add_child(bolt)

func _draw() -> void:
	if not _armed:
		draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.12))
		return
	var a := clampf(_time_left / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.30 * a))
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/HazardZone.gd
git commit -m "Hazards: HazardZone (both-sides throttled pool on the AttackPattern lifecycle)"
```

---

## Task 8: Destructible.gd — code-built obstacle

**Files:**
- Create: `scripts/Destructible.gd`

**Interfaces:**
- Consumes: an `Obstacles` row (via `configure`); `Hazards.stats_for`; `HazardZone`; `Shockwave`; `RunStats.add_coins`; `XpGem.tscn`.
- Produces: `Destructible.configure(row: Dictionary)`, `Destructible.take_damage(amount: float)`, `Destructible.light_fuse()`, `Destructible.is_fusing() -> bool`. Groups `"destructibles"` (+ `"cover"` if solid).

- [ ] **Step 1: Write the file**

Create `scripts/Destructible.gd`:

```gdscript
class_name Destructible
extends StaticBody2D
## A scatterable obstacle, built from an Obstacles row by ObstacleField (no scene/art —
## it draws itself). Solid cover (car/rubble) blocks movement + bullets + line of sight;
## non-solid props (barrel/drum/transformer/crate) are walk-through and take bullet damage.
## On death it spawns its hazard zone (barrels also burst via Shockwave + chain neighbors)
## or drops loot.

const _XP_GEM_SCENE := preload("res://scenes/XpGem.tscn")

var kind := "loot"
var shape := "circle"
var size := 18.0
var solid := false
var hp := 25.0
var hazard_id := ""
var loot := ""
var gem_count := 0
var color := Color(0.549, 0.522, 0.451)

var _health: Health
var _detonating := false
var _fuse := -1.0          # >= 0 = chain fuse counting down to detonation
var _hit_flash := 0.0

# Global per-frame chain-detonation budget (CHAIN_MAX_PER_TICK) so a dense barrel farm
# ripples across frames instead of detonating a whole wavefront on one frame.
static var _det_frame := -1
static var _det_count := 0

## Bake a row's fields. Call BEFORE add_child (so _ready can build the shape + layer).
func configure(row: Dictionary) -> void:
	kind = String(row["kind"])
	shape = String(row["shape"])
	size = float(row["size"])
	solid = bool(row["solid"])
	hp = float(row["hp"])
	hazard_id = String(row["hazard_id"])
	loot = String(row["loot"])
	gem_count = int(row["gem_count"])
	color = row.get("color", color)

func _ready() -> void:
	if hp >= 0.0:
		_health = Health.new(hp)
	_build_shape()
	add_to_group("destructibles")
	collision_layer = 0
	if solid:
		set_collision_layer_value(GameConfig.COVER_LAYER_BIT, true)
		add_to_group("cover")
	else:
		set_collision_layer_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)
	queue_redraw()

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	if shape == "rect":
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size * 2.0, size * 2.0)
		cs.shape = rect
	else:
		var circ := CircleShape2D.new()
		circ.radius = size
		cs.shape = circ
	add_child(cs)

func is_fusing() -> bool:
	return _fuse >= 0.0

func take_damage(amount: float) -> void:
	if hp < 0.0 or _detonating or _health == null:   # indestructible or already dying
		return
	_health.take_damage(amount)
	_hit_flash = 0.08
	queue_redraw()
	if _health.is_dead():
		_die()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			queue_redraw()
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			if not _claim_detonation_slot():
				_fuse = 0.001    # per-frame budget full — retry next frame (ripple)
				return
			_fuse = -1.0
			_die()

## Per-frame chain budget: at most CHAIN_MAX_PER_TICK fused barrels detonate per frame.
static func _claim_detonation_slot() -> bool:
	var frame := Engine.get_process_frames()
	if _det_frame != frame:
		_det_frame = frame
		_det_count = 0
	if _det_count >= GameConfig.CHAIN_MAX_PER_TICK:
		return false
	_det_count += 1
	return true

## A neighboring barrel lights this one after a short delay (ripple, not recursion).
func light_fuse() -> void:
	if _detonating or _fuse >= 0.0 or hazard_id != "fire":
		return
	_fuse = GameConfig.CHAIN_DELAY

func _die() -> void:
	if _detonating:
		return
	_detonating = true
	var tree := get_tree()
	# Barrel: instant Shockwave burst + chain-fuse nearby barrels.
	if hazard_id == "fire":
		var sw := Shockwave.new()
		tree.current_scene.add_child(sw)
		sw.global_position = global_position
		sw.blast(GameConfig.BARREL_BURST_RADIUS, GameConfig.BARREL_BURST_DAMAGE, GameConfig.BARREL_BURST_FORCE, null, null)
		var cr2 := GameConfig.BARREL_CHAIN_RADIUS * GameConfig.BARREL_CHAIN_RADIUS
		for d in tree.get_nodes_in_group("destructibles"):
			if d == self or not is_instance_valid(d):
				continue
			if (d as Node2D).global_position.distance_squared_to(global_position) <= cr2 and d.has_method("light_fuse"):
				d.light_fuse()
	# Lingering hazard zone (capped).
	if hazard_id != "" and tree.get_nodes_in_group("hazard_zones").size() < GameConfig.MAX_HAZARD_ZONES:
		var cfg := Hazards.stats_for(hazard_id)
		if not cfg.is_empty():
			var hz := HazardZone.new()
			tree.current_scene.add_child(hz)
			hz.global_position = global_position
			hz.configure_hazard(cfg)
	# Loot.
	if loot == "gems":
		_drop_loot(gem_count)
	queue_free()

func _drop_loot(n: int) -> void:
	var tree := get_tree()
	if _XP_GEM_SCENE != null:
		for i in n:
			var gem = _XP_GEM_SCENE.instantiate()
			tree.current_scene.add_child(gem)
			gem.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	RunStats.add_coins(GameConfig.CRATE_COIN_REWARD)

func _draw() -> void:
	var c := Color(1, 1, 1, 1) if _hit_flash > 0.0 else color
	var outline := Color(0.04, 0.0, 0.10)   # C1 void
	if shape == "rect":
		var r := Rect2(Vector2(-size, -size), Vector2(size * 2.0, size * 2.0))
		draw_rect(r, c)
		draw_rect(r, outline, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, size, c)
		draw_arc(Vector2.ZERO, size, 0.0, TAU, 24, outline, 2.0)
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/Destructible.gd
git commit -m "Hazards: Destructible (code-built obstacle: damage, death dispatch, chain fuse, draw)"
```

---

## Task 9: Bullet.gd — cover blocking + destructible hits + ricochet LoS

**Files:**
- Modify: `scripts/Bullet.gd`

- [ ] **Step 1: Add the layer mask bits in `_ready`**

Replace `_ready` (lines 27-28):

```gdscript
func _ready() -> void:
	body_entered.connect(_on_body_entered)
```

with:

```gdscript
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Detect cover (block) + destructibles (damage) in addition to enemies (default bit 1).
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)
	set_collision_mask_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)
```

- [ ] **Step 2: Branch cover + destructibles at the top of `_on_body_entered`**

Replace the start of `_on_body_entered` (lines 40-42):

```gdscript
func _on_body_entered(body) -> void:
	if not body.is_in_group("enemies") or body in _hit:
		return
```

with:

```gdscript
func _on_body_entered(body) -> void:
	# Solid cover damages-then-stops the bullet (cars are clearable; rubble shrugs it off).
	if body.is_in_group("cover"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return
	# Non-solid destructible props take raw damage (no talents); the bullet pierces or stops.
	if body.is_in_group("destructibles"):
		if body in _hit:
			return
		_hit.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if pierce_count > 0:
			pierce_count -= 1
			return
		queue_free()
		return
	if not body.is_in_group("enemies") or body in _hit:
		return
```

(Everything below this point in `_on_body_entered` is unchanged.)

- [ ] **Step 3: Make ricochet line-of-sight aware**

Replace `_nearest_unhit_enemy` (lines 81-92):

```gdscript
func _nearest_unhit_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for z in get_tree().get_nodes_in_group("enemies"):
		if z in _hit:
			continue
		var node := z as Node2D
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best
```

with:

```gdscript
func _nearest_unhit_enemy() -> Node2D:
	var space := get_world_2d().direct_space_state
	var best: Node2D = null
	var best_dist := INF
	for z in get_tree().get_nodes_in_group("enemies"):
		if z in _hit:
			continue
		var node := z as Node2D
		if not LineOfSight.is_clear(global_position, node.global_position, space):
			continue
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best
```

- [ ] **Step 4: Compile gate** — Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add scripts/Bullet.gd
git commit -m "Hazards: bullets blocked by cover, damage destructibles, ricochet respects LoS"
```

---

## Task 10: Enemy.gd — cover mask + anti-wedge steering

**Files:**
- Modify: `scripts/Enemy.gd`

- [ ] **Step 1: Add the cover bit to the enemy collision mask**

In `_ready`, replace (lines 44-46):

```gdscript
func _ready() -> void:
	add_to_group("enemies")
	_target = get_tree().get_first_node_in_group("player") as Player
```

with:

```gdscript
func _ready() -> void:
	add_to_group("enemies")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
	_target = get_tree().get_first_node_in_group("player") as Player
```

- [ ] **Step 2: Steer around cover in `_desired_velocity`**

Replace `_desired_velocity` (lines 184-187):

```gdscript
## Base movement intent (before slow/knockback). Override per enemy. Default = chase the player.
func _desired_velocity() -> Vector2:
	var dir := (_target.global_position - global_position).normalized()
	return dir * move_speed
```

with:

```gdscript
## Base movement intent (before slow/knockback). Override per enemy. Default = chase the player,
## but if we slid against solid cover last frame, steer tangentially around it (no pathfinding —
## just peel along the obstacle toward the player so a nav-less horde doesn't wedge on a car).
func _desired_velocity() -> Vector2:
	var dir := (_target.global_position - global_position).normalized()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other is Node and (other as Node).is_in_group("cover"):
			var tangent := Vector2(-col.get_normal().y, col.get_normal().x)
			if tangent.dot(dir) < 0.0:
				tangent = -tangent
			return (dir + tangent * GameConfig.ENEMY_COVER_STEER).normalized() * move_speed
	return dir * move_speed
```

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/Enemy.gd
git commit -m "Hazards: enemies collide with cover + anti-wedge tangential steering"
```

---

## Task 11: Player.gd — cover mask

**Files:**
- Modify: `scripts/Player.gd`

- [ ] **Step 1: Add the cover bit to the player collision mask**

In `_ready`, replace (lines 61-62):

```gdscript
func _ready() -> void:
	add_to_group("player")
```

with:

```gdscript
func _ready() -> void:
	add_to_group("player")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/Player.gd
git commit -m "Hazards: player collides with solid cover"
```

---

## Task 12: Gun.gd — LoS-filter the lightning/cone target pools

**Files:**
- Modify: `scripts/Gun.gd`

The pure pickers (`_nearest_enemy`/`_chain_targets`/`_enemies_in_cone`) stay intact; we just hand them the cover-visible subset of enemies.

- [ ] **Step 1: Filter in `_fire_lightning`**

Replace the first two lines of `_fire_lightning` (lines 298-300):

```gdscript
func _fire_lightning(dir: Vector2) -> bool:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var first := _nearest_enemy(global_position, gun_range, enemies)  # gun_range governs initial target acquisition only; chain hops use jump_radius
```

with:

```gdscript
func _fire_lightning(dir: Vector2) -> bool:
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	var first := _nearest_enemy(global_position, gun_range, enemies)  # gun_range governs initial target acquisition only; chain hops use jump_radius
```

- [ ] **Step 2: Filter in `_fire_cone`**

Replace the first three lines of `_fire_cone` (lines 333-336):

```gdscript
func _fire_cone(dir: Vector2) -> bool:
	_show_muzzle(dir.angle())
	var enemies := get_tree().get_nodes_in_group("enemies")
	var hits := _enemies_in_cone(global_position, dir, gun_range, cone_angle * 0.5, enemies)
```

with:

```gdscript
func _fire_cone(dir: Vector2) -> bool:
	_show_muzzle(dir.angle())
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	var hits := _enemies_in_cone(global_position, dir, gun_range, cone_angle * 0.5, enemies)
```

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/Gun.gd
git commit -m "Hazards: Tesla/Flamethrower skip enemies hidden behind cover (LoS-aware)"
```

---

## Task 13: BossProjectile.gd — cover absorbs enemy projectiles

**Files:**
- Modify: `scripts/BossProjectile.gd`

Boss/spitter projectiles are distance-checked `Node2D`s (no mask), so a swept LoS check is what makes cover block them too.

- [ ] **Step 1: Track the previous position + absorb on cover**

Replace `_process` (lines 26-35):

```gdscript
func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BOSS_PROJECTILE_LIFETIME:
		queue_free()
		return
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= HIT_RADIUS:
			_player.take_damage(damage)
			queue_free()
```

with:

```gdscript
func _process(delta: float) -> void:
	var prev := global_position
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BOSS_PROJECTILE_LIFETIME:
		queue_free()
		return
	# Solid cover absorbs the shot (swept check — robust against the projectile's speed).
	if not LineOfSight.is_clear(prev, global_position, get_world_2d().direct_space_state):
		queue_free()
		return
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= HIT_RADIUS:
			_player.take_damage(damage)
			queue_free()
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/BossProjectile.gd
git commit -m "Hazards: solid cover absorbs boss/spitter projectiles (both-sides blocking)"
```

---

## Task 14: ObstacleField.gd + Main.tscn — scatter / cull / wave drops (system ON)

**Files:**
- Create: `scripts/ObstacleField.gd`
- Modify: `scenes/Main.tscn`

**Interfaces:**
- Consumes: `Obstacles.pick`; `Destructible.configure`; `DifficultyManager.wave`; `Destructible.is_fusing`.

- [ ] **Step 1: Write the field**

Create `scripts/ObstacleField.gd`:

```gdscript
extends Node2D
## Scatters destructible obstacles around the roaming player, culls far ones (the distance
## culling enemies lack), and drops a cluster on each new wave. Mirrors Spawner's ring math.
## Self-inits from the "player" group like Spawner; lives as a sibling node in Main.tscn.

var _player: Node2D
var _spawn_t := 0.0
var _cull_t := 0.0
var _prev_wave := 1

func _ready() -> void:
	add_to_group("obstacle_field")
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_prev_wave = DifficultyManager.wave

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if DifficultyManager.wave != _prev_wave:
		_prev_wave = DifficultyManager.wave
		_drop_cluster()
	_spawn_t += delta
	if _spawn_t >= GameConfig.OBSTACLE_SPAWN_INTERVAL:
		_spawn_t = 0.0
		_ambient_topup()
	_cull_t += delta
	if _cull_t >= GameConfig.OBSTACLE_CULL_INTERVAL:
		_cull_t = 0.0
		_cull_far()

func _ambient_topup() -> void:
	var all_d := get_tree().get_nodes_in_group("destructibles")
	if all_d.size() >= GameConfig.OBSTACLE_HARD_CAP:
		return
	var keep2 := GameConfig.OBSTACLE_KEEP_RADIUS * GameConfig.OBSTACLE_KEEP_RADIUS
	var near := 0
	for d in all_d:
		if is_instance_valid(d) and (d as Node2D).global_position.distance_squared_to(_player.global_position) <= keep2:
			near += 1
	if near >= GameConfig.OBSTACLE_TARGET_COUNT:
		return
	var ang := randf_range(0.0, TAU)
	var r := randf_range(GameConfig.OBSTACLE_SPAWN_MIN_R, GameConfig.OBSTACLE_SPAWN_MAX_R)
	_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

func _drop_cluster() -> void:
	for i in GameConfig.OBSTACLE_CLUSTER_SIZE:
		if get_tree().get_nodes_in_group("destructibles").size() >= GameConfig.OBSTACLE_HARD_CAP:
			return
		var ang := randf_range(0.0, TAU)
		var r := randf_range(120.0, GameConfig.OBSTACLE_CLUSTER_RADIUS)
		_spawn_at(_player.global_position + Vector2(cos(ang), sin(ang)) * r)

func _spawn_at(pos: Vector2) -> void:
	var d := Destructible.new()
	d.configure(Obstacles.pick(DifficultyManager.wave))
	get_tree().current_scene.add_child(d)
	d.global_position = pos

func _cull_far() -> void:
	var cull2 := GameConfig.OBSTACLE_CULL_RADIUS * GameConfig.OBSTACLE_CULL_RADIUS
	for d in get_tree().get_nodes_in_group("destructibles"):
		if not is_instance_valid(d):
			continue
		if d.has_method("is_fusing") and d.is_fusing():
			continue   # don't cull a barrel mid chain-fuse
		if (d as Node2D).global_position.distance_squared_to(_player.global_position) > cull2:
			d.queue_free()
```

- [ ] **Step 2: Wire the node into Main.tscn**

In `scenes/Main.tscn`:

(a) Bump the scene's load step count — change line 1:

```
[gd_scene load_steps=15 format=3]
```

to:

```
[gd_scene load_steps=16 format=3]
```

(b) Add the script resource — after the `VirtualJoystick` ext_resource line (`id="16_joy"`, line 16), add:

```
[ext_resource type="Script" path="res://scripts/ObstacleField.gd" id="17_obstacle"]
```

(c) Add the node — after the `Spawner` node block (lines 41-42), add:

```
[node name="ObstacleField" type="Node2D" parent="."]
script = ExtResource("17_obstacle")
```

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/ObstacleField.gd scenes/Main.tscn
git commit -m "Hazards: ObstacleField scatter/cull/wave-drops, wired into Main (system live)"
```

---

## Task 15: Logic probe

**Files:**
- Create: `probe_obstacles.gd` (project root — throwaway, removed in Task 16)

- [ ] **Step 1: Write the probe**

Create `probe_obstacles.gd`:

```gdscript
extends SceneTree
## Throwaway logic probe for the obstacle/hazard registries. Run headless:
##   ...console.exe --path "...mobile-game" --headless --editor --script res://probe_obstacles.gd
## class_name globals (Obstacles/Hazards/GameConfig) are available in --script mode; autoloads
## and physics (LineOfSight) are NOT — those are verified by F5. Pure data only here.

func _init() -> void:
	var fails := 0

	# 1. Registry shape: 6 rows, all required keys present.
	var rows := Obstacles.all()
	if rows.size() != 6:
		print("PROBE FAIL: expected 6 obstacle rows, got %d" % rows.size()); fails += 1
	for row in rows:
		for key in ["id","kind","shape","size","solid","hp","hazard_id","loot","gem_count","weight","min_wave"]:
			if not row.has(key):
				print("PROBE FAIL: row %s missing key %s" % [row.get("id","?"), key]); fails += 1

	# 2. Wave gating: pick(1) never returns a min_wave>1 type (drum=2, transformer=3).
	for i in 400:
		var r1 := Obstacles.pick(1)
		if int(r1["min_wave"]) > 1:
			print("PROBE FAIL: pick(1) returned %s (min_wave %d)" % [r1["id"], r1["min_wave"]]); fails += 1
			break

	# 3. High wave can include gated types (statistical sanity over 400 picks).
	var seen := {}
	for i in 400:
		seen[String(Obstacles.pick(20)["id"])] = true
	if not seen.has("transformer"):
		print("PROBE FAIL: pick(20) never produced a transformer in 400 tries"); fails += 1

	# 4 + 5. Hazard tuning: families valid; fire no-slow, acid slows, electric stuns+chains.
	var fire := Hazards.stats_for("fire")
	var acid := Hazards.stats_for("acid")
	var elec := Hazards.stats_for("electric")
	if fire.is_empty() or float(fire["dps"]) <= 0.0:
		print("PROBE FAIL: fire hazard invalid"); fails += 1
	if float(fire["slow"]) != 0.0:
		print("PROBE FAIL: fire should not slow"); fails += 1
	if float(acid["slow"]) <= 0.0:
		print("PROBE FAIL: acid should slow"); fails += 1
	if float(elec["stun"]) <= 0.0 or int(elec["chain"]) <= 0:
		print("PROBE FAIL: electric should stun + chain"); fails += 1
	if not Hazards.stats_for("none").is_empty():
		print("PROBE FAIL: unknown hazard id should return {}"); fails += 1

	if fails == 0:
		print("PROBE PASS: all obstacle/hazard logic checks green")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()
```

- [ ] **Step 2: Run the probe**

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --script res://probe_obstacles.gd 2>&1 \
  | grep -iE "PROBE|error" | grep -v "shutdown_adb_on_exit"
```

Expected: `PROBE PASS: all obstacle/hazard logic checks green` (no `PROBE FAIL` lines). Fix the relevant task's code if any check fails.

- [ ] **Step 3: Commit (probe kept temporarily for re-runs)**

```bash
git add probe_obstacles.gd
git commit -m "Add throwaway logic probe for obstacle/hazard registries"
```

---

## Task 16: Final gate, cleanup, F5 handoff

**Files:**
- Delete: `probe_obstacles.gd`

- [ ] **Step 1: Full compile gate one more time** — Expected: no output.

- [ ] **Step 2: Remove the probe**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git rm probe_obstacles.gd
git commit -m "Remove obstacle/hazard logic probe (verified green)"
```

- [ ] **Step 3: F5 handoff checklist for Larry** (desktop, then phone)

**LAYER SAFETY FIRST** (the highest-blast-radius change — verify before anything else):
  - Enemies still reach and **bite** the player (contact damage works).
  - Player bullets still **hit and kill** enemies.

Then the feature:
  - Set `WAVE_DURATION := 6.0` temporarily (in `GameConfig.gd`) to reach later waves fast.
  - Barrels / drums / transformers / cars / crates **scatter** around you as you roam and **cull** when far behind.
  - Shoot a **barrel** → instant burst + a lingering **orange** fire pool; a cluster of barrels **chain-ripples** (no freeze/crash).
  - Shoot a **chem drum** → **green** acid cloud that drifts, ticks damage, and **slows**; a **transformer** → **cyan** electric field that stuns + arcs.
  - Stand in any hazard → **you** take damage; herd zombies into one → **they** take damage (acid slows them, electric stuns them).
  - **Cover:** you and zombies route around a **car** (no permanent wedge pile-up); your bullets AND a spitter's/boss's shots are **both** stopped by the car; **Tesla/Flamethrower** skip enemies hidden behind cover.
  - Smash a **crate** → XP gems scatter + the end-of-run coin total is higher.
  - Restore `WAVE_DURATION := 30.0`.

---

## Self-Review

**Spec coverage:**
- 4 families (barrel/fire, drum/acid, transformer/electric, car+rubble cover, crate loot) → Tasks 3, 4, 7, 8 ✓
- Both-sides hazard damage + anti-herding levers (flat dps, ENEMY/PLAYER mults) → Tasks 1, 7 ✓
- Placement: ambient scatter + cull + wave clusters → Task 14 ✓
- Cover blocks movement + all bullets (incl. boss/spitter) + LoS → Tasks 9, 10, 11, 13 ✓
- Enemies collide with cover + anti-wedge nudge → Task 10 ✓
- LoS-aware target-picking effects (lightning/cone/ricochet) → Tasks 9, 12 ✓
- Barrel Shockwave burst + fused chain + per-frame cap (CHAIN_MAX_PER_TICK) → Tasks 1, 8 ✓
- Crate loot (gems + coin tally) → Tasks 6, 8 ✓
- Palette exceptions (orange/cyan/green) as consts → Tasks 4, 7 ✓
- First 2 collision layers via single-bit API → Tasks 1, 2, 8, 9, 10, 11 ✓
- Mobile caps + ~5 Hz throttle → Tasks 1, 7, 14 ✓
- Hazard zones on the ZoneFill/AttackPattern lifecycle → Task 7 ✓

**Placeholder scan:** none — every step has concrete code/commands. (Art is intentionally `_draw`-rendered, not a placeholder — see Architecture.)

**Type/name consistency:**
- `GameConfig.COVER_LAYER_BIT` / `DESTRUCTIBLE_LAYER_BIT` / `COVER_MASK` defined in Task 1, used in Tasks 5, 8, 9, 10, 11.
- `Obstacles.pick`/`all` (Task 3) consumed by Task 14; row keys match Destructible.configure (Task 8) and the probe (Task 15).
- `Hazards.stats_for` keys (`color/dps/radius/duration/slow/slow_dur/stun/chain/drift`, Task 4) match HazardZone.configure_hazard reads (Task 7).
- `HazardZone.configure_hazard` (Task 7) called by Destructible._die (Task 8).
- `Destructible.configure/take_damage/light_fuse/is_fusing` (Task 8) match callers in Bullet (Task 9), Task 14, and HazardZone damage path (existing enemy/player methods).
- `LineOfSight.is_clear/filter_visible` (Task 5) match callers in Bullet (Task 9), Gun (Task 12), BossProjectile (Task 13).
- `RunStats.add_coins`/`bonus_coins` (Task 6) match Destructible._drop_loot (Task 8) and GameOver payout (Task 6).
- `Shockwave.blast(radius, damage, force, gun, player)` (existing) called with `(…, null, null)` in Task 8 — null gun/player supported by the existing `blast`.

# Environmental Hazards + Destructible Cover — Design Spec

**Date:** 2026-06-23
**Branch:** `feat/environmental-hazards`
**Status:** awaiting Larry review

## Goal

Add the first real **terrain layer** to the boundless arena: destructible objects that scatter around the player and, when destroyed, burst into **lingering hazard zones** that damage *both* the player and enemies. Turns a flat field into a tactical space — kite around cover, herd zombies into fire, blow chain-reacting barrels. Four destructible→hazard families ship in v1.

## Locked decisions (with Larry)

- **Four families, all in v1:**
  - **Explosive barrel** → instant burst (reuses `Shockwave`) **+ lingering fire pool** (🟠 orange). Barrels **chain-react**.
  - **Chem drum** → **acid/gas cloud** (🟢 green): damage-over-time **+ slow**, drifts slightly.
  - **Transformer** → **electric field** (🔵 cyan): damage **+ brief stun** + chain-zap.
  - **Cars / rubble** = solid cover; **wood crates** = soft, drop XP gems + a coin bump.
- **Hazards damage BOTH player and enemies** (tactical area-denial). Tuned so it can't trivialize the game (see Anti-trivialization).
- **Placement:** ambient scatter around the roaming player (spawn off-screen, cull far) **+** wave-linked cluster drops synced to `DifficultyManager.wave`.
- **Cover & bullets:** solid cover blocks **movement AND all bullets** (full line-of-sight), for both sides.
- **Enemies vs cover:** enemies **collide** with cover (keeps the kiting/funnel fantasy) **+ a cheap anti-wedge steering nudge** (they have no pathfinding). Small, sparse cover footprints. One-line fallback (drop cover from the enemy mask) if it wedges on device.
- **LoS-aware aiming, v1 scope:** only the **target-picking effects** (lightning / cone / ricochet) become cover-aware — they skip enemies behind cover. The **main gun stays manual fire-where-you-face** (no new projectile auto-aim), consistent with `2026-06-15-manual-aim-stop-to-shoot`.
- **Palette:** strict 4-color + the **three sanctioned gameplay-color exceptions** — orange (fire), cyan (electric), **green (toxic, new)**. Hazard *zones* use the exception colors; destructible *sprites* stay C3 gray-tan with a small accent in their hazard color so the player can read them.
- **Art:** new 32×32 palette placeholders via `gen_palette_sprites.py` (hand art later).

## Architecture

Max-reuse and **registry-faithful** — every new content file is a clone of `Enemies.gd`, every hazard zone is a `ZoneFill`/`AttackPattern` subclass, the barrel blast is `Shockwave.blast()` verbatim, crate loot is `XpGem`, and all numbers live in `GameConfig`. No central manager (keeps the repo's one-node-one-job style). *Two alternatives were explored and rejected: a pooled central `HazardManager` (best raw perf but a god-class, hardest to debug-by-feel) and per-hazard `Area2D` zones (cleanest but worst per-frame cost). The data-struct + single-renderer perf model is documented as a clean later upgrade in Non-goals.*

### 1. `scripts/logic/Obstacles.gd` — destructible registry
Mirrors `Enemies.gd` exactly: a `const _LIST: Array[Dictionary]`, stateless, returned read-only.
```
# row shape
{ id:String, scene:PackedScene(preload), kind:String,   # "hazard" | "cover" | "loot"
  solid:bool,        # true = on the cover layer (blocks movement + bullets + LoS)
  hp:float,          # <0 = indestructible (rubble)
  hazard_id:String,  # "" | "fire" | "acid" | "electric"
  loot:String,       # "" | "gems"
  gem_count:int, weight:int, min_wave:int }
```
v1 rows (all numbers reference `GameConfig`, never inline):
| id | kind | solid | hp | hazard_id | loot | min_wave |
|---|---|---|---|---|---|---|
| `barrel` | hazard | false | `BARREL_HP` | `fire` | "" | 1 |
| `chem_drum` | hazard | false | `DRUM_HP` | `acid` | "" | 2 |
| `transformer` | hazard | false | `TRANSFORMER_HP` | `electric` | "" | 3 |
| `car` | cover | **true** | `COVER_CAR_HP` | "" | "" | 1 |
| `rubble` | cover | **true** | `-1` (∞) | "" | "" | 1 |
| `crate` | loot | false | `CRATE_HP` | "" | `gems` | 1 |

`all()` returns `_LIST` by reference (do-not-mutate doc). `pick(wave)` = identical weighted + `min_wave` gating to `Enemies.pick`, falling back to `_LIST[0]`. Obstacle HP is **flat** (read straight from the row) — no wave-scaling curve (over-engineering for v1; flat reads correctly and avoids spongy late-wave barrels).

### 2. `scripts/logic/Hazards.gd` — hazard-zone tuning registry
Lookup-only (like `Bosses.gd`), keyed by `hazard_id`. `stats_for(id)` returns the dict a `HazardZone` consumes:
```
fire     -> { color:ORANGE, dps:FIRE_DPS,  radius:FIRE_RADIUS,  duration:FIRE_DURATION,
              slow:0.0, stun:0.0, chain:0, drift:0.0 }
acid     -> { color:GREEN,  dps:ACID_DPS,  radius:ACID_RADIUS,  duration:ACID_DURATION,
              slow:ACID_SLOW_FACTOR (dur ACID_SLOW_DURATION), stun:0.0, chain:0, drift:ACID_DRIFT_SPEED }
electric -> { color:CYAN,   dps:ELEC_DPS,  radius:ELEC_RADIUS,  duration:ELEC_DURATION,
              slow:0.0, stun:ELEC_STUN_DURATION, chain:ELEC_CHAIN_COUNT, drift:0.0 }
```
The orange/green/cyan `Color` consts live on `HazardZone` (not the palette), each tagged `# deliberate palette exception` — exactly the `FlameCone.CORE` / `Lightning.COLOR` precedent.

### 3. `scripts/HazardZone.gd extends ZoneFill` (which extends `AttackPattern`) — the lingering pools
Generalizes the existing acid-puddle so it serves all three families and damages **both sides**:
- `setup(null, player, cfg)` — `AttackPattern.setup` already grabs the player from the group if `boss` is null. Windup ≈ 0 (instant arm for destructible-spawned zones; `PATTERN_WINDUP_MIN` clamp respected — set a tiny telegraph, not a boss-length one).
- **Throttled tick:** override `_active(delta)` to accumulate `delta` and resolve victims only every `HAZARD_TICK_INTERVAL` (~0.2s ≈ 5Hz), **not** 60Hz. One `get_nodes_in_group("enemies")` call per tick window, reused for the whole zone.
- **Both sides:** each tick, for every enemy within `radius` (squared-distance, the `Shockwave` idiom) and for the player: apply `dps * interval` via existing `take_damage`, plus the family effect — `apply_slow` (acid), `apply_freeze`/stun (electric), `ignite` optional (fire). Player damage runs through `PLAYER_HAZARD_DMG_MULT`, enemy damage through `ENEMY_HAZARD_DMG_MULT`.
- **Status-refresh model:** enemies already self-tick burn/slow/freeze in `Enemy._physics_process`, so the zone *refreshes a status* on entry rather than re-dealing every tick where possible — cheap membership pass, reuses existing DoT machinery.
- **Electric chain:** on a tick, zap up to `chain` extra nearby enemies (group scan, like `Lightning`), draw cyan arcs via reused `Lightning.new()`.
- **Acid drift:** `global_position += drift_dir * drift * delta`, gentle, capped.
- `_draw()` = one `draw_circle` in the family exception color with the existing `_life`-fade alpha. Self-frees on `duration` (inherited lifecycle).
- **Cap:** `ObstacleField` enforces `MAX_HAZARD_ZONES` before a destructible spawns one.

### 4. `scripts/Destructible.gd` + `scenes/obstacles/*.tscn` — one generic destructible
One script for every family; behavior comes from the row.
- Scene = `Enemy.tscn` template: **`StaticBody2D`** root + `Sprite2D` + `CollisionShape2D`, `xp_gem_scene` export. (`StaticBody2D` so solid cover blocks movement for free.)
- `configure(row)` bakes `hp`/`kind`/`solid`/`hazard_id`/`loot`. `_ready()`: `add_to_group("destructibles")`; if `solid`, `add_to_group("cover")` + `set_collision_layer_value(GameConfig.COVER_LAYER_BIT, true)`; else `set_collision_layer_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)` (so the bullet `Area2D` `body_entered` fires on it). Sprite tint accent = hazard color.
- `take_damage(amount)` — **same method name/contract as `Enemy`**, so `Bullet`, `Shockwave`, cone, lightning all hit it for free once their group check includes `"destructibles"`. Indestructible rubble (`hp < 0`) ignores damage. Reuses the hit-flash shader.
- **On death** (`_die()`): set `_detonating = true` **first** (before any AoE that could re-enter), then:
  - `hazard_id == "fire"` → spawn a `Shockwave` (instant burst: `BARREL_BURST_DAMAGE` / `BARREL_BURST_RADIUS` / `BARREL_BURST_FORCE`) **+** queue a fire `HazardZone`; then **queue chain detonation** (see §5).
  - `hazard_id == "acid"|"electric"` → spawn the matching `HazardZone`.
  - `loot == "gems"` → drop `gem_count` `XpGem`s via the `Enemy._drop_gem` idiom; bump the run coin tally (see §9).
  - `queue_free()`.

### 5. Chain reactions — **deferred + budgeted** (critical safety)
A barrel's blast must detonate neighbors **without synchronous recursion** (the repo's `ExploderEnemy` detonates inside its own kill stack — recursing that across N barrels would stack-overflow / stall a frame on a phone, the #1 risk all three reviewers flagged).
- On a barrel `_die()`, after setting `_detonating = true`, scan group `destructibles` within `BARREL_CHAIN_RADIUS` for other barrels and schedule each via `call_deferred` / a tiny `CHAIN_DELAY` (~0.1s) fuse — **not** an immediate `take_damage`.
- Each barrel detonates **exactly once** (`_detonating` guard, set before the scan).
- A per-frame cap `CHAIN_MAX_PER_TICK` bounds how many detonate per frame, so a barrel farm ripples across frames (reads better, too).

### 6. `scripts/ObstacleField.gd` + `Main.tscn` wiring — placement, cull, wave drops
A scene node in `Main.tscn` **beside `Spawner`** (matches how `Spawner` is wired — self-inits from the `player` group in `_ready`; `Main.gd` needs no logic). Mirrors `Spawner`'s ring math; adds the culling enemies lack.
- **Ambient scatter** (timer `OBSTACLE_SPAWN_INTERVAL`): while live `destructibles` within `OBSTACLE_KEEP_RADIUS` `< OBSTACLE_TARGET_COUNT` and total `< OBSTACLE_HARD_CAP`, spawn `Obstacles.pick(wave)` at `player + Vector2.from_angle(randf()*TAU) * randf_range(OBSTACLE_SPAWN_MIN_R, OBSTACLE_SPAWN_MAX_R)` (off-screen, past the 960px portrait half-height — same rationale as `SPAWN_RADIUS`).
- **Cull** (timer `OBSTACLE_CULL_INTERVAL`): free any `destructible` past `OBSTACLE_CULL_RADIUS` **unless** it currently hosts a live hazard or was placed by a wave-drop (`pinned`) — never delete a barrel mid-burn or one the player is fighting near. Guard with `is_instance_valid`.
- **Wave-linked clusters:** cache `_prev_wave`; when `DifficultyManager.wave != _prev_wave`, drop `OBSTACLE_CLUSTER_SIZE` obstacles within `OBSTACLE_CLUSTER_RADIUS` of the player, family-biased to nastier types at higher waves. `pinned` for a grace period so they survive long enough to matter. (No wave signal exists — the documented `prev != cur` poll.)
- Respects `OBSTACLE_HARD_CAP` and (for zones) `MAX_HAZARD_ZONES`. At zone cap a barrel **still bursts** (`Shockwave`) but skips its lingering pool, so explosions never stop while pools stay bounded.
- **`process_mode` parity** with `DifficultyManager` so a menu pause can't desync the wave poll.

### 7. Collision layers — the project's first (handle with care)
Today **every** node is implicit `collision_layer=1 / mask=1`; bullets hit enemies *only* because of that shared default. Introduce exactly **two** named bits and use the **single-bit API** everywhere (`set_collision_*_value(bit, true)`) so the default bit 1 is never overwritten — this avoids the one-character `=` vs `|=` bug that would silently kill enemy contact damage game-wide.
- `project.godot`: name layer **4 = "cover"**, **5 = "destructible"**. `GameConfig.COVER_LAYER_BIT := 4`, `DESTRUCTIBLE_LAYER_BIT := 5`.
- **Solid cover** (`car`/`rubble`): `StaticBody2D` on layer 4.
- **Player + Enemy**: `set_collision_mask_value(4, true)` in `_ready` → `move_and_slide` blocks against cover for free, default mask 1 untouched.
- **Enemy anti-wedge:** in `Enemy._desired_velocity()`, if the last `move_and_slide` hit cover, add a small tangential component (slide *around* toward the player) so a nav-less horde peels around a car instead of grinding its back face. Keep cover footprints small/convex. Fallback if it still wedges on device: don't add bit 4 to the enemy mask (cover then blocks only player + bullets + LoS) — one line.
- **Bullet** (`Bullet.tscn`): `set_collision_mask_value(4, true)` (block on cover) + `set_collision_mask_value(5, true)` (register hits on barrels/drums/crates). In `_on_body_entered`, branch **before** the enemy path: `is_in_group("cover")` → `queue_free()`; `is_in_group("destructibles")` → `body.take_damage(...)` then pierce/`queue_free` (skip ignite/flash/talent procs on destructibles). Cover colliders are ≥ ~32px in their thin dimension so fast/upgraded bullets (≤~1200px/s ≈ 20px/step) can't tunnel `body_entered`.

### 8. LoS for target-picking effects + enemy projectiles
- `scripts/logic/LineOfSight.gd` (stateless, next to `TargetSelector`): `is_clear(from, to, space_state) -> bool` — one `intersect_ray` masked to the **cover bit only** (so enemies/player never self-block).
- `TargetSelector.gd`: **add** `nearest_visible_index_in_range(origin, points, max_range, space_state)` (nearest-first, returns the first **unblocked** candidate → 1–3 rays typical). Keep the original pure func for tests.
- `Gun.gd`: `_fire_lightning` first-target, `_chain_targets`, and `_enemies_in_cone` reject candidates failing `LineOfSight.is_clear`; `Bullet`'s ricochet picker too. → lightning/cone/ricochet never select an enemy behind cover. Main projectile gun unchanged.
- **Enemy projectiles** (`BossProjectile`, and `RangedEnemy` via it) are `Node2D` distance-checked, *not* on any mask — so mask-based cover blocking misses them. Add a per-frame **swept** `LineOfSight.is_clear(prev_pos, pos)` check; if cover is crossed, the projectile is **absorbed** (`queue_free`). Cheap (few enemy projectiles). This satisfies "cover blocks ALL bullets, both sides" — **not optional**.

### 9. Crate loot (reuse existing systems)
There is **no in-world coin entity** — coins are computed at run end by `CoinReward.payout()` from counters. So a crate drops `gem_count` `XpGem`s (existing in-world entity) **and** increments a `RunStats` counter folded into `CoinReward.payout()`. No new loot infra.

### 10. `scripts/logic/GameConfig.gd` — all tunables (starting values)
```
# --- Obstacles: placement & caps ---
const OBSTACLE_TARGET_COUNT := 12
const OBSTACLE_HARD_CAP := 24
const MAX_HAZARD_ZONES := 10
const OBSTACLE_SPAWN_INTERVAL := 0.4
const OBSTACLE_SPAWN_MIN_R := 1000.0      # just off the 960px portrait half-height
const OBSTACLE_SPAWN_MAX_R := 1300.0
const OBSTACLE_KEEP_RADIUS := 1400.0
const OBSTACLE_CULL_RADIUS := 1800.0
const OBSTACLE_CULL_INTERVAL := 1.0
const OBSTACLE_CLUSTER_SIZE := 4
const OBSTACLE_CLUSTER_RADIUS := 500.0

# --- Obstacle HP (flat, no wave scaling) ---
const BARREL_HP := 60.0
const DRUM_HP := 70.0
const TRANSFORMER_HP := 90.0
const COVER_CAR_HP := 400.0               # tanky but clearable; rubble = -1 (indestructible)
const CRATE_HP := 25.0
const CRATE_GEM_COUNT := 5

# --- Barrel burst (reuses Shockwave) + chain ---
const BARREL_BURST_DAMAGE := 60.0
const BARREL_BURST_RADIUS := 140.0
const BARREL_BURST_FORCE := 900.0
const BARREL_CHAIN_RADIUS := 160.0
const CHAIN_DELAY := 0.1
const CHAIN_MAX_PER_TICK := 3

# --- Hazard zones ---
const HAZARD_TICK_INTERVAL := 0.2         # ~5Hz, not per-frame
const ENEMY_HAZARD_DMG_MULT := 1.0        # anti-herding lever (lower if herding dominates)
const PLAYER_HAZARD_DMG_MULT := 1.0       # keep area-denial genuinely risky to the player
const FIRE_DPS := 25.0
const FIRE_RADIUS := 110.0
const FIRE_DURATION := 4.0
const ACID_DPS := 18.0
const ACID_RADIUS := 120.0
const ACID_DURATION := 5.0
const ACID_SLOW_FACTOR := 0.45
const ACID_SLOW_DURATION := 0.5
const ACID_DRIFT_SPEED := 20.0
const ELEC_DPS := 15.0
const ELEC_RADIUS := 130.0
const ELEC_DURATION := 3.0
const ELEC_STUN_DURATION := 0.4
const ELEC_CHAIN_COUNT := 4

# --- Collision layers (project's first) ---
const COVER_LAYER_BIT := 4
const DESTRUCTIBLE_LAYER_BIT := 5
```

### 11. Art — `art/obstacles/*.png` via `gen_palette_sprites.py`
Add functions for `barrel`, `chem_drum`, `transformer`, `car`, `rubble`, `crate` — 32×32 (cars larger), bodies in **C3 gray-tan** with a small accent stripe/glyph in the matching hazard exception color (orange/green/cyan) so the player reads a destructible's effect at a glance. Call them in the script's main block, run it. Hand art is a later follow-up (same as boss sprites).

## Integration contract (verified against current code)
- `ZoneFill extends AttackPattern` exists; `_active(delta)` + `_draw()` + self-free lifecycle confirmed; currently player-only at 60Hz → generalize to both-sides + throttled. ✓
- `Shockwave.blast(radius, damage, force, gun, player)` iterates group `enemies` by squared distance + `take_damage` → reused verbatim for the barrel burst. ✓
- `Enemy`/`Player` expose `take_damage(float)`, `apply_slow`, `apply_freeze`, `ignite`, `apply_knockback`. ✓
- `Bullet` is `Area2D` using `body_entered` (Godot 4.6 correct for hitting `CharacterBody2D`/`StaticBody2D` bodies). ✓
- `Enemy._drop_gem` idiom (instantiate `XpGem` → `current_scene.add_child` → set `global_position`) for crate loot. ✓
- `CoinReward.payout()` is a run-end formula over counters (no in-world coin) → crate "coins" = a `RunStats` bump. ✓
- `DifficultyManager.wave` is a public poll, no signal → `prev != cur` transition detection for cluster drops. ✓
- Zero `collision_layer`/`mask`/raycast usage anywhere today → this feature introduces the first two layers; **use `set_collision_*_value(bit, true)` only**. ✓

## Mobile-perf budget
Hard caps (≤24 destructibles, ≤10 zones); ~5Hz throttled zone ticks with one shared enemy scan; `ZoneFill`-based zones (no per-zone `Area2D`); **mask-based** bullet blocking (no per-bullet-per-frame raycast); LoS rays only at fire/acquisition time (1–3 per shot, cover-only mask); cull keeps node count bounded regardless of run length. Every cap/rate is a `GameConfig` const for weak-device tuning.

## Non-goals (deferred)
- Pooled `HazardManager` + data-struct single-renderer zone model (clean perf upgrade *if* a phone profile demands it; `HazardZone` reads from a cfg dict so the swap is a drop-in).
- True projectile **auto-aim** on the main gun (kept manual; flag-gated add later).
- Biomes / multiple maps, and scripted interactive set-pieces (the other two environment directions).
- Pooling of destructible nodes (caps + cull suffice for v1; drop-in later).
- Hand-drawn art; new hazard families beyond the four.

## Testing
- **Headless compile gate** after each change (`--headless --editor --quit`, grep errors, ignore benign `menu_background.jpg`).
- **Layer safety FIRST** (before any hazard logic): after the collision-layer edits, F5 and confirm **enemies still reach and bite the player** and **player bullets still kill enemies** — the layer change's highest-blast-radius regression.
- **F5 (Larry):** temporarily set `WAVE_DURATION := 6.0`.
  - Barrels/drums/transformers/cars/crates scatter around you and cull when far behind.
  - Shoot a **barrel** → burst + lingering fire pool; a cluster of barrels **chain-ripples** (no freeze/crash).
  - Stand in each hazard → you take damage; herd zombies into one → they take damage + acid slows + electric stuns.
  - **Cover:** you and zombies route around a car (no permanent wedge pile-up); your bullets and a spitter's/boss's shots are **both** stopped by cover; lightning/cone/ricochet skip enemies hidden behind cover.
  - **Crate** → drops XP gems + adds to the coin tally.
  - Restore `WAVE_DURATION := 30.0`.

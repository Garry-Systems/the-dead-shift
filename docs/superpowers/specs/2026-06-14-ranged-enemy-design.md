# Ranged "Spitter" Enemy — Design Spec

**Date:** 2026-06-14
**Branch:** `feat/boss-framework` (builds on the boss framework; ships together)
**Status:** approved by Larry 2026-06-14

## Goal

Add a second enemy archetype — a **ranged "Spitter"** that holds at a distance and fires projectiles at the player — to break up the current single chase-only enemy. Mixes into spawns starting at wave 10.

## Locked decisions (with Larry)

- **Behavior:** keeps its distance and shoots (classic spitter), NOT a fast darter.
- **Toughness:** same HP / contact damage as a normal enemy (uses the normal `DifficultyManager.enemy_stats()`).
- **Spawn:** ~25% of trash spawns are spitters once `wave >= 10`; endless mode only (boss-rush has no trash).
- **Projectile:** reuse the boss framework's `BossProjectile` (a generic "distance-hit the player, not shootable" hazard) with spitter-specific speed/damage.
- **No shot telegraph** in v1 — dodged by moving. Easy to add later.
- **Art:** new 32×32 **C3** placeholder sprite, palette-compliant, via `gen_palette_sprites.py`.

## Architecture

The spitter shares almost everything with the existing `Enemy` (health, hit-flash, incendiary/poison/slow/knockback talent hooks, the above-head health bar, XP-gem drop, contact damage). Only its **movement** (hold range instead of chase) and a **fire action** differ. So:

### 1. `Enemy.gd` — small, behavior-preserving refactor
- Add `class_name Enemy` (currently has none) so it can be subclassed.
- Extract the chase movement into an overridable virtual:
  ```
  ## Base movement intent (before slow/knockback). Override per enemy. Default = chase.
  func _desired_velocity() -> Vector2:
      var dir := (_target.global_position - global_position).normalized()
      return dir * move_speed
  ```
  In `_physics_process`, replace the inline `velocity = dir * (move_speed * _slow_factor)` with `velocity = _desired_velocity() * _slow_factor` (mathematically identical for the base enemy → **no regression**).
- Add an overridable per-frame action hook, called once after `move_and_slide()`:
  ```
  ## Per-frame action (e.g. ranged firing). Default no-op.
  func _act(_delta: float) -> void:
      pass
  ```
  The base enemy's `_act` is empty, so normal enemies are unchanged.

### 2. `RangedEnemy.gd extends Enemy` + `scenes/RangedEnemy.tscn`
- `class_name RangedEnemy`.
- Override `_desired_velocity()`: approach if `dist > preferred*1.1`, back off if `dist < preferred*0.9`, else hold (`Vector2.ZERO`). Preferred distance = `GameConfig.RANGED_PREFERRED_DIST`.
- Override `_act(delta)`: count down a fire cooldown; when ready AND the player is within `RANGED_FIRE_RANGE`, spawn a `BossProjectile` aimed at the player (`setup(dir, RANGED_PROJECTILE_SPEED, RANGED_PROJECTILE_DAMAGE)`), reset cooldown to `RANGED_FIRE_INTERVAL`.
- Override `_ready()`: call `super._ready()`, then stagger the initial cooldown with `randf_range(0, RANGED_FIRE_INTERVAL)` so a group doesn't volley in unison.
- Inherits everything else from `Enemy` — bullets, talents (burn/poison/slow/knockback/crit), the health bar, and the gem drop all work unchanged.
- Scene = a clone of `Enemy.tscn` (CharacterBody2D + CollisionShape radius 20 + `xp_gem_scene` export) with the script → `RangedEnemy.gd` and texture → `art/ranged_enemy.png`.

### 3. `Spawner.gd` — pick the spitter into the mix
- Add `@export var ranged_enemy_scene: PackedScene`.
- In `_spawn_enemy()`, choose `ranged_enemy_scene` when `ranged_enemy_scene != null and DifficultyManager.wave >= GameConfig.RANGED_ENEMY_MIN_WAVE and randf() < GameConfig.RANGED_ENEMY_SPAWN_CHANCE`; otherwise `enemy_scene`. Both are configured with the same `DifficultyManager.enemy_stats()` (same HP, per the locked decision). Only `_spawn_enemy` (endless) changes — boss-rush is untouched.

### 4. `scenes/Main.tscn` — wire the export (surgical)
- Add the `RangedEnemy.tscn` ext_resource and `ranged_enemy_scene = ExtResource(...)` under the `Spawner` node; bump `load_steps`. Leave everything else byte-identical.

### 5. `GameConfig.gd` — all tunables
```
# --- Ranged enemy (Spitter) ---
const RANGED_ENEMY_MIN_WAVE := 10        # spitters start mixing in at this wave
const RANGED_ENEMY_SPAWN_CHANCE := 0.25  # fraction of trash spawns that are spitters (wave >= min)
const RANGED_PREFERRED_DIST := 450.0     # px standoff the spitter tries to hold
const RANGED_FIRE_INTERVAL := 1.8        # seconds between shots
const RANGED_FIRE_RANGE := 700.0         # px; only fires within this range
const RANGED_PROJECTILE_SPEED := 320.0   # px/sec
const RANGED_PROJECTILE_DAMAGE := 12.0   # flat damage per hit
```

### 6. Art — `art/ranged_enemy.png`
Add a `ranged_enemy()` function to `gen_palette_sprites.py` rendering a 32×32 **C3** sprite with a silhouette distinct from `enemy()` (e.g. a hunched body with a forward "spout"/snout and a single eye), call it in the script's main block, run it. Palette-compliant (enemies are C3 per `reference_survivor_palette`). Dedicated hand-art is a later follow-up, same as the boss sprites.

## Integration contract (verified against current code)
- `BossProjectile.setup(dir, spd, dmg)` exists; it distance-hits the player and is NOT in the `enemies` group (player bullets pass through it). ✓
- `Enemy.configure(stats)` + `Enemy.tscn` carrying `xp_gem_scene` → spitters drop gems. ✓
- `DifficultyManager.wave` + `enemy_stats()` available at spawn. ✓
- Spitter is in the `enemies` group (inherited `Enemy._ready`) → auto-aim + bullets target it. ✓

## Non-goals (deferred)
- Shot telegraph / wind-up on spitter fire.
- A distinct projectile class (reuse `BossProjectile`).
- Hand-drawn art.
- Spitters in boss-rush mode.
- Other new enemy archetypes (this is one type).

## Testing
- Headless compile gate after each change (`--headless --editor --quit`, grep errors, ignore benign `menu_background.jpg`).
- F5 (Larry): set `WAVE_DURATION := 6.0` temporarily, reach wave 10, confirm ~1-in-4 spawns are spitters that hold range and fire dodgeable projectiles, that bullets/talents kill them and they drop gems, and that the projectiles damage the player on hit. Restore `WAVE_DURATION := 30.0`.

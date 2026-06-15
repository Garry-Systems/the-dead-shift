# Manual Aim (Stop-to-Shoot) — Design

**Date:** 2026-06-15
**Branch:** `feat/manual-aim` (off `master` @ `0efaf11`)
**Status:** Approved design — pending implementation plan

## Goal

Replace the auto-aim + auto-fire survivor control model with **manual aiming**, so
skill matters moment-to-moment. The player aims by facing a direction (steering),
and the gun fires in the direction the player is **last looking** — it no longer
picks targets for you. The existing "can't shoot while moving" rule is preserved
and becomes the *core* mechanic rather than an optional difficulty toggle.

This is a one-thumb scheme: there is **no second aim stick**. You aim with the
movement input and shoot by stopping.

## Current behavior (what we're replacing)

- `Gun.gd` calls `_find_nearest_enemy()` every frame (via `TargetSelector.nearest_index_in_range`,
  bounded by `gun_range`), sets `aim_direction` toward that enemy, and `_fire(aim_direction)`.
- Firing is gated on a target existing: `if target == null: return` — you cannot
  fire into empty space.
- `Player.gd` faces `gun.aim_direction` (the nearest enemy) when one exists, else
  the movement direction.
- `GameConfig.SHOOT_ONLY_WHILE_STILL = true` makes the gun hold fire while moving
  (`Player` sets `gun.hold_fire = SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO`).
- `gun_range` is used **only** for auto-targeting.

## New behavior

1. **Aim = facing = last move direction.** The player faces the direction they are
   moving. When stopped, they keep facing the last direction they moved
   (`_last_move_dir`). This faced direction is the fire direction.
2. **Smooth 360° aim.** The shot uses the exact last-move vector (any angle). Ryan's
   sprite snaps to the nearest of its 8 directional poses for display only — the
   bullet flies at the precise angle.
3. **Can't shoot while moving.** While `velocity != Vector2.ZERO` (including dash),
   the gun holds fire. The instant the player stops, the gun fires.
4. **Auto-fire while stopped.** When stopped, the gun fires **continuously at its
   fire rate** in the faced direction, draining the magazine and auto-reloading on
   empty exactly as today — until the player moves again.
5. **You can miss.** The gun fires in the faced direction whether or not an enemy is
   there. Bullets fly out and hit whatever they collide with (unchanged `Bullet.gd`
   collision). Facing the wrong way wastes ammo — that's the skill cost.
6. **Re-aim by nudging.** To change aim you tilt the stick a new way (drifting
   slightly) and stop again. There is no turn-in-place; facing only changes by moving.

## Detailed mechanics

### Fire direction ownership
The **Player** owns the fire direction now, not the Gun.
- `Player._physics_process` computes `face_dir = _last_move_dir` (the smooth,
  normalized last-move vector; defaults to `Vector2.RIGHT`).
- Player faces `face_dir` via `_face()` (existing 8-pose snap).
- Player pushes the fire direction into the gun each frame: `gun.aim_direction = face_dir`.
- Player continues to set `gun.hold_fire = velocity != Vector2.ZERO`.

### Gun firing
`Gun._process` is simplified:
- **Remove** `_find_nearest_enemy()`, the `TargetSelector` call, and the
  `if target == null: return` gate.
- `aim_direction` is now an input set by the Player (no longer self-computed). The
  Gun reads it.
- Fire logic: while not `hold_fire`, not reloading, cooldown elapsed, ammo > 0, and
  `aim_direction != Vector2.ZERO` → `_fire(aim_direction)`, decrement ammo, set
  cooldown, auto-reload on empty (all unchanged from today).
- `_find_nearest_enemy()` is deleted. `TargetSelector.gd` becomes unused; leave the
  file in place (harmless) to minimize churn, or delete it — implementer's call,
  noted in the plan.

### Spawn / idle fire guard
Default facing is `Vector2.RIGHT` and the player starts stopped, which would make the
gun auto-empty its magazine to the right before the player moves. Guard against this:
- The gun holds fire until the player has issued a **first movement input** this run.
- Implementation: a `_has_moved` flag on the Player (set true the first frame
  `dir != Vector2.ZERO`). Until then, force `gun.hold_fire = true`.
- This also keeps the gun quiet during the run-start `RunLoading` beat / before the
  first input.

### Range repurpose (approved)
`gun_range` no longer gates targeting (there is no targeting). Repurpose it as the
bullet's **maximum travel distance**:
- `Gun._spawn_bullet` passes `bullet.max_travel = gun_range`.
- `Bullet.gd` accumulates distance traveled and `queue_free()`s once it exceeds
  `max_travel` (in addition to the existing `BULLET_LIFETIME` safety cap).
- This keeps every range source meaningful and consistent: the loot **range** stat
  (`apply_loot` → `upgrade_range`), the **Long Scope** relic, and the range upgrade
  card all now extend how far your shots reach.
- `GameConfig.GUN_RANGE` comment updated from "ignore enemies farther than this" to
  "bullet max travel distance (px)". Value unchanged (600) unless tuning says otherwise.

### Dash (unchanged)
Double-tap / double-click still triggers the dash. Dash counts as moving
(`velocity != Vector2.ZERO`), so the gun holds fire during a dash. Behavior is
consistent with the new model and needs no change.

### Desktop / keyboard parity
WASD (or arrows) drives the same `_last_move_dir`. Stop pressing keys → fire in the
last-held direction. The mouse is **not** used for aiming. Same model as touch.

## Files touched

- `scripts/Gun.gd` — remove auto-target path; treat `aim_direction` as an input;
  pass `max_travel` to spawned bullets.
- `scripts/Player.gd` — face & aim from `_last_move_dir`; push `aim_direction` to the
  gun; add `_has_moved` spawn-fire guard.
- `scripts/Bullet.gd` — add `max_travel` field + distance-based despawn.
- `scripts/logic/GameConfig.gd` — update `GUN_RANGE` comment; `SHOOT_ONLY_WHILE_STILL`
  is now effectively always-on (keep the const for clarity, value `true`).
- `scripts/logic/TargetSelector.gd` — becomes unused (leave or delete; plan decides).

No scene (`.tscn`) changes. No new files. No new autoloads.

## Out of scope (follow-ups, not this change)

- **Boss / enemy rebalancing.** Bosses (and the spitter) were tuned assuming
  guaranteed auto-aim hits. Manual aim makes them harder; that is a separate play-tuning
  pass after this lands.
- **Aim assist / bullet magnetism.** Intentionally omitted — the request is for skill.
  Could be added later as an optional config knob if aiming feels too punishing on a
  phone.
- **Turn-in-place aiming / a second aim stick.** Explicitly not wanted.

## Acceptance criteria

**Headless gate (pre-F5):**
- `--headless --editor --quit` import/compile clean (ignore the benign
  `menu_background.jpg` JPEG-decode line).

**F5 smoke test:**
1. Move in any direction — gun holds fire while moving; Ryan faces the move direction.
2. Stop — gun fires continuously in the direction you were last heading, at the
   weapon's fire rate, draining the mag and auto-reloading on empty.
3. Aim is smooth 360° — face a precise diagonal between two enemies and the shot goes
   exactly there (sprite shows the nearest 8-pose).
4. Facing empty space and stopping fires into nothing (you can miss / waste ammo).
5. At spawn, standing still, the gun does **not** fire until you've moved once.
6. Dash (double-tap) still works and you do not shoot mid-dash.
7. A longer-range weapon/loot/Long Scope relic makes bullets travel visibly farther
   before despawning; a short-range one fizzles sooner.
8. Desktop: release WASD → fire in the last-held direction; mouse not needed to aim.

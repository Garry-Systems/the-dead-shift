# Design: Nail Gun "Pin" Signature Mechanic — The Dead Shift

**Date:** 2026-06-25
**Status:** Approved (brainstorm complete) — ready for implementation plan
**Game:** The Dead Shift (Godot 4 / GDScript), code at `C:\Users\thela\Documents\mobile-game\`
**Builds on:** the existing gun roster (`scripts/logic/Weapons.gd`), the projectile/Bullet
system (`scripts/Bullet.gd`, `scripts/Gun.gd`), and the enemy status system
(`scripts/Enemy.gd` — `apply_slow` / `apply_freeze` / `apply_dot`).

## Goal

Give the **Nail Gun** a signature hook. Today it is `id: "nailgun"` — an SMG-category gun whose
only distinction is `base_pierce: 1` (dmg 9, `fire_interval` 0.07, mag 25). Mechanically it is a
plain piercing SMG; its neighbors all have signatures (Tesla chains, Flamethrower burns, Acid
Cannon pools, Railgun beams) and it does not.

**The signature:** every nail has a chance to **PIN** the zombie it hits — root it in place
("nail its feet to the ground") for a short time, with a lavender "nailed" tell. The gun's rapid
fire turns into a steady scatter of pinned zombies across the horde — a **crowd-control** identity
distinct from its piercing-SMG neighbors.

### Decisions locked in brainstorm

- **Trigger model:** chance per nail (not stack-meter, not immunity-window). RNG-flavored, simple,
  fits the game's "RNG is king" identity.
- **Pin = root movement only** (NOT the full freeze action-lock). Ranged zombies pinned can still
  fire — their feet are nailed, not their hands. This also keeps the pin from being as strong as a
  full freeze.
- **Visual tell:** dedicated **`apply_pin`** with a **C4 lavender** (`#E0E5FF`) base-tint — the
  player/nail color, reads as "nailed by my hardware". Deliberately distinct from the `apply_freeze`
  **C2 indigo** "iced" tell, and does NOT mark the enemy `is_frozen()`, so Cold Snap weapons do not
  "shatter" nail-pinned zombies (no unintended cross-weapon synergy).
- **Bosses are immune for free** — `BossBase extends CharacterBody2D` (not `Enemy`), so it has no
  `apply_pin` method; the `has_method` guard makes the pin a no-op on bosses. No extra immunity code.

## Why this is low-risk / reuse-maxed

The pin rides the exact patterns already in the codebase:

- The **per-shot payload** plumbing (Gun def → `Gun` field → `Bullet` field) already carries
  `base_pierce`, `incendiary`/`burn`, `explode_radius`/`explode_force`, `pool_cfg`. `pin_chance` /
  `pin_dur` are added the same way: absent on every other gun → `def.get(..., 0.0)` → inert.
- The **enemy status** machinery already implements a movement-zero gate and a base-tint tell for
  `apply_freeze`. `apply_pin` mirrors it (own flag, own timer, own tint), reusing the same
  `_physics_process` velocity gate and the same `flash.gdshader` `base_tint` uniform.
- All enemy subclasses inherit the gate correctly (verified): `RangedEnemy` and `HiveEnemy` do not
  override `_physics_process`; `ExploderEnemy` overrides it but calls `super._physics_process(delta)`.

## Changes by file

### 1. `scripts/logic/Weapons.gd` — data only (nailgun def)

Add two keys to the `nailgun` dict (and only that dict):

```gdscript
{
    "id": "nailgun", "name": "Nail Gun", "desc": "Hardware-aisle rapid-fire — pins what it pierces", "category": "SMG",
    "fire_mode": "projectile", "base_pierce": 1,
    "pin_chance": 0.12, "pin_dur": 0.45,          # NEW: 12% per nail, root 0.45s
    "damage": 9.0, "fire_interval": 0.07, "bullet_speed": 950.0,
    "range": 500.0, "projectiles": 1, "spread": 0.05,
    "mag_size": 25, "reload_time": 1.3,
    "upgrades": ["damage", "fire_rate", "pierce", "bullet_speed", "choke", "ricochet", "reload", "mag"],
},
```

(`desc` updated to advertise the new identity; optional but nice.)

### 2. `scripts/Gun.gd` — carry the fields to the bullet

- New fields near the other per-shot payload vars:

  ```gdscript
  var pin_chance := 0.0              # Nail Gun: chance per hit to root the enemy
  var pin_dur := 0.0                 # Nail Gun: pin (root) duration in seconds
  ```

- In `configure(def)`, read them with defaults (so all other guns stay inert):

  ```gdscript
  pin_chance = float(def.get("pin_chance", 0.0))
  pin_dur = float(def.get("pin_dur", 0.0))
  ```

- In `_spawn_bullet(dir)`, pass them onto the bullet (next to the `incendiary` / `explode_*` block):

  ```gdscript
  bullet.pin_chance = pin_chance
  bullet.pin_dur = pin_dur
  ```

No upgrade hook for pin in v1 (scope). The gun's existing upgrade pool is unchanged.

### 3. `scripts/Bullet.gd` — roll the pin on enemy hit

- New vars in the talent-payload area:

  ```gdscript
  var pin_chance := 0.0          # Nail Gun: chance to root the enemy on hit
  var pin_dur := 0.0             # Nail Gun: root duration (seconds)
  ```

- In `_on_body_entered`, inside the enemy branch, in the `if not killed:` block (alongside the
  existing `incendiary`/`ignite` line):

  ```gdscript
  if not killed:
      if body.has_method("flash_hit"):
          body.flash_hit()
      if incendiary and body.has_method("ignite"):
          body.ignite(burn_dps, burn_duration)
      if pin_chance > 0.0 and body.has_method("apply_pin") and randf() < pin_chance:
          body.apply_pin(pin_dur)
  ```

  The `has_method("apply_pin")` guard is the boss-immunity path (BossBase has no such method) and is
  also future-proof against any other non-`Enemy` damageable.

### 4. `scripts/Enemy.gd` — the dedicated pin (root + lavender tell)

- New const next to `FROZEN_TINT`:

  ```gdscript
  const PIN_TINT := Color("E0E5FF")     # C4 lavender — "nailed" tell (palette-compliant)
  ```

- New state vars next to `_frozen` / `_freeze_time`:

  ```gdscript
  var _pinned := false           # Nail Gun: rooted in place while true (movement only)
  var _pin_time := 0.0
  ```

- New method (mirrors `apply_freeze`; strongest/longest application wins via `maxf`):

  ```gdscript
  ## Nail Gun: root the enemy in place for `duration`s (movement only — it can still act).
  ## Lavender "nailed" tell, distinct from the indigo freeze; does NOT set is_frozen().
  func apply_pin(duration: float) -> void:
      _pin_time = maxf(_pin_time, duration)
      if not _pinned:
          _pinned = true
          _refresh_tint()
  ```

- New tint helper, with **freeze outranking pin**:

  ```gdscript
  ## Resolve the persistent base tint: freeze (indigo) wins over pin (lavender) wins over none.
  func _refresh_tint() -> void:
      if _flash_mat == null:
          return
      var t := Color(1, 1, 1, 1)
      if _frozen:
          t = FROZEN_TINT
      elif _pinned:
          t = PIN_TINT
      _flash_mat.set_shader_parameter("base_tint", t)
  ```

- Refactor `apply_freeze` and `_thaw` to route their tint through `_refresh_tint()` (so when a freeze
  ends, the tint correctly falls back to lavender if the enemy is still pinned, and vice-versa):

  ```gdscript
  func apply_freeze(duration: float) -> void:
      _freeze_time = maxf(_freeze_time, duration)
      if not _frozen:
          _frozen = true
          _refresh_tint()

  func _thaw() -> void:
      _frozen = false
      _refresh_tint()
  ```

- In `_physics_process`, add a pin countdown next to the freeze countdown:

  ```gdscript
  if _pin_time > 0.0:
      _pin_time -= delta
      if _pin_time <= 0.0:
          _pinned = false
          _refresh_tint()
  ```

- Extend the movement-zero gate (the existing `if _frozen: velocity = Vector2.ZERO`):

  ```gdscript
  if _frozen or _pinned:
      velocity = Vector2.ZERO
  ```

  **Leave the `_act` gate untouched** — it stays `if not _frozen: _act(delta)`, so a *pinned*
  (but not frozen) ranged enemy still fires. This is the intended "feet, not hands" behavior.

## Balance (starter values — tunable, Larry's balance pass)

- `pin_chance = 0.12`, `pin_dur = 0.45`.
- Against the horde: a satisfying scatter of brief roots; the gun's piercing means one nail can pin
  more than one zombie in a line.
- Against a single focused target: procs refresh via `maxf` and can chain into a soft-lock. This is
  **intentional** — it is the gun's fantasy vs a tough zombie — and bosses are immune, so it cannot
  trivialize a boss fight. If it proves too strong, the lever is `pin_chance` / `pin_dur` (data only).

## Out of scope (YAGNI)

- No bonus damage / vulnerability while pinned (the pin already wins value by making every follow-up
  nail land).
- No new "pin chance+" upgrade card; the gun keeps its current upgrade pool.
- No pin-stack meter, no immunity-window (chance model chosen instead).
- No pin on bosses (auto-immune by class hierarchy).

## Testing

**Headless probe** (matches the existing `probe_*.gd` pattern at repo root):

1. Construct an `Enemy`, give it a target, call `apply_pin(0.5)`; step `_physics_process` a few
   frames → assert `velocity == Vector2.ZERO` while `_pin_time > 0`, then assert movement resumes
   after the timer expires.
2. Tint precedence: pin an enemy, then freeze it → `base_tint == FROZEN_TINT`; let freeze expire
   while still pinned → `base_tint == PIN_TINT`; let pin expire → `base_tint == white`.
3. Boss immunity: assert `BossBase` (or a boss instance) does **not** have method `apply_pin`
   (the bullet's `has_method` guard therefore no-ops).
4. Inert default: a non-nailgun `Gun` has `pin_chance == 0.0`, so its bullets never call `apply_pin`.

**Manual (Larry F5 APK pass):** equip the Nail Gun, fire into a horde → see lavender-tinted zombies
freeze in place briefly; confirm ranged zombies still shoot while pinned; confirm a boss never gets
pinned; confirm no other gun pins anything.

## Acceptance criteria

- Nail Gun pins ~12% of the zombies it hits for ~0.45s, shown by a lavender tint and zero movement.
- Pinned ranged zombies can still fire; pinned melee zombies cannot reach the player.
- Bosses are never pinned.
- No other weapon's behavior changes (all `pin_*` default to 0 / inert).
- Freeze and pin tints never clobber each other (freeze always wins while active).

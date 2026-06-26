# Nail Gun Pin Mechanic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Nail Gun a signature: each nail has a 12% chance to PIN (root) the zombie it hits for 0.45s, shown by a C4-lavender "nailed" tell; bosses immune; all other guns unchanged.

**Architecture:** Reuse the existing per-shot payload plumbing (Weapons def → `Gun` field → `Bullet` field, exactly like `base_pierce`/`incendiary`/`explode_*`) to carry `pin_chance`/`pin_dur`. Add a dedicated `apply_pin(duration)` to `Enemy` that mirrors `apply_freeze` (own `_pinned`/`_pin_time`, own lavender tint), reusing the same `_physics_process` velocity-zero gate. Spec: `docs/superpowers/specs/2026-06-25-nailgun-pin-design.md`.

**Tech Stack:** Godot 4.6, GDScript. Code at `C:\Users\thela\Documents\mobile-game\` (WSL: `/mnt/c/Users/thela/Documents/mobile-game/`). All work happens **in the game repo** (`origin` = `github.com/Garry-Systems/the-dead-shift`).

## Global Constraints

- **Strict 4-color palette.** Pin tint MUST be C4 lavender `#E0E5FF` (the player/projectile color). Freeze stays C2 indigo `#3D0099`. No new colors.
- **Reuse-maxed, no new systems.** Mirror existing patterns (`apply_freeze`, the payload `def.get(..., 0.0)` flow). Every other weapon stays inert (`pin_*` default `0.0`).
- **Bosses immune by class hierarchy** — never add `apply_pin` to `BossBase`. The `has_method("apply_pin")` guard is the immunity.
- **Pin = movement root only.** Do NOT gate `_act(delta)` on `_pinned` (ranged zombies still fire while pinned). Only the velocity gate is extended.
- **Pure static helper for tint precedence** so a probe can verify it headlessly (codebase convention, e.g. `Gun._enemies_in_cone`).

**Verification convention:** No WSL runtime UI harness, so each task verifies with the **headless compile GATE** plus a temporary `extends SceneTree` **probe** (created, run, deleted — NOT committed). Final verification is Larry's F5 APK pass.

Headless gate (**[GATE]**):
```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5 2>&1 \
  | grep -iE "SCRIPT ERROR|Parse Error|error|Cannot" | grep -viE "menu_background.jpg|jpe?g" || echo "GATE CLEAN"
```
Expected when clean: `GATE CLEAN`.

Probe runner (**[PROBE]** `<name>`):
```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --headless --path "C:\Users\thela\Documents\mobile-game" --script res://<name>.gd 2>&1 | grep PROBE
```

---

## File Structure
- **Modify** `scripts/Enemy.gd` — `PIN_TINT` const, `_pinned`/`_pin_time` state, `apply_pin()`, `is_pinned()`, pure `_resolve_tint()`, `_refresh_tint()`; route `apply_freeze`/`_thaw` through `_refresh_tint()`; pin countdown + extended velocity gate in `_physics_process`.
- **Modify** `scripts/logic/Weapons.gd` — add `pin_chance`/`pin_dur` to the `nailgun` def (and refresh its `desc`).
- **Modify** `scripts/Gun.gd` — `pin_chance`/`pin_dur` fields, read in `configure()`, passed in `_spawn_bullet()`.
- **Modify** `scripts/Bullet.gd` — `pin_chance`/`pin_dur` vars, roll `apply_pin` on enemy hit.

Build order: Enemy (core mechanic, fully probeable) → Weapons (data) → Gun+Bullet (plumbing reads the data) → ship.

---

## Task 1: Enemy — `apply_pin` root + lavender tell

**Files:** Modify `scripts/Enemy.gd`. Temp: `probe_pin.gd` (created, run, deleted — not committed).

- [ ] **Step 1: Create the feature branch.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && git checkout -b feat/nailgun-pin
```

- [ ] **Step 2: Add the pin tint const.** In `scripts/Enemy.gd`, the line is currently:

```gdscript
const FROZEN_TINT := Color("3D0099")   # C2 indigo — frozen tell (palette-compliant)
```

Add immediately after it:

```gdscript
const PIN_TINT := Color("E0E5FF")      # C4 lavender — Nail Gun "nailed" tell (palette-compliant)
```

- [ ] **Step 3: Add the pin state vars.** The lines are currently:

```gdscript
	var _frozen := false           # Cold Snap: fully stopped while true
```
(near the other status vars; `_freeze_time` is declared elsewhere as `var _freeze_time := 0.0`). Add after the `_frozen` declaration:

```gdscript
	var _pinned := false           # Nail Gun: rooted in place (movement only) while true
	var _pin_time := 0.0
```

- [ ] **Step 4: Add the pure tint resolver + the refresh helper.** Find `apply_freeze` / `is_frozen` / `_thaw`, currently:

```gdscript
## Talent (Cold Snap): fully stop the enemy for a duration. A hit while frozen shatters it.
func apply_freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	if not _frozen:
		_frozen = true
		if _flash_mat != null:
			_flash_mat.set_shader_parameter("base_tint", FROZEN_TINT)

func is_frozen() -> bool:
	return _frozen

func _thaw() -> void:
	_frozen = false
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("base_tint", Color(1, 1, 1, 1))
```

Replace that entire block with:

```gdscript
## Talent (Cold Snap): fully stop the enemy for a duration. A hit while frozen shatters it.
func apply_freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	if not _frozen:
		_frozen = true
		_refresh_tint()

func is_frozen() -> bool:
	return _frozen

func _thaw() -> void:
	_frozen = false
	_refresh_tint()

## Nail Gun: root the enemy in place for `duration`s (movement only — it can still act).
## Lavender "nailed" tell, distinct from the indigo freeze; does NOT set is_frozen().
func apply_pin(duration: float) -> void:
	_pin_time = maxf(_pin_time, duration)
	if not _pinned:
		_pinned = true
		_refresh_tint()

func is_pinned() -> bool:
	return _pinned

## Pure: persistent base tint by status precedence (freeze > pin > none).
## Static so a probe can verify the precedence headlessly.
static func _resolve_tint(frozen: bool, pinned: bool) -> Color:
	if frozen:
		return FROZEN_TINT
	if pinned:
		return PIN_TINT
	return Color(1, 1, 1, 1)

## Push the resolved tint to the flash material (no-op before the sprite material exists).
func _refresh_tint() -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("base_tint", _resolve_tint(_frozen, _pinned))
```

- [ ] **Step 5: Add the pin countdown.** In `_physics_process`, the freeze countdown is currently:

```gdscript
	if _freeze_time > 0.0:
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			_thaw()
```

Add immediately after it:

```gdscript
	if _pin_time > 0.0:
		_pin_time -= delta
		if _pin_time <= 0.0:
			_pinned = false
			_refresh_tint()
```

- [ ] **Step 6: Extend the velocity gate.** Further down in `_physics_process` the line is currently:

```gdscript
	if _frozen:
		velocity = Vector2.ZERO
```

Replace with:

```gdscript
	if _frozen or _pinned:
		velocity = Vector2.ZERO
```

(Leave the `if not _frozen: _act(delta)` line UNCHANGED — pinned enemies still act.)

- [ ] **Step 7: Run [GATE].** Expected: `GATE CLEAN`.

- [ ] **Step 8: Write the probe.** Create `probe_pin.gd` in the project root:

```gdscript
extends SceneTree
## One-off: verify the pin state, tint precedence (freeze > pin > none), and boss immunity.
func _init() -> void:
	var E = load("res://scripts/Enemy.gd")
	var e = E.new()
	e.apply_pin(0.5)
	var pin_set := e.is_pinned()
	var tint_freeze := Enemy._resolve_tint(true, true) == Enemy.FROZEN_TINT
	var tint_pin := Enemy._resolve_tint(false, true) == Enemy.PIN_TINT
	var tint_none := Enemy._resolve_tint(false, false) == Color(1, 1, 1, 1)
	var enemy_has := e.has_method("apply_pin")
	var boss = load("res://scripts/BossBase.gd").new()
	var boss_immune := not boss.has_method("apply_pin")
	var ok := pin_set and tint_freeze and tint_pin and tint_none and enemy_has and boss_immune
	print("PROBE pin=%s tF=%s tP=%s tN=%s enemyHas=%s bossImmune=%s -> %s" % [pin_set, tint_freeze, tint_pin, tint_none, enemy_has, boss_immune, ("PASS" if ok else "FAIL")])
	e.free()
	boss.free()
	quit()
```

- [ ] **Step 9: Run [PROBE] `probe_pin`.** Expected: `PROBE pin=true tF=true tP=true tN=true enemyHas=true bossImmune=true -> PASS`.

- [ ] **Step 10: Delete the probe + commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm probe_pin.gd && \
git add scripts/Enemy.gd && \
git commit -m "feat(enemy): add apply_pin root + lavender tell (freeze outranks pin)"
```

---

## Task 2: Weapons — pin data on the nailgun def

**Files:** Modify `scripts/logic/Weapons.gd`. Temp: `probe_naildef.gd` (created, run, deleted — not committed).

- [ ] **Step 1: Add the pin keys + refresh desc.** The `nailgun` def is currently:

```gdscript
		{
			"id": "nailgun", "name": "Nail Gun", "desc": "Hardware-aisle rapid-fire — cheap, pierces", "category": "SMG",
			"fire_mode": "projectile", "base_pierce": 1,
			"damage": 9.0, "fire_interval": 0.07, "bullet_speed": 950.0,
			"range": 500.0, "projectiles": 1, "spread": 0.05,
			"mag_size": 25, "reload_time": 1.3,
			"upgrades": ["damage", "fire_rate", "pierce", "bullet_speed", "choke", "ricochet", "reload", "mag"],
		},
```

Replace with:

```gdscript
		{
			"id": "nailgun", "name": "Nail Gun", "desc": "Hardware-aisle rapid-fire — pins what it pierces", "category": "SMG",
			"fire_mode": "projectile", "base_pierce": 1,
			"pin_chance": 0.12, "pin_dur": 0.45,
			"damage": 9.0, "fire_interval": 0.07, "bullet_speed": 950.0,
			"range": 500.0, "projectiles": 1, "spread": 0.05,
			"mag_size": 25, "reload_time": 1.3,
			"upgrades": ["damage", "fire_rate", "pierce", "bullet_speed", "choke", "ricochet", "reload", "mag"],
		},
```

- [ ] **Step 2: Run [GATE].** Expected: `GATE CLEAN`.

- [ ] **Step 3: Write the probe.** Create `probe_naildef.gd` in the project root:

```gdscript
extends SceneTree
## One-off: verify the nailgun def carries the pin keys and no other gun does.
func _init() -> void:
	var nail := {}
	var others_inert := true
	for d in Weapons.all():
		if d["id"] == "nailgun":
			nail = d
		elif d.get("pin_chance", 0.0) != 0.0 or d.get("pin_dur", 0.0) != 0.0:
			others_inert = false
	var nail_ok := is_equal_approx(nail.get("pin_chance", 0.0), 0.12) and is_equal_approx(nail.get("pin_dur", 0.0), 0.45)
	print("PROBE nail_ok=%s others_inert=%s -> %s" % [nail_ok, others_inert, ("PASS" if nail_ok and others_inert else "FAIL")])
	quit()
```

- [ ] **Step 4: Run [PROBE] `probe_naildef`.** Expected: `PROBE nail_ok=true others_inert=true -> PASS`.

- [ ] **Step 5: Delete the probe + commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm probe_naildef.gd && \
git add scripts/logic/Weapons.gd && \
git commit -m "feat(weapons): nailgun gains pin_chance 0.12 / pin_dur 0.45"
```

---

## Task 3: Gun + Bullet — carry the payload and roll the pin

**Files:** Modify `scripts/Gun.gd`, `scripts/Bullet.gd`. Temp: `probe_gunpin.gd` (created, run, deleted — not committed).

**Interfaces:**
- Consumes: `Weapons.all()` nailgun def keys `pin_chance` / `pin_dur` (Task 2); `Enemy.apply_pin(duration: float)` (Task 1).
- Produces: `Gun.pin_chance: float`, `Gun.pin_dur: float`; `Bullet.pin_chance: float`, `Bullet.pin_dur: float`.

- [ ] **Step 1: Add the Gun fields.** In `scripts/Gun.gd`, the talent-payload block is currently:

```gdscript
# Talent payload carried onto every bullet (raised by weapon talent cards).
var pierce_count := 0
var ricochet_count := 0
var incendiary := false
var burn_dps := 0.0
var burn_duration := 0.0
```

Add after `var burn_duration := 0.0`:

```gdscript
var pin_chance := 0.0              # Nail Gun: chance per hit to root the enemy (0 = none)
var pin_dur := 0.0                 # Nail Gun: pin (root) duration in seconds
```

- [ ] **Step 2: Read them in `configure()`.** The last config read is currently:

```gdscript
	beam_width = float(def.get("beam_width", 28.0))
	_ammo = mag_size
```

Insert between those two lines:

```gdscript
	beam_width = float(def.get("beam_width", 28.0))
	pin_chance = float(def.get("pin_chance", 0.0))
	pin_dur = float(def.get("pin_dur", 0.0))
	_ammo = mag_size
```

- [ ] **Step 3: Pass them to the bullet.** In `_spawn_bullet()`, the lines are currently:

```gdscript
	bullet.explode_radius = explode_radius
	bullet.explode_force = explode_force
	if pool_family != "":
		bullet.pool_cfg = _build_pool_cfg()
```

Insert after `bullet.explode_force = explode_force`:

```gdscript
	bullet.explode_radius = explode_radius
	bullet.explode_force = explode_force
	bullet.pin_chance = pin_chance
	bullet.pin_dur = pin_dur
	if pool_family != "":
		bullet.pool_cfg = _build_pool_cfg()
```

- [ ] **Step 4: Add the Bullet vars.** In `scripts/Bullet.gd`, the talent payload block is currently:

```gdscript
var incendiary := false        # ignites enemies it hits
var burn_dps := 0.0
var burn_duration := 0.0
```

Add after `var burn_duration := 0.0`:

```gdscript
var pin_chance := 0.0          # Nail Gun: chance to root the enemy on hit (0 = none)
var pin_dur := 0.0             # Nail Gun: root duration (seconds)
```

- [ ] **Step 5: Roll the pin on enemy hit.** In `_on_body_entered`, the not-killed block is currently:

```gdscript
		if not killed:
			if body.has_method("flash_hit"):
				body.flash_hit()
			if incendiary and body.has_method("ignite"):
				body.ignite(burn_dps, burn_duration)
```

Replace with:

```gdscript
		if not killed:
			if body.has_method("flash_hit"):
				body.flash_hit()
			if incendiary and body.has_method("ignite"):
				body.ignite(burn_dps, burn_duration)
			if pin_chance > 0.0 and body.has_method("apply_pin") and randf() < pin_chance:
				body.apply_pin(pin_dur)
```

- [ ] **Step 6: Run [GATE].** Expected: `GATE CLEAN`.

- [ ] **Step 7: Write the probe.** Create `probe_gunpin.gd` in the project root:

```gdscript
extends SceneTree
## One-off: verify Gun.configure pulls pin_* from the nailgun def, and a non-nail gun stays inert.
func _init() -> void:
	var G = load("res://scripts/Gun.gd")
	var nail := {}
	var pistol := {}
	for d in Weapons.all():
		if d["id"] == "nailgun":
			nail = d
		elif d["id"] == "pistol":
			pistol = d
	var gn = G.new()
	gn.configure(nail)
	var nail_ok := is_equal_approx(gn.pin_chance, 0.12) and is_equal_approx(gn.pin_dur, 0.45)
	var gp = G.new()
	gp.configure(pistol)
	var inert_ok := gp.pin_chance == 0.0 and gp.pin_dur == 0.0
	print("PROBE nail_ok=%s inert_ok=%s -> %s" % [nail_ok, inert_ok, ("PASS" if nail_ok and inert_ok else "FAIL")])
	gn.free()
	gp.free()
	quit()
```

- [ ] **Step 8: Run [PROBE] `probe_gunpin`.** Expected: `PROBE nail_ok=true inert_ok=true -> PASS`.

- [ ] **Step 9: Delete the probe + commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm probe_gunpin.gd && \
git add scripts/Gun.gd scripts/Bullet.gd && \
git commit -m "feat(gun): carry pin_chance/pin_dur onto bullets; roll apply_pin on hit"
```

---

## Task 4: Ship — merge, push, F5 checklist

**Files:** none (integration). Verifies the whole feature end-to-end and triggers the APK build.

- [ ] **Step 1: Confirm no probe files remain.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && ls probe_*.gd 2>/dev/null && echo "PROBES LEFT — delete them" || echo "no probes (good)"
```
Expected: `no probes (good)`.

- [ ] **Step 2: Final [GATE].** Expected: `GATE CLEAN`.

- [ ] **Step 3: Merge to master + push (triggers the APK pipeline → new version).**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
git checkout master && git merge --no-ff feat/nailgun-pin -m "feat: Nail Gun pin mechanic (chance-per-nail root)" && \
git push origin master 2>&1 | tail -3
```

- [ ] **Step 4: Larry F5 manual-test checklist** (after the APK build lands as a new version):
  - Equip the **Nail Gun**; fire into a horde → ~1 in 8 hit zombies briefly **stop dead** with a **lavender tint**, then resume.
  - A pinned **ranged** zombie **still fires** while rooted (feet, not hands).
  - A pinned **melee** zombie cannot reach you while rooted.
  - A **boss** is **never** pinned (no lavender tint, keeps moving).
  - **No other gun** pins anything (swap to Pistol/SMG/etc. → zero lavender tints).
  - Freeze (Cold Snap) still tints **indigo**, never overwritten by lavender on the same enemy.

---

## Self-Review

**Spec coverage:**
- Pin = chance-per-nail root → Task 3 Step 5 (`randf() < pin_chance` → `apply_pin`). ✔
- `apply_pin` root + movement-only + lavender tell → Task 1 (Steps 4–6). ✔
- Freeze outranks pin tint → Task 1 Step 4 (`_resolve_tint` precedence). ✔
- Bosses immune → Task 1 Step 8 probe asserts `BossBase` lacks `apply_pin`; Task 3 Step 5 `has_method` guard. ✔
- All other guns inert → Task 2 Step 3 probe (`others_inert`) + Task 3 Step 7 probe (`inert_ok`). ✔
- Data on nailgun def (0.12 / 0.45) → Task 2. ✔
- Plumbing Weapons→Gun→Bullet → Tasks 2 & 3. ✔
- Palette C4 lavender `#E0E5FF` → Task 1 Step 2 (`PIN_TINT`). ✔
- Testing via probes + F5 → every task + Task 4. ✔

**Placeholder scan:** none — every code step shows complete code; every run step shows the expected output.

**Type consistency:** `apply_pin(duration: float)` / `is_pinned() -> bool` / `_resolve_tint(frozen, pinned) -> Color` / `_refresh_tint()` defined in Task 1 and used identically in the Task 1/3 probes and the Task 3 bullet roll. `pin_chance`/`pin_dur` are `float` consistently across Weapons (data), Gun (Task 3 Steps 1–3), and Bullet (Task 3 Steps 4–5).

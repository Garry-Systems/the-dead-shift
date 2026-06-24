# Arsenal Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 11 new guns (10 → 21, every category to exactly 3) and 3 new fire mechanics (explosive AoE, piercing beam, enemy-only hazard pool) to The Dead Shift, reusing existing systems wherever possible.

**Architecture:** New weapon-def keys are read via `def.get()` so the existing 10 guns are untouched. Two of the three new mechanics (explosive, pool) are "a projectile that does something on impact" — they share one `Bullet` on-death hook and reuse `Shockwave` / `HazardZone`. Only one genuinely new fire mode is added (`"beam"`), mirroring the existing `_fire_cone`/`_fire_lightning`. New guns auto-enter loot via `LootRoller.roll("")`; only the 3 type-specific crates need their `bases` lists extended.

**Tech Stack:** Godot 4.6.3 / GDScript (no C#). Pure-data globals via `class_name`. 4-color palette pixel art via a stdlib Python generator.

## Global Constraints

- **Godot 4.6.3, GDScript only** — zero C#.
- **Strict 4-color palette** (C1 void `#0A001A` / C2 indigo `#3D0099` / C3 gray-tan `#8C8573` / C4 lavender `#E0E5FF`). The new Beam VFX is C4 lavender — **inside** the palette, no new exception. (Only Lightning cyan / FlameCone orange / red enemy projectiles are sanctioned exceptions; do not add more.)
- **Existing 10 guns must be byte-for-byte unaffected** — only add new `Weapons.all()` entries and new `def.get()`-guarded keys.
- **Per-gun mechanic params live in the weapon def** (like `jump_count`/`cone_angle`), NOT in `GameConfig`.
- **Damage flows through `damage` for every gun** — the explosion's blast damage and the acid pool's dps both equal the shell's `damage`. No `pool_dps`/`explode_damage` key.
- **Delivery shells (explosive/pool) deal NO direct hit damage and do NOT pierce/ricochet** — the AoE/pool is the damage.
- **Naming leans military / real-world firearms.**
- **Verification reality:** in Godot `--script` mode, autoloads + physics are unavailable; only `class_name` globals (pure data/math) are testable headless. Pure logic gets a throwaway probe (deleted within its task); scene/physics/visual behavior is verified by the Task 8 F5 checklist. Every task ends with a clean compile gate.

## Test Harness (one-time setup; already valid this session)

```bash
# If /tmp/godot46 is missing, recreate it:
mkdir -p /tmp/godot46 && python3 -c "import zipfile; zipfile.ZipFile('/mnt/c/Users/thela/Downloads/Godot_v4.6.3-stable_mono_win64.zip').extractall('/tmp/godot46')"
chmod +x "/tmp/godot46/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe"
```

**`GODOT`** = `/tmp/godot46/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe`

**Compile gate** (run after every task; baseline is currently clean):
```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --quit 2>&1 | grep -iE "SCRIPT ERROR|PARSE ERROR"
# Expected: NO output. (A benign "ERROR: EditorSettings not instantiated..." may print on the raw run — it is NOT a script error and is filtered out by this grep.)
```

**Probe run** (probe file lives at the project root → `res://probe_X.gd`):
```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_X.gd 2>&1 | grep -E "PROBE"
# Expected: "PROBE PASS: ..."
```

Branch: all work on `feat/arsenal-expansion` (already created; the spec commit `d8cc4da` is its first commit).

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `scripts/HazardZone.gd` | lingering damage pool | + `hurts_player` flag (enemy-only weapon pools) |
| `scripts/Beam.gd` | **new** straight-line beam VFX (lavender) | create |
| `scripts/Bullet.gd` | projectile | + on-death detonation (explosive/pool) for delivery shells |
| `scripts/Gun.gd` | firing | + new def keys, `_build_pool_cfg`, beam fire mode + `_fire_beam`/`_enemies_in_beam` |
| `scripts/logic/Weapons.gd` | weapon roster (data) | + 11 entries |
| `scripts/loot/Crates.gd` | crate defs (data) | extend 3 type-crate `bases` |
| `gen_palette_sprites.py` *(home repo `/home/larryun`)* | icon generator | + 11 `GUNS` entries → writes `art/weapons/<id>.png` into the game repo |

---

### Task 1: HazardZone enemy-only flag

**Files:**
- Modify: `scripts/HazardZone.gd`

**Interfaces:**
- Produces: `HazardZone.configure_hazard(cfg)` now honors `cfg["hurts_player"]` (bool, default `true`). When `false`, the pool damages enemies only.

- [ ] **Step 1: Add the flag field.** In `scripts/HazardZone.gd`, find the var block ending with `var _tick := 0.0` and add a line after it:

```gdscript
	var _tick := 0.0
	var _hurts_player := true
```

- [ ] **Step 2: Read it in `configure_hazard`.** Find `_drift = float(cfg.get("drift", 0.0))` inside `configure_hazard()` and add the read right after it:

```gdscript
	_drift = float(cfg.get("drift", 0.0))
	_hurts_player = bool(cfg.get("hurts_player", true))
```

- [ ] **Step 3: Gate the player-damage block in `_apply`.** Replace this block:

```gdscript
	var player := tree.get_first_node_in_group("player")
	if player != null and is_instance_valid(player):
		if (player as Node2D).global_position.distance_squared_to(global_position) <= r2:
			player.take_damage(_dps * dt * GameConfig.PLAYER_HAZARD_DMG_MULT)
			if _slow > 0.0 and player.has_method("apply_slow"):
				player.apply_slow(_slow, _slow_dur)
```

with:

```gdscript
	if _hurts_player:
		var player := tree.get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			if (player as Node2D).global_position.distance_squared_to(global_position) <= r2:
				player.take_damage(_dps * dt * GameConfig.PLAYER_HAZARD_DMG_MULT)
				if _slow > 0.0 and player.has_method("apply_slow"):
					player.apply_slow(_slow, _slow_dur)
```

- [ ] **Step 4: Compile gate.** Run the compile gate command. Expected: no output (clean). Env hazards never set `hurts_player` → default `true` → unchanged.

- [ ] **Step 5: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/HazardZone.gd
git commit -m "Arsenal: HazardZone hurts_player flag (enemy-only weapon pools)"
```

---

### Task 2: Beam VFX

**Files:**
- Create: `scripts/Beam.gd`

**Interfaces:**
- Produces: `class_name Beam extends Node2D` with `var start: Vector2`, `var end: Vector2`. Caller sets both, `add_child`s it; it draws a fading lavender line and frees itself.

- [ ] **Step 1: Create `scripts/Beam.gd`** with this exact content:

```gdscript
class_name Beam
extends Node2D
## Transient straight-line beam VFX for the Railgun: draws one thick fading line
## from `start` to `end`, then frees itself. Drawn in C4 lavender (the player color),
## so unlike Lightning (cyan) / FlameCone (orange) it stays INSIDE the strict 4-color
## palette — no new palette exception.

const COLOR := Color(0.878, 0.898, 1.0)   # C4 lavender (matches Shockwave.RING_COLOR)
const LIFE := 0.12                          # seconds visible
const CORE_WIDTH := 6.0                     # bright core thickness
const GLOW_WIDTH := 12.0                    # faint wide glow thickness

var start := Vector2.ZERO                    # world-space beam origin
var end := Vector2.ZERO                      # world-space beam end
var _life := LIFE

func _ready() -> void:
	z_index = 5

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var a := clampf(_life / LIFE, 0.0, 1.0)
	var s := to_local(start)
	var e := to_local(end)
	draw_line(s, e, Color(COLOR.r, COLOR.g, COLOR.b, 0.25 * a), GLOW_WIDTH)
	draw_line(s, e, Color(COLOR.r, COLOR.g, COLOR.b, a), CORE_WIDTH)
```

- [ ] **Step 2: Compile gate.** Run the compile gate. Expected: no output (clean — the new `class_name Beam` parses).

- [ ] **Step 3: Commit.**

```bash
git add scripts/Beam.gd
git commit -m "Arsenal: Beam VFX (straight lavender line, in-palette) for the Railgun"
```

---

### Task 3: Bullet delivery-shell on-death

**Files:**
- Modify: `scripts/Bullet.gd`

**Interfaces:**
- Consumes: `Shockwave.blast(radius, damage, force, gun, player)` (from `scripts/Shockwave.gd`); `HazardZone.configure_hazard(cfg)` with `hurts_player:false` (Task 1).
- Produces: `Bullet` honors `var explode_radius: float`, `var explode_force: float`, `var pool_cfg: Dictionary` (set by `Gun._spawn_bullet` in Task 4). When either is set, the bullet is a "delivery shell": it deals no direct hit/pierce, and detonates its effect on first solid contact or at range/lifetime end.

- [ ] **Step 1: Add shell fields.** In `scripts/Bullet.gd`, find the talent-payload var group ending with `var burn_duration := 0.0` and add after it:

```gdscript
	var burn_duration := 0.0

	# Delivery-shell on-death effects (set by Gun._spawn_bullet; inert on a normal bullet).
	var explode_radius := 0.0      # >0: detonate a Shockwave on death (Grenade Launcher)
	var explode_force := 0.0       # knockback force for the explosion
	var pool_cfg := {}             # non-empty: spawn an enemy-only HazardZone on death (Acid Cannon)
```

- [ ] **Step 2: Add the `_is_shell` / `_detonate` / `_expire` helpers.** Add these three functions to the file (e.g. just above `func _nearest_unhit_enemy()`):

```gdscript
## True when this bullet delivers an on-death effect instead of a direct hit.
func _is_shell() -> bool:
	return explode_radius > 0.0 or not pool_cfg.is_empty()

## Run the on-death effect(s) at the current position. No-op on a normal bullet.
func _detonate() -> void:
	if explode_radius > 0.0:
		var blast := Shockwave.new()
		get_tree().current_scene.add_child(blast)
		blast.global_position = global_position
		var gun = (talent_player.gun if (talent_player != null and is_instance_valid(talent_player)) else null)
		blast.blast(explode_radius, damage, explode_force, gun, talent_player)
	if not pool_cfg.is_empty():
		var zone := HazardZone.new()
		get_tree().current_scene.add_child(zone)
		zone.global_position = global_position
		zone.configure_hazard(pool_cfg)

## Detonate (if a shell) then free. Used at every end-of-life exit.
func _expire() -> void:
	if _is_shell():
		_detonate()
	queue_free()
```

- [ ] **Step 3: Route the range/lifetime exits through `_expire`.** In `_physics_process`, replace:

```gdscript
	if _traveled >= max_travel:
		queue_free()
		return
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()
```

with:

```gdscript
	if _traveled >= max_travel:
		_expire()
		return
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		_expire()
```

- [ ] **Step 4: Intercept shells at the top of `_on_body_entered`.** Add this as the first statement inside `func _on_body_entered(body) -> void:` (before the `cover` check):

```gdscript
func _on_body_entered(body) -> void:
	if _is_shell():
		# Delivery shells ignore direct damage/pierce — detonate on the first solid contact.
		if body.is_in_group("cover") or body.is_in_group("destructibles") or body.is_in_group("enemies"):
			_detonate()
			queue_free()
		return
```

(Leave the rest of `_on_body_entered` exactly as-is — it now only runs for normal bullets.)

- [ ] **Step 5: Compile gate.** Run the compile gate. Expected: no output (clean). `Shockwave` and `HazardZone` are `class_name` globals, resolvable from `Bullet`.

- [ ] **Step 6: Commit.**

```bash
git add scripts/Bullet.gd
git commit -m "Arsenal: Bullet delivery-shell detonation (explosive via Shockwave, pool via HazardZone)"
```

---

### Task 4: Gun new-mechanic plumbing (keys + pool cfg + beam)

**Files:**
- Modify: `scripts/Gun.gd`
- Test (throwaway): `probe_beam.gd`

**Interfaces:**
- Consumes: `Bullet.explode_radius/explode_force/pool_cfg` (Task 3); `Beam.start/end` (Task 2); `Hazards.GREEN`/`Hazards.ORANGE` (`scripts/logic/Hazards.gd`); `LineOfSight.filter_visible(origin, nodes, space)`, `TalentEngine.roll_damage`/`process_hit` (already used by `_fire_cone`).
- Produces: `Gun.configure()` reads `explode_radius, explode_force, pool, pool_radius, pool_duration, pool_slow, pool_slow_dur, beam_width`; `fire_mode == "beam"` dispatches `_fire_beam`; static `Gun._beam_contains(origin, dir, max_range, half_width, p) -> bool` and `Gun._enemies_in_beam(origin, dir, max_range, half_width, enemies) -> Array`.

- [ ] **Step 1: Add the new state vars.** In `scripts/Gun.gd`, find the fire-mode var group ending with `var jump_falloff := 0.8` and add after it:

```gdscript
	var jump_falloff := 0.8            # lightning mode: damage x this per jump
	var explode_radius := 0.0          # explosive shell blast radius (Grenade Launcher)
	var explode_force := 0.0           # explosive shell knockback force
	var pool_family := ""              # hazard-pool shell kind ("" = none; "acid" = Acid Cannon)
	var pool_radius := 90.0
	var pool_duration := 3.0
	var pool_slow := 0.0
	var pool_slow_dur := 0.0
	var beam_width := 28.0             # beam mode: half-corridor width (px)
```

- [ ] **Step 2: Read the new keys in `configure`.** Find `jump_falloff = float(def.get("jump_falloff", 0.8))` inside `configure()` and add after it:

```gdscript
	jump_falloff = float(def.get("jump_falloff", 0.8))
	explode_radius = float(def.get("explode_radius", 0.0))
	explode_force = float(def.get("explode_force", 0.0))
	pool_family = String(def.get("pool", ""))
	pool_radius = float(def.get("pool_radius", 90.0))
	pool_duration = float(def.get("pool_duration", 3.0))
	pool_slow = float(def.get("pool_slow", 0.0))
	pool_slow_dur = float(def.get("pool_slow_dur", 0.0))
	beam_width = float(def.get("beam_width", 28.0))
```

- [ ] **Step 3: Set shell params in `_spawn_bullet` + add `_build_pool_cfg`.** Find the end of `_spawn_bullet`:

```gdscript
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
```

and change it to:

```gdscript
	bullet.explode_radius = explode_radius
	bullet.explode_force = explode_force
	if pool_family != "":
		bullet.pool_cfg = _build_pool_cfg()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
```

Then add this helper (e.g. just below `_spawn_bullet`):

```gdscript
## Build the enemy-only HazardZone config for a pool-dropping shell (Acid Cannon).
## dps = this gun's damage, so damage cards/affixes scale the pool.
func _build_pool_cfg() -> Dictionary:
	var color = Hazards.GREEN if pool_family == "acid" else Hazards.ORANGE
	return {
		"color": color, "dps": damage, "radius": pool_radius, "duration": pool_duration,
		"slow": pool_slow, "slow_dur": pool_slow_dur, "stun": 0.0, "chain": 0,
		"drift": 0.0, "hurts_player": false,
	}
```

- [ ] **Step 4: Add the beam geometry statics.** Add both functions to `scripts/Gun.gd` (next to the other static targeting helpers at the bottom):

```gdscript
## Pure geometry: is world point `p` inside the beam corridor from `origin` along `dir`?
static func _beam_contains(origin: Vector2, dir: Vector2, max_range: float, half_width: float, p: Vector2) -> bool:
	var d := dir.normalized()
	var to := p - origin
	var along := to.dot(d)
	if along < 0.0 or along > max_range:
		return false
	return absf(to.dot(d.orthogonal())) <= half_width

## Every enemy inside the beam corridor. Static + pure (delegates to _beam_contains) so a
## probe can verify selection headlessly.
static func _enemies_in_beam(origin: Vector2, dir: Vector2, max_range: float, half_width: float, enemies: Array) -> Array:
	var hits: Array = []
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if _beam_contains(origin, dir, max_range, half_width, (e as Node2D).global_position):
			hits.append(e)
	return hits
```

- [ ] **Step 5: Write the beam geometry probe.** Create `probe_beam.gd` at the project root:

```gdscript
extends SceneTree
## Throwaway probe: Gun._beam_contains corridor geometry. Pure math, headless-safe.

func _init() -> void:
	var fails := 0
	var O := Vector2.ZERO
	var R := Vector2.RIGHT
	# On-axis, in range -> hit.
	if not Gun._beam_contains(O, R, 1000.0, 28.0, Vector2(500, 0)):
		print("PROBE FAIL: on-axis in-range point should be in the beam"); fails += 1
	# Behind the origin -> miss.
	if Gun._beam_contains(O, R, 1000.0, 28.0, Vector2(-50, 0)):
		print("PROBE FAIL: point behind the origin must miss"); fails += 1
	# Past the range -> miss.
	if Gun._beam_contains(O, R, 1000.0, 28.0, Vector2(1500, 0)):
		print("PROBE FAIL: point past max_range must miss"); fails += 1
	# Within half-width -> hit; outside -> miss.
	if not Gun._beam_contains(O, R, 1000.0, 28.0, Vector2(400, 20)):
		print("PROBE FAIL: point within half_width should hit"); fails += 1
	if Gun._beam_contains(O, R, 1000.0, 28.0, Vector2(400, 40)):
		print("PROBE FAIL: point outside half_width must miss"); fails += 1
	# Diagonal aim still works.
	if not Gun._beam_contains(O, Vector2(1, 1), 1000.0, 28.0, Vector2(300, 300)):
		print("PROBE FAIL: diagonal on-axis point should hit"); fails += 1
	# _enemies_in_beam returns only in-corridor nodes.
	var a := Node2D.new(); a.position = Vector2(300, 0)
	var b := Node2D.new(); b.position = Vector2(300, 200)
	var hits := Gun._enemies_in_beam(O, R, 1000.0, 28.0, [a, b])
	if hits.size() != 1 or hits[0] != a:
		print("PROBE FAIL: _enemies_in_beam should return only the in-corridor node"); fails += 1
	a.free(); b.free()
	if fails == 0:
		print("PROBE PASS: beam corridor geometry correct")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()
```

- [ ] **Step 6: Run the probe — expect FAIL.** Run:

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_beam.gd 2>&1 | grep -E "PROBE|SCRIPT ERROR"
```

Expected at this point: a SCRIPT/parse error or PROBE FAIL — but since Step 4 already added the statics, this should actually PASS. (If you are doing strict red-first, run the probe BEFORE Step 4: it errors with "Invalid call ... _beam_contains".) Proceed once the statics exist.

- [ ] **Step 7: Add the beam fire path + dispatch.** In `_fire`, add the `"beam"` case:

```gdscript
func _fire(dir: Vector2) -> bool:
	match fire_mode:
		"cone":      return _fire_cone(dir)
		"lightning": return _fire_lightning(dir)
		"beam":      return _fire_beam(dir)
		_:           return _fire_projectile(dir)
	return false  # unreachable; satisfies the static checker
```

Then add `_fire_beam` + `_spawn_beam` (next to `_fire_cone`):

```gdscript
func _fire_beam(dir: Vector2) -> bool:
	_show_muzzle(dir.angle())
	var enemies := LineOfSight.filter_visible(global_position, get_tree().get_nodes_in_group("enemies"), get_world_2d().direct_space_state)
	var hits := _enemies_in_beam(global_position, dir, gun_range, beam_width, enemies)
	var player := get_parent() as Player
	for e in hits:
		if not is_instance_valid(e):
			continue
		var hit_pos: Vector2 = e.global_position
		var roll := TalentEngine.roll_damage(damage, talent_payload)
		e.take_damage(float(roll["damage"]))
		var killed := not is_instance_valid(e)
		if not killed:
			if e.has_method("flash_hit"):
				e.flash_hit()
			if incendiary and e.has_method("ignite"):
				e.ignite(burn_dps, burn_duration)
		if not talent_payload.is_empty():
			TalentEngine.process_hit(e, hit_pos, damage, killed, talent_payload, {
				"player": player, "gun": self, "dir": dir, "tree": get_tree(),
			})
	_spawn_beam(dir)
	return true

func _spawn_beam(dir: Vector2) -> void:
	var beam := Beam.new()
	beam.start = global_position
	beam.end = global_position + dir * gun_range
	get_tree().current_scene.add_child(beam)
```

- [ ] **Step 8: Run the probe — expect PASS.**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_beam.gd 2>&1 | grep -E "PROBE"
```

Expected: `PROBE PASS: beam corridor geometry correct`

- [ ] **Step 9: Compile gate.** Run the compile gate. Expected: no output (clean).

- [ ] **Step 10: Delete the probe + commit.**

```bash
rm probe_beam.gd
git add scripts/Gun.gd
git commit -m "Arsenal: Gun beam fire mode + explosive/pool shell plumbing + new def keys"
```

---

### Task 5: The 11 weapon defs

**Files:**
- Modify: `scripts/logic/Weapons.gd`
- Test (throwaway): `probe_arsenal.gd`

**Interfaces:**
- Produces: `Weapons.all()` returns 21 entries; the 11 new ids `magnum, machine_pistol, pdw, auto_shotgun, slug_gun, battle_rifle, railgun, anti_materiel, grenade_launcher, lmg, acid_cannon`.

- [ ] **Step 1: Write the roster probe.** Create `probe_arsenal.gd` at the project root:

```gdscript
extends SceneTree
## Throwaway probe: weapon roster integrity. Pure data (Weapons is a class_name global).

const CATEGORIES := ["Pistol", "SMG", "Shotgun", "Rifle", "Sniper", "Heavy", "Special"]
const UPGRADE_IDS := ["damage", "fire_rate", "range", "bullet_speed", "ricochet", "pierce", "reload", "mag", "choke", "projectile", "incendiary"]
const FIRE_MODES := ["projectile", "cone", "lightning", "beam"]

func _init() -> void:
	var fails := 0
	var all := Weapons.all()
	if all.size() != 21:
		print("PROBE FAIL: expected 21 weapons, got %d" % all.size()); fails += 1
	var ids := {}
	var cat_counts := {}
	for c in CATEGORIES:
		cat_counts[c] = 0
	for def in all:
		var id := String(def.get("id", ""))
		if id == "" or ids.has(id):
			print("PROBE FAIL: missing/duplicate id '%s'" % id); fails += 1
		ids[id] = true
		var cat := String(def.get("category", ""))
		if not CATEGORIES.has(cat):
			print("PROBE FAIL: %s has bad category '%s'" % [id, cat]); fails += 1
		else:
			cat_counts[cat] += 1
		if float(def.get("damage", 0.0)) <= 0.0:
			print("PROBE FAIL: %s has non-positive damage" % id); fails += 1
		if not FIRE_MODES.has(String(def.get("fire_mode", "projectile"))):
			print("PROBE FAIL: %s has bad fire_mode" % id); fails += 1
		for u in def.get("upgrades", []):
			if not UPGRADE_IDS.has(String(u)):
				print("PROBE FAIL: %s has unknown upgrade '%s'" % [id, u]); fails += 1
	for c in CATEGORIES:
		if cat_counts[c] != 3:
			print("PROBE FAIL: category %s has %d guns (want 3)" % [c, cat_counts[c]]); fails += 1
	# New-mechanic guns carry the right keys.
	var by_id := {}
	for def in all:
		by_id[String(def["id"])] = def
	if not by_id.has("railgun") or String(by_id.get("railgun", {}).get("fire_mode", "")) != "beam":
		print("PROBE FAIL: railgun must be fire_mode beam"); fails += 1
	if float(by_id.get("grenade_launcher", {}).get("explode_radius", 0.0)) <= 0.0:
		print("PROBE FAIL: grenade_launcher needs explode_radius > 0"); fails += 1
	if String(by_id.get("acid_cannon", {}).get("pool", "")) != "acid":
		print("PROBE FAIL: acid_cannon needs pool == 'acid'"); fails += 1
	if fails == 0:
		print("PROBE PASS: roster is 21 guns, 3 per category, all keys valid")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()
```

- [ ] **Step 2: Run the probe — expect FAIL.**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_arsenal.gd 2>&1 | grep -E "PROBE"
```

Expected: `PROBE FAILED` (currently 10 guns, not 21).

- [ ] **Step 3: Add the 11 defs.** In `scripts/logic/Weapons.gd`, insert these 11 dictionaries into the `all()` array, immediately after the `flamethrower` entry and before the closing `]`:

```gdscript
			{
				"id": "magnum", "name": "Magnum", "desc": "Hand cannon — slow, brutal, punches through", "category": "Pistol",
				"fire_mode": "projectile", "base_pierce": 1,
				"damage": 55.0, "fire_interval": 0.45, "bullet_speed": 950.0,
				"range": 700.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 6, "reload_time": 1.4,
				"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
			},
			{
				"id": "machine_pistol", "name": "Machine Pistol", "desc": "Full-auto sidearm — spray it", "category": "Pistol",
				"damage": 14.0, "fire_interval": 0.09, "bullet_speed": 850.0,
				"range": 480.0, "projectiles": 1, "spread": 0.10,
				"mag_size": 18, "reload_time": 1.2,
				"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
			},
			{
				"id": "pdw", "name": "PDW", "desc": "Compact PDW — blistering fire rate, deep mag", "category": "SMG",
				"damage": 10.0, "fire_interval": 0.06, "bullet_speed": 900.0,
				"range": 500.0, "projectiles": 1, "spread": 0.07,
				"mag_size": 40, "reload_time": 1.5,
				"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "projectile", "pierce", "reload", "mag"],
			},
			{
				"id": "auto_shotgun", "name": "Auto Shotgun", "desc": "Semi-auto — keeps the lead coming", "category": "Shotgun",
				"damage": 12.0, "fire_interval": 0.30, "bullet_speed": 800.0,
				"range": 360.0, "projectiles": 4, "spread": 0.40,
				"mag_size": 8, "reload_time": 1.9,
				"upgrades": ["damage", "fire_rate", "projectile", "choke", "pierce", "incendiary", "reload", "mag"],
			},
			{
				"id": "slug_gun", "name": "Slug Gun", "desc": "Solid slug — a shotgun that reaches out and pierces", "category": "Shotgun",
				"fire_mode": "projectile", "base_pierce": 2,
				"damage": 60.0, "fire_interval": 0.70, "bullet_speed": 1000.0,
				"range": 650.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 5, "reload_time": 2.0,
				"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
			},
			{
				"id": "battle_rifle", "name": "Battle Rifle", "desc": "Marksman DMR — fast, accurate, hits hard", "category": "Rifle",
				"damage": 45.0, "fire_interval": 0.28, "bullet_speed": 1200.0,
				"range": 850.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 12, "reload_time": 1.7,
				"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
			},
			{
				"id": "railgun", "name": "Railgun", "desc": "Magnetic rail — instant beam, pierces everything in line", "category": "Sniper",
				"fire_mode": "beam", "beam_width": 28.0,
				"damage": 90.0, "fire_interval": 0.85, "bullet_speed": 0.0,
				"range": 1100.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 5, "reload_time": 2.2,
				"upgrades": ["damage", "fire_rate", "range", "incendiary", "reload", "mag"],
			},
			{
				"id": "anti_materiel", "name": "Anti-Materiel Rifle", "desc": ".50 cal — devastating, line-piercing, painfully slow", "category": "Sniper",
				"fire_mode": "projectile", "base_pierce": 3,
				"damage": 160.0, "fire_interval": 1.10, "bullet_speed": 1600.0,
				"range": 1300.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 4, "reload_time": 2.6,
				"upgrades": ["damage", "fire_rate", "range", "pierce", "bullet_speed", "ricochet", "reload", "mag"],
			},
			{
				"id": "grenade_launcher", "name": "Grenade Launcher", "desc": "Lobbed shells detonate in a crowd-clearing blast", "category": "Heavy",
				"fire_mode": "projectile", "explode_radius": 130.0, "explode_force": 600.0,
				"damage": 50.0, "fire_interval": 0.80, "bullet_speed": 650.0,
				"range": 600.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 6, "reload_time": 2.2,
				"upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
			},
			{
				"id": "lmg", "name": "LMG", "desc": "Belt-fed — more punch than the minigun, less spray", "category": "Heavy",
				"damage": 16.0, "fire_interval": 0.07, "bullet_speed": 880.0,
				"range": 600.0, "projectiles": 1, "spread": 0.09,
				"mag_size": 100, "reload_time": 3.2,
				"upgrades": ["damage", "fire_rate", "choke", "bullet_speed", "pierce", "incendiary", "reload", "mag"],
			},
			{
				"id": "acid_cannon", "name": "Acid Cannon", "desc": "Caustic shells leave a melting acid pool — area denial", "category": "Special",
				"fire_mode": "projectile", "pool": "acid",
				"pool_radius": 90.0, "pool_duration": 3.5, "pool_slow": 0.4, "pool_slow_dur": 1.0,
				"damage": 35.0, "fire_interval": 0.55, "bullet_speed": 700.0,
				"range": 520.0, "projectiles": 1, "spread": 0.0,
				"mag_size": 10, "reload_time": 2.0,
				"upgrades": ["damage", "fire_rate", "range", "projectile", "reload", "mag"],
			},
```

- [ ] **Step 4: Run the probe — expect PASS.**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_arsenal.gd 2>&1 | grep -E "PROBE"
```

Expected: `PROBE PASS: roster is 21 guns, 3 per category, all keys valid`

- [ ] **Step 5: Compile gate.** Run the compile gate. Expected: no output.

- [ ] **Step 6: Delete the probe + commit.**

```bash
rm probe_arsenal.gd
git add scripts/logic/Weapons.gd
git commit -m "Arsenal: 11 new gun defs (10 -> 21, every category to 3)"
```

---

### Task 6: Crate type-pool wiring

**Files:**
- Modify: `scripts/loot/Crates.gd`
- Test (throwaway): `probe_crates.gd`

**Interfaces:**
- Consumes: `Weapons.all()` (Task 5), `LootRoller.roll(rarity, base_id)`, `LootRoller.roll_from_crate(crate)`, `Crates.all()`.
- Produces: the 3 type crates include the new bases.

- [ ] **Step 1: Write the crate probe.** Create `probe_crates.gd` at the project root:

```gdscript
extends SceneTree
## Throwaway probe: crate type-pools resolve to real weapons; loot rolls are valid.

func _init() -> void:
	var fails := 0
	var ids := {}
	for def in Weapons.all():
		ids[String(def["id"])] = true
	# Every crate's declared bases must be real weapon ids.
	for crate in Crates.all():
		for b in crate.get("bases", []):
			if not ids.has(String(b)):
				print("PROBE FAIL: crate %s lists unknown base '%s'" % [crate["id"], b]); fails += 1
	# Each new base must be slotted into its expected type crate.
	var want := {
		"precision_pack": ["auto_shotgun", "slug_gun", "railgun", "anti_materiel"],
		"auto_case": ["pdw", "machine_pistol", "lmg"],
		"standard_arms": ["magnum", "battle_rifle", "grenade_launcher"],
	}
	for cid in want:
		var crate := Crates.get_crate(cid)
		var bases: Array = crate.get("bases", [])
		for b in want[cid]:
			if not bases.has(b):
				print("PROBE FAIL: crate %s missing base '%s'" % [cid, b]); fails += 1
	# LootRoller produces a valid instance for each new base across the rarity ladder.
	var new_bases := ["magnum", "machine_pistol", "pdw", "auto_shotgun", "slug_gun", "battle_rifle", "railgun", "anti_materiel", "grenade_launcher", "lmg", "acid_cannon"]
	for b in new_bases:
		for r in range(1, 9):
			var inst := LootRoller.roll(r, b)
			if String(inst.get("base", "")) != b:
				print("PROBE FAIL: roll(%d,%s) gave base '%s'" % [r, b, inst.get("base", "")]); fails += 1
				break
			if int(inst.get("rarity", 0)) < 1:
				print("PROBE FAIL: roll(%d,%s) has bad rarity" % [r, b]); fails += 1
				break
	if fails == 0:
		print("PROBE PASS: crate pools wired + loot rolls valid for all new bases")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()
```

- [ ] **Step 2: Run the probe — expect FAIL.**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_crates.gd 2>&1 | grep -E "PROBE"
```

Expected: `PROBE FAILED` (type crates don't yet contain the new bases).

- [ ] **Step 3: Extend the 3 type-crate `bases`.** In `scripts/loot/Crates.gd`:

Replace `"bases": ["sniper", "shotgun"],` with:
```gdscript
				"bases": ["sniper", "shotgun", "auto_shotgun", "slug_gun", "railgun", "anti_materiel"],
```

Replace `"bases": ["smg", "ak47", "nailgun"],` with:
```gdscript
				"bases": ["smg", "ak47", "nailgun", "pdw", "machine_pistol", "lmg"],
```

Replace `"bases": ["pistol", "rifle", "minigun"],` with:
```gdscript
				"bases": ["pistol", "rifle", "minigun", "magnum", "battle_rifle", "grenade_launcher"],
```

- [ ] **Step 4: Run the probe — expect PASS.**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --script res://probe_crates.gd 2>&1 | grep -E "PROBE"
```

Expected: `PROBE PASS: crate pools wired + loot rolls valid for all new bases`

- [ ] **Step 5: Compile gate.** Run the compile gate. Expected: no output.

- [ ] **Step 6: Delete the probe + commit.**

```bash
rm probe_crates.gd
git add scripts/loot/Crates.gd
git commit -m "Arsenal: slot 11 new guns into the 3 type crates"
```

---

### Task 7: Weapon icons (home-repo generator)

**Files:**
- Modify: `/home/larryun/gen_palette_sprites.py` (the `GUNS` dict) — home repo
- Create (generated): `art/weapons/<id>.png` ×11 + their `.import` — game repo

**Interfaces:**
- Consumes: nothing. Produces: 11 lavender 64×64 icons at `res://art/weapons/<id>.png`. (Until they exist, `WeaponInstance.icon` falls back to `_placeholder.png`, so guns are already playable.)

- [ ] **Step 1: Add the 11 entries to `GUNS`.** In `/home/larryun/gen_palette_sprites.py`, add these key/value pairs inside the `GUNS = { ... }` dict (each value is a list of `(x, y, w, h)` C4 rectangles on a 64×64 canvas — match the existing silhouette style; Larry can overwrite with hand art later at the same path):

```python
    "magnum":        [(26,30,22,4),(18,27,12,11),(15,30,6,7),(22,38,6,12)],
    "machine_pistol":[(28,28,16,5),(22,26,14,10),(25,36,6,13),(18,29,5,6)],
    "pdw":           [(28,27,18,5),(18,25,18,10),(22,35,5,16),(13,27,6,7)],
    "auto_shotgun":  [(20,26,32,7),(28,33,14,4),(12,28,12,9),(24,40,7,10)],
    "slug_gun":      [(18,29,34,5),(12,27,10,9),(8,30,8,7)],
    "battle_rifle":  [(24,28,28,4),(14,26,14,10),(8,28,8,8),(28,24,8,3)],
    "railgun":       [(14,28,40,3),(14,34,40,3),(16,26,10,12),(10,30,8,8),(50,25,3,14),(56,28,3,8)],
    "anti_materiel": [(14,30,40,4),(48,28,8,3),(48,33,8,3),(16,28,12,9),(10,31,8,7),(22,38,3,9),(30,38,3,9)],
    "grenade_launcher":[(24,28,26,8),(46,27,8,10),(18,26,12,12),(12,29,8,9),(22,40,7,10)],
    "lmg":           [(26,29,28,5),(14,25,16,14),(8,29,8,9),(30,23,10,3),(18,39,4,9),(26,39,4,9)],
    "acid_cannon":   [(16,24,12,22),(28,30,18,6),(46,31,12,5),(58,30,4,6),(30,36,6,11)],
```

- [ ] **Step 2: Generate the sprites.** Run the generator (it writes straight into the game repo's `art/`):

```bash
python3 /home/larryun/gen_palette_sprites.py
```

Expected: `palette sprites written to /mnt/c/Users/thela/Documents/mobile-game/art`

- [ ] **Step 3: Verify the 11 PNGs exist.**

```bash
ls -1 /mnt/c/Users/thela/Documents/mobile-game/art/weapons/{magnum,machine_pistol,pdw,auto_shotgun,slug_gun,battle_rifle,railgun,anti_materiel,grenade_launcher,lmg,acid_cannon}.png
```

Expected: all 11 listed, no "No such file".

- [ ] **Step 4: Compile gate (imports the new PNGs → generates `.import`).** Run the compile gate. Expected: no output.

- [ ] **Step 5: Commit (two repos).**

```bash
# Game repo — the icons + their import metadata, on the feature branch:
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add art/weapons/*.png art/weapons/*.import
git commit -m "Arsenal: 11 weapon icons (gen_palette_sprites weapons())"

# Home repo — the generator change:
cd /home/larryun
git add gen_palette_sprites.py
git commit -m "gen_palette_sprites: 11 new arsenal weapon icons"
```

---

### Task 8: Final verification gate + F5 handoff

**Files:** none (verification + handoff only).

- [ ] **Step 1: Full compile gate, clean.** Run the compile gate. Expected: no output.

- [ ] **Step 2: Re-run the roster + crate probes one final time** (recreate them from Tasks 5/6 if needed, run, confirm `PROBE PASS`, delete). Confirms data integrity after all edits.

- [ ] **Step 3: Confirm branch + commits.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git log --oneline -8
git status -s
```

Expected: 7 task commits on `feat/arsenal-expansion` atop the spec commit; working tree clean (no stray probe files).

- [ ] **Step 4: Hand Larry the F5 checklist** (he runs it on desktop F5 and/or after merge → APK):
  - Equip each new gun (DEV grant / crate) — all 21 appear; icon or placeholder shows.
  - **Magnum** one-shots trash + pierces 1; **Machine Pistol** / **PDW** spray fast.
  - **Auto Shotgun** semi-auto cadence; **Slug Gun** pierces at range.
  - **Battle Rifle** fast + accurate; **Anti-Materiel** line-pierces 3+.
  - **Railgun**: instant lavender beam; every enemy in the line takes damage; beam respects cover.
  - **Grenade Launcher**: shell flies → detonates in a crowd → ring + AoE damage + knockback.
  - **Acid Cannon**: shell lands → green pool; enemies in it melt + slow; **the player takes NO damage standing in it**.
  - **Regression — env hazards still hurt the player**: barrel fire / chem acid / transformer fields still damage the player.
  - **Regression — existing 10 guns** behave exactly as before.
  - New guns drop from the right type crates + roll affixes ("Razor Railgun" etc.).

- [ ] **Step 5: Merge handoff.** Do NOT auto-merge. After Larry's F5 passes, use `superpowers:finishing-a-development-branch` to merge `feat/arsenal-expansion` → master and push (push triggers the APK pipeline → new versionCode).

---

## Self-Review

**1. Spec coverage:**
- 11 guns w/ stats → Task 5 ✓
- New def keys (explode_radius/force, pool*, beam_width) → Task 4 (configure) ✓
- Explosive via Shockwave → Task 3 (`_detonate`) ✓
- Beam mode + Beam.gd (in-palette) → Task 2 + Task 4 ✓
- Hazard pool + enemy-only flag → Task 1 + Task 3 + Task 4 (`_build_pool_cfg`) ✓
- Delivery shells skip direct damage/pierce → Task 3 (Step 4) ✓
- Damage flows through `damage` (dps = damage) → Task 4 (`_build_pool_cfg`), Task 3 (blast uses `damage`) ✓
- Crate type-pool wiring → Task 6 ✓
- Icons → Task 7 ✓
- Verification (headless + F5) → Tasks' probes + Task 8 ✓

**2. Placeholder scan:** No TBD/TODO; every code step shows complete code. ✓

**3. Type consistency:** `_build_pool_cfg` cfg keys (`color,dps,radius,duration,slow,slow_dur,stun,chain,drift,hurts_player`) match `HazardZone.configure_hazard`'s `cfg.get(...)` reads (Task 1 adds `hurts_player`). `Shockwave.blast(radius, damage, force, gun, player)` arg order matches `scripts/Shockwave.gd`. `Beam.start/end` set in `_spawn_beam` match `Beam.gd`. `_beam_contains`/`_enemies_in_beam` signatures match the probe calls. ✓

## Notes / risks

- `_detonate` adds `Shockwave`/`HazardZone` to `get_tree().current_scene` before freeing the bullet — they are independent nodes, so freeing the bullet does not affect them.
- The Railgun beam fires whenever the player is standing still (like every gun), including into empty air — by design (it shows a beam; consistent with the cone). It does not gate on a target the way the Tesla does.
- Shockwave damages enemies only (not cover/destructibles); a grenade vs a wall still clears nearby enemies. Adding destructible damage to the blast is out of scope (YAGNI).
- If `Node2D.global_position` proves unavailable in `--script` mode, the `_enemies_in_beam` portion of `probe_beam.gd` can be dropped — `_beam_contains` (pure Vector2) is the core assertion and is fully headless-safe.

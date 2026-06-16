# Weapon Talents & Stats Expansion v1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grow the crate-weapon loot layer — talent catalog 10→31 (5 new combat behaviors + 16 data talents), affixes 7→31 (24 themed archetypes, legacy excluded from rolls), plus a roll-quality readout in the inspection popup — all pure-RNG, no save migration.

**Architecture:** Extends the existing data-driven loot system (`scripts/loot/`). Talents are catalog dicts whose `kind` is dispatched by `TalentEngine.resolve_payload`/`process_hit`; new behaviors add a `match` arm in each plus at most one combat hook on `Enemy`/`Gun`/`Bullet`. Affixes are catalog dicts the roller samples by rarity. The popup reads pure helpers on `WeaponInstance`. Everything stores only `0..1` rolls and resolves on read, so old saves keep working.

**Tech Stack:** Godot 4.6 + GDScript. No unit-test harness in this project — **verification is the headless compile gate + a logic probe**, the project's established workflow.

### Verification commands (used by every task)

**Compile gate** (run from WSL bash; the Windows binary runs via interop). Expected: **no output** (all error lines filtered; the `menu_background.jpg` JPEG-decode line is benign and excluded):

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --quit 2>&1 \
  | grep -iE "error|SCRIPT ERROR|Parse Error" | grep -v "menu_background.jpg"
```

**Logic probe** (Task 14 only):

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --script res://probe_talents.gd 2>&1 \
  | grep -iE "PROBE|error"
```

### File map

| File | Responsibility | Tasks |
|---|---|---|
| `scripts/logic/GameConfig.gd` | new tuning const | 1 |
| `scripts/loot/Talents.gd` | talent catalog (data) | 2, 3 |
| `scripts/Enemy.gd` | vulnerability + freeze combat hooks | 4, 5 |
| `scripts/Gun.gd` | surge + reload-nova + overpen producers | 6, 7, 8 |
| `scripts/loot/TalentEngine.gd` | resolve/process arms + `detonate` | 7, 9 |
| `scripts/Bullet.gd` | overpen damage growth | 8 |
| `scripts/loot/Affixes.gd` | themed affixes + legacy flag + rollable pool | 10 |
| `scripts/loot/LootRoller.gd` | roll from the rollable pool | 11 |
| `scripts/loot/WeaponInstance.gd` | roll-quality fields + label helper | 12 |
| `scripts/ui/WeaponDetailPopup.gd` | quality bars under stats + talents | 13 |
| `probe_talents.gd` | throwaway logic probe | 14, 15 |

**Task dependency note:** Tasks 6-8 add the *consumers* (`Gun.add_surge`, reload-nova read, overpen read). They read payload keys (`reload_nova`/`overpen`) that don't exist until Task 9 — that is intentional and safe (`{}.get(k, default)` returns the default, so the feature is dormant until Task 9 wires the producer). Build in order; the game compiles and runs after every task.

---

## Task 1: GameConfig — vulnerability cap

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (after the `UPGRADE_*` block, ~line 31)

- [ ] **Step 1: Add the const**

After the line `const UPGRADE_BURN_DURATION := 3.0     # incendiary burn duration (seconds)` add:

```gdscript

# --- Weapon talents (loot procs) ---
const TALENT_VULN_MAX := 1.0          # Marked: cap the bonus-damage-taken fraction (+100%)
```

- [ ] **Step 2: Compile gate** — run the gate command. Expected: no output.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/logic/GameConfig.gd
git commit -m "Talents: add TALENT_VULN_MAX config const"
```

---

## Task 2: Talents.gd — 16 data talents

**Files:**
- Modify: `scripts/loot/Talents.gd` (inside `all()`, before the closing `]` on ~line 86)

These reuse existing `kind`s, so no engine change is needed.

- [ ] **Step 1: Append the 16 entries**

In `Talents.all()`, immediately **before** the final `]` (after the `executioner` entry), insert:

```gdscript
		# --- Data talents (reuse existing behaviors) ---
		{
			"id": "pilotlight", "name": "Pilot Light", "kind": "onhit_ignite", "tier": 1,
			"color": Color("ff8c42"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance to ignite: %s dmg/s for %ss",
			"mods": [ {"min": 12, "max": 24}, {"min": 6, "max": 14}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "tar", "name": "Tar", "kind": "onhit_slow", "tier": 1,
			"color": Color("6fb7d6"), "level_required": {"min": 1, "max": 5},
			"desc": "%s%% chance to slow the target %s%% for %ss",
			"mods": [ {"min": 20, "max": 35}, {"min": 15, "max": 30}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "marksman", "name": "Marksman", "kind": "crit", "tier": 2,
			"color": Color("ff5b5b"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to crit for +%s%% damage",
			"mods": [ {"min": 12, "max": 22}, {"min": 70, "max": 130} ],
		},
		{
			"id": "adrenaline", "name": "Adrenaline", "kind": "onkill_frenzy", "tier": 2,
			"color": Color("ffae42"), "level_required": {"min": 5, "max": 12},
			"desc": "Kills surge fire rate +%s%% for %ss",
			"mods": [ {"min": 30, "max": 50}, {"min": 2.0, "max": 4.0} ],
		},
		{
			"id": "haymaker", "name": "Haymaker", "kind": "onhit_knockback", "tier": 2,
			"color": Color("b0b0b0"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to knock the target back hard",
			"mods": [ {"min": 25, "max": 45}, {"min": 280, "max": 460} ],
		},
		{
			"id": "rot", "name": "Rot", "kind": "onhit_dot", "tier": 2,
			"color": Color("7bd957"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance to poison: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 25, "max": 40}, {"min": 8, "max": 16}, {"min": 2, "max": 4} ],
		},
		{
			"id": "leech", "name": "Leech", "kind": "onhit_lifesteal", "tier": 2,
			"color": Color("d65a6a"), "level_required": {"min": 8, "max": 16},
			"desc": "%s%% chance on hit to heal %s health",
			"mods": [ {"min": 10, "max": 20}, {"min": 1, "max": 4} ],
		},
		{
			"id": "cluster", "name": "Cluster", "kind": "onkill_explode", "tier": 2,
			"color": Color("ff6644"), "level_required": {"min": 6, "max": 14},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 40, "max": 70}, {"min": 12, "max": 30}, {"min": 60, "max": 110} ],
		},
		{
			"id": "mercy", "name": "Mercy", "kind": "onhit_execute", "tier": 2,
			"color": Color("a05050"), "level_required": {"min": 10, "max": 18},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 5, "max": 10} ],
		},
		{
			"id": "hollowpoint", "name": "Hollowpoint", "kind": "crit", "tier": 3,
			"color": Color("ff1f1f"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to crit for +%s%% damage",
			"mods": [ {"min": 20, "max": 32}, {"min": 100, "max": 180} ],
		},
		{
			"id": "inferno", "name": "Inferno", "kind": "onhit_ignite", "tier": 3,
			"color": Color("ff3300"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to set ablaze: %s dmg/s for %ss",
			"mods": [ {"min": 28, "max": 48}, {"min": 30, "max": 60}, {"min": 3, "max": 5} ],
		},
		{
			"id": "glacial", "name": "Glacial", "kind": "onhit_slow", "tier": 3,
			"color": Color("7fdfff"), "level_required": {"min": 12, "max": 22},
			"desc": "%s%% chance to slow the target %s%% for %ss",
			"mods": [ {"min": 35, "max": 55}, {"min": 50, "max": 75}, {"min": 3, "max": 5} ],
		},
		{
			"id": "arcwelder", "name": "Arc Welder", "kind": "onhit_chain", "tier": 3,
			"color": Color("bff3ff"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to arc to %s enemies for %s%% damage",
			"mods": [ {"min": 30, "max": 45}, {"min": 3, "max": 5}, {"min": 55, "max": 90} ],
		},
		{
			"id": "plague", "name": "Plague", "kind": "onhit_dot", "tier": 3,
			"color": Color("3fbf3f"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance to poison: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 40, "max": 60}, {"min": 18, "max": 34}, {"min": 4, "max": 6} ],
		},
		{
			"id": "daisycutter", "name": "Daisy Cutter", "kind": "onkill_explode", "tier": 3,
			"color": Color("ff2200"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 70, "max": 100}, {"min": 40, "max": 80}, {"min": 140, "max": 240} ],
		},
		{
			"id": "reaper", "name": "Reaper", "kind": "onhit_execute", "tier": 3,
			"color": Color("700000"), "level_required": {"min": 18, "max": 28},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 15, "max": 25} ],
		},
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/loot/Talents.gd
git commit -m "Talents: add 16 data talents (remix existing procs across tiers)"
```

---

## Task 3: Talents.gd — 5 new-behavior talents

**Files:**
- Modify: `scripts/loot/Talents.gd` (the `all()` array + the `kinds` doc comment at top)

The new `kind`s are inert until Task 9 adds their engine arms (`resolve_payload`'s `match` simply skips an unknown kind), so this is safe to land now.

- [ ] **Step 1: Document the new kinds**

In the header doc comment, under the `## kinds (...)` list, append:

```gdscript
##   onhit_vulnerable on hit   — mark the target to take extra damage for a duration
##   onhit_freeze     on hit   — fully stop the target; a hit while frozen shatters it (AoE)
##   onkill_surge     on kill  — next shots gain bonus pierce + extra pellets
##   onreload_nova    on reload — finishing a reload blasts an AoE around the player
##   overpen          passive  — bonus pierce; each enemy pierced grows the shot's damage
```

- [ ] **Step 2: Append the 5 entries**

In `Talents.all()`, before the final `]` (after the Task 2 block), insert:

```gdscript
		# --- New behaviors (engine arms in TalentEngine, hooks in Enemy/Gun/Bullet) ---
		{
			"id": "marked", "name": "Marked", "kind": "onhit_vulnerable", "tier": 2,
			"color": Color("ffd166"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to mark: target takes +%s%% damage for %ss",
			"mods": [ {"min": 20, "max": 40}, {"min": 15, "max": 35}, {"min": 3, "max": 5} ],
		},
		{
			"id": "overflow", "name": "Overflow", "kind": "onkill_surge", "tier": 2,
			"color": Color("ff9f1c"), "level_required": {"min": 6, "max": 12},
			"desc": "Kills grant +%s pierce & +%s shots for %ss",
			"mods": [ {"min": 1, "max": 2}, {"min": 1, "max": 2}, {"min": 2, "max": 4} ],
		},
		{
			"id": "backblast", "name": "Backblast", "kind": "onreload_nova", "tier": 2,
			"color": Color("ff6b35"), "level_required": {"min": 5, "max": 12},
			"desc": "Finishing a reload blasts %s damage (radius %s)",
			"mods": [ {"min": 25, "max": 60}, {"min": 120, "max": 220} ],
		},
		{
			"id": "coldsnap", "name": "Cold Snap", "kind": "onhit_freeze", "tier": 3,
			"color": Color("a8e6ff"), "level_required": {"min": 14, "max": 22},
			"desc": "%s%% chance to freeze %ss; a hit on a frozen enemy shatters for %s dmg (radius %s)",
			"mods": [ {"min": 10, "max": 22}, {"min": 1.0, "max": 2.0}, {"min": 40, "max": 90}, {"min": 80, "max": 140} ],
		},
		{
			"id": "railbreaker", "name": "Railbreaker", "kind": "overpen", "tier": 3,
			"color": Color("c0c0c0"), "level_required": {"min": 12, "max": 22},
			"desc": "Shots pierce +%s enemies, +%s%% damage per pierce",
			"mods": [ {"min": 2, "max": 4}, {"min": 15, "max": 30} ],
		},
```

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/loot/Talents.gd
git commit -m "Talents: add 5 new-behavior talents (Marked/Overflow/Backblast/Cold Snap/Railbreaker)"
```

---

## Task 4: Enemy.gd — vulnerability (Marked)

**Files:**
- Modify: `scripts/Enemy.gd`

- [ ] **Step 1: Add state fields**

After the line `var _slow_time := 0.0` (~line 25) add:

```gdscript
	var _vuln_bonus := 0.0         # extra damage-taken fraction (Marked talent); 0 = none
	var _vuln_time := 0.0
```

(Note: these are indented to match the existing top-level `var` block — one tab. Mirror the surrounding lines exactly.)

- [ ] **Step 2: Add the hook**

After `apply_knockback` (~line 88) add:

```gdscript
## Talent (Marked): take extra damage for a duration. Strongest application wins; capped in take_damage.
func apply_vulnerable(frac: float, duration: float) -> void:
	_vuln_bonus = maxf(_vuln_bonus, frac)
	_vuln_time = maxf(_vuln_time, duration)
```

- [ ] **Step 3: Apply the multiplier in `take_damage`**

Replace the start of `take_damage` (~line 153):

```gdscript
func take_damage(amount: float) -> void:
	_health.take_damage(amount)
```

with:

```gdscript
func take_damage(amount: float) -> void:
	if _vuln_bonus > 0.0:
		amount *= (1.0 + minf(_vuln_bonus, GameConfig.TALENT_VULN_MAX))
	_health.take_damage(amount)
```

- [ ] **Step 4: Tick the timer**

In `_physics_process`, immediately after the slow-tick block (the `if _slow_time > 0.0:` block ending at ~line 113) add:

```gdscript
	if _vuln_time > 0.0:
		_vuln_time -= delta
		if _vuln_time <= 0.0:
			_vuln_bonus = 0.0
```

- [ ] **Step 5: Compile gate** — Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add scripts/Enemy.gd
git commit -m "Enemy: add vulnerability hook (Marked talent damage multiplier)"
```

---

## Task 5: Enemy.gd — freeze (Cold Snap)

**Files:**
- Modify: `scripts/Enemy.gd`

Freeze is handled entirely in the base `Enemy._physics_process`, so subclasses (Ranged/Hive/Exploder) inherit it with no edits — a frozen enemy's velocity is zeroed and its `_act` hook is skipped.

- [ ] **Step 1: Add a tint const + state fields**

After `const KNOCKBACK_DECAY := 900.0` (~line 9) add:

```gdscript
const FROZEN_TINT := Color("3D0099")   # C2 indigo — frozen tell (palette-compliant)
```

After the `_vuln_time` field added in Task 4 add:

```gdscript
	var _frozen := false
	var _freeze_time := 0.0
```

- [ ] **Step 2: Add the hooks**

After `apply_vulnerable` (from Task 4) add:

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

- [ ] **Step 3: Tick the freeze timer**

In `_physics_process`, after the vuln-tick block (Task 4) add:

```gdscript
	if _freeze_time > 0.0:
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			_thaw()
```

- [ ] **Step 4: Stop movement + skip `_act` while frozen**

Replace the movement tail of `_physics_process` (currently ~lines 118-125):

```gdscript
	velocity = _desired_velocity() * _slow_factor

	if _knockback != Vector2.ZERO:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	move_and_slide()
	_act(delta)
```

with:

```gdscript
	velocity = _desired_velocity() * _slow_factor

	if _knockback != Vector2.ZERO:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if _frozen:
		velocity = Vector2.ZERO

	move_and_slide()
	if not _frozen:
		_act(delta)
```

- [ ] **Step 5: Compile gate** — Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add scripts/Enemy.gd
git commit -m "Enemy: add freeze state (Cold Snap stop + indigo tint, skips movement/act)"
```

---

## Task 6: Gun.gd — overflow surge

**Files:**
- Modify: `scripts/Gun.gd`

- [ ] **Step 1: Add state fields**

After `var _frenzy_time := 0.0` (~line 39) add:

```gdscript
	var _surge_pierce := 0             # Overflow: bonus pierce on the next shots
	var _surge_shots := 0              # Overflow: extra pellets on the next shots
	var _surge_time := 0.0
```

- [ ] **Step 2: Add the hook**

After `add_frenzy` (~line 107) add:

```gdscript
## Talent (Overflow): a kill grants bonus pierce + extra pellets to the next shots.
func add_surge(pierce: int, shots: int, duration: float) -> void:
	_surge_pierce = maxi(_surge_pierce, pierce)
	_surge_shots = maxi(_surge_shots, shots)
	_surge_time = maxf(_surge_time, duration)
```

- [ ] **Step 3: Tick the surge timer**

In `_process`, just after the frenzy tick (the `if _frenzy_time > 0.0:` block, ~line 112) add:

```gdscript
	if _surge_time > 0.0:
		_surge_time -= delta
		if _surge_time <= 0.0:
			_surge_pierce = 0
			_surge_shots = 0
```

- [ ] **Step 4: Use extra pellets in `_fire`**

Replace `_fire` (~lines 153-164) with:

```gdscript
func _fire(dir: Vector2) -> void:
	var base_angle := dir.angle()
	_show_muzzle(base_angle)
	var count: int = projectile_count + (_surge_shots if _surge_time > 0.0 else 0)
	if count <= 1:
		var jitter: float = randf_range(-spread, spread) if spread > 0.0 else 0.0
		_spawn_bullet(Vector2.from_angle(base_angle + jitter))
		return
	# Fan pellets evenly across the spread arc (force a small fan if a 1-shot gun gained pellets).
	var arc: float = maxf(spread, 0.20)
	for i in count:
		var t := float(i) / float(count - 1)
		var offset := lerpf(-arc * 0.5, arc * 0.5, t)
		_spawn_bullet(Vector2.from_angle(base_angle + offset))
```

- [ ] **Step 5: Add surge pierce in `_spawn_bullet`**

Replace the line `	bullet.pierce_count = pierce_count` (~line 193) with:

```gdscript
	bullet.pierce_count = pierce_count + (_surge_pierce if _surge_time > 0.0 else 0)
```

- [ ] **Step 6: Compile gate** — Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add scripts/Gun.gd
git commit -m "Gun: add Overflow surge (kill grants temp pierce + extra pellets)"
```

---

## Task 7: TalentEngine.detonate + Gun reload nova (Backblast)

**Files:**
- Modify: `scripts/loot/TalentEngine.gd`
- Modify: `scripts/Gun.gd`

- [ ] **Step 1: Public area-damage helper in TalentEngine**

In `scripts/loot/TalentEngine.gd`, after `process_hit` (before `_roll`, ~line 84) add:

```gdscript
## Public area-damage helper (used by Gun reload-nova and freeze-shatter). Thin wrapper
## over _explode so callers don't need to build a ctx dict.
static func detonate(pos: Vector2, dmg: float, radius: float, tree) -> void:
	_explode(pos, dmg, radius, { "tree": tree })
```

- [ ] **Step 2: Gun stores the resolved nova**

In `scripts/Gun.gd`, after `var talent_payload := {}` (~line 37) add:

```gdscript
	var _reload_nova := {}             # Backblast: {dmg, radius} resolved from talent_payload; {} = none
```

- [ ] **Step 3: Read it in `apply_loot`**

In `apply_loot`, replace:

```gdscript
	talent_payload = TalentEngine.resolve_payload(WeaponInstance.active_talents(inst))
	_ammo = mag_size   # start the run with a full (boosted) magazine
```

with:

```gdscript
	talent_payload = TalentEngine.resolve_payload(WeaponInstance.active_talents(inst))
	_reload_nova = talent_payload.get("reload_nova", {})
	_ammo = mag_size   # start the run with a full (boosted) magazine
```

- [ ] **Step 4: Fire the nova when a reload finishes**

In `_process`, replace the reload-complete block (~lines 119-122):

```gdscript
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
		return
```

with:

```gdscript
		if _reload_timer <= 0.0:
			_ammo = mag_size
			_reloading = false
			if not _reload_nova.is_empty():
				TalentEngine.detonate(global_position, float(_reload_nova["dmg"]), float(_reload_nova["radius"]), get_tree())
		return
```

- [ ] **Step 5: Compile gate** — Expected: no output. (Nova is dormant until Task 9 populates `reload_nova`.)

- [ ] **Step 6: Commit**

```bash
git add scripts/loot/TalentEngine.gd scripts/Gun.gd
git commit -m "Gun/TalentEngine: reload nova (Backblast) + public detonate helper"
```

---

## Task 8: Gun + Bullet — overpenetration (Railbreaker)

**Files:**
- Modify: `scripts/Gun.gd`
- Modify: `scripts/Bullet.gd`

- [ ] **Step 1: Gun stores the resolved overpen**

In `scripts/Gun.gd`, after `var _reload_nova := {}` (Task 7) add:

```gdscript
	var _overpen := {}                 # Railbreaker: {pierce, growth} from talent_payload; {} = none
```

- [ ] **Step 2: Read it in `apply_loot`**

In `apply_loot`, replace the line added in Task 7:

```gdscript
	_reload_nova = talent_payload.get("reload_nova", {})
```

with:

```gdscript
	_reload_nova = talent_payload.get("reload_nova", {})
	_overpen = talent_payload.get("overpen", {})
```

- [ ] **Step 3: Apply overpen in `_spawn_bullet`**

Replace the line (set in Task 6):

```gdscript
	bullet.pierce_count = pierce_count + (_surge_pierce if _surge_time > 0.0 else 0)
```

with:

```gdscript
	bullet.pierce_count = pierce_count + (_surge_pierce if _surge_time > 0.0 else 0) + int(_overpen.get("pierce", 0))
	bullet.overpen_growth = float(_overpen.get("growth", 0.0))
```

- [ ] **Step 4: Bullet field**

In `scripts/Bullet.gd`, after `var ricochet_count := 0` (~line 13) add:

```gdscript
var overpen_growth := 0.0      # Railbreaker: % damage gained each time the bullet pierces
```

- [ ] **Step 5: Grow damage on pierce**

In `_on_body_entered`, replace the pierce branch (~lines 73-75):

```gdscript
	if pierce_count > 0:
		pierce_count -= 1
		return
```

with:

```gdscript
	if pierce_count > 0:
		pierce_count -= 1
		if overpen_growth > 0.0:
			damage *= (1.0 + overpen_growth / 100.0)
		return
```

- [ ] **Step 6: Compile gate** — Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add scripts/Gun.gd scripts/Bullet.gd
git commit -m "Gun/Bullet: overpenetration (Railbreaker) bonus pierce + per-pierce damage growth"
```

---

## Task 9: TalentEngine — wire the 5 new behaviors

**Files:**
- Modify: `scripts/loot/TalentEngine.gd`

This connects the talent defs (Task 3) to the hooks (Tasks 4-8).

- [ ] **Step 1: Add resolve arms**

In `resolve_payload`, inside the `match String(def["kind"]):` block, after the `"onhit_execute":` arm (~line 38) add:

```gdscript
			"onhit_vulnerable":
				payload["procs"].append({ "kind": "vulnerable", "chance": v.call(0), "amount": v.call(1), "dur": v.call(2) })
			"onhit_freeze":
				payload["procs"].append({ "kind": "freeze", "chance": v.call(0), "dur": v.call(1), "shatter": v.call(2), "radius": v.call(3) })
			"onkill_surge":
				payload["procs"].append({ "kind": "surge", "pierce": int(round(v.call(0))), "shots": int(round(v.call(1))), "dur": v.call(2) })
			"onreload_nova":
				payload["reload_nova"] = { "dmg": v.call(0), "radius": v.call(1) }
			"overpen":
				payload["overpen"] = { "pierce": int(round(v.call(0))), "growth": v.call(1) }
```

- [ ] **Step 2: Add process arms**

In `process_hit`, inside the `match String(proc["kind"]):` block, after the `"execute":` arm (~line 82) add:

```gdscript
				"vulnerable":
					if alive and _roll(proc["chance"]) and body.has_method("apply_vulnerable"):
						body.apply_vulnerable(float(proc["amount"]) / 100.0, float(proc["dur"]))
				"freeze":
					if alive and body.has_method("apply_freeze"):
						if body.has_method("is_frozen") and body.is_frozen():
							detonate(hit_pos, float(proc["shatter"]), float(proc["radius"]), ctx.get("tree"))
						elif _roll(proc["chance"]):
							body.apply_freeze(float(proc["dur"]))
				"surge":
					if killed and ctx.get("gun") != null and is_instance_valid(ctx["gun"]):
						ctx["gun"].add_surge(int(proc["pierce"]), int(proc["shots"]), float(proc["dur"]))
```

Note: `reload_nova`/`overpen` have **no** `process_hit` arm — the Gun reads those payload fields directly (Tasks 7-8).

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/loot/TalentEngine.gd
git commit -m "TalentEngine: wire vulnerable/freeze/surge procs + reload_nova/overpen fields"
```

---

## Task 10: Affixes.gd — themed archetypes + legacy flag

**Files:**
- Modify: `scripts/loot/Affixes.gd`

- [ ] **Step 1: Replace `all()` with the legacy-flagged + themed catalog**

Replace the entire `static func all() -> Array:` body (the `return [ ... ]`, ~lines 22-71) with:

```gdscript
static func all() -> Array:
	return [
		# --- Legacy affixes (kept for save compatibility; excluded from the roll pool) ---
		{
			"id": "rusted", "name": "Rusted", "rarity": 1, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 0, "legacy": true,
			"stats": { "damage": [4, 12], "reload": [3, 10] },
		},
		{
			"id": "salvaged", "name": "Salvaged", "rarity": 2, "min_stats": 2, "max_stats": 3,
			"min_talents": 0, "max_talents": 1, "legacy": true,
			"stats": { "damage": [10, 22], "fire_rate": [6, 14], "range": [8, 18] },
		},
		{
			"id": "hardened", "name": "Hardened", "rarity": 3, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 1, "legacy": true,
			"stats": { "damage": [18, 36], "fire_rate": [10, 20], "range": [14, 26], "mag": [12, 28] },
		},
		{
			"id": "lethal", "name": "Lethal", "rarity": 4, "min_stats": 3, "max_stats": 4,
			"min_talents": 1, "max_talents": 2, "legacy": true,
			"stats": {
				"damage": [30, 55], "fire_rate": [16, 28], "range": [20, 36],
				"mag": [18, 36], "reload": [12, 28], "multishot": [1, 1], "pierce": [1, 1],
			},
		},
		{
			"id": "savage", "name": "Savage", "rarity": 5, "min_stats": 4, "max_stats": 5,
			"min_talents": 2, "max_talents": 2, "legacy": true,
			"stats": {
				"damage": [45, 80], "fire_rate": [22, 36], "bullet_speed": [15, 40],
				"range": [28, 48], "mag": [25, 50], "reload": [18, 36], "multishot": [1, 2], "pierce": [1, 2],
			},
		},
		{
			"id": "merciless", "name": "Merciless", "rarity": 6, "min_stats": 4, "max_stats": 6,
			"min_talents": 2, "max_talents": 3, "legacy": true,
			"stats": {
				"damage": [60, 105], "fire_rate": [28, 44], "range": [36, 60], "bullet_speed": [25, 55],
				"mag": [35, 70], "reload": [25, 45], "multishot": [2, 3], "pierce": [1, 3], "ricochet": [1, 1],
			},
		},
		{
			"id": "carnage", "name": "Carnage", "rarity": 7, "min_stats": 5, "max_stats": 7,
			"min_talents": 3, "max_talents": 3, "legacy": true,
			"stats": {
				"damage": [80, 140], "fire_rate": [35, 55], "range": [45, 75], "bullet_speed": [40, 80],
				"mag": [50, 100], "reload": [35, 60], "multishot": [2, 4], "pierce": [2, 4], "ricochet": [1, 2],
			},
		},

		# --- Rarity 1 (talents 0/0, stats 1/2) ---
		{ "id": "r1_razor", "name": "Razor", "rarity": 1, "min_stats": 1, "max_stats": 1,
			"min_talents": 0, "max_talents": 0, "stats": { "damage": [6, 14] } },
		{ "id": "r1_rapid", "name": "Rapid", "rarity": 1, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 0, "stats": { "fire_rate": [6, 14], "reload": [3, 10] } },

		# --- Rarity 2 (talents 0/1, stats 2/3) ---
		{ "id": "r2_razor", "name": "Razor", "rarity": 2, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 1, "stats": { "damage": [12, 24], "range": [8, 18] } },
		{ "id": "r2_rapid", "name": "Rapid", "rarity": 2, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 1, "stats": { "fire_rate": [8, 16], "reload": [6, 14] } },
		{ "id": "r2_longshot", "name": "Longshot", "rarity": 2, "min_stats": 1, "max_stats": 2,
			"min_talents": 0, "max_talents": 1, "stats": { "range": [12, 24], "bullet_speed": [10, 28] } },

		# --- Rarity 3 (talents 1/1, stats 2/3) ---
		{ "id": "r3_razor", "name": "Razor", "rarity": 3, "min_stats": 2, "max_stats": 2,
			"min_talents": 1, "max_talents": 1, "stats": { "damage": [20, 40], "range": [14, 26] } },
		{ "id": "r3_rapid", "name": "Rapid", "rarity": 3, "min_stats": 2, "max_stats": 2,
			"min_talents": 1, "max_talents": 1, "stats": { "fire_rate": [12, 22], "reload": [10, 22] } },
		{ "id": "r3_heavy", "name": "Heavy", "rarity": 3, "min_stats": 2, "max_stats": 2,
			"min_talents": 1, "max_talents": 1, "stats": { "mag": [14, 30], "damage": [14, 28] } },

		# --- Rarity 4 (talents 1/2, stats 3/4) ---
		{ "id": "r4_razor", "name": "Razor", "rarity": 4, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 2, "stats": { "damage": [32, 58], "range": [20, 36], "fire_rate": [12, 22] } },
		{ "id": "r4_heavy", "name": "Heavy", "rarity": 4, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 2, "stats": { "mag": [20, 40], "multishot": [1, 1], "damage": [24, 44] } },
		{ "id": "r4_hollow", "name": "Hollow", "rarity": 4, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 2, "stats": { "pierce": [1, 1], "multishot": [1, 1], "damage": [20, 40] } },
		{ "id": "r4_longshot", "name": "Longshot", "rarity": 4, "min_stats": 2, "max_stats": 3,
			"min_talents": 1, "max_talents": 2, "stats": { "range": [24, 42], "bullet_speed": [18, 40], "damage": [20, 40] } },

		# --- Rarity 5 (talents 2/2, stats 4/5) ---
		{ "id": "r5_razor", "name": "Razor", "rarity": 5, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 2, "stats": { "damage": [48, 84], "fire_rate": [18, 30], "range": [28, 48], "bullet_speed": [15, 40] } },
		{ "id": "r5_heavy", "name": "Heavy", "rarity": 5, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 2, "stats": { "mag": [28, 55], "multishot": [1, 2], "damage": [36, 64], "reload": [15, 30] } },
		{ "id": "r5_hollow", "name": "Hollow", "rarity": 5, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 2, "stats": { "pierce": [1, 2], "multishot": [1, 2], "damage": [32, 60], "range": [24, 44] } },
		{ "id": "r5_brutal", "name": "Brutal", "rarity": 5, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 2, "stats": { "damage": [40, 72], "multishot": [1, 2], "pierce": [1, 2], "fire_rate": [18, 30] } },

		# --- Rarity 6 (talents 2/3, stats 4/6) ---
		{ "id": "r6_razor", "name": "Razor", "rarity": 6, "min_stats": 3, "max_stats": 5,
			"min_talents": 2, "max_talents": 3, "stats": { "damage": [64, 110], "fire_rate": [28, 44], "range": [36, 60], "bullet_speed": [25, 55], "reload": [25, 45] } },
		{ "id": "r6_heavy", "name": "Heavy", "rarity": 6, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 3, "stats": { "mag": [38, 75], "multishot": [2, 3], "damage": [48, 88], "reload": [25, 45] } },
		{ "id": "r6_hollow", "name": "Hollow", "rarity": 6, "min_stats": 3, "max_stats": 4,
			"min_talents": 2, "max_talents": 3, "stats": { "pierce": [1, 3], "multishot": [2, 3], "damage": [44, 84], "ricochet": [1, 1] } },
		{ "id": "r6_brutal", "name": "Brutal", "rarity": 6, "min_stats": 4, "max_stats": 5,
			"min_talents": 2, "max_talents": 3, "stats": { "damage": [56, 100], "multishot": [2, 3], "pierce": [1, 3], "ricochet": [1, 1], "fire_rate": [28, 44] } },

		# --- Rarity 7 (talents 3/3, stats 5/7) ---
		{ "id": "r7_razor", "name": "Razor", "rarity": 7, "min_stats": 4, "max_stats": 6,
			"min_talents": 3, "max_talents": 3, "stats": { "damage": [85, 145], "fire_rate": [35, 55], "range": [45, 75], "bullet_speed": [40, 80], "reload": [35, 60], "mag": [40, 80] } },
		{ "id": "r7_heavy", "name": "Heavy", "rarity": 7, "min_stats": 4, "max_stats": 5,
			"min_talents": 3, "max_talents": 3, "stats": { "mag": [55, 105], "multishot": [2, 4], "damage": [70, 120], "reload": [35, 60], "pierce": [2, 4] } },
		{ "id": "r7_hollow", "name": "Hollow", "rarity": 7, "min_stats": 4, "max_stats": 5,
			"min_talents": 3, "max_talents": 3, "stats": { "pierce": [2, 4], "multishot": [2, 4], "damage": [64, 116], "ricochet": [1, 2], "range": [45, 75] } },
		{ "id": "r7_brutal", "name": "Brutal", "rarity": 7, "min_stats": 5, "max_stats": 6,
			"min_talents": 3, "max_talents": 3, "stats": { "damage": [80, 140], "multishot": [2, 4], "pierce": [2, 4], "ricochet": [1, 2], "fire_rate": [35, 55], "bullet_speed": [40, 80] } },
	]
```

- [ ] **Step 2: Add the rollable-pool accessor**

After `of_rarity` (~line 85) add:

```gdscript
## Affixes of a rarity that the loot roller may pick (themed only — legacy excluded).
static func rollable_of_rarity(rarity: int) -> Array:
	var out: Array = []
	for a in all():
		if a["rarity"] == rarity and not a.get("legacy", false):
			out.append(a)
	return out
```

- [ ] **Step 3: Compile gate** — Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add scripts/loot/Affixes.gd
git commit -m "Affixes: 24 themed archetypes; flag legacy; add rollable_of_rarity"
```

---

## Task 11: LootRoller — roll from the themed pool

**Files:**
- Modify: `scripts/loot/LootRoller.gd`

- [ ] **Step 1: Use `rollable_of_rarity`**

In `roll`, replace (~lines 11-13):

```gdscript
	var affixes := Affixes.of_rarity(rarity)
	if affixes.is_empty():
		affixes = Affixes.of_rarity(1)
```

with:

```gdscript
	var affixes := Affixes.rollable_of_rarity(rarity)
	if affixes.is_empty():
		affixes = Affixes.rollable_of_rarity(1)
```

- [ ] **Step 2: Compile gate** — Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add scripts/loot/LootRoller.gd
git commit -m "LootRoller: roll affixes from the themed (non-legacy) pool"
```

---

## Task 12: WeaponInstance — roll-quality data

**Files:**
- Modify: `scripts/loot/WeaponInstance.gd`

- [ ] **Step 1: Add the quality-label helper**

After `rarity_name` (~line 19) add:

```gdscript
## Roll-quality label for a 0..1 roll (the god-roll readout).
static func quality_label(roll: float) -> String:
	if roll >= 1.0: return "PERFECT"
	if roll >= 0.95: return "NEAR MAX"
	if roll >= 0.75: return "HIGH"
	if roll >= 0.5: return "GOOD"
	if roll >= 0.25: return "FAIR"
	return "LOW"
```

- [ ] **Step 2: Add a per-stat roll-info helper**

After `_flat_bonus` (~line 174) add:

```gdscript
# Roll-quality info for a stat row: {} if the stat wasn't rolled, else {roll, lo, hi, fixed}.
# lo/hi are the affix bonus endpoints as display strings ("+12%" / "+2").
static func _stat_quality(inst: Dictionary, affix: Dictionary, stat_id: String, is_pct: bool) -> Dictionary:
	if not inst.get("stats", {}).has(stat_id):
		return {}
	var roll := float(inst["stats"][stat_id])
	var rng: Array = affix.get("stats", {}).get(stat_id, [0, 0])
	var lo: float = rng[0]
	var hi: float = rng[1]
	var lo_s: String = ("+%d%%" % roundi(lo)) if is_pct else ("+%d" % int(lo))
	var hi_s: String = ("+%d%%" % roundi(hi)) if is_pct else ("+%d" % int(hi))
	return { "roll": roll, "lo": lo_s, "hi": hi_s, "fixed": (lo == hi) }
```

- [ ] **Step 3: Merge roll-info into `full_stats` rows**

`full_stats` builds each row as `rows.append({ "label":..., "value":..., "bonus":... })`. Wrap each `rows.append({...})` so it also merges `_stat_quality`. Replace the rows block (~lines 119-134) with:

```gdscript
	var affix := Affixes.get_affix(String(inst.get("affix", "")))
	var rows: Array = []
	rows.append(_merge({ "label": "DAMAGE", "value": str(roundi(damage)), "bonus": _pct_bonus(s, "damage") }, _stat_quality(inst, affix, "damage", true)))
	rows.append(_merge({ "label": "FIRE RATE", "value": "%.1f/s" % rate, "bonus": _pct_bonus(s, "fire_rate") }, _stat_quality(inst, affix, "fire_rate", true)))
	rows.append(_merge({ "label": "RANGE", "value": str(roundi(rng)), "bonus": _pct_bonus(s, "range") }, _stat_quality(inst, affix, "range", true)))
	rows.append(_merge({ "label": "RELOAD", "value": "%.1fs" % reload, "bonus": _pct_bonus(s, "reload") }, _stat_quality(inst, affix, "reload", true)))
	rows.append(_merge({ "label": "MAGAZINE", "value": str(mag), "bonus": _pct_bonus(s, "mag") }, _stat_quality(inst, affix, "mag", true)))
	# Conditional rows: shown only when relevant, so the block stays clean but never hides a
	# rolled bonus (bullet_speed/multishot/pierce/ricochet only roll on higher rarities).
	if s.has("bullet_speed"):
		rows.append(_merge({ "label": "BULLET SPD", "value": str(roundi(bspeed)), "bonus": _pct_bonus(s, "bullet_speed") }, _stat_quality(inst, affix, "bullet_speed", true)))
	if shots > 1:
		rows.append(_merge({ "label": "MULTISHOT", "value": str(shots), "bonus": _flat_bonus(s, "multishot") }, _stat_quality(inst, affix, "multishot", false)))
	if pierce > 0:
		rows.append(_merge({ "label": "PIERCE", "value": str(pierce), "bonus": _flat_bonus(s, "pierce") }, _stat_quality(inst, affix, "pierce", false)))
	if ricochet > 0:
		rows.append(_merge({ "label": "RICOCHET", "value": str(ricochet), "bonus": _flat_bonus(s, "ricochet") }, _stat_quality(inst, affix, "ricochet", false)))
	return rows
```

Then add the `_merge` helper after `_stat_quality`:

```gdscript
# Shallow-merge the quality keys into a row dict (no-op if quality is {} — base/unrolled stat).
static func _merge(row: Dictionary, quality: Dictionary) -> Dictionary:
	for k in quality:
		row[k] = quality[k]
	return row
```

- [ ] **Step 4: Add quality to `talent_details`**

In `talent_details`, replace the `out.append({...})` block (~lines 149-155) with:

```gdscript
		var rolls: Array = t.get("rolls", [])
		var q := 0.0
		if rolls.size() > 0:
			for r in rolls:
				q += float(r)
			q /= rolls.size()
		out.append({
			"name": String(def["name"]),
			"color": def.get("color", Color.WHITE),
			"effect": _talent_effect(def, rolls),
			"locked": unlock > lvl,
			"unlock_level": unlock,
			"quality": q,
			"quality_label": quality_label(q),
		})
```

(The existing line `"effect": _talent_effect(def, t.get("rolls", []))` becomes `_talent_effect(def, rolls)` — same value, reusing the local.)

- [ ] **Step 5: Compile gate** — Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add scripts/loot/WeaponInstance.gd
git commit -m "WeaponInstance: roll-quality info on stat rows + talents + quality_label"
```

---

## Task 13: WeaponDetailPopup — quality bars

**Files:**
- Modify: `scripts/ui/WeaponDetailPopup.gd`

- [ ] **Step 1: Add a mini-bar helper**

After `_divider` (~line 191) add:

```gdscript
## A thin quality bar styled like the XP bar (C4 fill on a C1 track, C2 border).
func _mini_bar(frac: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PixelTheme.DARK
	bg.border_color = PixelTheme.ACCENT_DIM
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(0)
	bg.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = PixelTheme.ACCENT
	fill.set_corner_radius_all(0)
	fill.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## The lo · bar · hi · flag line shown under a rolled stat. Caller only adds it when row.has("roll").
func _stat_quality_line(row: Dictionary) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if bool(row.get("fixed", false)):
		var maxed := Label.new()
		maxed.text = "MAX"
		PixelTheme.style_label(maxed, 14, PixelTheme.SELECT)
		hb.add_child(maxed)
		var fbar := _mini_bar(1.0)
		fbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(fbar)
		return hb
	var q := float(row.roll)
	var lo := Label.new()
	lo.text = String(row.lo)
	PixelTheme.style_label(lo, 14, PixelTheme.TEXT_DIM)
	hb.add_child(lo)
	var bar := _mini_bar(q)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(bar)
	var hi := Label.new()
	hi.text = String(row.hi)
	PixelTheme.style_label(hi, 14, PixelTheme.TEXT_DIM)
	hb.add_child(hi)
	var flag := Label.new()
	flag.text = ("★ " + WeaponInstance.quality_label(q)) if q >= 0.95 else WeaponInstance.quality_label(q)
	PixelTheme.style_label(flag, 14, PixelTheme.ACCENT if q >= 0.75 else PixelTheme.TEXT_DIM)
	hb.add_child(flag)
	return hb
```

- [ ] **Step 2: Rebuild the stats section as per-stat blocks (so a full-width bar can sit under each row)**

Replace the whole `_build_stats_section` (~lines 131-154) with:

```gdscript
func _build_stats_section(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("STATS"))
	for row in WeaponInstance.full_stats(_inst):
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := Label.new()
		name_l.text = String(row.label)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelTheme.style_label(name_l, 18, PixelTheme.TEXT_DIM)
		line.add_child(name_l)
		var val_l := Label.new()
		val_l.text = String(row.value)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelTheme.style_label(val_l, 18, PixelTheme.TEXT)
		line.add_child(val_l)
		if String(row.bonus) != "":
			var bonus_l := Label.new()
			bonus_l.text = String(row.bonus)
			bonus_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			PixelTheme.style_label(bonus_l, 16, PixelTheme.SELECT)
			line.add_child(bonus_l)
		block.add_child(line)
		if row.has("roll"):
			block.add_child(_stat_quality_line(row))
		parent.add_child(block)
```

- [ ] **Step 3: Add the quality bar to each talent**

Replace the per-talent loop body in `_build_talents_section` (~lines 162-177) with:

```gdscript
	for t in talents:
		var locked: bool = bool(t.locked)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Label.new()
		var suffix: String = ("  (LOCKED — LV%d)" % int(t.unlock_level)) if locked else ""
		nm.text = String(t.name).to_upper() + suffix
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelTheme.style_label(nm, 18, PixelTheme.TEXT_DIM if locked else PixelTheme.ACCENT)
		head.add_child(nm)
		var q: float = float(t.get("quality", 0.0))
		var ql := Label.new()
		ql.text = "%s %d%%" % [String(t.get("quality_label", "")), int(round(q * 100.0))]
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelTheme.style_label(ql, 14, PixelTheme.TEXT_DIM if locked else (PixelTheme.ACCENT if q >= 0.75 else PixelTheme.SELECT))
		head.add_child(ql)
		row.add_child(head)
		var qbar := _mini_bar(q)
		qbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(qbar)
		var eff := Label.new()
		eff.text = String(t.effect)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.custom_minimum_size = Vector2(maxf(200.0, _card_w - 80.0), 0)
		PixelTheme.style_label(eff, 16, PixelTheme.TEXT_DIM)
		row.add_child(eff)
		parent.add_child(row)
```

- [ ] **Step 4: Compile gate** — Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/WeaponDetailPopup.gd
git commit -m "WeaponDetailPopup: quality bars under each stat + talent"
```

---

## Task 14: Logic probe

**Files:**
- Create: `probe_talents.gd` (project root — a throwaway, removed in Task 15)

- [ ] **Step 1: Write the probe**

Create `probe_talents.gd`:

```gdscript
extends SceneTree
## Throwaway logic probe for the talents/stats expansion. Run headless:
##   ...console.exe --path "...mobile-game" --headless --editor --script res://probe_talents.gd
## class_name globals (Talents/Affixes/LootRoller/WeaponInstance/TalentEngine/Enemy/Rarity)
## are available in --script mode; autoloads are NOT, so this avoids them.

func _init() -> void:
	var fails := 0

	# 1. Roll 500 instances across all rarities: no crash; known talent ids; non-legacy affixes.
	for i in 500:
		var rarity := (i % 7) + 1
		var inst := LootRoller.roll(rarity)
		var affix := Affixes.get_affix(String(inst["affix"]))
		if affix.get("legacy", false):
			print("PROBE FAIL: rolled a legacy affix %s" % inst["affix"]); fails += 1
		for t in inst["talents"]:
			if Talents.get_talent(String(t["id"])).is_empty():
				print("PROBE FAIL: unknown talent id %s" % t["id"]); fails += 1

	# 2. resolve_payload produces the new procs/fields.
	var actives := [
		{ "id": "marked", "unlock_level": 1, "rolls": [0.5, 0.5, 0.5] },
		{ "id": "coldsnap", "unlock_level": 1, "rolls": [0.5, 0.5, 0.5, 0.5] },
		{ "id": "overflow", "unlock_level": 1, "rolls": [1.0, 1.0, 0.5] },
		{ "id": "backblast", "unlock_level": 1, "rolls": [0.5, 0.5] },
		{ "id": "railbreaker", "unlock_level": 1, "rolls": [0.5, 0.5] },
	]
	var payload := TalentEngine.resolve_payload(actives)
	var kinds := []
	for p in payload["procs"]:
		kinds.append(p["kind"])
	for need in ["vulnerable", "freeze", "surge"]:
		if not kinds.has(need):
			print("PROBE FAIL: payload missing proc %s" % need); fails += 1
	if not payload.has("reload_nova"):
		print("PROBE FAIL: payload missing reload_nova"); fails += 1
	if not payload.has("overpen"):
		print("PROBE FAIL: payload missing overpen"); fails += 1

	# 3. Enemy vulnerability multiplier + freeze flag (no tree / no autoloads touched).
	var e = Enemy.new()
	e.configure({ "max_health": 1000.0, "move_speed": 70.0, "touch_damage": 10.0 })
	e.apply_vulnerable(0.5, 5.0)
	e.take_damage(100.0)   # 100 * 1.5 = 150 -> fraction 0.85 (non-fatal, no RunStats)
	if absf(e.health_fraction() - 0.85) > 0.001:
		print("PROBE FAIL: vuln expected 0.85 got %f" % e.health_fraction()); fails += 1
	if e.is_frozen():
		print("PROBE FAIL: enemy frozen before apply_freeze"); fails += 1
	e.apply_freeze(2.0)
	if not e.is_frozen():
		print("PROBE FAIL: apply_freeze did not set is_frozen"); fails += 1
	e.free()

	# 4. Legacy affix still resolves (no migration regression).
	var legacy := { "base": "ak47", "affix": "hardened", "rarity": 3, "level": 5, "xp": 0,
		"stats": { "damage": 0.5 }, "talents": [] }
	var ls := WeaponInstance.resolved_stats(legacy)
	if not ls.has("damage") or float(ls["damage"]) <= 0.0:
		print("PROBE FAIL: legacy affix damage did not resolve"); fails += 1

	# 5. Roll-quality: stat roll surfaces with lo/hi; talent quality = mean of mod rolls.
	var qinst := { "base": "ak47", "affix": "r3_rapid", "rarity": 3, "level": 1, "xp": 0,
		"stats": { "fire_rate": 0.8 },
		"talents": [ { "id": "napalm", "unlock_level": 1, "rolls": [0.5, 0.5, 1.0] } ] }
	var fr_found := false
	for row in WeaponInstance.full_stats(qinst):
		if String(row.label) == "FIRE RATE" and row.has("roll"):
			fr_found = true
			if absf(float(row.roll) - 0.8) > 0.001:
				print("PROBE FAIL: fire_rate roll expected 0.8 got %f" % row.roll); fails += 1
			if String(row.lo) == "" or String(row.hi) == "":
				print("PROBE FAIL: fire_rate lo/hi missing"); fails += 1
	if not fr_found:
		print("PROBE FAIL: FIRE RATE row missing roll info"); fails += 1
	var td := WeaponInstance.talent_details(qinst)
	if td.is_empty() or absf(float(td[0]["quality"]) - 0.6667) > 0.01:
		print("PROBE FAIL: talent quality expected ~0.667 got %s" % (td[0]["quality"] if not td.is_empty() else "none")); fails += 1

	if fails == 0:
		print("PROBE PASS: all talent/stat checks green")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()
```

- [ ] **Step 2: Run the probe**

```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --path "C:\Users\thela\Documents\mobile-game" --headless --editor --script res://probe_talents.gd 2>&1 \
  | grep -iE "PROBE|error"
```

Expected: `PROBE PASS: all talent/stat checks green` (and no `PROBE FAIL` lines). If any check fails, fix the relevant task's code before continuing.

- [ ] **Step 3: Commit (probe kept temporarily for re-runs)**

```bash
git add probe_talents.gd
git commit -m "Add throwaway logic probe for talents/stats expansion"
```

---

## Task 15: Final gate, cleanup, handoff

**Files:**
- Delete: `probe_talents.gd`

- [ ] **Step 1: Full compile gate one more time** — Expected: no output.

- [ ] **Step 2: Remove the probe**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git rm probe_talents.gd
git commit -m "Remove talents/stats logic probe (verified green)"
```

- [ ] **Step 3: F5 handoff checklist for Larry** (manual, on desktop then phone)

  - Open a few crates → weapons show **themed names** ("Razor AK-47") + the rarity tag (`Hardened · Level N`) in the inspect popup.
  - Inspect popup shows a **quality bar** under each rolled stat (lo · bar · hi · flag) and under each talent (label + bar + %); a max roll shows ★ / "MAX".
  - Level a gun (grind weapon XP) until a new-behavior talent unlocks, then verify in a run:
    - **Marked** — marked enemies visibly die faster (take +dmg).
    - **Cold Snap** — an enemy freezes (stops, indigo tint); a follow-up hit shatters it (AoE).
    - **Overflow** — after a kill, the next shots pierce / extra pellets briefly.
    - **Backblast** — finishing a reload pops an AoE nova around you.
    - **Railbreaker** — shots pierce a line and ramp damage through it.
  - Confirm an **existing/old saved weapon** still loads and displays correctly (legacy affix).

---

## Self-Review

**Spec coverage:**
- §1 talent catalog (10+5+16) → Tasks 2, 3 ✓
- §2 engine wiring (resolve/process arms, Enemy/Gun/Bullet hooks, `detonate`) → Tasks 4-9 ✓
- §3 themed affixes + legacy flag + `rollable_of_rarity` → Tasks 10, 11 ✓
- §4 display (themed name free; rarity tag already in popup) → no code needed (verified in Task 15 checklist) ✓
- §5 roll-quality readout (data + bars + thresholds) → Tasks 12, 13 ✓
- §6 balance (data tables) → covered by the data in Tasks 2/3/10 ✓
- §7 save compat (legacy retained, additive ids) → Task 10 + probe check 4 ✓
- §8 testing (compile gate + probe checks 1-5) → Tasks 1-15 ✓
- §10 `GameConfig` knob → Task 1 ✓

**Placeholder scan:** none — every step has concrete code/commands.

**Type/name consistency:** proc kinds (`vulnerable`/`freeze`/`surge`) match between `resolve_payload` (Task 9 Step 1) and `process_hit` (Task 9 Step 2); payload fields `reload_nova`/`overpen` match between Task 9 producer and Tasks 7/8 consumers; `add_surge(pierce, shots, dur)` signature matches Task 6 def and Task 9 call; `apply_vulnerable(frac, dur)` / `apply_freeze(dur)` / `is_frozen()` match Enemy defs (Tasks 4/5) and engine calls (Task 9); `overpen_growth` matches Bullet field (Task 8 Step 4) and Gun set (Task 8 Step 3); `_merge`/`_stat_quality`/`quality_label` match between WeaponInstance (Task 12) and popup reads (Task 13).

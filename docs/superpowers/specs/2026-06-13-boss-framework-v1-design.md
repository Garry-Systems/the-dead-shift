# Boss Framework v1 — Design Spec

**Date:** 2026-06-13
**Branch:** `feat/boss-framework` (off `master`)
**Companion doc:** `2026-06-13-boss-bible.md` (58 boss concepts this framework is built to host)

## Goal

Build a reusable boss architecture so that adding any of the 58 catalogued bosses (or new ones) means **writing one phase table + maybe one new attack pattern — not a new boss from scratch.** Validate it by porting the existing brute and shipping 2 new showcase bosses that, together, exercise every part of the framework.

### Scope decisions (locked with Larry, 2026-06-13)
- **v1 content:** the framework + port the existing brute (parity proof) + **2 new showcase bosses**.
- **Pattern shelf:** the **full 6 primitives** (ExpandingRing, AimedBand, ZoneFill, ProjectileEmitter, SummonSpawner, DebuffApplier).
- **Boss selection:** **random from the pool** of built bosses (no back-to-back repeat). The wave-band escalation ladder is deliberately deferred — easy to layer on later.

## Non-goals (deferred)
- The wave-escalation ladder (random pool for now).
- Boss name banners / intro UI (the existing bottom-center HP bar stays).
- The heavyweight "Ambitious-tier" systems from the bible (screen shaders, control-rule rewrites, living arenas, contract systems). v1 ships the cheap+medium primitive shelf only.
- New boss art — all 3 v1 bosses reuse `art/enemy.png` with modulate/scale tweaks (placeholder-first, per project ethos).
- Dash-lock and axis-remap debuffs (DebuffApplier v1 does gun-jam + move-slow only; the hooks are designed to extend).

---

## Architecture

The contract a boss must satisfy is duck-typed (verified against the real code): be in the **`boss`** group (HUD polls it) + **`enemies`** group (bullets/auto-aim hit it), and expose `configure(stats)`, `take_damage(amount)`, `ignite(dps, dur)`, `flash_hit()`, `health_fraction()`. `BossBase` provides all of these, so every boss inherits the contract for free.

### 1. `scripts/BossBase.gd` — `class_name BossBase extends CharacterBody2D`
Extracts everything generic out of today's `Boss.gd` and adds the phase/pattern engine. All current brute behavior except the hardcoded slam moves here.

**Carried over from `Boss.gd` (unchanged behavior):**
- `@export var xp_gem_scene: PackedScene` and `@export var relic_pickup_scene: PackedScene` (the `slam_wave_scene` export is **removed** — patterns now come from the phase table).
- `var max_health/move_speed/touch_damage`, `var _health: Health`, `var _target: Player`, burn fields, `_flash_mat`.
- `configure(stats)`, `_setup_flash()`, `flash_hit()`, `_set_flash()`, `health_fraction()`, `ignite()`.
- `take_damage()` → `_die()` → `_reward()` (RunStats.add_boss + XP burst + `_target.full_heal()` + relic drop via `relic_bar.roll_drop`). **Identical to today.**
- Chase movement + contact damage in `_physics_process`, **but** speed is `move_speed * _speed_mult` and contact range stays 60px.

**New — the engine:**
```
var phases: Array = []          # built by subclass _build_phases(); sorted so phases[0].at == 1.0
var _phase_idx := -1
var _speed_mult := 1.0
var _pat_clock := 0.0           # counts down to the next pattern
var _pat_i := 0                 # round-robin index into the current phase's patterns

func _ready():
    add_to_group("enemies"); add_to_group("boss")
    _target = get_tree().get_first_node_in_group("player") as Player
    if _health == null: _health = Health.new(max_health)
    _setup_flash()
    phases = _build_phases()
    _enter_phase(0)

# Subclass overrides this. Returns an Array of phase Dictionaries:
#   { "at": float,            # enter when health_fraction() <= at; first phase MUST be 1.0
#     "patterns": Array,      # entries: { "scene": PackedScene, "params": Dictionary }
#     "cadence": float,       # seconds between pattern casts (default 4.0)
#     "speed_mult": float,    # chase-speed multiplier this phase (default 1.0)
#     "on_enter": Callable }  # optional one-shot when the phase begins
func _build_phases() -> Array: return []

func _enter_phase(i): # set _phase_idx, _speed_mult, reset _pat_i, _pat_clock = small; call on_enter if present

func _physics_process(delta):
    # 1. burn tick (unchanged from today)
    # 2. advance phases: while next phase exists and health_fraction() <= phases[_phase_idx+1].at: _enter_phase(next)
    # 3. chase + contact damage (speed *= _speed_mult)
    # 4. pattern clock: _pat_clock -= delta; if <=0 -> _cast_next_pattern(); _pat_clock = phase.cadence

func _cast_next_pattern():
    var pats = phases[_phase_idx]["patterns"]
    if pats.is_empty(): return
    var entry = pats[_pat_i % pats.size()]; _pat_i += 1
    var p = (entry["scene"] as PackedScene).instantiate()
    get_tree().current_scene.add_child(p)
    p.global_position = global_position
    p.setup(self, _target, entry.get("params", {}))
```
A boss subclass is therefore just: a `.tscn` (Sprite+Collision+exports) + a script overriding `_build_phases()`. **That is the entire cost of a new boss when its patterns already exist.**

### 2. `scripts/patterns/AttackPattern.gd` — `class_name AttackPattern extends Node2D`
The generalized SlamWave lifecycle. Lives in the world (added to `current_scene`), draws its own telegraph, executes, frees itself.
```
var boss: Node2D
var player: Node2D
var params := {}
var _windup := 0.8
var _aim_point := Vector2.ZERO   # player pos snapshotted at telegraph start (dodge = move during windup)
var _fired := false

func setup(b, p, cfg):
    boss = b; player = p; params = cfg
    _windup = clampf(float(cfg.get("windup", 0.8)), 0.5, 1.2)   # readability clamp

func _ready():
    if player == null: player = get_tree().get_first_node_in_group("player")
    _aim_point = player.global_position if (player and is_instance_valid(player)) else global_position

func _process(delta):
    if _windup > 0.0:
        _windup -= delta; queue_redraw()
        if _windup <= 0.0: _fired = true; _on_telegraph_end()
        return
    _active(delta); queue_redraw()

func _on_telegraph_end(): pass    # one-shot when the warning ends (spawn hit / emit / apply)
func _active(delta): pass         # per-frame after windup; subclass frees itself when done
func _draw(): pass                # telegraph (during windup) + active visuals
```
**Readability rules (apply to every pattern):** windup clamped 0.5–1.2s; telegraphs are high-contrast filled/outlined shapes; the damaging area is always pre-shown by the telegraph.

### 3. The pattern shelf (`scripts/patterns/*.gd`, each `extends AttackPattern`, each a trivial `.tscn`)
Each `.tscn` is a bare `Node2D` + script (like today's `SlamWave.tscn`); any child nodes are built in code (matching the codebase style — `Enemy` builds its health bar in code, `Gun` builds its muzzle in code). **Hit detection uses distance checks, not Area2D/collision layers** (matching `SlamWave`/`Enemy`/`Boss`), so no collision-layer wiring is needed.

1. **`ExpandingRing.gd`** — the refactor of `SlamWave.gd`. Telegraph = faint filled circle at full radius; then a drawn ring expands 0→radius; one-shot leading-band hit on the player. Params: `radius`, `expand_time`, `damage`, `windup` (defaults = the `SLAM_*` consts so the ported brute is pixel-identical).
2. **`AimedBand.gd`** — a snapped laser/charge. Telegraph = a high-contrast line/thin rectangle from the boss through `_aim_point` (drawn during windup). On telegraph end, the band becomes damaging for `active_time` (~0.15s); player hit once if within `thickness` of the line segment. Dodge = step off the line during windup. Params: `length`, `thickness`, `damage`, `active_time`, `windup`.
3. **`ZoneFill.gd`** — acid/fire puddle. Telegraph = filled circle (or rect) at a target point (boss pos, `_aim_point`, or a `params.offset`). On telegraph end it becomes a damaging zone for `duration`; ticks `dps` to the player while inside (reuses the per-second distance-damage pattern from `Enemy`). Params: `radius`, `dps`, `duration`, `windup`, `at` (`"boss"`|`"player"`).
4. **`ProjectileEmitter.gd`** — spawns `BossProjectile` hazards. Telegraph = brief flash/charge glyph on the boss. On telegraph end, emits `count` projectiles in a `pattern` shape: `"fan"` (arc centered on `_aim_point`), `"ring"` (full TAU), `"spiral"` (emitted over `active` time with rotating angle), `"aimed"` (single shot at `_aim_point`). Params: `count`, `pattern`, `arc`, `speed`, `damage`, `spin`, `windup`.
5. **`SummonSpawner.gd`** — instances `Enemy` adds via `const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")` (the pattern preloads it directly — no registry/export needed, no `Enemy` change). Telegraph = N faint circles where adds will appear (reuses the SlamWave faint-circle look). On telegraph end, spawns `count` enemies configured with `DifficultyManager.enemy_stats()` (optionally scaled by `params.hp_mult`). If `decoy: true`, the add is spawned **very close to the player** so the player's nearest-target auto-aim locks onto it (the auto-aim-steal mechanic). Params: `count`, `decoy`, `hp_mult`, `windup`.
6. **`DebuffApplier.gd`** — attacks the control scheme. The pattern repositions to the player's location every frame so its visuals follow the player. Telegraph = a colored ring drawn around the player during windup. On telegraph end, calls a new Player hook for `duration`s: `"jam"` → `player.apply_fire_lock(duration)` (gun can't fire even while still); `"slow"` → `player.apply_slow(factor, duration)`. During the active `duration` it keeps drawing a pulsing aura around the player (red = jam, blue = slow) so the debuff is always visible, then frees. Params: `kind` (`"jam"`|`"slow"`), `duration`, `factor` (for slow), `windup`.

### 4. `scripts/BossProjectile.gd` + `scenes/BossProjectile.tscn`
A small enemy-side hazard (your existing `Bullet` only hits the `enemies` group, so bosses need their own). `Node2D` + script: travels `direction * speed`, lives `lifetime`s, distance-checks the player each frame, deals `damage` **once** on hit then frees, frees on lifetime/offscreen. Placeholder visual = a small drawn circle or `art/muzzle.png` tinted. Does **not** join `enemies` (it's not shootable). Set up by `ProjectileEmitter`.

### 5. `scripts/logic/Patterns.gd` — `class_name Patterns`
A registry that `preload()`s each pattern `.tscn` by path and exposes them as constants, so phase tables reference `Patterns.RING`, `Patterns.BAND`, `Patterns.ZONE`, `Patterns.EMITTER`, `Patterns.SUMMON`, `Patterns.DEBUFF` without per-boss `@export` wiring. (Mirrors `Weapons.gd`/`Relics.gd` data-registry style.)

### 6. `scripts/logic/Bosses.gd` — `class_name Bosses` + `Spawner.gd` change
- `Bosses.gd` `preload()`s the built boss `.tscn`s into an array and exposes `pick(last_id: String) -> PackedScene` (uniform random, excluding the scene whose `boss_id` == `last_id` when more than one exists) and `count()`.
- `Spawner.gd`: **remove** the `@export var boss_scene` entirely — boss selection is now 100% via `Bosses.gd`. Add `var _last_boss_id := ""`. `_spawn_boss(stats)` does `var entry := Bosses.pick(_last_boss_id)` (returns `{scene, id}`), instantiates the scene, `configure(stats)`, then `_last_boss_id = entry.id`. Boss-rush mode uses `Bosses.pick` too. Keep `enemy_scene` untouched.
- `Bosses.gd` keeps a parallel array of `{id, scene}` (id matches each boss's `const BOSS_ID`) so the picker never has to instance a node just to read an id. `pick(last_id)` returns a uniform-random entry, excluding `last_id` when `count() > 1`.
- **Main.tscn (surgical):** remove exactly two lines from the file — `boss_scene = ExtResource("7_boss")` under the `Spawner` node, and the now-orphaned `[ext_resource type="PackedScene" path="res://scenes/Boss.tscn" id="7_boss"]`. Leave everything else byte-identical (Ground, Player, `enemy_scene`, every CanvasLayer).

---

## The 3 v1 bosses

### A. Brute — `scripts/bosses/Brute.gd extends BossBase` (the port / parity proof)
- `const BOSS_ID := "brute"`. Stats via `configure` (unchanged `DifficultyCurve.boss_stats`).
- `_build_phases()` → one phase:
  `[{ "at":1.0, "cadence":SLAM_INTERVAL, "patterns":[{ "scene":Patterns.RING, "params":{"radius":SLAM_RADIUS,"expand_time":SLAM_EXPAND_TIME,"damage":SLAM_DAMAGE,"windup":SLAM_WINDUP} }] }]`
- **Scene:** create `scenes/bosses/Brute.tscn` (content copied from `scenes/Boss.tscn`): CharacterBody2D + Sprite2D(enemy.png, red modulate, scale 2.5) + CircleShape2D(48); script → `Brute.gd`; keep the `xp_gem_scene`/`relic_pickup_scene` exports; drop the `slam_wave_scene` export + its ext_resource. `Bosses.gd` preloads it. Then delete `scenes/Boss.tscn` (Main.tscn no longer references it — see §6).
- **Acceptance:** plays identically to the current Phase-4 boss (slow chase, 4s telegraphed slam, same reward).

### B. The Brood Mother — `scripts/bosses/BroodMother.gd` (exercises SummonSpawner + ZoneFill + ProjectileEmitter, multi-phase)
- `const BOSS_ID := "brood_mother"`. Bigger HP, slow. Placeholder: enemy.png, green-purple modulate, scale 3.0.
- Phases:
  - **100%** cadence 4.0: `[SUMMON(count:3), ZONE(radius:90,dps:18,duration:4)]` — spawns adds + acid nests.
  - **≤66%** cadence 3.2, speed_mult 1.0: `[SUMMON(count:3,decoy:true), ZONE(...), EMITTER(count:8,pattern:"ring",speed:180)]` — decoy adds steal auto-aim; adds a radial spit.
  - **≤33%** cadence 2.6: `[SUMMON(count:4,decoy:true), EMITTER(count:10,pattern:"ring"), ZONE(...)]` — frantic.
- **Combat-model exploit:** decoy adds hijack nearest-target auto-aim so the player's fire wanders off the boss; acid zones deny standing-still firing spots.
- New consts in GameConfig for its summon counts / zone dps / HP (see Config section).

### C. OVERCLOX, the Heat Tyrant — `scripts/bosses/HeatTyrant.gd` (exercises DebuffApplier + AimedBand + ExpandingRing, multi-phase)
- `const BOSS_ID := "heat_tyrant"`. Medium-high HP, slow. Placeholder: enemy.png, orange modulate, scale 2.5.
- Phases:
  - **100%** cadence 3.5: `[RING(meltdown pulse), BAND(solar flare)]`.
  - **≤66%** cadence 3.0: `[RING, BAND, BAND]` — more aimed beams.
  - **≤33%** cadence 2.6: `[DEBUFF(kind:"jam",duration:2.0) "Forced Vent", RING, BAND]` — periodically jams the gun, forcing a pure-movement window.
- **Combat-model exploit:** the gun-jam removes the player's auto-fire for a window, so they must dash/kite blind of DPS — directly attacking the "stand still and let the gun work" default. (This is the cheap, timed-debuff version of the bible's full heat-meter boss; the meter version is a later upgrade.)

---

## Player hooks (new, small — for DebuffApplier)
Add to `Player.gd`, mirroring how `Enemy` manages its slow timer:
```
var _fire_lock_time := 0.0
var _ext_slow_factor := 1.0
var _ext_slow_time := 0.0

func apply_fire_lock(duration): _fire_lock_time = maxf(_fire_lock_time, duration)
func apply_slow(factor, duration):
    _ext_slow_factor = minf(_ext_slow_factor, clampf(1.0 - factor, 0.1, 1.0))
    _ext_slow_time = maxf(_ext_slow_time, duration)
```
In `_physics_process`: decay both timers (clear factor to 1.0 when `_ext_slow_time` hits 0); apply `_ext_slow_factor` to `speed`; set `gun.hold_fire = (SHOOT_ONLY_WHILE_STILL and velocity != ZERO) or _fire_lock_time > 0.0`. **Must not regress** the existing shoot-only-while-still behavior when no debuff is active.

---

## Config additions (`scripts/logic/GameConfig.gd`)
New `# --- Boss framework v1 ---` block. Defaults so every value is tunable in one place (project rule):
- Pattern defaults: `PATTERN_WINDUP_MIN/MAX` (0.5/1.2), `AIMED_BAND_THICKNESS`, `AIMED_BAND_ACTIVE`, `BOSS_PROJECTILE_SPEED`, `BOSS_PROJECTILE_DAMAGE`, `BOSS_PROJECTILE_LIFETIME`, `ZONE_DEFAULT_DPS`, `ZONE_DEFAULT_DURATION`, `DEBUFF_JAM_DURATION`, `DEBUFF_SLOW_FACTOR`, `DEBUFF_SLOW_DURATION`.
- Brood Mother: `BROOD_HP`, `BROOD_SUMMON_COUNT`, `BROOD_ZONE_DPS`, etc.
- Heat Tyrant: `HEAT_HP`, `HEAT_BAND_DAMAGE`, `HEAT_JAM_DURATION`, etc.
- Keep existing `SLAM_*` consts (ExpandingRing reads them as the Brute's params).

---

## Files summary

**New scripts:** `BossBase.gd`; `patterns/{AttackPattern,ExpandingRing,AimedBand,ZoneFill,ProjectileEmitter,SummonSpawner,DebuffApplier}.gd`; `BossProjectile.gd`; `logic/Patterns.gd`; `logic/Bosses.gd`; `bosses/{Brute,BroodMother,HeatTyrant}.gd`.
**New scenes:** `scenes/patterns/{ExpandingRing,AimedBand,ZoneFill,ProjectileEmitter,SummonSpawner,DebuffApplier}.tscn`; `scenes/BossProjectile.tscn`; `scenes/bosses/{Brute,BroodMother,HeatTyrant}.tscn`.
**Changed:** `Spawner.gd` (registry picker, remove `boss_scene` export), `Player.gd` (debuff hooks), `GameConfig.gd` (consts), `scenes/Main.tscn` (remove the 2 `boss_scene` lines, surgical). `Enemy.gd`/`Enemy.tscn` are **not** changed — `SummonSpawner` preloads `Enemy.tscn` directly.
**Removed:** `scripts/Boss.gd`, `scripts/SlamWave.gd`, `scenes/SlamWave.tscn`, `scenes/Boss.tscn` (logic migrated; verify nothing else references them before deleting).

---

## Migration safety
- The boss contract is duck-typed; nothing references `class_name Boss` directly (confirmed: Spawner/HUD/Bullet/RelicBar all use the `boss`/`enemies` groups + method names). Refactor is safe.
- Port the Brute **first** and confirm parity before building B/C.
- `scenes/Main.tscn` is delicate (holds the art-pass Ground/Player wiring) — edit it surgically and only where required.

## GDScript gotchas to honor (from project memory)
- `var x := <expr>` errors on Variant exprs — use explicit types when reading from `Dictionary`/`get_nodes_in_group`/base-typed nodes; cast `(n as Node2D)` before `.global_position`.
- `instantiate()` returns `Node` — assign to an untyped `var p =` when setting custom props (`.direction`, `.setup`).
- Give scripts `class_name` + cast refs for custom-method access.
- Dictionary reads: `float(entry["damage"])`, `entry.get("windup", 0.8)`.

## Testing / smoke checklist
**Headless compile gate (catch parse/type errors before F5):**
`/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5` then grep stderr for errors (the `menu_background.jpg` JPEG-decode line is the only expected one). Autoloads don't load in `--script` mode, so use `--quit-after`, not a probe script, for this feature.

**F5 smoke (Larry):** temporarily set `WAVE_DURATION := 6.0` to reach bosses fast.
1. Reach wave 5 → a boss spawns (random of the 3). Confirm bottom-center HP bar, chase, telegraphed attacks, and that bullets/auto-aim hit it.
2. **Brute:** slam telegraph → expanding ring → dash to avoid. Identical to before.
3. **Brood Mother:** summons adds (auto-aim sometimes pulls to a decoy), acid zones deny ground, ring spit at low HP. Phase ramp visible.
4. **Heat Tyrant:** meltdown rings + aimed beams; at <33% the gun JAMS for ~2s (HUD ammo can't fire) forcing a movement window; resumes after.
5. Kill any boss → XP burst + full heal + relic pickup (unchanged reward).
6. Run several boss waves → confirm no immediate repeat of the same boss; no errors in the Godot output.
7. Restore `WAVE_DURATION := 30.0`.

## Out-of-scope follow-ups (natural next specs)
- Wave-band escalation ladder (swap `Bosses.pick` for a wave-aware picker).
- More bosses off the bible (each = a `_build_phases()` + maybe one new pattern).
- DebuffApplier extensions (dash-lock, axis-remap) + the OVERCLOX heat-meter version.
- Boss intro banner UI.

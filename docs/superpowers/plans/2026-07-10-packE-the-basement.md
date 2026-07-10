# Pack E: The Basement (v0.1.63) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A risk/reward mid-run detour: a cellar door occasionally spawns; stand on it to descend into a 60-second walled gauntlet (dense trash + guaranteed elites, shift clock still ticking) for a guaranteed crate.

**Architecture:** Pure `BasementLogic.gd` (roll gate + crate-floor math) + a `Basement.gd` controller node in Main.tscn that owns the whole lifecycle (door spawn on wave edges → descend → gauntlet at a far world offset → reward → return). Surface systems pause via new `suspended` flags on Spawner + ObstacleField. Door is a code-drawn prop (`BasementDoor.gd`).

**Tech Stack:** Godot 4.6 GDScript, game repo `/mnt/c/Users/thela/Documents/mobile-game`.

**Spec:** `docs/superpowers/specs/2026-07-09-roadmap-4-design.md` §Pack E (approved).

## Global Constraints

- Runner env / boot-scene probes / MANDATORY DUAL GATE per task: identical to Packs 0/A —
  `GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`; probe via `timeout 25 "$GODOT" --path "$PROJ" --headless res://_probe.tscn` (NEVER `--script`); gates = editor-quit grep + Main.tscn boot grep, both 0 (log-redirect workaround if the pipe hangs). **Reports MUST contain LITERAL probe output** and both gate numbers. Delete probe files + stray `.uid` sidecars pre-commit; `git add` tracked-file sidecars for NEW scripts. Commit on master; NO push before ship.
- Spec constants (verbatim): roll from wave ≥ 3, chance 25%/wave-edge via `RunConfig.rand_float()` (Daily stays deterministic), max 2 doors/run, ≤1 alive, door despawns after 45s unentered; descend = stand in ring 1.2s; gauntlet 60s at world offset (+24000, +24000), wall ring radius ~800; guaranteed 2-3 elites (elites here roll in ALL allowed modes — deliberate exception, comment it); reward crate rarity floor `mini(2 + wave / 5, <apex floor id>)`; 8s pickup window then auto-ascend; modes: endless, overtime, horde, daily — NOT boss_rush; death inside = normal run end; shift clock keeps ticking (do NOT touch DifficultyManager.run_time).
- All tunables = `GameConfig.BASEMENT_*` consts with `##` comments (values in Task 1).
- Wave tracking is TIME-DERIVED (`DifficultyManager.wave = floor(run_time / WAVE_DURATION) + 1`, no signal) — edge-detect like `NightEvents._prev_wave` (NightEvents.gd:27).
- The dim-ink idiom for secondary text is `PixelTheme.ACCENT.darkened(0.45)` (never raw ACCENT_DIM as font color).

---

### Task 1: `BasementLogic.gd` + config

**Files:**
- Create: `scripts/logic/BasementLogic.gd`
- Modify: `scripts/logic/GameConfig.gd` (new BASEMENT block)

**Interfaces:**
- Produces (consumed verbatim by Tasks 3-4): `BasementLogic.can_roll(wave: int, mode: String, doors_spawned: int, door_alive: bool, in_basement: bool) -> bool` (pure gate: wave ≥ `BASEMENT_MIN_WAVE`, mode in allowed list, doors_spawned < `BASEMENT_MAX_PER_RUN`, not door_alive, not in_basement); `BasementLogic.roll(rand01: float) -> bool` (rand01 < `BASEMENT_DOOR_CHANCE` — caller passes `RunConfig.rand_float()`); `BasementLogic.crate_floor(wave: int) -> int` (`mini(GameConfig.BASEMENT_CRATE_FLOOR_BASE + wave / GameConfig.BASEMENT_CRATE_FLOOR_WAVES, GameConfig.BASEMENT_CRATE_FLOOR_MAX)`); `BasementLogic.ALLOWED_MODES := ["endless", "overtime", "horde", "daily"]`.
  NOTE: "overtime"/"daily" are endless-FLAG modes in this codebase — VERIFY how `RunConfig.mode` represents them (grep `mode ==` in Spawner.gd/Main.gd; memory says OVERTIME and DAILY are endless variants with flags, so `mode` may read "endless" for them). If they're flags not modes, ALLOWED_MODES = ["endless", "horde"] plus no flag-check needed (they inherit endless) and only boss_rush is excluded — implement per what you find, keep the boss_rush exclusion explicit, and report the actual representation.

- [ ] **Step 1: Failing probe** (boot scene):

```gdscript
extends Node
func _ready() -> void:
	var fails := 0
	if BasementLogic.can_roll(2, "endless", 0, false, false):
		fails += 1; print("PROBE FAIL wave gate")
	if not BasementLogic.can_roll(3, "endless", 0, false, false):
		fails += 1; print("PROBE FAIL wave 3 should roll")
	if BasementLogic.can_roll(9, "boss_rush", 0, false, false):
		fails += 1; print("PROBE FAIL boss_rush allowed")
	if BasementLogic.can_roll(9, "endless", 2, false, false):
		fails += 1; print("PROBE FAIL per-run cap")
	if BasementLogic.can_roll(9, "endless", 0, true, false):
		fails += 1; print("PROBE FAIL door-alive gate")
	if BasementLogic.can_roll(9, "endless", 0, false, true):
		fails += 1; print("PROBE FAIL in-basement gate")
	if not BasementLogic.roll(0.1) or BasementLogic.roll(0.9):
		fails += 1; print("PROBE FAIL chance roll at 0.25")
	if BasementLogic.crate_floor(3) != 2 or BasementLogic.crate_floor(10) != 4 or BasementLogic.crate_floor(99) != GameConfig.BASEMENT_CRATE_FLOOR_MAX:
		fails += 1; print("PROBE FAIL crate floor math: %d %d %d" % [BasementLogic.crate_floor(3), BasementLogic.crate_floor(10), BasementLogic.crate_floor(99)])
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	get_tree().quit(fails)
```

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement.** GameConfig block:

```gdscript
# --- THE BASEMENT (roadmap-4 Pack E, v0.1.63) ---
const BASEMENT_MIN_WAVE := 3            # first wave a cellar door can roll
const BASEMENT_DOOR_CHANCE := 0.25      # per wave-edge roll (via RunConfig.rand_float — Daily stays seeded)
const BASEMENT_MAX_PER_RUN := 2         # doors per run
const BASEMENT_DOOR_LIFETIME := 45.0    # seconds an unentered door lingers
const BASEMENT_DESCEND_HOLD := 1.2      # seconds standing in the ring to descend
const BASEMENT_DOOR_MIN_DIST := 500.0   # door placement ring around the player (px)
const BASEMENT_DOOR_MAX_DIST := 900.0
const BASEMENT_OFFSET := Vector2(24000, 24000)  # gauntlet arena world offset
const BASEMENT_RADIUS := 800.0          # walled ring radius
const BASEMENT_DURATION := 60.0         # gauntlet seconds (shift clock keeps ticking — stolen time)
const BASEMENT_SPAWN_INTERVAL := 0.55   # dense trash cadence inside
const BASEMENT_ELITES := 2              # guaranteed elites per gauntlet (+1 past wave 10)
const BASEMENT_CRATE_FLOOR_BASE := 2    # reward crate rarity floor = BASE + wave/WAVES, capped
const BASEMENT_CRATE_FLOOR_WAVES := 5
const BASEMENT_CRATE_FLOOR_MAX := 7     # apex floor (red) — never guarantees the animated tiers
const BASEMENT_PICKUP_WINDOW := 8.0     # seconds to grab the crate before auto-ascend
```

`scripts/logic/BasementLogic.gd`: class_name BasementLogic, the four statics per the Interfaces block, doc comment `## Pure gate/math for THE BASEMENT (Pack E). Controller = scripts/Basement.gd; keeping the decisions pure keeps them probe-able (Characters.gd lesson).` Implement exactly the expressions the Interfaces block states (with the ALLOWED_MODES resolution you verified).

- [ ] **Step 4: Probe PASS. Step 5: rm probes, gates 0/0, commit:** `feat(basement): BasementLogic gate/roll/crate-floor + config`

---

### Task 2: Surface suspension flags

**Files:**
- Modify: `scripts/Spawner.gd` (`_process` line ~20), `scripts/ObstacleField.gd` (`_process` line ~16)

**Interfaces:**
- Produces: `Spawner.suspended: bool = false` and `ObstacleField.suspended: bool = false` — when true, `_process` returns immediately (no spawns, no scatter, no cull). Task 4's controller flips both.

- [ ] **Step 1: Failing probe:** instantiate `Spawner.new()` and `ObstacleField.new()` off-tree; assert `"suspended" in s` and default false (property-existence probe — behavior is one `if` read in review). Expect FAIL (property missing).
- [ ] **Step 2: Implement:** in each file add near the top vars:

```gdscript
var suspended := false   # THE BASEMENT (Pack E): controller pauses surface spawning/scatter while below
```

and as the FIRST line of `_process`: `if suspended: return` (in Spawner this must sit BEFORE the mode dispatch; in ObstacleField before the player-null check is fine).
- [ ] **Step 3: Probe PASS; gates 0/0; commit:** `feat(basement): suspended flags on Spawner + ObstacleField`

---

### Task 3: Cellar door prop + roll wiring

**Files:**
- Create: `scripts/BasementDoor.gd`
- Create: `scripts/Basement.gd` (controller — door-management half; Task 4 adds the gauntlet half)
- Modify: `scenes/Main.tscn` (add a `Basement` node — mirror how ObstacleField is wired as a sibling: plain Node2D with script)

**Interfaces:**
- Consumes: `BasementLogic.can_roll/roll` (T1), `RunConfig.rand_float()`, `Spawner._pick_spawn_pos`-style ring placement (reimplement locally with `BASEMENT_DOOR_MIN/MAX_DIST` + the forecourt keep-out — grep `FORECOURT_SPAWN_KEEPOUT` for the keep-out idiom and copy it).
- Produces: `BasementDoor` (Node2D, code-drawn): emits `signal descend_requested` after the player stands within its ring for `BASEMENT_DESCEND_HOLD`s continuously; `Basement.doors_spawned: int`, `Basement.in_basement: bool` (false until T4), `Basement._on_wave_edge()` roll logic. Door visual: C2 `#3D0099` hatch rect ~64×48 + C4 handle bar + a pulsing ring (draw_arc, radius 90, alpha oscillating on `_process` time accumulator) + descend progress arc (0→TAU as hold accrues, ACCENT). Standing detection: `player.global_position.distance_to(global_position) <= BASEMENT_DOOR_RING` (add `const BASEMENT_DOOR_RING := 90.0` to the GameConfig block) — accumulate hold time in `_process`, reset when outside, emit once.

- [ ] **Step 1: Failing probe:** door hold-accumulation is pure-ish — expose `static func hold_step(inside: bool, held: float, delta: float) -> float` on BasementDoor (`held + delta` if inside else `0.0`) and probe it (0.0 reset, accumulation, crossing `BASEMENT_DESCEND_HOLD`); plus `Basement` off-tree: `b._on_wave_edge()` with a stubbed rand (make the rand injectable: `_roll_door(rand01: float)` internal taking the value, `_on_wave_edge` passes `RunConfig.rand_float()`) — assert doors_spawned increments only when gate+roll pass. Expect FAIL.
- [ ] **Step 2: Implement** per the Interfaces block. `Basement._process`: edge-detect `DifficultyManager.wave != _prev_wave` (NightEvents idiom, init `_prev_wave` in `_ready`), on edge call `_on_wave_edge()`; that calls `BasementLogic.can_roll(wave, RunConfig.mode, doors_spawned, _door != null and is_instance_valid(_door), in_basement)` then `_roll_door(RunConfig.rand_float())`; success → instantiate BasementDoor at a ring position 500-900px from the player rerolled up to 8 times against the forecourt keep-out (Spawner's idiom), `doors_spawned += 1`, start the 45s despawn timer (door frees itself via its own `_lifetime` countdown; controller detects freed via `is_instance_valid`). Wire `descend_requested` → a `_descend()` stub that just `push_warning("descend: T4")` for now. Main.tscn: add the node (follow the ObstacleField node entry shape — plain node + script ext_resource).
- [ ] **Step 3: Probe PASS; gates 0/0** (boot gate also proves Main.tscn edit parses)**; commit:** `feat(basement): cellar door prop + wave-edge roll wiring`

---

### Task 4: Descend, gauntlet, reward, return

**Files:**
- Modify: `scripts/Basement.gd` (the gauntlet half), `scripts/Hud.gd` (reuse `_show_banner(text, sub)` from Pack 0 — no new HUD code beyond a countdown reuse check)

**Interfaces:**
- Consumes: `Spawner.suspended`/`ObstacleField.suspended` (T2), `BasementLogic.crate_floor` (T1), `Enemies.pick(wave)` + `configure(Enemies.stats_for(...))` + `apply_elite(kind)` (Spawner._spawn_enemy idiom, Spawner.gd:100-106), the NIGHT STOCKER's in-run crate-pickup entity (grep `CrateDrop`/`crate_pickup` — find what `Patterns.CRATE` spawns and reuse THAT entity directly with the floor from `BasementLogic.crate_floor`; if its rarity floor isn't parameterized, add an optional `rarity_floor` to the pickup's grant call — report the shape found), `ScreenFlash` (fade), `CombatText.callout` or `_show_banner` for the BASEMENT banner.
- Produces: full lifecycle on `Basement`: `_descend()` → fade (ScreenFlash), store `_surface_pos = player.global_position`, teleport player to `BASEMENT_OFFSET`, build the wall ring ONCE per descent (ring of `no_cull` indestructible rubble-style solid cover — reuse the Obstacles/Destructible registry the way ObstacleField spawns cover; ~24 segments at `BASEMENT_RADIUS`; tag them in a `"basement_wall"` group for cleanup), `Spawner.suspended = true`, `ObstacleField.suspended = true`, `in_basement = true`, banner `_show_banner("THE BASEMENT", "hold out")`, start `BASEMENT_DURATION` countdown (own timer var — do NOT touch DifficultyManager.run_time; the shift clock ticking on is the point); gauntlet spawning: own `_spawn_t` cadence `BASEMENT_SPAWN_INTERVAL`, spawns at the arena rim (ring radius − 100) via the Spawner idiom; exactly `BASEMENT_ELITES` (+1 if wave > 10) elites forced via `apply_elite(KINDS[RunConfig.rand_int() % 4])` spread across the window (e.g. at 10s intervals); timer end → stop spawning, spawn the reward crate pickup at arena center with `BasementLogic.crate_floor(DifficultyManager.wave)`, banner `_show_banner("SHIFT CONTINUES", "grab it and go")`, `BASEMENT_PICKUP_WINDOW` countdown → `_ascend()`: fade, kill every node in `"basement_wall"` + any enemies beyond 2000px of the surface point (the gauntlet stragglers — free them directly, no rewards), teleport back to `_surface_pos`, unsuspend both systems, `in_basement = false`. Player death inside: nothing special — GameOver flow already handles it; the controller must also detect `player` invalid and hard-reset its state (no dangling suspension into the death screen).

- [ ] **Step 1: Failing probe:** the lifecycle is tree-bound; probe the pure seams only: `crate_floor` values across waves (already T1 — extend with the elite-count rule: expose `static func elite_count(wave: int) -> int` on BasementLogic returning `GameConfig.BASEMENT_ELITES + (1 if wave > 10 else 0)` and probe 3→2, 11→3). Expect FAIL (method missing).
- [ ] **Step 2: Implement** everything in the Interfaces block. Every judgment call (crate-pickup shape, wall-segment source, straggler cleanup radius) gets a one-line report note.
- [ ] **Step 3: Probe PASS; BOTH gates 0/0; commit:** `feat(basement): descend/gauntlet/reward/return lifecycle`

---

### Task 5: Pay-stub line + counter

**Files:**
- Modify: `scripts/Basement.gd` (increment), `scripts/GameOver.gd` (stub row), `scripts/SaveManager.gd` (DEFAULTS + accessor), RunStats (per-run counter — find its file via `grep -rn "class_name RunStats\|var bonus_coins" scripts/`)

**Interfaces:**
- Produces: `RunStats.basements_cleared: int` (reset in `RunStats.reset()`, incremented on each successful gauntlet completion — at crate spawn, not at pickup); lifetime `SaveManager` key `"basements_cleared"` (DEFAULTS + `add_basement_cleared()` accessor, flushed where other lifetime counters flush — grep `crates_opened_total` for the chokepoint idiom and mirror); GameOver stub row `_row(_stub_vbox, "BASEMENTS CLEARED", "×%d")` only when > 0 (informational row, NO coin value — place near the wave/boss rows).

- [ ] **Step 1: Failing probe:** `SaveManager.add_basement_cleared()` increments the key; DEFAULTS contains it (snapshot/restore `_data`). Expect FAIL.
- [ ] **Step 2: Implement.** Mirror the `crates_opened_total` counter idiom exactly (same flush site, same accessor shape).
- [ ] **Step 3: Probe PASS; gates 0/0; commit:** `feat(basement): BASEMENTS CLEARED stub line + lifetime counter`

---

### Task 6: Ship v0.1.63 (controller task)

- [ ] Fable whole-branch review (base = v0.1.62 ship commit `72772c0`); one fix dispatch; Minor triage.
- [ ] `VERSION` → `0.1.63`; CHANGELOG:

```markdown
## v0.1.63 — Check the Walk-In (2026-07-10)

Someone has to.
- **NEW: THE BASEMENT** — a cellar door sometimes appears mid-shift. Stand on it and go down: sixty seconds, walls, everything the dark can throw at you, guaranteed elites. Survive and a crate comes up with you. The shift clock keeps running while you're down there — basement time is stolen time.
- Twice a night, at most. The door doesn't wait forever. Not available in Boss Rush.
- Your pay-stub now counts BASEMENTS CLEARED. Wear it proudly.
```

- [ ] Push, CI green, confirm 0.1.63 stamp, tag, `gh release create` with APK.
- [ ] Ledger + memory. F5 checklist: door telegraphs readably + despawns; hold-to-descend arc feel; gauntlet density survivable-but-scary at wave 5 vs 12; clock visibly kept running; crate floor scales; death inside = clean GameOver (no stuck suspension); Daily runs identical twice (seed intact); horde-mode basement sanity; return teleport doesn't strand you in cover.

## Self-review notes (applied)

- Spec §Pack E coverage: roll/gates (T1/T3), suspension (T2), door prop (T3), gauntlet+reward+return (T4), stub+counter (T5). The spec's "surface enemies distance-culled or never reach" concern resolves via T4's straggler cleanup + 24k offset (enemies have no cull — they walk toward the player but cover 24k px at ~100px/s = never arrive within 60s; cleaned at ascend).
- ALLOWED_MODES representation is flagged as verify-first (overtime/daily are endless flags) rather than guessed.
- Type consistency: `BasementLogic` statics, `suspended` flags, and signal names match between producer and consumer tasks.

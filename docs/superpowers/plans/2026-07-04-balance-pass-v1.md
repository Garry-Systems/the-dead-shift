# Balance Pass v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved Balance Pass v1 (spec `docs/superpowers/specs/2026-07-04-balance-pass-v1-design.md`): soften the late-game cliff, make late bosses scary, scale enemy special damage, tune 6 guns, guarantee affix signature stats, fix the crate economy, pay out on quit, and scale elite XP.

**Architecture:** Almost everything is data/constant changes in the existing config-over-code layers (`GameConfig.gd`, `Weapons.gd`, `Affixes.gd`, `Crates.gd`). Three small mechanics: a `special_mult` wave-growth factor threaded through the existing `configure(stats)` dicts (pure, headless-testable), an `impact_frac` key on delivery shells, and a quit-payout path in PauseMenu mirroring GameOver.

**Tech Stack:** Godot 4.6 / GDScript (tabs, `def.get()` for optional keys), headless Godot 4.6.3 via WSL interop for parse gates + probes, Python stdlib sprite generator in the home repo.

## Global Constraints

- Game repo: `/mnt/c/Users/thela/Documents/mobile-game` (Windows path `C:\Users\thela\Documents\mobile-game`). Work on branch `feat/balance-pass-v1` off master.
- Home repo: `/home/larryun` (sprite generator + this plan). Separate git repo, no remote.
- GDScript: TAB indentation, `##` doc comments on new functions, snake_case. NEW dict keys read via `def.get()`/`stats.get()` with defaults so untouched content keeps working.
- Do NOT touch: rarity drop odds (`Rarity.roll`), talent counts (`Rarity.TIERS[].talents` = 0/0/1/1/2/3/3/4), talent level-gating, Nail Gun pin values, the 3 dev grants.
- Crate icons: strict 4-color 32×32 palette (C1 `#0A001A`, C2 `#3D0099`, C3 `#8C8573`, C4 `#E0E5FF`). The 64×64 gunmetal override is weapons-only.
- Headless gate after EVERY task (see Task 0 for `$GODOT`): parse must be clean. The `EditorSettings not instantiated` ERROR is benign noise; grep only `SCRIPT ERROR|PARSE ERROR`.
- Probes are transient `probe_balance.gd` SceneTree scripts at the game-repo root — delete the file AND its generated `.uid` before the final commit.
- Commit per task on the branch. End every commit message with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01GCNSBjBidRc6ziYtYeWov1`
- Numbers in this plan are Larry-approved. Do not "improve" them.

---

### Task 0: Environment + assumption gate (no commit)

**Files:** none modified.

**Interfaces:**
- Produces: a working `$GODOT` command string used by every later task; confirmed weapon/method identifiers.

- [ ] **Step 1: Locate or install headless Godot**

```bash
ls /tmp/godot46/ 2>/dev/null || (mkdir -p /tmp/godot46 && cd /tmp/godot46 && unzip -q ~/Downloads/Godot_v4.6.3-stable_mono_win64.zip && chmod +x */Godot*console.exe)
find /tmp/godot46 -name "*console.exe"
```
Expected: one path like `/tmp/godot46/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe`. Export it:
```bash
GODOT="<the path found>"
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --quit 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"
```
Expected: `0`.

- [ ] **Step 2: Verify identifiers the plan relies on**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
grep -n '"id": "tesla' scripts/logic/Weapons.gd            # exact Tesla weapon id (expect "tesla")
grep -n "func heal\|func max_hp" scripts/Player.gd          # BossBase heal API
grep -n "cfg.get(\"damage\"" scripts/patterns/ProjectileEmitter.gd
grep -n "func record_run\|func add_game_played" scripts/SaveManager.gd
grep -n "func add_run_xp" scripts/loot/Inventory.gd
git checkout -b feat/balance-pass-v1
```
Expected: every grep hits. If the Tesla id is NOT `tesla`, use the real id in Task 5's `bases` list.

- [ ] **Step 3: Mirror the spec + plan into the game repo**

```bash
mkdir -p docs/superpowers/specs docs/superpowers/plans
cp /home/larryun/docs/superpowers/specs/2026-07-04-balance-pass-v1-design.md docs/superpowers/specs/
cp /home/larryun/docs/superpowers/plans/2026-07-04-balance-pass-v1.md docs/superpowers/plans/
```
(Committed with Task 1.)

---

### Task 1: Difficulty curve + boss late ramp + boss heal

**Files:**
- Modify: `scripts/logic/GameConfig.gd:51` (SPAWN_INTERVAL_FLOOR), `:62` (ENEMY_LATE_HP_GROWTH), near `:70` (new BOSS_LATE_HP_GROWTH), near `:179` (new BOSS_KILL_HEAL_FRAC)
- Modify: `scripts/logic/DifficultyCurve.gd:28-34` (boss_stats)
- Modify: `scripts/BossBase.gd:182-186` (heal)

**Interfaces:**
- Produces: `GameConfig.BOSS_LATE_HP_GROWTH: float`, `GameConfig.BOSS_KILL_HEAL_FRAC: float`; `DifficultyCurve.boss_stats(wave)` now late-ramps HP.

- [ ] **Step 1: Edit GameConfig constants**

Line 51: `const SPAWN_INTERVAL_FLOOR := 0.20` → `const SPAWN_INTERVAL_FLOOR := 0.25    # fastest the spawner ever gets (seconds)`
Line 62: `const ENEMY_LATE_HP_GROWTH := 1.15` → `const ENEMY_LATE_HP_GROWTH := 1.12     # per-wave HP multiplier past ENEMY_LATE_WAVE`
After line 70 (`BOSS_SPAWN_RATE_MULT`), add:
```gdscript
const BOSS_LATE_HP_GROWTH := 1.12     # extra per-wave boss HP multiplier past ENEMY_LATE_WAVE (mirrors trash)
```
After line 179 (`BOSS_RUSH_HEAL_FRAC`), add:
```gdscript
const BOSS_KILL_HEAL_FRAC := 0.33      # endless boss-kill heal fraction (was a FULL heal)
```

- [ ] **Step 2: Late-ramp boss HP in DifficultyCurve.boss_stats**

Replace lines 30-34 with:
```gdscript
static func boss_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)
	var hp: float = GameConfig.BOSS_BASE_HP * pow(GameConfig.ENEMY_HP_GROWTH, w)
	var dmg: float = GameConfig.BOSS_TOUCH_DAMAGE * pow(GameConfig.ENEMY_DMG_GROWTH, w)
	# Past the late wave, bosses ramp like trash does — otherwise trash HP outgrows
	# bosses and every 5th late wave becomes the EASY part of the run.
	if wave > GameConfig.ENEMY_LATE_WAVE:
		hp *= pow(GameConfig.BOSS_LATE_HP_GROWTH, wave - GameConfig.ENEMY_LATE_WAVE)
	return {"max_health": hp, "move_speed": GameConfig.BOSS_MOVE_SPEED, "touch_damage": dmg}
```
NOTE: Boss Rush feeds `boss_stats(boss_rush_count)` (Spawner.gd:59), so bosses past the 10th spawn in a rush also ramp — accepted side effect, flag for phone tuning.

- [ ] **Step 3: Cut the endless full heal in BossBase._reward**

Replace lines 182-186:
```gdscript
	if _target and is_instance_valid(_target):
		if boss_rush:
			_target.heal(_target.max_hp() * GameConfig.BOSS_RUSH_HEAL_FRAC)
		else:
			_target.full_heal()
```
with:
```gdscript
	if _target and is_instance_valid(_target):
		if boss_rush:
			_target.heal(_target.max_hp() * GameConfig.BOSS_RUSH_HEAL_FRAC)
		else:
			# Endless: a strong top-up, no longer a full reset — late bosses stay a
			# risk/reward spike instead of a free sustain valve.
			_target.heal(_target.max_hp() * GameConfig.BOSS_KILL_HEAL_FRAC)
```

- [ ] **Step 4: Parse gate**

```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --editor --quit 2>&1 | grep -E "SCRIPT ERROR|PARSE ERROR"
```
Expected: no output.

- [ ] **Step 5: Curve probe**

Write `probe_balance.gd` at the game-repo root:
```gdscript
extends SceneTree
## Transient probe: difficulty-curve checkpoints for Balance Pass v1 Task 1.
func _init() -> void:
	var fails := 0
	# Wave-1 values must be untouched (base stats, no growth).
	var e1 := DifficultyCurve.enemy_stats(1)
	if absf(float(e1["max_health"]) - GameConfig.ENEMY_MAX_HEALTH) > 0.001:
		print("FAIL wave-1 enemy hp changed"); fails += 1
	var b10 := DifficultyCurve.boss_stats(10)
	if absf(float(b10["max_health"]) - GameConfig.BOSS_BASE_HP * pow(GameConfig.ENEMY_HP_GROWTH, 9)) > 0.01:
		print("FAIL boss wave<=10 got ramped"); fails += 1
	# Late ramp must be ACTIVE past wave 10.
	var b20 := DifficultyCurve.boss_stats(20)
	var raw20 := GameConfig.BOSS_BASE_HP * pow(GameConfig.ENEMY_HP_GROWTH, 19)
	if float(b20["max_health"]) <= raw20 * 2.0:
		print("FAIL boss late ramp missing/weak: ", b20["max_health"], " vs raw ", raw20); fails += 1
	if absf(GameConfig.SPAWN_INTERVAL_FLOOR - 0.25) > 0.0001 or absf(GameConfig.ENEMY_LATE_HP_GROWTH - 1.12) > 0.0001:
		print("FAIL constants"); fails += 1
	for w in [1, 5, 11, 16, 21]:
		print("wave %d: trash hp %.0f  interval %.2f  boss hp %.0f" % [w,
			DifficultyCurve.enemy_stats(w)["max_health"], DifficultyCurve.spawn_interval(w),
			DifficultyCurve.boss_stats(w)["max_health"]])
	print("PROBE " + ("OK" if fails == 0 else "FAILED (%d)" % fails))
	quit()
```
Run:
```bash
"$GODOT" --path "C:\\Users\\thela\\Documents\\mobile-game" --headless --script res://probe_balance.gd 2>&1 | tail -10
```
Expected: checkpoint table + `PROBE OK`.

- [ ] **Step 6: Commit**

```bash
git add scripts/logic/GameConfig.gd scripts/logic/DifficultyCurve.gd scripts/BossBase.gd docs/superpowers
git commit -m "feat(balance): soften late HP cliff, late-ramp boss HP, endless boss heal 33%"
```
(`probe_balance.gd` stays untracked until Task 8 deletes it.)

---

### Task 2: Enemy special damage scales with waves

**Files:**
- Modify: `scripts/logic/DifficultyCurve.gd` (enemy_stats + boss_stats return dicts)
- Modify: `scripts/logic/Enemies.gd:50-56` (stats_for pass-through)
- Modify: `scripts/Enemy.gd` (~line 20 var; configure at 45-51)
- Modify: `scripts/BossBase.gd:31-36` (configure)
- Modify: `scripts/RangedEnemy.gd:44`, `scripts/ExploderEnemy.gd:31-33`
- Modify: `scripts/patterns/AttackPattern.gd` (new helper), `scripts/patterns/ExpandingRing.gd:19`, `scripts/patterns/AimedBand.gd:19`, `scripts/patterns/ZoneFill.gd:17`, `scripts/patterns/ProjectileEmitter.gd` (its `cfg.get("damage", ...)` line)

**Interfaces:**
- Consumes: nothing from other tasks (independent of Task 1's value changes).
- Produces: `stats["special_mult"]` in every `DifficultyCurve.enemy_stats`/`boss_stats`/`Enemies.stats_for` dict; `Enemy._special_mult: float`; `BossBase.special_mult: float` (public); `AttackPattern._special_mult_of(b: Node2D) -> float`.
- Rule: player-placed hazards (Acid Cannon pools via `configure_hazard` with `setup(null, ...)`) and destructible-spawned world hazards stay FLAT — only enemy/boss-dealt specials scale.

- [ ] **Step 1: Emit the multiplier from the pure curve**

In `DifficultyCurve.enemy_stats`, compute the growth once and return it. Replace line 14 and line 20:
```gdscript
	var growth := pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var dmg: float = GameConfig.ENEMY_TOUCH_DAMAGE * growth
```
and the return becomes:
```gdscript
	return {"max_health": hp, "move_speed": spd, "touch_damage": dmg, "special_mult": growth}
```
In `boss_stats` (as rewritten in Task 1), same pattern:
```gdscript
	var growth := pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var dmg: float = GameConfig.BOSS_TOUCH_DAMAGE * growth
```
and return:
```gdscript
	return {"max_health": hp, "move_speed": GameConfig.BOSS_MOVE_SPEED, "touch_damage": dmg, "special_mult": growth}
```

- [ ] **Step 2: Pass it through Enemies.stats_for**

`scripts/logic/Enemies.gd:50-56` — add one line to the returned dict (NOT multiplied by the per-type `dmg_mult`; the exploder's dmg_mult is 0.0 and must not zero this):
```gdscript
static func stats_for(entry: Dictionary, wave: int) -> Dictionary:
	var base := DifficultyCurve.enemy_stats(wave)
	return {
		"max_health": float(base["max_health"]) * float(entry["hp_mult"]),
		"move_speed": minf(float(base["move_speed"]) * float(entry["spd_mult"]), GameConfig.ENEMY_HARD_SPEED_CAP),
		"touch_damage": float(base["touch_damage"]) * float(entry["dmg_mult"]),
		"special_mult": float(base["special_mult"]),
	}
```

- [ ] **Step 3: Bake it on Enemy + BossBase at configure**

`scripts/Enemy.gd` — near the stat vars (~line 23), add:
```gdscript
var _special_mult := 1.0       # wave-growth factor for flat special damage (projectiles, blasts)
```
In `configure()` (lines 47-51), add before the `_health` line:
```gdscript
	_special_mult = float(stats.get("special_mult", 1.0))
```
`scripts/BossBase.gd` — near its stat vars, add:
```gdscript
var special_mult := 1.0        # wave-growth factor patterns apply to their flat damage numbers
```
In `configure()` (lines 32-36), add before the `_health` line:
```gdscript
	special_mult = float(stats.get("special_mult", 1.0))
```

- [ ] **Step 4: Scale the two enemy dealers**

`scripts/RangedEnemy.gd:44`:
```gdscript
	proj.setup(dir, GameConfig.RANGED_PROJECTILE_SPEED, GameConfig.RANGED_PROJECTILE_DAMAGE * _special_mult)
```
`scripts/ExploderEnemy.gd:33` (keep the surrounding radius check):
```gdscript
			_target.take_damage(GameConfig.EXPLODER_BLAST_DAMAGE * _special_mult)
```

- [ ] **Step 5: Scale the boss patterns via one base-class helper**

`scripts/patterns/AttackPattern.gd` — add below `setup()`:
```gdscript
## Wave-growth multiplier baked into the owning boss at spawn. 1.0 when there is no
## boss (player-spawned HazardZones call setup(null, ...) and must stay flat).
func _special_mult_of(b: Node2D) -> float:
	if b != null and is_instance_valid(b) and "special_mult" in b:
		return float(b.special_mult)
	return 1.0
```
Then multiply the flat reads in each pattern's `setup()`:
- `scripts/patterns/ExpandingRing.gd:19`: `_damage = float(cfg.get("damage", GameConfig.SLAM_DAMAGE)) * _special_mult_of(b)`
- `scripts/patterns/AimedBand.gd:19`: `_damage = float(cfg.get("damage", GameConfig.AIMED_BAND_DAMAGE)) * _special_mult_of(b)`
- `scripts/patterns/ZoneFill.gd:17`: `_dps = float(cfg.get("dps", GameConfig.ZONE_DEFAULT_DPS)) * _special_mult_of(b)`
- `scripts/patterns/ProjectileEmitter.gd` (find its `_damage = float(cfg.get("damage", GameConfig.BOSS_PROJECTILE_DAMAGE))` line): append ` * _special_mult_of(b)` — if that line is outside `setup()` and has no `b` in scope, use the stored `boss` member instead: `* _special_mult_of(boss)`.

Do NOT touch: `scripts/HazardZone.gd` (dual-use player/world pools), `scripts/Destructible.gd` (barrel bursts are not player damage), `scripts/patterns/SummonSpawner.gd` (spawns adds, deals no damage).

- [ ] **Step 6: Parse gate** (same command as Task 1 Step 4). Expected: clean.

- [ ] **Step 7: Probe**

Append to `probe_balance.gd` `_init()` (before the final print; keep Task 1's checks):
```gdscript
	# special_mult present and equal to the bite growth factor
	for w2 in [1, 11, 21]:
		var es := DifficultyCurve.enemy_stats(w2)
		var want := pow(GameConfig.ENEMY_DMG_GROWTH, w2 - 1)
		if absf(float(es.get("special_mult", -1.0)) - want) > 0.0001:
			print("FAIL special_mult wave ", w2); fails += 1
		var bs := DifficultyCurve.boss_stats(w2)
		if absf(float(bs.get("special_mult", -1.0)) - want) > 0.0001:
			print("FAIL boss special_mult wave ", w2); fails += 1
	var sf := Enemies.stats_for({"hp_mult": 2.2, "spd_mult": 1.0, "dmg_mult": 0.0}, 21)
	if absf(float(sf.get("special_mult", -1.0)) - pow(GameConfig.ENEMY_DMG_GROWTH, 20)) > 0.0001:
		print("FAIL stats_for drops/zeroes special_mult"); fails += 1
```
Run the probe. Expected: `PROBE OK`.

- [ ] **Step 8: Commit**

```bash
git add scripts/logic/DifficultyCurve.gd scripts/logic/Enemies.gd scripts/Enemy.gd scripts/BossBase.gd scripts/RangedEnemy.gd scripts/ExploderEnemy.gd scripts/patterns/AttackPattern.gd scripts/patterns/ExpandingRing.gd scripts/patterns/AimedBand.gd scripts/patterns/ZoneFill.gd scripts/patterns/ProjectileEmitter.gd
git commit -m "feat(balance): enemy special damage (projectiles/blasts/slams/bands/zones) scales per-wave like bites"
```

---

### Task 3: Gun tuning — 6 weapons

**Files:**
- Modify: `scripts/logic/Weapons.gd` (sniper :51-57, slug_gun :113-118, grenade_launcher :144-149, lmg :152-156, acid_cannon :159-165, flamethrower :76-81)
- Modify: `scripts/logic/GameConfig.gd:32-33` (FLAME_BURN_*)
- Modify: `scripts/Gun.gd` (configure ~:85-114, `_build_pool_cfg` :284-292, `_spawn_bullet` :260-282, new vars near :24-28)
- Modify: `scripts/Bullet.gd` (shell vars :21-25, `_on_body_entered` shell branch :51-57)

**Interfaces:**
- Produces: def keys `pool_dps` (acid pool dps, scales with the damage ratio) and `impact_frac` (fraction of `damage` dealt to a directly-contacted enemy before a shell detonates); `Gun.pool_dps`, `Gun.impact_frac`, `Gun._base_damage`, `Bullet.impact_frac`.

- [ ] **Step 1: Weapons.gd def edits**

sniper — insert a mode/pierce line (matching slug_gun's pattern) after the id line:
```gdscript
		{
			"id": "sniper", "name": "Sniper", "desc": "Bolt-action — devastating, slow, punches through the line", "category": "Sniper",
			"fire_mode": "projectile", "base_pierce": 2,
			"damage": 120.0, "fire_interval": 0.90, "bullet_speed": 1500.0,
```
(rest of the def unchanged)
slug_gun: `"damage": 60.0,` → `"damage": 78.0,`
lmg: `"mag_size": 100, "reload_time": 3.2,` → `"mag_size": 100, "reload_time": 4.5,`
grenade_launcher — extend the mode line:
```gdscript
			"fire_mode": "projectile", "explode_radius": 130.0, "explode_force": 600.0, "impact_frac": 0.5,
```
acid_cannon — extend the pool line:
```gdscript
			"pool_radius": 90.0, "pool_duration": 3.5, "pool_slow": 0.4, "pool_slow_dur": 1.0, "pool_dps": 25.0,
```
flamethrower: `"damage": 6.0,` → `"damage": 5.0,`

- [ ] **Step 2: GameConfig flame burn**

Lines 32-33 →
```gdscript
const FLAME_BURN_DPS := 30.0           # Flamethrower base burn — a real damage channel, not a tick
const FLAME_BURN_TIME := 3.0           # Flamethrower burn duration, refreshed each tick — melts after the sweep
```

- [ ] **Step 3: Gun.gd plumbing**

Near the pool vars (lines 24-28), add:
```gdscript
var pool_dps := 0.0                # pool damage/sec at BASE damage (0 = pool dps just equals live damage)
var impact_frac := 0.0             # shells: fraction of damage dealt to the directly-hit enemy (0 = none)
var _base_damage := 0.0            # def damage before loot/cards — anchors ratio-scaled derived stats
```
In `configure()`, after `damage = float(def["damage"])` add:
```gdscript
	_base_damage = damage
```
and in the `def.get()` block (after the `pool_slow_dur` line) add:
```gdscript
	pool_dps = float(def.get("pool_dps", 0.0))
	impact_frac = float(def.get("impact_frac", 0.0))
```
Replace `_build_pool_cfg` (lines 284-292) with:
```gdscript
## Build the enemy-only HazardZone config for a pool-dropping shell (Acid Cannon).
## Pool dps is its own def stat (pool_dps), scaled by the gun's live/base damage ratio
## so damage cards & affixes still grow the pool — but shell hit and pool tune apart.
func _build_pool_cfg() -> Dictionary:
	var color = Hazards.GREEN if pool_family == "acid" else Hazards.ORANGE
	var dps := damage
	if pool_dps > 0.0 and _base_damage > 0.0:
		dps = pool_dps * (damage / _base_damage)
	return {
		"color": color, "dps": dps, "radius": pool_radius, "duration": pool_duration,
		"slow": pool_slow, "slow_dur": pool_slow_dur, "stun": 0.0, "chain": 0,
		"drift": 0.0, "hurts_player": false,
	}
```
In `_spawn_bullet` (after `bullet.explode_force = explode_force`), add:
```gdscript
	bullet.impact_frac = impact_frac
```

- [ ] **Step 4: Bullet.gd impact damage**

Shell vars block (lines 21-25) — add:
```gdscript
var impact_frac := 0.0         # >0: the directly-contacted enemy takes damage*frac before the blast
```
Replace the shell branch at the top of `_on_body_entered` (lines 52-57):
```gdscript
	if _is_shell():
		# Delivery shells ignore pierce — but a direct enemy hit lands impact damage
		# (impact_frac of the shell's damage) BEFORE detonating, so the Grenade
		# Launcher isn't dead weight against a single boss. Cover/props: blast only.
		if body.is_in_group("cover") or body.is_in_group("destructibles") or body.is_in_group("enemies"):
			if impact_frac > 0.0 and body.is_in_group("enemies") and body.has_method("take_damage"):
				body.take_damage(damage * impact_frac)
			_detonate()
			queue_free()
		return
```
(`_detonate` runs after the impact so an impact kill still detonates at the corpse; the `_detonated` guard keeps it once-only.)

- [ ] **Step 5: Parse gate.** Expected: clean.

- [ ] **Step 6: Probe def values**

Append to `probe_balance.gd` before the final print:
```gdscript
	# Task 3 gun defs
	var want_defs := {
		"sniper": {"base_pierce": 2.0}, "slug_gun": {"damage": 78.0},
		"lmg": {"reload_time": 4.5}, "grenade_launcher": {"impact_frac": 0.5},
		"acid_cannon": {"pool_dps": 25.0}, "flamethrower": {"damage": 5.0},
	}
	for def in Weapons.all():
		var wid := String(def["id"])
		if want_defs.has(wid):
			for k in want_defs[wid]:
				if absf(float(def.get(k, -999.0)) - float(want_defs[wid][k])) > 0.0001:
					print("FAIL def ", wid, ".", k, " = ", def.get(k)); fails += 1
	if absf(GameConfig.FLAME_BURN_DPS - 30.0) > 0.0001 or absf(GameConfig.FLAME_BURN_TIME - 3.0) > 0.0001:
		print("FAIL flame burn consts"); fails += 1
```
Run. Expected: `PROBE OK`.

- [ ] **Step 7: Commit**

```bash
git add scripts/logic/Weapons.gd scripts/logic/GameConfig.gd scripts/Gun.gd scripts/Bullet.gd
git commit -m "feat(balance): tune 6 guns — sniper pierce, slug/LMG numbers, GL impact hit, acid pool_dps, real flame burn"
```

---

### Task 4: Affix signature-stat guarantee

**Files:**
- Modify: `scripts/loot/Affixes.gd` (add `"signature"` to every non-legacy `rN_*` affix)
- Modify: `scripts/loot/LootRoller.gd:31-36` (the stat-subset draw)

**Interfaces:**
- Produces: `affix["signature"]: String` on all rollable affixes; `LootRoller.roll` always includes the signature stat in `inst["stats"]`.

- [ ] **Step 1: Add signature keys**

Family rule (one per affix, must be a key of that affix's `stats`):
razor → `"damage"` · rapid → `"fire_rate"` · longshot → `"range"` · hollow → `"pierce"` · brutal → `"multishot"` · heavy → `"mag"` at r3 (it has no multishot), `"multishot"` at r4-r8.
Edit each of the 21 `rN_*` defs, inserting `"signature": "<stat>",` right after `"rarity": N,`. Example (r5_brutal):
```gdscript
		{ "id": "r5_brutal", "name": "Brutal", "rarity": 5, "signature": "multishot", "min_stats": 3, "max_stats": 4, "min_talents": 2, "max_talents": 2, "stats": { "damage": [40, 72], "multishot": [1, 2], "pierce": [1, 2], "fire_rate": [18, 30] } },
```
Full mapping: r1_razor damage, r1_rapid fire_rate, r2_razor damage, r2_rapid fire_rate, r2_longshot range, r3_razor damage, r3_rapid fire_rate, r3_heavy mag, r4_razor damage, r4_heavy multishot, r4_hollow pierce, r4_longshot range, r5_razor damage, r5_heavy multishot, r5_hollow pierce, r5_brutal multishot, r6_razor damage, r6_heavy multishot, r6_hollow pierce, r6_brutal multishot, r7_razor damage, r7_heavy multishot, r7_hollow pierce, r7_brutal multishot, r8_razor damage, r8_heavy multishot, r8_hollow pierce, r8_brutal multishot. Legacy affixes (`rusted`…`carnage`): NO signature (they never roll).

- [ ] **Step 2: Guarantee the draw in LootRoller.roll**

Replace lines 31-36 (`# Choose how many...` through the `for i in n:` loop) with:
```gdscript
	# Choose how many of the affix's stats roll, then roll each as a 0..1 quality.
	# The affix's SIGNATURE stat is always among them — a purple that says "Brutal"
	# always brings its multishot; the rest of the draw stays random (god-rolls live).
	var keys: Array = affix.get("stats", {}).keys()
	keys.shuffle()
	var sig := String(affix.get("signature", ""))
	if sig != "" and keys.has(sig):
		keys.erase(sig)
		keys.push_front(sig)
	var n: int = clampi(randi_range(int(affix["min_stats"]), int(affix["max_stats"])), 0, keys.size())
	for i in n:
		inst["stats"][keys[i]] = snappedf(randf(), 0.001)
```
(Every rollable affix has `min_stats >= 1`, so `n >= 1` and the front-loaded signature always draws.)

- [ ] **Step 3: Parse gate.** Expected: clean.

- [ ] **Step 4: Loot probe**

Append to `probe_balance.gd`:
```gdscript
	# Task 4: signature always rolls; talent counts regression (0/0/1/1/2/3/3/4)
	var want_talents := [0, 0, 1, 1, 2, 3, 3, 4]
	for tier in range(1, 9):
		for i2 in 300:
			var inst := LootRoller.roll(tier)
			var affix := Affixes.get_affix(String(inst["affix"]))
			var sig := String(affix.get("signature", ""))
			if sig == "" or not inst["stats"].has(sig):
				print("FAIL tier ", tier, " affix ", affix.get("id"), " missing signature"); fails += 1
				break
			if inst["talents"].size() != want_talents[tier - 1]:
				print("FAIL tier ", tier, " talent count ", inst["talents"].size()); fails += 1
				break
```
Run. Expected: `PROBE OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/loot/Affixes.gd scripts/loot/LootRoller.gd
git commit -m "feat(loot): every affix guarantees its signature stat — a purple always feels purple"
```

---

### Task 5: Crate economy — prices, floors, Specials Case + icon

**Files:**
- Modify: `scripts/loot/Crates.gd` (fiftyfifty price; 3 floors + descs; new specials_case)
- Modify (HOME repo): `/home/larryun/gen_palette_sprites.py` (new emblem + make line)
- Create: `art/crates/specials_case.png` (generated)

**Interfaces:**
- Produces: crate id `specials_case` (auto-appears in Store — `MainMenu` loops `Crates.all()`; icon auto-loads from `art/crates/specials_case.png` via `Crates.icon()`).

- [ ] **Step 1: Crates.gd edits**

fiftyfifty: `"price": 400,` → `"price": 700,`
precision_pack / auto_case / standard_arms: `"rarity_floor": 1,` → `"rarity_floor": 2,` on all three, and update each desc's tail from `Any rarity up to Apocalypse.` to `Salvaged or better, up to Apocalypse.` (keep the first sentence).
Insert after the standard_arms entry (use the EXACT Tesla id confirmed in Task 0):
```gdscript
		{
			"id": "specials_case", "name": "Specials Case", "price": 650,
			"rarity_floor": 2, "rarity_ceil": 8, "bases": ["tesla", "flamethrower", "acid_cannon"],
			"desc": "Weird science: Tesla, flame & acid. Salvaged or better, up to Apocalypse.",
		},
```

- [ ] **Step 2: Icon in the home-repo generator**

In `/home/larryun/gen_palette_sprites.py` inside `crates()`, add an emblem (after the `apocalypse` def) — a lightning bolt for the weird-science case, C4 on the shared chest:
```python
    def bolt(b):                          # Specials Case: a lightning bolt (weird science)
        rect(b, 32, 16, 13, 4, 2, C4)
        rect(b, 32, 14, 15, 4, 2, C4)
        rect(b, 32, 12, 17, 8, 2, C4)
        rect(b, 32, 15, 19, 4, 2, C4)
        rect(b, 32, 13, 21, 4, 2, C4)
```
and register it with the other `make(...)` calls:
```python
    make("specials_case", bolt)
```
Run it:
```bash
cd /home/larryun && python3 -c "import gen_palette_sprites as g; g.crates()"
ls -la "/mnt/c/Users/thela/Documents/mobile-game/art/crates/specials_case.png"
```
Expected: the PNG exists (existing crate PNGs regenerate byte-identical — the generator is deterministic).

- [ ] **Step 3: Visual QA the icon**

Upscale and READ the image (multimodal):
```bash
python3 -c "
from PIL import Image
im = Image.open('/mnt/c/Users/thela/Documents/mobile-game/art/crates/specials_case.png').resize((256,256), Image.NEAREST)
im.save('/tmp/claude-1000/-home-larryun/fcc2fef1-bc7e-4646-9a69-1bfab57358c2/scratchpad/specials_case_big.png')"
```
(If PIL is unavailable, read the 32×32 PNG directly.) The bolt must read as a zigzag against the indigo chest, distinct from the 10 existing emblems. Adjust rects and regenerate if muddy.

- [ ] **Step 4: Parse gate.** Expected: clean. (Godot picks the PNG up on next editor scan; headless `--editor --quit` generates the `.import`.)

- [ ] **Step 5: Crate probe**

Append to `probe_balance.gd`:
```gdscript
	# Task 5: crate economy
	if int(Crates.get_crate("fiftyfifty").get("price", 0)) != 700:
		print("FAIL 5050 price"); fails += 1
	for cid in ["precision_pack", "auto_case", "standard_arms", "specials_case"]:
		if int(Crates.get_crate(cid).get("rarity_floor", 0)) < 2:
			print("FAIL floor ", cid); fails += 1
	var sc := Crates.get_crate("specials_case")
	if sc.is_empty():
		print("FAIL specials_case missing"); fails += 1
	else:
		var wids := []
		for wdef in Weapons.all():
			wids.append(String(wdef["id"]))
		for bid in sc.get("bases", []):
			if not wids.has(String(bid)):
				print("FAIL specials_case base not a weapon id: ", bid); fails += 1
		for i3 in 300:
			var r_inst := LootRoller.roll_from_crate(sc)
			if int(r_inst["rarity"]) < 2 or not sc["bases"].has(String(r_inst["base"])):
				print("FAIL specials_case roll ", r_inst["rarity"], " ", r_inst["base"]); fails += 1
				break
```
Run. Expected: `PROBE OK`.

- [ ] **Step 6: Commit both repos**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/loot/Crates.gd art/crates/specials_case.png art/crates/specials_case.png.import
git commit -m "feat(economy): 50/50 crate 700c, category crates floor 2, new Specials Case crate (tesla/flame/acid)"
cd /home/larryun && git add gen_palette_sprites.py && git commit -m "gen_palette_sprites: specials_case crate icon (bolt emblem)"
```

---

### Task 6: Quit/restart pays out at 75%

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (new const near the COIN_* block :124-127)
- Modify: `scripts/RunStats.gd` (paid_out flag)
- Modify: `scripts/GameOver.gd:66-74` (set flag)
- Modify: `scripts/PauseMenu.gd:153-159` (payout on quit/restart)

**Interfaces:**
- Consumes: `CoinReward.payout(wave, bosses, kills)` (pure static), autoloads `DifficultyManager`/`RunStats`/`SaveManager`/`Inventory`, `RunConfig` unused here.
- Produces: `GameConfig.QUIT_PAYOUT_FRAC: float`; `RunStats.paid_out: bool` (reset with the run; guards double payout).

- [ ] **Step 1: GameConfig const** — after `COIN_PER_KILL` (line 127):
```gdscript
const QUIT_PAYOUT_FRAC := 0.75  # quit/restart from pause pays this fraction of the death payout
```

- [ ] **Step 2: RunStats flag** — add with the other vars and reset it:
```gdscript
var paid_out := false    # this run's payout already granted (death OR quit) — no double dipping
```
and in `reset()` add `paid_out = false`.

- [ ] **Step 3: GameOver sets the flag**

In `GameOver._on_player_died` (line 68, before `SaveManager.add_coins(earned)`), add:
```gdscript
	if RunStats.paid_out:
		return
	RunStats.paid_out = true
```

- [ ] **Step 4: PauseMenu payout**

Replace lines 153-159 with:
```gdscript
## Abandoning a run (restart or quit) still pays — at QUIT_PAYOUT_FRAC of the death
## payout — and still counts as a played game, so mobile interruptions aren't punished.
## Mirrors GameOver._on_player_died; RunStats.paid_out guards double payment.
func _abandon_run_payout() -> void:
	if RunStats.paid_out:
		return
	RunStats.paid_out = true
	var wave := DifficultyManager.wave
	var bosses := RunStats.bosses_killed
	var earned := int((CoinReward.payout(wave, bosses, RunStats.kills) + RunStats.bonus_coins) * GameConfig.QUIT_PAYOUT_FRAC)
	SaveManager.add_coins(earned)
	SaveManager.record_run(wave, bosses)
	SaveManager.add_game_played()
	SaveManager.save_game()
	Inventory.add_run_xp(RunStats.kills + wave * 10 + bosses * 50)

func _on_restart() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	_abandon_run_payout()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
```
(Weapon XP intentionally pays FULL — only coins take the 75% haircut; death stays the optimal exit.)

- [ ] **Step 5: Parse gate.** Expected: clean. (No headless probe — autoload/scene behavior; covered by the phone checklist.)

- [ ] **Step 6: Commit**

```bash
git add scripts/logic/GameConfig.gd scripts/RunStats.gd scripts/GameOver.gd scripts/PauseMenu.gd
git commit -m "feat(economy): quitting/restarting a run pays 75% coins + counts toward the 10-game reward"
```

---

### Task 7: Elite XP — gem value scales with spawn HP

**Files:**
- Modify: `scripts/logic/GameConfig.gd` (new const after XP_GEM_VALUE :94)
- Modify: `scripts/Enemy.gd:268-273` (_drop_gem)

**Interfaces:**
- Consumes: `XpGem.value` (existing var, granted via `_player.add_xp(value)`); `Enemy.max_health` (baked at configure, includes wave growth × type hp_mult).
- Produces: `GameConfig.XP_GEM_VALUE_MAX: int`.

- [ ] **Step 1: GameConfig const** — after line 94:
```gdscript
const XP_GEM_VALUE_MAX := 15          # cap on hp-scaled gem value (elite/late kills pay more)
```

- [ ] **Step 2: Scale the drop**

Replace `_drop_gem` (lines 268-273):
```gdscript
func _drop_gem() -> void:
	if xp_gem_scene == null:
		return
	var gem = xp_gem_scene.instantiate()
	# Elite/late kills pay proportionally: gem value scales with this enemy's baked
	# max HP over the wave-1 base (capped), so killing the big thing beats runner-farming.
	gem.value = clampi(roundi(max_health / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
	get_tree().current_scene.add_child(gem)
	gem.global_position = global_position
```
(Bosses keep 30 × value-1 gems — BossBase._reward is untouched.)

- [ ] **Step 3: Parse gate.** Expected: clean.

- [ ] **Step 4: Leveling-pace sanity probe**

Append to `probe_balance.gd`:
```gdscript
	# Task 7: gem values at checkpoints (shambler hp_mult 1.0, brute 2.2)
	for w3 in [1, 11, 21]:
		var hp_s := float(DifficultyCurve.enemy_stats(w3)["max_health"])
		var gv_s := clampi(roundi(hp_s / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
		var gv_b := clampi(roundi(hp_s * 2.2 / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
		print("wave %d gem value: shambler %d  brute %d" % [w3, gv_s, gv_b])
	var gv1 := clampi(roundi(float(DifficultyCurve.enemy_stats(1)["max_health"]) / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
	if gv1 != 1:
		print("FAIL wave-1 gem value changed: ", gv1); fails += 1
```
Run. Expected: table printed, wave-1 shambler = 1, `PROBE OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/logic/GameConfig.gd scripts/Enemy.gd
git commit -m "feat(balance): XP gem value scales with enemy HP (cap 15) — elites worth killing"
```

---

### Task 8: Final gate, cleanup, review, ship

**Files:**
- Delete: `probe_balance.gd`, `probe_balance.gd.uid`

- [ ] **Step 1: Full probe + parse run** — run `probe_balance.gd` one last time (all sections), expect `PROBE OK`; then the parse gate, expect clean.

- [ ] **Step 2: Delete the probe**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f probe_balance.gd probe_balance.gd.uid
```

- [ ] **Step 3: Whole-branch review** — dispatch a code reviewer over `git diff master...feat/balance-pass-v1` against the spec (`docs/superpowers/specs/2026-07-04-balance-pass-v1-design.md`). Fix anything real, re-run the gates.

- [ ] **Step 4: Merge + push**

```bash
git checkout master && git merge --ff-only feat/balance-pass-v1 && git push origin master
```
CI builds the APK (~1.5 min); note the run number N → version `0.1.<N>`.

- [ ] **Step 5: Changelog + release (after CI is green)**

Add a CHANGELOG.md entry (player-facing, newest-first) covering: gentler late-game ramp, tougher late bosses (smaller heal), enemy specials scale late, 6-gun tuning pass, guaranteed affix signature stats, 50/50 700c + category floors + Specials Case crate, quit pays 75%, elite XP. Commit with `[skip ci]`. Then:
```bash
git tag v0.1.<N> <merge-commit> && git push origin v0.1.<N>
gh release create v0.1.<N> <downloaded android-latest apk> --title "v0.1.<N> — Balance Pass v1" --notes-file <notes>
```

- [ ] **Step 6: Phone F5 checklist for Larry** (paste into the handoff)
1. Late run (min 8+): swarm noticeably survivable vs before; wave-15+ boss is a real spike; boss kill heals ~1/3, not full.
2. Wave 12+ spitter/exploder hits hurt more than wave-2 ones.
3. Grenade Launcher vs a lone boss: visibly better TTK. Sniper shots pierce 3 targets. LMG reload is a real pause. Flamethrower: enemies keep melting ~3s after the cone sweeps off. Acid pools melt slower than before but shells hit the same.
4. Pull a few purples: every "Brutal/Heavy" purple has its multishot, every "Hollow" its pierce.
5. Store: 50/50 at 700; category crates never pay a gray; new Specials Case (bolt icon) sells Tesla/Flame/Acid, Salvaged+.
6. Quit a run from pause: coins granted (~75%), games-played ticks (check the 10-game reward progress).
7. Big kills drop fat gems late — leveling keeps pace past minute 8 (if it firehoses, lower `XP_GEM_VALUE_MAX`).

---

## Self-review notes (spec coverage)

- Spec §1 → Task 1 · §2 → Task 1 · §3 → Task 2 · §4 → Task 3 · §5 → Task 4 · §6 → Tasks 5+6 · §7 → Task 7 · Verification plan → probe steps in Tasks 1-7 + Task 8 gate. No save migration anywhere (new keys via `.get()`, prices/consts only).
- Known intentional side effects (documented in-task): Boss Rush bosses past #10 also late-ramp (Task 1); weapon XP pays full on quit while coins take the haircut (Task 6).

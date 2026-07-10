# Pack A: Employee Benefits (v0.1.62) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permanent meta-progression: a new SCRAP currency (byproduct of weapon deconstruction) funds 9 flat benefit tracks (HP/speed/XP/cash/rerolls/dash/coins/salvage/revive) bought on a new BENEFITS hub page and applied at run start.

**Architecture:** Pure `Benefits.gd` registry (tracks/costs/effects) + `scrap`/`benefits` save keys; one byproduct hook in `Inventory.deconstruct`; one run-start application pass in `Main.gd`; a revive intercept in `Player.take_damage` ahead of Second Wind; a REROLL button on `LevelUpUI`; a BENEFITS page in `MainMenu`.

**Tech Stack:** Godot 4.6 GDScript, game repo `/mnt/c/Users/thela/Documents/mobile-game`.

**Spec:** `docs/superpowers/specs/2026-07-09-roadmap-4-design.md` §Pack A (approved; scrap = ADDITIVE byproduct, coins payout untouched).

## Global Constraints

- Runner env / probe runner / dual gate: identical to prior packs —
  ```bash
  GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'
  ```
  Probes are BOOT SCENES (`_probe.gd` extends Node + `_probe.tscn`, `timeout 25 "$GODOT" --path "$PROJ" --headless res://_probe.tscn`), never `--script`. MANDATORY DUAL GATE per task, both print 0:
  ```bash
  "$GODOT" --path "$PROJ" --headless --editor --quit 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"
  timeout 25 "$GODOT" --path "$PROJ" --headless res://scenes/Main.tscn 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"
  ```
  Probe AND both gates are non-negotiable. Delete probe files + `.uid` sidecars before committing. Commit on master, do NOT push before the ship task. Line numbers approximate — anchor on quoted code.
- Track ids and values are FIXED (spec): `insurance` +4 max HP/lvl cap 5 · `comfy_shoes` +2% move/lvl cap 5 · `night_school` +3% xp/lvl cap 5 · `signing_bonus` +50 run-coins/lvl cap 5 · `second_opinion` +1 reroll/lvl cap 3 · `stretch_breaks` −4% dash CD/lvl cap 5 · `register_skim` +2% coins/lvl cap 5 · `pack_rat` +10% scrap-from-deconstruct/lvl cap 5 · `union_rep` revive ×1 @50% HP + 2s invuln, cap 1.
- Costs per level: `[25, 60, 140, 320, 700]` scrap; `union_rep` flat `1500`.
- Scrap byproduct: `maxi(1, payout / 10)` before PACK RAT; coins payout is byte-identical to today.
- HARDCORE: `union_rep` is a NO-OP (`RunConfig.hardcore`); `insurance` joins the spawn baseline via `Player.grant_base_max_health` (deliberately not heal-gated — same adjudicated rule as Ryan's bonus, Player.gd:398-403).
- Every tunable in `GameConfig` with a `##` comment: `BENEFIT_COSTS := [25, 60, 140, 320, 700]`, `BENEFIT_REVIVE_COST := 1500`, `BENEFIT_REVIVE_HEAL_FRAC := 0.5`, `BENEFIT_REVIVE_INVULN := 2.0`, plus per-track per-level magnitudes as listed above (`BENEFIT_HP_PER_LVL := 4.0`, `BENEFIT_SPEED_PER_LVL := 0.02`, `BENEFIT_XP_PER_LVL := 0.03`, `BENEFIT_CASH_PER_LVL := 50`, `BENEFIT_DASH_CD_PER_LVL := 0.04`, `BENEFIT_COIN_PER_LVL := 0.02`, `BENEFIT_SCRAP_PER_LVL := 0.10`).

---

### Task 1: `Benefits.gd` + save plumbing

**Files:**
- Create: `scripts/logic/Benefits.gd`
- Modify: `scripts/SaveManager.gd` (DEFAULTS dict line ~12, accessors near `add_coins` line ~131)
- Modify: `scripts/logic/GameConfig.gd` (new BENEFITS block)

**Interfaces:**
- Produces: `Benefits.TRACKS: Array[Dictionary]` (ordered rows `{id, name, flavor, cap}`), `Benefits.cost(id: String, next_level: int) -> int` (-1 if capped/unknown), `Benefits.cap(id) -> int`, `Benefits.level(id) -> int` (reads save), `Benefits.try_buy(id) -> bool` (spends scrap + persists + returns success), and effect getters used verbatim by Tasks 2-4: `Benefits.hp_bonus() -> float`, `speed_mult() -> float` (1.0 + n·0.02), `xp_mult() -> float`, `start_cash() -> int`, `reroll_charges() -> int`, `dash_cd_mult() -> float` (1.0 − n·0.04), `coin_mult() -> float`, `scrap_mult() -> float` (1.0 + n·0.10), `has_revive() -> bool`.
- SaveManager: `scrap() -> int`, `add_scrap(n: int)`, `spend_scrap(n: int) -> bool` (false if short), `benefit_level(id: String) -> int`, `set_benefit_level(id: String, lvl: int)` — DEFAULTS gains `"scrap": 0` and `"benefits": {}`.

- [ ] **Step 1: Failing probe** — `_probe.gd` (boot scene):

```gdscript
extends Node
func _ready() -> void:
	var fails := 0
	if Benefits.TRACKS.size() != 9:
		fails += 1; print("PROBE FAIL track count %d" % Benefits.TRACKS.size())
	for t in Benefits.TRACKS:
		for k in ["id", "name", "flavor", "cap"]:
			if not t.has(k):
				fails += 1; print("PROBE FAIL track %s missing %s" % [str(t.get("id", "?")), k])
	if Benefits.cost("insurance", 1) != 25 or Benefits.cost("insurance", 5) != 700:
		fails += 1; print("PROBE FAIL insurance cost ladder")
	if Benefits.cost("insurance", 6) != -1:
		fails += 1; print("PROBE FAIL over-cap cost not -1")
	if Benefits.cost("union_rep", 1) != 1500 or Benefits.cost("union_rep", 2) != -1:
		fails += 1; print("PROBE FAIL union_rep cost/cap")
	if Benefits.cost("nonexistent", 1) != -1:
		fails += 1; print("PROBE FAIL unknown track cost not -1")
	# effect math at level 0 (fresh save) then simulated levels via SaveManager
	if Benefits.speed_mult() != 1.0 or Benefits.hp_bonus() != 0.0 or Benefits.has_revive():
		fails += 1; print("PROBE FAIL non-neutral effects at level 0")
	SaveManager.set_benefit_level("insurance", 3)
	SaveManager.set_benefit_level("comfy_shoes", 5)
	SaveManager.set_benefit_level("union_rep", 1)
	if absf(Benefits.hp_bonus() - 12.0) > 0.01:
		fails += 1; print("PROBE FAIL hp_bonus %f" % Benefits.hp_bonus())
	if absf(Benefits.speed_mult() - 1.10) > 0.001:
		fails += 1; print("PROBE FAIL speed_mult %f" % Benefits.speed_mult())
	if not Benefits.has_revive():
		fails += 1; print("PROBE FAIL revive not detected")
	# scrap wallet
	SaveManager.add_scrap(100)
	if SaveManager.scrap() < 100:
		fails += 1; print("PROBE FAIL add_scrap")
	if SaveManager.spend_scrap(999999):
		fails += 1; print("PROBE FAIL overspend allowed")
	var before := SaveManager.scrap()
	if not SaveManager.spend_scrap(50) or SaveManager.scrap() != before - 50:
		fails += 1; print("PROBE FAIL spend_scrap")
	# try_buy end-to-end: fund exactly one insurance level 4 (cost 320)
	SaveManager.add_scrap(320 - SaveManager.scrap() if SaveManager.scrap() < 320 else 0)
	var lvl_before := Benefits.level("insurance")
	if lvl_before == 3 and Benefits.try_buy("insurance") and Benefits.level("insurance") != 4:
		fails += 1; print("PROBE FAIL try_buy did not level")
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	get_tree().quit(fails)
```
NOTE: the probe mutates the real save file's `benefits`/`scrap` keys. FIRST verify how SaveManager persists (grep `save_game\|user://savegame`) and back up + restore `user://savegame.json` around the probe run if it exists on this machine (`%APPDATA%` path irrelevant — headless uses the project-local `user://` under the Windows appdata of the exe; simplest: snapshot `SaveManager._data` in-probe and restore + `save_game()` at the end of `_ready`). Report which protection you used.

- [ ] **Step 2: Run — expect FAIL** (Benefits not defined).
- [ ] **Step 3: Implement.** `scripts/logic/GameConfig.gd` — new block after the RANK consts:

```gdscript
# --- EMPLOYEE BENEFITS (roadmap-4 Pack A, v0.1.62) ---
const BENEFIT_COSTS := [25, 60, 140, 320, 700]  # scrap cost for level 1..5 of every 5-cap track
const BENEFIT_REVIVE_COST := 1500        # UNION REP single level
const BENEFIT_REVIVE_HEAL_FRAC := 0.5    # revive restores this fraction of max HP
const BENEFIT_REVIVE_INVULN := 2.0       # seconds of post-revive invulnerability
const BENEFIT_HP_PER_LVL := 4.0          # INSURANCE: flat max HP per level (spawn baseline)
const BENEFIT_SPEED_PER_LVL := 0.02      # COMFY SHOES: move-speed fraction per level
const BENEFIT_XP_PER_LVL := 0.03         # NIGHT SCHOOL: xp-gain fraction per level
const BENEFIT_CASH_PER_LVL := 50         # SIGNING BONUS: run-start coins per level
const BENEFIT_DASH_CD_PER_LVL := 0.04    # STRETCH BREAKS: dash-cooldown cut per level
const BENEFIT_COIN_PER_LVL := 0.02       # REGISTER SKIM: coin-gain fraction per level
const BENEFIT_SCRAP_PER_LVL := 0.10      # PACK RAT: extra scrap from deconstructs per level
```

`scripts/SaveManager.gd` — DEFAULTS gains two keys (after `"weapons": []`):

```gdscript
	"scrap": 0,               # EMPLOYEE BENEFITS currency — byproduct of deconstructs (Pack A)
	"benefits": {},           # benefit track id -> purchased level (Pack A)
```

and accessors next to `add_coins` (mirror its shape exactly, including the save-on-mutate behavior you observe there — if `add_coins` does NOT call `save_game()` itself, don't either; match the file's idiom):

```gdscript
func scrap() -> int:
	return int(_data.get("scrap", 0))

func add_scrap(amount: int) -> void:
	_data["scrap"] = scrap() + maxi(amount, 0)

## False (and no mutation) when the wallet is short.
func spend_scrap(amount: int) -> bool:
	if amount > scrap():
		return false
	_data["scrap"] = scrap() - amount
	return true

func benefit_level(id: String) -> int:
	var b: Dictionary = _data.get("benefits", {})
	return int(b.get(id, 0))

func set_benefit_level(id: String, lvl: int) -> void:
	var b: Dictionary = _data.get("benefits", {})
	b[id] = lvl
	_data["benefits"] = b
```

`scripts/logic/Benefits.gd`:

```gdscript
class_name Benefits
## EMPLOYEE BENEFITS (roadmap-4 Pack A): permanent scrap-funded flat tracks. Pure logic —
## costs, caps, and effect math live here; SaveManager holds the wallet + levels; Main.gd
## applies the effects once at run start. RNG/rarity untouched by design (flat QoL only).

const TRACKS := [
	{ "id": "insurance",      "name": "INSURANCE",      "flavor": "the plan covers bites now. mostly.",        "cap": 5 },
	{ "id": "comfy_shoes",    "name": "COMFY SHOES",    "flavor": "non-slip. blood-resistant. regulation.",     "cap": 5 },
	{ "id": "night_school",   "name": "NIGHT SCHOOL",   "flavor": "learn on the job. faster.",                  "cap": 5 },
	{ "id": "signing_bonus",  "name": "SIGNING BONUS",  "flavor": "a little something up front.",               "cap": 5 },
	{ "id": "second_opinion", "name": "SECOND OPINION", "flavor": "don't like the options? ask again.",         "cap": 3 },
	{ "id": "stretch_breaks", "name": "STRETCH BREAKS", "flavor": "five minutes. your legs will thank you.",    "cap": 5 },
	{ "id": "register_skim",  "name": "REGISTER SKIM",  "flavor": "we round in your favor now.",                "cap": 5 },
	{ "id": "pack_rat",       "name": "PACK RAT",       "flavor": "the back room remembers everything.",        "cap": 5 },
	{ "id": "union_rep",      "name": "UNION REP",      "flavor": "one call. one favor. once.",                 "cap": 1 },
]

static func _track(id: String) -> Dictionary:
	for t in TRACKS:
		if String(t["id"]) == id:
			return t
	return {}

static func cap(id: String) -> int:
	return int(_track(id).get("cap", 0))

## Scrap cost of buying `next_level` (1-based) of a track; -1 = unknown track or over cap.
static func cost(id: String, next_level: int) -> int:
	var t := _track(id)
	if t.is_empty() or next_level < 1 or next_level > int(t["cap"]):
		return -1
	if id == "union_rep":
		return GameConfig.BENEFIT_REVIVE_COST
	return int(GameConfig.BENEFIT_COSTS[next_level - 1])

static func level(id: String) -> int:
	return mini(SaveManager.benefit_level(id), cap(id))

## Buys the next level if affordable; persists via SaveManager. False = capped or short.
static func try_buy(id: String) -> bool:
	var next := level(id) + 1
	var c := cost(id, next)
	if c < 0 or not SaveManager.spend_scrap(c):
		return false
	SaveManager.set_benefit_level(id, next)
	SaveManager.save_game()
	return true

# --- effect getters (the ONLY read points gameplay uses) ---
static func hp_bonus() -> float:
	return level("insurance") * GameConfig.BENEFIT_HP_PER_LVL

static func speed_mult() -> float:
	return 1.0 + level("comfy_shoes") * GameConfig.BENEFIT_SPEED_PER_LVL

static func xp_mult() -> float:
	return 1.0 + level("night_school") * GameConfig.BENEFIT_XP_PER_LVL

static func start_cash() -> int:
	return level("signing_bonus") * GameConfig.BENEFIT_CASH_PER_LVL

static func reroll_charges() -> int:
	return level("second_opinion")

static func dash_cd_mult() -> float:
	return 1.0 - level("stretch_breaks") * GameConfig.BENEFIT_DASH_CD_PER_LVL

static func coin_mult() -> float:
	return 1.0 + level("register_skim") * GameConfig.BENEFIT_COIN_PER_LVL

static func scrap_mult() -> float:
	return 1.0 + level("pack_rat") * GameConfig.BENEFIT_SCRAP_PER_LVL

static func has_revive() -> bool:
	return level("union_rep") >= 1
```

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/logic/Benefits.gd scripts/SaveManager.gd scripts/logic/GameConfig.gd && git commit -m "feat(benefits): Benefits.gd tracks/costs/effects + scrap wallet save keys"
```

---

### Task 2: Scrap byproduct on deconstruct

**Files:**
- Modify: `scripts/loot/Inventory.gd` (deconstruct payout, lines ~97-106)
- Modify: the weapon detail popup that emits `scrap_confirmed` (find it: `grep -rn "scrap_confirmed" scripts/` — wired in MainMenu.gd:450) — add a "+N SCRAP" line to whatever result feedback the scrap flow already shows (match the existing coin-payout feedback idiom you find there; if the popup shows no payout feedback at all today, add the scrap amount to the popup's confirm-button label instead — report which).

**Interfaces:**
- Consumes: `SaveManager.add_scrap`, `Benefits.scrap_mult()` (Task 1).
- Produces: `Inventory.deconstruct` returns/behaves as today for coins, plus banks scrap; expose the banked amount to the UI the same way the coin payout is exposed (extend the existing return/signal — read the function's full body first and mirror).

- [ ] **Step 1: Failing probe** — `_probe.gd` (boot scene; snapshot + restore `SaveManager._data` around mutations as in Task 1):

```gdscript
extends Node
func _ready() -> void:
	var fails := 0
	# seed a known weapon then deconstruct it; scrap must be ceil-safe: maxi(1, payout/10) * pack_rat
	SaveManager.set_benefit_level("pack_rat", 0)
	var list: Array = SaveManager.get_weapons() if SaveManager.has_method("get_weapons") else []
	# build a minimal rarity-1 instance the way LootRoller stores them — verify the dict shape
	# first (grep '"uid"' scripts/loot/LootRoller.gd) and adjust keys if needed:
	var inst := { "uid": "probe_w1", "base": "pistol", "rarity": 1 }
	list.append(inst)
	SaveManager.set_weapons(list)
	var scrap_before := SaveManager.scrap()
	Inventory.deconstruct("probe_w1")
	var gained := SaveManager.scrap() - scrap_before
	# rarity-1 scrap band is [10,20] -> coins payout 10..20 -> scrap 1..2
	if gained < 1 or gained > 2:
		fails += 1; print("PROBE FAIL scrap gained %d (want 1..2)" % gained)
	# pack rat multiplies: level 5 = x1.5
	SaveManager.set_benefit_level("pack_rat", 5)
	list = SaveManager.get_weapons()
	list.append({ "uid": "probe_w2", "base": "pistol", "rarity": 1 })
	SaveManager.set_weapons(list)
	scrap_before = SaveManager.scrap()
	Inventory.deconstruct("probe_w2")
	gained = SaveManager.scrap() - scrap_before
	if gained < 1 or gained > 3:   # roundi((1..2)*1.5) = 2..3, allow 1 if impl floors
		fails += 1; print("PROBE FAIL pack-rat scrap %d" % gained)
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	get_tree().quit(fails)
```
Adjust the instance-dict keys to the real weapon shape you verified; if `Inventory.deconstruct` looks up by a different key than `uid`, adapt the probe (not the game code).

- [ ] **Step 2: Run — expect FAIL** (no scrap banked).
- [ ] **Step 3: Implement.** In `Inventory.deconstruct`, directly after `SaveManager.add_coins(payout)` (line ~103):

```gdscript
	# EMPLOYEE BENEFITS (Pack A): deconstructs also bank SCRAP — an ADDITIVE byproduct, the
	# coins payout above is untouched. PACK RAT multiplies the byproduct only.
	var scrap_gain := roundi(maxi(1, payout / 10) * Benefits.scrap_mult())
	SaveManager.add_scrap(scrap_gain)
```
Then surface `scrap_gain` in the popup feedback per the Files note (mirror the coin idiom; report the route).

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add -A scripts/ && git commit -m "feat(benefits): deconstructs bank scrap (+N SCRAP feedback), PACK RAT bonus"
```

---

### Task 3: Run-start effects + UNION REP revive

**Files:**
- Modify: `scripts/Main.gd` (run-start block where `RunConfig.hardcore` applies `HARDCORE_COIN_MULT`, line ~24-27)
- Modify: `scripts/Player.gd` (death path line ~294 where Second Wind intercepts; dash construction line ~24; `xp_mult` var line ~43)

**Interfaces:**
- Consumes: all `Benefits.*` effect getters (Task 1 signatures).
- Produces: gameplay effects; no downstream task consumes code from this one.

- [ ] **Step 1: Failing probe** — `_probe.gd`: pure-math assertions only (full run-boot integration is covered by the boot gate + F5): after `SaveManager.set_benefit_level` seeding (insurance 5 / comfy_shoes 5 / night_school 5 / stretch_breaks 5 / register_skim 5 / union_rep 1, snapshot-restored), assert `Benefits.hp_bonus()==20.0`, `speed_mult()==1.10`, `xp_mult()==1.15`, `dash_cd_mult()==0.80`, `coin_mult()==1.10`, `has_revive()`. PLUS: instantiate `Player` scene OFF-TREE is unsafe (textures/children) — instead grep-verify in the probe is impossible; the revive path gets its own pure helper: assert `Player.revive_order_note` exists? NO — keep it simple: the probe asserts the Benefits math; the revive wiring is verified by reading the diff in review + boot gate + F5. State this explicitly in your report.
- [ ] **Step 2: Run — expect FAIL only if Task 1 seeds are wrong; if it passes immediately, note that this task's probe is math-only and proceed** (the real deliverable is wiring, gated by review).
- [ ] **Step 3: Implement — run-start pass.** In `Main.gd`, extend the existing run-start block (after the `RunConfig.hardcore` coin-mult lines ~24-27):

```gdscript
	# EMPLOYEE BENEFITS (Pack A): permanent tracks applied once per run, all through existing
	# chokepoints. Multiplies the SAME RunStats.coin_mult hardcore already touches above.
	RunStats.coin_mult *= Benefits.coin_mult()
	RunStats.bonus_coins += Benefits.start_cash()   # SIGNING BONUS — pays out on the stub like any coins
```
VERIFY FIRST: `RunStats` autoload path + that `bonus_coins` exists and flows into `CoinReward` payout (grep `bonus_coins` — v0.1.4x hazard-crate coins used it). If `bonus_coins` doesn't exist or means something else, seed starting cash via the same mechanism hazard crates use — report the route.
Player-side effects belong wherever the player is configured at spawn — find the spot that already calls `grant_base_max_health` for Ryan (Characters.gd:61 caller) and add, for EVERY character (outside the Ryan branch, same configuration pass):

```gdscript
	# EMPLOYEE BENEFITS (Pack A): INSURANCE joins the spawn baseline (same adjudicated
	# hardcore-exempt rule as Ryan's bonus — see grant_base_max_health's doc), the rest are
	# plain run-start multipliers.
	if Benefits.hp_bonus() > 0.0:
		player.grant_base_max_health(Benefits.hp_bonus())
	player.move_speed *= Benefits.speed_mult()
	player.xp_mult *= Benefits.xp_mult()
```
(Verify `move_speed` is the live var the Player's `_physics_process` reads — Player.gd:112 — and that Characters.gd's configuration runs before first physics tick.)
Dash cooldown: in `Player.gd`, the dash is built at line ~24 `DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN)`. Read `scripts/logic/DashState.gd` (or wherever DashState lives) for the cooldown field/param and apply `GameConfig.DASH_COOLDOWN * Benefits.dash_cd_mult()` at construction — since `_dash` is built at field-init time (before Benefits could differ per-run? Benefits is save-backed and static — fine at init). If DashState's cooldown is a constructor arg, change the init line to:

```gdscript
var _dash := DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN * Benefits.dash_cd_mult())
```

- [ ] **Step 4: Implement — UNION REP revive.** In `Player.gd`'s death path (line ~294), the existing shape is:

```gdscript
		if has_second_wind and not second_wind_used:
			second_wind_used = true
			...
```
Insert the revive intercept BEFORE it (spec: UNION REP fires first), same pattern:

```gdscript
		# UNION REP (Pack A): the benefits revive fires BEFORE Second Wind (spec order) and
		# never in HARDCORE (one-life identity — same flag the heal-gate uses).
		if _union_rep_available and not RunConfig.hardcore:
			_union_rep_available = false
			_health.current = maxf(1.0, max_hp() * GameConfig.BENEFIT_REVIVE_HEAL_FRAC)
			_grant_invuln(GameConfig.BENEFIT_REVIVE_INVULN)
			return
```
with `var _union_rep_available := Benefits.has_revive()` initialized at spawn-config time (NOT field init — set it in the same configuration pass as the other effects so a save bought mid-session applies next run predictably), and `_grant_invuln` = whatever the existing spawn-protection/invulnerability mechanism is (grep `invuln\|spawn_protect\|_protect` in Player.gd — REUSE it; if the field is a bare timer var, set it directly and note the name). Verify the death path's exact structure — if Second Wind's block heals via a different route (e.g. `heal()`), do NOT copy it blindly: `heal()` is a no-op in HARDCORE but union rep is already hardcore-gated; setting `_health.current` directly bypasses the heal-gate deliberately (revive ≠ heal), matching how Second Wind must already work — confirm and report.
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/Main.gd scripts/Player.gd scripts/logic/Characters.gd && git commit -m "feat(benefits): run-start effect pass + UNION REP revive ahead of Second Wind"
```
(Adjust the `git add` list to the files you actually touched — e.g. if the spawn pass lives elsewhere.)

---

### Task 4: SECOND OPINION — level-up card reroll

**Files:**
- Modify: `scripts/LevelUpUI.gd` (card offer build; read the whole file first — it pauses the game and offers 3 cards, odd=player/even=gun)

**Interfaces:**
- Consumes: `Benefits.reroll_charges()` (Task 1).
- Produces: none downstream.

- [ ] **Step 1: Read `LevelUpUI.gd` fully.** Identify: (a) where the 3 cards are drawn for an offer (the function that picks from `Upgrades.player_cards`/gun cards), (b) how buttons are laid out, (c) any state that must reset between queued level-ups.
- [ ] **Step 2: Implement.** Add `var _rerolls_left := 0`, set `_rerolls_left = Benefits.reroll_charges()` ONCE per run (wherever the UI is created/reset at run start — not per level-up). Add a REROLL button under the card row, PixelTheme-styled like the existing card buttons but half-height, label `REROLL (%d)` — visible only when `_rerolls_left > 0`. Pressed: `_rerolls_left -= 1`, redraw the SAME offer type (re-run the same pick function for the current level's parity, excluding nothing new — a redraw may repeat cards, that's the gamble), refresh buttons. The button hides at 0 charges. Charges are PER RUN (not per level-up, not persisted mid-run).
- [ ] **Step 3: Probe** — pure part only: `Benefits.reroll_charges()` returns the seeded level (0→0, 3→3) with snapshot-restore; note in the report that the button behavior is review+F5 territory (LevelUpUI needs a live run).
- [ ] **Step 4: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/LevelUpUI.gd && git commit -m "feat(benefits): SECOND OPINION reroll button on the level-up offer"
```

---

### Task 5: BENEFITS hub page

**Files:**
- Modify: `scripts/MainMenu.gd` (hub button row lines ~178-181; new page section — study `_show_records`/`_populate_store` and the drag-scroll idiom lines ~52-60 first)

**Interfaces:**
- Consumes: `Benefits.TRACKS/cost/level/cap/try_buy`, `SaveManager.scrap()` (Task 1).
- Produces: none downstream.

- [ ] **Step 1: Read the RECORDS + STORE page builders and the shared drag-scroll/`_guarded` machinery.** The new page must reuse: `_make_button` for nav, the title idiom (`_make_title(vbox, "BENEFITS", 44)`), the ScrollContainer + drag-anywhere scroll (register the new scroll the way `_store_scroll` was added in v0.1.28 — `_input` resolves the active scroll), and `_guarded()` on all buy buttons.
- [ ] **Step 2: Implement.** Hub: `vbox.add_child(_make_button("BENEFITS", func(): _show_benefits()))` inserted between the STORE and RECORDS lines (~178-181). Page: title, `SCRAP: %d` balance line (ACCENT, size 26, refreshed after every purchase), then one row per `Benefits.TRACKS` entry: NAME (ACCENT, 22) + flavor line (ACCENT.darkened(0.45), 16 — the readable-dim idiom from Pack 0) + level pips `●●●○○` (filled = owned, ACCENT/ACCENT_DIM) + a buy button: `label = "%d SCRAP" % cost` or `"MAXED"` (disabled) — pressed → `if Benefits.try_buy(id): SoundManager.play("purchase")` + refresh the row + balance, else `SoundManager.play("ui_tap")` (verify the store's exact deny/afford sound names and mirror). BACK button returns to the hub (mirror `_show_records`' back wiring).
- [ ] **Step 3: Probe** — data-level: every TRACKS row renders from real data (`cost(id, level+1)` is -1 only when `level == cap`); with a seeded wallet of 25, `try_buy("insurance")` succeeds once then fails broke (snapshot-restore the save around it). UI layout itself = review+F5.
- [ ] **Step 4: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/MainMenu.gd && git commit -m "feat(benefits): BENEFITS hub page — scrap balance, 9 tracks, pips, buy flow"
```

---

### Task 6: Ship v0.1.62 (controller task)

- [ ] **Step 1:** Fable whole-branch review (base = the v0.1.61 ship commit `c7af2e0`), one fix dispatch for Critical/Important + triage of accumulated Minors.
- [ ] **Step 2:** `VERSION` → `0.1.62`; CHANGELOG:

```markdown
## v0.1.62 — The Benefits Package (2026-07-09)

You're a valued employee now. Valued employees get BENEFITS:
- NEW: the BENEFITS page — spend SCRAP on nine permanent perks: more health, faster shoes, night school, a signing bonus, dash training, a skim off the register, and one very expensive favor from the UNION REP (he gets you back up. once. not in HARDCORE.)
- NEW: SCRAP — every weapon you deconstruct now also banks scrap on top of the usual coins. PACK RAT makes the pile grow faster.
- NEW: SECOND OPINION — reroll the level-up cards you didn't ask for (charges per run).
```

- [ ] **Step 3:** Commit + push, watch CI green, confirm android-latest says 0.1.62, tag `v0.1.62`, `gh release create` with the APK.
- [ ] **Step 4:** Ledger + memory. F5 checklist: scrap toast on deconstruct; benefits page buys/pips/balance; run starts with +HP/+speed visible; signing bonus on the stub; reroll button appears with charges and burns down; UNION REP revive fires before Second Wind, absent in HARDCORE; hardcore max-HP baseline intact.

## Self-review notes (applied)

- Spec §Pack A coverage: currency (T1 wallet + T2 byproduct), 9 tracks + revive (T1 data, T3 effects, T4 reroll UI), BENEFITS page (T5), Hardcore rules (T3), feedback line (T2), no respec (nothing built).
- Uncertainty is delegated explicitly (RunStats.bonus_coins route, DashState field, invuln mechanism, popup feedback idiom, sound names) with verify-first instructions and report-back requirements — no silent guessing.
- Type consistency: getter names in T1 match every consumer in T2-T5.
- Save-file safety: every probe that mutates save state snapshots and restores `SaveManager._data`.

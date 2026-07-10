# Pack 0: Lore Flavor Pack (v0.1.61) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Voice everywhere — boss intro one-liners, death-screen quips, rank promotion blurbs, STAFF MEMOs on the daily popup, and a punch-up of the 18 commendation descriptions. Text only, no new UI containers.

**Architecture:** One new pure registry `scripts/logic/Flavor.gd` holds every line; five existing surfaces read from it. Missing id → `""` → surface hides/skips, never crashes.

**Tech Stack:** Godot 4.6 GDScript, game repo `/mnt/c/Users/thela/Documents/mobile-game`.

**Spec:** `docs/superpowers/specs/2026-07-09-roadmap-4-design.md` §Pack 0 (approved).

## Global Constraints

- Runner env (all tasks):
  ```bash
  GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'
  ```
- **PROBE RUNNER:** boot-scene style — `_probe.gd` (`extends Node`, assertions in `_ready()`, `get_tree().quit(fails)`) + minimal `_probe.tscn`; run `timeout 25 "$GODOT" --path "$PROJ" --headless res://_probe.tscn`. NEVER `--script` (autoloads absent). Delete `_probe.gd`/`_probe.tscn`/`*.uid` sidecars before committing.
- **MANDATORY DUAL GATE per task**, both print 0:
  ```bash
  "$GODOT" --path "$PROJ" --headless --editor --quit 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"
  timeout 25 "$GODOT" --path "$PROJ" --headless res://scenes/Main.tscn 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"
  ```
- **Every flavor line ≤ 70 characters** (phone width). Lowercase deadpan is the voice (existing UI headers stay UPPERCASE; flavor lines are lowercase except MEMO: prefix and proper nouns).
- Commit on master, do NOT push until the ship task. Plan line numbers are approximate — anchor on quoted code text.

---

### Task 1: `Flavor.gd` registry + all content

**Files:**
- Create: `scripts/logic/Flavor.gd`

**Interfaces:**
- Produces: `Flavor.boss_line(id: String) -> String` ("" if unknown), `Flavor.death_quip() -> String` (random), `Flavor.rank_blurb(rank: int) -> String` ("" out of range), `Flavor.staff_memo() -> String` (random). Tasks 2-3 call exactly these.

- [ ] **Step 1: Failing probe** — `_probe.gd` body (boot-scene runner per Global Constraints):

```gdscript
extends Node
func _ready() -> void:
	var fails := 0
	# full boss coverage — this id list must match Bosses._LIST (probe cross-checks the size)
	if Bosses.count() != 9:
		fails += 1; print("PROBE FAIL boss roster is %d, id list below assumes 9 — update both" % Bosses.count())
	for id in ["brute","brood_mother","heat_tyrant","manager","night_stocker","fryer","courier","karen","tanker"]:
		if Flavor.boss_line(id) == "":
			fails += 1; print("PROBE FAIL no boss line for %s" % id)
	if Flavor.boss_line("nonexistent") != "":
		fails += 1; print("PROBE FAIL unknown boss id not empty")
	# every line everywhere <= 70 chars, none empty
	for l in Flavor.BOSS_LINES.values() + Flavor.DEATH_QUIPS + Flavor.RANK_BLURBS + Flavor.STAFF_MEMOS:
		if String(l).length() > 70:
			fails += 1; print("PROBE FAIL >70 chars: %s" % l)
		if String(l).strip_edges() == "":
			fails += 1; print("PROBE FAIL empty line")
	# REPLACE the 10 below with the REAL ladder size after running:
	#   grep -n "TIERS\|RANKS\|name_for" scripts/logic/Ranks.gd
	# (count the ladder entries; if it is not 10, the RANK_BLURBS list in Task 1 Step 3 must be
	# re-authored to that size — report NEEDS_CONTEXT, do not pad)
	if Flavor.RANK_BLURBS.size() != 10:
		fails += 1; print("PROBE FAIL rank blurb count %d != rank ladder size" % Flavor.RANK_BLURBS.size())
	if Flavor.rank_blurb(-1) != "" or Flavor.rank_blurb(99) != "":
		fails += 1; print("PROBE FAIL out-of-range rank blurb not empty")
	if Flavor.death_quip() == "" or Flavor.staff_memo() == "":
		fails += 1; print("PROBE FAIL random getters empty")
	print("PROBE PASS" if fails == 0 else "PROBE FAIL total %d" % fails)
	get_tree().quit(fails)
```
NOTE: before finalizing the probe, `grep -n "TIERS\|COUNT\|size" scripts/logic/Ranks.gd` and assert the blurb count against the ladder's REAL size expression (replace the `if "COUNT" in Ranks` guess with the actual API; hard-fail if you can't find it).

- [ ] **Step 2: Run — expect FAIL** (Flavor not defined).
- [ ] **Step 3: Implement** `scripts/logic/Flavor.gd` (content verbatim):

```gdscript
class_name Flavor
## Every piece of ambient voice in one pure registry (roadmap-4 Pack 0). Surfaces read via
## the getters; a missing id returns "" and the surface hides itself — flavor can never
## crash gameplay. All lines <= 70 chars (phone width). Lowercase deadpan is the voice.

const BOSS_LINES := {
	"brute": "big guy from aisle 5. he was like this before.",
	"brood_mother": "she's not on the schedule. her kids are.",
	"heat_tyrant": "the AC guy never came. this is what happened.",
	"manager": "he never clocked out. now he never will.",
	"night_stocker": "restocking since the incident. don't block the aisles.",
	"fryer": "the fryer station is technically still operational.",
	"courier": "signature required. he will collect it.",
	"karen": "she asked for corporate. corporate is dead.",
	"tanker": "pump 3 called for a refill. he's still delivering.",
}

const DEATH_QUIPS := [
	"your shift has been covered.",
	"cleanup on every aisle.",
	"you are no longer eligible for the health plan.",
	"break room's open. permanently.",
	"your name tag will be reissued.",
	"clocking you out. someone had to.",
	"the night shift always finds staff.",
	"leave the vest. they always leave the vest.",
	"corporate has been notified. nobody answered.",
	"the coffee was still warm.",
	"employee of the month is posthumous this month.",
	"the register doesn't count itself. well. it does now.",
]

## Indexed by rank (0 = TRAINEE ... 9 = FRANCHISE OWNER) — size must match the Ranks ladder.
const RANK_BLURBS := [
	"you get a vest. the vest does nothing.",
	"you may now run the register unsupervised. congratulations?",
	"keys to the ice machine. guard them.",
	"you've unlocked the horde. that's not a benefit.",
	"someone has to order more shells. it's you now.",
	"overtime approved. sleep is not.",
	"you know where the mop is. you know where everything is.",
	"hardcore clearance. the insurance no longer applies.",
	"you basically run this place. it shows.",
	"it's yours now. all of it. even the basement.",
]

const STAFF_MEMOS := [
	"MEMO: the walk-in stays CLOSED after 2AM.",
	"MEMO: do not refund the dead. no exceptions.",
	"MEMO: pump 3 is fine. stop reporting pump 3.",
	"MEMO: if the manager speaks to you, you didn't hear it.",
	"MEMO: the mop is not a weapon. update: the mop is a weapon.",
	"MEMO: night shift differential remains $0.25/hr.",
	"MEMO: the freezer hum is normal. the freezer voice is not.",
	"MEMO: the slushie machine is self-cleaning. leave it alone.",
	"MEMO: report all bites to HR. HR reports to no one.",
	"MEMO: dawn deliveries resume when dawn does.",
	"MEMO: employee discount does not apply to ammunition.",
	"MEMO: the corkboard is for APPROVED notices only.",
	"MEMO: lost & found is full. stop finding things.",
	"MEMO: smile. customers can tell.",
]

static func boss_line(id: String) -> String:
	return String(BOSS_LINES.get(id, ""))

static func death_quip() -> String:
	return DEATH_QUIPS[randi() % DEATH_QUIPS.size()]

static func rank_blurb(rank: int) -> String:
	if rank < 0 or rank >= RANK_BLURBS.size():
		return ""
	return RANK_BLURBS[rank]

static func staff_memo() -> String:
	return STAFF_MEMOS[randi() % STAFF_MEMOS.size()]
```

If the Ranks ladder size is NOT 10 (Step 1 grep), STOP and report NEEDS_CONTEXT — the blurb list must be authored to the real size, not padded.

- [ ] **Step 4: Run probe — expect `PROBE PASS`.**
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/logic/Flavor.gd && git commit -m "feat(flavor): Flavor.gd — boss lines, death quips, rank blurbs, staff memos"
```

---

### Task 2: Wire boss intros + death quips

**Files:**
- Modify: `scripts/Hud.gd` (boss-name/SHIFT CHANGE area — `_boss_name_label` near line 10/98, the SHIFT CHANGE toast edge-detect near line 11/25)
- Modify: `scripts/GameOver.gd` (pay-stub build around `_stub_vbox` line ~263, helper `_centered_line` line ~109)

**Interfaces:**
- Consumes: `Flavor.boss_line(id)`, `Flavor.death_quip()` (Task 1).
- Produces: nothing downstream.

- [ ] **Step 1: Read the two wire sites.** In `Hud.gd`, find where the SHIFT CHANGE toast fires (`_boss_was_alive` edge-detect, `_show_banner`) and where the boss display name is resolved (`Bosses.name_for(...)` or equivalent — grep `name_for` in Hud.gd; the boss node's `boss_id()` is available from the "boss" group member). In `GameOver.gd`, find the end of the stub build (after the "Clocked out" line region).
- [ ] **Step 2: Implement boss intro.** Where the boss name becomes visible for a NEW boss (the same edge the SHIFT CHANGE toast uses), append the flavor line as a NEW small Label directly under `_boss_name_label` (same anchors, offset one line height, `PixelTheme` dim color, font size ~14, `visible = line != ""`):

```gdscript
	var line := Flavor.boss_line(id)   # id = the boss's boss_id() the name lookup already uses
	_boss_flavor_label.text = line
	_boss_flavor_label.visible = line != ""
```

with `_boss_flavor_label` built next to `_boss_name_label` in the HUD constructor (copy its anchor block, shift `offset_top`/`offset_bottom` down by ~22px, `add_theme_font_size_override("font_size", 14)`, `add_theme_color_override("font_color", PixelTheme.ACCENT_DIM)`). Clear it (`visible = false`) wherever `_boss_name_label` is hidden/cleared.
If the label geometry collides with the HP bar (eyeball via a boot run is impossible headless — judge from the anchor offsets you read), prefer appending the line to the SHIFT CHANGE banner text instead (`_show_banner("SHIFT CHANGE — %s" % name)` becomes two banner lines) and say which route you took in your report.
- [ ] **Step 3: Implement death quip.** At the very bottom of the stub build (after the last existing `_centered_line`/row), only when the run ended in DEATH (not an extraction win — find the win flag the stub already branches on for its WIN/SHIFT'S OVER header and reuse it):

```gdscript
	if not won:   # match the actual variable name found in Step 1
		_centered_line(_stub_vbox, "\"%s\"" % Flavor.death_quip(), PixelTheme.ACCENT_DIM, 16)
```

- [ ] **Step 4: Probe** — boot-scene probe asserting: `Flavor.boss_line("karen") != ""` (registry reachable from game code) and — layout-independent — that Hud.gd parses with the new label member (the dual gate covers compile; assert `Flavor.death_quip().length() <= 70` ×20 draws for random stability). Run: PASS.
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/Hud.gd scripts/GameOver.gd && git commit -m "feat(flavor): boss intro line under the boss bar + death quip on the pay-stub"
```

---

### Task 3: Promotion blurbs + STAFF MEMO + commendation punch-up

**Files:**
- Modify: `scripts/MainMenu.gd` (PROMOTED reward-queue entry near line 1124, daily-login reward popup near line 77)
- Modify: `scripts/GameOver.gd` (PROMOTED stub line near line 258-306)
- Modify: `scripts/logic/Commendations.gd` (the 18 `"desc"` strings in the data table, lines ~34+)
- Possibly modify: `scripts/ui/RewardPopup.gd` (if the memo line needs a new optional label — check its build first)

**Interfaces:**
- Consumes: `Flavor.rank_blurb(rank)`, `Flavor.staff_memo()` (Task 1).

- [ ] **Step 1: Wire promotion blurbs.** GameOver: the `★ PROMOTED: <rank name> ★` `_centered_line` (line ~306) gets a second line under it: `_centered_line(_stub_vbox, Flavor.rank_blurb(rank_after), PixelTheme.ACCENT_DIM, 16)` guarded on `!= ""` (verify `rank_after` is the reached rank INDEX — if it's a name string, find the index the popup already has). MainMenu: the `{"title": "PROMOTED!", ...}` reward descriptor (line ~1124) gains the blurb — read `_promotion_reward()` / RewardPopup to find where descriptor text renders and add the blurb line there, guarded on `!= ""`.
- [ ] **Step 2: Wire STAFF MEMO.** The daily-login reward popup (`_reward_popup`, shown on entry line ~77): add one memo line (`Flavor.staff_memo()`, dim, small, bottom of the popup content) so it shows on the DAILY claim popup specifically — if RewardPopup is shared by other reward types, gate it: memo only when the popup is showing the daily-login reward (find the discriminator in the descriptor dict; report what you keyed on).
- [ ] **Step 3: Punch up the 18 commendation descs in place.** Rules: keep the earning criterion unambiguous (numbers stay), ≤ 70 chars, add the voice. Six worked examples — match this register for the other twelve:
  - `"Finish your first shift."` → `"Finish your first shift. everyone remembers their first."`
  - `"Finish 10 shifts."` → `"Finish 10 shifts. it's a habit now."`
  - `"Finish 100 shifts."` → `"Finish 100 shifts. this is your life."`
  - `"Kill 2,500 zombies (lifetime)."` → `"2,500 lifetime kills. pest control was cheaper."`
  - `"Kill 25,000 zombies (lifetime)."` → `"25,000 lifetime kills. the town is mostly you now."`
  - `"Pull an Armageddon."` (or actual golden_ticket desc) → `"Pull an Armageddon. molten gold. 1-in-362,880."`
- [ ] **Step 4: Probe** — boot-scene probe: every Commendations desc ≤ 70 chars and non-empty; every desc still contains its number where the original had one (hardcode the id→required-substring pairs for the numeric ones you edited, e.g. `{"punching_in": "10", "career_clerk": "100", "exterminator": "2,500", "genocide_shift": "25,000"}` extended to all numeric descs you find); `Flavor.rank_blurb(0) != ""`. Run: PASS.
- [ ] **Step 5: rm probe files, BOTH gates (0/0), commit:**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && rm -f _probe.gd _probe.tscn *.uid && git add scripts/MainMenu.gd scripts/GameOver.gd scripts/logic/Commendations.gd scripts/ui/RewardPopup.gd 2>/dev/null; git add scripts/MainMenu.gd scripts/GameOver.gd scripts/logic/Commendations.gd; git commit -m "feat(flavor): promotion blurbs, daily STAFF MEMO, commendation desc punch-up"
```

---

### Task 4: Ship v0.1.61 (controller task)

- [ ] **Step 1:** Fable whole-branch review of the pack range (afa9e2e-era ship base = the v0.1.60 ship commit `bfd5a41`.. HEAD); fix anything Critical/Important via one fix dispatch.
- [ ] **Step 2:** Bump `VERSION` to `0.1.61`. CHANGELOG entry:

```markdown
## v0.1.61 — Voices from the Corkboard (2026-07-09)

The store found its voice:
- Every boss now gets an intro line under their name. THE MANAGER never clocked out.
- The pay-stub has opinions about your death.
- Promotions come with a word from corporate. So do daily logins — read the STAFF MEMOs.
- All 18 commendations rewritten with the respect they deserve (which varies).
```

- [ ] **Step 3:** Commit (VERSION + CHANGELOG + any review fixes), push, watch the run green, confirm android-latest body says 0.1.61, tag `v0.1.61` at the pushed commit, `gh release create v0.1.61` with the APK + notes.
- [ ] **Step 4:** Ledger + memory update.

## Self-review notes (applied)

- Spec §Pack 0 coverage: 5 surfaces ↔ T2 (boss, death), T3 (promo, memo, commendations); registry + coverage probe T1; ≤70-char rule enforced in T1/T3 probes; "missing id shows nothing" via `""` getters + `visible` guards.
- The two genuinely-uncertain layout points (boss flavor label geometry; RewardPopup memo gating) are delegated with explicit decision rules + report-back requirements rather than fake certainty.
- Type consistency: `boss_line/death_quip/rank_blurb/staff_memo` used identically in T2/T3.

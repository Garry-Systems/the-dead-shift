# Weapon Inspection Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the inventory's weapon-tile detail popup show the gun's real stats and a full talent breakdown (with level/XP), instead of two terse summary lines.

**Architecture:** Add pure, stateless display helpers to `WeaponInstance` (the instance dict stays the source of truth) that resolve real stat values — mirroring `Gun.gd`'s exact `upgrade_*` math — plus filled talent effect text and XP progress. Then rewrite `WeaponDetailPopup._rebuild()` to render title → subtitle → XP bar → scrollable STATS section → TALENTS section → the unchanged action row. The popup's public API (`open(inst, is_equipped)` + `equip_requested`/`scrap_confirmed`/`closed` signals) is unchanged, so `MainMenu` needs no edits.

**Tech Stack:** Godot 4.6 (.NET edition exe, GDScript), `PixelTheme` UI kit, strict 4-color palette ([[reference_survivor_palette]]).

**Branch note:** The repo is currently on `feat/boss-framework` with uncommitted title/gas-station WIP. Confirm the target branch with Larry before the first commit (likely a fresh `feat/weapon-inspect` branch). All commits below assume the chosen branch.

**Verification model:** This project has no GUT suite — Larry F5s in Godot, and logic is checked headless. Two tools (runnable from WSL):
- **Compile gate:** `"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --editor --quit`
- **Logic probe:** `"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --script res://probe_weapon_inspect.gd` (class_name globals like `WeaponInstance` are available in `--script` mode; autoloads are not — the probe uses only class_name globals). If the run reports the script class isn't found, re-run with `--editor --script` added.
- The only expected/benign error line in headless output is the `menu_background.jpg` JPEG-decode warning — filter it out when grepping.

---

## File Structure

- **Modify** `scripts/loot/WeaponInstance.gd` — add `xp_progress`, `full_stats`, `talent_details`, and small private formatter helpers. Leave the existing terse `stat_summary` / `talent_summary` intact (still used by the `WeaponTile` hover tooltip).
- **Modify** `scripts/ui/WeaponDetailPopup.gd` — rewrite `_rebuild()` and add section-builder helpers. Keep `_ready`, `open`, `_build_action_row`, `_show_scrap_confirm`, `_close` behavior.
- **Temporary** `probe_weapon_inspect.gd` (repo root, `res://`) — throwaway logic probe; deleted before the final commit, never committed.

---

## Task 1: Pure display helpers in `WeaponInstance`

**Files:**
- Modify: `scripts/loot/WeaponInstance.gd`
- Probe: `probe_weapon_inspect.gd` (repo root)

- [ ] **Step 1: Write the failing probe**

Create `probe_weapon_inspect.gd` at the repo root:

```gdscript
# Throwaway logic probe for the weapon inspection helpers. NOT committed.
extends SceneTree

func _init() -> void:
	# A known Hardened AK-47 at level 7: one active talent (killshot, unlock 3) and one
	# still-locked (venom, unlock 14). Rolls fixed at 0.5 so values are deterministic.
	var inst := {
		"uid": "test", "base": "ak47", "affix": "hardened", "rarity": 3,
		"level": 7, "xp": 120,
		"stats": { "damage": 0.5, "fire_rate": 0.5, "mag": 0.5 },
		"talents": [
			{ "id": "killshot", "unlock_level": 3, "rolls": [0.5, 0.5] },
			{ "id": "venom", "unlock_level": 14, "rolls": [0.5, 0.5, 0.5] },
		],
	}
	print("XP: ", WeaponInstance.xp_progress(inst))
	print("STATS:")
	for r in WeaponInstance.full_stats(inst):
		print("  %s = %s  %s" % [r.label, r.value, r.bonus])
	print("TALENTS:")
	for t in WeaponInstance.talent_details(inst):
		print("  %s | locked=%s lv=%d | %s" % [t.name, t.locked, t.unlock_level, t.effect])
	quit()
```

- [ ] **Step 2: Run the probe to verify it fails**

Run:
```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --script res://probe_weapon_inspect.gd 2>&1 | grep -vi "menu_background"
```
Expected: FAIL — a parse/runtime error that `xp_progress` / `full_stats` / `talent_details` are not declared in `WeaponInstance`.

- [ ] **Step 3: Add the helpers to `WeaponInstance.gd`**

Append these to `scripts/loot/WeaponInstance.gd` (after the existing `icon` function, before end of file):

```gdscript
## Level/XP progress for the inspection popup. needed = level*100 (the Inventory curve in
## Inventory.add_run_xp); frac is 0..1 toward the next level (0 when needed is 0).
static func xp_progress(inst: Dictionary) -> Dictionary:
	var lvl := int(inst.get("level", 1))
	var xp := int(inst.get("xp", 0))
	var needed := lvl * 100
	var frac: float = (float(xp) / float(needed)) if needed > 0 else 0.0
	return { "level": lvl, "xp": xp, "needed": needed, "frac": clampf(frac, 0.0, 1.0) }

## Ordered display rows of the gun's REAL stats = base Weapons def + rolled affix bonuses,
## computed with the SAME formulas Gun.apply_loot/upgrade_* use so the popup matches in-run
## behavior. Each row: { label, value, bonus } — bonus is "" when no affix rolled that stat.
## Character perks / in-run upgrade cards are intentionally excluded: this is the weapon's
## intrinsic profile (what you compare between drops).
static func full_stats(inst: Dictionary) -> Array:
	var base := _base_def(inst)
	if base.is_empty():
		return []
	var s := resolved_stats(inst)   # only rolled stats present; % as e.g. 11.0, flat as ints

	var damage: float = float(base["damage"]) * (1.0 + _pct(s, "damage"))
	var interval: float = float(base["fire_interval"]) * (1.0 - _pct(s, "fire_rate"))
	var rate: float = (1.0 / interval) if interval > 0.0 else 0.0
	var rng: float = float(base["range"]) * (1.0 + _pct(s, "range"))
	var reload: float = float(base["reload_time"]) * (1.0 - _pct(s, "reload"))
	var mag: int = int(ceil(float(base["mag_size"]) * (1.0 + _pct(s, "mag"))))
	var bspeed: float = float(base["bullet_speed"]) * (1.0 + _pct(s, "bullet_speed"))
	var shots: int = int(base["projectiles"]) + int(s.get("multishot", 0))
	var pierce: int = int(s.get("pierce", 0))
	var ricochet: int = int(s.get("ricochet", 0))

	var rows: Array = []
	rows.append({ "label": "DAMAGE", "value": str(roundi(damage)), "bonus": _pct_bonus(s, "damage") })
	rows.append({ "label": "FIRE RATE", "value": "%.1f/s" % rate, "bonus": _pct_bonus(s, "fire_rate") })
	rows.append({ "label": "RANGE", "value": str(roundi(rng)), "bonus": _pct_bonus(s, "range") })
	rows.append({ "label": "RELOAD", "value": "%.1fs" % reload, "bonus": _pct_bonus(s, "reload") })
	rows.append({ "label": "MAGAZINE", "value": str(mag), "bonus": _pct_bonus(s, "mag") })
	# Conditional rows: shown only when relevant, so the block stays clean but never hides a
	# rolled bonus (bullet_speed/multishot/pierce/ricochet only roll on higher rarities).
	if s.has("bullet_speed"):
		rows.append({ "label": "BULLET SPD", "value": str(roundi(bspeed)), "bonus": _pct_bonus(s, "bullet_speed") })
	if shots > 1:
		rows.append({ "label": "MULTISHOT", "value": str(shots), "bonus": _flat_bonus(s, "multishot") })
	if pierce > 0:
		rows.append({ "label": "PIERCE", "value": str(pierce), "bonus": _flat_bonus(s, "pierce") })
	if ricochet > 0:
		rows.append({ "label": "RICOCHET", "value": str(ricochet), "bonus": _flat_bonus(s, "ricochet") })
	return rows

## Detailed talent rows for the popup. Each: { name, color, effect, locked, unlock_level }.
## `effect` = the catalog desc filled with this instance's resolved rolled values. `color` is
## the catalog hint (returned for completeness) — the UI colors active vs locked itself (C4 /
## C3) to honor the locked 4-color palette.
static func talent_details(inst: Dictionary) -> Array:
	var lvl := int(inst.get("level", 1))
	var out: Array = []
	for t in inst.get("talents", []):
		var def := Talents.get_talent(String(t.get("id", "")))
		if def.is_empty():
			continue
		var unlock := int(t.get("unlock_level", 0))
		out.append({
			"name": String(def["name"]),
			"color": def.get("color", Color.WHITE),
			"effect": _talent_effect(def, t.get("rolls", [])),
			"locked": unlock > lvl,
			"unlock_level": unlock,
		})
	return out

# --- private formatters for the inspection helpers ---

# 0..1 multiplier from a resolved percent stat (e.g. 11.0 -> 0.11); 0 if the stat wasn't rolled.
static func _pct(stats: Dictionary, id: String) -> float:
	return float(stats.get(id, 0.0)) / 100.0

# "+11%" for a rolled percent stat, "" if not rolled.
static func _pct_bonus(stats: Dictionary, id: String) -> String:
	if not stats.has(id):
		return ""
	return "+%d%%" % roundi(float(stats[id]))

# "+2" for a rolled flat stat, "" if not rolled.
static func _flat_bonus(stats: Dictionary, id: String) -> String:
	if not stats.has(id):
		return ""
	return "+%d" % int(stats[id])

# Fill a talent's desc format string with its resolved rolled mod values.
static func _talent_effect(def: Dictionary, rolls: Array) -> String:
	var mods: Array = def.get("mods", [])
	var vals: Array = []
	for i in mods.size():
		var roll: float = float(rolls[i]) if i < rolls.size() else 0.0
		vals.append(_fmt_num(Talents.resolve(def, i, roll)))
	return String(def.get("desc", "")) % vals

# Round to int for whole-ish or large values; one decimal for small fractionals (e.g. 2.4s).
static func _fmt_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05 or absf(v) >= 10.0:
		return str(roundi(v))
	return "%.1f" % v
```

- [ ] **Step 4: Run the probe to verify it passes**

Run:
```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --script res://probe_weapon_inspect.gd 2>&1 | grep -vi "menu_background"
```
Expected: PASS — output resembling:
```
XP: { "level": 7, "xp": 120, "needed": 700, "frac": 0.1714... }
STATS:
  DAMAGE = 24  +11%
  FIRE RATE = 9.2/s  +9%
  RANGE = 650
  RELOAD = 1.7s
  MAGAZINE = 34  +12%
TALENTS:
  Killshot | locked=false lv=3 | 13% chance to crit for +60% damage
  Venom | locked=true lv=14 | 40% chance to poison: 16 dmg/s for 4s (stacks)
```
(Exact numbers may differ slightly by rounding; the shape, the `locked` flags, and that bonuses appear only on rolled stats are what matter.)

- [ ] **Step 5: Commit**

```bash
git add scripts/loot/WeaponInstance.gd
git commit -m "$(cat <<'EOF'
Weapon inspect: pure stat/talent/XP display helpers

full_stats mirrors Gun.upgrade_* math for real values; talent_details fills
each desc with resolved rolls + locked flag; xp_progress reads the level*100 curve.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Rewrite `WeaponDetailPopup._rebuild()` to render the detailed view

**Files:**
- Modify: `scripts/ui/WeaponDetailPopup.gd`

- [ ] **Step 1: Add the two new member vars**

In `scripts/ui/WeaponDetailPopup.gd`, find the member declarations near the top:

```gdscript
var _inst: Dictionary
var _is_equipped := false
var _card_vbox: VBoxContainer
var _action_row: Control
var _confirm_row: Control
```

Add two lines after `_confirm_row`:

```gdscript
var _scroll: ScrollContainer
var _inner: VBoxContainer
```

- [ ] **Step 2: Replace `_rebuild()` with the sectioned layout**

Replace the entire existing `_rebuild()` function (currently builds title + one stats line + one talent line + action row) with:

```gdscript
func _rebuild() -> void:
	for c in _card_vbox.get_children():
		c.queue_free()

	# Title — weapon name, rarity-colored (the one kept color exception).
	var title := Label.new()
	title.text = WeaponInstance.display_name(_inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 24)
	title.add_theme_color_override("font_color", WeaponInstance.color(_inst))
	_card_vbox.add_child(title)

	# Subtitle — rarity name · level.
	var sub := Label.new()
	sub.text = "%s  ·  Level %d" % [WeaponInstance.rarity_name(_inst), int(_inst.get("level", 1))]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(sub, 14, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(sub)

	# XP bar.
	_card_vbox.add_child(_build_xp_row())

	# Scrollable stats + talents (so a max-roll weapon can't overflow the card).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner = VBoxContainer.new()
	_inner.add_theme_constant_override("separation", 12)
	_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_inner)
	_build_stats_section(_inner)
	_build_talents_section(_inner)
	_card_vbox.add_child(_scroll)
	_fit_scroll()   # cap scroll height to content (deferred a frame for layout)

	# Actions (unchanged behavior).
	_action_row = _build_action_row()
	_card_vbox.add_child(_action_row)
```

- [ ] **Step 3: Add the section-builder helpers**

Add these new functions to `scripts/ui/WeaponDetailPopup.gd` (place them right after `_rebuild()`):

```gdscript
# Sizes the scroll region to its content, capped at half the viewport height so short cards
# don't pad and tall ones scroll. Deferred one frame so child labels have reported min sizes.
func _fit_scroll() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_scroll) or not is_instance_valid(_inner):
		return
	var cap: float = get_viewport_rect().size.y * 0.5
	_scroll.custom_minimum_size.y = minf(_inner.get_combined_minimum_size().y + 4.0, cap)

func _build_xp_row() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prog := WeaponInstance.xp_progress(_inst)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = maxf(1.0, float(prog.needed))
	bar.value = float(prog.xp)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	box.add_child(bar)
	var lbl := Label.new()
	lbl.text = "%d / %d XP" % [int(prog.xp), int(prog.needed)]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(lbl, 12, PixelTheme.TEXT_DIM)
	box.add_child(lbl)
	return box

func _build_stats_section(parent: VBoxContainer) -> void:
	parent.add_child(_section_header("STATS"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in WeaponInstance.full_stats(_inst):
		var name_l := Label.new()
		name_l.text = String(row.label)
		PixelTheme.style_label(name_l, 14, PixelTheme.TEXT_DIM)
		grid.add_child(name_l)
		var val_l := Label.new()
		val_l.text = String(row.value)
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelTheme.style_label(val_l, 14, PixelTheme.TEXT)
		grid.add_child(val_l)
		var bonus_l := Label.new()
		bonus_l.text = String(row.bonus)
		bonus_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelTheme.style_label(bonus_l, 13, PixelTheme.SELECT)
		grid.add_child(bonus_l)
	parent.add_child(grid)

func _build_talents_section(parent: VBoxContainer) -> void:
	var talents := WeaponInstance.talent_details(_inst)
	if talents.is_empty():
		return
	parent.add_child(_section_header("TALENTS"))
	for t in talents:
		var locked: bool = bool(t.locked)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var nm := Label.new()
		var suffix: String = ("  (LOCKED — LV%d)" % int(t.unlock_level)) if locked else ""
		nm.text = String(t.name).to_upper() + suffix
		PixelTheme.style_label(nm, 14, PixelTheme.TEXT_DIM if locked else PixelTheme.ACCENT)
		row.add_child(nm)
		var eff := Label.new()
		eff.text = String(t.effect)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.custom_minimum_size = Vector2(440, 0)
		PixelTheme.style_label(eff, 12, PixelTheme.TEXT_DIM)
		row.add_child(eff)
		parent.add_child(row)

func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	PixelTheme.style_label(l, 13, PixelTheme.SELECT)
	return l
```

- [ ] **Step 4: Run the compile gate**

Run:
```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --editor --quit 2>&1 | grep -iE "error|parse|SCRIPT" | grep -vi "menu_background"
```
Expected: PASS — no output (no parse/script errors). Any line printed here other than a `menu_background.jpg` decode warning is a failure to fix before committing.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/WeaponDetailPopup.gd
git commit -m "$(cat <<'EOF'
Weapon inspect: detailed popup (real stats + talents + level/XP)

Tapping an inventory gun now shows a level/XP bar, a full stat block with real
values + rolled bonuses, and per-talent effect text (locked talents dimmed C3,
active C4 — palette-compliant). Stats+talents scroll; equip/scrap/close unchanged.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Clean up the probe and final gate

**Files:**
- Delete: `probe_weapon_inspect.gd`

- [ ] **Step 1: Delete the throwaway probe**

```bash
rm "/mnt/c/Users/thela/Documents/mobile-game/probe_weapon_inspect.gd"
```
(If Godot generated `probe_weapon_inspect.gd.uid`, remove that too: `rm -f "/mnt/c/Users/thela/Documents/mobile-game/probe_weapon_inspect.gd.uid"`.)

- [ ] **Step 2: Final compile gate**

Run:
```bash
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --path 'C:\Users\thela\Documents\mobile-game' --headless --editor --quit 2>&1 | grep -iE "error|parse|SCRIPT" | grep -vi "menu_background"
```
Expected: PASS — no output.

- [ ] **Step 3: Confirm the probe isn't tracked**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && git status --short | grep probe_weapon_inspect || echo "clean — probe not tracked"
```
Expected: `clean — probe not tracked`.

---

## F5 Smoke Checklist (Larry, in Godot)

- Main menu → INVENTORY → tap several guns of different rarities.
- **Stats:** each shows a real value; a `+N%` / `+N` bonus appears only where an affix rolled that stat (a plain Rusted gun shows mostly bare values).
- **Talents:** active talents show filled effect text in lavender; locked ones are dimmed gray with `(LOCKED — LV N)` and still show their effect. A common weapon with no talents shows **no** TALENTS section.
- **Level/XP:** subtitle reads `Rarity · Level N`; the XP bar fills proportionally with `xp / needed XP` beneath it.
- **Overflow:** a high-rarity weapon (many stats + 3 talents) scrolls inside the card; EQUIP / SCRAP / CLOSE stay pinned and reachable.
- **Regression:** EQUIP equips, SCRAP shows the YES/NO confirm and pays out, CLOSE dismisses — all exactly as before.

---

## Self-Review (completed during planning)

- **Spec coverage:** Full stat block → Task 1 `full_stats` + Task 2 `_build_stats_section`. Talent rows w/ effect + lock → Task 1 `talent_details` + Task 2 `_build_talents_section`. Level + XP bar → Task 1 `xp_progress` + Task 2 `_build_xp_row`. Scroll-to-fit → Task 2 `_fit_scroll`. Edge cases (no talents / locked / no-bonus / overflow / equipped) → covered in the builders + unchanged action row.
- **Placeholder scan:** none — every step has full code or an exact command.
- **Type consistency:** helper names (`full_stats`/`talent_details`/`xp_progress`) and row keys (`label`/`value`/`bonus`; `name`/`color`/`effect`/`locked`/`unlock_level`) match between Task 1 (producer) and Task 2 (consumer). `_scroll`/`_inner` declared in Step 1, used in Steps 2–3.
- **Palette:** active talents C4 (`ACCENT`), locked C3 (`TEXT_DIM`), bonuses/headers C4 (`SELECT`) — no raw talent RGB. Rarity-colored title is the kept exception.

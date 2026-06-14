# Tile Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the MainMenu text-list inventory with a 3-column grid of rarity-colored weapon tiles; tapping a tile opens a detail popup with EQUIP + SCRAP (confirm + payout).

**Architecture:** Two new code-built UI classes (`WeaponTile`, `WeaponDetailPopup`) + small helpers on `WeaponInstance` and `PixelTheme`. `MainMenu` builds the grid and owns the Inventory mutations; the popup only emits intent. Data layer (`Inventory`) is unchanged. Spec: `docs/superpowers/specs/2026-06-13-tile-inventory-design.md`.

**Tech Stack:** Godot 4.6, GDScript. UI built in code (project convention). Placeholder icon art via a stdlib PNG generator.

**Verification convention (project-specific):** No WSL-reachable runtime UI test harness exists, so each task verifies with the **headless compile gate** (catches GDScript parse/type errors) and the feature is smoke-tested by Larry via F5 at the end (GUT unit tests are deferred per project memory).

Headless gate command (referred to below as **[GATE]**):
```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5 2>&1 \
  | grep -iE "SCRIPT ERROR|Parse Error|error|Cannot" | grep -viE "menu_background.jpg|jpe?g" || echo "GATE CLEAN"
```
Expected when clean: `GATE CLEAN` (the only tolerated line is the known `menu_background.jpg` JPEG-decode message, filtered out).

---

## File Structure

- **Create** `scripts/ui/WeaponTile.gd` — one weapon tile (rarity border, icon, name, rarity, EQUIPPED badge); emits `tile_pressed(inst)`.
- **Create** `scripts/ui/WeaponDetailPopup.gd` — modal detail card over a scrim; emits `equip_requested` / `scrap_confirmed` / `closed`.
- **Create** `~/gen_weapon_icons.py` — stdlib PNG generator → `art/weapons/{7 ids}.png` + `_placeholder.png` (temporary glyphs).
- **Modify** `scripts/ui/PixelTheme.gd` — add `style_tile(b, rarity)` + `_tile_box(...)`.
- **Modify** `scripts/loot/WeaponInstance.gd` — add `icon(inst)`.
- **Modify** `scripts/MainMenu.gd` — inventory panel → grid + popup wiring (replace `_build_inventory_panel` body and `_populate_inventory`; add `_on_tile_pressed`, `_on_scrap`, `_detail_popup` member).

---

## Task 1: PixelTheme tile stylebox

**Files:**
- Modify: `scripts/ui/PixelTheme.gd`

- [ ] **Step 1: Add the tile stylebox helpers** (append before the final `style_card` or after it, inside the class)

```gdscript
## A square weapon-tile button: dark fill + a thick rarity-colored border, hover/press states.
static func style_tile(b: Button, rarity: Color) -> void:
	b.add_theme_stylebox_override("normal", _tile_box(BTN_BG, rarity, 4))
	b.add_theme_stylebox_override("hover", _tile_box(BTN_HOVER, rarity.lightened(0.25), 4))
	b.add_theme_stylebox_override("pressed", _tile_box(rarity.darkened(0.35), rarity, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func _tile_box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.set_content_margin_all(6)
	return sb
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/ui/PixelTheme.gd
git commit -m "Tile inventory: add PixelTheme.style_tile (rarity-bordered square)"
```

---

## Task 2: Placeholder weapon icons

**Files:**
- Create: `~/gen_weapon_icons.py`
- Create (generated): `art/weapons/{pistol,smg,shotgun,rifle,minigun,ak47,sniper}.png`, `art/weapons/_placeholder.png`

- [ ] **Step 1: Write the generator** `~/gen_weapon_icons.py`

```python
#!/usr/bin/env python3
# Stdlib-only PNG generator for TEMPORARY weapon-tile placeholder icons.
# 64x64 RGBA, light-gray gun silhouettes on transparent bg. Larry overwrites
# these with real art at the same paths (res://art/weapons/<id>.png).
import zlib, struct, os

W = H = 64
GRAY = (214, 214, 214, 255)
OUT = "/mnt/c/Users/thela/Documents/mobile-game/art/weapons"

def blank():
    return bytearray(W * H * 4)

def rect(px, x, y, w, h, col=GRAY):
    for yy in range(max(0, y), min(H, y + h)):
        for xx in range(max(0, x), min(W, x + w)):
            i = (yy * W + xx) * 4
            px[i:i+4] = bytes(col)

def write_png(path, px):
    def chunk(typ, data):
        return (struct.pack(">I", len(data)) + typ + data
                + struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff))
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        raw += px[y*W*4:(y+1)*W*4]
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    with open(path, "wb") as f:
        f.write(sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b""))

# Each weapon = a list of rects (x, y, w, h) forming a right-pointing silhouette.
GUNS = {
    "pistol":  [(26,28,20,6),(28,30,8,16)],
    "smg":     [(30,27,16,5),(20,26,16,10),(24,36,5,12),(15,28,6,7)],
    "shotgun": [(22,26,30,7),(30,33,12,4),(12,28,12,8)],
    "rifle":   [(26,28,26,4),(16,26,12,10),(8,28,9,8)],
    "minigun": [(28,24,26,3),(28,30,26,3),(28,36,26,3),(16,24,14,16)],
    "ak47":    [(30,27,24,4),(18,26,14,9),(24,34,5,6),(26,39,5,6),(28,44,5,5),(10,28,9,6)],
    "sniper":  [(20,30,34,3),(30,24,14,4),(33,22,4,3),(38,22,4,3),(16,29,8,7),(8,31,9,6)],
}
PLACEHOLDER = [(24,29,26,5),(18,27,10,10),(10,29,9,8)]

def render(rects):
    px = blank()
    for r in rects:
        rect(px, *r)
    return px

def main():
    os.makedirs(OUT, exist_ok=True)
    for wid, rects in GUNS.items():
        write_png(os.path.join(OUT, wid + ".png"), render(rects))
    write_png(os.path.join(OUT, "_placeholder.png"), render(PLACEHOLDER))
    print("wrote", len(GUNS) + 1, "icons to", OUT)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it**

Run: `python3 ~/gen_weapon_icons.py`
Expected: `wrote 8 icons to /mnt/c/Users/thela/Documents/mobile-game/art/weapons`

- [ ] **Step 3: Verify the files exist**

Run: `ls /mnt/c/Users/thela/Documents/mobile-game/art/weapons/`
Expected: `_placeholder.png ak47.png minigun.png pistol.png rifle.png shotgun.png smg.png sniper.png`

- [ ] **Step 4: Commit** (the `.import` files are generated when Larry next opens the editor)

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add art/weapons
git commit -m "Tile inventory: placeholder weapon icons (art/weapons/<id>.png)"
```

---

## Task 3: WeaponInstance.icon() helper

**Files:**
- Modify: `scripts/loot/WeaponInstance.gd`

- [ ] **Step 1: Add the icon helper** (append inside the class, after `base_def`)

```gdscript
## The tile icon for this instance: per-weapon art if present, else the shared placeholder.
static func icon(inst: Dictionary) -> Texture2D:
	var id := String(base_def(inst).get("id", ""))
	var path := "res://art/weapons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://art/weapons/_placeholder.png")
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/loot/WeaponInstance.gd
git commit -m "Tile inventory: WeaponInstance.icon() with per-weapon art + fallback"
```

---

## Task 4: WeaponTile

**Files:**
- Create: `scripts/ui/WeaponTile.gd`

- [ ] **Step 1: Create the tile**

```gdscript
class_name WeaponTile
extends Button
## A square inventory tile for one rolled weapon instance: rarity-colored border (via
## PixelTheme.style_tile), a per-weapon icon, the weapon name + rarity, and an EQUIPPED
## badge. Emits tile_pressed(inst) when tapped. Content overlays the Button as
## mouse-ignoring children so the Button still receives the press. Built in code.

signal tile_pressed(inst: Dictionary)

const TILE_SIZE := Vector2(170, 170)
const ICON_SIZE := Vector2(96, 96)

var _inst: Dictionary

## Builds the tile for an instance. Call once right after instancing.
func setup(inst: Dictionary, is_equipped: bool) -> void:
	_inst = inst
	custom_minimum_size = TILE_SIZE
	clip_contents = true
	text = ""
	PixelTheme.style_tile(self, WeaponInstance.color(inst))
	pressed.connect(func(): tile_pressed.emit(_inst))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = WeaponInstance.icon(inst)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(WeaponInstance.base_def(inst).get("name", "?"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(name_lbl, 15, PixelTheme.TEXT)
	box.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = WeaponInstance.rarity_name(inst)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(rarity_lbl, 11, WeaponInstance.color(inst))
	box.add_child(rarity_lbl)

	if is_equipped:
		_add_equipped_badge()

## A small green "EQ" badge pinned to the top-right corner.
func _add_equipped_badge() -> void:
	var badge_panel := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = PixelTheme.SELECT
	bsb.set_corner_radius_all(0)
	bsb.anti_aliasing = false
	bsb.content_margin_left = 4
	bsb.content_margin_right = 4
	bsb.content_margin_top = 1
	bsb.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", bsb)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Label.new()
	badge.text = "EQ"
	badge.add_theme_font_override("font", PixelTheme.body_font())
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", PixelTheme.DARK)
	badge_panel.add_child(badge)
	add_child(badge_panel)
	# Pin to top-right, growing leftward to its min size.
	badge_panel.anchor_left = 1.0
	badge_panel.anchor_right = 1.0
	badge_panel.anchor_top = 0.0
	badge_panel.anchor_bottom = 0.0
	badge_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge_panel.grow_vertical = Control.GROW_DIRECTION_END
	badge_panel.offset_left = -6
	badge_panel.offset_right = -6
	badge_panel.offset_top = 6
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/ui/WeaponTile.gd
git commit -m "Tile inventory: WeaponTile (rarity border, icon, name, EQ badge)"
```

---

## Task 5: WeaponDetailPopup

**Files:**
- Create: `scripts/ui/WeaponDetailPopup.gd`

- [ ] **Step 1: Create the popup**

```gdscript
class_name WeaponDetailPopup
extends Control
## A modal weapon detail card over a dim scrim. Built once and reused; open(inst, eq)
## rebuilds its contents. Emits intent signals — the owner (MainMenu) performs the
## Inventory mutation and repopulates the grid. SCRAP uses an inline two-step confirm.

signal equip_requested(inst: Dictionary)
signal scrap_confirmed(inst: Dictionary)
signal closed()

var _inst: Dictionary
var _is_equipped := false
var _card_vbox: VBoxContainer
var _action_row: Control
var _confirm_row: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP    # block the grid behind
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	PixelTheme.style_card(card)
	center.add_child(card)
	_card_vbox = VBoxContainer.new()
	_card_vbox.add_theme_constant_override("separation", 14)
	card.add_child(_card_vbox)

func open(inst: Dictionary, is_equipped: bool) -> void:
	_inst = inst
	_is_equipped = is_equipped
	_rebuild()
	visible = true

func _rebuild() -> void:
	for c in _card_vbox.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = WeaponInstance.display_name(_inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 26)
	title.add_theme_color_override("font_color", WeaponInstance.color(_inst))
	_card_vbox.add_child(title)

	var stats := Label.new()
	stats.text = "%s  ·  %s" % [WeaponInstance.rarity_name(_inst), WeaponInstance.stat_summary(_inst)]
	stats.custom_minimum_size = Vector2(500, 0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(stats, 14, PixelTheme.TEXT_DIM)
	_card_vbox.add_child(stats)

	var tsum: String = WeaponInstance.talent_summary(_inst)
	if tsum != "":
		var tlabel := Label.new()
		tlabel.text = "⟡ " + tsum
		tlabel.custom_minimum_size = Vector2(500, 0)
		tlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(tlabel, 13, PixelTheme.ACCENT)
		_card_vbox.add_child(tlabel)

	_action_row = _build_action_row()
	_card_vbox.add_child(_action_row)

func _build_action_row() -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var equip_btn := Button.new()
	equip_btn.text = "EQUIPPED" if _is_equipped else "EQUIP"
	PixelTheme.style_button(equip_btn, Vector2(480, 60), 18)
	equip_btn.disabled = _is_equipped
	equip_btn.pressed.connect(func():
		equip_requested.emit(_inst)
		_close())
	row.add_child(equip_btn)

	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	var scrap_btn := Button.new()
	scrap_btn.text = "SCRAP (%d-%d)" % [int(band[0]), int(band[1])]
	PixelTheme.style_button(scrap_btn, Vector2(480, 56), 16)
	scrap_btn.disabled = _is_equipped
	scrap_btn.add_theme_color_override("font_color", PixelTheme.DANGER)
	scrap_btn.pressed.connect(_show_scrap_confirm)
	row.add_child(scrap_btn)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	PixelTheme.style_button(close_btn, Vector2(480, 56), 16)
	close_btn.pressed.connect(_close)
	row.add_child(close_btn)
	return row

func _show_scrap_confirm() -> void:
	_action_row.visible = false
	var band: Array = Rarity.tier(int(_inst.get("rarity", 1))).scrap
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 10)
	var q := Label.new()
	q.text = "Scrap for %d-%d coins?" % [int(band[0]), int(band[1])]
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(q, 16, PixelTheme.DANGER)
	_confirm_row.add_child(q)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	var yes := Button.new()
	yes.text = "YES"
	PixelTheme.style_button(yes, Vector2(220, 56), 16)
	yes.pressed.connect(func():
		scrap_confirmed.emit(_inst)
		_close())
	hb.add_child(yes)
	var no := Button.new()
	no.text = "NO"
	PixelTheme.style_button(no, Vector2(220, 56), 16)
	no.pressed.connect(func():
		_confirm_row.queue_free()
		_action_row.visible = true)
	hb.add_child(no)
	_confirm_row.add_child(hb)
	_card_vbox.add_child(_confirm_row)

func _close() -> void:
	visible = false
	closed.emit()
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/ui/WeaponDetailPopup.gd
git commit -m "Tile inventory: WeaponDetailPopup (stats + equip/scrap-confirm/close)"
```

---

## Task 6: MainMenu grid + popup wiring

**Files:**
- Modify: `scripts/MainMenu.gd`

- [ ] **Step 1: Add the popup member var** — under the existing member vars (after `var _inv_from_play := false`), add:

```gdscript
var _detail_popup: WeaponDetailPopup   # reused modal for tile taps
```

- [ ] **Step 2: Replace `_build_inventory_panel()`** with:

```gdscript
func _build_inventory_panel() -> void:
	_inv_panel = _make_panel()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inv_panel.add_child(center)

	var card := PanelContainer.new()
	PixelTheme.style_card(card)
	card.custom_minimum_size = Vector2(640, 800)
	center.add_child(card)

	_inv_vbox = VBoxContainer.new()
	_inv_vbox.add_theme_constant_override("separation", 10)
	card.add_child(_inv_vbox)
	# Contents are (re)built on every show by _populate_inventory().

	# Reusable detail popup, layered above the panel content.
	_detail_popup = WeaponDetailPopup.new()
	_inv_panel.add_child(_detail_popup)
	_detail_popup.equip_requested.connect(_on_equip)
	_detail_popup.scrap_confirmed.connect(_on_scrap)
```

- [ ] **Step 3: Replace `_populate_inventory()`** with (swaps the text list for a 3-column tile grid; header + crate row + sort preserved):

```gdscript
func _populate_inventory() -> void:
	for c in _inv_vbox.get_children():
		c.queue_free()

	_make_title(_inv_vbox, "INVENTORY", 28)

	var coins := Label.new()
	coins.text = "COINS: %d" % Inventory.coins()
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(coins, 16, PixelTheme.ACCENT)
	_inv_vbox.add_child(coins)

	if _inv_from_play:
		var prompt := Label.new()
		prompt.text = "Equip a weapon to play"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(prompt, 14, PixelTheme.SELECT)
		_inv_vbox.add_child(prompt)

	# Crate buttons (disabled when you can't afford it / inventory full).
	var crate_row := HBoxContainer.new()
	crate_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crate_row.add_theme_constant_override("separation", 10)
	_inv_vbox.add_child(crate_row)
	for crate in Crates.all():
		var cb := Button.new()
		cb.text = "%s (%d)" % [String(crate["name"]).to_upper(), int(crate["price"])]
		PixelTheme.style_button(cb, Vector2(250, 50), 14)
		cb.disabled = Inventory.coins() < int(crate["price"]) or Inventory.is_full()
		cb.pressed.connect(_on_crate.bind(String(crate["id"])))
		crate_row.add_child(cb)

	# Owned weapons as a tile grid, best rarity first; tap a tile for the detail popup.
	var owned := Inventory.weapons().duplicate()
	owned.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_uid := Inventory.equipped_uid()

	if owned.is_empty():
		var none := Label.new()
		none.text = "No weapons yet — open a crate."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 14, PixelTheme.TEXT_DIM)
		_inv_vbox.add_child(none)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(0, 560)
		_inv_vbox.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		for inst in owned:
			var tile := WeaponTile.new()
			grid.add_child(tile)
			tile.setup(inst, String(inst.get("uid", "")) == equipped_uid)
			tile.tile_pressed.connect(_on_tile_pressed)

	_inv_vbox.add_child(_make_button("CANCEL" if _inv_from_play else "BACK", _on_inv_back))
```

- [ ] **Step 4: Add the two new handlers** (place near `_on_equip`):

```gdscript
func _on_tile_pressed(inst: Dictionary) -> void:
	var is_eq: bool = String(inst.get("uid", "")) == Inventory.equipped_uid()
	_detail_popup.open(inst, is_eq)

func _on_scrap(inst: Dictionary) -> void:
	Inventory.deconstruct(String(inst.get("uid", "")))
	_populate_inventory()
```

- [ ] **Step 5: Delete the old `_on_equip` only if duplicated** — keep the existing `_on_equip(inst)` as-is (the popup's `equip_requested` connects to it; it already handles the `_inv_from_play` → mode-picker flow). Do not re-add it.

- [ ] **Step 6: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 7: Commit**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/MainMenu.gd
git commit -m "Tile inventory: MainMenu grid of tiles + detail-popup wiring"
```

---

## Task 7: Integration gate + F5 smoke handoff

**Files:** none (verification only)

- [ ] **Step 1: Full headless gate** — Run **[GATE]**. Expected: `GATE CLEAN`.

- [ ] **Step 2: Hand off to Larry for F5 smoke test** (Larry opens the editor first so `art/weapons/*.png` import). Checklist:
  1. Menu → INVENTORY → a 3-column grid of rarity-colored tiles (icons = placeholder glyphs), names + rarity, EQ badge on the equipped one.
  2. Tap a tile → detail popup: name (rarity-colored), stat + talent summary, EQUIP / SCRAP / CLOSE.
  3. EQUIP a different weapon → popup closes, EQ badge moves. The equipped tile's popup shows EQUIP + SCRAP disabled.
  4. Open a non-equipped weapon → SCRAP shows `(min-max)` → tap → "Scrap for N-M coins? YES/NO" → YES removes it, coins go up, grid refreshes; NO returns to the buttons.
  5. Buy a crate → a new tile appears; crate buttons disable when broke / inventory full.
  6. From hub with nothing equipped, PLAY → forced into inventory → equip from popup → continues to the mode picker; CANCEL returns to hub.
  7. No errors in Godot output; layout reads at phone width.

---

## Self-Review (completed during planning)
- **Spec coverage:** tile visual w/ icons (T2/T4), tap→popup (T5), equip+scrap-confirm+payout (T5/T6), grid replacing list (T6), `WeaponInstance.icon` (T3), `PixelTheme.style_tile` (T1), PLAY-forced-equip preserved (T6 keeps `_on_equip`), placeholder art + path convention (T2). ✓ all spec sections mapped.
- **Placeholder scan:** no TBD/TODO; every code step is complete. ✓
- **Type consistency:** `tile_pressed`/`equip_requested`/`scrap_confirmed`/`closed` signal names and `setup`/`open` signatures match across T4/T5/T6; `WeaponInstance.icon`/`PixelTheme.style_tile` names match their definitions and call sites. ✓

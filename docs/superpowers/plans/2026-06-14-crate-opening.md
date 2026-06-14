# CS:GO-Style Crate Opening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crates become unopened inventory items; opening one plays a scrolling reel that decelerates onto a pre-rolled weapon under a center reticle (tick sound, settle flash, reveal card), then awards the weapon and consumes the crate.

**Architecture:** New `SaveManager.crates` state + `Inventory.buy_crate`/`commit_crate`; crate tiles in the inventory grid open a full-screen `CrateOpener` whose `_process` loop ports AfterDark's reel math (fast-linear → exponential ease-out → snap). Adds generated crate icons + a generated `tick.wav` audio. Spec: `docs/superpowers/specs/2026-06-14-crate-opening-design.md`.

**Tech Stack:** Godot 4.6, GDScript. UI in code. Branch `feat/crate-opening` (off `test/combined-f5`).

**Verification convention:** headless compile gate per task; a self-restoring save probe for the persistence task; Larry's F5 for the animation/feel.

Headless gate (**[GATE]**):
```bash
cd "/mnt/c/Users/thela/Documents/mobile-game" && \
"/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" \
  --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5 2>&1 \
  | grep -iE "SCRIPT ERROR|Parse Error|error|Cannot" | grep -viE "menu_background.jpg|jpe?g" || echo "GATE CLEAN"
```

---

## File Structure
- **Modify** `scripts/SaveManager.gd` — `crates` save key + API.
- **Modify** `scripts/loot/Inventory.gd` — `buy_crate` + `commit_crate`; remove `open_crate`.
- **Modify** `scripts/loot/Crates.gd` — `icon()`.
- **Modify** `~/gen_palette_sprites.py` — crate-box glyphs. **Create** `~/gen_tick.py` — tick wav.
- **Create** `scripts/ui/CrateTile.gd`, `scripts/ui/CrateOpener.gd`.
- **Create (generated)** `art/crates/{_crate,footlocker,munitions_cache}.png`, `audio/tick.wav`.
- **Modify** `scripts/MainMenu.gd` — grid crate tiles + opener wiring + store `buy_crate`.

---

## Task 1: SaveManager — owned-crates state

**Files:** Modify `scripts/SaveManager.gd`. Temp: `probe_crate.gd`.

- [ ] **Step 1: Add the save key.** In `DEFAULTS`, after the `"unlocked_characters": ["ryan"],` line add:

```gdscript
	"unlocked_characters": ["ryan"],   # character ids the player owns (Ryan free)
	"crates": {},             # owned unopened crates: crate_id -> count
```

- [ ] **Step 2: Add the API.** Insert before `# --- Character unlocks ---`:

```gdscript
# --- Owned crates (unopened) ---

func crates() -> Dictionary:
	return _data.get("crates", {})

func crate_count(id: String) -> int:
	return int(crates().get(id, 0))

func add_crate(id: String) -> void:
	var c: Dictionary = crates()
	c[id] = crate_count(id) + 1
	_data["crates"] = c

func remove_crate(id: String) -> bool:
	if crate_count(id) <= 0:
		return false
	var c: Dictionary = crates()
	var n := crate_count(id) - 1
	if n <= 0:
		c.erase(id)
	else:
		c[id] = n
	_data["crates"] = c
	return true

```

- [ ] **Step 3: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 4: Persistence probe.** Create `probe_crate.gd`:

```gdscript
extends SceneTree
func _init() -> void:
	var path := "user://savegame.json"
	var had := FileAccess.file_exists(path)
	var backup := ""
	if had:
		backup = FileAccess.get_file_as_string(path)
	var SM = load("res://scripts/SaveManager.gd")
	var sm = SM.new()
	sm.load_game()
	sm.add_crate("footlocker")
	sm.add_crate("footlocker")
	sm.save_game()
	var sm2 = SM.new()
	sm2.load_game()
	var persisted = sm2.crate_count("footlocker")
	sm2.remove_crate("footlocker")
	var after_remove = sm2.crate_count("footlocker")
	if had:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		var d := DirAccess.open("user://")
		if d != null and d.file_exists("savegame.json"):
			d.remove("savegame.json")
	print("PROBE persisted=", persisted, " after_remove=", after_remove, " -> ", ("PASS" if persisted == 2 and after_remove == 1 else "FAIL"))
	quit()
```

- [ ] **Step 5: Run the probe.**

Run: `cd "/mnt/c/Users/thela/Documents/mobile-game" && "/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe" --headless --path "C:\Users\thela\Documents\mobile-game" --script res://probe_crate.gd 2>&1 | grep PROBE`
Expected: `PROBE persisted=2 after_remove=1 -> PASS`

- [ ] **Step 6: Delete probe + commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
rm -f probe_crate.gd probe_crate.gd.uid
git add scripts/SaveManager.gd
git commit -m "Crate opening: SaveManager owned-crates state + API"
```

---

## Task 2: Inventory — buy_crate + commit_crate (remove open_crate)

**Files:** Modify `scripts/loot/Inventory.gd`.

- [ ] **Step 1: Replace `open_crate`.** Delete the entire `open_crate` function:

```gdscript
## Buys + opens a crate: spends coins, rolls an instance, adds it. Returns the instance
## (empty dict on failure: unknown crate, not enough coins, or inventory full).
func open_crate(crate_id: String) -> Dictionary:
	var crate := Crates.get_crate(crate_id)
	if crate.is_empty():
		return {}
	if coins() < int(crate["price"]):
		return {}
	if is_full():
		return {}
	if not SaveManager.spend_coins(int(crate["price"])):
		return {}
	var inst := LootRoller.roll_from_crate(crate)
	add(inst)                              # add() saves + emits item_added/inventory_changed
	coins_changed.emit(coins())
	return inst
```

and replace it with:

```gdscript
## Store purchase: spend coins and add an UNOPENED crate to the collection.
## Returns false on unknown crate or not enough coins. (Crates don't count against the
## weapon cap, so inventory-full does not block buying.)
func buy_crate(crate_id: String) -> bool:
	var crate := Crates.get_crate(crate_id)
	if crate.is_empty():
		return false
	if not SaveManager.spend_coins(int(crate["price"])):
		return false
	SaveManager.add_crate(crate_id)
	SaveManager.save_game()
	coins_changed.emit(coins())
	inventory_changed.emit()
	return true

## Finalize an opened crate: consume one crate + add the rolled winner. Atomic.
## Returns false if no crate owned / inventory full / empty roll. The opener supplies the
## winner so the reel and the award are the same instance.
func commit_crate(crate_id: String, winner: Dictionary) -> bool:
	if SaveManager.crate_count(crate_id) <= 0 or is_full() or winner.is_empty():
		return false
	SaveManager.remove_crate(crate_id)
	add(winner)   # appends, auto-equips if none, saves, emits
	return true
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`. (MainMenu still references `open_crate` at this point — but the gate only parses each script; cross-script calls aren't resolved at parse time, so it stays clean. MainMenu is fixed in Task 7.)

- [ ] **Step 3: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/loot/Inventory.gd
git commit -m "Crate opening: Inventory.buy_crate + commit_crate (replace instant open_crate)"
```

---

## Task 3: Crate icons — Crates.icon() + generated art

**Files:** Modify `scripts/loot/Crates.gd`, `~/gen_palette_sprites.py`. Generate `art/crates/*.png`.

- [ ] **Step 1: Add `icon()` to Crates.** Insert after `get_crate()`:

```gdscript
## Tile icon for a crate (per-crate art if present, else the shared placeholder).
static func icon(id: String) -> Texture2D:
	var path := "res://art/crates/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://art/crates/_crate.png")
```

- [ ] **Step 2: Add a crate glyph generator.** In `~/gen_palette_sprites.py`, add this function before `def main():`:

```python
def crates():
    os.makedirs(ART + "/crates", exist_ok=True)
    b = canvas(32, 32)
    rect(b, 32, 5, 13, 22, 16, C2)        # chest body (indigo)
    rect(b, 32, 4, 8, 24, 6, C4)          # lid (lavender)
    rect(b, 32, 14, 6, 4, 4, C4)          # latch
    rect(b, 32, 5, 19, 22, 2, C4)         # body band highlight
    for name in ["_crate", "footlocker", "munitions_cache"]:
        write_png(ART + "/crates/" + name + ".png", 32, 32, b)
```

- [ ] **Step 3: Call it from main().** Change the `main()` body to add `crates()`:

```python
def main():
    enemy(); bullet(); muzzle(); xp_gem(); relic(); ground(); weapons(); crates()
    print("palette sprites written to", ART)
```

- [ ] **Step 4: Run the generator.**

Run: `python3 ~/gen_palette_sprites.py && ls /mnt/c/Users/thela/Documents/mobile-game/art/crates/`
Expected: `_crate.png  footlocker.png  munitions_cache.png`

- [ ] **Step 5: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 6: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/loot/Crates.gd art/crates
git commit -m "Crate opening: Crates.icon() + generated crate-box icons"
```

---

## Task 4: Tick sound (.wav)

**Files:** Create `~/gen_tick.py`. Generate `audio/tick.wav`.

- [ ] **Step 1: Write the generator** `~/gen_tick.py`:

```python
#!/usr/bin/env python3
# Stdlib WAV generator: a short decaying click for the crate-reel tick. 16-bit mono PCM.
import struct, math, os
SR = 44100
DUR = 0.04
OUT = "/mnt/c/Users/thela/Documents/mobile-game/audio"

def main():
    os.makedirs(OUT, exist_ok=True)
    n = int(SR * DUR)
    samples = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 90.0)
        s = math.sin(2 * math.pi * 1800.0 * t) * env
        if i < 3:
            s = 1.0 * (1.0 - i / 3.0)          # tiny attack transient
        v = max(-1.0, min(1.0, s * 0.6))
        samples.append(int(v * 32767))
    data = b"".join(struct.pack("<h", s) for s in samples)
    byte_rate = SR * 2
    hdr = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE"
    hdr += b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, SR, byte_rate, 2, 16)
    hdr += b"data" + struct.pack("<I", len(data))
    with open(os.path.join(OUT, "tick.wav"), "wb") as f:
        f.write(hdr + data)
    print("wrote tick.wav", len(samples), "samples")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run it.**

Run: `python3 ~/gen_tick.py && ls -l /mnt/c/Users/thela/Documents/mobile-game/audio/tick.wav`
Expected: `wrote tick.wav 1764 samples` and the file exists.

- [ ] **Step 3: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add audio/tick.wav
git commit -m "Crate opening: generated tick.wav for the reel"
```

---

## Task 5: CrateTile (inventory grid)

**Files:** Create `scripts/ui/CrateTile.gd`.

- [ ] **Step 1: Create the tile.**

```gdscript
class_name CrateTile
extends Button
## An inventory-grid tile for an owned (unopened) crate type: crate icon + name + an xN
## count badge, C2 indigo border. Emits crate_pressed(crate_id). Mirrors WeaponTile.

signal crate_pressed(crate_id: String)

const TILE_SIZE := Vector2(170, 170)
const ICON_SIZE := Vector2(96, 96)

var _crate_id := ""

func setup(crate: Dictionary, count: int) -> void:
	_crate_id = String(crate.get("id", ""))
	custom_minimum_size = TILE_SIZE
	clip_contents = true
	text = ""
	PixelTheme.style_tile(self, PixelTheme.ACCENT_DIM)   # C2 indigo border (crates have no rarity)
	pressed.connect(func(): crate_pressed.emit(_crate_id))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var icon := TextureRect.new()
	icon.texture = Crates.icon(_crate_id)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = String(crate.get("name", "Crate"))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(name_lbl, 13, PixelTheme.TEXT)
	box.add_child(name_lbl)

	if count > 1:
		_add_count_badge(count)

## A green "xN" badge pinned to the top-right corner (explicit rect, like WeaponTile's EQ).
func _add_count_badge(count: int) -> void:
	var badge_panel := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = PixelTheme.ACCENT
	bsb.set_corner_radius_all(0)
	bsb.anti_aliasing = false
	bsb.content_margin_left = 4
	bsb.content_margin_right = 4
	bsb.content_margin_top = 1
	bsb.content_margin_bottom = 1
	badge_panel.add_theme_stylebox_override("panel", bsb)
	badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := Label.new()
	badge.text = "x%d" % count
	badge.add_theme_font_override("font", PixelTheme.body_font())
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", PixelTheme.DARK)
	badge_panel.add_child(badge)
	add_child(badge_panel)
	badge_panel.anchor_left = 1.0
	badge_panel.anchor_top = 0.0
	badge_panel.anchor_right = 1.0
	badge_panel.anchor_bottom = 0.0
	badge_panel.offset_left = -44
	badge_panel.offset_top = 6
	badge_panel.offset_right = -6
	badge_panel.offset_bottom = 28
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/ui/CrateTile.gd
git commit -m "Crate opening: CrateTile (grid tile w/ icon, name, xN badge)"
```

---

## Task 6: CrateOpener (the reel reveal)

**Files:** Create `scripts/ui/CrateOpener.gd`.

- [ ] **Step 1: Create the opener.**

```gdscript
class_name CrateOpener
extends Control
## CS:GO-style crate reveal: a horizontal reel of weapon tiles scrolls fast, eases out,
## and snaps centered on a pre-rolled winner under a reticle; then a settle flash + reveal
## card. The winner is committed (award + consume crate) on settle. Ported from AfterDark's
## CrateSpinner. Full-screen overlay, built in code, hidden by default.

signal closed()

const TILE_W := 140.0
const TILE_H := 180.0
const ITEM_PX := 148.0      # TILE_W + 8 gap
const REEL_COUNT := 50
const LAND_INDEX := 42      # winner slot (7 decoys trail it)
const FAST_SPEED := 3000.0  # px/sec linear phase
const SLOW_DIST := 1100.0   # switch to ease-out within this distance
const SLOWDOWN := 9.0       # lerp factor (x delta) in the ease-out phase
const TICK_PX := 148.0      # one tile-width per tick
const TICK_CD := 0.03       # min seconds between ticks

var _crate_id := ""
var _winner := {}
var _scroll_x := 0.0
var _target_x := 0.0
var _animating := false
var _last_tick_x := 0.0
var _tick_cd := 0.0

var _mask: Control
var _reel: Control
var _reveal_card: PanelContainer
var _reveal_vbox: VBoxContainer
var _flash_rect: ColorRect
var _tick_player: AudioStreamPlayer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	_mask = Control.new()
	_mask.clip_contents = true
	_mask.anchor_left = 0.0
	_mask.anchor_right = 1.0
	_mask.anchor_top = 0.5
	_mask.anchor_bottom = 0.5
	_mask.offset_top = -TILE_H / 2.0
	_mask.offset_bottom = TILE_H / 2.0
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mask)

	_reel = Control.new()
	_reel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.add_child(_reel)

	var reticle := ColorRect.new()
	reticle.color = PixelTheme.ACCENT
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_left = -3
	reticle.offset_right = 3
	reticle.offset_top = -TILE_H / 2.0 - 8.0
	reticle.offset_bottom = TILE_H / 2.0 + 8.0
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_reveal_card = PanelContainer.new()
	PixelTheme.style_card(_reveal_card)
	_reveal_card.custom_minimum_size = Vector2(minf(520.0, get_viewport_rect().size.x - 48.0), 0)
	_reveal_card.visible = false
	center.add_child(_reveal_card)
	_reveal_vbox = VBoxContainer.new()
	_reveal_vbox.add_theme_constant_override("separation", 14)
	_reveal_card.add_child(_reveal_vbox)

	_tick_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/tick.wav"):
		_tick_player.stream = load("res://audio/tick.wav")
	add_child(_tick_player)

func open(crate_id: String) -> void:
	if SaveManager.crate_count(crate_id) <= 0 or Inventory.is_full():
		return
	_crate_id = crate_id
	_winner = LootRoller.roll_from_crate(Crates.get_crate(crate_id))
	_reveal_card.visible = false
	_flash_rect.color = Color(1, 1, 1, 0)
	_build_reel()
	visible = true
	_start_spin()

func _build_reel() -> void:
	for ch in _reel.get_children():
		ch.queue_free()
	var crate := Crates.get_crate(_crate_id)
	for i in REEL_COUNT:
		var inst: Dictionary = _winner if i == LAND_INDEX else LootRoller.roll_from_crate(crate)
		var tile := _reel_tile(inst)
		tile.position = Vector2(i * ITEM_PX, 0.0)
		_reel.add_child(tile)

func _reel_tile(inst: Dictionary) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(TILE_W, TILE_H)
	p.size = Vector2(TILE_W, TILE_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PixelTheme.BTN_BG
	sb.border_color = WeaponInstance.color(inst)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	p.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.texture = WeaponInstance.icon(inst)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 10
	icon.offset_top = 10
	icon.offset_right = -10
	icon.offset_bottom = -10
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	return p

func _start_spin() -> void:
	var view_w := get_viewport_rect().size.x
	var winner_center := LAND_INDEX * ITEM_PX + TILE_W / 2.0
	_target_x = view_w / 2.0 - winner_center + randf_range(-30.0, 30.0)
	_scroll_x = 0.0
	_reel.position = Vector2(0.0, 0.0)
	_last_tick_x = 0.0
	_tick_cd = 0.0
	_animating = true

func _process(delta: float) -> void:
	if not _animating:
		return
	_tick_cd = maxf(0.0, _tick_cd - delta)
	var dist := _target_x - _scroll_x
	if absf(dist) > SLOW_DIST:
		_scroll_x += signf(dist) * FAST_SPEED * delta
	else:
		_scroll_x = lerpf(_scroll_x, _target_x, clampf(SLOWDOWN * delta, 0.0, 1.0))
	if absf(_scroll_x - _last_tick_x) >= TICK_PX and _tick_cd <= 0.0:
		_play_tick()
		_last_tick_x = _scroll_x
		_tick_cd = TICK_CD
	_reel.position.x = _scroll_x
	if absf(_scroll_x - _target_x) < 1.0:
		_scroll_x = _target_x
		_reel.position.x = _scroll_x
		_animating = false
		_on_settle()

func _play_tick() -> void:
	if _tick_player.stream != null:
		_tick_player.play()

func _on_settle() -> void:
	_flash(WeaponInstance.color(_winner))
	Inventory.commit_crate(_crate_id, _winner)
	_show_reveal(_winner)

func _flash(col: Color) -> void:
	_flash_rect.color = Color(col.r, col.g, col.b, 0.5)
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color", Color(col.r, col.g, col.b, 0.0), 0.4)

func _show_reveal(inst: Dictionary) -> void:
	for c in _reveal_vbox.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = WeaponInstance.display_name(inst).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_title(title, 24)
	title.add_theme_color_override("font_color", WeaponInstance.color(inst))
	_reveal_vbox.add_child(title)
	var stats := Label.new()
	stats.text = "%s  ·  %s" % [WeaponInstance.rarity_name(inst), WeaponInstance.stat_summary(inst)]
	stats.custom_minimum_size = Vector2(460, 0)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelTheme.style_label(stats, 14, PixelTheme.TEXT_DIM)
	_reveal_vbox.add_child(stats)
	var tsum: String = WeaponInstance.talent_summary(inst)
	if tsum != "":
		var tl := Label.new()
		tl.text = "⟡ " + tsum
		tl.custom_minimum_size = Vector2(460, 0)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(tl, 13, PixelTheme.ACCENT)
		_reveal_vbox.add_child(tl)
	var cont := Button.new()
	cont.text = "CONTINUE"
	PixelTheme.style_button(cont, Vector2(0, 60), 18)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.pressed.connect(_close)
	_reveal_vbox.add_child(cont)
	_reveal_card.visible = true

func _close() -> void:
	visible = false
	closed.emit()
```

- [ ] **Step 2: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 3: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/ui/CrateOpener.gd
git commit -m "Crate opening: CrateOpener reel reveal (ported AfterDark spinner)"
```

---

## Task 7: MainMenu wiring

**Files:** Modify `scripts/MainMenu.gd`.

- [ ] **Step 1: Add the opener member var.** After `var _char_vbox: VBoxContainer ...`, add:

```gdscript
var _crate_opener: CrateOpener   # reused full-screen reel, opened from a crate tile
```

- [ ] **Step 2: Build + wire the opener in `_build_inventory_panel`.** At the end of `_build_inventory_panel()` (after the `_detail_popup` lines), add:

```gdscript
	_crate_opener = CrateOpener.new()
	_inv_panel.add_child(_crate_opener)
	_crate_opener.closed.connect(_populate_inventory)
```

- [ ] **Step 3: Replace the grid section of `_populate_inventory`.** Replace from `# Owned weapons as a tile grid` down to the `for inst in owned:` loop (the whole grid block including the empty-state) with:

```gdscript
	# Grid: owned crates first, then weapons (best rarity first). Tap a crate to open it,
	# a weapon for its detail popup.
	var owned := Inventory.weapons().duplicate()
	owned.sort_custom(func(a, b): return int(a.get("rarity", 1)) > int(b.get("rarity", 1)))
	var equipped_uid := Inventory.equipped_uid()
	var owned_crates: Dictionary = SaveManager.crates()

	if owned.is_empty() and owned_crates.is_empty():
		var none := Label.new()
		none.text = "No weapons yet — buy a crate in the Store."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelTheme.style_label(none, 14, PixelTheme.TEXT_DIM)
		_inv_vbox.add_child(none)
	else:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_inv_vbox.add_child(scroll)
		var grid_center := HBoxContainer.new()
		grid_center.alignment = BoxContainer.ALIGNMENT_CENTER
		grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid_center)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		grid_center.add_child(grid)
		for crate_id in owned_crates:
			var ct := CrateTile.new()
			grid.add_child(ct)
			ct.setup(Crates.get_crate(String(crate_id)), int(owned_crates[crate_id]))
			ct.crate_pressed.connect(_on_crate_tile_pressed)
		for inst in owned:
			var tile := WeaponTile.new()
			grid.add_child(tile)
			tile.setup(inst, String(inst.get("uid", "")) == equipped_uid)
			tile.tile_pressed.connect(_on_tile_pressed)
```

(Confirm the block you replaced ended right before `	# Bottom button: CANCEL ...` — that BACK/CANCEL line stays.)

- [ ] **Step 4: Add the crate-tile handler.** Place next to `_on_tile_pressed`:

```gdscript
## Crate tile tapped → open the CS:GO reel for that crate.
func _on_crate_tile_pressed(crate_id: String) -> void:
	_crate_opener.open(crate_id)
```

- [ ] **Step 5: Switch the store to buy-not-open.** Replace `_on_buy_crate`:

```gdscript
func _on_buy_crate(crate_id: String) -> void:
	if Inventory.buy_crate(crate_id):
		_last_unbox = "%s added to inventory." % String(Crates.get_crate(crate_id).get("name", "Crate"))
		_last_unbox_color = PixelTheme.SELECT
	else:
		_last_unbox = "Not enough coins."
		_last_unbox_color = PixelTheme.TEXT_DIM
	_populate_store()
```

- [ ] **Step 6: Crate buy buttons no longer gate on inventory-full.** In `_populate_store()`, change the crate button disabled line from:

```gdscript
		cb.disabled = SaveManager.coins() < int(crate["price"]) or Inventory.is_full()
```
to:
```gdscript
		cb.disabled = SaveManager.coins() < int(crate["price"])
```

- [ ] **Step 7: Run [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 8: Commit.**

```bash
cd "/mnt/c/Users/thela/Documents/mobile-game"
git add scripts/MainMenu.gd
git commit -m "Crate opening: inventory crate tiles + opener wiring + store buy-not-open"
```

---

## Task 8: Integration gate + F5 handoff

**Files:** none.

- [ ] **Step 1: Full [GATE]** — Expected: `GATE CLEAN`.

- [ ] **Step 2: Hand off to Larry for F5** (open the editor first so `art/crates/*.png` + `audio/tick.wav` import). Checklist:
  1. STORE → buy a crate → "… added to inventory"; coins drop. (Inventory not opened.)
  2. INVENTORY → a crate tile (×count if >1) appears **first** in the grid, weapons after.
  3. Tap the crate → full-screen reel scrolls fast, **ticks per tile**, decelerates, snaps centered on a tile under the gold reticle; settle flash + reveal card with the weapon.
  4. CONTINUE → the weapon is now in the grid; the crate count dropped (tile gone at 0); coins unchanged by opening.
  5. Buy several, open several — winners vary; relaunch → crate counts + weapons persisted.

---

## Self-Review (done during planning)
- **Spec coverage:** crates state+API (T1), buy/commit + remove open_crate (T2), Crates.icon + art (T3), tick wav (T4), CrateTile (T5), CrateOpener reel (T6), MainMenu grid+opener+store (T7). ✓
- **Placeholders:** none — complete code each step. ✓
- **Type/name consistency:** `crates`/`crate_count`/`add_crate`/`remove_crate`, `buy_crate`/`commit_crate`, `Crates.icon`, `CrateTile.setup`/`crate_pressed`, `CrateOpener.open`/`closed`, `_crate_opener`/`_on_crate_tile_pressed` — defined before use; `open_crate` removed in T2 and its only caller (`_on_buy_crate`) updated in T7. ✓

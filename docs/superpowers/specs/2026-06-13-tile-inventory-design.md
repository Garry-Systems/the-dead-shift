# Tile Inventory System — Design Spec

**Date:** 2026-06-13
**Branch:** `feat/tile-inventory` (off `master`)
**Project:** Survivor Game (Ryan Ace) — Godot 4.6 / GDScript, mobile portrait.

## Goal
Replace the scrolling **text-list** inventory (`MainMenu._populate_inventory`) with a **grid of rarity-colored weapon tiles**. Tapping a tile opens a **detail popup** with full stats + **EQUIP** and **SCRAP** (the latter surfaces the already-built `Inventory.deconstruct()`, which currently has no UI). The data layer is complete and untouched — this is a UI/UX rebuild.

## Scope decisions (locked with Larry, 2026-06-13)
- **Tile visual:** per-weapon **icons** (`art/weapons/<id>.png`), with a placeholder fallback so it works before final art. Larry will supply real icons later at the same paths.
- **Interaction:** tap a tile → **detail popup** (Equip + Scrap + Close).
- **Scrap:** **single-item**, shows the coin payout, **inline confirm** before scrapping. No bulk scrap.

## Non-goals (deferred)
- Bulk scrap / "scrap all below rarity X".
- Filtering / search / multiple sort orders (keep the existing rarity-desc sort).
- Any change to the loot data model, crates, rolling, save format, or coins.
- Reusing the tile elsewhere (crate-reveal screen) — `WeaponTile` is built reusable, but wiring it into other screens is a later task.
- Final per-weapon icon art (placeholders ship now; Larry overwrites).

---

## Architecture

All UI is **built in code** (matching `MainMenu`/`PixelTheme` convention — no new `.tscn`). Three new pieces + small helpers.

### 1. `scripts/ui/WeaponTile.gd` — `class_name WeaponTile extends Button`
A square, touch-friendly tile representing one weapon instance. Root is a `Button` (so taps are free) styled with a **rarity-colored** stylebox; content is overlaid as `MOUSE_FILTER_IGNORE` children so the button still receives the press.
```
signal tile_pressed(inst: Dictionary)
const TILE_SIZE := Vector2(170, 170)
var _inst: Dictionary

func setup(inst: Dictionary, is_equipped: bool) -> void:
    _inst = inst
    custom_minimum_size = TILE_SIZE
    PixelTheme.style_tile(self, WeaponInstance.color(inst))   # rarity border + hover/press
    # children (all mouse_filter = IGNORE), via a centered VBox:
    #   - TextureRect: WeaponInstance.icon(inst), ~96px, expand, KEEP_ASPECT_CENTERED, nearest filter
    #   - Label: base_def(inst).name (e.g. "AK-47"), Silkscreen ~16, TEXT
    #   - Label: WeaponInstance.rarity_name(inst), Silkscreen ~12, WeaponInstance.color(inst)
    #   - if is_equipped: a small green "EQUIPPED" badge Label pinned to a corner (PixelTheme.SELECT)
    pressed.connect(func(): tile_pressed.emit(_inst))
```
Texture filter for the icon: set `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST` (the project is global-Nearest, but set it explicitly on the TextureRect to be safe with non-imported placeholders).

### 2. `scripts/ui/WeaponDetailPopup.gd` — `class_name WeaponDetailPopup extends Control`
A full-rect overlay: a dim scrim (`PixelTheme.OVERLAY_DIM`, `MOUSE_FILTER_STOP` so it blocks the grid) + a centered `PanelContainer` card (`PixelTheme.style_card`). Hidden by default; one instance reused.
```
signal equip_requested(inst: Dictionary)
signal scrap_confirmed(inst: Dictionary)
signal closed()
var _inst: Dictionary

func open(inst: Dictionary, is_equipped: bool) -> void:
    # rebuild card content:
    #   - Title: WeaponInstance.display_name(inst), colored WeaponInstance.color(inst)
    #   - Label: rarity_name + "  ·  " + stat_summary   (wrapped)
    #   - Label: "⟡ " + talent_summary (if non-empty, wrapped)
    #   - EQUIP button: disabled if is_equipped; else pressed -> equip_requested.emit(inst); _close()
    #   - SCRAP button: disabled if is_equipped; else shows payout band from Rarity.tier(rarity).scrap
    #        as "SCRAP (N–M)"; first press flips the row to an inline confirm:
    #        "Scrap for N–M coins?  [YES]  [NO]"  (YES -> scrap_confirmed.emit(inst); _close())
    #        (DANGER-colored; NO returns to the normal buttons)
    #   - CLOSE button -> _close() (emits closed)
    visible = true
```
The popup does **not** call `Inventory` itself — it emits intent; `MainMenu` performs the mutation and repopulates. (Keeps the popup reusable and the data flow in one place.)

### 3. `MainMenu.gd` inventory rework
- `_build_inventory_panel()`: keep the centered card (`custom_minimum_size` ~ `Vector2(640, 800)`). Inside a VBox: **header** (title + `_inv_coins` label + the `_inv_from_play` "Equip a weapon to play" prompt) → **crate row** (unchanged `Crates.all()` buttons) → a `ScrollContainer` (`SIZE_EXPAND_FILL`, min height ~560) holding a **`GridContainer` with `columns = 3`** (store as `_inv_grid`) → **BACK/CANCEL** button. Add one reused `WeaponDetailPopup` child to `_inv_panel` (hidden).
- `_populate_inventory()`: clear `_inv_grid`; refresh `_inv_coins`/crate disabled-states; sort `Inventory.weapons()` rarity-desc (as today); for each instance build a `WeaponTile`, `setup(inst, uid == equipped_uid)`, connect `tile_pressed` → `_on_tile_pressed`. Empty-state label when no weapons. (Crate row + sort logic carried over verbatim.)
- `_on_tile_pressed(inst)`: `_detail_popup.open(inst, is_equipped)`; (re)connect its signals once in `_build_inventory_panel`:
  - `equip_requested` → existing `_on_equip(inst)` (preserves the `_inv_from_play` → mode-picker flow).
  - `scrap_confirmed` → `Inventory.deconstruct(uid)`, then `_populate_inventory()` + refresh coins. (`deconstruct` already guards equipped + persists + emits.)
  - `closed` → hide popup.
- Keep `_on_crate`, `_on_inv_back`, and the PLAY-forced-equip behavior (`_on_play` → `_show_inventory(true)` when nothing equipped).

### 4. `WeaponInstance.icon(inst)` helper (new static)
```
static func icon(inst: Dictionary) -> Texture2D:
    var id := String(base_def(inst).get("id", ""))
    var path := "res://art/weapons/%s.png" % id
    if ResourceLoader.exists(path):
        return load(path)
    return load("res://art/weapons/_placeholder.png")   # always present
```

### 5. `PixelTheme.style_tile(b, rarity)` helper (new static)
A chunky hard-cornered square stylebox set: `normal` = dark bg (`BTN_BG`) + **rarity-colored border** (width 4); `hover` = slightly lighter bg + brighter rarity border; `pressed` = rarity bg. No corner radius, no AA (matches the kit). Reuses the private `_box(bg, border, bw)` pattern.

### 6. Placeholder icons + path convention
- Convention: **`res://art/weapons/<weapon_id>.png`** for the 7 ids (`pistol, smg, shotgun, rifle, minigun, ak47, sniper`) + a generic `_placeholder.png`. Target source size **64×64** pixel art (rendered nearest, shown ~96px).
- Ship now: extend the stdlib PNG generator (`~/gen_sprites.py`, no Pillow on this box) to emit 7 simple **distinct** gun-silhouette glyphs (so the grid reads as varied) + `_placeholder.png`, written to `art/weapons/`. These are **temporary stand-ins** — Larry overwrites them with real icons at the same paths. (PNG import happens when Larry next opens the editor, like all art.)

---

## Data layer (unchanged — reference)
`Inventory` (autoload) already provides everything: `weapons()`, `coins()`, `is_full()` (cap 120), `equipped_uid()`, `equip(uid)`, `deconstruct(uid)` (rarity-band scrap, refuses equipped, persists + emits), `open_crate(crate_id)`, signals (`inventory_changed`, `coins_changed`, …). `Rarity.tier(id).scrap` = `[min,max]` payout band for the popup. **No data changes in this spec.**

## Flows
- **Browse:** INVENTORY → grid of tiles (rarity-desc). Tap a tile → popup.
- **Equip:** popup EQUIP → `Inventory.equip` → grid refreshes (new EQUIPPED badge). If `_inv_from_play`, instead proceed to the mode picker (existing behavior).
- **Scrap:** popup SCRAP → shows band → confirm YES → `deconstruct` → grid + coins refresh. Disabled for the equipped weapon.
- **Crate:** unchanged — buy/open from the crate row → `open_crate` → grid refresh; disabled when unaffordable or `is_full()`.
- **Forced equip from PLAY:** unchanged entry; equipping from the popup continues to the mode picker; CANCEL returns to hub.

## Files
**New:** `scripts/ui/WeaponTile.gd`, `scripts/ui/WeaponDetailPopup.gd`; `art/weapons/{pistol,smg,shotgun,rifle,minigun,ak47,sniper}.png` + `art/weapons/_placeholder.png` (generated placeholders).
**Changed:** `scripts/MainMenu.gd` (inventory panel → grid + popup wiring; keep hub/mode/char/crate/PLAY-flow), `scripts/loot/WeaponInstance.gd` (+`icon()`), `scripts/ui/PixelTheme.gd` (+`style_tile`), `~/gen_sprites.py` (emit the weapon glyphs).
**Unchanged:** all of `scripts/loot/*` logic, `SaveManager`, `Crates`, `Rarity`, save format, coins.

## GDScript gotchas to honor (project memory)
- Explicit types when reading Variants: `var v: float = ...`, `int(inst.get("rarity", 1))`, cast nodes `(n as Node2D)`.
- `instantiate()`/`.new()` results assigned to untyped `var` when setting custom props.
- New scripts get `class_name` + typed refs for custom-method access.
- TextEntry/Button signal wiring: connect in code (no scene wiring).

## Testing
**Headless compile gate** (catch parse/type errors before F5):
`/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5` → grep stderr for errors (the `menu_background.jpg` JPEG-decode line is the only expected one). Tiles/icons are only built when the inventory is **opened** (a user action), not at boot, so the new `art/weapons/*.png` (un-imported until Larry opens the editor) don't affect this gate — it's purely a GDScript parse/type check.

**F5 smoke (Larry):**
1. Menu → INVENTORY shows a **3-column tile grid**, rarity-colored borders, icons (placeholder glyphs), names + rarity, EQUIPPED badge on the equipped one.
2. Tap a tile → detail popup with name (rarity-colored), stat + talent summary, EQUIP / SCRAP / CLOSE.
3. EQUIP a different weapon → popup closes, badge moves. SCRAP is disabled on the equipped tile's popup.
4. Open a non-equipped weapon → SCRAP shows the payout band → confirm → weapon gone, coins increased, grid refreshed.
5. Buy a crate → new tile appears; crate buttons disable when broke / inventory full.
6. From hub with nothing equipped, PLAY → forced into inventory → equip from popup → continues to mode picker.
7. No errors in the Godot output; layout reads well at phone width.

## Out-of-scope follow-ups
- Real per-weapon icon art (drop into `art/weapons/<id>.png`).
- Bulk scrap, filter/sort options, tile use in the crate-reveal screen.

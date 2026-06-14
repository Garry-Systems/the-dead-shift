# Crate Opening (CS:GO-style) — Design Spec

**Date:** 2026-06-14
**Branch:** `feat/crate-opening` (off `test/combined-f5`)
**Reference:** Larry's AfterDark s&box `CrateSpinner.razor` (200-tile reel, pre-rolled winner, fast-linear → exponential ease-out → snap, tick per tile-width, settle flash + reveal card). This ports that feel to the Godot mobile game.

## Goal
Make crates a CS:GO-style experience: **buying a crate adds it (unopened) to the inventory**; opening it from the inventory plays a **scrolling reel that decelerates and lands on a pre-rolled weapon under a center reticle**, with a tick sound, settle flash, and reveal card — then the weapon drops into the inventory and the crate is consumed.

## Scope decisions (locked with Larry, 2026-06-14)
- **Crates live as tiles in the inventory grid** (mixed with weapons), one tile per owned type with a ×count badge. Tap → opener.
- **Add a tick sound now** — a minimal audio player + a generated `tick.wav`.

## Non-goals (deferred)
- Music/other SFX (only the crate tick). Crate "preview contents/odds" modal. Opening multiples at once. IAP. A 3D/parallax reel — this is a flat 2D strip.

---

## Architecture

### 1. `SaveManager.gd` — owned-crates state
- `DEFAULTS` += `"crates": {}` (dict `crate_id -> count`). The existing merge loads a saved Dictionary; JSON parses counts as float, so reads coerce with `int()`.
- API (memory-only mutators; caller saves):
```gdscript
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

### 2. `Inventory.gd` — buy + commit (replaces instant `open_crate`)
Remove `open_crate()` (no longer instant). Add:
```gdscript
## Store purchase: spend coins, add an UNOPENED crate to the collection. Returns false
## if unknown crate / not enough coins.
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

## Finalize an opened crate: consume one crate + add the rolled weapon. Atomic; returns
## false if no crate owned / inventory full / empty roll. Caller (the opener) supplies the
## winner so the reel and the award match.
func commit_crate(crate_id: String, winner: Dictionary) -> bool:
	if SaveManager.crate_count(crate_id) <= 0 or is_full() or winner.is_empty():
		return false
	SaveManager.remove_crate(crate_id)
	add(winner)   # appends, auto-equips if none, saves, emits item_added/inventory_changed
	return true
```

### 3. Crate icons — `Crates.icon()` + generated art
- Convention `res://art/crates/<crate_id>.png`, fallback `res://art/crates/_crate.png`:
```gdscript
static func icon(id: String) -> Texture2D:
	var path := "res://art/crates/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://art/crates/_crate.png")
```
- Generate (extend `~/gen_palette_sprites.py`): a 32×32 crate-box glyph in palette → `art/crates/_crate.png` + `footlocker.png` + `munitions_cache.png` (box body C2 indigo + C4 lid/latch highlight, so it reads as a chest on the void).

### 4. Audio — tick `.wav` + player
- New `~/gen_tick.py` (stdlib WAV writer): 16-bit mono PCM, 44100 Hz, ~40 ms — a short decaying blip (`sin(2*pi*1800*t) * exp(-t*90)`, scaled to int16, with a 1-sample transient) → `audio/tick.wav`. Godot imports `.wav` as `AudioStreamWAV` automatically.
- `CrateOpener` adds an `AudioStreamPlayer` child in `_ready`, `stream = load("res://audio/tick.wav")` guarded by `ResourceLoader.exists`; `.play()` on each tick.

### 5. `scripts/ui/CrateTile.gd` — inventory grid crate tile
`class_name CrateTile extends Button` (mirrors `WeaponTile`, 170×170): C2 indigo border (`PixelTheme.style_tile(self, PixelTheme.ACCENT_DIM)`), crate icon (`Crates.icon(id)`, 96px nearest), crate name, and an `×N` count badge (top-right, like the EQ badge). Emits `crate_pressed(crate_id)`.

### 6. `scripts/ui/CrateOpener.gd` — the reel reveal
`class_name CrateOpener extends Control` (full-rect overlay, hidden by default). Ported AfterDark math in `_process`.

**Nodes (built in `_ready`):** dim scrim (`PixelTheme.OVERLAY_DIM`, `MOUSE_FILTER_STOP`); a **mask** Control (full width, fixed height ~200, vertically centered, `clip_contents = true`) holding the **reel** Control; a **reticle** (a C4 vertical bar ~6px at screen center with a glow); a **reveal card** (`PanelContainer`, hidden); a flash `ColorRect` (hidden); an `AudioStreamPlayer`.

**Constants (tunable):**
```gdscript
const TILE_W := 140.0
const ITEM_PX := 148.0     # TILE_W + 8 gap
const REEL_COUNT := 50
const LAND_INDEX := 42     # winner slot (7 decoys trail it)
const FAST_SPEED := 3000.0 # px/sec linear phase
const SLOW_DIST := 1100.0  # switch to ease-out within this distance of target
const SLOWDOWN := 9.0      # lerp factor (× delta) in the ease-out phase
const TICK_PX := 148.0     # one tile-width per tick
const TICK_CD := 0.03      # min seconds between ticks
```

**Flow:**
```gdscript
func open(crate_id: String) -> void:
	if SaveManager.crate_count(crate_id) <= 0 or Inventory.is_full():
		return                     # guarded; caller only opens owned crates
	_crate_id = crate_id
	_winner = LootRoller.roll_from_crate(Crates.get_crate(crate_id))
	_build_reel()
	_reveal_card.visible = false
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

func _start_spin() -> void:
	var view_w := get_viewport_rect().size.x
	var winner_center := LAND_INDEX * ITEM_PX + TILE_W / 2.0
	_target_x = view_w / 2.0 - winner_center + randf_range(-30.0, 30.0)
	_scroll_x = 0.0
	_reel.position.x = 0.0
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

func _on_settle() -> void:
	_flash(WeaponInstance.color(_winner))
	Inventory.commit_crate(_crate_id, _winner)   # award + consume + save
	_show_reveal(_winner)
```
`_reel_tile(inst)` = a 140×TILE-height `PanelContainer` with a rarity-bordered `StyleBoxFlat` (`WeaponInstance.color(inst)`) containing a centered `TextureRect` (`WeaponInstance.icon(inst)`, nearest). `_flash(color)` tweens a full-rect `ColorRect`'s alpha 0.5→0 over 0.4 s. `_show_reveal(inst)` fills the reveal card (`display_name` in rarity color, `rarity_name + stat_summary`, `talent_summary`, CONTINUE button) and shows it. CONTINUE → `_close()` (hide + `closed.emit()`).

**Signal:** `signal closed()` — `MainMenu` repopulates the inventory on close.

### 7. `MainMenu.gd` wiring
- `_build_inventory_panel`: add a reused `CrateOpener` child to `_inv_panel` (like `_detail_popup`); connect `closed` → `_populate_inventory`. Member `var _crate_opener: CrateOpener`.
- `_populate_inventory`: build the grid with **crate tiles first**, then weapon tiles. Owned crates from `SaveManager.crates()`; for each `crate_id` with count > 0 → `CrateTile.setup(Crates.get_crate(id), count)`, connect `crate_pressed` → `_on_crate_tile_pressed`. Empty-state check becomes "no weapons AND no crates".
- `_on_crate_tile_pressed(crate_id)`: `_crate_opener.open(crate_id)`.
- Store `_on_buy_crate`: change `Inventory.open_crate(crate_id)` → `Inventory.buy_crate(crate_id)`; result line → `"<Name> added to inventory"` (no "Unboxed"). Keep the disabled checks (coins / not relevant: `is_full` no longer blocks buying a crate since the crate itself is small — but keep a sane cap; for v1 buying is allowed regardless of weapon-grid fullness, since crates aren't weapons. Disable only on coins.) Update the crate button `disabled = SaveManager.coins() < price`.

---

## Reel math (ported from AfterDark)
AfterDark: `reel.Left = scrollX`; `scrollX` runs 0 → `target = maskWidth/2 - itemCenterX`; phase 1 linear at `fastSpeed`, phase 2 `Lerp(scrollX, target, slowdown*dt)`, snap < 1px; tick every item-width. This spec uses the identical structure with Godot `position.x`, `lerpf`, `_process(delta)`, and `get_viewport_rect()` for the mask/reticle center (avoids layout-timing on the mask rect). The winner is pre-rolled and placed at `LAND_INDEX`; the reel only lands on it.

## Data flow
Store → `buy_crate` (spend + add_crate + save) → crate tile appears in inventory. Tap crate tile → `CrateOpener.open` (roll winner, build reel) → spin → settle → `commit_crate` (consume crate + add weapon + save) → reveal card → close → inventory repopulates (crate count −1, new weapon present). Coins = shared `SaveManager` wallet.

## Files
**New:** `scripts/ui/CrateTile.gd`, `scripts/ui/CrateOpener.gd`; `art/crates/{_crate,footlocker,munitions_cache}.png` (generated); `audio/tick.wav` (generated); `~/gen_tick.py`.
**Changed:** `scripts/SaveManager.gd` (crates state+API), `scripts/loot/Inventory.gd` (buy_crate/commit_crate, remove open_crate), `scripts/loot/Crates.gd` (+`icon()`), `~/gen_palette_sprites.py` (+crate glyphs), `scripts/MainMenu.gd` (grid crate tiles + opener wiring + store buy_crate).

## Edge cases
- Inventory full → tapping a crate is a **no-op** (the `open()` guard returns early before any animation); `commit_crate` also guards. Buying a crate is still allowed (it's not a weapon and doesn't count against the 120-weapon cap). An on-screen "inventory full" note is a deferred follow-up (rare at the 120 cap).
- Owning multiple of a type → one tile, ×N badge; opening decrements; tile disappears at 0.
- Old save → gets `"crates": {}`.
- `tick.wav` un-imported before first editor open → `ResourceLoader.exists` guard means no crash (silent until imported).
- The roll is authoritative on settle via `commit_crate` (validates ownership) — the reel winner and the awarded item are the same dict instance.

## Testing
**Headless gate** (parse/type) as before.
**Persistence probe** (self-restoring, like the store): add a crate, save, reload, assert `crate_count` persisted; then `commit_crate` and assert the crate decremented + a weapon was added. Restore the backup.
**F5 (Larry):**
1. STORE → buy a crate → "added to inventory"; coins drop.
2. INVENTORY → a crate tile (×count) appears first in the grid.
3. Tap it → full-screen reel scrolls fast, decelerates, **ticks per tile**, lands centered on a tile under the reticle; settle flash + reveal card.
4. CONTINUE → the rolled weapon is in the grid; the crate count dropped (tile gone at 0). Coins unchanged by opening.
5. Relaunch → crate counts + new weapon persisted.

## Out-of-scope follow-ups
- Crate odds/preview screen, batch opening, more SFX/music, fancier reveal for top rarities.

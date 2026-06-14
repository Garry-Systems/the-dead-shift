# Store (Start-Page Shop) — Design Spec

**Date:** 2026-06-14
**Branch:** `feat/store` (off `test/combined-f5`, which integrates tile-inventory + portrait + contact-fix + restyle)
**Project:** Survivor Game (Ryan Ace) — Godot 4.6 / GDScript, mobile portrait.

## Goal
Add a **STORE** to the MainMenu hub: the single "spend coins" place. It (1) **unlocks characters** (Ryan free; Jimbo & Bob cost coins) and (2) **buys crates** (moved out of the inventory). The inventory panel becomes pure collection (grid + equip/scrap). Characters become gated — character-select only lets you pick unlocked ones.

## Scope decisions (locked with Larry, 2026-06-14)
- Store sells **character unlocks + crates**, and **crate-buying moves from the inventory into the store**.
- **Ryan free; Jimbo & Bob cost coins.** Default prices (tunable): Jimbo **600**, Bob **400**.

## Non-goals (deferred)
- Buying coins with real money (Phase 8 IAP — a later thin layer over the same wallet).
- Cosmetics / skins. Selling weapons directly (crates are the weapon source).
- A separate store *scene* — built in code as a MainMenu panel, like the others.

---

## Architecture

### 1. `SaveManager.gd` — character ownership (new persistent state)
- Add to `DEFAULTS`: `"unlocked_characters": ["ryan"]`. The existing forward-compat merge handles it: old saves without the key keep the default `["ryan"]`; the `Array == Array` type check in `load_game()` loads a saved list correctly. (`DEFAULTS.duplicate(true)` means `_data` owns its own array — safe to mutate.)
- New API (mutators change memory only; caller saves — matches the existing pattern):
```gdscript
func unlocked_characters() -> Array:
    return _data.get("unlocked_characters", ["ryan"])

func is_character_unlocked(id: String) -> bool:
    return id in unlocked_characters()

func unlock_character(id: String) -> void:
    var list: Array = _data.get("unlocked_characters", [])
    if id not in list:
        list.append(id)
        _data["unlocked_characters"] = list
```

### 2. `Characters.gd` — price metadata
- Add a `"price"` field to each `all()` entry: `ryan` = 0, `jimbo` = 600, `bob` = 400. (Tunable; mirrors how `Crates` carry a price.)
- Add a helper:
```gdscript
static func price(id: String) -> int:
    return int(get_character(id).get("price", 0))
```

### 3. `MainMenu.gd` — STORE panel + gating + crate move
**Hub:** add a `STORE` button → `PLAY / STORE / CHARACTERS / INVENTORY`. Wire `_show_store()`.

**`_show_only(panel)`:** include the new `_store_panel` in the visibility toggle.

**`_build_store_panel()`** — responsive card (same pattern as the inventory: `MarginContainer` full-rect with 24px margins → `style_card` PanelContainer → `_store_vbox` VBox). Content rebuilt on show by `_populate_store()`.

**`_populate_store()`** — clears `_store_vbox`, then:
1. Title "STORE" + a coins label (`COINS: %d` via `SaveManager.coins()`).
2. A `ScrollContainer` (vertical-expand fill) → inner VBox holding:
   - **"CHARACTERS"** subheading. For each `Characters.all()` entry, a row: name (`PixelTheme.TEXT`) + wrapped perk `desc` + a button:
     - unlocked → `OWNED` (disabled, `PixelTheme.TEXT_DIM`).
     - locked → `UNLOCK – <price>`; `disabled = SaveManager.coins() < price`; pressed → `_on_buy_character(id, price)`.
   - **"CRATES"** subheading. For each `Crates.all()`, a button `"<NAME> (<price>)"`, disabled when `coins < price or Inventory.is_full()`, pressed → `_on_buy_crate(id)`.
   - A **result label** `_store_result` rendering the `_last_unbox` member (the last crate outcome, in `_last_unbox_color`; reset to `""` when the store is opened via `_show_store()`).
3. `BACK` button → `_show_only(_hub)`.

Members added: `_store_panel`, `_store_vbox`, `_store_result: Label`, `var _last_unbox := ""`, `var _last_unbox_color := PixelTheme.TEXT`.

**Handlers:**
```gdscript
func _on_buy_character(id: String, price: int) -> void:
    if SaveManager.is_character_unlocked(id):
        return
    if not SaveManager.spend_coins(price):
        return
    SaveManager.unlock_character(id)
    SaveManager.save_game()
    _populate_store()

func _on_buy_crate(crate_id: String) -> void:
    var inst := Inventory.open_crate(crate_id)   # spends coins, rolls, adds to inventory, saves
    if inst.is_empty():
        _last_unbox = "Can't open that crate."
        _last_unbox_color = PixelTheme.TEXT_DIM
    else:
        _last_unbox = "Unboxed: %s (%s)" % [WeaponInstance.display_name(inst), WeaponInstance.rarity_name(inst)]
        _last_unbox_color = WeaponInstance.color(inst)
    _populate_store()   # rebuilds the panel (incl. the result label from _last_unbox) + refreshes coins/buttons
```
Because `_populate_store()` rebuilds the whole panel, the crate result is stored in the `_last_unbox`/`_last_unbox_color` members and rendered into `_store_result` during the rebuild — not set on the label directly (which would be wiped).

**Inventory change:** delete the crate-row block from `_populate_inventory()` (the `crate_row` HBox + the `for crate in Crates.all()` loop). Keep the header (title + coins + `_inv_from_play` prompt), the tile grid, and BACK. The PLAY-forced-equip flow is unchanged.

**Character-select gating (`_build_char_panel` + `_refresh_char_labels`):**
- In `_build_char_panel`, for each character determine `unlocked := SaveManager.is_character_unlocked(cid)`. Locked → button `disabled = true`, label prefixed `🔒 `, and the desc shows `"Unlock in the Store"` instead of the perk text.
- `_select_character(id)` only sets `RunConfig.character_id` if `SaveManager.is_character_unlocked(id)` (disabled buttons can't fire anyway; this is a guard).
- `_refresh_char_labels`: selected & unlocked → `SELECT` (C4); unlocked-not-selected → `TEXT_DIM` (C3); locked stays disabled (Godot dims it).
- **Guard:** add `_ensure_valid_character()` (resets `RunConfig.character_id = "ryan"` if the current one isn't unlocked) called in `_ready()` and when showing the character panel. Prevents starting a run as a locked character.

---

## Data flow
Hub → STORE → buy character (spend → unlock → save → refresh) or buy crate (`Inventory.open_crate` → roll/add/save → result line). Hub → CHARACTERS → select among unlocked only. Coins are the existing shared `SaveManager` wallet (run rewards + crate spend + unlocks all hit it). Everything persists via `SaveManager.save_game()`.

## Files
**Changed:** `scripts/SaveManager.gd` (unlock state + 3 methods, +1 DEFAULTS key), `scripts/logic/Characters.gd` (+`price` field + `price()` helper), `scripts/MainMenu.gd` (STORE button + store panel + 2 handlers + `_ensure_valid_character`; remove inventory crate row; gate char-select).
**Unchanged:** `Crates.gd`, `Inventory.gd` (reused as-is), the loot system, the tile inventory grid.

## Edge cases
- Already-owned character → `OWNED`, disabled. Insufficient coins → buy button disabled.
- Inventory full → crate buttons disabled (existing `Inventory.is_full()`).
- Old save (pre-feature) → gets `["ryan"]`; Jimbo/Bob lock until bought (acceptable for the dev build; only Larry plays).
- Locked character can never be the active run character (the `_ensure_valid_character` guard + gated select).

## Testing
**Headless gate** (parse/type): `…Godot…console.exe --headless --path "C:\Users\thela\Documents\mobile-game" --quit-after 5` → grep for errors (only the `menu_background.jpg` line is expected).
**Save round-trip probe** (this feature persists data — verify like Phase 6 Spec 1): a headless probe that unlocks a character, saves, reloads, and asserts it persisted (run the script class directly; autoloads aren't loaded in `--script` mode).
**F5 (Larry):**
1. Hub shows **STORE**; coins visible.
2. STORE → Characters: Ryan `OWNED`; Jimbo/Bob show `UNLOCK – 600/400`, disabled when broke.
3. Buy a character you can afford → coins drop, button → `OWNED`, persists across relaunch.
4. STORE → Crates: buy → "Unboxed: …" line, coins drop, weapon appears in the inventory grid; disabled when broke / inventory full. (Inventory no longer has a crate row.)
5. CHARACTERS: locked ones show `🔒` + "Unlock in the Store", can't be selected; unlocked ones selectable; can't start a run as a locked character.

## Out-of-scope follow-ups
- IAP coin packs (Phase 8). New characters (just add to `Characters.all()` with a price). Store SFX/juice.

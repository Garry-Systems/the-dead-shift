# Crate Gun-Pools v1 — Design

**Date:** 2026-06-16
**Status:** Approved (small — spec doubles as the build reference)
**Project:** The Dead Shift (Godot 4 + GDScript)

## Goal

Differentiate crates by **which guns** they contain instead of by rarity cap. **Every crate can
roll up to the top rarity (Carnage / r7)** — the crate decides the *weapon pool*, not the ceiling.
Adds 3 new gun-pool crates and lifts the existing Footlocker's cap so it too can roll the best.

## Background — what exists today

- `Crates.all()` entries are pure data: `{id, name, price, rarity_floor, rarity_ceil, desc}`.
  The store buy buttons (`MainMenu._build_store`), inventory `CrateTile`s, and the `CrateOpener`
  reel all iterate `Crates.all()` / `Crates.get_crate(id)` — so adding a crate auto-wires
  everywhere.
- `LootRoller.roll_from_crate(crate)` rolls a rarity via `Rarity.roll(floor, ceil)` then
  `LootRoller.roll(rarity, crate.force_base)`. `force_base = ""` → a random base from
  `Weapons.all()`; a set id → that one gun. There is **no way to roll from a subset** of guns today.
- Base weapon ids (verified): `pistol, smg, shotgun, rifle, minigun, ak47, sniper`.
- Crate icons: `Crates.icon(id)` loads `art/crates/<id>.png`, else `art/crates/_crate.png`. The
  generator currently writes one generic crate glyph for all, so crates are told apart by NAME.

## Design

### New lever: `bases` (weapon-id subset)
Add an optional `"bases": [ids]` field to a crate. `LootRoller.roll_from_crate` picks a random
base from that list when present:

```gdscript
static func roll_from_crate(crate: Dictionary) -> Dictionary:
	var rarity := Rarity.roll(int(crate.get("rarity_floor", 1)), int(crate.get("rarity_ceil", Rarity.MAX_ID)))
	var bases: Array = crate.get("bases", [])
	var base_id: String = String(bases[randi() % bases.size()]) if not bases.is_empty() else String(crate.get("force_base", ""))
	return roll(rarity, base_id)
```

(`force_base` kept for back-compat; `bases` wins when set; both empty → any gun, unchanged.)

### Crate lineup (5 total) — all reach r7

| id | name | price | bases | rarity_floor–ceil |
|---|---|---|---|---|
| `footlocker` | Footlocker | 150 | *(any)* | **1–7** *(was 1–4)* |
| `munitions_cache` | Munitions Cache | 600 | *(any)* | 4–7 *(unchanged)* |
| `precision_pack` | Buckshot & Bolts | 500 | `["sniper","shotgun"]` | 1–7 |
| `auto_case` | Full Auto Case | 500 | `["smg","ak47"]` | 1–7 |
| `standard_arms` | Standard Arms | 500 | `["pistol","rifle","minigun"]` | 1–7 |

Exact `Crates.all()` additions/edits:

```gdscript
# Footlocker: change "rarity_ceil": 4 -> 7 and update desc to "Any gun, any rarity - a real gamble."
{
	"id": "precision_pack", "name": "Buckshot & Bolts", "price": 500,
	"rarity_floor": 1, "rarity_ceil": 7, "bases": ["sniper", "shotgun"],
	"desc": "Snipers & shotguns. Any rarity up to Carnage.",
},
{
	"id": "auto_case", "name": "Full Auto Case", "price": 500,
	"rarity_floor": 1, "rarity_ceil": 7, "bases": ["smg", "ak47"],
	"desc": "SMGs & AK-47s. Any rarity up to Carnage.",
},
{
	"id": "standard_arms", "name": "Standard Arms", "price": 500,
	"rarity_floor": 1, "rarity_ceil": 7, "bases": ["pistol", "rifle", "minigun"],
	"desc": "Pistols, rifles & miniguns. Any rarity up to Carnage.",
},
```

### Icons
The 3 new crates fall back to the shared `_crate.png` glyph (same as the existing crates look
today) and are distinguished by name. Distinct per-crate art is a later polish, not in scope.

## Save compatibility
`SaveManager.crates` is an `id → count` dict. New crate ids are additive; existing
`footlocker`/`munitions_cache` ids are unchanged, so owned/unopened crates persist. Lifting
Footlocker's `rarity_ceil` only affects *future* rolls (rarity isn't stored on the crate count).
No migration.

## Verification
- Headless compile gate (filter benign `menu_background.jpg` + `EditorSettings not instantiated`).
- Logic probe: `roll_from_crate({"bases":["sniper","shotgun"], "rarity_floor":1, "rarity_ceil":7})`
  ×200 → every result's `base` ∈ {sniper, shotgun}; an any-gun crate still spans bases.

## Files touched
- `scripts/loot/Crates.gd` — lift Footlocker ceil + 3 new entries with `bases`.
- `scripts/loot/LootRoller.gd` — `roll_from_crate` honors `bases`.

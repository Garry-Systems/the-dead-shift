# Transfer Stores: BIG MART + PARKING GARAGE (v0.1.65) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two selectable run locations built as data palettes over the existing procedural arena: BIG MART (aisle combat, shelf dominos, freezer patches) and THE PARKING GARAGE (pillar lattice, chain-exploding cars, weaponizable car alarms).

**Architecture:** Pure `Locations.gd` registry + `RunConfig.location`; small seams on the existing systems (weighted-pick overlays on Enemies/Obstacles, a dps-0 guard + rect `size_y` on the hazard/destructible layer); per-location content = registry rows + one placement pass each in ObstacleField + a set-piece builder; picker UI on the mode panel; per-location best rows.

**Tech Stack:** Godot 4.6 GDScript; home-repo generator for 2 ground tiles.

**Spec:** `docs/superpowers/specs/2026-07-10-transfer-stores-design.md` (approved: rank gates 2/4 · all modes except Daily & Boss Rush · shared bests + per-location line).

## Global Constraints

- Runner env / boot-scene probes / MANDATORY DUAL GATE / literal probe output in reports / .uid sidecars / master-no-push-until-ship: identical to the roadmap-4 packs (`GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`; probes never `--script`; new class_name → one `--editor --quit` cache pass; snapshot/restore `SaveManager._data` when probes touch saves).
- Verified codebase facts every task may rely on: `Obstacles.all()` rows are plain dicts (schema in Obstacles.gd:7-22, hp<0 = indestructible, `by_id()` exists); `ObstacleField._spawn_at(pos, row = {})` already takes a forced row (Rush Hour path, ObstacleField.gd:71-75); `Destructible._draw` renders shape+color only and rects are SQUARE (`size` = half-extent both axes, Destructible.gd:165-171); `Enemies.TYPES` rows have `weight`/`min_wave`; `RunConfig.mode` ∈ endless|boss_rush|horde with hardcore/overtime/daily as flags; ground = `Main.tscn` `Ground` Parallax2D using `art/ground.png` ext_resource; `Enemy.taunt(node, duration)` accepts any Node2D (Pack C); `_show_banner(text, sub)` exists (Pack 0); the PROMOTED popup's unlock line is built in `MainMenu._promotion_reward()` (verify exact shape in T5).
- All numbers = GameConfig consts with ## comments (starter values): `LOC_MART_RANK := 2`, `LOC_GARAGE_RANK := 4`, `SHELF_HP := 120.0`, `SHELF_HALF_W := 26.0`, `SHELF_HALF_H := 12.0`, `SHELF_CHAIN_RADIUS := 140.0`, `SHELF_GEMS := 1`, `MART_FORMATION_LEN_MIN := 3`, `MART_FORMATION_LEN_MAX := 5`, `FREEZER_SLOW := 0.35`, `FREEZER_SLOW_DUR := 1.0`, `FREEZER_RADIUS := 110.0`, `FREEZER_DURATION := 45.0`, `FREEZER_CHANCE_PER_WAVE := 0.5`, `PILLAR_RADIUS := 40.0`, `PILLAR_GRID := 480.0`, `PILLAR_DENSITY := 0.55`, `WAIL_TIME := 6.0`, `WAIL_TAUNT_RADIUS := 500.0`, `WAIL_TAUNT_TICK := 0.5`, `WAIL_TAUNT_DUR := 1.2`, `WAIL_MAX_CONCURRENT := 2`.
- Copy ≤ 70 chars; dim-ink = `PixelTheme.ACCENT.darkened(0.45)`; palette strict (pillars/shelves C2/C3, no new exception colors).

---

### Task 1: `Locations.gd` + `RunConfig.location` + seams

**Files:** Create `scripts/logic/Locations.gd`; Modify `scripts/RunConfig.gd` (or wherever RunConfig lives — it's the autoload with `mode`/`hardcore`), `scripts/logic/GameConfig.gd`, `scripts/logic/Enemies.gd`, `scripts/logic/Obstacles.gd`, `scripts/HazardZone.gd`, `scripts/Destructible.gd`.

**Interfaces (produced):**
- `Locations.ALL: Array` — rows `{ id, name, rank_unlock, banner_sub, memo, ground ("res://art/ground.png" | "res://art/ground_mart.png" | "res://art/ground_garage.png"), obstacle_mults: Dictionary (row-id → weight mult, missing = 1.0, 0.0 = excluded), spawn_mults: Dictionary (enemy-id → mult), gimmick: String }`. Rows: `forecourt` (rank 0, all mults empty = today's arena byte-identical), `big_mart` (rank `LOC_MART_RANK`, banner_sub "attention shoppers.", obstacle_mults {barrel:0.4, car:0.3, transformer:0.5, shelf:1.0}, spawn_mults {shambler:1.2, runner:1.3, spitter:0.5}, gimmick "mart"), `parking_garage` (rank `LOC_GARAGE_RANK`, banner_sub "level 3 stays closed.", obstacle_mults {car:2.2, transformer:0.0, crate:0.6, pillar:1.0}, spawn_mults {shambler:1.3, exploder:1.5}, gimmick "garage").
- `Locations.by_id(id) -> Dictionary` ({} unknown), `Locations.unlocked(id, rank) -> bool`, `Locations.obstacle_mult(id, row_id) -> float`, `Locations.spawn_mult(id, enemy_id) -> float`.
- `RunConfig.location := "forecourt"` + reset in the same place other run fields reset; **forced** to "forecourt" wherever Daily Shift and Boss Rush configure the run (find both entry points — Daily sets `daily=true`, Boss Rush sets mode — force at those sites with a comment).
- `Enemies.pick(wave, mults: Dictionary = {})` — optional per-id weight multiplier (roundi(weight × mult), 0 excludes; default {} = today's behavior byte-identical). Same optional param on `Obstacles.pick(wave, mults = {})`.
- `HazardZone._apply`: skip the `take_damage` calls entirely when `_dps <= 0.0` (slow/stun still apply) — freezer patches must not flash/shake at 0 damage. One guard per loop, backward compatible.
- `Destructible`: optional row field `size_y` (rect half-height; absent = square as today) — configure + `_draw` + collider extents honor it. All existing rows unaffected.

- [ ] Probe (RED first): Locations rows complete (3, fields present, forecourt mults empty); `unlocked` at ranks 1/2/4; `obstacle_mult("parking_garage","transformer") == 0.0`; `Enemies.pick(5, {"shambler": 0.0})` never returns shambler over 100 draws and `pick(5)` unchanged-vs-today smoke (returns valid ids); same for Obstacles; RunConfig.location default + reset; copy ≤ 70 chars. (Destructible size_y + HazardZone guard are compile-checked here, behavior-verified in T3's probe.)
- [ ] Implement per the Interfaces block; probe GREEN; gates 0/0; commit `feat(locations): registry, RunConfig.location, weighted-pick overlays, dps-0 + size_y seams`.

---

### Task 2: Run-start wiring — ground swap, banner, bias pass-through

**Files:** Modify `scripts/Main.gd`, `scenes/Main.tscn` (only if the ground sprite needs a node path anchor — prefer runtime texture swap), `scripts/Spawner.gd`, `scripts/ObstacleField.gd`.

**Interfaces:** Consumes T1's getters. Produces: at run start Main resolves `var loc := Locations.by_id(RunConfig.location)` once — swaps the Ground parallax texture (`load(loc.ground)`; find the Sprite2D under the `Ground` Parallax2D in Main.tscn and set its texture; forecourt = no-op), shows `_show_banner("TONIGHT'S SHIFT: %s" % loc.name, loc.banner_sub)` for non-forecourt (reuse the banner call idiom; don't collide with OVERTIME's own start banner — sequence or skip, report), and hands the mult dicts to `Spawner.location_spawn_mults` / `ObstacleField.location_obstacle_mults` (plain Dictionary fields consumed at every `Enemies.pick`/`Obstacles.pick` call site — thread the param through each).

- [ ] Probe: math-only (Locations getters at each id) + compile; runtime texture-swap is boot-gate + F5 territory (say so). Gates 0/0. Commit `feat(locations): run-start ground/banner/bias wiring`.

---

### Task 3: BIG MART content

**Files:** Modify `scripts/logic/Obstacles.gd` (shelf row), `scripts/Destructible.gd` (chain_id collapse), `scripts/ObstacleField.gd` (formation pass + freezer scatter), `scripts/Forecourt.gd` OR a new `scripts/MartFront.gd` (set-piece — read how Forecourt is instantiated in Main.tscn and mirror; the builder must only run when its location is active, and Forecourt must no-op outside "forecourt").

**Interfaces:** Consumes T1 seams. Produces:
- Obstacles row `shelf`: kind "cover"? NO — soft, non-solid loot-ish: `{ id:"shelf", kind:"loot", shape:"rect", size:GameConfig.SHELF_HALF_W, size_y:GameConfig.SHELF_HALF_H, solid:false, hp:GameConfig.SHELF_HP, hazard_id:"", loot:"gems", gem_count:GameConfig.SHELF_GEMS, color:C3, weight:55, min_wave:1, chain_id:"shelf" }` — plus optional row field **`chain_id`**: on `_die`, a destructible with a chain_id `light_fuse`s same-chain_id destructibles within `SHELF_CHAIN_RADIUS` (reuses the existing barrel fuse + per-frame budget verbatim — verify barrels chain via hazard-kind and generalize WITHOUT changing barrel behavior: barrels keep chaining exactly as today; report the mechanism found). A fused shelf dies its normal death (gems + dust) — NO blast, NO hazard.
- ObstacleField **formation mode**: rows with `"formation": true` (add to the shelf row) spawn as axis-aligned runs of `MART_FORMATION_LEN_MIN..MAX` units spaced `2 × SHELF_HALF_W + 6` px along the run axis (random horizontal/vertical per formation), the whole run placed by the normal ring/keep-out logic. Ambient + cluster paths both honor it.
- **Freezer patches**: in the mart only (gimmick "mart"), each wave edge rolls `FREEZER_CHANCE_PER_WAVE` (unseeded randf — position-flavor RNG per the Spawner idiom, NOT the daily stream) to place a slow-only HazardZone near the player (dps 0, slow `FREEZER_SLOW`, slow_dur `FREEZER_SLOW_DUR`, radius `FREEZER_RADIUS`, duration `FREEZER_DURATION`, pale C4 tint via a color override — verify HazardZone color cfg accepts any Color). Owner: ObstacleField's location pass (it already has wave-edge machinery via _drop_cluster — read and co-locate).
- Set-piece: storefront slab (solid rubble-style rect run) + 2 checkout lanes (3 shelves each) built at origin when location == "big_mart", honoring the existing spawn keep-out.

- [ ] Probe: shelf row shape incl. size_y/chain_id; chain: two shelves 100px apart off-tree… fuse needs tree — in-tree with processing driven: kill shelf A → assert shelf B fuse lit within budget frames (mirror how the barrel-chain was probed historically if a precedent exists, else drive `_physics_process` manually and assert the fuse timer state); dps-0 freezer zone: player stub takes NO damage but receives apply_slow. Gates 0/0. Commit `feat(locations): BIG MART — shelf aisles, dominos, freezer patches, storefront`.

---

### Task 4: PARKING GARAGE content

**Files:** Modify `scripts/logic/Obstacles.gd` (pillar row), `scripts/ObstacleField.gd` (lattice pass), `scripts/Destructible.gd` (wail), new `scripts/GarageBooth.gd` set-piece (or fold into the T3 set-piece dispatcher — match T3's structure).

**Interfaces:** Consumes T1 seams + `Enemy.taunt`. Produces:
- Obstacles row `pillar`: `{ id:"pillar", kind:"cover", shape:"circle", size:GameConfig.PILLAR_RADIUS, solid:true, hp:-1.0, color:C2-ish concrete (use the C2 const family — palette strict), weight:0, min_wave:1 }` — weight 0: pillars NEVER scatter randomly; they exist only via the lattice pass.
- **Lattice pass** (garage only): each cull tick, for every 480px (`PILLAR_GRID`) grid node within the scatter radius of the player: deterministic presence = `hash(Vector2i(gx, gy)) % 100 < PILLAR_DENSITY * 100` (position-derived — the same world spot ALWAYS resolves the same; track spawned cells in a Dictionary to avoid doubles; far cells culled by the normal cull EXCEPT pillars must re-spawn when revisited — the spawned-cells entry must clear on cull; verify the cull path can report/clear them, e.g. pillars join a "lattice" group and the pass reconciles group members vs nearby cells). Lattice EXCLUDES: forecourt keep-out AND the basement offset region (distance to BASEMENT_OFFSET < BASEMENT_RADIUS × 2).
- **CAR ALARM (wail)**: Destructible rows may carry `"wail": true` (garage's car row — the garage passes a modified car row via obstacle_mults? NO: mults only scale weights. Add the flag via a location hook: ObstacleField, when gimmick == "garage", injects `row = row.duplicate(); row["wail"] = true` for picked `car` rows — report placement). On the first `take_damage` that doesn't kill it, a wailing-enabled car starts a `WAIL_TIME` wail: every `WAIL_TAUNT_TICK`s call `Enemy.taunt(self, WAIL_TAUNT_DUR)` on "enemies"-group members (guard `e is Enemy` — bosses excluded, Pack C idiom) within `WAIL_TAUNT_RADIUS`; pulsing C4 ring `_draw` overlay; one wail per car ever (`_wailed` flag); global cap `WAIL_MAX_CONCURRENT` via a "wailing_cars" group drop-oldest (silence, not free). SFX: reuse an existing sting throttled (grep SoundManager for a suitable id — "ui_denied"/"alarm"-ish; report choice; NO new WAVs).
- Set-piece: attendant booth (solid) + 2 barrier arms (soft rects using size_y).

- [ ] Probe: pillar row weight 0 never returned by `Obstacles.pick` over 200 draws; lattice hash determinism (same cell → same verdict, ~55% density over a 20×20 sample within ±10pts); wail: car stub in-tree, take_damage below lethal → wail state on + a planted Enemy within radius gets `_taunt_time > 0` after one tick; second damage doesn't restart; cap drop-oldest silences. Gates 0/0. Commit `feat(locations): PARKING GARAGE — pillar lattice, car alarms, booth`.

---

### Task 5: Picker UI, unlocks, records, copy

**Files:** Modify `scripts/MainMenu.gd` (mode panel + promo popup + RECORDS), `scripts/SaveManager.gd` (`last_location`, `location_best` dict + accessors), `scripts/GameOver.gd` (location_best update on run end), `scripts/logic/Flavor.gd` (2 memos).

**Interfaces:** Consumes `Locations.ALL/unlocked`, `Ranks` rank. Produces:
- Mode panel location row: a cycling `_make_button` labeled `LOCATION: <NAME>` (tap advances to the next UNLOCKED location, wraps; shows `<NAME> — RANK N` grayed for locked ones it skips-with-flash or simply cycles only unlocked + shows a lock hint line — pick the simpler that matches the mode-button lock idiom, report). Sets `RunConfig.location` + persists `SaveManager.last_location`. Restored on menu load (guard: if saved id somehow locked → forecourt). Row hidden until rank ≥ `LOC_MART_RANK` (before that it's noise).
- PROMOTED popup: ranks 2/4 append `TRANSFER APPROVED: BIG MART|THE PARKING GARAGE` to the unlock line — find `_promotion_reward()`'s "Unlocked:" construction (mode unlocks at 3/5/7) and mirror.
- Records: `SaveManager.location_best(id)/set_location_best(id, wave)`; GameOver updates it for non-forecourt endless-family runs (same guard family as best_wave — verify OVERTIME's frozen-bests rule and respect it: overtime runs do NOT write location bests either); RECORDS page: one dim row per unlocked non-forecourt location `BIG MART — WAVE %d` (0 = "—").
- Flavor: `STAFF_MEMOS` += `"MEMO: BIG MART is not our competitor. BIG MART is a warning."` and `"MEMO: do not park on level 3."` (≤70 chars each; probe asserts).

- [ ] Probe: accessors round-trip (snapshot/restore); `Locations.unlocked` gating vs the picker's cycle set (pure part); memo lengths. UI = review+F5. Gates 0/0. Commit `feat(locations): picker row, TRANSFER APPROVED unlocks, per-location bests, memos`.

---

### Task 6: Ground tiles (home generator → game art; controller QA gate)

**Files:** Modify `/home/larryun/gen_palette_sprites.py`; generated `art/ground_mart.png`, `art/ground_garage.png` (16px, same canvas/idiom as `ground()`).

- Builders: `ground_mart()` = C1 base + faint C2 tile-seam grid (lines every 8px, 1px, sparse breaks); `ground_garage()` = C1 base + C2 parking-stripe dashes (one horizontal dash row per tile, offset). Both must tile seamlessly (edges consistent — verify by eye at 4×4 tiling in the QA sheet).
- Implementer: builders + regenerate + write a /tmp QA sheet showing each tile tiled 4×4 at 4× scale + run the boot gate; STOP before committing (controller QA).
- [ ] Controller QA → commit both repos: game `art(locations): mart + garage ground tiles`; home generator commit.

---

### Task 7: Ship v0.1.65 (controller task)

- [ ] Fable whole-branch review (base = the v0.1.64 ship commit `c444469`). Special attention: forecourt byte-identity (default mults empty → zero behavior change for existing runs — THE regression risk of this pack); Daily determinism (freezer/wail RNG unseeded-positional only; location forced forecourt on daily); pillar lattice × basement/extraction/forecourt keep-outs; wail × taunt × mannequin decoy stacking; shelf chains at wave-15 density (budget shared with barrels); OVERTIME frozen-bests respected by location_best.
- [ ] One fix dispatch; Minor triage. `VERSION` → `0.1.65`; CHANGELOG "**v0.1.65 — Transfer Request Approved**" (voice: you can work at OTHER stores now; the stores are not better); push, CI green, stamp check, tag, release with APK; ledger + memory.
- [ ] F5 checklist: forecourt runs feel byte-identical; mart aisles read + dominos chain satisfyingly + freezer slow is fair; garage pillars make dash-lanes + alarm dinner-bell peels the horde + car chains are readable; picker cycle + locked states; TRANSFER APPROVED at ranks 2/4; per-location bests rows; daily still forecourt.

## Self-review notes (applied)

- Spec coverage: registry/RunConfig/seams (T1), run-start wiring (T2), MART (T3), GARAGE (T4), UI/unlock/records/copy (T5), tiles (T6), ship (T7). Spec's §5 verification table fully consumed into task verify-first directives.
- The two verified-here catches are baked in: `size_y` rect extension (square-only rects) and the HazardZone `_dps <= 0` guard (freezer flash-spam).
- Type consistency: `Locations.*` getters, mult-dict params, row field names (`chain_id`, `wail`, `size_y`, `formation`) consistent across tasks.

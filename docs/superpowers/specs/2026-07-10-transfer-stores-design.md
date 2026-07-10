# Transfer Stores — BIG MART + THE PARKING GARAGE (v0.1.65)

**Date:** 2026-07-10 · **Status:** approved picks via buttons (BIG MART + PARKING GARAGE; LOADING DOCK / CAR WASH / TRUCK STOP / DINER benched). Design calls (all recommendations accepted): rank-gated unlocks · all modes except Daily & Boss Rush · shared bests + per-location best line.

**Concept:** locations are DATA PALETTES over the existing procedural arena, not tilemaps: ground-tile variant + obstacle mix + hazard bias + spawn-table bias + origin set-piece + ONE gimmick rule + copy/ambience. Target: v0.1.65, single pack.

## 1. Architecture

- **`scripts/logic/Locations.gd`** (pure registry): rows `{ id, name, rank_unlock, banner_sub, memo, ground, obstacle_weights, hazard_bias, spawn_bias, gimmick }`. Rows: `forecourt` (rank 0 — today's arena, byte-identical defaults), `big_mart` (rank 2), `parking_garage` (rank 4). Pure getters: `by_id`, `unlocked(id, rank)`, `ALL`.
- **`RunConfig.location: String`** (default `"forecourt"`), set by the PLAY-panel picker; **forced to `"forecourt"` for Daily Shift and Boss Rush** (seeded board stays one fair fight; boss arena stays pure). Reset with the other RunConfig fields.
- Consumers read the CURRENT location row once at run start: `ObstacleField` (weights + location prop rows), `Forecourt` (builds only when `location == "forecourt"`; each location has its own origin set-piece builder), ground sprite path, `Spawner`/`Enemies` bias, HUD banner (`TONIGHT'S SHIFT: BIG MART` via the Pack-0 `_show_banner(text, sub)`).
- **Selection UI:** a location row on the PLAY/mode panel (left/right arrows or cycling button showing the location name + LOCKED (RANK N) state — mirror the mode-select idiom). Locked = unselectable + rank requirement shown. Selection persists (`SaveManager` key `last_location`, reset to forecourt if the save's rank no longer unlocks it — can't happen, ranks don't regress; keep the guard anyway).
- **Records:** shared bests remain THE records. New save dict `location_best` (id → best wave, endless-family only), one compact row per unlocked non-forecourt location in RECORDS ("BIG MART — WAVE 14").

## 2. BIG MART (rank 2) — aisle combat

*"attention shoppers. please disregard the shoppers."*

- **Set-piece at origin:** storefront slab (solid cover) + 2 checkout lanes (soft cover rows) — Forecourt-style code-built.
- **Obstacles:** NEW destructible row `shelf` (soft, hp ~120, rect collider wider than tall, drawn as a C2/C3 shelving unit): scattered in **row formations** — the location's scatter pass places shelves in runs of 3-5 aligned units (a "formation" placement mode in ObstacleField, used only by location rows that request it) → the field reads as broken aisles. Reduced barrel/car weights; crates kept.
- **Gimmick — SHELF DOMINO:** a destroyed shelf `light_fuse`s aligned neighbor shelves within ~140px (existing barrel-chain fuse tech, `CHAIN_DELAY` + per-frame budget) — but a shelf "burst" is a collapse: no blast, no fire; drops 1-2 XP gems, brief dust draw. Whole aisles can be brought down — on purpose or by a Tanker.
- **FREEZER SECTION:** occasional floor patches (slow-only HazardZone: dps 0, `apply_slow` both sides, long duration, pale C4-tinted draw) scattered like ambient hazards. Cold shelf-lined arena identity.
- **Spawn bias:** +shamblers/+runners (shoppers), fewer spitters.

## 3. THE PARKING GARAGE (rank 4) — sightline chess

*"level 3 is closed. level 3 has been closed for a while."*

- **Set-piece at origin:** attendant booth (solid) + ramp barrier arms (soft).
- **Obstacles:** NEW indestructible row `pillar` (hp −1, round collider ~40px, drawn as a C2 concrete column) placed on a **lattice**: as the player roams, pillars spawn snapped to a fixed 480px world grid (position-derived, deterministic — the same world spot always has/lacks a pillar via a hash of the grid coords; no drift, no doubles). Heavy car weight (chain explosions), no transformers-on-grid conflicts (cars/barrels still scatter freely between pillars).
- **Gimmick — CAR ALARMS:** the first time a car takes damage (without dying), it WAILS for ~6s: siren SFX (reuse an existing WAV pitched, or the flame throttle idiom — no new audio), pulsing C4 ring draw, and every 0.5s it calls **`Enemy.taunt(car, 1.2s)`** on enemies within ~500px — the Pack-C taunt seam takes ANY Node2D with `take_damage`, so a wailing car IS a taunt target. The horde piles onto the car; the car usually dies (chain explosion risk); the player chooses when to ring the dinner bell. One wail per car, `WAIL_MAX_CONCURRENT 2` (drop-oldest silences).
- **Ambience:** darker ground variant (denser dark tile pattern — stays strict-palette); spawn bias: +shamblers thick, +exploders (gas fumes).

## 4. Shared plumbing

- Ground variants: 2 new 16px tiles via the home generator (mart = C1 + faint C2 grid lines/tile seams; garage = C1 + C2 parking-stripe dashes), same NEAREST tiling path.
- Unlock moment: the existing PROMOTED popup's "Unlocked:" line gains the location at ranks 2/4 (`TRANSFER APPROVED: BIG MART`) — mirror the mode-unlock wiring.
- Copy: 1 banner sub + 1 STAFF MEMO per location added to `Flavor.gd` pools (≤70 chars).
- Sprites/art: NO new entity art; shelves/pillars are code-drawn like all destructibles; 2 ground PNGs only.
- Config: every number above = `GameConfig.LOC_*` / `MART_*` / `GARAGE_*` consts with ## comments (starter values).
- Basement/extraction/events: all work unchanged in any location (the basement offset arena is location-agnostic: wall/rubble as today; pillars' lattice EXCLUDES the basement offset region and the forecourt keep-out).

## 5. Plan-time verification

| Assumption | Verify |
|---|---|
| ObstacleField weight table shape + where a "formation" placement pass can hook | ObstacleField.gd `_spawn_at`/cluster code |
| Destructible row schema supports new soft/indestructible rows + custom draw | Obstacles.gd registry + Destructible._draw dispatch |
| Taunt on a Destructible car: car has `take_damage`, isn't in "enemies", wail ring drawable on it | Destructible.gd + Enemy.taunt guards |
| Ground sprite is swappable per run (where ground.png loads) | Main.tscn / parallax node |
| Mode-select UI idiom for the location row + LOCKED state | MainMenu mode panel |
| PROMOTED "Unlocked:" line source | Ranks/MainMenu promo descriptor |
| Slow-only HazardZone (dps 0) doesn't no-op/misdraw | HazardZone._apply/draw |
| Daily/BossRush forcing point for RunConfig.location | RunConfig reset + run-start flow |

## 6. Testing & rollout

Per-task boot-scene probes + the mandatory dual gate; pack-level fable review before ship; VERSION bump 0.1.65 + tag. F5 focus: aisle-formation readability, domino chain feel + perf at wave 12, freezer slow fairness, pillar lattice density vs dash lanes, alarm dinner-bell tactics (does the horde visibly peel?), locked/unlocked picker states, per-location best rows, Daily still forecourt-only.

## Out of scope

Locations 3-6 (benched), per-location music/WAVs, location-specific bosses/events, tilemaps, Daily-with-locations.

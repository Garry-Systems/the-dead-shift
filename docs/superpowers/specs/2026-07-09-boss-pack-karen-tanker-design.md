# Boss Pack: THE KAREN + THE TANKER — design

**Date:** 2026-07-09 · **Target release:** v0.1.60 · **Status:** approved by Larry (kits approved individually via question buttons)

Roster goes 7 → 9. Both bosses join the normal `Bosses.pick()` rotation and Boss Rush automatically (uniform-random-excluding-last needs no changes). Each boss brings exactly one new pattern class; everything else is reuse. All numbers below are **starter values** in `GameConfig` — tuned on phone later.

---

## 1. THE KAREN — attacks aim + footing

A customer, not staff (first non-employee boss). Fast-ish chaser, weak touch damage; the kit is the pressure. Combat-model exploit: constant forced repositioning (shove) + auto-aim theft (decoys) — the player can never plant and fire.

**New pattern: `ScreamRing` extends ExpandingRing** (`scripts/patterns/ScreamRing.gd`)
- Identical telegraph/expand/damage-once behavior via `super`.
- On player hit (and only on hit): shove the player `KAREN_SCREAM_SHOVE` px directly away from ring center + `CameraShake` trauma kick.
- Requires **new `Player.apply_shove(impulse: Vector2)`** — a decaying external-velocity impulse folded into the existing movement integration (same spirit as dash; must not fight joystick input, just add to it). No shove while player is mid-dash (dash wins).

**Phases** (`karen`, "THE KAREN", `KAREN_HP 1600` — slightly above Courier, well under Manager; `KAREN_SPEED_MULT 0.85`):

| Phase | at | cadence | patterns (round-robin) |
|---|---|---|---|
| P1 | 1.0 | 4.2 | ScreamRing · DebuffApplier slow (*"LEAVING A REVIEW"*) |
| P2 | 0.66 | 3.6 | ScreamRing · Summon `{count: 3, decoy: true}` · slow |
| P3 | 0.33 | 3.2 | Summon **MANAGER ON DUTY** (once, via `on_enter`) · ScreamRing · jam · decoy summon |

**P3 `on_enter` (existing BossBase hook):** fire `CombatText.callout(karen_pos, "GET ME THE MANAGER!", PixelTheme.ACCENT)` + a one-shot SummonSpawner `{count: 1, hp_mult: KAREN_MANAGER_HP_MULT 6.0, elite_kind: "alpha"}`.
- **New optional `elite_kind` cfg key on SummonSpawner:** after `configure()`, if non-empty call `e.apply_elite(kind)`. Deliberately bypasses the Spawner's endless/horde elite gate — this is a boss move, not ambient spawn (comment this at the call site). Alpha = speed-aura buffer → the "manager" literally buffs the staff around him. Round-robin P3 list must NOT contain the manager summon (one-shot only, via `on_enter`).
- Jam in P3 is the Manager's signature on loan (`MANAGER_JAM_DURATION` reused, own const not needed).

New consts: `KAREN_HP 1600`, `KAREN_SPEED_MULT 0.85`, `KAREN_SCREAM_RADIUS 240`, `KAREN_SCREAM_DAMAGE 30`, `KAREN_SCREAM_SHOVE 150`, `KAREN_MANAGER_HP_MULT 6.0`. Scream windup/expand reuse `SLAM_WINDUP`/`SLAM_EXPAND_TIME`.

## 2. THE TANKER — attacks the arena

The fuel-delivery driver who never left. Slow between bursts (`TANKER_SPEED_MULT 0.5`), all threat is in the dashes. Combat-model exploit: moving area denial — his trails carve the kite space into burning corridors (vs the Fryer's static zones).

**New pattern: `TrailDash` extends ChargeDash** (`scripts/patterns/TrailDash.gd`)
- During the dash window (`_physics_process`, after `super` moves the body): every `TANKER_TRAIL_SPACING 90` px of travel, spawn a fire `HazardZone` at the boss position.
- Each pool: `configure_hazard({color: fire, dps: TANKER_POOL_DPS 20, radius: TANKER_POOL_RADIUS 70, duration: TANKER_POOL_DURATION 4.0, hurts_player: true, windup: TANKER_IGNITE_DELAY 0.9})` — reads as a dark puddle for ~0.9s, THEN ignites. Cross wet fuel early or lose the lane. Pools hurt enemies too (both-sides, standard hazard multipliers).
- **New optional `windup` cfg key on `HazardZone.configure_hazard`:** `_windup = float(cfg.get("windup", GameConfig.HAZARD_WINDUP))` — one line, backward compatible (all existing callers unchanged).
- **Pool cap:** pools join group `"tanker_fuel"`; before spawning, if group size ≥ `TANKER_TRAIL_MAX 14`, free the OLDEST (group order = spawn order — same drop-oldest idiom as `cap_player_pools`, but its own group/cap; player pools unaffected).
- Puddle visual pre-ignite: HazardZone already draws a faint pre-arm circle; darken it for fuel via a `puddle: true` cfg → draw C1-dark puddle instead of faint orange (small `_draw` branch keyed off a stored flag).

**Phases** (`tanker`, "THE TANKER", `TANKER_HP 2400` — second-tankiest after Manager):

| Phase | at | cadence | patterns (round-robin) |
|---|---|---|---|
| P1 | 1.0 | 4.6 | TrailDash |
| P2 | 0.66 | 4.0 | TrailDash · ZoneFill fuel spill near player (reuse Fryer-style params, fire color) |
| P3 | 0.33 | 3.4 | **JACKKNIFE**: TrailDash ×2 back-to-back (second dash re-aims at the player's current position; implemented as TrailDash cfg `chain: 1` — on `_end_charge`, if chain > 0, re-telegraph 0.4s and dash again with chain − 1) · ExpandingRing tank-rupture (`TANKER_RUPTURE_RADIUS 260`, `TANKER_RUPTURE_DAMAGE 40`) · denser trail (`spacing 60`) |

Dash speed/duration: `TANKER_CHARGE_SPEED 600`, `TANKER_CHARGE_DURATION 1.0` (longer haul than Courier so the trail matters). `charging` flag handling for the chained dash must keep BossBase chase stood down BETWEEN the two dashes (hold `charging = true` through the 0.4s re-telegraph; `_exit_tree` guard still resets it if the boss dies mid-chain).

## 3. Shared plumbing

- **Registry:** two entries appended to `Bosses._LIST` — `{karen, Karen.tscn, "THE KAREN"}`, `{tanker, Tanker.tscn, "THE TANKER"}`. Scenes cloned from an existing boss scene (Courier is the closest shape for both).
- **Scripts:** `scripts/bosses/Karen.gd`, `scripts/bosses/Tanker.gd` (BossBase subclasses, `_hp_mult()` from new consts, `_build_phases()` per tables above).
- **Sprites:** 48px palette boss sprites via home-repo `gen_palette_sprites.py` (`karen.png`, `tanker.png` → `art/bosses/`), contact-sheet QA like Pack F. `_draw` regalia fallbacks gated on `_sprite_loaded` (Manager-tie idiom): Karen = C4 sunglasses band + C1 bob wedge + handbag rect; Tanker = C1 cap + C4 hose loop.
- **Lore:** intro one-liners land with the already-queued flavor-text pack (Karen: *"she asked for corporate. corporate is dead."*; Tanker: *"pump 3 called for a refill. he's still delivering."* — final lines in the flavor pack, not here).
- **Sound:** reuse existing boss-spawn/hit SFX wiring — no new WAVs in this pack.

## 4. Plan-time verification (implementer MUST check before coding)

| Assumption | Where to verify |
|---|---|
| Player movement integration point for `apply_shove` decaying impulse | `Player.gd` `_physics_process` / dash handling |
| `on_enter` Callable signature + when it fires | `BossBase._enter_phase` (line ~114) |
| `apply_elite("alpha")` safe on a summon-spawned enemy post-`configure()` | `Enemy.apply_elite`, Spawner call order at `Spawner.gd:104` |
| `configure_hazard` callers all omit `windup` today (backward compat) | grep `configure_hazard(` |
| ExpandingRing exposes a hit-player hook ScreamRing can extend (or shove folded into an overridden hit check) | `scripts/patterns/ExpandingRing.gd` |
| ChargeDash `_end_charge`/`queue_free` shape allows the chained re-dash without double-free | `scripts/patterns/ChargeDash.gd:67` |
| Boss Rush pulls from `Bosses.pick()` (new bosses auto-included) | grep `Bosses.pick` |

## 5. Testing

- Headless probes: phase tables well-formed (at/cadence/patterns), consts exist, `Bosses.count() == 9`, `name_for` both ids; SummonSpawner `elite_kind` applies + plain summons untouched; HazardZone default windup unchanged when key omitted; TrailDash pool cap drop-oldest at 14; shove decays to zero and never permanently displaces input authority.
- **MANDATORY gate (both):** editor-quit parse check AND boot gate `timeout 25 $GODOT --headless --path <proj> res://scenes/Main.tscn 2>&1 | grep -cE "SCRIPT ERROR|PARSE ERROR"` expect 0 — put in every implementer brief.
- Phone F5 checklist: Karen shove feel (does forced movement read as fair on touch?), puddle→ignite timing readable at wave 15 density, JACKKNIFE second dash dodgeable, MANAGER ON DUTY visibly buffs adds, no boss-bar weirdness from the big add.

## 6. Out of scope

Boss intro one-liner display system (flavor pack), new music/SFX, renaming the legacy 3 bosses, elite gate changes for ambient spawns, balance beyond starter values.

# Special Abilities — "Company Equipment" (v0.1.68)

**Date:** 2026-07-10
**Target release:** v0.1.68 (Night Shift Stories / boss bench + VISITORS slides to v0.1.69)
**Approved by Larry:** character-signature actives (not loadout/drops), flat cooldown (not kill-charge), Ryan = projectile wipe + push, NEW character Jackson Killa gets the turret.

## Concept

Every character gets ONE signature active ability, fired from a dedicated HUD button on a flat
per-ability cooldown. Available from wave 1 on any character you own — it's part of the character,
no separate unlock. This is the game's first player-triggered active layer (everything else is
auto-fire, double-tap dash, or passive).

Roster grows 6 → 7: **Jackson Killa** (new, heavy-weapons specialist) owns the SENTRY TURRET.

## UX — the ability button

- New button in the **bottom-right corner** of the in-run HUD (`Hud.gd`), ~140×140px, showing the
  ability's icon.
- **Cooldown display:** greyed with a bottom-up fill while cooling; full-bright + one-shot flash +
  `ability_ready` SFX when ready. Tap while cooling = no-op (small "shake" nudge, no sound spam).
- **Touch handling:** the button must swallow touches inside its rect (`set_input_as_handled`, same
  idiom as CrateOpener's tap-skip) so a tap there never feeds `VirtualJoystick.gd` movement or the
  double-tap dash detector in `Player.gd`. This is the riskiest UI wiring in the pack — verify on
  the phone that mashing the button never dashes.
- Cast feedback: CombatText callout of the ability name (e.g. "CLEAR OUT!") + per-ability SFX via
  the `gen_retro_audio.py` pattern.

## The seven abilities

All numbers are STARTER values, constants in `GameConfig.gd` (`ABILITY_*` prefix). Cooldowns are
per-ability so each can be tuned independently.

| Character | Ability | Effect | CD (s) |
|---|---|---|---|
| Ryan Ace | **CLEAR OUT** | Wipes EVERY enemy projectile on the map + radial push: all enemies within 520px shoved hard away (zero damage — pure breathing room) | 40 |
| **Jackson Killa** (NEW) | **SENTRY TURRET** | Drops a stationary turret at his position; auto-fires at the nearest enemy for 12s. Cap 1 — casting again replaces the old one | 45 |
| Jimbo James | **DEAD EYE** | 3s bullet time: world runs at ~0.3 time-scale, Jimbo compensated (move + fire ×2.5) so he acts near-normal while everything crawls | 50 |
| Zombie Bob | **ONE OF THEM** | 4s: regular enemies + elites stop targeting him entirely (no chase, no contact damage, ranged hold fire). **Bosses unaffected** — they know | 45 |
| Alstar Tuck | **JACKPOT** | Rolls ONE of 4 effects, equal weight: NUKE (big Shockwave, real damage), DEEP FREEZE (freeze every enemy on screen 3s), PAYDAY (+2 bonus coins per kill for 10s), TRIGGER HAPPY (instant reload + 40% frenzy 6s). CombatText announces the roll | 60 |
| The Janitor | **CLOSING TIME** | Giant slick (≈3× dash-slick radius) centered on him for 8s: enemies inside hard-slowed AND kills inside pay +2 bonus coins each | 45 |
| The Delivery Girl | **AIR DROP** | Marks her position; 1.5s later a package slams down — Shockwave damage + knockback in 300px, then drops 2 health packs + a gem cluster | 40 |

### Design details & rules

- **CLEAR OUT vs Ryan's dash:** Ryan's dash currently owns the projectile purge (internal
  `CHAR_RYAN_ABILITY_COOLDOWN 15s`). The purge MOVES to the ability button (dash keeps the AK
  instant-reload perk). His character desc updates accordingly. `CHAR_RYAN_ABILITY_COOLDOWN` and the
  dash-purge call in `Player.gd` are removed/repurposed.
- **DEAD EYE time-scale ownership:** `Juice.gd` hit-stop also writes `Engine.time_scale` and
  force-restores to 1.0. Introduce a single base-scale owner (e.g. `Juice.base_scale` static,
  default 1.0): hit-stop restores to `base_scale`, DEAD EYE sets `base_scale = 0.3` then back to
  1.0 after 3 REAL seconds (SceneTreeTimer `ignore_time_scale = true`). Safety nets: restore on
  player death, run end, and `_ready()` (statics survive scene reloads — the RelicEffects lesson).
  Shift clock / run_time slowing during it is coherent (whole world slows) — accepted.
- **ONE OF THEM:** ghost state on Player (`_ghost_time`); `Enemy.gd` gates chase/contact/ranged
  fire on it (statuses like frozen/pin unaffected). Physical bodies still collide — "ignored", not
  "intangible". Hive broods inherit the ignore like any regular enemy. Taunt outranks nothing here
  (a taunted enemy is already not targeting the player).
- **JACKPOT coins + CLOSING TIME coins:** per-kill bonus window, NOT `RunStats.coin_mult` (that
  multiplies the whole run payout) — reuse the Blood Moon pays-PER-KILL idiom from v0.1.50.
- **SENTRY TURRET:** new `Turret.gd` node; targeting + `CompanionBullet` fire copied from the
  drone's `_fire_drone_shot` (talent-free by design, same as coworkers). Turret bullets never crit,
  never proc talents. On basement teleport, an active turret is expired immediately (stationary =
  strandable; same class of fix as `COWORKER_LEASH_SNAP`).
- **AIR DROP health packs are a NEW pickup type** — the game has none today (only XpGem /
  RelicPickup / BasementCratePickup). New `HealthPack.gd`: XpGem's collect pattern, heals a flat
  `ABILITY_AIRDROP_HEAL 25` via `Player.heal()`. Spawned ONLY by AIR DROP in this pack (world/enemy
  drops are out of scope, but the node is reusable later).
- **AIR DROP in HARDCORE:** health packs no-op (global heal no-op rule already covers
  `Player.heal`). Accepted — the damage + gems still justify the cast. No special-casing.
- **Daily determinism:** ability RNG (JACKPOT) is player-triggered and un-seeded — same rule as
  loot RNG, which the Daily already excludes from its date-seed. No changes needed.
- **Boss Rush / Horde / Overtime:** abilities work everywhere, no mode gating.

## Jackson Killa — full character

- `id: "jackson"`, name **Jackson Killa**, price **3,600c** (new top of the ladder).
- Desc: "Drops a SENTRY TURRET that holds the line. Bonus damage & fire rate with Heavy weapons."
- Passive (weapon-conditional, `apply_weapon`): +25% damage, +15% fire rate when the equipped
  weapon's category is Heavy (`minigun`, `grenade_launcher`, `lmg` — the only category with no
  specialist).
- No always-on stat; dash is plain. His identity = turret + heavy guns.
- Sprite/select-panel treatment identical to the existing six (whatever the select panel currently
  renders per character; new art via the home-repo generator if the others have any).
- **Prereq shipping in this pack:** character-select scroll fix — `_char_vbox` gets a
  ScrollContainer (flagged at v0.1.54: select panel already at 1693/1920px; a 7th entry overflows).

## Architecture

- `scripts/logic/Abilities.gd` — NEW, `class_name`, autoload-free (probe-able like
  `Characters.gd`): registry mapping character id → ability id/name/cooldown/param dict (params
  read from GameConfig). Pure helpers only.
- `scripts/AbilityController.gd` — NEW node (child of Main or Player): owns the cooldown timer,
  receives button presses from Hud, dispatches per-ability cast functions that call existing seams
  (`Shockwave.blast`, `Enemy.apply_freeze`, `Gun.instant_reload`/`add_frenzy`, HazardZone
  configure, purge loop, ghost flag, turret spawn, time-scale).
- `scripts/Turret.gd` — NEW (SENTRY TURRET only).
- `scripts/HealthPack.gd` — NEW pickup (AIR DROP only; see design details).
- Touched: `Hud.gd` (button), `Player.gd` (ghost state; dash purge removal), `Enemy.gd` (ghost
  gates), `Juice.gd` (base_scale), `Characters.gd` (Jackson + desc updates), `MainMenu.gd`
  (char-select ScrollContainer), `GameConfig.gd` (ABILITY_* constants), SFX wiring.

## Verified engine seams (T0 facts)

| Seam | Location | Note |
|---|---|---|
| Projectile purge | `Player.gd:227 _purge_projectiles()` | iterates group `"enemy_projectiles"` |
| Radial push | `Shockwave.blast(radius, damage, force, gun, player, hit_destructibles=false)` | verify damage=0 + gun=null path in plan T0 |
| Drone fire | `Companion.gd:254 _fire_drone_shot` → `CompanionBullet.new()` | talent-free |
| Freeze | `Enemy.gd:286 apply_freeze(duration)` | |
| Frenzy | `Gun.gd:180 add_frenzy(pct, duration)` | |
| Instant reload | `Gun.gd:325 instant_reload()` | |
| Time scale | `Juice.gd` (`JUICE_HITSTOP_SCALE 0.05`, restores 1.0 today) | becomes base_scale-aware |
| Hazard pools | `HazardZone.configure_hazard(cfg)` — dps/hurts_player/windup/immune | Janitor slick node reused for CLOSING TIME |
| Per-kill coin bonus | Blood Moon per-kill idiom (v0.1.50) + `Characters.coin_per_kill_bonus` | JACKPOT/CLOSING TIME windows |
| Taunt (contrast) | `Enemy.gd:326 taunt(node, duration)` | ONE OF THEM is a new inverse gate, not taunt reuse |
| Char select | `MainMenu.gd:457 _char_vbox` | ScrollContainer prereq |

## Testing

- Pure probes (boot-scene runner per the v0.1.60 lesson): Abilities registry completeness (all 7
  ids resolve, cooldowns > 0), cooldown state machine (cast → cooling → ready), JACKPOT roll
  distribution (4 outcomes, ~equal over 4k rolls), ghost-gate truth table (regular/elite ignore,
  boss unaffected), Jackson heavy-perk applies on exactly minigun/grenade_launcher/lmg.
- Boot gate: editor-quit AND headless Main.tscn boot, `SCRIPT ERROR|PARSE ERROR` count 0
  (mandatory gate addition from v0.1.57).
- Phone F5 checklist: button never moves/dashes when mashed; DEAD EYE never leaves the game slowed
  (pause during it, die during it, quit during it); CLEAR OUT wipes a spitter volley visibly;
  turret expires in basement; 7-character select scrolls.

## Out of scope

- Ability upgrades/levels, second ability slots, ability-specific relics or benefits tracks.
- Coworker/companion interactions beyond reusing CompanionBullet.
- Rebalancing existing character passives (only Ryan's desc/dash change as specified).

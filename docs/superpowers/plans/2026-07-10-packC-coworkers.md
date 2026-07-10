# Pack C: Coworkers (v0.1.64) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Companions with the game's RNG DNA: STAFF FILE purchases (800c) pull a coworker (STORE CAT / DELIVERY DRONE / FLOOR MANNEQUIN) with a rarity + trait; one equips at a time and fights alongside the player.

**Architecture:** Pure `Coworkers.gd` registry (types, rarity scaling, traits, roll) + save plumbing; a new `taunt` seam on Enemy (the pack's one new enemy-side mechanic); a `Companion.gd` runtime node (+ per-type behavior + `MannequinDecoy`); store row + reveal + STAFF inventory section; 32px sprites.

**Sanctioned spec divergence (controller-adjudicated):** the spec said pulls "open on the existing reel", but `CrateOpener` is weapon-shaped throughout (`LootRoller.roll_from_crate`, `WeaponInstance.color`, `weapon_revealed`) — coworker pulls instead reveal via a dedicated popup + `crate_win` sting + confetti. The reel stays weapons-only.

**Tech Stack:** Godot 4.6 GDScript; home-repo sprite generator.

**Spec:** `docs/superpowers/specs/2026-07-09-roadmap-4-design.md` §Pack C.

## Global Constraints

- Runner env / boot-scene probes / MANDATORY DUAL GATE / literal-probe-output reports / .uid sidecar tracking / master-no-push: identical to Packs 0/A/E (`GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`; probes via `res://_probe.tscn`; new class_names need one `--editor --quit` cache pass; snapshot/restore `SaveManager._data` around save-mutating probes).
- Coworker instance shape (fixed): `{ "uid": String, "type": "cat"|"drone"|"mannequin", "rarity": int 1-9, "trait": String ("" below purple) }`.
- Traits roll ONLY at rarity ≥ 5 (purple+), one per coworker, from the 8-trait pool (Task 1).
- Bosses are immune to taunt BY CONSTRUCTION (taunt lives on Enemy; BossBase is a separate class — no code needed, but the plan says so where relevant).
- All numbers = `GameConfig.COWORKER_*` consts with ## comments (starter values).
- DRONE projectiles: raw damage, NO talent path, NO crit (deliberate — coworkers don't scale with gun talents).
- Every flavor string ≤ 70 chars, dim-ink = `PixelTheme.ACCENT.darkened(0.45)`.

---

### Task 1: `Coworkers.gd` registry + save plumbing

**Files:** Create `scripts/logic/Coworkers.gd`; Modify `scripts/SaveManager.gd` (DEFAULTS + accessors), `scripts/logic/GameConfig.gd`.

**Interfaces (produced, consumed by T3/T4):**
- `Coworkers.TYPES := ["cat", "drone", "mannequin"]`; `Coworkers.name_for(type) -> String` (STORE CAT / DELIVERY DRONE / FLOOR MANNEQUIN); `Coworkers.flavor(type) -> String` (cat: "she was here before you. she'll be here after." / drone: "the app says your order is 6 minutes away. forever." / mannequin: "it volunteered. don't ask how.").
- `Coworkers.TRAITS := ["sharp", "wired", "wide", "steady", "chilling", "pinning", "magnetic", "studious"]` + `trait_name/trait_desc(t)` (SHARP +25% damage / WIRED +20% attack rate / WIDE +25% radius-range / STEADY +30% mannequin HP & duration / CHILLING hits slow 25% for 1.5s / PINNING 15% pin chance 0.45s / MAGNETIC +40% coin pickup radius aura / STUDIOUS +10% player XP while alive — descs ≤ 70 chars, criterion-clear).
- `Coworkers.roll(rarity: int) -> Dictionary` (uid = `"cw_" + str(Time.get_ticks_usec())` idiom — VERIFY how LootRoller mints weapon uids and mirror; type uniform via `randi()`; trait only when rarity ≥ `COWORKER_TRAIT_MIN_RARITY` 5).
- Stat scaling (pure): `Coworkers.stat_mult(rarity) -> float` = `1.0 + (rarity - 1) * GameConfig.COWORKER_STAT_PER_RARITY` (0.18) — single curve all types share.
- `Coworkers.scrap_value(rarity) -> Array` = Rarity tier's scrap band halved (`[band[0]/2, band[1]/2]` ints, min 5).
- SaveManager: DEFAULTS `"coworkers": []` + `"equipped_coworker": ""`; accessors `coworkers()/set_coworkers(list)/equipped_coworker()/set_equipped_coworker(uid)` mirroring the weapons-list idiom exactly.
- GameConfig block: `COWORKER_CRATE_PRICE := 800`, `COWORKER_TRAIT_MIN_RARITY := 5`, `COWORKER_STAT_PER_RARITY := 0.18`, plus per-type bases (T3 consumes): `COWORKER_CAT_RATE := 4.0`, `COWORKER_CAT_DAMAGE := 40.0`, `COWORKER_CAT_RANGE := 500.0`, `COWORKER_CAT_PIN := 0.45`, `COWORKER_DRONE_RATE := 1.1`, `COWORKER_DRONE_DAMAGE := 9.0`, `COWORKER_DRONE_RANGE := 420.0`, `COWORKER_DRONE_ORBIT := 90.0`, `COWORKER_MANNEQUIN_CD := 12.0`, `COWORKER_MANNEQUIN_HP := 150.0`, `COWORKER_MANNEQUIN_TAUNT_RADIUS := 400.0`, `COWORKER_MANNEQUIN_TAUNT_TIME := 4.0`, each with a ## comment.

- [ ] Probe (RED first): TYPES size 3; roll(1) has empty trait ×20 draws; roll(9) trait non-empty ∈ TRAITS ×20; roll uid non-empty unique ×5; stat_mult(1)=1.0, (9)=2.44±0.001; scrap_value(9) = half of Rarity tier 9 band; save accessors round-trip (snapshot/restore); every flavor/desc ≤ 70 chars.
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(coworkers): registry, rarity scaling, traits, save plumbing`.

---

### Task 2: Enemy taunt seam

**Files:** Modify `scripts/Enemy.gd`.

**Interfaces (produced, consumed by T3's mannequin):**
- `Enemy.taunt(node: Node2D, duration: float) -> void` — sets `_taunt_node`/`_taunt_time` (refresh = maxf, like other status idioms in this file).
- While taunted and the node is valid: `_desired_velocity` steers toward the taunt node instead of `_target` (find the movement-target read in `_desired_velocity` ~line 484 and the base `_physics_process` velocity math ~line 437-447 — the taunt substitution must survive subclass overrides the way frozen/fear do: apply at the BASE class chokepoint, read how fear was enforced there and mirror); contact with the taunt node (distance ≤ the same contact idiom used vs the player — read `_touching_player` and the `_contact_cd` block ~line 471) deals `touch_damage` to it via `node.take_damage(dmg)` `has_method`-guarded, keeping the player-contact path untouched when not taunted.
- Expiry/invalid: countdown in `_physics_process`; freed node → immediate clear. Frozen/pinned/feared still outrank (velocity zero / flee win — insert the taunt read where fear already resolved).
- RangedEnemy: taunted ranged enemies fire at the taunt node if trivially wirable via the same `_target` substitution; if their fire path hard-codes the Player type, leave them player-targeting and note it (spec: mannequin taunts "enemies within radius" — melee-only is acceptable v1; REPORT which).

- [ ] Probe (RED): stub Node2D with `take_damage` recorder; `e.configure({max_health: 100, move_speed: 80, touch_damage: 10})`; `e.taunt(stub, 4.0)`; assert internal state set + expiry after simulated countdown (drive `_physics_process` manually with `set_physics_process(false)` — off-tree may crash on group/tree calls: add the enemy to the probe tree, disable processing, drive manually; restore any autoload state).
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(coworkers): Enemy.taunt seam — movement + contact retarget, status-outranked`.

---

### Task 3: Companion runtime

**Files:** Create `scripts/Companion.gd`, `scripts/MannequinDecoy.gd`, `scripts/CompanionBullet.gd` (only if the existing Bullet can't fire talent-free — VERIFY: can `Bullet` be spawned with a null/zero talent payload? read how Gun spawns it; if a bare kinematic bullet is simpler, make CompanionBullet a ~40-line straight-line Area2D-free mover using the distance-hit idiom). Modify the spawn-config pass (`Characters.apply_base` caller in Main.gd) to instantiate the Companion when `SaveManager.equipped_coworker() != ""`.

**Interfaces:**
- `Companion.configure(inst: Dictionary)` — reads type/rarity/trait; all stats × `Coworkers.stat_mult(rarity)`; trait effects applied per T1's table (CHILLING/PINNING ride the attack; WIDE scales range/radius; SHARP damage; WIRED rate; STEADY mannequin only; MAGNETIC = aura that widens the player's pickup radius — find how coin/gem magnetism works (grep `magnet|pickup_radius` — v0.1.54 Delivery Girl has +20% pickup; reuse HER mechanism); STUDIOUS = `player.xp_mult *= 1.10` on spawn (undone never — run-scoped, fine).
- Behaviors (all `_physics_process`, hover-follow the player at ~120px offset, no collision):
  - CAT: every `COWORKER_CAT_RATE / rate_mult`s, dash-line to the nearest enemy within `COWORKER_CAT_RANGE` (LoS-free), `take_damage(dmg)` + `apply_pin(COWORKER_CAT_PIN)` `has_method`-guarded (+ trait pin/slow riders), snap back over 0.3s. Draw: sprite flip toward motion.
  - DRONE: orbit `COWORKER_DRONE_ORBIT`px, every `1/rate`s fire at nearest enemy in range: straight projectile, raw `take_damage`, no talents/crit (Global Constraints).
  - MANNEQUIN: every `COWORKER_MANNEQUIN_CD`s place a `MannequinDecoy` at the player's position: HP (STEADY-scaled), calls `Enemy.taunt(self, TAUNT_TIME)` on "enemies"-group members within TAUNT_RADIUS every 0.5s tick while alive (re-taunt keeps aggro), `take_damage` → HP, death = small shatter draw + free. Cap 1 alive (placing frees the old).
- Companion node itself: untargetable (no groups), indestructible, PROCESS_MODE_INHERIT (pauses with tree).

- [ ] Probe: pure seams — `Coworkers.stat_mult` already covered; assert Companion script class exists + `MannequinDecoy` HP math via direct instantiation with processing disabled; the behavioral loop is review+F5 (state this).
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(coworkers): Companion runtime — cat pounce, drone orbit, mannequin taunt decoy`.

---

### Task 4: STAFF FILE purchase + STAFF inventory section

**Files:** Modify `scripts/MainMenu.gd` (store row + reveal + STAFF section), possibly `scripts/ui/WeaponDetailPopup.gd` or a new small `CoworkerDetailPopup` (judgment: reuse if the popup's layout tolerates a non-weapon; otherwise a lean new popup — REPORT which).

**Interfaces:**
- Store: STAFF FILE row (800c via `COWORKER_CRATE_PRICE`, desc "personnel are a renewable resource. hire someone.") in `_populate_store` after the crates, `_guarded` buy → spend coins (mirror the crate-buy spend idiom + sounds) → `Coworkers.roll(Rarity.roll(1, Rarity.MAX_ID))` (VERIFY `Rarity.roll(floor, ceil)`'s real signature from LootRoller usage) → append to `SaveManager.coworkers()` list + save → reveal popup: coworker sprite (or type glyph pre-T5), NAME + rarity color frame + trait line, `crate_win` sting + confetti idiom (grep `_confetti|burst` in MainMenu for the existing celebration call).
- STAFF section in the inventory page (below crates section — find how the crates section renders in `_populate_inventory` and mirror): coworker tiles (type glyph + rarity border via `Rarity` color; `Rarity.is_animated` tiers repaint like weapon tiles — reuse that refresher if trivial, else static cyan fallback per the Molten precedent, REPORT which); tap → detail popup: name/flavor/trait/stats summary + EQUIP (sets `equipped_coworker`, one at a time, re-tap = UNEQUIP to "") + SCRAP (pays `Coworkers.scrap_value(rarity)` roll in coins + the Pack-A scrap byproduct via the same formula deconstruct uses — reuse `Inventory.deconstruct`'s scrap math shape, do NOT route through Inventory (coworkers aren't weapons); guard: scrapping the equipped coworker unequips first).
- Equipped indicator on the tile (mirror the equipped-weapon tile marker).

- [ ] Probe: seeded save — roll+append+equip+scrap round-trip through the SaveManager accessors (snapshot/restore); scrap payout within the halved band; scrapping equipped clears `equipped_coworker`.
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(coworkers): STAFF FILE store pull, reveal, STAFF inventory section, equip/scrap`.

---

### Task 5: Sprites (home generator → game art)

**Files:** Modify `/home/larryun/gen_palette_sprites.py`; generated: `art/coworkers/cat.png|drone.png|mannequin.png` (32px) + `art/crates/staff_file.png` (match existing crate-icon canvas — read a `_build_crate_*` function for the size/idiom).

- Builders (mirror the enemy/boss builder helpers; palette C1-C4; features read at a glance: CAT = low silhouette + tail + C4 eye glints; DRONE = C2 rotor bar + C3 body + C4 lens; MANNEQUIN = armless torso on a pole base + blank C1 head; STAFF FILE crate = folder/clipboard motif + paw stamp).
- Wire: `Companion`/tiles load `res://art/coworkers/<type>.png` with a code-drawn glyph fallback when missing (the BossBase `_sprite_loaded` idiom, so T3/T4 don't hard-depend on this task's PNGs).
- Implementer does Steps: builders + regenerate + boot-spawn check; controller does the contact-sheet/at-size visual QA before commit (STOP after generation, report paths).
- [ ] Commit (after controller QA): game `art(coworkers): cat/drone/mannequin 32px + staff file icon`; home repo generator commit.

---

### Task 6: Ship v0.1.64 (controller task)

- [ ] Fable whole-branch review (base = v0.1.63 ship commit `be025c6`); one fix dispatch; Minor triage. Special attention: taunt vs frozen/fear/pin interactions, Companion perf (per-frame group scans), MAGNETIC/STUDIOUS stacking with cards, save migration, daily determinism (Coworkers.roll uses unseeded randi — menu-side only, verify no in-run seeded path consumes it).
- [ ] `VERSION` → `0.1.64`; CHANGELOG entry (title: **New Hires (Night Crew)** — voice per the pack); push, CI green, stamp check, tag, release with APK.
- [ ] Ledger + memory + roadmap-4 wrap-up. F5 checklist: pull feel + reveal drama; cat pounce/pin readability; drone dps sanity; mannequin actually peels a horde (the taunt seam live); trait effects visible; equip/unequip/scrap flows; basement + coworker interaction (companion teleports with player? verify on device); Karen decoys + mannequin coexist.

## Self-review notes (applied)

- Spec §Pack C coverage: registry/traits/roll (T1), taunt = the flagged highest-risk mechanic isolated in its own task (T2), runtime + 3 kits (T3), acquisition/UI (T4 — reel divergence sanctioned and documented), sprites with fallback decoupling (T5).
- Type consistency: instance dict shape, `Coworkers.*` signatures, GameConfig names checked across tasks.
- Verify-first directives on every judgment point (uid mint, Rarity.roll signature, magnet mechanism, popup reuse, crate-icon canvas).

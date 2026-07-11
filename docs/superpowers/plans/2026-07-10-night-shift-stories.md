# Night Shift Stories (v0.1.68) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two bench bosses (MYSTERY SHOPPER concealed/re-cloaking; THE MASCOT shedding/accelerating — roster 11) + the VISITORS event class (ICE CREAM TRUCK mid-run shop with the game's first mid-run coin spending, CRYPTID bounty, DRIVE-BY lane).

**Architecture:** An opt-in `concealed` state on BossBase (has_method-guarded HUD/toast gating — the existing 9 bosses stay byte-identical); Mascot = phase-driven scale/speed/pattern ladder with per-instance collision-shape duplication; `Visitors.gd` controller (Basement roll idiom, seeded gate-first) driving three visitor implementations; `RunStats.spend_run_coins` + a SNACKS pre-mult deduction through the CoinReward chokepoint (both twins for free).

**Tech Stack:** Godot 4.6 GDScript; home generators for 5 sprites + 3 WAVs.

**Spec:** `docs/superpowers/specs/2026-07-10-night-shift-stories-design.md` (approved).

## Global Constraints

- Runner env / boot-scene probes (never `--script`; new class_name → editor cache pass) / MANDATORY DUAL GATE per task with the **case-insensitive parent-parity convention** (baselines 19 editor / 7 boot known XpGem noise — state both counts, yours must be ≤ parent) / **LITERAL RED+GREEN probe output + gate numbers** / probe files deleted, .uid tracked / master, NO push before ship. `GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`.
- Verified seams (re-verify locally as touched): HUD boss poll + `_boss_was_alive` toast edge at Hud.gd:214-224 (bar/name/toast must ALL gate on reveal); fear-flee vector math at Enemy.gd:473-478 (cryptid reuses the math in its own node — do NOT touch Enemy.gd); LevelUpUI `_rerolls_left` (:22/:34/:142-143 — needs a public `add_reroll_charge()`); **boss .tscn collision shapes are SubResources = SHARED across instances — Mascot MUST `shape = shape.duplicate()` before any resize** (scenes/bosses/*.tscn:8/22 pattern); `CoinReward.pre_mult_total(wave,bosses,kills,bonus)` (:32) + `final_payout(wave,bosses,kills,bonus,mult,signing_bonus,run_time)` (:59) — snacks threads through BOTH (deduct pre-mult; stub row keeps row-sum==TOTAL, the clawback complement precedent).
- Spec constants (verbatim starter values): `SHOPPER_REVEAL_DAMAGE 60`, strike range ~120px, `SHOPPER_HP 1800`, re-cloak at 0.66/0.33; `MASCOT_HP 2600`, scale ladder 1.15/0.9/0.7, speed 0.55/0.9/1.35; `VISITOR_CHANCE 0.20` wave≥4 gate-FIRST then `RunConfig.rand_float()` (Daily determinism — the Basement door precedent), max 1 active, `VISITOR_COOLDOWN 90`, ≤2/run, endless+horde only, no same-visitor repeat per run; `TRUCK_STAY 25`, `TRUCK_HEAL_COST 150` (30% max HP via Player.heal — hardcore shows disabled "NOT IN HARDCORE"), `TRUCK_REROLL_COST 200`, `TRUCK_RELIC_COST 400` (slot-A mix, never cursed, full bar → swap flow), 3-purchase cap; `CRYPTID_WINDOW 20`, `CRYPTID_HP 900`, `CRYPTID_COINS 250` + floor-mapped crate; `DRIVEBY_DPS 80`, 2s siren warning, 6s total, hits enemies AND player in-lane, car untargetable.
- All numbers = GameConfig consts with ## comments; copy ≤ 70 chars deadpan; palette strict; every static gameplay flag resets in _ready (the RelicEffects lesson); pause-contract on any SceneTreeTimer (process_always chosen deliberately + commented).

---

### Task 1: Concealed-boss seam + THE MYSTERY SHOPPER

**Files:** Modify `scripts/BossBase.gd` (opt-in concealed state), `scripts/Hud.gd` (bar/name/toast reveal-gating), `scripts/logic/Bosses.gd` (+row), `scripts/logic/Flavor.gd` (+line), `scripts/logic/GameConfig.gd` (SHOPPER_*); Create `scripts/bosses/MysteryShopper.gd`, `scenes/bosses/MysteryShopper.tscn` (Courier-clone shape).

**Interfaces:** BossBase gains `func revealed() -> bool: return true` (base default — existing bosses byte-identical) and NO other base behavior change. Hud gates bar+name+toast on `not boss.has_method("revealed") or boss.revealed()` — wait, every BossBase now HAS the method; gate simply on `(boss as BossBase).revealed()`. Toast edge: `_boss_was_alive` only sets (and the toast only fires) when a revealed boss is seen; a boss revealing LATER must still fire the toast exactly once (track the edge on "revealed boss seen", not "boss exists" — rename/add `_boss_was_revealed` carefully, preserving Boss Rush debounce comments). MysteryShopper: `revealed()` returns its state; disguise = leaves the .tscn's shared enemy texture + NO regalia while concealed (its real 48px sprite swaps in on reveal — `_setup_sprite` deferred to first reveal); reveal triggers per spec (cumulative `SHOPPER_REVEAL_DAMAGE` since last cloak OR player within 120px); re-cloak at phase edges via `on_enter` (shimmer draw + reposition to a rim point among live spawns + damage counter reset); concealed movement = trash-speed drift toward the player (speed_mult ~0.35), revealed = runner-class lunges (`CHARGE` short/low-cadence per spec). Taunt/pin immunity = class-free as all bosses.

- [ ] Probe (RED first): base `revealed()` true on a plain BossBase + every existing boss subclass (instantiate scripts, assert true — byte-identity); shopper starts unrevealed, reveals at cumulative 60 dmg, re-cloak resets the counter, count 11 after registry (this task = 10; assert 10 here, mascot makes 11 in T2 — assert 10), flavor line present, phase table well-formed. Gates at parent parity. Commit `feat(boss): THE MYSTERY SHOPPER — concealed-boss seam, reveal/re-cloak fight`.

---

### Task 2: THE MASCOT

**Files:** Create `scripts/bosses/Mascot.gd`, `scenes/bosses/Mascot.tscn`; Modify `scripts/logic/Bosses.gd` (+row → count 11), `scripts/logic/Flavor.gd` (+line), `scripts/logic/GameConfig.gd` (MASCOT_*).

**Interfaces:** Phase table per spec (L1 RING+SUMMON cadence 4.4 / L2 CHARGE+RING cadence 3.6 / L3 short CHARGE cadence 2.0); `on_enter` per shed phase: RING burst at the shed moment, **`$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()` ONCE in `_ready` (comment the SubResource-sharing trap)** then radius × the scale ladder per phase, `$Sprite2D.scale` likewise, speed via the phase `speed_mult` (0.55/0.9/1.35); texture swaps mascot_a/b/c when T5's art lands (ResourceLoader.exists fallback = tint-scale on the shared art — the staged idiom).

- [ ] Probe: count 11 + name_for; phases 3 / cadences / speed ladder; shape-duplicate assertion (two Mascot instances → resizing one's shape leaves the other's radius unchanged — THE trap probe); flavor line. Gates parent parity. Commit `feat(boss): THE MASCOT — shedding phases, accelerating duel`.

---

### Task 3: Visitors controller + CRYPTID + DRIVE-BY

**Files:** Create `scripts/Visitors.gd` (controller, Main.tscn sibling — Basement wiring idiom), `scripts/Cryptid.gd` (flee entity), `scripts/DrivebyLane.gd` (lane pattern node); Modify `scenes/Main.tscn`, `scripts/logic/GameConfig.gd` (VISITOR_/CRYPTID_/DRIVEBY_*), `scripts/Hud.gd` only if banner reuse needs nothing (use `_show_banner(text, sub)` — no HUD edits expected).

**Interfaces:** Visitors rolls on wave edges (NightEvents `_prev_wave` idiom + frame-1 sentinel — the Basement lesson), gate-FIRST (`wave ≥ 4`, mode endless|horde, none active, cooldown elapsed, count < 2, in_basement false — read Basement.in_basement via group) THEN `RunConfig.rand_float()`; visitor pick = seeded `RunConfig.rand_int() % remaining` (no repeats/run). CRYPTID: banner "SOMETHING IS IN THE LOT" + shimmer-drawn CharacterBody2D in "enemies" group (targetable) with flee steering (the Enemy.gd:473-478 vector math, reimplemented locally), `CRYPTID_HP 900` via a Health pool, despawn at `CRYPTID_WINDOW` (banner "IT'S GONE"); death → `CRYPTID_COINS` via RunStats.add_coins + `SaveManager.add_crate(BasementLogic.crate_id_for(wave))` + save (the basement chokepoint) + banner "NOBODY WILL BELIEVE YOU". Verify cryptid in "enemies" doesn't break kill counters/talents (it's a legit kill — on_kill hooks firing is FINE, note it) and the basement straggler sweep frees it if stranded (it's in "enemies" — automatic). DRIVE-BY: siren WAV (T5; play the id now, file lands later — SoundManager tolerates? VERIFY: missing WAV behavior — if it errors, gate the play on the stream existing and note) + 2s AimedBand-style lane telegraph across the arena through the player's position snapshot, then the car sprite crosses at high speed dealing `DRIVEBY_DPS`-scaled ticks to "enemies" AND the player while in-lane (HazardZone-style 5Hz ticks over a moving band, or a band + sweep — implementer picks the simpler using the AimedBand internals as reference; car untargetable Node2D).

- [ ] Probe: gate-first roll invariants (all gates enforced; rand consumed only when gates pass — the Basement precedent probe shape); no-repeat pick; cryptid reward math via seams; driveby lane damage tick math on stubs (player + enemy in/out of lane). Gates parent parity. Commit `feat(visitors): controller + THE CRYPTID + THE DRIVE-BY`.

---

### Task 4: THE ICE CREAM TRUCK + mid-run spending

**Files:** Create `scripts/IceCreamTruck.gd` (prop + arrival/departure + shop zone), `scripts/ui/TruckShop.gd` (paused 3-button overlay, RelicChoice UI idiom); Modify `scripts/Visitors.gd` (truck = third visitor), `scripts/RunStats.gd` (`snacks_spent` + `spend_run_coins`), `scripts/logic/CoinReward.gd` (snacks deduction pre-mult in BOTH pre_mult_total-derived displays and final_payout — thread a `snacks: int` param or read RunStats directly INSIDE like weapon_xp_payout does — prefer the internal read, the twin-proof pattern), `scripts/GameOver.gd` (SNACKS −N stub row before TOTAL when > 0), `scripts/LevelUpUI.gd` (`func add_reroll_charge() -> void: _rerolls_left += 1; _update_reroll_button()` — verify the update call name), `scripts/logic/GameConfig.gd` (TRUCK_*).

**Interfaces:** Truck drives in on a lane (straight-line mover), parks `~600px` from the player, `TRUCK_STAY 25`s, jingle loops (T5 WAV — same missing-file guard as T3), stand-in-zone (door-ring idiom) opens TruckShop: HEAL SCOOP (30% max HP via `player.heal` — in hardcore the button is disabled labeled "NOT IN HARDCORE"; heal's no-op makes it safe anyway), SECOND OPINION TO GO (`LevelUpUI.add_reroll_charge()` via group/scene lookup), MYSTERY FLAVOR (slot-A relic roll — reuse `Relics`' A-mix helper; grant via the bar's take path; full bar → RelicChoice's swap flow — reuse, don't fork; if reuse is tangled, a simple "bar full — no flavors for you" disabled state is the sanctioned fallback, REPORT which). `RunStats.spend_run_coins(cost) -> bool`: spendable = `CoinReward.pre_mult_total(wave, bosses, kills, bonus)` at current stats minus `snacks_spent`; false+deny if short; success increments `snacks_spent`. Deduction: pre-mult inside final_payout (and the PAYDAY pre-mult record must ALSO subtract snacks — the badge measures what you banked; verify the recording sites read the net value — thread consistently and REPORT). 3-purchase cap → early departure honk.

- [ ] Probe: spend_run_coins math (afford/deny/accumulate); final_payout with snacks — row-sum==TOTAL sweep incl. clawback+vested cases; PAYDAY net-of-snacks; reroll grant seam; hardcore scoop disable state (pure read). Overlay = review+F5. Gates parent parity. Commit `feat(visitors): ICE CREAM TRUCK — mid-run shop, spend_run_coins, SNACKS stub row`.

---

### Task 5: Sprites + WAVs (home generators; controller QA gate)

**Files:** Modify `/home/larryun/gen_palette_sprites.py` (shopper 48px [sunglasses + shopping basket, NO undead notching], mascot_a/b/c 48px [full suit → half suit → tiny performer — same character shrinking, distinct at a glance], truck 64×32 [box van + serving window + C4 cone glyph], police_car 64×32 [light bar]) — NOTE the sheet's boss row auto-includes registry-listed bosses only if BOSS_SPRITES rows are added (add shopper + mascot_a; the b/c variants + vehicles need ad-hoc QA tiles — compose a /tmp sheet); Modify `/home/larryun/gen_retro_audio.py` (`truck_jingle` ~2s loopable melody, `truck_honk` ~0.5s, `driveby_siren` ~1.5s) + SoundManager ids + regenerate.
- Implementer generates + boot-checks + STOPS (controller visual QA before commit, both repos after approval).
- [ ] Commit game `art(nss): shopper, mascot x3, truck, police car + 3 SFX` + home commits.

---

### Task 6: Ship v0.1.68 (controller task)

- [ ] Fable whole-branch review (base = v0.1.67 ship `5971f66`). Attention: concealed-boss byte-identity across the existing 9 (the release's #1 regression risk); HUD toast/bar edges in Boss Rush with a concealed boss in rotation; mascot shape duplication under Boss Rush re-spawns; visitor rolls × basement suspension × dawn lockout; snacks × clawback × vested ordering + both twins; truck shop × every paused overlay; cryptid in "enemies" × sweeps/taunts/coworkers; missing-WAV guards.
- [ ] Fix wave; `VERSION` → `0.1.68`; CHANGELOG "**v0.1.68 — Night Shift Stories**"; push, CI, stamp, tag, release; ledger + memory.
- [ ] F5: shopper re-find fun factor; mascot pacing; truck spend-vs-bank dilemma + SNACKS row math; cryptid chase; drive-by dodge; roster-11 rotation sanity.

## Self-review notes (applied)

- Spec §1→T1, §2→T2, §3 controller/cryptid/driveby→T3, truck→T4, §4 plumbing split across T1-T5, §5 verification consumed into Global Constraints + verify-first directives, §6→T6.
- The four named traps are baked in: SubResource shape sharing (T2 probe), reveal-edge toast (T1), gate-first seeded rolls (T3), snacks in the PAYDAY measure (T4).
- Type consistency: `revealed()`, `spend_run_coins`, `add_reroll_charge`, const names checked across tasks.

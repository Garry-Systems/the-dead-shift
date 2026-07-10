# Relics Overhaul "Lost & Found" (v0.1.66) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relics go from 8 stat sticks to 27 relics in 3 families with a pick-1-of-2 choice moment (cursed bargains opt-in), mid-run scrapping, and 10 run-rule PROTOTYPE effects.

**Architecture:** `Relics.gd` keeps the reversible stat contract and gains family/hook metadata; a new run-scoped `RelicEffects.gd` owns PROTOTYPE/CURSED hooks bound to verified existing chokepoints (each hook fully reversible); `RelicChoice.gd` is the paused two-card overlay (LevelUpUI idiom); RelicPickup opens the choice; RelicMenu gains SCRAP; RelicBar renders 6 slots under overstocked.

**Tech Stack:** Godot 4.6 GDScript.

**Spec:** `docs/superpowers/specs/2026-07-10-relics-overhaul-design.md` (approved; relics are RUN-SCOPED — no save migration).

## Global Constraints

- Runner env / boot-scene probes (never `--script`; new class_name → one `--editor --quit` cache pass) / MANDATORY DUAL GATE per task (editor-quit grep 0 + Main.tscn boot grep 0; log-redirect if the pipe hangs) / **LITERAL RED+GREEN probe output + gate numbers in every report** / delete probe files, track new .uid sidecars / master, NO push before ship: identical to the last three packs. `GODOT="$(find /tmp/godot46 -name '*console.exe' | head -1)"; PROJ='C:\Users\thela\Documents\mobile-game'`.
- **Verified hook facts** (from pre-plan verification — implementers may rely on these, re-verify locally before use): `DifficultyManager.run_time += delta` at DifficultyManager.gd:32 (single accumulator; ShiftClock + waves + dawn are pure math over it → a hold freezes ALL of them coherently); `Player._on_dash_started()` at Player.gd:203; `Player.heal(amount)` single choke at :403; `Enemy.apply_fear(duration)` at Enemy.gd:314; Gun pierce idiom = `base_pierce` + `_surge_pierce` bonuses (Gun.gd:17/60); `DifficultyManager.set_elite_chance_mult(m)` at :57 (Extraction also drives it — COMPOSE, never clobber; verify how Extraction sets/restores and stack multiplicatively); `RunStats.kills/elites_killed` counters exist.
- Spec constants (verbatim): `RELIC_CURSED_CHANCE 0.35` (slot B only, NEVER slot A), `RELIC_SKIP_COINS 75`, `RELIC_DRY_COINS 150`, `RELIC_SCRAP_COINS 100`, `RELIC_CURSED_SCRAP_COINS 25`, slot-A mix 60% STANDARD / 40% PROTOTYPE; `MAX_RELIC_SLOTS` stays 4; overstocked bar 4→6; **dead_mans_vest NEVER offered in HARDCORE** (`RunConfig.hardcore`); no duplicates of held relics ever offered; full-bar take → swap flow (scrap one first, its scrap value pays).
- Reversibility is a hard invariant: for every relic, apply→remove leaves every touched stat/flag bit-identical (probe asserts round-trips). Cursed included.
- All numbers = GameConfig `RELIC_*` consts with ## comments (starter values); descs ≤ 70 chars, lowercase deadpan (authored copy in T1/T3 is binding); palette-strict (cursed card = INVERTED frame: C4 border on C1 fill + ⚠ glyph — no new colors).

---

### Task 1: Pool expansion — `Relics.gd` data + consts

**Files:** Modify `scripts/logic/Relics.gd`, `scripts/logic/GameConfig.gd`.

**Interfaces (produced):**
- Every relic row gains `"family": "standard"|"prototype"|"cursed"` and (prototype/cursed only) `"hook": String` (the RelicEffects hook id = the relic id) + `"desc"` stays the display line. STANDARD rows keep the existing apply/remove modes; the two new standards: `tip_jar` (RunStats.coin_mult ×(1+RELIC_TIP_JAR_PCT 0.15), mode "special" — reversal = divide the ratio back; mirror the pct-ratio idiom), `punch_card` (weapon-XP mult — find the run-scoped weapon-XP path (WeaponInstance.apply_xp / a RunStats mult?) and add a clean multiplicative field with ratio reversal; report the choke found).
- New statics: `Relics.family_of(id) -> String`, `Relics.pool(family: String, held: Array, hardcore: bool) -> Array` (un-held ids of that family; excludes `dead_mans_vest` when hardcore), `Relics.roll_choice(held: Array, hardcore: bool) -> Array` → `[a_id, b_id]` (A: 60/40 standard/prototype; B: RELIC_CURSED_CHANCE cursed else A-mix; never dupes of held OR of each other; degraded returns: 1 id when pools thin, [] when empty).
- PROTOTYPE/CURSED rows (ids/names/bargains per the spec tables §3 — copy the spec's names verbatim; write descs ≤ 70 chars in the deadpan voice, e.g. static_soles: "dash leaves a live wire. don't ask which regulation this violates.") — 10 + 7 rows, `"mode": "hook"` so the legacy apply() ignores them (RelicEffects owns them; add a guard: `apply()` on a hook-mode row push_warns + no-ops).
- GameConfig `RELIC_*` block: the spec's §1/§2 constants + per-relic magnitudes: `RELIC_TIP_JAR_PCT 0.15`, `RELIC_PUNCH_CARD_PCT 0.20`, `RELIC_STATIC_TRAIL_DPS 20.0`, `RELIC_STATIC_TRAIL_DUR 1.0`, `RELIC_DOUBLE_FUSE_PCT 0.5`, `RELIC_DOUBLE_FUSE_DELAY 0.3`, `RELIC_MAGNET_STREAK 5`, `RELIC_MAGNET_WINDOW 3.0`, `RELIC_INTERCOM_FEAR 1.5`, `RELIC_ACCELERANT_PCT 0.25`, `RELIC_TIMECLOCK_HOLD 10.0`, `RELIC_SPARE_GEMS 1`, `RELIC_SPARE_COIN_CHANCE 0.10`, `RELIC_RUBBER_MOVE_PCT 0.05`, `RELIC_ADRENAL_REFUND 2.0`, `RELIC_CHAIN_PIERCE 1`, `RELIC_STAPLER_DMG_PCT 0.40`, `RELIC_STAPLER_HEAL_FACTOR 0.5`, `RELIC_DRINK_SPEED_PCT 0.25`, `RELIC_DRINK_HP_LOSS 30.0`, `RELIC_DRINK_HP_FLOOR 40.0`, `RELIC_CARD_COIN_MULT 2.0`, `RELIC_CARD_STUB_CUT 0.25`, `RELIC_PACT_HEAL_PER_KILL 1.0`, `RELIC_NAMETAG_ELITE_MULT 1.5`, `RELIC_NAMETAG_GEM_MULT 2.0`, `RELIC_OVERSTOCK_SLOTS 2`, `RELIC_OVERSTOCK_HP_LOSS 20.0`, `RELIC_VEST_HEAL_CAP 0.5` — each ## commented.

- [ ] Probe (RED first, boot scene): pool sizes 10/10/7; every row has family (+hook for non-standard); descs ≤ 70; `roll_choice` invariants over 300 draws (no held dupes, A never cursed, B cursed ≈ 35%±7, no A==B, hardcore never offers dead_mans_vest); standard reversibility round-trips on a stub (glass_edge + tip_jar apply→remove bit-identical); hook-mode apply() no-ops with warning.
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(relics): 27-relic pool — families, hooks, choice roll, consts`.

---

### Task 2: `RelicEffects.gd` — the 17 hook implementations

**Files:** Create `scripts/RelicEffects.gd` (run-scoped node, added to Main.tscn as a plain sibling — mirror the Basement node wiring); Modify (small seams only, each behind a default-off check): `scripts/Gun.gd` (`bonus_pierce` run field folded where `base_pierce`/`_surge_pierce` combine — mirror that idiom), `scripts/Enemy.gd` (accelerant: in `take_damage`, `if _burn_time > 0.0 and RelicEffects.accelerant: amount *= (1.0 + GameConfig.RELIC_ACCELERANT_PCT)` — RelicEffects exposes STATIC flags for hot-path reads, set/cleared by the instance), `scripts/DifficultyManager.gd` (`time_hold: float`; `_process` decrements the hold before advancing run_time), `scripts/Player.gd` (heal-factor + heal-cap + kill-heal via the single heal choke + a `healing_disabled_except_kills` flag; hurt-hook callback for adrenal_valve; slow-immunity flag consumed where slow stacks apply; dash hook via `_on_dash_started`), `scripts/Destructible.gd` (double_fuse: after a hazard burst, schedule ONE damage-only Shockwave at 50% after the delay — `hit_destructibles=false` and NO light_fuse from the echo, the v0.1.36 recursion lesson), `scripts/CoinReward.gd` (company_card stub cut post-mult — the vested-signing precedent), boss-kill hook for overtime_clock + intercom's elite-death hook + spare_parts' loot hook + magnet_coil's streak (RelicEffects listens where kills/elite-kills/crate-deaths are counted — find each counter's bump site and call the hook there, default no-op one-liners).

**Interfaces (produced):** `RelicEffects.equip(id)` / `RelicEffects.unequip(id)` (idempotent, reversible; called by the bar/choice/scrap flows); static hot-path flags (`accelerant`, `slow_immune`, `healing_factor`, ...) documented per hook; `RelicEffects.instance` static (CombatText idiom) so seams call `RelicEffects.on_kill()` etc. as safe no-ops when absent.
Also: `dead_mans_vest` cheat-death inserts in the death path AFTER UNION REP and BEFORE Second Wind (order: vest is per-boss-cycle — track `_vest_ready` reset on boss kills), `cursed_nametag` composes `set_elite_chance_mult` multiplicatively with Extraction's surge (read how Extraction sets/restores; keep a compose contract — product of both sources, restore on unequip), `overstocked` calls the bar's slot-count setter (T4 provides; stub via `has_method` until then).

- [ ] Probe (RED first): equip/unequip round-trips for every hook id (flags/fields return to defaults bit-identical); accelerant math on an Enemy stub with burn; time_hold freezes run_time for exactly N simulated seconds; double-fuse echo is damage-only (no fuse lit on a neighbor stub); vest ordering asserted structurally (read the death path in the probe via source text if runtime is impractical — say so). Behavioral loops (streak magnet pull, trail spawning) = review+F5 (state it).
- [ ] Implement; probe GREEN; gates 0/0; commit `feat(relics): RelicEffects — 17 reversible prototype/cursed hooks on verified chokepoints`.

---

### Task 3: RELIC CHOICE overlay + pickup rewire

**Files:** Create `scripts/ui/RelicChoice.gd` (+ registration in whatever builds per-run HUD/UI — mirror how LevelUpUI lives in Main.tscn); Modify `scripts/RelicPickup.gd` (opens the choice instead of auto-applying), `scripts/RelicBar.gd` (take/swap entry).

**Interfaces:** RelicChoice.open(a_id, b_id) — pauses (PROCESS_MODE_ALWAYS, LevelUpUI idiom incl. paused-input inheritance), two PixelTheme cards (name/family tag/desc); cursed card = inverted frame (C4 border, C1 fill, ⚠ glyph, family tag "CURSED"); SKIP button pays `RELIC_SKIP_COINS` to run coins; empty-pool pickup pays `RELIC_DRY_COINS` (no overlay); full-bar take → swap flow: the overlay swaps to "pick a relic to scrap" (4 held cards, scrap value labels, cursed scrap 25), then applies the new relic. Wire `Relics.roll_choice(held, RunConfig.hardcore)` at pickup collection. Boss Rush uses the same flow at its existing chance.

- [ ] Probe: pure seams (roll_choice already T1; swap-flow bookkeeping via a pure helper if extracted); UI = review+F5. Gates 0/0. Commit `feat(relics): pick-1-of-2 RELIC CHOICE overlay, skip/dry payouts, full-bar swap`.

---

### Task 4: SCRAP in the RelicMenu + 6-slot bar + copy pass

**Files:** Modify `scripts/RelicMenu.gd` (SCRAP button per held relic → coins by family + `RelicEffects.unequip`/`Relics.remove` + slot freed), `scripts/RelicBar.gd` (`set_slot_count(n)` — overstocked 4→6 rendering; verify the bar's draw is slot-count-driven or fix it to be), `scripts/Hud.gd` only if the bar's HUD anchor needs width (report).

- [ ] Probe: scrap bookkeeping (coins paid by family, slot freed, effect reversed — reuse T2's round-trip helper); set_slot_count(6) state. UI = review+F5. Gates 0/0. Commit `feat(relics): mid-run scrapping + overstocked 6-slot bar`.

---

### Task 5: Ship v0.1.66 (controller task)

- [ ] Fable whole-branch review (base = v0.1.65 ship commit `14efad2`). Special attention: reversibility under stacking (relic + upgrade cards on the same stat — the pct-ratio drift contract), choice overlay vs LevelUpUI both paused (queued level-up during a relic choice?), time_hold vs basement clock + dawn lockout + extraction (all run_time-derived — coherent by design, verify no consumer caches dawn), company_card stub cut vs vested signing bonus ordering, nametag × extraction elite-mult compose, HARDCORE matrix (stapler/pact/vest text truth), Boss Rush relic flow, forecourt/locations orthogonality.
- [ ] One fix dispatch; Minor triage. `VERSION` → `0.1.66`; CHANGELOG "**v0.1.66 — Lost & Found**" (voice: the back room had a box). Push, CI green, stamp check, tag, release with APK; ledger + memory.
- [ ] F5: the choice moment feel; cursed pick temptation rate; scrap usage; Broken Timeclock power; blood_pact long-run; overstocked bar on-screen; per-relic proc visibility.

## Self-review notes (applied)

- Spec §1 (choice/skip/dry/swap) → T3; §2 (scrap) → T4; §3 pool → T1 (data) + T2 (behavior); §4 engine → T2/T3/T4; §5 verification consumed into Global Constraints verified-facts + per-task verify-first; §6 testing → per-task probes + T5 review. Hardcore vest exclusion in T1's roll + probe.
- Timeclock design confirmed against code (single run_time accumulator, pure derivations) — no fallback needed; noted for T5's cache check.
- Type consistency: family/hook row fields, `roll_choice(held, hardcore)`, `RelicEffects.equip/unequip`, `set_slot_count` consistent across tasks.

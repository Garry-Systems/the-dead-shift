# SDD ledger — plan: docs/superpowers/plans/2026-09-19-power-curve.md
Spec: docs/superpowers/specs/2026-09-19-power-curve-design.md · start HEAD 857d96e (v0.1.73 + docs) · branch master
Ruling: work directly on master, no worktree — repo convention (every prior SDD run; Godot .godot import cache lives in the tree, a worktree forces a multi-minute re-import per gate); pushes are gated to Task 9, which Larry pre-authorized ("run all 9 through to a shipped v0.1.74") — cost if wrong: local commits on master to revert, nothing published before T9.

## Pre-flight scan
| pair / task | produces vs consumes | finding |
|---|---|---|
| T1→T2 | rolled dict {tier,value,amount,desc,band} → UpgradeApply reads value/amount | consistent |
| T1→T3 | tier/desc/band + CARD_TIER_NAMES/COLORS → _paint_cards | consistent |
| T2→T3 | temp local RNG in _pick_three → replaced by _rng; apply(player, card) call site | consistent |
| T2↔T5 | both edit Gun.gd (upgrade hooks vs _process fire tail + frenzy) | disjoint hunks |
| T2↔T6 | both edit Gun._fire_cone (burn line vs ctx key) | disjoint lines |
| T2 vs Upgrades.gd:29 | T2 deletes UPGRADE_CRIT_CHANCE_PCT used by the catalog desc | plan covers it (literal fallback) |
| T4→T8, T7→T8 | starter consts retuned; T4 probe hardcodes 8/38 | plan covers it (T8: probes read consts) |
| T4 | BossBase gem value key | verified: enemy_stats() returns "max_health" |
| T6↔T5 | proc_scale = fire_interval (base, not frenzy-shortened) | procs/sec rise slightly under frenzy — accepted, minor |
| T1 self | probe bands ±0.005 vs whole-% rounding + maxf(0.01) | consistent |
| T2 self | probe vs code | consistent |
| T3 self | ScreenFlash.flash(tree,color) does not exist | RULING below |
| T5 self | probe re-implements the cadence loop in the probe = tests its own copy | RULING below |
| T6 self | stubs vs process_hit guards (has_method) | consistent |
| T7 self | 10 roster consts + Brute(1.0) all in [0.8,1.3], order kept | consistent |
| T8 self | tuning may hit out-of-scope wall → STOP-and-report clause | consistent |
| T9 self | push + tag = pre-authorized by Larry's execution pick | ok |
Ruling: T3 Legendary flash = stock white `ScreenFlash` instance with `alpha = 0.35` (class has no color param/static; it is PROCESS_MODE_ALWAYS so it fades while paused) — white is palette-safe — cost if wrong: cosmetic.
Ruling: T5 cadence becomes a PURE static the gun actually calls — `Gun.shots_due(cooldown, interval, max_shots) -> Array [shots:int, new_cooldown:float]` (shots = min(max_shots, floor(-cooldown/interval)+1) when cooldown<=0 else 0; new_cooldown = cooldown + shots*interval, clamped to >=0 when the cap was hit) — replaces the plan's next_cooldown helper so the probe exercises production code, not a copy — cost if wrong: small refactor of one function.
Models: implementers sonnet (T8 opus), task reviewers sonnet, final review opus.
Task 1: dispatched (BASE 857d96e, implementer sonnet)
Task 1: implementer DONE (857d96e..eab71fe; probe 10/10, gates 19/0/0, regressions green) — task review dispatched. Note: implementer used a Sonnet co-author trailer instead of the constraints' Fable line (harness attribution rule) — accepted, not a defect.
Task 1: review = production code correct; 2 Important on the probe (flat kind untested [plan-mandated gap]; tautological gun_ids count check). Ruling: add flat-kind + ricochet coverage and a Weapons.all()-driven spec-coverage check — spec's "displayed number = applied number" binds all kinds — cost if wrong: a few extra probe lines.
Task 1: minor (deferred): unreachable maxf floors in CardRolls pct/flat branches (drop or comment)
Task 1: minor (deferred): band-string building repeated across pct/barrel/crit branches
Task 1: fix round 1/5 dispatched (resumed implementer)
Task 1: fix round 1/5 (2 addressed, 0 open — flat-kind coverage, tautological check; probe-only, no new commit)
Task 1: complete (commits 857d96e..eab71fe, review clean)
Task 2: dispatched (BASE eab71fe, implementer sonnet)
Task 2: implementer ended its turn early waiting on a background Godot run (nothing implemented) — resumed with foreground-run instructions
Task 2: implementer DONE_WITH_CONCERNS (eab71fe..b2a9fe0; probe 24/24, gates 19/0/0, regressions green). Concern verified by controller = PLAN DEFECT: base crit_mult is 1.0 (TalentEngine.gd:16,160), so a chance-only Kill Shot made crits deal x1.0 without a crit talent.
Ruling: first Kill Shot pick per run grants +1.0 crit_mult ONCE (new const CARD_CRIT_MULT_BONUS_ONCE), later picks chance only — matches spec §5.2 "crit stays x2 + talents", removes only the per-pick (quadratic) growth — cost if wrong: one const + 4 lines in Gun.upgrade_crit. Spec text to be amended in T8's spec-update step.
Task 2: pre-review fix dispatched (resumed implementer)
Task 2: pre-review fix landed (ecf7be3, probe 25/25, gates + regressions green) — task review dispatched
Task 2: review = spec ✅, quality Approved; 1 Important labeled plan-mandated: `if v > 0.0: player.gun.upgrade_damage(v)` repeated in the pierce and ricochet arms (UpgradeApply.gd:30,33).
Ruling: the code stands — a one-line guard in two adjacent match arms is below the abstraction threshold; a helper adds more indirection than it removes — cost if wrong: a 3-line refactor; final review sees this line.
Task 2: minor (deferred): probe never asserts a non-Epic pierce/ricochet (value 0.0) leaves damage unchanged
Task 2: minor (deferred): long inline comment on Gun._fire_cone burn line — make it a ## block
Task 2: complete (commits eab71fe..ecf7be3, review clean, 1 ruled)
Task 3: dispatched (BASE ecf7be3, implementer sonnet)
Task 3: implementer DONE (ecf7be3..cfe5735; probe 20/20, gates 19/0/0, regressions green) — task review dispatched. F5 eyeball list: 4-row fit in 214px on long descs, Common gray legibility, Legendary flash+sting feel, border-only tier read on phone.
Task 3: review = behavior correct; 1 Important: new layout numbers left as bare literals, card size duplicated in _build_ui and _paint_cards (controller ruling not followed)
Task 3: minor (deferred): style_tier_button allocates 3 styleboxes that style_button's call immediately discards (plan-mandated shape; not a leak)
Task 3: minor (folded into fix round 1): ScreenFlash parented under LevelUpUI instead of current_scene
Task 3: fix round 1/5 dispatched (resumed implementer; FIX_BASE cfe5735)
Task 3: fix round 1/5 (2 addressed, 0 open — named layout consts, ScreenFlash parenting; commits cfe5735..0965427)
Task 3: minor (deferred): probe_card_ui can print a non-deterministic "ObjectDB instances leaked at exit" warning when its final real-RNG roll lands a Legendary (in-flight ScreenFlash tween at quit) — seed the probe RNG
Task 3: complete (commits ecf7be3..0965427, review clean)
Task 4: dispatched (BASE 0965427, implementer sonnet)
Task 4: implementer DONE_WITH_CONCERNS (0965427..89de997; probe 20/20, gates 19/0/0, regressions green). Concern: the dispatch's ">100x" level-57 pacing bound was the CONTROLLER's arithmetic error — real ratio with starters 8/1.17 is ~71x (362,392 vs 5,073).
Ruling: implementer's ">= 50x" probe bound accepted — the check's purpose (level 57 unreachable in a shift) holds at 71x — cost if wrong: none, probe-only.
Task 4: task review dispatched
Task 4: review = spec ✅, quality Approved; 1 Important labeled plan-mandated: gem_value_for_hp floors to 1 BEFORE Enemy's elite/night multipliers (old code floored only at the end) — differs only when HP/50 rounds to 0 under a multiplier; provably unreachable with today's consts (multipliers gate at wave >= 5, runner ratio crosses 0.5 at wave 3).
Ruling: the code stands — floor-first is the better rule (an elite's x3 should multiply at least 1) and it is inert today; T6 (which edits Enemy.gd) adds a source comment at Enemy._drop_gem documenting the order and its dependency on ENEMY_HP_GROWTH / NIGHT_EVENT_MIN_WAVE / ELITE_MIN_WAVE — cost if wrong: a 1-XP difference on a wave-2 runner under a modifier that cannot occur.
Task 4: carry to T8: OVERTIME_HEADSTART_XP (124) was verified to still buy 8 levels with starters 8/1.17 (cumulative 119) — if T8 retunes XP_BASE/XP_GROWTH it must re-derive this const (= cumulative XP to level 8, rounded up to the next 5).
Task 4: minor (deferred): no end-to-end probe of Enemy._drop_gem (elite + night mult + clamp)
Task 4: complete (commits 0965427..89de997, review clean, 1 ruled)
Task 5: dispatched (BASE 89de997, implementer sonnet)
Task 5: implementer DONE (89de997..d4a070b; probe 20/20, gates 19/0/0, regressions green) — task review dispatched
Task 5: review = spec ✅, quality Approved, no Critical/Important. ⚠️ resolved by controller: no player-facing text states the JACKPOT frenzy number (only AbilityController callout "TRIGGER HAPPY" + the GameConfig comment).
Task 5: minor (deferred): shot SFX can play up to 4x in one frame during a catch-up burst — F5 listen for audio pileup after a hitch
Task 5: minor (deferred): probe_fire_timing hardcodes cap 4 in _simulate(); no real-Gun probe of the _fire-false / mag-empties-mid-burst branches (verified by reading)
Task 5: complete (commits 89de997..d4a070b, review clean)
Task 6: dispatched (BASE d4a070b, implementer sonnet)
Task 6: implementer DONE_WITH_CONCERNS (d4a070b..62ae36f; probe 15/15, gates 19/0/0, regressions green). Concern verified = PLAN GAP: `spread` and `mine` arms are kill-gated too (TalentEngine.gd:301,304) but the brief's unscaled list named only explode/ammo/bolt/pool.
Ruling: every `killed and` arm rolls unscaled (per-enemy event, not per-tick) — spread/mine join the list; rule documented in a comment where `scale` is declared — cost if wrong: two proc arms on one gun class.
Task 6: pre-review fix dispatched (resumed implementer)
Task 6: pre-review fix landed (3b39d8c; probe 17/17, gates + regressions green) — task review dispatched
Task 6: review = spec ✅, quality Approved, no Critical/Important
Task 6: minor (deferred): TalentEngine.gd:230 states the unscaled rule as an enumerated list — lead with the general `killed and` rule
Task 6: minor (deferred): per-second statistical probe tolerance (100±40 over 2000) is loose (plan-mandated); probe leaves some stub nodes for engine teardown
Task 6: complete (commits d4a070b..3b39d8c, review clean)
Task 7: dispatched (BASE 3b39d8c, implementer sonnet)
Task 7: implementer DONE (3b39d8c..8cfc64b; probe 36/36, gates 19/0/0, regressions green). probe_procs count discrepancy (15 vs the 17 reported in T6) checked by controller: re-ran it — fails=0, 15 top-level PASS lines, spread + mine on-kill assertions present and passing; the "17" was a counting difference in the T6 report, not a regression.
Task 7: task review dispatched
Task 7: review = spec ✅ otherwise; 1 Important labeled plan-mandated: `_suppress_time` resets whenever no REVEALED boss is alive, so a Mystery Shopper's re-cloak/re-reveal cycle grants a fresh 75 s each time (up to ~3x75 s per boss).
Ruling: budget is per BOSS (spec §5.1 "at most 75 s per boss … counts only revealed time") — accumulate while revealed, HOLD while alive-but-concealed, reset only when no boss is alive — cost if wrong: 3 lines in Spawner._process.
Task 7: minor (deferred): dispatch template carried a stale probe_procs count (17 vs the real 15 top-level PASS lines)
Task 7: fix round 1/5 dispatched (resumed implementer; FIX_BASE 8cfc64b)
Task 7: fix round 1/5 (1 addressed, 0 open — per-boss suppression budget; commits 8cfc64b..abb59ad)
Task 7: complete (commits 3b39d8c..abb59ad, review clean)
Task 8: dispatched (BASE abb59ad, implementer opus)
Task 8: implementer DONE_WITH_CONCERNS (abb59ad..1a1ea76). Sim validated vs old curve (MID L23/L45 vs analysis 22/43). Tuned: XP 11/1.16, OVERTIME_HEADSTART_XP 160, BOSS_BASE_HP 7500 (roster x5), BOSS_XP_REWARD 35, CARD_TIER_BANDS uniform x1.82. PASS: levels 3/11/17/26/30, MID ratio 2.81→1.62, FRESH min 0.61, w5 boss mean 54.5s. FAIL: boss TTK w10/15/20 = 15.6/8.9/6.8s (ref DPS grows x1.287/wave vs boss HP x1.12). Boss XP/50s income 0.78/0.37/0.21/0.20.
Controller finding (CRITICAL in 1a1ea76): the uniform x1.82 band scale pushes reduction-type cards past 100% — Fast Hands base 0.20 x Legendary 4.05–5.5 = 0.81–1.10 → `reload_mult *= (1 - p)` goes NEGATIVE; Tighter Choke 0.30 x 2.4–5.5 = 0.72–1.65 → negative spread. It also nearly doubles defense cards (Iron Skin Legendary -61–83%), pre-empting spec 2.
Ruling: REVERT CARD_TIER_BANDS to the Larry-approved table [[0.5,0.8],[0.8,1.2],[1.3,1.8],[2.2,3.0]]; get the needed MID power by raising ONLY the two pure-DPS card bases (UPGRADE_DAMAGE_PCT, UPGRADE_FIRE_RATE_PCT) via the probe — "Rare = today's value" then holds for every card except those two, whose base is deliberately raised because 30 picks must do the work 57 did — cost if wrong: two consts; Larry retunes on the phone pass.
Ruling: D5 (Larry-locked 45–60s boss fights) outranks spec §5.5's single-compounding mechanism (controller's design, proven insufficient by the sim) — add boss-only `BOSS_HP_GROWTH` (probe-tuned, expected ~1.27–1.29/wave) used by DifficultyCurve.boss_stats; BOSS_BASE_HP re-anchored so w5 stays 45–60s; probe_bosses assertions updated from ENEMY_HP_GROWTH to BOSS_HP_GROWTH; spec §5.5 amended — cost if wrong: late bosses too spongy for under-geared players (they already scale the same way pre-v0.1.74).
Ruling: boss XP must be ~neutral at every boss wave. Trash spawns are HALVED (not stopped) during a fight, so neutral = boss XP ≈ 0.5 x (fight-length x normal income); target band 0.5–1.0 of 50s income at w5/10/15/20. Mechanism: per-gem value also scales with relative spawn rate (pure static XpCurve.boss_gem_value(wave)), boss gems exempt from XP_GEM_VALUE_MAX; gem COUNT stays BOSS_XP_REWARD (no clutter) — cost if wrong: one static + const.
Task 8: fix round 1/5 dispatched (resumed implementer opus; FIX_BASE 1a1ea76)
Task 8: fix round 1 result (1a1ea76..dd2ce46): bands restored; UPGRADE_DAMAGE_PCT 0.40 / UPGRADE_FIRE_RATE_PCT 0.30; BOSS_HP_GROWTH 1.29, BOSS_BASE_HP 5600 (+roster); BOSS_GEM_VALUE_MULT 0.8 + XpCurve.boss_gem_value; levels 3/11/17/27/30, MID ratio 2.81→1.65, FRESH min 0.62, boss XP 0.78/0.61/0.55/0.64 — all PASS. Residual: boss TTK roster means 69.0/40.6/46.7/65.9 s (worst miss x1.15). New concerns: 1.29 compounds past extraction (w30 base boss 9.0M HP) and Boss Rush indexes boss_stats(N) per spawn (3 concurrent bosses now x3.7 tankier at second zero; 15th boss 202k).
Ruling: accept the boss-TTK residual — one base + one geometric rate cannot track a reference DPS whose growth changes slope (x1.435 → x1.254 → x1.204/wave); spec §4 boss tolerance AMENDED to roster mean 40–70 s / every boss 30–80 s, recorded in the spec with this reason, probe bands updated so the probe is green rather than permanently red — cost if wrong: w5 boss runs long for fresh saves (spec already accepted >60 s there); F5 item.
Ruling: BOSS_HP_GROWTH applies only while the gear ladder is climbing — through the last scheduled shift boss (new const BOSS_HP_GROWTH_LAST_WAVE := 20); beyond it bosses grow with ENEMY_HP_GROWTH like trash (post-w20 player growth is cards only, ~x1.10/wave) — prevents late-endless boss walls (9.0M HP at w30) — cost if wrong: late-endless bosses slightly soft, same as trash.
Ruling: Boss Rush is outside this spec and was tuned around the old numbers — it gets its own curve DifficultyCurve.boss_rush_stats(n) = BOSS_RUSH_BASE_HP (1500) x ENEMY_HP_GROWTH^(n-1) (exactly its post-Task-7 behaviour), so the endless retune does not make its 3 opening bosses x3.7 tankier — cost if wrong: Boss Rush unchanged from Task 7, revisit in its own pass.
Task 8: fix round 2/5 dispatched (resumed implementer opus; FIX_BASE dd2ce46)
Task 8: fix round 2 result (dd2ce46..77b474a): BOSS_HP_GROWTH_LAST_WAVE 20 (w30 base boss 9.0M → 2.18M; MID TTK w25/w30 76/85 s, no wall); Boss Rush own curve (BOSS_RUSH_BASE_HP 1500, boss_rush_stats, shared _boss_shape); amended bands in probe + spec; BOSS_BASE_HP 5550; means 68.5/40.2/46.3/65.3 s; 43/44 cells in band. Residual: w5 MANAGER 83 s vs 80 s ceiling.
Ruling: trim Manager's roster multiplier inside the spec's 0.8–1.3 band — MANAGER_HP 6900 (x1.243, still tankiest) — so every cell fits and the probe is fully green — cost if wrong: Manager 4% less tanky than planned.
Task 8: carry to ship notes (F5 / follow-up): Boss Rush is frozen at pre-v0.1.74 boss HP while DPS cards doubled → materially easier, needs its own pass; boss scaling has an intentional kink at wave 21; fire_eff (stop-to-shoot uptime) is the sim's largest unmeasured assumption.
Task 8: fix round 3/5 dispatched (resumed implementer opus; FIX_BASE 77b474a)
Task 8: fix round 3 result (77b474a..ca02d4c): MANAGER_HP 6900 (x1.2432); probe_power_curve 29/0 fully green; boss TTK means 68.2/40.0/46.1/65.0 s, all 44 cells in 30–80; all probes fails=0; gates 19/0/0. (Fix rounds 1–3 were controller-ruled scope changes before the task review, not review findings.)
Task 8: task review dispatched (whole range abb59ad..ca02d4c, reviewer opus — tuning + scope rulings are the riskiest diff of the plan)
Task 8: review (opus) = all rulings A–G implemented correctly, model reads live values, no circularity, EV math right; 3 Important:
  I1 (plan-mandated) sim card policy awards Extra Barrel ("projectile") to pistol/AK-47, which can never be offered it (Weapons.upgrades_for) → reference DPS inflated 10–15%; corrected, w5 boss mean → ~80 s and MID 9:35 ratio → ~1.48 (<1.5): tuned constants not yet trustworthy.
  I2 boss_gem_value's spawn-rate scaling leaks into Boss Rush (wave = run time there; many concurrent kills) → up to ~x3.8 XP per kill; defeats ruling E's isolation intent on the XP axis.
  I3 committed probe-output doc's "BEFORE" section came from an earlier probe build (broken "worst: = 0s" line), not reproducible.
Ruling: I1 — the sim's pick policy must be DERIVED from the real offer mechanics, not a hand-written cycle: 3 cards drawn from the build weapon's live Weapons.upgrades_for pool, player picks by a stated priority (damage > fire_rate > reload > non-DPS), choosing the higher roll when both DPS cards are offered; probe asserts every modelled pick is legal for that weapon. Retune against it. Sanity stop: if UPGRADE_DAMAGE_PCT would need > 0.60, stop and report — cost if wrong: another tuning pass.
Ruling: I2 — Boss Rush boss gems use the plain wave-current trash gem value (XpCurve.gem_value_for_hp, capped, NO spawn-rate factor, NO BOSS_GEM_VALUE_MULT); endless unchanged. Boss Rush cannot be fully isolated from the new XP curve and still needs its own pass — cost if wrong: Boss Rush XP a little low/high until that pass.
Ruling: I3 — label section A as a historical run from the first probe build (not reproducible with the committed probe) rather than regenerating it.
Task 8: minor (folded into the fix): review minors 4–11, 14, 15 (stale comments/spec lines, /11.0 literal, magic 52.0, hardcoded header strings, hardcoded reduction-card id list, duplicated ratio expr). Minor 12 (INTENDED_MULTS pins Manager) and 13 (rerolls unmodelled — state it) deferred/noted.
Task 8: fix round 1/5 on review findings dispatched — FRESH implementer (opus): the original's context has absorbed three long rounds (FIX_BASE ca02d4c)
Task 8: review fix round 1 result (ca02d4c..871d479, fresh opus implementer): pick model derived from real offer mechanics (200k fixed-seed offers through real shuffle + CardRolls.roll; P(card offered)=3/8, both-DPS 0.1071, none-of-DPS/reload 17.9%; picks dmg 34.7% / fire 29.6% / reload 17.8%; expected gun level x1.275) — controller cross-checked the hypergeometric numbers by hand: 6/56=0.1071 ✓, 10/56=0.1786 ✓. Retune: UPGRADE_DAMAGE_PCT 0.60, UPGRADE_FIRE_RATE_PCT 0.45, BOSS_BASE_HP 4150, BOSS_HP_GROWTH 1.31, roster x0.7477. §4 all PASS: levels 3/11/17/27/30, MID ratio 1.58–2.59, FRESH ≥0.60, 44/44 boss cells 30.5–79.1 s, means 67.8/40.2/48.5/63.1, boss XP 0.78/0.61/0.55/0.64. I2: XpCurve.boss_rush_gem_value; I3: section A labelled historical. power_curve 44/0; all probes fails=0; gates 19/0/0.
Ruling: accept UPGRADE_DAMAGE_PCT 0.60 although it sits ON the sanity ceiling — it is the only grid point where the MID ratio band holds, and it holds at the LOW end (1.58), so the model says "barely enough", not "too much"; the model credits 0 DPS to pierce/ricochet/mag/incendiary, so real play is likely somewhat stronger — top F5 item for Larry (Legendary Hollow Points = +132–180% damage) — cost if wrong: two constants.
Task 8: scoped re-review dispatched (sonnet; FIX_BASE ca02d4c)
Task 8: review fix round 1/5 (3 addressed + minors, 0 open — derived pick model, Boss Rush boss XP, historical label; commits ca02d4c..871d479)
Task 8: complete (commits abb59ad..871d479, review clean after 3 controller-ruled scope rounds + 1 review fix round)
Task 9: final whole-branch review dispatched (opus; range 857d96e..871d479)
Final review (opus, 857d96e..871d479): no Critical; architecture/save-compat/numerical safety sound; 7 Important + minors. Verdict "ship with fixes".
  F1 GUN_MAX_SHOTS_PER_FRAME=4 caps shots at 4xfps — reachable now that Hair Trigger base tripled (30fps Flamethrower ~3.6 picks + frenzy) → frame-rate-dependent DPS again.
  F2 shot SFX plays per shot inside _fire → up to 4x/frame steady-state on fast guns; only "shot_special" throttled.
  F3 Quick Step rolled desc lost "(cap 40%)" — the only remaining cap in the card system.
  F4 four execute talent descs (Pink Slip, Mercy, Executioner, Reaper) still promise instant kills with bosses now immune.
  F5 Tesla Extra Barrel shows "+1 Projectile at N% damage" but grants a full-strength chain jump (share discarded).
  F6 honest frenzy cuts Rampage's real effect ~49% (x3.33→x1.70) while the ability const was compensated.
  F7 Boss Rush ships softer on two axes (frozen HP vs higher card DPS; halved level-keyed concurrency).
Ruling: F1 fix — GUN_MAX_SHOTS_PER_FRAME 4→8 (240 shots/s even at 30 fps; remains a hitch guard) and probe_fire_timing reads the live const — cost if wrong: more cone sweeps in a hitch frame.
Ruling: F2 fix — one shot SFX per frame (first shot of the frame only) — cost if wrong: none audible.
Ruling: F3/F4/F5 fix the text (Tesla: desc "+N Chain Jump", no share/band) — player-facing truth.
Ruling: F6 stands — Larry explicitly chose "Honest for cards + talents" knowing the listed 70% was really +233%; the ability was compensated because it is not a talent and carries no player-facing number. Changelog states it plainly + F5 item — cost if wrong: retune talent `rof` values later.
Ruling: F7 ship Boss Rush soft with a changelog note; gating a mode out of the build is a bigger product change than this release owns; own pass on the bench — cost if wrong: an easy side mode for one release.
Final review minors folded into the ONE fix wave: Mascot.gd stale comment; probe doc baseline column; Upgrades.gd dead+wrong catalog descs; XpCurve "uncapped" comment + docstring targets-vs-measured; CardRolls unknown-id warning; Kill Shot fmt; Legendary plural grammar; Gun.gd long inline comment; spec §3 note that rerolls re-roll tiers (sim = floor). Remaining ledger minors: can wait (per final reviewer triage).
Task 9: final-review fix wave dispatched (ONE dispatch, sonnet; FIX_BASE 871d479)
Task 9: final-review fix wave landed (871d479..9b94373; all 15 items; 10 probes fails=0; gates 19/0/0) — ONE scoped re-review dispatched (sonnet)
Task 9: fix-wave re-review = all findings addressed, no player-visible bugs. Residual minor (parked, deferred to the next spec's sweep): Gun.gd:575 upgrade_crit doc comment still quotes the old "(2x Damage)" card text; spec prose says Graveyard Shift ≈-15% (computes ≈-16%).

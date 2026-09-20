# SDD ledger — plan: docs/superpowers/plans/2026-09-20-survivability.md
Spec: docs/superpowers/specs/2026-09-20-survivability-design.md · start HEAD 9d9f189 (v0.1.74 + spec/plan docs) · branch master
Ruling: work directly on master, no worktree — repo convention, Godot import cache lives in the tree; pushes gated to Task 6, which Larry pre-authorized by picking "Subagent-driven, now … then ship v0.1.75" — cost if wrong: local commits to revert.

## Pre-flight scan
| pair / task | produces vs consumes | finding |
|---|---|---|
| T1↔T2↔T3 | all add GameConfig consts | disjoint blocks |
| T2↔T3 | both edit DifficultyCurve.gd (enemy_stats speed term vs elite_chance) | disjoint functions |
| T3→T4 | RunConfig.probation + Main._ready hook → callout uses the flag | consistent |
| T3↔T1 | none shared | — |
| T5 | probe_power_curve type-mix may be a bracket table | plan covers both cases |
| T1 self | TTD sim needs the probe player to actually die; a dev save with UNION REP (benefit revive) or a character revive would corrupt the measurement | RULING below |
| T1 self | blink via self_modulate vs existing modulate tweens | consistent (separate property) |
| T3 self | mutating boss_stats() dict | safe: DifficultyCurve builds a fresh literal per call |
| T4 self | CombatText.instance at Main._ready | verified: CombatText is a child node of Main.tscn and sets `instance` in its own _ready; children ready before the parent → no deferral needed |
| T6 self | push + tag | pre-authorized |
Ruling: T1's TTD simulation runs with RunConfig.hardcore = true (restored afterwards) — HARDCORE disables UNION REP and the character revive, so death is a plain `died` signal and the timing is save-independent; the 70% cap applies in HARDCORE by spec, so the measurement is unaffected — cost if wrong: none (probe-only).
Models: implementers sonnet (T5 opus), task reviewers sonnet, final review opus.
Task 1: dispatched (BASE 9d9f189, implementer sonnet)
Task 1: implementer DONE (9d9f189..b73cd6d; probe 40/40, gates 19/0/0, 10 regression probes fails=0). Measured surrounded TTD 3.6/2.4/1.6/0.8 s (targets 3.2/2.1/1.4/0.7, within ±15%: a 6-biter 0.1 s attempt grid lands hits every 0.4 s, not exactly 0.35) — task review dispatched
Task 1: review = production code correct (order, classification sweep complete, cap, blink on self_modulate); 2 Important on the probe: (1) the hardcore ruling was applied to the cap test, not the TTD simulation; (2) no assertion that the sprite ever actually dims. Minor folded in: a player who dies on a dim blink phase stays at 0.35 alpha (tree pauses in _die).
Task 1: minor (deferred): TTD margins thin at waves 11/17 (probe's even 0.1 s stagger grid); brittle source-string checks (being relaxed in the fix)
Task 1: fix round 1/5 dispatched (resumed implementer; FIX_BASE b73cd6d)
Task 1: fix round 1/5 (3 addressed, 0 open — hardcore-wrapped TTD, real blink assertions, opaque-on-death; commits b73cd6d..0d5bbcd)
Task 1: complete (commits 9d9f189..0d5bbcd, review clean)
Task 2: dispatched (BASE 0d5bbcd, implementer sonnet)
Task 2: implementer DONE (0d5bbcd..efe60f9; probe 34/34, gates 19/0/0, all regression probes fails=0, power_curve unmoved) — task review dispatched
Task 2: review = spec ✅, quality Approved, no Critical/Important (knee/cap arithmetic hand-verified by the reviewer: w7 78.83, w11 118.4, w14 160.6, w17 217.9, w18 capped)
Task 2: minor (deferred): probe source checks are substring-only (backed by numeric checks)
Task 2: complete (commits 0d5bbcd..efe60f9, review clean)
Task 3: dispatched (BASE efe60f9, implementer sonnet)
Task 3: implementer DONE (efe60f9..70bb5ba; probe 60/60, gates 19/0/0, 12 regression probes fails=0). Note: relaxed one probe_bosses source check (exact-substring of the old _check_boss call → body-contains) because the brief's new _check_boss shape broke the literal match — task review dispatched
Task 3: review = production code approved on every point (flag timing incl. RESTART + Daily, no min_wave/elite leak surfaces, only wave-5 boss softened, nothing persisted, seeded pick sequences identical with probation off and from wave 9 on). 1 Important on a PROBE: the relaxed probe_bosses check only proves `boss_stats()` appears somewhere in _check_boss.
Task 3: fix round 1/5 dispatched (resumed implementer; probe-only: bind `stats := DifficultyManager.boss_stats()` → `_spawn_boss(stats)`, ordered, no boss_rush_stats)
Note for every later dispatch: probe_probation, probe_survivability and probe_speed_ramp join the regression list.
Task 3: fix round 1/5 (1 addressed, 0 open — probe_bosses binds stats→_spawn_boss, ordered; probe-only, no new commit)
Task 3: complete (commits efe60f9..70bb5ba, review clean)
Task 4: dispatched (BASE 70bb5ba, implementer sonnet)
Task 4: implementer DONE_WITH_CONCERNS (70bb5ba..f02c4be; probe 90/90, gates 19/0/0, 13 probes fails=0). Concern verified = PLAN DEFECT: CombatText.callout is a pooled 0.6 s proc-word system — unreadable for a ~35-char sentence the spec wants up ~3 s.
Ruling: announce probation on the existing HUD banner (Hud.show_banner — the mechanism NightEvents/Extraction use), two lines `PROBATIONARY PERIOD\nSHIFT n OF 10` (no dash → no glyph/width risk); check collision with the first-run onboarding hints and delay by a named const if they overlap — spec §3.4 "existing CombatText.callout style" amended at T5 — cost if wrong: one call site.
Task 4: pre-review fix dispatched (resumed implementer)
Task 4: pre-review fix 1 landed (d1d208b: HUD banner, 2 lines, PROBATION_BANNER_DELAY 1.5 s; probe 95/95). New concern from the implementer: on a non-forecourt location (reachable at rank 2, inside 10 games) the TONIGHT'S SHIFT banner and the probation banner would overlap (banners are independent full-screen overlays).
Ruling: sequence, never stack — when the location banner fires, the probation banner waits PROBATION_BANNER_DELAY_AFTER_LOCATION (3.2 s = 2.6 hold + 0.4 fade + margin), else 1.5 s; one timer site — cost if wrong: a const.
Ruling: FirstRunHints overlap on a brand-new save's first shift is accepted (hint label under a 3 s banner) — F5 item — cost if wrong: cosmetic, first shift only.
Task 4: pre-review fix 2 dispatched (resumed implementer)
Task 4: pre-review fix 2 landed (b264b97; probe 103/103, gates 19/0/0, regressions green) — task review dispatched (range 70bb5ba..b264b97)
Task 4: review = spec ✅, quality Approved, no Critical/Important (freed-node safety via signal auto-disconnect + pause-respecting timer verified; stub line single-path via RunStats.paid_out)
Task 4: minor (deferred): two probe substring checks are imprecise (`PROBATION_BANNER_DELAY` is a prefix of `..._AFTER_LOCATION`; `_populate_stub` arg threading checked by body-contains)
Task 4: note for Larry (design awareness, not a bug): the PROBATION COMPLETE line keys on games_played 9→10, so it also shows when that 10th shift is a Daily run; an abandon that crosses 10 shows no line (no stub on that path)
Task 4: complete (commits 70bb5ba..b264b97, review clean)
Task 5: dispatched (BASE b264b97, implementer opus)
Task 5: implementer DONE_WITH_CONCERNS (b264b97..fbc3c47, docs only). All 44 v0.1.74 checks still pass byte-identical; live-derived type mix matches the old bracket table to 0.043%; first boss TTK 67.8 s → 51.8 s on probation; 13 probes, 483 PASS. The NEW report check fails at 2:00 (0.93 vs 1.22) and 4:00 (0.75 vs 0.96): FRESH normal→probation power÷threat 1:30 1.14→1.56 · 2:00 1.22→0.93 · 2:30 0.84→0.96 · 3:00 0.93→1.31 · 3:30 0.95→1.12 · 4:00 0.96→0.75. Cause: a lighter opening pays less XP (mean gem value per spawn 1.00 vs 1.48 at 1:30, 2.29 vs 3.56 at 3:00) → the probation player is ~1 level (one gun card, ~x1.28) behind exactly when the schedules converge at 4:00; plus a +3.5% threat-proxy artifact at 2:00 (removing the low-HP exploder raises mean spawn HP).
Ruling: this is a real defect in the probation feature found by the spec's own verification, and it is in this spec's scope — add "training pay": on probation the player gets a run-long XP bonus PROBATION_XP_BONUS (probe-tuned, expect 0.15–0.25; applied once in Main._ready via player.upgrade_xp_gain, same multiplicative channel NIGHT SCHOOL uses) so a new hire joins the normal game at 4:00 at parity, not a level behind — cost if wrong: one const; new hires end a shift ~1 level higher.
Ruling: the probation-vs-normal check allows a 5% tolerance (probation ≥ 0.95 x normal) to absorb the documented threat-proxy artifact at 2:00; spec §4 words it as a report row, the probe states the tolerance and why — cost if wrong: none (report metric).
Task 5: fix dispatched (resumed implementer opus; FIX_BASE fbc3c47)
Task 5: training-pay fix landed (4feb88a + 6fba2a5): PROBATION_XP_BONUS 0.15 (smallest 0.05 step meeting both conditions); probation/normal ratios now ≥0.97x at all six minutes, level 14 vs 14 at 4:00, first boss 40.7 s; 13 probes fails=0 (power_curve 46, probation 113); gates 19/0/0 — task review dispatched (range b264b97..6fba2a5)
Task 5: review = spec ✅, quality Approved, no Critical/Important (bonus applied once, gated, after apply_base; sim reads live values; 43 prior check lines byte-identical; spec + committed doc match shipped behavior)
Task 5: minor (deferred): the probe's tuning guard asserts the shipped PROBATION_XP_BONUS is the SMALLEST passing step — a future unrelated balance change could trip it spuriously; re-run the sweep before treating that as a regression
Task 5: complete (commits b264b97..6fba2a5, review clean)
Task 6: final whole-branch review dispatched (opus; range 9d9f189..6fba2a5)
Final review (opus, 9d9f189..6fba2a5): READY TO SHIP = YES. No Critical. Independent end-to-end sweep confirmed all 12 player-damage sites classified correctly and nothing damages the player outside take_damage; save format unchanged; Daily determinism safe; probation inert when off.
  I1 Quick Step (dodge) is worth ~13% (not 40%) against a dense surround now — a dodged bite is replaced ~0.1 s later by the next biter; spec §3.2 claimed the opposite. Keeps full value vs sparse damage.
  I2 Spike Armor/Thorns reflects once per LANDED bite → ~4x less output in a surround (intended consequence, unmeasured).
  I3 a bite-opened i-frame window also blocks boss patterns/projectiles (player is inside a window ~87.5% of the time while being chewed on; at w20 an ~18 HP bite can erase a 70 HP slam). Reviewer verdict: acceptable genre behavior (the window always costs a landed hit), document it + F5.
  Minors: m1/m2 comment rot (RunConfig.gd:41, GameConfig PROBATION_BANNER_DELAY), m3 spec says _process (it is _physics_process), m4 spec understates the faster-than-before speed window (really 3:30–7:30, peak +27.8% at 4:30 — exactly where probation's schedule converges), m5 blink can freeze dim behind a pause/level-up overlay, m6 boss pattern `_hit_player` latch fires even on a blocked hit (ChargeDash could reconnect), m7 plan still describes the CombatText callout, m8 NightEvents (Blood Moon from wave 5) are not excluded from probation.
  Quantified by the reviewer: minigun max-roll lifesteal ≈15.4 HP/s vs a dawn surround of 62 HP/s raw (≈23 HP/s after 3x Iron Skin + 40% dodge) → net −7.5 HP/s; at 5+ Iron Skin stacks a heavy defensive build is effectively unkillable by trash BITES (pools/exploders/patterns still kill) — read as the spec's intent; re-measure in spec 3.
Ruling: I1/I2 — no code in this release; spec §3.2 sentence corrected; Quick Step + Spike Armor go on spec 3's card-retune list — cost if wrong: two cards under-tuned for one release.
Ruling: I3 — ship as is (genre-standard, never free); spec §3.2 gains a paragraph stating the interaction + verdict; top F5 item; the structural answer (heavy hits piercing windows opened by light ones) is a spec-3 design question — cost if wrong: bosses softer than intended while trash is on the player.
Ruling: m6 (pattern latch) and m8 (NightEvents on probation) and m5 (blink behind overlays) are gameplay changes → NOT in a last-minute fix wave; all three go to the spec-3 backlog + F5 list — cost if wrong: minor.
Task 6: final-review fix wave dispatched — DOCS + COMMENTS ONLY (m1, m2, m3, m4, m7, I1 sentence, I3 paragraph, spec-3 backlog + F5 additions) (sonnet; FIX_BASE 6fba2a5)
Task 6: fix-wave re-review = all addressed (arithmetic re-verified); controller final run: 13 probes fails=0, gates 19/0/0; v0.1.75 released e091a8b, tag pushed, both CI workflows green, GitHub release live 08:05 AM CDT 2026-09-20.

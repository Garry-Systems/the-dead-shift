# The Dead Shift v0.1.72 — economy / difficulty map (2026-09-19)

Analytical pass (no playtest data). Four read-only analysts, every number read from code; detail +
file:line cites in the sibling files: `map_difficulty.md`, `map_power.md`, `map_economy.md`,
`map_meta.md`. Player-DPS and income figures rest on stated kill-rate / uptime assumptions — treat
anything past minute 10 as *shape*, not value. Larry's standing calls (talent level-gating, steep
rarity) are quantified, not flagged.

## 1. The cross: player power ÷ threat

Threat = effective enemy HP/s thrown at the player (spawn rate × HP × type mix × elites).
Ratio > 1 means the player out-kills the spawn stream on raw single-target DPS.

| t (min) | threat HP/s | fresh save | mid gear (Lethal AK) | late gear (Merciless AK) |
|---|---|---|---|---|
| 0 | 50 | 1.5 | 5.2 | 24 |
| 1 | 61 | 1.4 | 5.1 | 28 |
| 3 | 290 | **0.41** | 2.3 | 14 |
| 5 | 702 | **0.34** | 2.1 | 20 |
| 8 (dawn) | 2,518 | **0.27** | 3.1 | 39 |
| 10 | 4,287 | 0.42 | 6.6 | 67 |
| 15 | 13,316 | 1.4 | 19 | 293 |
| 20 | 41,357 | 2.9 | 29 | 646 |

What it says:

- **Fresh saves are underwater from 1:30 to ~10:00** (kill a quarter to a third of what spawns, 130–400
  live enemies backlog). The 1:30–3:00 spike (brutes → elites → hives, threat ×4–5 in two minutes) is
  the new-player wall.
- **Anyone with a Lethal gun is never HP-checked**, and after ~minute 8 *everyone* out-scales the game:
  XP per kill grows 12%/wave (it's HP/50) while level cost is linear (5+3L) → level ~60 by 10:00, a
  card pick every ~5.7 s, all cards multiplicative and uncapped.
- **Deaths don't come from HP — they come from the surround.** No i-frames, no alive cap, enemy speed
  ×2.87 between waves 11–18 (runners outrun the player at w14, shamblers at dawn). Time-to-die when
  surrounded: 1.0 s at 0:00, 0.46 s at dawn, 0.23 s at 15:00. So difficulty is binary: nothing reaches
  you, or you're deleted in under half a second. That's the "pushover or wall" feel.
- **Boss HP compounding twice past w10 (×1.25/wave vs trash ×1.12) is the only thing keeping pace with
  player power.** In isolation it looks like the #1 curve bug; in context it must be retuned *together
  with* the XP curve, not before it. Boss TTK today: fresh ~20–50 s at every tier, mid ≤5 s, late <1 s.

## 2. Larry's watch-list, answered

| question | answer |
|---|---|
| AIMBOT trivializes the run? | Its own 60 s window, yes (×1.2–2.3 DPS, fires while moving at 330 px/s vs 240 cap). The run, no — 240 s CD holds. The *package* is the issue: Jimbo = best ability + best defensive passive + ×1.47 gun perk for 600 coins. |
| Always-up turret + Heavy bonus too much? | No. Turret is 52 flat DPS: +69% at 0:00, +22% at 5:00, +3% at 10:00. Heavy perk is the same ×1.47 Ryan and Jimbo get. Nothing the player *places* scales with wave. |
| Coins pile up late-run? | Income climbs 3–6× to w18, caps ~400/min at the spawn floor, then decays. Not runaway — back-loaded (first 5 min = 22% of an extraction payout). Big Mart shelves: +2–4%, noise. |
| HARDCORE ×3? | The real lever. Zero threat-side change (only healing/revives off), so for a geared player who never gets hit it's a free ×3 coins, ×3 rank XP, ×2 weapon XP. |
| Coworker traits register? | They aren't incremental. A pull has a 1/24 (4.17%) chance of any trait (config comment says ~15%); traits are +20–40% when they land. A specific type+trait = 230k–403k coins. A Rusted drone = 6.5% of a bare pistol. |
| Snack prices? | Fine in normal. At the likeliest arrival (1:30) the pocket is ~135 vs a 150 heal → dead visit. No run-coin balance shown on HUD or truck. In HARDCORE spends come off pre-multiplier, so the 400 relic really costs 1,320–1,980. |
| Boss pushovers / walls? | Pushovers: Brute, Night Stocker, Courier. Walls (sponges): Manager ×2.0, Mascot, Mystery Shopper. Most lethal: Tanker ≈ Mascot. Boss-to-boss HP spread (2.73×) outweighs five waves of scaling — a w5 Manager out-tanks a w10 Stocker. |

## 3. Ranked fix list (recommendation for the balance spec)

1. **XP curve (keystone).** Exponential XP income vs linear level cost. Everything downstream — card
   spam, runaway DPS, trivial bosses, flat late game — is this. Fix first, retune the rest against it.
2. **Cap / de-multiply the cards.** Kill Shot is quadratic (1+0.05n²; text says "2x"), Extra Barrel is
   +100% vs Hollow Points +20%, Silver Tongue ×1.2 coins uncapped (rank XP inherits it), Fast Learner
   feeds #1. "+X% fire rate" is really ×1/(1−X): Rampage's "70%" is +233%.
3. **Per-hit procs need an internal cooldown.** Shatter on a minigun ≈ 1,080 AoE DPS vs the gun's 160;
   lifesteal 50–108 HP/s on a flamethrower vs Regeneration's 1 HP/s; poison stacks uncapped. Same
   talents are dead on snipers. Bosses aren't execute-immune (Reaper = 25% of boss HP in one hit).
4. **Survivability model.** Brief i-frames on hit and/or a softer w11–18 speed ramp, so damage is
   readable instead of a 0.4 s deletion. This is what makes geared play feel fair *after* #1–3 land.
5. **Bosses.** Remove the double compounding once #1 lands; narrow the 2.73× roster spread; close the
   boss-as-pet loop (a living boss halves trash spawns indefinitely and blocks later bosses — dawn
   surge drops *below* the ordinary w14 rate); boss XP is a flat 30.
6. **New-player wall 1:30–3:00.** Stagger brute/elite/hive unlocks or bump the starter gun; the w5 boss
   is 19.6 s of trash-stream vs 7.3 s for the w10 boss.
7. **Economy shape.** Fixed-price sinks end at 13,000 coins (~1.5 h) — after that it's gacha only;
   ranks 6/8/9/10 unlock nothing and 73% of rank XP sits after the last unlock; free crates ≈ 75% of a
   typical player's daily coin value; Janitor +57% coins is the only coin character; company_card's
   "curse" nets ×1.5.
8. **Broken promises.** Basement crate ladder (Titan w15 / Apex w20 / Apocalypse w25) is unreachable —
   dawn lockout blocks doors w13–21 and the 2-door cap is spent by w12 in 76% of runs. Surge "forced
   spawn floor" moves the interval 0.263→0.25 (nothing). Day-3 streak "tier up" lowers Munitions/Titan
   odds. Challenge rewards inverted (open 3 crates → Titan; kill 3 bosses → Munitions). STAFF FILE odds
   comment wrong. Footlocker and themed crates are dominated.
9. **Imperceptible / dead.** Benefit steps (+2% speed, +4 HP, +3% XP; PACK RAT L1 rounds to ×1.000),
   weapon XP on Rusted/Salvaged guns (no talents, nothing else levels), tiers 1–3 obsolete from run 1,
   Incendiary on Tesla/Flamethrower, most cards on Acid Cannon, fire rate quantized to frames (120 Hz
   phones do more DPS), `DEBUFF_SLOW_DURATION` never read, `ENEMY_LATE_HP_GROWTH` == early growth.
10. **QoL blockers.** 120-weapon cap with no bulk scrap, and a full inventory refuses crate opens.

## 4. Fixed in this session

**OVERTIME instant-quit farm** (economy flag 1, plus the all-mode instant-restart loop, flag 2).
Both v0.1.72 gates read `DifficultyManager.run_time`, which OVERTIME presets to 240 s — a 0-second
pause-quit vested the full signing bonus, paid the 9-wave head start, counted as a played game
(milestone crate every 10 loops), and banked weapon XP: ~1,200 coins/min vs ~356 legit.
Fix: new `DifficultyManager.played_time` (real seconds played; never preset, never held); signing
vest + games_played gate key on it; abandon coins *and* weapon XP ramp in via
`CoinReward.abandon_frac` over the first 120 s played. Probe: `.superpowers/probe_overtime_farm`.

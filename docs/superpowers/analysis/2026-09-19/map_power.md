# The Dead Shift v0.1.72 — PLAYER POWER map (read-only analysis)

Repo: `/mnt/c/Users/thela/Documents/mobile-game/`. All paths below are relative to `scripts/`. Arithmetic was done in python
(`scratchpad/weapons.py`, `sim2.py`, `sim3.py`). Nothing in the game was edited.

Conventions used throughout
- "burst DPS" = dmg x projectiles / fire_interval. "sustained" = mag x dmg x proj / (mag x interval + reload).
- Rarity names: the game has a 9-tier ladder (loot/Rarity.gd:22-32). I map the brief's words as
  Common = Rusted(r1), Rare = Lethal(r4, blue), Epic = Savage(r5, purple), Legendary = Merciless(r7, orange).
  Apocalypse(r8)/Armageddon(r9) sit above that.
- The designer is KEEPING talent level-gating and the steep rarity ladder. Neither is flagged per se; where the ladder
  is mentioned it is about a specific formula that behaves differently from how it reads.

Two structural facts that shape everything
1. STOP-TO-SHOOT + MOVE-TO-AIM. `SHOOT_ONLY_WHILE_STILL := true` (logic/GameConfig.gd:18); the gun fires along the last
   move direction and only while velocity == 0 (Player.gd:173-174). Paper DPS is therefore multiplied by an
   uptime x accuracy factor I call `fire_eff` (assumed 0.80 at t=0 falling to 0.50 at 10 min and 0.40 at 20 min —
   ASSUMPTION, not measured). AIMBOT is the only thing in the game that removes this factor.
2. EVERY damage/fire-rate source multiplies. `upgrade_damage` is `damage *= 1+pct` (Gun.gd:469-470) and
   `upgrade_fire_rate` is `fire_interval *= 1-pct` (Gun.gd:472-473). Affixes, cards, character perks and relics all go
   through those two hooks (Gun.gd:146-157, logic/Characters.gd:108-130, logic/Relics.gd:177-184,
   RelicEffects.gd:128-139). Nothing is additive with anything else except crit (see 2.4).
   "+X% fire rate" everywhere in the game really means "interval x (1-X)" = a DPS multiplier of 1/(1-X).

---------------------------------------------------------------------------------------------------------------

## 1. Weapon table (base defs, no loot/cards) — logic/Weapons.gd

| gun | dmg | interval | proj | pierce | range | mag / reload | burst DPS | sustained DPS | sustained @60fps* | rough AoE x | horde DPS | cite | special |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| lmg | 16 | 0.07 | 1 | 0 | 600 | 100 / 4.5 | 229 | 139 | 125 | 1.0 | 139 | Weapons.gd:153 | Heavy, spread .09 |
| ak47 | 22 | 0.12 | 1 | 0 | 650 | 30 / 1.7 | 183 | 125 | 116 | 1.0 | 125 | :45 | spread .04 |
| acid_cannon | (35) | 0.55 | 1 | - | 520 | 10 / 2.0 | 159** | 117** | 117 | ~4 | ~470 | :160 | NO direct damage; 25 dps pool r90 3.5 s, slow 40% |
| minigun | 8 | 0.05 | 1 | 0 | 520 | 150 / 3.0 | 160 | 114 | 114 | 1.0 | 114 | :38 | Heavy, spread .14 |
| battle_rifle | 45 | 0.28 | 1 | 0 | 850 | 12 / 1.7 | 161 | 107 | 106 | 1.0 | 107 | :122 | - |
| pdw | 10 | 0.06 | 1 | 0 | 500 | 40 / 1.5 | 167 | 103 | 96 | 1.0 | 103 | :100 | spread .07 |
| flamethrower | 5 | 0.05 | 1 | all | 280 | 100 / 2.5 | 130*** | 97*** | 97 | ~5 | ~480 | :77 | 60deg cone, hits ALL in cone, +30 dps/3 s burn |
| anti_materiel | 160 | 1.10 | 1 | 3 | 1300 | 4 / 2.6 | 145 | 91 | 91 | ~2.4 | ~220 | :137 | pierce 3 |
| rifle | 70 | 0.55 | 1 | 0 | 900 | 8 / 1.8 | 127 | 90 | 90 | 1.0 | 90 | :31 | - |
| smg | 12 | 0.08 | 1 | 0 | 550 | 30 / 1.6 | 150 | 90 | 88 | 1.0 | 90 | :17 | spread .06 |
| sniper | 120 | 0.90 | 1 | 2 | 1200 | 5 / 2.2 | 133 | 90 | 90 | ~2.0 | ~180 | :52 | pierce 2 |
| machine_pistol | 14 | 0.09 | 1 | 0 | 480 | 18 / 1.2 | 156 | 89 | 84 | 1.0 | 89 | :93 | spread .10 |
| auto_shotgun | 12 | 0.30 | 4 | 0 | 360 | 8 / 1.9 | 160 | 89 | 89 | 1.0 | 89 | :107 | 4 pellets arc .40 |
| pistol (starter) | 25 | 0.20 | 1 | 0 | 600 | 12 / 1.1 | 125 | 86 | 86 | 1.0 | 86 | :10 | - |
| magnum | 55 | 0.45 | 1 | 1 | 700 | 6 / 1.4 | 122 | 80 | 80 | ~1.5 | ~120 | :85 | pierce 1 |
| shotgun (starter) | 15 | 0.65 | 5 | 0 | 380 | 6 / 2.0 | 115 | 76 | 76 | 1.0 | 76 | :24 | 5 pellets arc .45 |
| nailgun | 9 | 0.07 | 1 | 1 | 500 | 25 / 1.3 | 129 | 74 | 67 | ~1.5 | ~110 | :60 | pierce 1, 12% pin .45 s |
| slug_gun | 78 | 0.70 | 1 | 2 | 650 | 5 / 2.0 | 111 | 71 | 71 | ~2.0 | ~140 | :114 | pierce 2 |
| railgun | 90 | 0.85 | 1 | all | 1100 | 5 / 2.2 | 106 | 70 | 70 | ~2.5 | ~175 | :129 | beam, 56 px corridor, hits all |
| tesla | 30 | 0.35 | 1 | chain | 600 | 20 / 1.8 | 86 | 68 | 68 | 3.36 | ~230 | :69 | 4 jumps x0.8 falloff, r320 (sum = 3.36x) |
| grenade_launcher | 50 | 0.80 | 1 | blast | 600 | 6 / 2.2 | 94**** | 64**** | 64 | ~3.7 | ~180 | :145 | Heavy; blast r130 + 50% impact |

\* `Gun._process` sets `_cooldown = fire_interval` after each shot and fires at most once per rendered frame
(Gun.gd:233-248), so the real interval is ceil(interval / frame_dt) frames. At 60 fps: LMG/nailgun 0.07 -> 0.0833
(-16%), PDW 0.06 -> 0.0667 (-10%), AK 0.12 -> 0.1333 (-10%), machine pistol 0.09 -> 0.10 (-10%). See flag F6.
\** Acid Cannon: the shell has `pool` but no `explode_radius`/`impact_frac`, so the bullet's shell branch deals nothing
on contact (Bullet.gd:53-63) and only drops a HazardZone (Bullet.gd:161-166). The "35 damage" stat is never dealt; it
only anchors the pool-dps ratio (Gun.gd:457-466). Number shown = one target standing in every live pool (cap 8).
\*** per target: 100 direct + 30 burn (`FLAME_BURN_DPS`, GameConfig.gd:33; Gun.gd:640-655).
\**** direct-hit target takes 25 impact + 50 blast (Bullet.gd:59-61, 155-160).

AoE factors are rough "targets meaningfully damaged per trigger pull in a wave-10+ horde" estimates (pierce N ~ 1+0.5N,
Tesla = geometric sum of falloff, cone/blast from area). They are judgment, not measurement.

Reading: base sustained single-target DPS is a tight band (64-139, 2.2x spread); the starter pistol sits at 86.
The two outliers by horde DPS are the Flamethrower and Acid Cannon (~4-5x), but the Flamethrower's real advantage
is the proc interaction in F2, not its base numbers.

---------------------------------------------------------------------------------------------------------------

## 2. Multiplier stack

### 2.1 Rarity / affix (loot/Affixes.gd:30-71, loot/Rarity.gd:22-32, loot/LootRoller.gd:34-42)
Talent slots per rarity: 0,0,1,1,2,3,3,4,5. Signature stat always rolls (LootRoller.gd:36-39).

| rarity | talents | Razor dmg% | Razor fire% | Razor DPS x min/mid/max | Brutal (dmg x fire x +multishot) on a 1-projectile gun min/mid/max |
|---|---|---|---|---|---|
| 1 Rusted | 0 | 6-14 | - | 1.06 / 1.10 / 1.14 | - |
| 2 Salvaged | 0 | 12-24 | - | 1.12 / 1.18 / 1.24 | - |
| 3 Hardened | 1 | 20-40 | - | 1.20 / 1.30 / 1.40 | - |
| 4 Lethal | 1 | 32-58 | 12-22 | 1.50 / 1.75 / 2.03 | - |
| 5 Savage | 2 | 48-84 | 18-30 | 1.80 / 2.18 / 2.63 | 3.4 / 5.1 / 7.4 |
| 6 Carnage | 3 | 64-110 | 28-44 | 2.28 / 2.92 / 3.75 | 6.5 / 9.7 / 14.3 |
| 7 Merciless | 3 | 85-145 | 35-55 | 2.85 / 3.91 / 5.44 | 8.3 / 15.3 / 26.7 |
| 8 Apocalypse | 4 | 115-195 | 45-68 | 3.91 / 5.86 / 9.22 | 15.3 / 28.4 / 53.4 |
| 9 Armageddon | 5 | 155-265 | 60-90 | 6.38 / 12.4 / 36.5 | 31 / 72 / 245 |

The steepness is intended. Two things inside it are worth knowing because they are not what the tooltip implies:
- fire_rate% is an interval cut, so value is 1/(1-p): +55% = x2.2, +68% = x3.1, +90% = x10 (Gun.gd:472-473).
- multishot is +N projectiles on any base (Gun.gd:481-487): +3 on an AK is x4, +6 is x7; on a 5-pellet shotgun +3 is x1.6.
- reload 60-95% at r9 hits `RELOAD_TIME_FLOOR` 0.15 s (GameConfig.gd:164) — reload effectively disappears.

### 2.2 Level-up cards (logic/Upgrades.gd, logic/UpgradeApply.gd, LevelUpUI.gd:175-178)
Odd levels = 3 random of the 12 player cards, even levels = 3 random of the gun's 6-8 card pool (Upgrades.gd:83-84).
NO card has a stack cap except Quick Step (40%) and Second Wind (once).

| card | value | stacking | cap | cite |
|---|---|---|---|---|
| Hollow Points | +20% dmg | multiplicative 1.2^n | none | GameConfig.gd:26, Gun.gd:469 |
| Hair Trigger | "+15% fire rate" = interval x0.85 = +17.6% | mult 1.176^n | none (frame cap only) | :27, Gun.gd:472 |
| Extra Barrel | +1 projectile (Tesla: +1 jump) | additive count; x2 on a 1-proj gun | none | Gun.gd:481-487 |
| Armor Piercing / Ricochet | +1 | additive | none | Gun.gd:492-496 |
| Incendiary | +8 dps / 3 s burn | burn_dps additive per pick, enemy burn is max-wins | none | :31-32, Gun.gd:498-501 |
| Fast Hands / Extended Mag | -20% reload / +50% mag | mult | reload floor 0.15 s | :164-166 |
| Long Barrel / Overpressure / Choke | +15% / +15% / -30% spread | mult | - | :28-30 |
| Kill Shot | +5 crit-chance pts AND +1.0 crit mult per pick | both ADD -> DPS = 1 + 0.05 n^2 | none | :347-348, Gun.gd:515-517 |
| Swift Feet | +10% move | mult, HARDCODED 0.10 | none | UpgradeApply.gd:9 |
| Tough Hide / Regen / Magnet | +20 HP / +1 HP/s / +25% | add / add / mult, HARDCODED | none | UpgradeApply.gd:11-15 |
| Iron Skin | -15% CONTACT damage only | mult 0.85^n | none | :341, Player.gd:319-320 |
| Quick Step | +8% dodge | additive | 40% (5 picks) | :342-343 |
| Quick Reset | -15% dash CD | mult, no floor | none | DashState.gd:38-39 |
| Fast Learner | +20% XP | mult 1.2^n | none | :345, Player.gd:549-550 |
| Silver Tongue | +20% coins | mult | none | RunStats.gd:83-84 |
| Spike Armor | reflect 2x bite | additive | none | :349 |
| Second Wind | revive 50% | once | 1 | :350 |

Expected value of one gun card under a greedy "damage > fire rate > anything" policy with a 3-of-8 offer:
P(damage offered)=37.5%, P(fire rate but not damage)=26.8% -> geometric mean x1.138 per gun level.

### 2.3 Characters (logic/Characters.gd:58-130)
| char | price | passive | DPS value |
|---|---|---|---|
| Ryan | 0 | +50 HP; AK-47 only: +25% dmg, "+15%" fire; dash = instant AK reload | x1.47 on ONE gun (GameConfig.gd:146-148); dash-reload lifts AK sustained 125 -> ~183 (another x1.47) |
| Jimbo | 600 | +50% move; sniper only: +25% dmg, +15% fire, -20% reload | x1.47 on one gun (:149-151,167) |
| Bob | 400 | +25% pickup | none |
| Alstar | 2400 | "+30%" fire with ANY rarity>=5 gun = x1.43; dash shockwave 50 dmg r320 force 1200 carrying the gun's talents | x1.43 on every purple+ gun (:154-158) |
| Janitor | 2800 | +1 coin/kill; dash slick 50% slow r90 4 s | none |
| Delivery Girl | 3200 | +20% pickup; dash mine 45 dmg r110 | flat 45 per dash (:182-184) |
| Jackson | 3600 | Heavy (minigun/GL/LMG): +25% dmg, +15% fire | x1.47 on three guns (:933-934) — identical constants to Ryan/Jimbo |

### 2.4 Talents (loot/Talents.gd, loot/TalentEngine.gd)
- Crit: chance and mult ADD across all crit talents and Kill Shot cards (TalentEngine.gd:24-26). Max three-talent roll
  72% @ x4.9 = x3.81 expected; Double Tap adds ~+0.26.
- Frenzy (Bloodrush 15-30 / Adrenaline 30-50 / Rampage 45-70): max-wins channel (Gun.gd:180-182) but applied as
  `fire_interval * (1 - frenzy)` (Gun.gd:245) -> x1.18-1.43 / x1.43-2.0 / x1.82-3.33, multiplicative with everything.
- Vulnerable (Chalk 8-15 / Marked 15-35 / Death Warrant 40-70): max-wins, capped +100% (Enemy.gd:286-289, 603-604);
  bosses have no `apply_vulnerable` -> immune.
- Execute (Pink Slip 3-6 / Mercy 5-10 / Executioner 8-15 / Reaper 15-25): threshold check, no boss exclusion
  (TalentEngine.gd:257-261; BossBase.gd:157,229). Thresholds do not stack — only the largest matters.
- Curb Stomp +15-30% vs hampered; Clock In +40-80% on ONE shot per mag; Last Call avg +15-30% (TalentEngine.gd:169-176).
- Rebar/Railbreaker: +1-2 / +2-4 pierce, damage compounds per pierce (Bullet.gd:129-134). Bullets only.
- FLAT-number talents (do not scale with gun damage or wave): all explode/nova/mine/pool/DoT/lifesteal/shatter values.
- %-of-gun-damage talents (scale correctly): chain family, Death Rattle, Double Tap.
- Boss immunity (by missing methods): freeze, pin, slow, fear, poison, vulnerable. Bosses CAN be ignited and executed.

### 2.5 Relics (logic/Relics.gd:42-74, RelicEffects.gd:111-158) — in-run, one choice per boss kill, 4 slots (6 with Overstocked)
DPS relics: Manager's Stapler x1.40 (heals halved), Expired Drink interval x0.75 = x1.33 (+25% move, -30 max HP),
Glass Edge x1.25, Accelerant x1.25 vs burning (also bosses, BossBase.gd:235-236), Hairpin x1.176, Chain Letter +1 pierce.
Best four = x2.92; six slots (Overstocked + all five) = x3.43. All multiplicative with the rest.
Survival: Dead Man's Vest (cheat death every boss cycle), Blood Pact (1 HP/kill ~ 4 HP/s late), Field Kit 1.5 HP/s, Vital Surge +40.

### 2.6 Benefits (logic/Benefits.gd:50-75, GameConfig.gd:610-621) — NO damage anywhere
Max: +20 HP, +10% move, +15% XP, -20% dash CD, 3 rerolls, +10% coins, 1 revive. Per-level steps are +4 HP / +2% / +3%.

### 2.7 Coworkers (Companion.gd:77-106, logic/Coworkers.gd:123-124)
`stat_mult = 1 + 0.18(r-1)` multiplies BOTH damage and rate, so DPS scales with mult^2.
Cat 10 DPS at r1 -> 24 (r4) -> 60 (r9) -> 74 with SHARP. Drone 8.2 -> 19 -> 49 -> 61. Flat; never scales with wave.

### 2.8 Theoretical maximum (static, before any level-up card)
r9 Brutal perfect roll on a 1-projectile gun 245 x character 1.47 x relics 3.43 x crit 3.81 x Rampage 3.33 x Death Warrant 1.7
x Reaper 1.33 = ~3.6e4 x base on paper. In practice the fire-rate part is clipped by the one-shot-per-frame cap
(pistol: 0.2 s x 0.1 x 0.85 x 0.85 x 0.75 x 0.3 = 0.0033 s, clipped to 0.0167 s = x12 instead of x62) and by mag/reload.
Cards then multiply on top with no ceiling (section 4).

---------------------------------------------------------------------------------------------------------------

## 3. XP / level pacing

- Curve: `xp_for_level(L) = 5 + 3L` (logic/XpCurve.gd:6-7, GameConfig.gd:137-138). Cumulative to level n = 5n + 1.5 n(n-1).
  LINEAR cost per level.
- XP per kill: gem value = round(enemy max_health / 50), clamped 1..15 (Enemy.gd:655-659, GameConfig.gd:139-140).
  Since trash HP = 50 x 1.12^(wave-1) (logic/DifficultyCurve.gd:7-21), XP per kill grows ~12% per wave until the cap:
  avg gem (type-mix weighted) = 1.0 (w1), 2.0 (w5), 4.5 (w10), 6.9 (w15), 9.5 (w20), 13.3 (w25), 15 (w30+).
- Elite: gem x3 on a body that already has x2.5 HP = 7.5x (GameConfig.gd:514-515) — hits the 15 cap from wave 8.
- Boss: 30 gems of value 1 = 30 XP flat, never scaled (BossBase.gd:252-260, GameConfig.gd:73).
- Spawn rate: 1/s at wave 1, x1/0.92 per wave, floor 0.25 s = 4/s from wave 18 (8.5 min); halved while a revealed boss lives
  (DifficultyCurve.gd:24-27, Spawner.gd:40-42).
- XP income at full clear, 85% gem pickup: 0.8 XP/s (0 min), 1.0 (1), 5.0 (3), 9.2 (5), 24.8 (8), 34.7 (10), 45 (12), 51 (20).

Assumptions for the table: spawn x0.9 (boss-alive time), +15% hive brood from wave 7, boss killed on schedule (+30 XP each),
no XP multipliers unless stated, crates ignored.

| scenario | 1 min | 3 | 5 | 8 | 10 | 15 | 20 |
|---|---|---|---|---|---|---|---|
| FULL CLEAR (100% of spawns killed, 85% gems picked) | 4 | 13 | 25 | 50 | 69 | 117 | 155 |
| PLAUSIBLE (80% killed, 80% picked) | 3 | 11 | 22 | 43 | 60 | 101 | 135 |
| CONSERVATIVE (55% killed, 70% picked) — struggling fresh save | 2 | 9 | 17 | 33 | 46 | 79 | 104 |
| PLAUSIBLE + Night School 5 + STUDIOUS + 2 Fast Learner (x1.82) | 5 | 15 | 30 | 59 | 81 | 138 | 182 |

Level = cards taken (one card per level; half gun, half stat). Dawn/extraction is at 8:00-9:50
(logic/ShiftClock.gd:13-14, GameConfig.gd:547-549), so a normal winning run ends around level 43-60.
At 10 min in the PLAUSIBLE row income is 27 XP/s against a level-50 cost of 155 -> a level-up pause every ~5.7 s.

---------------------------------------------------------------------------------------------------------------

## 4. Modeled player DPS

Method: level trajectory taken from section 3 (decoupled from DPS to avoid a feedback loop), gun cards allocated in
expectation under the greedy policy (37.5% damage, 26.8% fire rate, 14.3% reload, 14.3% mag per gun level), Kill Shot
taken on 18% of stat levels (25% offer x ~70% take), fire interval clipped at 1/60 s, reload floor 0.15 s,
`eff DPS = paper sustained x fire_eff(t) + flat companion DPS`. Boss HP uses a x1.3 roster-average multiplier.
Treat t >= 15 min as "shape only".

(a) FRESH — Rusted Razor Pistol (+10% dmg), Ryan with no AK, no talents/benefits/coworker, CONSERVATIVE levels, Glass Edge at 5 min
| t | wave | cards | paper DPS | eff DPS | x vs t=0 | shambler HP (x) | TTK s | boss HP | boss TTK s |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 1 | 0 | 94 | 75 | 1.0 | 50 (1.0) | 0.66 | 3,068 (w5) | 41 |
| 1 | 3 | 2 | 108 | 86 | 1.1 | 63 (1.3) | 0.73 | 3,068 | 36 |
| 3 | 7 | 9 | 165 | 119 | 1.6 | 99 (2.0) | 0.83 | 3,068 | 26 |
| 5 | 11 | 17 | 366 | 238 | 3.2 | 155 (3.1) | 0.65 | 5,408 (w10) | 23 |
| 8 | 17 | 33 | 1,246 | 685 | 9.1 | 307 (6.1) | 0.45 | 16,795 (w15) | 25 |
| 10 | 21 | 46 | 3,622 | 1,811 | 24 | 482 (9.6) | 0.27 | 52,162 (w20) | 29 |
| 15 | 31 | 79 | 45,187 | 18,979 | 252 | 1,498 (30) | 0.08 | 503,173 (w30) | 27 |
| 20 | 41 | 104 | 299,350 | 119,740 | 1,588 | 4,653 (93) | 0.04 | 4.85M (w40) | 41 |

(b) MID — Lethal(r4) Razor AK-47 (+45% dmg, -17% interval), weapon lvl 8 with Killshot (13% / +60%), Ryan AK perk, r3 drone 15 DPS,
Night School L3, PLAUSIBLE levels, Glass Edge at 2.5 min, Hairpin at 7.5 min
| t | cards | paper DPS | eff DPS | x vs t=0 | shambler TTK s | boss TTK s |
|---|---|---|---|---|---|---|
| 0 | 0 | 304 | 258 | 1.0 | 0.19 | 12 |
| 1 | 3 | 368 | 309 | 1.2 | 0.20 | 10 |
| 3 | 11 | 888 | 654 | 2.5 | 0.15 | 5 |
| 5 | 22 | 2,291 | 1,504 | 5.8 | 0.10 | 4 |
| 8 | 43 | 13,994 | 7,712 | 30 | 0.04 | 2 |
| 10 | 60 | 56,565 | 28,298 | 110 | 0.02 | 2 |
| 15 | 101 | 594,572 | 249,735 | 966 | 0.01 | 2 |
| 20 | 135 | 3.05M | 1.22M | 4,717 | 0.00 | 4 |

(c) LATE — Merciless(r7) Razor AK-47 mid rolls (+115% dmg, -45% interval, +60% mag, -47% reload), weapon lvl 22 with
Killshot + Adrenaline (40%, 85% uptime) + Reaper 20%, Ryan AK perk, r6 SHARP cat 45 DPS, max benefits, boosted-XP levels,
relics Glass Edge 2.5 / Hairpin 5 / Stapler 7.5 / Drink 10
| t | cards | paper DPS | eff DPS | x vs t=0 | shambler TTK s | boss TTK s |
|---|---|---|---|---|---|---|
| 0 | 0 | 1,451 | 1,206 | 1.0 | 0.04 | 3 |
| 1 | 5 | 2,049 | 1,685 | 1.4 | 0.04 | 2 |
| 3 | 15 | 5,775 | 4,203 | 3.5 | 0.02 | 1 |
| 5 | 30 | 21,515 | 14,030 | 12 | 0.01 | <1 |
| 8 | 59 | 176,927 | 97,355 | 81 | ~0 | <1 |
| 10 | 81 | 577,829 | 288,960 | 240 | ~0 | <1 |
| 15 | 138 | 9.3M | 3.9M | 3,248 | ~0 | <1 |
| 20 | 182 | 66.8M | 26.7M | 22,159 | ~0 | <1 |
A Brutal-affix r7 (+3 multishot) instead of Razor is ~2.3x archetype (c) at every row.

What the model says
- Gear gap at t=0: (a) 75 : (b) 258 : (c) 1,206 effective DPS = 1 : 3.4 : 16 against enemies whose HP does not know about gear.
  That is the intended steep ladder; (c) is never HP-checked at any point in a run.
- The only HP-check in the game is the fresh save between ~2 and ~5 minutes: (a)'s DPS is x1.6 at 3 min while trash HP is x2.0.
  A self-consistent run of the sim (kills limited by DPS) has (a) killing 93% of spawns at 3 min, 67% at 5 min and 53% at
  8 min with a backlog of 130-400 live enemies — i.e. that is where fresh saves die.
- Anyone who gets past minute ~6 out-scales the game: in-run cards give x24 (a) to x240 (c) by 10 min versus x9.6 trash HP
  and x17 boss HP. Card growth is exponential in levels and levels accelerate (section 3).
- Composition of (b)'s x110 at 10 min: damage cards x7.8, fire-rate/mag/reload x~4.5, Kill Shot x3.4 (5.4 picks), relics x1.47.

---------------------------------------------------------------------------------------------------------------

## 5. Ability evaluation (logic/Abilities.gd:22-45, AbilityController.gd, GameConfig.gd:862-934)

| char | ability | CD / duration | uptime | offensive value | survivability value | scales with gear/wave? |
|---|---|---|---|---|---|---|
| Jimbo | AIMBOT | 240 / 60 (:893-894) | 25% (31% of a 9.7-min run: 3 casts) | removes fire_eff: x1.19 at 0 min, x1.46 at 5, x1.9 at 10, x2.3 at 15+ while live -> +5% to +30% run-average gun DPS | fires while moving at 330 px/s (363 with Comfy Shoes 5) vs trash cap 240 / hard cap 360 (:57,234): near-untouchable for 60 s | YES — the only one of seven |
| Jackson | SENTRY TURRET | 45 / 60 (:879-880) | 100% (15 s of each CD wasted; recast = free reposition) | 26 / 0.5 s = 52 DPS flat single-target, range 620 (Turret.gd:66-106) = +69% of archetype (a) at 0 min, +44% at 3, +22% at 5, +8% at 8, +3% at 10; +20% -> 0.2% for (b); <4% always for (c) | body-blocks nothing, taunts nothing | NO |
| Alstar | JACKPOT | 60 / instant | 4 equal rolls (AbilityController.gd:242-275) | NUKE 220 r480 with gun talents (1 shambler-kill until wave ~14); TRIGGER HAPPY interval x0.6 for 6 s = +1.7% run-average; PAYDAY = zero combat value | DEEP FREEZE 3 s on all trash | NO (nuke flat; frenzy yes but tiny) |
| Delivery Girl | AIR DROP | 40 / 1.5 s delay | - | 160 r300 no talents = 4 DPS-equivalent per target; one-shots shamblers until wave 11 | 2 x 25 HP = 1.25 HP/s, + 9 XP | NO |
| Ryan | CLEAR OUT | 40 | - | 0 damage | knockback 1400 in r520 + deletes every enemy projectile | n/a (always relevant) |
| Janitor | CLOSING TIME | 45 / 8 | 18% | 0 damage, +2 coins/kill inside | 50% slow in r270 | n/a |
| Bob | SECOND SHIFT | once | - | 0 | one extra life at 50% HP + 2 s invuln; burns BEFORE Union Rep / Vest / Second Wind so it stacks with all three (Player.gd:333-363) | n/a |

AIMBOT — does it trivialize play? During its window, yes: it deletes both of the game's core constraints (stop-to-shoot
and move-to-aim) on the character who also has +50% move speed, so Jimbo circle-kites faster than anything in the trash
roster while firing continuously. Over a whole run, no: 25% uptime, and casts at 0:30 / 4:30 / 8:30 cover boss 2 and
two thirds of the dawn surge but leave 70% of the run as normal play. It is the strongest ability by a wide margin and
the only one whose value GROWS with gear and time, but the 240 s cooldown is doing its job. The thing actually out of
line is the package: best ability + best defensive passive + a x1.47 gun perk for 600 coins (second cheapest).

TURRET + Heavy bonus — out of line? No. The Heavy perk is byte-identical to Ryan's AK and Jimbo's sniper perks
(0.25 / 0.15), just on three guns instead of one. The turret is the best flat-damage ability for a fresh save in
minutes 0-4 (+44-69% DPS) and is statistically invisible after minute 8 for anyone, and at every minute for a geared
player. Its problem is the opposite of "too strong": 26 damage never scales while trash HP is x9.6 by 10 min.
The 60 s life vs 45 s CD overlap buys nothing but a reposition.

Power ranking (total, mid-to-late progression)
1. Jimbo — AIMBOT + 330 move + sniper x1.47
2. Alstar — x1.43 on EVERY purple+ gun, and a r320 knockback-1200 shockwave on a 1.5 s dash that applies the gun's
   on-hit talents (execute, freeze, mark...) to everything around him; JACKPOT itself is weak
3. Jackson — x1.47 on the three best proc carriers (minigun/LMG/GL); turret early only; no defensive tool
4. Ryan — +50 HP, CLEAR OUT, x1.47 (x2.16 with dash-reload) but only once an AK drops; nothing for a fresh save's pistol
5. Delivery Girl — small sustain + flat mines
6. Bob — one extra life, zero throughput
7. Janitor — economy character, zero damage
For a fresh save the order of the top is Jackson > Jimbo > Ryan (Alstar's perk is dead below rarity 5).

---------------------------------------------------------------------------------------------------------------

## 6. FLAGS (most severe first)

F1. XP income is exponential, level cost is linear -> level-up spam and unbounded card stacking.
    Gem value tracks enemy HP (x1.12/wave, Enemy.gd:655) while `xp_for_level = 5 + 3L` (XpCurve.gd:7). Income goes
    1 -> 35 -> 51 XP/s; plausible level 22 at 5 min, 43 at 8, 60 at 10, 135 at 20. At 10 min that is a pause-the-game
    card pick every ~5.7 s. Because no gun card is capped (F3) this is also the root of the late-run DPS blow-up.
    Fast Learner (x1.2^n, Player.gd:549-550) feeds the same loop — an uncapped version of the sim diverged.

F2. Flat per-hit procs have no proc coefficient or ICD, so hit-rate is worth 20-100x.
    - Shatter: a hit on a frozen enemy detonates 40-90 AoE EVERY hit and never thaws it (TalentEngine.gd:266-273,
      Enemy.gd:294-305). Minigun + Cold Snap avg roll = ~1,080 flat AoE DPS vs the gun's own 160; sniper = ~11.
      Flamethrower: every target in the cone does this at 20 Hz.
    - Lifesteal: flat heal per hit (TalentEngine.gd:229-233). Bloodthirst avg 13% x 4 HP = 10.4 HP/s on a minigun
      (21.6 max roll), 52-108 HP/s on a flamethrower with 5 targets, 0.6 HP/s on a sniper. Regeneration card = 1 HP/s.
    - Poison: `_dot_dps += dps` per proc with duration refreshed, no cap (Enemy.gd:274-277). Plague on a minigun
      adds ~260 dps per second of contact.
    Net: minigun / flamethrower / LMG / PDW are the dominant talent carriers; the same talents are near-dead on
    sniper / AMR / railgun / slug gun.

F3. Kill Shot stacks quadratically and mis-describes itself. Each pick adds +5 chance AND +1.0 multiplier
    (Gun.gd:515-517), text says "+5% Crit Chance (2x Damage)" (Upgrades.gd:29). DPS = 1 + 0.05 n^2: x1.05, 1.20, 1.45,
    1.80, 2.25, ... x4.2 at 8 picks; with an average Hollowpoint already on the gun one pick is +28%, five picks x4.26.
    Compare Hollow Points +20%. Related: Extra Barrel is +100% on any 1-projectile gun (Gun.gd:481-487).

F4. Bosses are not execute-immune. `take_damage(1_000_000)` fires whenever `health_fraction() <= threshold`
    (TalentEngine.gd:257-261) and BossBase exposes both methods (BossBase.gd:157,229). Reaper 15-25% deletes up to
    13,000 HP of a wave-20 boss in one hit and skips most of every boss's final phase; Alstar's dash applies it in r320.

F5. "Fire rate +X%" is an interval cut everywhere, so the real value is 1/(1-X) and explodes at the top.
    Rampage "+70%" = +233% (Gun.gd:245); Alstar "+30%" = +43%; r8 affix "+68%" = x3.1; r9 "+90%" = x10 (Affixes.gd:68,71).
    Not a complaint about steep rarity — the displayed number and the delivered number diverge by up to 10x.

F6. Fire rate is quantized to rendered frames and hard-capped at one shot per frame (Gun.gd:233-248, `_process`, no
    carry-over). At 60 fps LMG/nailgun lose 16%, PDW/AK/machine pistol 10%. A Hair Trigger on a minigun
    (0.05 -> 0.0425 -> 0.0361) changes nothing for the first two picks (still 3 frames). Minigun/flamethrower have only
    3x fire-rate headroom before the cap, sniper 54x. DPS is higher on 90/120 Hz phones.

F7. Dead or near-dead options (each verified in code)
    - Incendiary card on the Tesla: in its pool (Weapons.gd:74) but `_fire_lightning` never ignites (Gun.gd:519-578). 100% dead.
    - Incendiary card on the Flamethrower: `maxf(FLAME_BURN_DPS 30, burn_dps)` (Gun.gd:640) — picks 1-3 (8/16/24) do
      nothing, pick 4 gives +2 dps. In its pool (Weapons.gd:82).
    - Acid Cannon: never calls process_hit and pools deal raw damage (Bullet.gd:53-63,161-166; HazardZone.gd:94) ->
      crit, Kill Shot, and every on-hit/on-kill talent are dead on it; its listed 35 damage is never dealt.
    - Affix stats that do nothing: multishot on Railgun/Flamethrower (projectile_count unused in Gun.gd:587,632);
      pierce/ricochet/bullet_speed on Tesla/Railgun/Flamethrower; pierce/ricochet on GL/Acid (shells ignore pierce,
      Bullet.gd:53-55). Heavy/Hollow/Brutal all have a multishot or pierce SIGNATURE, so e.g. an r8 Brutal Railgun has
      4 of 6 stats dead including the guaranteed one. Overflow/Mag Dump/Rebar/Railbreaker are dead on the same guns.
    - Clock In on big mags: +40-80% on 1 of 150 shots = +0.27-0.53% DPS (minigun), 0.4-0.8% (LMG/flamethrower).
    - Tighter Choke on SMG/PDW/nailgun (spread .05-.07 rad = inside the 28 px hit width at max range) and on any gun
      with 2+ projectiles below 0.20 spread, because the fan uses `maxf(spread, 0.20)` (Gun.gd:375).
    - Multiple execute talents on one gun: only the highest threshold matters.
    - Flat talents vs HP growth: Firecracker 8-16 = 24% of a wave-1 shambler, 2.8% at wave 20, 0.9% at wave 30;
      Short Fuse 10-22 per reload; Incendiary card 24 total = 5.6% at wave 20.
    - Relics: Static Soles = 20 damage per dash in r90 (GameConfig.gd:106-107) = 4.6% of a wave-20 shambler;
      Spare Parts = +1 one-XP gem per crate (:115) ~ 1% of XP income by 5 min; Heavy Rounds has no DPS effect and is
      fully dead on Tesla/Railgun/Flamethrower; Cursed Nametag's gem x2 is 100% eaten by the 15 cap from wave 8.
    - Spike Armor: 2x bite = 40% of attacker HP at wave 1, 12% at wave 20, 6% at wave 30, and requires being bitten.
    - Benefits per level: +4 HP (less than half a wave-1 bite), +2% move (4.4 px/s), +2% coins — imperceptible steps.
    - Coworker damage: 8-74 DPS flat; under 6% of a Lethal gun at t=0 and under 0.1% by 10 min. Utility only.

F8. Boss XP is flat 30 (BossBase.gd:252-260; comment: "enough to pop a level-up"). True at wave 5 (level ~9 costs 32);
    at wave 20 it is 16% of a level = three shambler kills. Same shape: `XP_GEM_VALUE_MAX 15` makes the elite x3 bonus
    progressively dead from wave 8 and fully dead from wave 25.

F9. Nothing the player places scales. Turret 26, NUKE 220, AIR DROP 160, Alstar shock 50, Delivery mine 45, cat 40,
    drone 9, every explode/nova/mine/pool talent — all fixed numbers against HP that is x3.1 at 5 min, x9.6 at 10, x30 at 15.
    Every character ability except AIMBOT is therefore an early-game tool.

F10. Character price vs power is inverted: Jimbo (#1) costs 600, Janitor (#7) 2,800, Delivery Girl (#5) 3,200
     (Characters.gd:22-43). Ryan's and Jackson's gun perks are dead on the three starter guns (pistol/SMG/shotgun,
     loot/Inventory.gd:238).

F11. Config hygiene (grep-verified)
    - `DEBUFF_SLOW_DURATION` (GameConfig.gd:213) is never read; DebuffApplier uses `DEBUFF_JAM_DURATION` as the slow default
      (patterns/DebuffApplier.gd:16).
    - `GUN_FIRE_INTERVAL`, `GUN_RANGE`, `BULLET_DAMAGE` (:19-22) are only Gun field defaults, always overwritten by
      `configure()` (Gun.gd:10-13,103-110; Main.gd:152) — editing them changes nothing.
    - `ENEMY_LATE_HP_GROWTH` 1.12 == `ENEMY_HP_GROWTH` 1.12 (:54,63): the documented "steeper late ramp" is a no-op for HP.
    - Card magnitudes 0.10 / 20 / 1.0 / 0.25 are hardcoded in UpgradeApply.gd:9-15; gun-card descriptions are hardcoded
      strings (Upgrades.gd:51-71) and Coworkers.trait_desc is hardcoded (Coworkers.gd:82-99) despite the GameConfig
      comment saying it is derived (:713-715). Changing the consts desyncs the text.
    - Affix `min_talents`/`max_talents` are unread legacy (documented, Affixes.gd:20-22).

Model caveats: `fire_eff`, kill fraction, gem pickup, card-pick policy and AoE factors are assumptions stated above;
absolute DPS past ~10 min is shape-only. Every code claim in section 6 was read directly in the cited lines.

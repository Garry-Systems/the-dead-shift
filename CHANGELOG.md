# Changelog — The Dead Shift

What's new in each build. The version you have is shown in-app and under
**Settings ▸ Apps ▸ The Dead Shift** (`0.1.<build>`). Grab the latest APK from the
[**android-latest** release](https://github.com/Garry-Systems/the-dead-shift/releases/tag/android-latest).

## v0.1.53 — Clock In Tomorrow, Too (2026-07-06)

- **CHALLENGE BOARD** — three challenges rotate daily: kill counts, elite hunts, elemental kill quotas, reach 2 AM, survive a Blood Moon, win an extraction, fuse weapons and more — each paying out a crate on completion. Fresh set every day.
- **DAILY SHIFT** — one attempt, once a day: a seeded run where the night's events, elites, and horde composition are locked to the date. Same shift for everyone — post your pay stub. Best daily score lives on your RECORDS page.

## v0.1.52 — Feed the Beast (2026-07-06)

- **WEAPON FUSION** — duplicates are food now. Open any gun and hit **FEED**: sacrifice a same-model duplicate to pump weapon XP into it (talents unlock on the spot — higher-rarity sacrifices are worth a fortune). Feed it a duplicate of **equal or higher rarity** and it also **rerolls the gun's weakest stat** — shown honestly, old → new, and yes, the dice can come up worse. Your equipped gun can eat but never be eaten. Fusions tracked on the RECORDS page.

## v0.1.51 — For the Record (2026-07-05)

- **RECORDS page** — a new hub screen with your lifetime story: total kills, runs worked, coins earned, bosses and elites dropped, best wave, best clock-out time, shifts survived, Armageddons pulled, and kill counts for every gun you've ever carried.
- **The game HITS now** — crit kills freeze the world for a split second, explosions shake the screen (scaled to the blast), boss slams thump, the extraction chopper rattles the whole forecourt. One EFFECTS toggle (next to the sound switches) turns it all off if it's not your thing.

## v0.1.50 — No Two Shifts Alike (2026-07-05)

The run itself finally rolls the dice:

- **ELITE ZOMBIES** — from wave 6, any zombie can spawn elite: **Armored** (shrugs off 30% of damage), **Volatile** (green ring — its death blast is telegraphed, and aimed at YOU), **Splitter** (halves into runners), **Alpha** (a gold-ringed pack leader buffing everything around it). Elites carry 2.5× health, triple XP, and bonus coins.
- **NIGHT SHIFT EVENTS** — random events crash the shift: **BLOOD MOON** (spawns double, every kill pays bonus coins), **FOG BANK** (can't see far, gems worth double), **POWER SURGE** (all your electricity chains 2 extra targets), **RUSH HOUR** (a convoy of wrecks rolls in as fresh cover).
- **DAWN EXTRACTION** — 6:00 AM is a real ending now: the radio crackles RESCUE INBOUND, a 90-second mega-surge hits, and a chopper sets down at the gas station. Make it to the LZ and you **WIN the shift** — 1.5× pay, a survivor's stub, and a new "shifts survived" record. Or ignore the ride and keep working. Your call, clerk.

## v0.1.49 — The Talent Tree Grows Teeth (2026-07-05)

**29 new talents — the pool nearly doubles to 60**, and 16 of them are mechanics the game has never had:

- **Black Friday** rips open a gravity well that drags the horde into a pile. **Double Tap** makes your crits echo with a phantom second hit. **Septic Shock** ruptures every burn and poison on a target in one burst; **Outbreak** spreads them to everything nearby on a kill.
- **A full crowd-control build**: **Deadbolt** pins targets on any gun, **Curb Stomp** punishes anything slowed/frozen/pinned, **Closing Time** slows everything near you.
- **Playstyle picks**: **Clock In** (first shot after a reload hits huge) vs **Last Call** (the mag hits harder as it empties). **Brass Picker** loads kills back into your mag. **Graveyard Shift** spikes your fire rate when you're nearly dead.
- **Kills that keep killing**: **Death Rattle** arcs lightning, **Bile Spill** pools acid, **Parting Gift** leaves a mine. **Dead Man's Switch** detonates when something dares to bite you. **Night Terror** sends zombies fleeing in fear — while spitters fire over their shoulder as they run.
- Plus deeper tiers for every family that was missing one — tier-1 finally has real variety (5 → 15 options), so early weapon levels matter.
- Every one of them has its own visual and callout, riding the new effects system. New pulls only — your current guns keep their rolled talents.

## v0.1.48 — See Your Power (2026-07-05)

Every talent proc in the game is now VISIBLE — nothing happens silently anymore:

- **Gold crit numbers** pop off every critical hit (and only crits — no damage-number spam).
- **Chain lightning is real lightning** — Live Wire and Arc Welder draw their actual arcs between targets.
- **Executes announce themselves** — a blood-red flash and "EXECUTED" when Executioner/Mercy/Reaper delete a target.
- **Freeze shatters ring** with an indigo burst and "SHATTER"; **marked enemies glow gold**; **poisoned enemies tint green**; **lifesteal streams blood motes** back to you; **kill-explosions ring orange at their true radius**; **reload novas finally show their blast**; **piercing rounds visibly power up** as they drill through the line; **fire-rate surges call out** when they kick in.
- **Grenade blasts and Alstar's dash can now CRIT** when your gun carries a crit talent — gold numbers on explosions included.
- Two hidden bugs fixed along the way: stacking two reload-nova or two pierce talents on one weapon no longer drops one of them.
- All of it is mobile-safe: pooled text, capped effects, zero frame cost when nothing procs.

## v0.1.47 — ARMAGEDDON (2026-07-05)

The rarity ladder gets a new ceiling — and a new look:

- **★ ARMAGEDDON ★ — the new top rarity.** Molten gold, **5 talents** (nothing else has more than 4), and its prefixes always roll EVERY stat they can carry, with the fattest ranges in the game. From a basic Footlocker it's a ~1-in-360,000 pull — premium crates cut that down. The dream just got bigger.
- **Apocalypse goes RAINBOW** — the old cyan is gone; Apocalypse weapons now shimmer through the whole spectrum, live, on tiles, in the inspect screen, and on the crate reel.
- **Red and orange traded places** — Carnage (red) is now tier 6 and Merciless (orange) sits above it at tier 7. Same power, same odds — your guns keep everything; only the labels and colors moved.
- Every crate that could reach Apocalypse can now reach Armageddon.

## v0.1.46 — Store-Shelf Ready (2026-07-05)

Launch prep — the boring build that makes the Play Store possible:

- **A real app icon** — a gas pump under the crescent moon, in the game's palette (goodbye Godot robot), with proper Android adaptive-icon layers.
- **A real name** — the app installs as **The Dead Shift** (was "Mobile Game"). ⚠️ The app identity changed, so this installs as a NEW app — delete the old one after installing this.
- **Release pipeline** — a tag-triggered workflow that builds a Play-Store-ready signed .aab (one keystore step remains, documented in docs/RELEASE-SIGNING.md).
- **Privacy policy** — the game collects nothing and says so, hosted and ready for the Play Console data-safety form.

## v0.1.45 — Meet the Staff (2026-07-05)

The boss roster more than doubles — 3 → 7, and the new hires all work the night shift:

- **THE MANAGER** — slow, massive, and never alone: summons staff, jams your gun, and slams the floor.
- **THE NIGHT STOCKER** — fast, charges you down with a telegraphed dash, and drops solid stock crates behind it to wall off your escape routes (capped — it can pressure you, never seal you in).
- **THE FRYER** — floods the floor with grease-fire pools and sweeping heat lances.
- **THE COURIER** — crosses the whole arena in one charge, sprays radial bursts, and slows you down just by being near.
- **Every boss is named on its HP bar**, a **SHIFT CHANGE** banner announces each boss wave, and the original three are still on the payroll. All seven rotate in endless and Boss Rush.

## v0.1.44 — Turn the Sound On (2026-07-05)

The game was silent. Not anymore:

- **A full retro soundscape** — every gun category has its own shot (pistol crack, shotgun boom, sniper ring, heavy chug, energy zap), zombies thud and drop, barrels and pumps explode, gems chime, crates sting on a win, level-ups fanfare, dashes whoosh, Ryan's purge blasts, bosses roar in, and dawn gets its own sting.
- **Music** — a dark menu loop and a driving run loop, both seamless.
- **Mute toggles** — SFX and Music switches in the pause menu and main menu, remembered between sessions.

## v0.1.43 — Pump 3 Is On Fire (2026-07-05)

- **The gas station is HERE** — every endless run now starts on the forecourt of the station where your shift began: the store at your back (solid cover — zombies path around it), a tall GAS price sign, and **three fuel pumps** that absolutely should not be shot. Shoot them anyway: bigger blasts than barrels, chain reactions included. The rest of the wasteland scatters around you as you roam, same as before.

## v0.1.42 — Show Up, Cash In (2026-07-05)

- **Daily login streak** — the daily reward now remembers you. Claim on consecutive days and the crate quality climbs: **day 3+** shifts the roll a whole tier up, **day 7+** guarantees Munitions Cache or better, every day. Miss a day and the streak resets — the popup shows STREAK: DAY N so you know exactly what's on the line.

## v0.1.41 — Clock In (2026-07-05)

The night shift is finally on screen:

- **The shift clock** — endless runs now tick from 10:00 PM toward dawn (1 second = 1 in-game minute). Make it to **6:00 AM** and the DAWN banner pays a survival bonus — then the shift keeps going for as long as you can hold it.
- **SHIFT'S OVER** — the death screen is now an end-of-shift pay stub: base pay, waves, bosses, kills and tips itemized to your total, with your clock-out time stamped on it.
- **★ NEW BEST ★** — beating your record finally looks like it: confetti and a banner instead of the same old screen.
- **Weapon XP on the stub** — see exactly what your equipped gun earned this run and when its next talent unlocks.
- **STORE button on the death screen** — coins in hand, store one tap away.

## v0.1.40 — Twelve Ways to Level (2026-07-05)

- **The level-up pool tripled** — every level-up now draws from 12+ cards instead of the same 4 stat boosts. New picks: **Armor** (take less from bites and boss contact), **Dodge** (chance to ignore hits entirely), **Dash Cooldown**, **XP Gain**, **Coin Gain** (fatter run payouts), **Crit** (chance to double damage), **Thorns** (biters take it back), **Second Wind** (cheat death once per run), **Pickup Radius**, and **Move Speed**. Build variety starts at level 2 now — no two runs level the same.

## v0.1.39 — Welcome to the Night Shift (2026-07-05)

The first five minutes got a full rework — new players now actually learn the game instead of bouncing off it:

- **The game teaches itself** — your first run walks you through the three things nobody knew: DRAG ANYWHERE TO MOVE, STAND STILL TO SHOOT, DOUBLE-TAP TO DASH. Three quick hints, first run only, never again.
- **A real starter kit** — new players begin with a pistol (equipped), an SMG and a shotgun instead of a wall of 21 identical gray guns. The other 18 are yours to discover in crates — which makes every crate pull mean something.
- **Crates open when you buy them** — the reel + reveal now plays immediately after a store purchase or a daily-reward claim, instead of silently dropping the crate into your inventory. Crates waiting in your inventory now say TAP TO OPEN.

## v0.1.38 — The Big Fix-Up (2026-07-05)

A full-codebase audit (every script, adversarially verified) turned up 17 real bugs — including several that have been silently broken since their features shipped. All fixed:

- **On-kill talents work now** — Bloodrush, Gut Bomb, Cluster Bomb, Daisy Cutter and Overflow procs never actually fired (a kill-detection bug meant the game never saw the kill). If your build had an on-kill talent, it just got a real upgrade.
- **Execute talents no longer double-dip** — Executioner/Mercy/Reaper were re-killing already-dead zombies for double kill credit, double XP and double coins. One kill = one payout now.
- **Your save can't be wiped anymore** — saving briefly deleted the old file before writing the new one; a badly-timed app kill in that window lost everything. Saves are now atomic.
- **Dead zombies act dead** — enemies killed by burn/poison used to keep walking, biting, shooting and spawning brood for the rest of the frame. They stop, immediately.
- **Relics uninstall cleanly** — removing a percentage relic could permanently corrupt the stat it touched if you'd taken an upgrade card in between.
- **Weapon inspect crash fixed** — viewing a gun with Concussive or Haymaker crashed the popup.
- **Burn doesn't ghost** — an expired strong burn no longer boosts a later weak one.
- **Smoother late-game hordes** — flamethrower/railgun/Tesla and ricochet shots were doing thousands of unnecessary line-of-sight checks per second; big frame-rate win on busy screens.
- **Acid pools capped at 8** — the oldest pool now fades when you drop a 9th (perf guard; your newest shot always lands).
- **Quality-of-life:** opening a crate with a full inventory now says so (and the message clears once you scrap something); a stray second finger can't freeze menu scrolling anymore; Ryan's purge flash can't stick over the pause screen.

## v0.1.37 — Balance Pass v1 (2026-07-04)

The first full balance pass — difficulty curve, guns, loot feel, and the coin economy all tuned in one sweep.

- **The late-game wall is a slope now** — enemy HP ramps gentler past wave 10 and the spawn rate caps a bit lower, so a good purple-weapon run can push toward minute 10 instead of hitting a cliff at 6–8. Loot tier still rules your run length.
- **Late bosses are scary again** — bosses now keep ramping like the horde does past wave 10 (previously the horde outgrew them), and killing one heals a strong chunk (about a third) instead of a full reset. High risk, real reward.
- **Spitters, exploders and boss attacks scale** — their damage now grows with the waves like zombie bites always did. Wave-2 hits are unchanged; wave-15 hits actually hurt.
- **Six guns tuned:**
  - **Sniper** rounds now **punch through 3 targets** — it finally belongs in its category.
  - **Grenade Launcher** shells deal **direct-hit damage** on the zombie they strike, on top of the blast — no longer dead weight against a lone boss.
  - **Flamethrower** burn is a real damage channel now (3× stronger, burns 3s) — sweep the cone and watch the horde keep melting.
  - **Slug Gun** hits harder (60 → 78) to pay for its slow pace.
  - **LMG** keeps its monster 100-round belt but reloads slower (3.2s → 4.5s).
  - **Acid Cannon** pools melt a touch slower — it was quietly the best boss-killer AND the best crowd gun at once.
- **A purple always feels purple** — every weapon prefix now guarantees its signature stat (a "Brutal" always brings its multishot, a "Hollow" its pierce). God rolls still exist; dud rolls don't. New pulls only.
- **Store shake-up** — the 50/50 Crate is now 700 coins (it was quietly the best deal in the store), the three 500-coin category crates never pay out a gray anymore, and there's a new **Specials Case** (650) for Tesla / Flamethrower / Acid Cannon.
- **Quitting a run pays** — leaving from the pause menu now banks 75% of your coins and counts toward the every-10-games reward. Dying still pays full.
- **Big kills drop big XP** — gem value scales with the enemy's HP (up to 15×), so killing the brute is finally worth more than farming runners.

## v0.1.36 — More Weapons Hit Barrels (2026-06-28)

- **The railgun, Tesla gun, and grenade launcher now damage barrels and destructibles too** — matching the flamethrower. The Tesla can even arc its lightning to barrels. Zapped/blasted/beamed barrels burst as usual.

## v0.1.35 — Flamethrower Burns Barrels (2026-06-28)

- **The flamethrower now damages barrels, crates, and other destructibles** caught in its cone — torch a barrel and it bursts. Previously the flame only hurt enemies.

## v0.1.34 — Flamethrower Flash Fix (2026-06-28)

- **Enemies no longer wash out solid white under the flamethrower** (and the railgun beam / Nail Gun) — the hit-flash was re-firing faster than it could fade, pinning them white and hiding their burn tint. Now it pulses cleanly, so you can actually see enemies burn and take damage.

## v0.1.33 — Apocalypse 4 Talents (2026-06-28)

- **Apocalypse (cyan) weapons now roll 4 talents** — the top rarity gets an extra top-tier talent, so it's a clear cut above (Orange and Red stay at 3). No weapon ever rolls the same talent twice. Applies to newly pulled weapons.

## v0.1.32 — Consistent Talent Counts (2026-06-27)

- **Each rarity now grants a set number of talents** — Orange weapons always have **3** talents (never 2 or 1), and every rarity has a fixed count: Green/Blue **1**, Purple **2**, Orange/Red/Cyan **3** (Gray/White none). Which talents you get is still random — only the count is locked. Applies to newly pulled weapons.

## v0.1.31 — Triple-Tap to Skip (2026-06-27)

- **Triple-tap to skip the crate reveal** — in a hurry? Tap the screen three times while a crate is spinning to jump straight to the result. You still get the exact same weapon, just without the wait.

## v0.1.30 — Smaller Crate Reveal & Gunmetal Weapons (2026-06-27)

- **Crate opening is 20% smaller** — the reveal reel had grown a touch oversized; it's scaled back down 20% while keeping the exact same spin and snap.
- **No more spoiler tiles** — the weapons sitting on either side of your prize are no longer forced to be rares, so the reel doesn't give away the result before it lands.
- **All 21 weapons redrawn** — every gun icon is remade as detailed 64×64 "gunmetal" pixel art (metal body, lit top edge, dark outline, with energy cores, scopes and barrels picked out) in place of the old flat silhouettes.

## v0.1.29 — Nail Gun Pin (2026-06-26)

- **The Nail Gun can PIN zombies** — each nail now has a chance to nail a zombie to the spot for a moment, marked by a lavender "pinned" flash. It roots their feet, not their aim — pinned shooters still fire back. Bosses are immune.

## v0.1.28 — Store Drag-Scroll (2026-06-24)

- **The Store scrolls from anywhere too** — just like the inventory: drag anywhere on the store screen to scroll the list, and a tap still buys or selects. Accidental buys from a scroll-drag are prevented.

## v0.1.27 — Inventory Scroll & Bigger Crate Reel (2026-06-24)

- **Inventory scrolls from anywhere** — drag anywhere on the inventory screen to scroll your collection; a tap still selects a gun or crate.
- **Bigger crate opening** — the reel now fills most of the screen as it rolls by, so each gun is large and easy to read as it passes.

## v0.1.26 — Arsenal Expansion (2026-06-24)

The biggest weapon drop yet — the roster goes from **10 to 21 guns**, so every
category (Pistol, SMG, Shotgun, Rifle, Sniper, Heavy, Special) now has **three** guns.

**3 brand-new fire types:**
- ⚡ **Railgun** (Sniper) — fires an instant beam that pierces *every* enemy in a straight line.
- 💥 **Grenade Launcher** (Heavy) — lobbed shells explode in a crowd-clearing blast with knockback.
- ☣ **Acid Cannon** (Special) — leaves a lingering acid pool that melts and slows enemies (and won't hurt you).

**8 more new guns:** Magnum, Machine Pistol (Pistol) · PDW (SMG) · Auto Shotgun,
Slug Gun (Shotgun) · Battle Rifle (Rifle) · Anti-Materiel .50 (Sniper) · LMG (Heavy).

All new guns drop from crates and roll the full range of rarities, prefixes, and talents.
*(Gun stats are starting values — a balance pass is coming.)*

## v0.1.25 — Environmental Hazards & Cover (2026-06-23)

The arena now has destructible terrain. Explosive **barrels** (fire), **chem drums**
(acid), and **transformers** (electric arcs) scatter the map and can be shot to trigger
area effects that hurt enemies *and* you. **Cars and rubble** act as solid cover that
blocks movement and bullets; **crates** break open for XP and bonus coins.

## v0.1.24 — Three New Guns (2026-06-22)

- **Nail Gun** — fast, cheap, pierces one enemy.
- **Tesla Gun** — arcs chain lightning through the horde.
- **Flamethrower** — a cone of fire that always ignites.
- Every gun now has a **category** label (groundwork for the bigger roster).

## v0.1.23 — Readability Pass (2026-06-22)

- Level-up is now **3 big, easy-to-read cards**.
- The crate-opening reel was reoriented to scroll **vertically** (top → bottom).

## v0.1.22 — Ryan's Purge Tuning (2026-06-21)

- The purge now flashes the screen white on use.
- Added a **15-second cooldown** to the purge effect only — Ryan keeps his dodge dash.
- New **"PURGE Ns / READY"** readout above the ammo.

## v0.1.21 — Free Rewards & Ryan's Dash (2026-06-21)

- **Daily login reward** (a free crate, weighted toward cheaper pulls).
- **Every-10-games reward** (a crate or a gun).
- **Ryan Ace's dash is now a "purge"** — wipes all enemy bullets and instantly reloads the AK.
- Starting bonus raised to 30,000 coins.

## v0.1.20 — New Character: Alstar Tuck (2026-06-21)

A buyable character whose dash drops a **shockwave blast** (knockback + your gun's on-hit
effects) and who gets **+30% fire rate** with purple-tier and better guns.

## v0.1.19 — Crates, Apocalypse Tier & Polish (2026-06-21)

- **More crates** (Scrap, Titan, Apex, 50/50, type-specific packs) with tiered drop odds.
- New top rarity: **Apocalypse** (tier 8) — the ultimate chase pull.
- **Confetti** on rare crate wins; enemies now **bite-and-bounce** instead of sticking;
  enemy projectiles turned **red**; bigger menus/inventory/crate UI.
- Builds now stamp a real version number so phone updates are verifiable.

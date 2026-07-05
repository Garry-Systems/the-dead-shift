# Changelog — The Dead Shift

What's new in each build. The version you have is shown in-app and under
**Settings ▸ Apps ▸ The Dead Shift** (`0.1.<build>`). Grab the latest APK from the
[**android-latest** release](https://github.com/Garry-Systems/the-dead-shift/releases/tag/android-latest).

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

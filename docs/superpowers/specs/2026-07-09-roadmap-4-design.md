# Roadmap 4 — Lore Flavor, Employee Benefits, The Basement, Coworkers

**Date:** 2026-07-09 · **Status:** mini-specs for Larry's picks (A/C/E via buttons + the pre-approved lore pack; B evolutions / D transfer stores / F visitors benched)
**Ship order:** Pack 0 lore → **v0.1.61** · Pack A benefits → **v0.1.62** · Pack E basement → **v0.1.63** · Pack C coworkers → **v0.1.64**
**Process:** each pack = its own plan + SDD execution. Every release: bump the committed `VERSION` file (drives the displayed version since v0.1.60) and tag to match. All numbers are starter values.

---

## Pack 0 — LORE FLAVOR PACK (v0.1.61)

Voice-only, NO new UI containers (Larry's scope pick: no collectible memos, no cutscenes). One new pure registry `scripts/logic/Flavor.gd` (static funcs, probe-able) feeds existing labels:

| Surface | Wire point | Content |
|---|---|---|
| Boss intro one-liner | the SHIFT CHANGE toast / boss-bar appearance path (v0.1.45) — append the line under the boss name | 9 lines, one per boss id (e.g. THE MANAGER — *"he never clocked out."*; THE KAREN — *"she asked for corporate. corporate is dead."*; THE TANKER — *"pump 3 called for a refill."*) |
| Death-screen quip | one rotating line on the SHIFT'S OVER pay-stub footer | ~12 deadpan quips, random per death |
| Rank promotion blurb | PROMOTED popup subtitle | 10 lines, one per rank (TRAINEE→FRANCHISE OWNER) |
| Commendation descriptions | punch-up pass over the 18 existing badge description strings in place | rewrite for voice, same length budget |
| STAFF MEMO | one rotating line on the daily-streak popup | ~14 corporate-apocalypse memos (*"MEMO: the walk-in stays CLOSED after 2AM."*) |

Rules: every line ≤ 70 chars (phone widths), palette/UI untouched, `Flavor.line_for(kind, id)` + `Flavor.random(kind)` with deterministic fallback "" (missing id = show nothing, never crash). Boss lines keyed by `boss_id()` — probe asserts full coverage of `Bosses._LIST`.

**Plan-time verification:** where the boss bar/SHIFT CHANGE toast text is set (Hud.gd); pay-stub footer insertion point (GameOver stub vbox); PROMOTED popup shape; daily popup label; commendation description source (Commendations.gd).

## Pack A — EMPLOYEE BENEFITS (v0.1.62)

**The missing permanent progression.** Larry's picks: scrap-funded flat tracks + a revive track (auto-disabled in HARDCORE).

**New currency: SCRAP.** Discovery: today "scrap" is only the deconstruct-for-coins payout (`Inventory.deconstruct` → coins from `Rarity.TIERS[].scrap` range) — no stored currency exists. Design: deconstruct keeps paying coins exactly as today AND additionally banks `max(1, coin_payout / 10)` scrap (new save key `scrap`, int). Additive — no existing income nerfed. Scrap displayed on the BENEFITS page header (and the inventory scrap-confirm popup gains a "+N SCRAP" line).

**Tracks** (pure `scripts/logic/Benefits.gd`: costs, caps, effect values; save key `benefits` = {track: level}):

| Track | / level | Cap | Notes |
|---|---|---|---|
| INSURANCE (Max HP) | +4 | 5 | joins the spawn baseline via the `grant_base_max_health` path — exempt from HARDCORE's heal-block like Ryan's baseline |
| COMFY SHOES (Move Speed) | +2% | 5 | |
| NIGHT SCHOOL (XP Gain) | +3% | 5 | stacks multiplicatively with the xp-gain level-up card |
| SIGNING BONUS (Starting Cash) | +50 run-coins | 5 | seeds the run's coin counter, pays out on the stub like any coins |
| SECOND OPINION (Card Reroll) | +1 reroll charge | 3 | adds a REROLL button on the level-up card screen (small UI: one button, existing panel) — reroll redraws the offer once per charge |
| STRETCH BREAKS (Dash CD) | −4% | 5 | |
| REGISTER SKIM (Coin Gain) | +2% | 5 | via `RunStats.coin_mult` (exists since v0.1.40) |
| PACK RAT (Salvage Bonus) | +10% scrap from deconstructs | 5 | self-feeding, deliberately |
| UNION REP (Revive) | 1 auto-revive/run at 50% HP + 2s invuln | 1 | **no-op in HARDCORE** (one-life identity); fires before Second Wind card if both present |

Costs per level: 25 / 60 / 140 / 320 / 700 scrap (UNION REP flat 1500). No respec (permanent). Effects applied once at run start via existing chokepoints; a `Benefits.effect(track)` pure getter is the single read point.

**UI:** new hub button **BENEFITS** between STORE and RECORDS (`_make_button` row, MainMenu). Page = title + scrap balance + 9 track rows (name, flavor line, level pips, cost button) in the existing PixelTheme list style; drag-scroll like the store.

**Plan-time verification:** `Inventory.deconstruct` payout site; `grant_base_max_health` signature; `RunStats.coin_mult` application points (both payout paths); xp-gain chokepoint from the v0.1.40 card; level-up screen layout for the REROLL button; HARDCORE flag read (`RunConfig`); Second Wind exclusion interplay; save DEFAULTS idiom for new keys.

## Pack E — THE BASEMENT (v0.1.63)

**Risk/reward mid-run detour.** Larry's pick: chance door ~every 4 waves, max 2/run; shift clock keeps ticking inside (basement time is stolen time).

- **Door:** from wave 3 on, each wave start rolls 25% (via `RunConfig.rand_float()` so Daily Shift stays seed-deterministic) to place a CELLAR DOOR prop ~500-900px from the player (forecourt keep-out respected). Max 2 doors/run, ≤1 alive at once, despawns after 45s unentered. Modes: endless, overtime, horde, daily. NOT boss_rush. Door visual: code-drawn C2 hatch + C4 handle + pulsing ring (grab/interact conventions don't apply — it's floor geometry).
- **Descend:** stand in the door's ring 1.2s (mobile-friendly, no new input; progress arc drawn) → screen fade → player teleported to the BASEMENT sub-arena: a walled ring (indestructible rubble-style cover ring, radius ~800) at a far world offset (+24000, +24000), same scene. Surface wave spawner suspended; surface enemies get distance-culled by the existing cull rules or simply never reach (verification item).
- **Inside:** 60s countdown banner (BASEMENT — hold out). Dedicated spawn table: dense trash + guaranteed 2-3 elites (elites roll here in ALL allowed modes — basement is elite territory; deliberate exception like the Karen summon). No dawn/events/extraction inside. Death = normal run end.
- **Reward + exit:** survive 60s → a crate drops (id-weighted table, rarity floor scales `2 + wave/5` capped at apex) + auto-ascend after pickup window (8s) → fade back to the surface spot, wave spawner resumes. The pay-stub gains a "BASEMENTS CLEARED" line when > 0; lifetime counter `basements_cleared` (future commendation hook, not this pack).
- Config: `BASEMENT_*` consts (chance, cap, duration, radius, offset, spawn density mult, elite count, crate floor formula, despawn).

**Plan-time verification:** wave-start hook for the roll (Spawner/DifficultyManager); how Extraction/events suspend spawning (reuse that idiom); enemy cull rules at distance; HUD banner idiom (SHIFT CHANGE toast); teleport + camera behavior; ObstacleField interaction at the offset; Daily Shift determinism contract (`RunConfig.rand_float` consumers).

## Pack C — COWORKERS (v0.1.64)

**Companions with the game's own RNG DNA.** Larry's pick: STAFF FILE crate (800c), gun crates untouched, one equipped at a time.

- **Instance:** `{uid, type, rarity, trait}` — rarity reuses the 9-tier ladder (weights as generic crates, scrap values ÷2); one trait slot rolls at purple+ from a coworker trait pool (~8: +damage, +attack rate, +radius, +duration, on-hit slow, on-hit pin chance, coin magnet aura, xp magnet aura).
- **Types (v1, 3):**
  - **STORE CAT** — every 4s pounce-dashes the nearest enemy in 500px: damage + 0.45s pin (reuses `apply_pin`). Rarity scales damage + pounce rate.
  - **DELIVERY DRONE** — orbits the player, auto-fires a weak projectile at the nearest enemy (pistol-class dps, own simple bullet — no talent path, no crit). Rarity scales dps + fire rate.
  - **FLOOR MANNEQUIN** — placed on a 12s cooldown where the player stands; enemies within 400px target IT for 4s (taunt), ~150 HP then shatters. Rarity scales HP + taunt radius. **This is the pack's one new enemy-side mechanic** (a taunt target override in the enemy targeting path) — flagged highest-risk, gets the deepest verification.
- **Acquisition/UI:** STAFF FILE crate row in the store (800c, own icon via home generator — clipboard+paw motif); pulls open on the existing reel; coworkers live in a new STAFF section of the inventory grid (own tile look: type glyph + rarity frame); tap → detail popup with EQUIP / SCRAP (scrap pays coins+scrap like weapons). Equipped coworker uid in save (`equipped_coworker`); spawns with the player each run as a Companion node.
- **Sprites:** 32px palette sprites via home generator (cat/drone/mannequin) + crate icon; `_draw` fallback not needed (sprites ship in-pack).
- Config: `COWORKER_*` consts for every number above.

**Plan-time verification:** enemy targeting path for the taunt override (Enemy `_desired_velocity` / target selection — bosses EXCLUDED from taunt, has_method guard style); inventory grid section pattern (crates section precedent); crate reel's item-type assumptions (it renders weapons — needs a coworker tile branch like the {sb,rarity} reel entries); store row + TryBuy wiring; save list idiom (`Inventory` vs new `Staff` store); pin reuse on pounce.

## Out of scope (all packs)

Weapon evolutions / transfer stores / visitors (benched), coworker fusion or talents-on-coworkers, benefits respec, prestige/franchise loop, weekly seed, share cards, new WAVs (reuse existing SFX), any rarity/weight rebalance.

## Testing (every pack)

Per-task probes (boot-scene runner — `_probe.tscn`, NOT `--script`) + the MANDATORY dual gate (editor-quit AND Main.tscn boot, both grep-0) per task. Pack-level fable whole-branch review before each ship. Phone F5 checklist written into each pack's final task.

# Power Curve (v0.1.74) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-base the in-run power curve: ~30 level-ups per shift, RNG rarity-tiered level-up cards with no stack caps, honest card/talent fire rate, de-degenerated procs, and 45–60 s on-curve boss fights — all tuned against a headless sim probe.

**Architecture:** A new pure `CardRolls.gd` (tier + value roll, autoload-free, seedable) sits between the existing card catalog (`Upgrades.gd`) and `UpgradeApply.apply`, which now takes the rolled card dict instead of an id. `XpCurve` goes geometric. Gun gets a second, honest fire-rate hook for cards (the legacy hook stays for affixes + character perks), a remainder-carrying fire timer, and per-barrel damage shares. `TalentEngine.process_hit` gains a per-second gate for cone guns, a freeze-consuming Shatter, and boss execute immunity. `DifficultyCurve.boss_stats` drops its second compounding; `Spawner` caps boss spawn-suppression at 75 s. A sim probe drives the final constants.

**Tech Stack:** Godot 4.6.3 GDScript. Headless probes via WSL interop.

**Spec:** `docs/superpowers/specs/2026-09-19-power-curve-design.md` (decisions D1–D6 are Larry-locked — do not relitigate). Background numbers: `docs/superpowers/analysis/2026-09-19/`.

## Global Constraints

- **Runner:** `GODOT="/mnt/c/Tools/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe"`, run from the repo root `/mnt/c/Users/thela/Documents/mobile-game/` (quote it). **Always redirect output to a file, then grep the file** (`timeout 240 "$GODOT" --headless --path . <scene> > out.txt 2>&1`) — piping a Windows exe through grep under `timeout` hangs. First run after adding a `class_name` needs an editor cache pass first: `timeout 300 "$GODOT" --headless --path . --editor --quit > ed.txt 2>&1`.
- **Probes = boot-scene pattern, never `--script`** (the `--script` runner poisons compilation of autoload-referencing scripts). A probe is `.superpowers/probe_<name>.gd` (`extends Node`, `check(name, ok)` helper printing `PASS  `/`FAIL  `, ends with `print("PROBE DONE fails=%d")` + `get_tree().quit(1 if fails > 0 else 0)`) plus a 5-line `.tscn` that attaches it — copy `.superpowers/probe_overtime_farm.gd/.tscn` as the template. `.superpowers/` is untracked; do not commit probes.
- **MANDATORY DUAL GATE per task** (paste the numbers in your report): editor gate `--editor --quit` → `grep -ciE "SCRIPT ERROR|PARSE ERROR" ed.txt` must be **≤ 19** (the 19 are known XpGem preload "Parse Error: Busy" lines — parity, not zero); boot gate `timeout 25 "$GODOT" --headless --path . res://scenes/Main.tscn > boot.txt 2>&1` → `grep -cE "SCRIPT ERROR" boot.txt` must be **0**; same for `res://scenes/MainMenu.tscn`.
- **Regression probes stay green:** `.superpowers/probe_hygiene.tscn` (28/28) and `.superpowers/probe_overtime_farm.tscn` (16/16).
- **RED before GREEN:** run each new probe before implementing and paste the failing output, then the passing output.
- Every tunable number is a `GameConfig` const with a `#` comment. Files use tabs. Some files are CRLF — preserve each file's existing line endings.
- Spec constants are **starters**; only Task 8 retunes them. Tasks 1–7 use the starter values verbatim.
- Card tier colors are loot-rarity colors and are exempt from the strict 4-color palette; everything else in UI stays PixelTheme.
- Work on `master` (repo convention); one commit per task with the message given; **no push until Task 9**. End every commit message with:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  ```
- Out of scope (specs 2 and 3): i-frames, enemy speed/unlock timing, boss damage, lifesteal/regen values, coins, ranks, crates, weapon base stats, affix values, rarity odds.

## File map

| file | change |
|---|---|
| `scripts/logic/CardRolls.gd` | **new** — tier roll, value roll, rolled-card dict, desc/band text |
| `scripts/logic/GameConfig.gd` | card tier tables, 4 formerly-hardcoded card bases, XP consts, boss consts |
| `scripts/logic/UpgradeApply.gd` | `apply(player, card: Dictionary)` — applies rolled values |
| `scripts/logic/Upgrades.gd` | catalog descs become fallbacks; nothing else |
| `scripts/logic/Weapons.gd` | drop `"incendiary"` from the Tesla pool |
| `scripts/Gun.gd` | `upgrade_fire_rate_card`, `upgrade_add_barrel`, `bonus_barrels`, crit chance-only, frenzy honest, fire-timer remainder, flame burn additive |
| `scripts/LevelUpUI.gd`, `scripts/ui/PixelTheme.gd` | tier border/label/number/band, Legendary flash + sting |
| `scripts/logic/XpCurve.gd`, `scripts/BossBase.gd` | geometric level cost; wave-scaled boss gems |
| `scripts/loot/TalentEngine.gd`, `scripts/Enemy.gd` | cone per-second procs, Shatter consumes freeze, boss execute immunity |
| `scripts/logic/DifficultyCurve.gd`, `scripts/Spawner.gd` | single compounding; 75 s suppression cap |

---

### Task 1: `CardRolls` — pure tier + value roll

**Files:** Create `scripts/logic/CardRolls.gd`. Modify `scripts/logic/GameConfig.gd` (add the block below next to the existing `UPGRADE_*` consts at ~line 26). Probe `.superpowers/probe_card_rolls.gd/.tscn`.

**Interfaces — Produces (later tasks rely on these exact names):**
- GameConfig: `CARD_TIER_NAMES`, `CARD_TIER_WEIGHTS`, `CARD_TIER_BANDS`, `CARD_TIER_COLORS`, `CARD_INT_AMOUNT`, `CARD_INT_EPIC_DAMAGE_PCT`, `CARD_BARREL_SHARE`, `CARD_CRIT_CHANCE`, `CARD_SECOND_WIND_TIER`, `UPGRADE_MOVE_SPEED_PCT`, `UPGRADE_MAX_HEALTH`, `UPGRADE_REGEN`, `UPGRADE_PICKUP_PCT`.
- `CardRolls.roll_tier(rng: RandomNumberGenerator) -> int` (0..3)
- `CardRolls.roll(card: Dictionary, rng: RandomNumberGenerator) -> Dictionary` — returns a COPY of the catalog card `{id,title,desc}` plus `tier: int`, `value: float`, `amount: int` (integer/barrel cards; else 0), `desc: String` (rolled text), `band: String`.
- `CardRolls.spec(id: String) -> Dictionary` — `{kind, base, fmt}`; kinds: `"pct"`, `"flat"`, `"int"`, `"barrel"`, `"crit"`, `"fixed"`.

- [ ] **Step 1: GameConfig block**

```gdscript
# --- Level-up card rolls (Power Curve v0.1.74): every offered card rolls a tier, then a value ---
const CARD_TIER_NAMES := ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const CARD_TIER_WEIGHTS := [60, 27, 10, 3]            # per offered card, independent; no luck/pity
const CARD_TIER_BANDS := [[0.5, 0.8], [0.8, 1.2], [1.3, 1.8], [2.2, 3.0]]   # x the card's base value ("Rare = the old flat value")
const CARD_TIER_COLORS := [Color("d6d6d6"), Color("2f7bff"), Color("a64bff"), Color("ff7a18")]  # Salvaged/Lethal/Savage/Merciless loot colors
const CARD_INT_AMOUNT := [1, 1, 1, 2]                 # Armor Piercing / Ricochet / Extra Barrel count per tier
const CARD_INT_EPIC_DAMAGE_PCT := 0.10                # Epic Armor Piercing / Ricochet also grant +10% damage
const CARD_BARREL_SHARE := [[0.40, 0.55], [0.55, 0.70], [0.70, 0.90], [1.0, 1.0]]  # Extra Barrel: damage share of each ADDED barrel
const CARD_CRIT_CHANCE := [[3.0, 4.0], [4.0, 6.0], [7.0, 9.0], [11.0, 15.0]]       # Kill Shot: crit-chance points (chance only, no mult growth)
const CARD_SECOND_WIND_TIER := 2                      # Second Wind never rolls; always shown as EPIC
const UPGRADE_MOVE_SPEED_PCT := 0.10   # "Swift Feet" base (was hardcoded in UpgradeApply)
const UPGRADE_MAX_HEALTH := 20.0       # "Tough Hide" base (was hardcoded)
const UPGRADE_REGEN := 1.0             # "Regeneration" base HP/sec (was hardcoded)
const UPGRADE_PICKUP_PCT := 0.25       # "Magnet" base (was hardcoded)
```

- [ ] **Step 2: Write the probe (RED).** `_ready()` checks, with `var rng := RandomNumberGenerator.new(); rng.seed = 12345`:
  - 10,000 × `CardRolls.roll_tier(rng)` → frequencies within ±2 points of 60/27/10/3.
  - For `damage` (base 0.20): 2,000 rolls → every `value` inside `[base×lo, base×hi]` of its tier's band (allow ±0.005 for whole-percent rounding); `desc` matches `"+%d%% Damage"` with `%d == roundi(value*100)`; `band` non-empty.
  - `pierce`: `amount == CARD_INT_AMOUNT[tier]`; on tier 2 `value == CARD_INT_EPIC_DAMAGE_PCT`, else `value == 0.0`.
  - `projectile`: `amount == CARD_INT_AMOUNT[tier]`, `value` inside `CARD_BARREL_SHARE[tier]`.
  - `crit`: `value` inside `CARD_CRIT_CHANCE[tier]`, whole number.
  - `second_wind`: `tier == CARD_SECOND_WIND_TIER` on every roll, `value == 0.0`.
  - `roll()` does not mutate the input dict (`card.has("tier") == false` afterwards).
  - Every id in `Upgrades.player_cards()` and every id returned by `Upgrades.gun_card` for the 11 gun-card ids has a non-empty `CardRolls.spec(id)`.
  Run it; expected: parse failure / FAILs because `CardRolls` doesn't exist. Paste output.

- [ ] **Step 3: Implement `scripts/logic/CardRolls.gd`**

```gdscript
class_name CardRolls
## Pure level-up card roll logic (Power Curve, v0.1.74). Every OFFERED card rolls a rarity tier
## (GameConfig.CARD_TIER_WEIGHTS) and then a value inside that tier's band. Autoload-free and
## seedable (takes the RNG) — same discipline as Upgrades.gd — so a headless probe can verify it.

## id -> {kind, base, fmt}. kind: "pct" (fraction, shown as whole %), "flat" (number shown as is),
## "int" (whole +N, Epic adds damage), "barrel" (+N barrels at a rolled damage share),
## "crit" (crit-chance points from its own table), "fixed" (never rolls).
static func spec(id: String) -> Dictionary:
	match id:
		"move_speed":    return {"kind": "pct", "base": GameConfig.UPGRADE_MOVE_SPEED_PCT, "fmt": "+%d%% Move Speed"}
		"max_health":    return {"kind": "flat", "base": GameConfig.UPGRADE_MAX_HEALTH, "fmt": "+%s Max Health", "step": 1.0}
		"regen":         return {"kind": "flat", "base": GameConfig.UPGRADE_REGEN, "fmt": "+%s Health / sec", "step": 0.1}
		"pickup":        return {"kind": "pct", "base": GameConfig.UPGRADE_PICKUP_PCT, "fmt": "+%d%% Pickup Radius"}
		"armor":         return {"kind": "pct", "base": GameConfig.UPGRADE_ARMOR_PCT, "fmt": "-%d%% Contact Damage Taken"}
		"dodge":         return {"kind": "pct", "base": GameConfig.UPGRADE_DODGE_PCT, "fmt": "+%d%% Dodge Chance"}
		"dash_cooldown": return {"kind": "pct", "base": GameConfig.UPGRADE_DASH_CD_PCT, "fmt": "-%d%% Dash Cooldown"}
		"xp_gain":       return {"kind": "pct", "base": GameConfig.UPGRADE_XP_PCT, "fmt": "+%d%% XP Gain"}
		"coin_gain":     return {"kind": "pct", "base": GameConfig.UPGRADE_COIN_PCT, "fmt": "+%d%% Coin Payout"}
		"thorns":        return {"kind": "flat", "base": GameConfig.UPGRADE_THORNS_MULT, "fmt": "Biters Take %sx Their Own Damage", "step": 0.1}
		"crit":          return {"kind": "crit", "base": 0.0, "fmt": "+%d%% Crit Chance (2x Damage)"}
		"second_wind":   return {"kind": "fixed", "base": 0.0, "fmt": ""}
		"damage":        return {"kind": "pct", "base": GameConfig.UPGRADE_DAMAGE_PCT, "fmt": "+%d%% Damage"}
		"fire_rate":     return {"kind": "pct", "base": GameConfig.UPGRADE_FIRE_RATE_PCT, "fmt": "+%d%% Fire Rate"}
		"bullet_speed":  return {"kind": "pct", "base": GameConfig.UPGRADE_BULLET_SPEED_PCT, "fmt": "+%d%% Bullet Speed"}
		"range":         return {"kind": "pct", "base": GameConfig.UPGRADE_RANGE_PCT, "fmt": "+%d%% Range"}
		"choke":         return {"kind": "pct", "base": GameConfig.UPGRADE_CHOKE_PCT, "fmt": "-%d%% Spread"}
		"reload":        return {"kind": "pct", "base": GameConfig.UPGRADE_RELOAD_PCT, "fmt": "-%d%% Reload Time"}
		"mag":           return {"kind": "pct", "base": GameConfig.UPGRADE_MAG_PCT, "fmt": "+%d%% Magazine"}
		"incendiary":    return {"kind": "flat", "base": GameConfig.UPGRADE_BURN_DPS, "fmt": "Hits burn for +%s dmg/sec", "step": 0.1}
		"pierce":        return {"kind": "int", "base": 0.0, "fmt": "Bullets pierce +%d enemy"}
		"ricochet":      return {"kind": "int", "base": 0.0, "fmt": "Bullets bounce to +%d enemy"}
		"projectile":    return {"kind": "barrel", "base": 0.0, "fmt": "+%d Projectile at %d%% damage"}
	return {}

static func roll_tier(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in GameConfig.CARD_TIER_WEIGHTS:
		total += int(w)
	var pick := rng.randi_range(1, total)
	for i in GameConfig.CARD_TIER_WEIGHTS.size():
		pick -= int(GameConfig.CARD_TIER_WEIGHTS[i])
		if pick <= 0:
			return i
	return 0

## Returns a rolled COPY of a catalog card: + tier, value, amount, desc, band. The displayed number
## IS the applied number (values are rounded to their display step before being stored).
static func roll(card: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := card.duplicate()
	var s := spec(String(card["id"]))
	var kind := String(s.get("kind", "fixed"))
	var tier := GameConfig.CARD_SECOND_WIND_TIER if kind == "fixed" else roll_tier(rng)
	out["tier"] = tier
	out["value"] = 0.0
	out["amount"] = 0
	out["band"] = ""
	match kind:
		"pct":
			var band: Array = GameConfig.CARD_TIER_BANDS[tier]
			var base := float(s["base"])
			var v := roundf(base * rng.randf_range(float(band[0]), float(band[1])) * 100.0) / 100.0
			out["value"] = maxf(v, 0.01)
			out["desc"] = String(s["fmt"]) % roundi(out["value"] * 100.0)
			out["band"] = "band %d-%d%%" % [roundi(base * float(band[0]) * 100.0), roundi(base * float(band[1]) * 100.0)]
		"flat":
			var band: Array = GameConfig.CARD_TIER_BANDS[tier]
			var base := float(s["base"])
			var step := float(s.get("step", 1.0))
			var v := roundf(base * rng.randf_range(float(band[0]), float(band[1])) / step) * step
			out["value"] = maxf(v, step)
			out["desc"] = String(s["fmt"]) % _num(out["value"], step)
			out["band"] = "band %s-%s" % [_num(base * float(band[0]), step), _num(base * float(band[1]), step)]
		"int":
			out["amount"] = int(GameConfig.CARD_INT_AMOUNT[tier])
			out["desc"] = String(s["fmt"]) % out["amount"]
			if tier == 2:
				out["value"] = GameConfig.CARD_INT_EPIC_DAMAGE_PCT
				out["desc"] += " and +%d%% Damage" % roundi(GameConfig.CARD_INT_EPIC_DAMAGE_PCT * 100.0)
		"barrel":
			var share: Array = GameConfig.CARD_BARREL_SHARE[tier]
			out["amount"] = int(GameConfig.CARD_INT_AMOUNT[tier])
			out["value"] = roundf(rng.randf_range(float(share[0]), float(share[1])) * 100.0) / 100.0
			out["desc"] = String(s["fmt"]) % [out["amount"], roundi(out["value"] * 100.0)]
			out["band"] = "band %d-%d%%" % [roundi(float(share[0]) * 100.0), roundi(float(share[1]) * 100.0)]
		"crit":
			var cb: Array = GameConfig.CARD_CRIT_CHANCE[tier]
			out["value"] = float(rng.randi_range(int(cb[0]), int(cb[1])))
			out["desc"] = String(s["fmt"]) % int(out["value"])
			out["band"] = "band %d-%d%%" % [int(cb[0]), int(cb[1])]
	return out

static func _num(v: float, step: float) -> String:
	return str(int(roundf(v))) if step >= 1.0 else "%.1f" % v
```

- [ ] **Step 4:** Editor cache pass, run probe → all PASS. Dual gate. Regression probes.
- [ ] **Step 5: Commit** `feat(cards): CardRolls — rarity-tiered RNG value rolls for level-up cards`

---

### Task 2: Apply rolled cards (UpgradeApply + Gun hooks)

**Files:** Modify `scripts/logic/UpgradeApply.gd` (whole `apply`), `scripts/Gun.gd` (`upgrade_fire_rate` area ~line 472, `upgrade_add_projectile` ~481, `upgrade_crit` ~515, `_fire_projectile` ~366, `_spawn_bullet` ~429, `_fire_cone` burn line ~640), `scripts/logic/Weapons.gd` (Tesla `"upgrades"` list, ~line 74: remove `"incendiary"`), `scripts/LevelUpUI.gd:168` (call site only: `UpgradeApply.apply(_player, card)`), `scripts/logic/GameConfig.gd` (delete `UPGRADE_CRIT_MULT_BONUS`, `UPGRADE_CRIT_CHANCE_PCT`; fix the Kill Shot catalog desc in `Upgrades.gd:29` to not reference the deleted const — use the literal fallback `"+Crit Chance (2x Damage)"`). Probe `.superpowers/probe_card_apply`.

**Interfaces — Consumes:** Task 1's rolled card dict. **Produces:** `UpgradeApply.apply(player: Player, card: Dictionary) -> void`; `Gun.upgrade_fire_rate_card(pct: float)`; `Gun.upgrade_add_barrel(n: int, share: float)`; `Gun.bonus_barrels: Array[float]`; `Gun.upgrade_crit(chance_pct: float)` (one arg).

Key facts the implementer must not break:
- `Gun.upgrade_fire_rate(pct)` (`fire_interval *= (1.0 - pct)`) is **also called by `apply_loot` for weapon affixes (`Gun.gd:150`) and by character perks (`Characters.gd:111-130`)**. Decision D6: those keep the old math. **Do not change `upgrade_fire_rate`.** Cards get their own hook.
- `upgrade_add_projectile(n)` stays for affix multishot (`Gun.gd:156`). Cards use `upgrade_add_barrel`.

- [ ] **Step 1: Probe (RED).** Instance `res://scenes/Player.tscn` under the probe node (it builds its own Gun; if Player needs the Main scene, instead `var gun := Gun.new()` on a bare Node and test Gun hooks directly, and test player hooks on the Player instance — read `Player._ready` first and pick whichever boots clean). Checks:
  - `upgrade_fire_rate_card(0.20)` → `fire_interval` == old/1.20 (±1e-6). `upgrade_fire_rate(0.20)` → old×0.80 (legacy unchanged).
  - `upgrade_add_barrel(1, 0.5)` on a 1-projectile gun → `bonus_barrels == [0.5]`, `projectile_count` unchanged, `spread > 0`; on a `fire_mode = "lightning"` gun → `jump_count` +1 and `bonus_barrels` empty.
  - `upgrade_crit(5.0)` → `talent_payload["crit_chance"]` +5, `talent_payload.get("crit_mult", 1.0)` unchanged.
  - `UpgradeApply.apply(player, {"id":"damage","tier":1,"value":0.17,"amount":0})` → gun damage ×1.17. `{"id":"pierce","tier":2,"value":0.10,"amount":1}` → `pierce_count` +1 and damage ×1.10. `{"id":"max_health","value":26.0}` → max HP +26.
  - Source checks: `UpgradeApply.gd` contains no numeric literal `0.10`/`20.0`/`0.25`; `GameConfig.gd` no longer contains `UPGRADE_CRIT_MULT_BONUS`; Tesla's upgrades list has no `"incendiary"`.
- [ ] **Step 2: Gun.gd**

```gdscript
# next to `var projectile_count := 1`
var bonus_barrels: Array[float] = []   # Extra Barrel card: damage share of each card-added barrel (Power Curve)

## Level-up card + talent fire rate (Power Curve D6): HONEST — "+20%" means 20% more shots/sec.
## upgrade_fire_rate() below keeps the legacy interval-shrink math for weapon affixes and
## character perks (apply_loot / Characters.apply_weapon), which Larry kept as-is.
func upgrade_fire_rate_card(pct: float) -> void:
	fire_interval /= (1.0 + pct)

## Extra Barrel card: +n barrels that each fire at `share` of the gun's damage. Affix multishot
## still uses upgrade_add_projectile (full-damage pellets).
func upgrade_add_barrel(n: int, share: float) -> void:
	if fire_mode == "lightning":
		jump_count += n
		return
	for i in n:
		bonus_barrels.append(share)
	if spread <= 0.0:
		spread = 0.20

func upgrade_crit(chance_pct: float) -> void:
	talent_payload["crit_chance"] = float(talent_payload.get("crit_chance", 0.0)) + chance_pct
```

`_fire_projectile`: `var base_count: int = projectile_count + (_surge_shots if _surge_time > 0.0 else 0)`; `var count := base_count + bonus_barrels.size()`; the `count <= 1` branch is unchanged; in the fan loop pass the share: `var share: float = 1.0 if i < base_count else bonus_barrels[i - base_count]` → `_spawn_bullet(Vector2.from_angle(base_angle + offset), share)`.
`_spawn_bullet(dir: Vector2, dmg_mult: float = 1.0)`: `bullet.damage = damage * dmg_mult`.
`_fire_cone` burn: `var bdps := GameConfig.FLAME_BURN_DPS + burn_dps` (was `maxf(...)`, which ate the first 3 Incendiary picks). Update the stale Kill Shot doc comment above `upgrade_crit`.

- [ ] **Step 3: UpgradeApply.gd** — full replacement of `apply`:

```gdscript
## Applies a ROLLED upgrade card (CardRolls.roll output: id + value/amount) to the player, its gun,
## or (coin_gain) RunStats.
static func apply(player: Player, card: Dictionary) -> void:
	var v := float(card.get("value", 0.0))
	var n := int(card.get("amount", 0))
	match String(card["id"]):
		"move_speed":    player.upgrade_move_speed(v)
		"max_health":    player.upgrade_max_health(v)
		"regen":         player.upgrade_regen(v)
		"pickup":        player.upgrade_pickup_radius(v)
		"armor":         player.upgrade_armor(v)
		"dodge":         player.upgrade_dodge(v)
		"dash_cooldown": player.upgrade_dash_cooldown(v)
		"xp_gain":       player.upgrade_xp_gain(v)
		"coin_gain":     RunStats.add_coin_mult(v)
		"crit":          player.gun.upgrade_crit(v)
		"thorns":        player.upgrade_thorns(v)
		"second_wind":   player.upgrade_second_wind()
		"damage":        player.gun.upgrade_damage(v)
		"fire_rate":     player.gun.upgrade_fire_rate_card(v)
		"bullet_speed":  player.gun.upgrade_bullet_speed(v)
		"range":         player.gun.upgrade_range(v)
		"projectile":    player.gun.upgrade_add_barrel(n, v)
		"choke":         player.gun.upgrade_reduce_spread(v)
		"pierce":
			player.gun.upgrade_pierce(n)
			if v > 0.0: player.gun.upgrade_damage(v)
		"ricochet":
			player.gun.upgrade_ricochet(n)
			if v > 0.0: player.gun.upgrade_damage(v)
		"incendiary":    player.gun.upgrade_incendiary(v, GameConfig.UPGRADE_BURN_DURATION)
		"reload":        player.gun.upgrade_reload_speed(v)
		"mag":           player.gun.upgrade_mag_size(v)
```

Grep for any other `UpgradeApply.apply(` / `upgrade_crit(` callers (`grep -rn "UpgradeApply.apply\|upgrade_crit(" scripts`) and update them; none expected beyond `LevelUpUI.gd:168`. In `LevelUpUI._pick_three`, temporarily roll so the game stays playable this commit: `var rng := RandomNumberGenerator.new(); rng.randomize()` then `return pool.slice(0, 3).map(func(c): return CardRolls.roll(c, rng))` (Task 3 owns the presentation; `desc` already shows the rolled text).
- [ ] **Step 4:** Probe GREEN, dual gate, regression probes. **Commit** `feat(cards): apply rolled values — honest card fire rate, barrel damage share, chance-only Kill Shot`

---

### Task 3: LevelUpUI — tier presentation

**Files:** Modify `scripts/LevelUpUI.gd`, `scripts/ui/PixelTheme.gd` (add `style_tier_button`). Probe `.superpowers/probe_card_ui`.

**Interfaces — Consumes:** rolled card fields `tier`, `desc`, `band`; `GameConfig.CARD_TIER_NAMES/COLORS`.

- [ ] **Step 1: Probe (RED).** Instance the LevelUpUI script on a CanvasLayer under the probe (read its `_ready`: it tolerates a null player). Inject `_current_cards` with three hand-built rolled cards (tiers 0, 2, 3) and call the new `_paint_cards()`; assert: `_tier_labels[i].text == GameConfig.CARD_TIER_NAMES[tier]`; the button's `"normal"` stylebox `border_color == GameConfig.CARD_TIER_COLORS[tier]`; `_descs[i].text == card.desc`; `_bands[i].text == card.band`; a `fixed` card (empty band) hides its band label.
- [ ] **Step 2: PixelTheme**

```gdscript
## Level-up card tinted by its rolled rarity tier (Power Curve): style_button's frame with the
## tier color as a 4px border in every state. Loot-rarity colors are palette-exempt.
static func style_tier_button(b: Button, tier_color: Color, min_size: Vector2, font_size: int = 39) -> void:
	style_button(b, min_size, font_size)
	b.add_theme_stylebox_override("normal", _box(BTN_BG, tier_color, 4))
	b.add_theme_stylebox_override("hover", _box(BTN_HOVER, tier_color, 4))
	b.add_theme_stylebox_override("pressed", _box(tier_color, tier_color, 4))
```

- [ ] **Step 3: LevelUpUI.** Add `var _tier_labels: Array[Label] = []`, `var _bands: Array[Label] = []`, `var _rng := RandomNumberGenerator.new()` (`_rng.randomize()` in `_ready`). In the card-build loop add, above `name_lbl`, a tier label (`PixelTheme.style_label(tier_lbl, 20, PixelTheme.TEXT_DIM)`, centered, `mouse_filter IGNORE`) and, below `desc`, a band label (`PixelTheme.readable_label(band_lbl, 18, PixelTheme.TEXT_DIM)`); bump the desc font to 30 (the rolled number is the headline) and the card button height from 188 to 214 so four rows fit (keep `_reroll_btn` at exactly half: 107). Split `_refresh_cards` into roll + `_paint_cards()`:

```gdscript
func _refresh_cards() -> void:
	_current_cards = _pick_three(_current_level)
	_paint_cards()
	_update_reroll_button()

func _paint_cards() -> void:
	var best_tier := 0
	for i in 3:
		var c: Dictionary = _current_cards[i]
		var tier := int(c.get("tier", 0))
		best_tier = maxi(best_tier, tier)
		var col: Color = GameConfig.CARD_TIER_COLORS[tier]
		PixelTheme.style_tier_button(_buttons[i], col, Vector2(760, 214))
		_tier_labels[i].text = String(GameConfig.CARD_TIER_NAMES[tier])
		_tier_labels[i].add_theme_color_override("font_color", col)
		_card_titles[i].text = String(c["title"]).to_upper()
		_descs[i].text = String(c["desc"])
		_bands[i].text = String(c.get("band", ""))
		_bands[i].visible = _bands[i].text != ""
	if best_tier == 3:
		SoundManager.play("relic_choice")   # Legendary offer sting (existing SFX id)
		ScreenFlash.flash(get_tree(), GameConfig.CARD_TIER_COLORS[3])
```

Read `scripts/ScreenFlash.gd` first and use its real API (if it has no static `flash(tree, color)`, call whatever it exposes; if it only works unpaused, skip the flash and keep the sting — the tree is paused here). `_pick_three` uses `_rng` (replace Task 2's temporary local RNG). A reroll re-rolls tiers and values (it calls `_refresh_cards`) — intended.
- [ ] **Step 4:** Probe GREEN, dual gate, regression probes. Boot `Main.tscn` 25 s and confirm 0 script errors. **Commit** `feat(cards): tier-colored level-up cards — rolled number, band, Legendary sting`

---

### Task 4: Geometric XP curve + wave-scaled boss XP

**Files:** Modify `scripts/logic/XpCurve.gd`, `scripts/logic/GameConfig.gd` (`XP_BASE := 8`, new `XP_GROWTH := 1.17`, delete `XP_PER_LEVEL`; grep `XP_PER_LEVEL` repo-wide and fix every reference), `scripts/BossBase.gd:_reward` (~line 252). Probe `.superpowers/probe_xp_curve`.

- [ ] **Step 1: Probe (RED):** `XpCurve.xp_for_level(0) == 8`; `xp_for_level(10) == roundi(8 * pow(1.17, 10))` (= 38); strictly increasing for L in 0..60; cumulative cost to level 30 between 4,000 and 6,500; `GameConfig` source has no `XP_PER_LEVEL`. Boss gems: source check that `BossBase.gd` sets `gem.value` from the wave (string `DifficultyManager.enemy_stats()` present in `_reward`).
- [ ] **Step 2: XpCurve**

```gdscript
## XP required to advance FROM `level` to `level + 1`. Geometric (Power Curve v0.1.74): XP income
## grows ~20%/wave (gem value tracks enemy HP), so a linear cost gave level ~57 by extraction and a
## card every ~6s. XP_BASE x XP_GROWTH^level targets ~29 levels at 9:35 (5/12/18/25 at 1/3/5/8 min).
static func xp_for_level(level: int) -> int:
	return roundi(GameConfig.XP_BASE * pow(GameConfig.XP_GROWTH, level))
```

- [ ] **Step 3: BossBase._reward** — inside the gem loop, after `instantiate()`:

```gdscript
			# Power Curve: boss gems are worth what a wave-current shambler's gem is (same formula +
			# cap as Enemy's drop), so a 45-60s boss fight pays about what that much trash would —
			# 30 flat value-1 gems was ~3 shambler kills at wave 20.
			var trash_hp: float = float(DifficultyManager.enemy_stats()["max_health"])
			gem.value = clampi(roundi(trash_hp / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
```
(Verify the key name in `DifficultyCurve.enemy_stats` — it is `"max_health"` for bosses; use the same key the trash dict actually has.) Set `gem.value` BEFORE `add_child` if XpGem reads it in `_ready` (it does not today — value is read on collect — either order works).
- [ ] **Step 4:** Probe GREEN, dual gate, regression probes. **Commit** `feat(xp): geometric level cost (~30 levels/shift) + wave-scaled boss XP`

---

### Task 5: Honest frenzy + frame-rate-independent fire timer

**Files:** Modify `scripts/Gun.gd` (`_process` fire section ~lines 233–248), `scripts/logic/GameConfig.gd` (`ABILITY_JACKPOT_FRENZY`). Probe `.superpowers/probe_fire_timing`.

Context: the frenzy channel (`add_frenzy`, `_frenzy_mult`) is fed by talents (Bloodrush/Rampage `"frenzy"` procs, Graveyard Shift) **and** by Alstar's JACKPOT ability (`AbilityController.gd:274`). D6 makes talent rate bonuses honest. The ability is not a talent and must keep its real strength: old effect of 0.4 was ×1/(1−0.4) = ×1.667, so under the honest formula the const becomes **0.667**.

- [ ] **Step 1: Probe (RED).** Bare `Gun` with a stub that counts `_fire` calls is awkward — instead test the arithmetic through a small pure helper you add: `static func Gun.next_cooldown(carry: float, interval: float) -> float`. Checks: simulate 10 s at dt=1/60 and dt=1/120 with `interval = 0.07` using the same loop the gun uses (copy it into the probe: subtract dt, while cooldown ≤ 0 and shots_this_frame < 4: shoot, cooldown = next_cooldown(cooldown, interval)) → shot counts within 1% of each other and within 1% of `10/0.07`; with frenzy 0.70 the effective interval is `interval / 1.70`; source check: `Gun.gd` has no `(1.0 - _frenzy_mult)`; `GameConfig.ABILITY_JACKPOT_FRENZY` ≈ 0.667.
- [ ] **Step 2: Gun.gd fire section** — replace the tail of `_process`:

```gdscript
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if fire_mode == "projectile" and bullet_scene == null:
		return

	# Hold fire while moving (stop-to-shoot) or before the player has aimed. Clamp the carried
	# debt so a long hold doesn't bank a burst for the moment the player stops.
	if hold_fire or aim_direction == Vector2.ZERO:
		_cooldown = 0.0
		return

	# Frame-rate independent cadence (Power Curve): carry the overshoot into the next interval and
	# allow a bounded catch-up burst, so a 0.05-0.07s gun fires the same shots/sec at 60 and 120 fps
	# (resetting to the full interval each shot cost the LMG/Nailgun ~16% at 60 fps).
	var shots := 0
	while _cooldown <= 0.0 and shots < GameConfig.GUN_MAX_SHOTS_PER_FRAME:
		if not _fire(aim_direction):
			_cooldown = 0.0
			return                  # no shot happened (e.g. Tesla with no target) — don't waste ammo/cooldown
		shots += 1
		# Talent/ability frenzy is HONEST (D6): +70% = 1.7x shots/sec.
		var interval := (fire_interval / (1.0 + _frenzy_mult)) if _frenzy_time > 0.0 else fire_interval
		_cooldown = next_cooldown(_cooldown, interval)
		_ammo -= 1
		if _ammo <= 0:
			_cooldown = maxf(_cooldown, 0.0)   # never carry fire debt through a reload (would burst on the first frame after it)
			_start_reload()
			return
	if _cooldown < 0.0:
		_cooldown = 0.0                 # hit the per-frame cap: drop the remaining debt

static func next_cooldown(carry: float, interval: float) -> float:
	return carry + interval
```
Add `const GUN_MAX_SHOTS_PER_FRAME := 4` to GameConfig. Read the 40 lines above the fire section first — reload handling returns early before this block; keep that intact. Set `ABILITY_JACKPOT_FRENZY := 0.667` with a comment explaining the conversion.
- [ ] **Step 3:** Probe GREEN, dual gate, regression probes. **Commit** `fix(gun): honest frenzy fire rate + frame-rate-independent fire timer`

---

### Task 6: Procs — cone per-second, Shatter thaw, boss execute immunity

**Files:** Modify `scripts/loot/TalentEngine.gd` (`process_hit` ~220–290, `_roll`), `scripts/Gun.gd` (`_fire_cone` ctx dict ~661), `scripts/Enemy.gd` (public `consume_freeze()` next to `_thaw` ~303). Probe `.superpowers/probe_procs`.

- [ ] **Step 1: Probe (RED).** Use stub bodies (`extends Node`, add to the tree): an enemy stub with `apply_freeze/is_frozen/consume_freeze/health_fraction/take_damage` recording calls; a boss stub that is `add_to_group("boss")` with `health_fraction() -> 0.1` and a `take_damage` recorder. Checks:
  - Execute payload `{"procs":[{"kind":"execute","threshold":25.0}]}` on the boss stub at 10% HP → `take_damage` NOT called; on the enemy stub → called with 1,000,000.
  - Freeze payload with `"chance": 0.0` on an already-frozen enemy stub → shatter fires once **and** `consume_freeze` was called; a second `process_hit` immediately after (stub now reports `is_frozen() == false`) → no shatter, no freeze (chance 0).
  - Per-second gate: payload lifesteal `"chance": 100.0`, ctx `"proc_scale": 0.05` → over 2,000 calls (seeded `seed(7)`), heal count is 100 ± 40 (≈5%), not 2,000. Without `proc_scale` → 2,000.
- [ ] **Step 2: TalentEngine.** At the top of `process_hit`: `var scale: float = float(ctx.get("proc_scale", 1.0))`. Replace every `_roll(proc["chance"])` inside `process_hit` with `_roll(float(proc["chance"]) * scale)` **except on-kill procs** (`explode`, `ammo`, `bolt`, `pool` — they're gated by `killed`, a per-enemy event, not per tick). Execute arm becomes:

```gdscript
			"execute":
				# Bosses are execute-immune (Power Curve): Reaper deleted the last 25% of a boss fight.
				if alive and not body.is_in_group("boss") and body.has_method("health_fraction") and body.health_fraction() <= float(proc["threshold"]) / 100.0:
```
Freeze arm: after `CombatText.callout(hit_pos, "SHATTER", ...)` add `if body.has_method("consume_freeze"): body.consume_freeze()`; the `elif` re-freeze roll uses the scaled chance.
- [ ] **Step 3: Enemy.gd**

```gdscript
## Shatter consumes the freeze (Power Curve): the target thaws and must be re-frozen by a fresh
## chance roll — a frozen target used to shatter on EVERY later hit, forever.
func consume_freeze() -> void:
	_freeze_time = 0.0
	if _frozen:
		_thaw()
```
- [ ] **Step 4: Gun._fire_cone** — add to the ctx dict: `"proc_scale": fire_interval,` with the comment `# constant-stream gun (D4): a talent's listed chance is PER SECOND per target, so per-tick chance = chance x tick interval`. (Cards/frenzy shrinking `fire_interval` keeps procs/sec constant — intended.)
- [ ] **Step 5:** Probe GREEN, dual gate, regression probes. **Commit** `fix(talents): per-second procs on cone guns, Shatter consumes freeze, bosses execute-immune`

---

### Task 7: Bosses — single compounding, roster band, 75 s suppression cap

**Files:** Modify `scripts/logic/DifficultyCurve.gd:40-49`, `scripts/logic/GameConfig.gd` (delete `BOSS_LATE_HP_GROWTH`; add `BOSS_SUPPRESS_MAX_SECONDS := 75.0`; roster HP consts below), `scripts/Spawner.gd` (~36–46, 93–98). Probe `.superpowers/probe_bosses`.

Roster (wave-1 HP; `BOSS_BASE_HP` stays 1500 until Task 8 — mult = HP/1500, band 0.8–1.3, order preserved):

| const | old | new | mult |
|---|---|---|---|
| `MANAGER_HP` | 3000 | 1950 | 1.30 |
| `MASCOT_HP` | 2600 | 1850 | 1.23 |
| `TANKER_HP` | 2400 | 1800 | 1.20 |
| `BROOD_HP` | 2200 | 1700 | 1.13 |
| `FRYER_HP` | 2000 | 1650 | 1.10 |
| `HEAT_HP` | 1900 | 1600 | 1.07 |
| `SHOPPER_HP` | 1800 | 1550 | 1.03 |
| `KAREN_HP` | 1600 | 1500 | 1.00 |
| Brute (no const; `_hp_mult` 1.0) | 1500 | 1500 | 1.00 |
| `COURIER_HP` | 1400 | 1350 | 0.90 |
| `STOCKER_HP` | 1100 | 1200 | 0.80 |

Update each const's trailing comment (several cite old neighbors' numbers).

- [ ] **Step 1: Probe (RED):** `DifficultyCurve.boss_stats(20)["max_health"]` == `BOSS_BASE_HP * pow(ENEMY_HP_GROWTH, 19)` (±0.5); ratio `boss_stats(20)/boss_stats(10)` == `pow(1.12, 10)` (±1%) (today it is ×9.65); GameConfig source has no `BOSS_LATE_HP_GROWTH`; all 10 roster consts / `BOSS_BASE_HP` within [0.8, 1.3]; `MANAGER_HP` is the max and `STOCKER_HP` the min; Spawner: `Spawner.suppression_active(0.0, true)`, `(74.9, true)` true; `(75.0, true)` false; `(10.0, false)` false.
- [ ] **Step 2: DifficultyCurve.boss_stats** — delete the `if wave > GameConfig.ENEMY_LATE_WAVE:` block and its comment; update the doc comment: bosses scale with the SAME single `ENEMY_HP_GROWTH` as trash (Power Curve: the second compounding existed only to chase runaway player power).
- [ ] **Step 3: Spawner**

```gdscript
var _suppress_time := 0.0   # seconds the CURRENT revealed boss has been suppressing trash spawns

## Trash runs at BOSS_SPAWN_RATE_MULT only for the first BOSS_SUPPRESS_MAX_SECONDS a revealed boss
## lives (Power Curve): the slowdown clears room for a duel; it must not reward keeping a boss
## alive as a pet. The boss still blocks the next boss spawn either way.
static func suppression_active(suppress_time: float, revealed_boss_alive: bool) -> bool:
	return revealed_boss_alive and suppress_time < GameConfig.BOSS_SUPPRESS_MAX_SECONDS
```
In `_process`: `var revealed := _revealed_boss_alive()`; `_suppress_time = (_suppress_time + delta) if revealed else 0.0`; replace the `if _revealed_boss_alive():` line with `if suppression_active(_suppress_time, revealed):`. (Resetting to 0 when no revealed boss is alive gives each boss its own 75 s.) If `Spawner.gd` has no `class_name`, call the static via a preload in the probe (`load("res://scripts/Spawner.gd").suppression_active(...)`).
- [ ] **Step 4:** Probe GREEN, dual gate, regression probes. **Commit** `balance(bosses): single HP compounding, roster 0.8-1.3x, 75s spawn-suppression cap`

---

### Task 8: Power-curve sim probe + tuning

**Files:** Create `.superpowers/probe_power_curve.gd/.tscn` (untracked) and **commit a copy of the final probe output** as `docs/superpowers/analysis/2026-09-19/power-curve-probe-v0.1.74.txt`. Modify only `scripts/logic/GameConfig.gd` constants: `XP_BASE`, `XP_GROWTH`, `BOSS_BASE_HP` (+ the 10 roster consts scaled by the same factor so mults are unchanged), `BOSS_XP_REWARD`, and — only if a §4 target can't otherwise be met — `CARD_TIER_BANDS`.

The sim is a deterministic expected-value model stepping 1 s from 0 to 1200 s, reading **live** `GameConfig`/`DifficultyCurve`/`XpCurve`/`Weapons`/`CardRolls` values (no copied constants):
- **Threat(t):** `spawns/s = 1/DifficultyCurve.spawn_interval(wave)`; mean enemy HP = shambler HP × type-mix factor × elite factor. Use the type-mix and elite factors from `map_difficulty.md` §2 (mix factor by wave bracket; elite `min(0.05+0.005w, 0.15)` from w6, effective ×3.39); print them in the output header.
- **XP income(t):** `spawns/s × 0.80 killed × 0.80 collected × mean gem value` (gem = `clampi(roundi(HP/50),1,15)`, elites ×3), × the player's XP mult. Levels via `XpCurve.xp_for_level`.
- **Cards:** on each level-up apply the **expected value** of a roll (`Σ tier_weight × band_mid × base`). Policy: odd levels (player pool) → no DPS effect except Kill Shot taken 1 in 4 odd levels; even levels (gun pool) cycle Hollow Points → Hair Trigger → Extra Barrel → Hollow Points → Fast Hands (repeat). Print the policy.
- **Builds:** FRESH = pistol def, affix DPS ×1.10, no talents. MID = AK-47 def ×1.75 (Lethal mid Razor), crit talent ×1.15, +8 flat DPS drone. LATE = AK-47 ×3.91 (Merciless mid), talents ×3.8, relics ×2.0. `fire_eff` (stop-to-shoot uptime) 0.80→0.65→0.50→0.40 at 0/5/10/20 min, linear between — same as `map_power.md`.
- **Output:** table at t = 1, 3, 5, 8, 9:35, 15, 20 min: level, DPS, threat HP/s, ratio — per build; boss table: for w5/w10/w15/w20 × 11 bosses, TTK = boss HP / DPS of the **reference build for that wave** (w5: FRESH ×1.3, w10: MID, w15: MID ×1.7 [Savage], w20: MID ×2.2 [Carnage]).
- **Poison line (report only, spec §5.4):** for a Minigun carrying the tier-2 poison talent at its mid roll (read `loot/Talents.gd` for chance/dps/duration), print steady-state stacked poison DPS against a w10 boss across a 52 s fight, as a % of that gun's bullet DPS. No FAIL condition — it informs whether poison needs revisiting.
- **Checks (spec §4):** MID level at 1/3/5/8 min within ±2 of 5/12/18/25 and 27–32 at 9:35; MID ratio within 1.5–3.0 at every sampled minute from 3:00 to 9:35; FRESH ratio ≥ 0.5 reported (not a FAIL); every boss TTK at reference gear within 35–75 s and the roster mean within 45–60 s.

- [ ] **Step 1:** Write the probe; run it on the untuned tree; paste the full table (expect boss TTK FAILs — `BOSS_BASE_HP` 1500 is the old number).
- [ ] **Step 2: Tune, in this order, re-running after each:** (1) `XP_BASE`/`XP_GROWTH` until the level checks pass; (2) `BOSS_BASE_HP` (scale roster consts together) until the boss TTK checks pass — solve directly: `new = old × 52 / mean_TTK`; (3) `BOSS_XP_REWARD` so XP from one boss ≈ 50 s × XP income at that wave (report the four ratios; target 0.7–1.3); (4) only if the MID ratio band fails, widen/narrow `CARD_TIER_BANDS` uniformly and say so in the report.
- [ ] **Step 3:** If a target is unreachable without touching something out of scope (enemy HP growth, spawn rate, weapon stats), **STOP and report** the closest achievable table — do not silently change scope.
- [ ] **Step 4:** Update the spec's starter values in `docs/superpowers/specs/2026-09-19-power-curve-design.md` §5 to the tuned numbers (one line each, "tuned: X"). Dual gate + all probes (Tasks 1–7 probes must still pass — fix any probe that hardcoded a starter value by reading the const instead). **Commit** `balance: tune XP curve, boss HP and boss XP against the power-curve probe`

---

### Task 9: Ship v0.1.74

- [ ] Whole-branch review (superpowers:requesting-code-review) over `git diff v0.1.73..HEAD`; fix Important+ findings.
- [ ] `VERSION` → `0.1.74` (file is `0.1.74\n`). `CHANGELOG.md`: new top entry `## v0.1.74 — Performance-Based Pay (<date>)`, house voice (deadpan corporate), bullets: rolled tiered cards (no caps, Legendary moment), ~30 levels/shift pacing, bosses are real fights now (45–60 s) + boss XP, honest fire-rate text, proc fixes (flamethrower, Shatter, execute vs bosses), 120 Hz fairness fix, keeping a boss alive no longer thins the horde.
- [ ] Final gates: editor ≤ 19, boot Main + MainMenu 0, all probes green (hygiene 28/28, overtime farm 16/16, Tasks 1–8).
- [ ] Commit `release: v0.1.74 — Performance-Based Pay (power curve)`, `git tag v0.1.74`, `git push origin master && git push origin v0.1.74`; watch both workflows (`gh run watch <id> --exit-status`) to green; confirm `gh release list` shows v0.1.74.
- [ ] Update memory (`project_zombie_survivor.md` ▶ block + `MEMORY.md` line): shipped, tuned constants, F5 priorities for Larry — card pacing feel, Legendary moment, boss length at w5/w10, minigun/flamethrower proc builds, 60 vs 120 Hz parity. Next: spec 2 (Survivability + new-player wall).

---

## Spec coverage check

| spec § | task |
|---|---|
| 5.1 XP curve, boss XP, 75 s suppression | 4, 7 (suppression), 8 (tuning) |
| 5.2 card rolls, integer cards, Extra Barrel, Kill Shot, Second Wind, presentation, config, Incendiary fixes | 1, 2, 3 |
| 5.3 honest fire rate (cards + talents), affixes untouched, timer remainder | 2 (cards), 5 (frenzy channel + timer) |
| 5.4 procs | 6; poison report line in 8 |
| 5.5 bosses | 7, 8 |
| §3/§4 sim probe + targets | 8 |
| §8 testing | per-task probes + gates; Larry F5 after 9 |

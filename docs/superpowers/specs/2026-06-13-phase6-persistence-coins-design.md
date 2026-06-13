# Phase 6 — Spec 1: Persistence & Coins (design)

**Date:** 2026-06-13
**Status:** Approved (brainstorm), pending spec review
**Game:** Survivor Game (Godot 4.6 / GDScript top-down survivor)
**Repo HEAD at design time:** `19d30f2`

---

## Phase 6 roadmap (context)

Phase 6 is the **meta layer** — what happens between runs. It is too large for one
implementation plan, so it is split into three specs built in dependency order. Each
is independently smoke-testable.

| Spec | Name | Scope |
|------|------|-------|
| **1 (this doc)** | **Persistence & Coins** | Save file, coin wallet, end-of-run payout, high scores. The foundation. |
| 2 | Weapon Variants & Crates | Rolled weapon system (rarity + stat rolls + innate talents + naming), crate %-drop + opening reveal, inventory rework (equip + scrap), weapon-select uses owned guns. The centerpiece. |
| 3 | Character Shop | Spend coins to unlock characters + buy crates. |

### The full meta loop (target end-state, for context only)

- Finish a run → earn **coins** (scaled by wave / bosses / kills) **+ a % chance for a crate**.
- Open a crate → reveals a **rolled weapon** (base family + rarity + stat rolls + innate talent).
- **Inventory** = collection of rolled weapons; **equip one** per run, **scrap** the rest for coins.
- **Shop** = spend coins to unlock characters and buy extra crates.
- Everything saved to `user://savegame.json`.

**Spec 1 implements only the bolded coin/persistence parts.** The crate drop, weapon
rolls, inventory, and shop are explicitly out of scope here.

---

## 1. Goal

Make coins a real, persistent currency. After Spec 1:

- Every run ends with a coin payout scaled by performance, shown on the Game Over screen.
- Coins, plus best-wave and best-bosses high scores, persist across app launches in a JSON save file.
- The main menu shows the current coin balance.

Nothing yet *spends* coins (that's Spec 3) and nothing yet *drops crates* (Spec 2) — Spec 1
is the plumbing those depend on.

## 2. Non-goals (deferred)

- Crate drops / weapons / rarity (Spec 2).
- Inventory, equip, scrap (Spec 2).
- Character shop, spending coins, unlock/lock state (Spec 3).
- Persisting the selected character or mode (Spec 3, when selection becomes meaningful).
- IAP / real-money coin purchases (Phase 8).
- Settings, audio, cloud save.

## 3. Data model

Single save file: **`user://savegame.json`**.

Schema **version 1**:

```json
{
  "version": 1,
  "coins": 0,
  "best_wave": 0,
  "best_bosses": 0
}
```

- `coins` — int, the player's wallet (never negative).
- `best_wave` — int, highest wave reached in any Endless run.
- `best_bosses` — int, most bosses defeated in any run (Boss Rush or Endless).
- `version` — int, schema version for forward migration.

Later specs add keys (`owned_weapons`, `equipped_weapon`, `owned_characters`, `pending_crates`,
…). The loader is built so adding keys never breaks an existing save (see §4).

## 4. Components

### 4.1 `SaveManager` (new autoload — `scripts/SaveManager.gd`)

Owns the in-memory save dictionary and all disk I/O. Registered as an autoload so it loads
once on boot and survives scene changes.

- `const SAVE_PATH := "user://savegame.json"`
- `const DEFAULTS := { "version": 1, "coins": 0, "best_wave": 0, "best_bosses": 0 }`
- `var _data: Dictionary` — the live save state.

**Lifecycle**
- `_ready()` → `load()`.

**Load (`load()`)**
1. Start from `DEFAULTS.duplicate(true)`.
2. If `SAVE_PATH` does not exist → keep defaults (first launch), return.
3. Read the file; `JSON.parse_string` the text.
4. If parse fails or the result is not a Dictionary → **corruption fallback**: copy the bad
   file to `user://savegame.corrupt.json` (best-effort), keep defaults, log a warning, return.
5. Migration/merge: for each key in `DEFAULTS`, if the parsed dict has it **and the type
   matches**, copy it into `_data`; otherwise the default stands. Force `_data.version` to the
   current version. (This drops unknown/legacy keys and back-fills missing ones — adding keys
   in Spec 2/3 is automatically safe.)

**Save (`save()`)**
- Write `JSON.stringify(_data, "\t")` atomically: write to `user://savegame.tmp`, then
  `DirAccess` rename it over `SAVE_PATH`. (Avoids a half-written file if the app is killed mid-write.)
  If the platform's `rename` won't overwrite an existing target, remove the old `SAVE_PATH` first,
  then rename. (Implementation detail for the plan; the contract is "the file is never left half-written".)
- Returns `bool` success; logs on failure (never crashes the game).

**Public API** (mutators change memory only; the caller decides when to `save()`):
- `coins() -> int` — read the wallet.
- `add_coins(amount: int) -> void` — `_data.coins += max(amount, 0)`.
- `spend_coins(amount: int) -> bool` — if `coins() >= amount`, subtract and return `true`; else
  return `false` (no change). *(Unused in Spec 1; present for Spec 3.)*
- `best_wave() -> int`, `best_bosses() -> int` — read high scores.
- `record_run(wave: int, bosses: int) -> void` — `best_wave = max(best_wave, wave)`,
  `best_bosses = max(best_bosses, bosses)`.

All mutators are null/negative-safe.

### 4.2 `RunStats` (new autoload — `scripts/RunStats.gd`)

Per-run counters that the payout reads. Lightweight; no persistence.

- `var kills: int = 0` — trash enemies killed this run.
- `var bosses_killed: int = 0` — bosses killed this run.
- `reset() -> void` — zero both. Called at run start.
- `add_kill() -> void` — `kills += 1`.
- `add_boss() -> void` — `bosses_killed += 1`.

Bosses count **only** toward `bosses_killed`, not `kills`, so the payout's per-kill and
per-boss terms don't double-count.

### 4.3 Coin payout (pure function)

A pure helper computing the run reward. Lives in `scripts/logic/CoinReward.gd`
(`class_name CoinReward`, static, no node deps — matches the existing `XpCurve`/`DifficultyCurve`
pure-logic pattern).

```
static func payout(wave: int, bosses: int, kills: int) -> int:
    return GameConfig.COIN_BASE \
        + GameConfig.COIN_PER_WAVE * wave \
        + GameConfig.COIN_PER_BOSS * bosses \
        + GameConfig.COIN_PER_KILL * kills
```

### 4.4 `GameConfig` additions (new "Coins" group)

| Const | Value | Meaning |
|-------|-------|---------|
| `COIN_BASE` | `10` | Flat coins for finishing a run. |
| `COIN_PER_WAVE` | `5` | Per wave reached (Endless) / per boss-rush wave-equivalent. |
| `COIN_PER_BOSS` | `25` | Per boss defeated. |
| `COIN_PER_KILL` | `1` | Per trash enemy killed. |

All tunable; these are starting values to balance against Spec 2/3 prices later.

## 5. Integration points (exact)

1. **`project.godot`** — register two autoloads after the existing
   `DifficultyManager` / `RunConfig`:
   ```
   SaveManager="*res://scripts/SaveManager.gd"
   RunStats="*res://scripts/RunStats.gd"
   ```

2. **`Main.gd` `_ready()`** — add `RunStats.reset()` next to the existing
   `DifficultyManager.reset()` so every run starts with zeroed counters.

3. **`Enemy.gd`** — on death (the branch in `take_damage` that drops the gem and frees the
   enemy), call `RunStats.add_kill()`.

4. **`Boss.gd` `_reward()`** — call `RunStats.add_boss()` (alongside the existing XP burst /
   full-heal / relic drop).

5. **`GameOver.gd` `_on_player_died()`** — replace the single summary line with:
   - Determine `wave = DifficultyManager.wave` and `bosses = RunStats.bosses_killed`.
   - `var earned := CoinReward.payout(wave, bosses, RunStats.kills)`
   - `SaveManager.add_coins(earned)`, `SaveManager.record_run(wave, bosses)`, `SaveManager.save()`.
   - Build the summary text (PixelTheme-styled, multi-line):
     - Endless: `Wave reached: {wave}   (best {SaveManager.best_wave()})`
     - Boss Rush: `Bosses defeated: {bosses}   (best {SaveManager.best_bosses()})`
     - `Coins earned: +{earned}`
     - `Total coins: {SaveManager.coins()}`
   - This replaces the current boss_rush `boss_rush_count - 1` off-by-one logic with
     `RunStats.bosses_killed`, which is exact in both modes.

6. **`MainMenu.gd` `_build_hub()`** — add a coin-balance readout near the top of the hub (e.g.
   top-right or under the title), pixel font via PixelTheme, text `COINS: {SaveManager.coins()}`.
   Because the menu scene is re-instanced on every return from a run, reading the balance in
   `_ready`/`_build_hub` is always current — no live updating needed.

## 6. Edge cases & decisions

- **First launch:** no file → defaults, coins 0, bests 0. No crash.
- **Corrupt save:** parse failure → back up to `savegame.corrupt.json`, reset to defaults, warn.
  Player loses progress but the game still boots. (Acceptable for v1; atomic writes make this rare.)
- **Forward compatibility:** the merge-over-defaults loader means Spec 2/3 can add keys to
  `DEFAULTS` and old saves silently gain them at their default value.
- **Save frequency:** one `save()` per run-end (in GameOver). `spend_coins` callers (Spec 3)
  will save after spending. No per-frame writes.
- **Negative/overflow:** `add_coins` floors the addend at 0; coins are ints. No realistic overflow
  at these magnitudes.
- **Boss Rush wave value:** `DifficultyManager.wave` keeps ticking in Boss Rush but isn't shown
  there; the Boss Rush summary uses `bosses_killed`. The payout's `COIN_PER_WAVE * wave` still
  applies in Boss Rush (time survived), which is fine.

## 7. Testing / smoke checklist (Larry F5s)

1. **Fresh:** delete `user://savegame.json` (or first run) → menu shows `COINS: 0`.
2. **Earn:** play an Endless run, die → Game Over shows `Wave reached`, `Coins earned: +X`,
   `Total coins: X`. X matches `10 + 5·wave + 25·bosses + 1·kills`.
3. **Bank + display:** back to menu → hub shows the new `COINS` total.
4. **Persist:** fully close Godot, relaunch, F5 → balance and bests are unchanged.
5. **High score:** beat a higher wave than before → `(best …)` updates; do worse → best holds.
6. **Boss Rush:** a Boss Rush run shows `Bosses defeated: N (best M)` and pays `COIN_PER_BOSS·N`.
7. **No crash on corruption:** hand-edit the JSON to garbage → game still boots at defaults and
   writes a `savegame.corrupt.json`.

## 8. Files touched

**New:** `scripts/SaveManager.gd`, `scripts/RunStats.gd`, `scripts/logic/CoinReward.gd`.
**Modified:** `project.godot`, `scripts/logic/GameConfig.gd`, `scripts/Main.gd`, `scripts/Enemy.gd`,
`scripts/Boss.gd`, `scripts/GameOver.gd`, `scripts/MainMenu.gd`.

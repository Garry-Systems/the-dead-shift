extends Node
## AUTOLOAD (registered in project.godot as "RunConfig"). Holds the run-setup choices
## the menu makes — character + game mode — and carries them into the gameplay scene.
## Session-only (no persistence). No class_name: the autoload name is already global.

var character_id := "ryan"
var mode := "endless"        # "endless" | "boss_rush" | "horde"

# --- Locations (Transfer Stores, v0.1.65) ---
## Locations.ALL id for the run about to start. Session-only, same as `mode`/the flags below —
## set by the PLAY-panel location picker (Task 5), read once at run start (Main.gd, Task 2).
## Reset to "forecourt" in clear_mode_flags() alongside the other mode-exclusivity fields;
## Daily Shift and Boss Rush additionally FORCE it back to "forecourt" at their own launch sites
## (MainMenu._on_daily_shift / _start_run's "boss_rush" branch) so neither can ever inherit a
## non-forecourt pick even if a future picker sets `location` in a different order.
var location := "forecourt"

## Set by GameOver's STORE button just before returning to the menu; MainMenu._ready()
## consumes (and resets) this to land directly in the store view instead of the hub.
var open_store_on_menu := false

# --- Mode-exclusivity flags (Pack G: v0.1.58) ---
## HARDCORE and OVERTIME both keep `mode == "endless"` (same pattern `daily` already established)
## so every endless-only gate (NightEvents/Extraction/Hud's dawn bonus, the elite roll) keeps
## working unchanged. HORDE NIGHT is instead its own top-level `mode` value (Spawner routes on it
## directly) since it needs its own spawn/boss/elite behavior, not just a flag layered on endless.
var hardcore := false
var overtime := false

# --- Daily Shift (Pack C, v0.1.53) ---
## True only for a Daily Shift run (always mode == "endless" underneath). `daily_rng` is seeded
## from the date string's hash and consumed ONLY by NightEvents' event/kind rolls, Spawner's
## elite chance/kind rolls, Enemies.pick()'s enemy-type roll, THE BASEMENT's cellar-door roll
## (Basement._on_wave_edge -> _roll_door), its gauntlet's forced-elite kind picks, and its
## gauntlet's own Enemies.pick() call (Basement._spawn_gauntlet_enemy) — via rand_float()/
## rand_int() below. Loot rolls, talent procs, and everything else stay on the engine's global
## RNG (documented partial determinism, per spec: a full deterministic replay isn't attempted).
var daily := false
var daily_rng: RandomNumberGenerator = null

## Arms a fresh seeded generator for `date_str` ("YYYY-MM-DD"). Called once when the Daily Shift
## button is tapped (MainMenu) AND again every time Main.tscn's _ready() runs while `daily` is
## true (covers a mid-run "RESTART RUN" from PauseMenu, which reloads Main.tscn directly,
## bypassing the mode picker) — so a restart replays the SAME deterministic event/elite/enemy-type
## sequence rather than continuing the old generator's already-advanced internal state.
func start_daily(date_str: String) -> void:
	daily = true
	daily_rng = RandomNumberGenerator.new()
	daily_rng.seed = hash(date_str)

## Clears the daily flag/generator. Called at the top of every NORMAL (non-daily) mode start
## (MainMenu._start_run), so a leftover Daily Shift seed from an earlier attempt this session can
## never leak into a plain Endless/Boss Rush run.
func clear_daily() -> void:
	daily = false
	daily_rng = null

## Clears every mode-exclusivity flag (daily + hardcore + overtime). Call at the top of EVERY
## mode-select launch path (MainMenu's ENDLESS/BOSS RUSH/HORDE/DAILY SHIFT/OVERTIME/HARDCORE
## buttons) before arming the ONE flag (if any) that launch actually wants — keeps every picker
## button mutually exclusive, so a flag left over from an earlier session's pick can never leak
## into a different mode's run.
func clear_mode_flags() -> void:
	clear_daily()
	hardcore = false
	overtime = false
	location = "forecourt"   # Transfer Stores: reset with the other run-exclusivity fields; the
	                         # location picker (Task 5) re-applies its pick AFTER this call, same
	                         # as hardcore/overtime/daily do today

## Float roll for the 3 daily-seeded decision points above: the seeded generator while `daily` is
## armed, otherwise the engine's own global RNG (byte-identical to every non-daily run today).
func rand_float() -> float:
	return daily_rng.randf() if (daily and daily_rng != null) else randf()

## Int roll, same fallback rule as rand_float().
func rand_int() -> int:
	return daily_rng.randi() if (daily and daily_rng != null) else randi()

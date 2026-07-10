extends Node
## Per-run counters (kills, bosses) read by the end-of-run coin payout.
## Autoload — survives scene changes; reset() is called at the start of each run
## from Main._ready. Session-only, no persistence. No class_name: the autoload
## name is already global.

var kills := 0
var bosses_killed := 0
var elites_killed := 0   # Pack A: elite-modifier kills (Pack C's challenge board will read this)
var bonus_coins := 0     # coins from in-world sources (e.g. smashed crates), added to the run payout
var coins_per_kill := 0.0   # Pack E: the Janitor's passive — flat bonus coins added on every kill
                             # (0 = no character bonus); set by Main._ready() at run start from
                             # Characters.coin_per_kill_bonus() (kept out of Characters.gd itself
                             # so that file stays autoload-free — see its doc comment).
var paid_out := false    # this run's payout already granted (death OR quit) — no double dipping
var coin_mult := 1.0     # "Silver Tongue" level-up card: multiplies the WHOLE run payout (stacks); the
                         # one place GameOver + PauseMenu's quit path both read from — see CoinReward.final_payout
var weapon_xp_mult := 1.0   # Relics Overhaul: "Punch Card" relic multiplies the run's weapon-XP award
                             # (stacks, mirrors coin_mult's ratio idiom); the one place GameOver's
                             # end-of-run Inventory.add_run_xp chokepoint reads from.
var signing_bonus := 0   # SIGNING BONUS (Benefits.start_cash()): set once at run start (Main.gd), paid out
                         # POST-mult and vested over GameConfig.SIGNING_BONUS_VEST_TIME seconds of run_time
                         # — see CoinReward.vested_signing — so an instant pause-quit can't farm it at full
                         # value x HARDCORE x REGISTER SKIM.

# --- Pack C: challenge-board counters (v0.1.53) — all flushed at the paid_out-guarded payout
# blocks alongside the existing kill/boss/elite counters. See Enemy.take_damage / TalentEngine._chain
# / NightEvents for exactly where each is bumped.
var fire_kills := 0             # kill transition happened while the enemy's incendiary burn was active
var electric_kills := 0         # kill transition happened via TalentEngine._chain's lightning-arc damage
var poison_kills := 0           # kill transition happened while the enemy's Venom DoT was active
var blood_moons_survived := 0   # a Blood Moon event ran its full course (NightEvents._end_event) this run
var power_surge_kills := 0      # kill transition happened while a Power Surge event was active

var basements_cleared := 0      # Pack E (THE BASEMENT), Task 5: gauntlets survived to the reward
                                 # drop this run — bumped at crate SPAWN (Basement._start_reward),
                                 # not at pickup; read by GameOver's pay-stub INFORMATIONAL row.

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0
	elites_killed = 0
	bonus_coins = 0
	coins_per_kill = 0.0
	paid_out = false
	coin_mult = 1.0
	weapon_xp_mult = 1.0
	signing_bonus = 0
	fire_kills = 0
	electric_kills = 0
	poison_kills = 0
	blood_moons_survived = 0
	power_surge_kills = 0
	basements_cleared = 0

## A trash enemy was killed.
func add_kill() -> void:
	kills += 1

## A boss was killed.
func add_boss() -> void:
	bosses_killed += 1

## An elite-modifier enemy was killed (Pack A).
func add_elite_kill() -> void:
	elites_killed += 1

## Add coins earned from an in-world source (smashed crate, etc.).
func add_coins(n: int) -> void:
	bonus_coins += n

## "Silver Tongue" level-up card: raises the run-payout multiplier (multiplicative, stacks).
func add_coin_mult(pct: float) -> void:
	coin_mult *= (1.0 + pct)

# --- Pack C: challenge-board counter bumps (v0.1.53) ---

func add_fire_kill() -> void:
	fire_kills += 1

func add_electric_kill() -> void:
	electric_kills += 1

func add_poison_kill() -> void:
	poison_kills += 1

func add_blood_moon_survived() -> void:
	blood_moons_survived += 1

func add_power_surge_kill() -> void:
	power_surge_kills += 1

## THE BASEMENT (Pack E) gauntlet reward dropped — the run survived it. Called from
## Basement._start_reward(), at crate spawn (not at pickup — the clear itself is the event).
func add_basement_cleared() -> void:
	basements_cleared += 1


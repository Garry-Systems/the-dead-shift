extends Node
## Per-run counters (kills, bosses) read by the end-of-run coin payout.
## Autoload — survives scene changes; reset() is called at the start of each run
## from Main._ready. Session-only, no persistence. No class_name: the autoload
## name is already global.

var kills := 0
var bosses_killed := 0
var elites_killed := 0   # Pack A: elite-modifier kills (Pack C's challenge board will read this)
var bonus_coins := 0     # coins from in-world sources (e.g. smashed crates), added to the run payout
var paid_out := false    # this run's payout already granted (death OR quit) — no double dipping
var coin_mult := 1.0     # "Silver Tongue" level-up card: multiplies the WHOLE run payout (stacks); the
                         # one place GameOver + PauseMenu's quit path both read from — see CoinReward.final_payout

## Zero the counters for a fresh run.
func reset() -> void:
	kills = 0
	bosses_killed = 0
	elites_killed = 0
	bonus_coins = 0
	paid_out = false
	coin_mult = 1.0

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

## Night events (Pack A, Blood Moon): add a FLAT amount to coin_mult (not multiplicative like
## the card above), so the event can remove EXACTLY the same amount on end regardless of what
## add_coin_mult() has done before/after/during — composes with the card by pure addition.
func adjust_coin_mult(delta: float) -> void:
	coin_mult += delta

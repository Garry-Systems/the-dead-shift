class_name CoinReward
## Pure end-of-run coin payout math. No node or state dependencies
## (mirrors XpCurve / DifficultyCurve). Tunable via GameConfig.COIN_* consts.

## Coins awarded for a run: a flat base plus per-wave, per-boss, and per-kill terms.
static func payout(wave: int, bosses: int, kills: int) -> int:
	return GameConfig.COIN_BASE \
		+ GameConfig.COIN_PER_WAVE * wave \
		+ GameConfig.COIN_PER_BOSS * bosses \
		+ GameConfig.COIN_PER_KILL * kills

## SIGNING BONUS (final-review fix): vests linearly over GameConfig.SIGNING_BONUS_VEST_TIME
## seconds of run_time, capped at the full bonus — kills the instant-quit farm where a
## pause-and-quit at 0s used to bank the whole bonus x HARDCORE x3 x REGISTER SKIM. Pure static
## (no RunStats/DifficultyManager reference) so it's probe-able headless: vested_signing(250, 0)
## == 0, vested_signing(250, 60) == 125, vested_signing(250, 120) == vested_signing(250, 999) == 250.
static func vested_signing(bonus: int, run_time: float) -> int:
	return roundi(float(bonus) * clampf(run_time / GameConfig.SIGNING_BONUS_VEST_TIME, 0.0, 1.0))

## Full run payout: the base formula above, plus in-world bonus coins (smashed crates), times
## the run's coin multiplier (the "Silver Tongue" level-up card) — the ONE shared place both the
## death payout (GameOver) and the quit/restart payout (PauseMenu, which further scales the
## result by QUIT_PAYOUT_FRAC) compute "earned coins", so the card can't apply on one path only.
## The vested signing bonus is added POST-mult (final-review fix) — it does NOT compose with
## coin_mult (HARDCORE / Silver Tongue / REGISTER SKIM all live in that one accumulator), it's
## strictly time-vested. Both callers pass the SAME signing_bonus/run_time so it can't double-pay.
static func final_payout(wave: int, bosses: int, kills: int, bonus: int, mult: float, signing_bonus: int, run_time: float) -> int:
	var total := int(round(float(payout(wave, bosses, kills) + bonus) * mult))
	total += vested_signing(signing_bonus, run_time)
	return total

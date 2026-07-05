class_name CoinReward
## Pure end-of-run coin payout math. No node or state dependencies
## (mirrors XpCurve / DifficultyCurve). Tunable via GameConfig.COIN_* consts.

## Coins awarded for a run: a flat base plus per-wave, per-boss, and per-kill terms.
static func payout(wave: int, bosses: int, kills: int) -> int:
	return GameConfig.COIN_BASE \
		+ GameConfig.COIN_PER_WAVE * wave \
		+ GameConfig.COIN_PER_BOSS * bosses \
		+ GameConfig.COIN_PER_KILL * kills

## Full run payout: the base formula above, plus in-world bonus coins (smashed crates), times
## the run's coin multiplier (the "Silver Tongue" level-up card) — the ONE shared place both the
## death payout (GameOver) and the quit/restart payout (PauseMenu, which further scales the
## result by QUIT_PAYOUT_FRAC) compute "earned coins", so the card can't apply on one path only.
static func final_payout(wave: int, bosses: int, kills: int, bonus: int, mult: float) -> int:
	return int(round(float(payout(wave, bosses, kills) + bonus) * mult))

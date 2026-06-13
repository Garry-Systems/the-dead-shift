class_name CoinReward
## Pure end-of-run coin payout math. No node or state dependencies
## (mirrors XpCurve / DifficultyCurve). Tunable via GameConfig.COIN_* consts.

## Coins awarded for a run: a flat base plus per-wave, per-boss, and per-kill terms.
static func payout(wave: int, bosses: int, kills: int) -> int:
	return GameConfig.COIN_BASE \
		+ GameConfig.COIN_PER_WAVE * wave \
		+ GameConfig.COIN_PER_BOSS * bosses \
		+ GameConfig.COIN_PER_KILL * kills

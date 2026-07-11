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

## PAYDAY (Deep Clean, item 4): the run subtotal BEFORE RunStats.coin_mult is applied — base
## formula plus in-world bonus coins, nothing else. Exactly the same "subtotal" pre_cut_total/
## final_payout multiply by mult (see the "SHIFT BONUS" row comment in GameOver._populate_stub,
## which already calls this quantity "the subtotal"). Feeds SaveManager.record_best_run_payout so
## HARDCORE's x3 coin_mult (and REGISTER SKIM/tip_jar composing into the same accumulator) can't
## trivialize the PAYDAY commendation just by holding a stacked multiplier — the badge now
## measures actual in-run scale (waves/bosses/kills/bonus), not the multiplier stack. Deliberately
## excludes the vested signing bonus too (it's added post-mult in pre_cut_total but isn't itself
## part of "the subtotal" mult composes over) and any win/clawback adjustment — this is the purest
## pre-mult number, matching "PRE-coin_mult subtotal" from the design doc literally. Both GameOver
## and PauseMenu call this with the SAME (wave, bosses, kills, bonus) locals they already compute
## for final_payout, so the two twin call sites can't drift.
static func pre_mult_total(wave: int, bosses: int, kills: int, bonus: int) -> int:
	return payout(wave, bosses, kills) + bonus

## The run total BEFORE company_card's clawback: (base formula + in-world bonus) × mult, plus the
## vested signing bonus. Split out of final_payout (pure static, probe-able) so GameOver's
## pay-stub can itemize the clawback with EXACTLY the arithmetic final_payout applies — see
## clawback() below. NOT flag-gated: this is the same number final_payout pays whenever
## company_card isn't held.
static func pre_cut_total(wave: int, bosses: int, kills: int, bonus: int, mult: float, signing_bonus: int, run_time: float) -> int:
	var total := int(round(float(payout(wave, bosses, kills) + bonus) * mult))
	total += vested_signing(signing_bonus, run_time)
	return total

## Relics Overhaul (company_card): the coin amount "corporate claws back" off a pre-cut total.
## Defined as `pre_cut - roundi(pre_cut * (1 - RELIC_CARD_STUB_CUT))` — the exact complement of
## what final_payout keeps — so the stub's "-cut" row and the paid TOTAL always sum exactly,
## rounding included (a naive `roundi(pre_cut * CUT)` could drift the sum by 1 on .5 boundaries).
static func clawback(pre_cut: int) -> int:
	return pre_cut - roundi(float(pre_cut) * (1.0 - GameConfig.RELIC_CARD_STUB_CUT))

## Full run payout: the base formula above, plus in-world bonus coins (smashed crates), times
## the run's coin multiplier (the "Silver Tongue" level-up card) — the ONE shared place both the
## death payout (GameOver) and the quit/restart payout (PauseMenu, which further scales the
## result by QUIT_PAYOUT_FRAC) compute "earned coins", so the card can't apply on one path only.
## The vested signing bonus is added POST-mult (final-review fix) — it does NOT compose with
## coin_mult (HARDCORE / Silver Tongue / REGISTER SKIM all live in that one accumulator), it's
## strictly time-vested. Both callers pass the SAME signing_bonus/run_time so it can't double-pay.
static func final_payout(wave: int, bosses: int, kills: int, bonus: int, mult: float, signing_bonus: int, run_time: float) -> int:
	var total := pre_cut_total(wave, bosses, kills, bonus, mult, signing_bonus, run_time)
	# Relics Overhaul (company_card): "corporate claws back 25%" — a post-mult cut on the FINAL
	# total (base+bonus+mult, PLUS the vested signing bonus), the same vested-signing precedent
	# (a late, additive-then-multiplicative step). Static class-level flag read — no node/instance
	# needed, so this stays true to the file's own "pure, no state dependency" doc comment; both
	# twin callers (GameOver._finish_run, PauseMenu._abandon_run_payout) get it automatically since
	# both already route through this one chokepoint. Subtracting clawback() (instead of re-rounding
	# inline) keeps this the byte-same result as before AND guarantees the stub row sums (see above).
	if RelicEffects.company_card:
		total -= clawback(total)
	return total

## Weapon-loot run-XP payout (Deep Clean, item 17): the amount awarded to the equipped weapon's
## own XP track (Inventory.add_run_xp) at run end. Base formula `kills + wave*10 + bosses*50`,
## times `RunStats.weapon_xp_mult` (the "Punch Card" relic, Relics Overhaul) times
## GameConfig.HARDCORE_WEAPON_XP_MULT when RunConfig.hardcore — both mults compose into ONE float
## and round ONCE (`int(round(...))`), mirroring final_payout's own single-round idiom. Reads
## RunStats/RunConfig directly (same precedent as final_payout reading RelicEffects.company_card
## above — a static class-level/autoload flag read, not a node dependency) rather than taking them
## as params, so the twin call sites (GameOver._finish_run, PauseMenu._abandon_run_payout) can
## never let their own copies of the mult composition drift apart — there's only one copy, here.
static func weapon_xp_payout(kills: int, wave: int, bosses: int) -> int:
	var xp_amount := kills + wave * 10 + bosses * 50
	var xp_mult := RunStats.weapon_xp_mult
	if RunConfig.hardcore:
		xp_mult *= GameConfig.HARDCORE_WEAPON_XP_MULT
	return int(round(float(xp_amount) * xp_mult))

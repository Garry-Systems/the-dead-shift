class_name XpCurve
## Pure XP-threshold math. No node dependency.

## XP required to advance FROM `level` to `level + 1`. Geometric (Power Curve v0.1.74): XP income
## grows ~20%/wave (gem value tracks enemy HP), so a linear cost gave level ~57 by extraction and a
## card every ~6s. XP_BASE x XP_GROWTH^level targets ~29 levels at 9:35 (5/12/18/25 at 1/3/5/8 min).
static func xp_for_level(level: int) -> int:
	return roundi(GameConfig.XP_BASE * pow(GameConfig.XP_GROWTH, level))

## Wave-current trash-zombie gem value for a kill worth this much max HP: ratio to the wave-1
## baseline (GameConfig.ENEMY_MAX_HEALTH), clamped to [1, XP_GEM_VALUE_MAX]. Used by
## Enemy._drop_gem (the base value, before elite/night-event multipliers and its own final clamp)
## and, through boss_gem_value() below, by BossBase._reward.
static func gem_value_for_hp(max_health: float) -> int:
	return clampi(roundi(max_health / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)

## XP value of ONE boss gem on `wave` (Power Curve): the wave-current basic-zombie gem value times the
## wave's spawn rate relative to wave 1 — trash XP income grows with BOTH, so a flat count of
## trash-valued gems fell to ~0.2x of a fight's worth of income by wave 20. Deliberately NOT capped by
## XP_GEM_VALUE_MAX (that cap exists to stop elite/late trash gems running away, not boss payouts).
static func boss_gem_value(wave: int) -> int:
	var trash_hp: float = float(DifficultyCurve.enemy_stats(wave)["max_health"])
	var rate := DifficultyCurve.spawn_interval(1) / DifficultyCurve.spawn_interval(wave)
	return maxi(1, roundi(float(gem_value_for_hp(trash_hp)) * rate * GameConfig.BOSS_GEM_VALUE_MULT))

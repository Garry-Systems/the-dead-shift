class_name XpCurve
## Pure XP-threshold math. No node dependency.

## XP required to advance FROM `level` to `level + 1`. Geometric (Power Curve v0.1.74): XP income
## grows ~20%/wave (gem value tracks enemy HP), so a linear cost gave level ~57 by extraction and a
## card every ~6s. XP_BASE x XP_GROWTH^level targets ~29 levels at 9:35 (5/12/18/25 at 1/3/5/8 min).
static func xp_for_level(level: int) -> int:
	return roundi(GameConfig.XP_BASE * pow(GameConfig.XP_GROWTH, level))

## Wave-current trash-zombie gem value for a kill worth this much max HP: ratio to the wave-1
## baseline (GameConfig.ENEMY_MAX_HEALTH), clamped to [1, XP_GEM_VALUE_MAX]. Shared by
## Enemy._drop_gem (the base value, before elite/night-event multipliers and its own final clamp)
## and BossBase._reward (so boss gems pay what a wave-current trash kill pays instead of a flat
## historical amount).
static func gem_value_for_hp(max_health: float) -> int:
	return clampi(roundi(max_health / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)

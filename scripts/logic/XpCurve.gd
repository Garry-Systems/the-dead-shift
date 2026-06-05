class_name XpCurve
## Pure XP-threshold math. No node dependency.

## XP required to advance FROM `level` to `level + 1`.
## Level 0->1 costs XP_BASE, and each later level costs XP_PER_LEVEL more.
static func xp_for_level(level: int) -> int:
	return GameConfig.XP_BASE + level * GameConfig.XP_PER_LEVEL

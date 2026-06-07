class_name DifficultyCurve
## Pure wave -> difficulty math. No node/scene dependency so it can be reasoned about
## (and unit-tested later) in isolation. Wave 1 = base stats (no growth); each later
## wave applies a geometric multiplier from GameConfig.

## Scaled stats for an enemy spawned on the given wave.
static func enemy_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)   # wave 1 -> exponent 0 -> base stats
	var hp: float = GameConfig.ENEMY_MAX_HEALTH * pow(GameConfig.ENEMY_HP_GROWTH, w)
	var dmg: float = GameConfig.ENEMY_TOUCH_DAMAGE * pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var spd: float = minf(GameConfig.ENEMY_MOVE_SPEED * pow(GameConfig.ENEMY_SPEED_GROWTH, w), GameConfig.ENEMY_SPEED_CAP)
	return {"max_health": hp, "move_speed": spd, "touch_damage": dmg}

## Seconds between spawns on the given wave (decays toward SPAWN_INTERVAL_FLOOR).
static func spawn_interval(wave: int) -> float:
	var w := maxi(wave - 1, 0)
	var interval: float = GameConfig.SPAWN_INTERVAL * pow(GameConfig.SPAWN_INTERVAL_DECAY, w)
	return maxf(interval, GameConfig.SPAWN_INTERVAL_FLOOR)

## Scaled stats for a boss spawned on the given wave. Reuses the enemy HP/damage
## growth curves on top of the boss base values; move speed is fixed (bosses are slow).
static func boss_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)
	var hp: float = GameConfig.BOSS_BASE_HP * pow(GameConfig.ENEMY_HP_GROWTH, w)
	var dmg: float = GameConfig.BOSS_TOUCH_DAMAGE * pow(GameConfig.ENEMY_DMG_GROWTH, w)
	return {"max_health": hp, "move_speed": GameConfig.BOSS_MOVE_SPEED, "touch_damage": dmg}

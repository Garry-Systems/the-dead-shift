class_name DifficultyCurve
## Pure wave -> difficulty math. No node/scene dependency so it can be reasoned about
## (and unit-tested later) in isolation. Wave 1 = base stats (no growth); each later
## wave applies a geometric multiplier from GameConfig.

## Scaled stats for an enemy spawned on the given wave.
static func enemy_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)   # wave 1 -> exponent 0 -> base stats
	# Early HP/speed growth freezes at ENEMY_LATE_WAVE; past it a steeper late multiplier takes
	# over, so waves 1..ENEMY_LATE_WAVE are unchanged and the harder ramp only applies after.
	var early := mini(w, GameConfig.ENEMY_LATE_WAVE - 1)
	var hp: float = GameConfig.ENEMY_MAX_HEALTH * pow(GameConfig.ENEMY_HP_GROWTH, early)
	var spd: float = GameConfig.ENEMY_MOVE_SPEED * pow(GameConfig.ENEMY_SPEED_GROWTH, early)
	var growth := pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var dmg: float = GameConfig.ENEMY_TOUCH_DAMAGE * growth
	if wave > GameConfig.ENEMY_LATE_WAVE:
		var lw := wave - GameConfig.ENEMY_LATE_WAVE
		hp *= pow(GameConfig.ENEMY_LATE_HP_GROWTH, lw)
		spd *= pow(GameConfig.ENEMY_LATE_SPEED_GROWTH, lw)
	spd = minf(spd, GameConfig.ENEMY_SPEED_CAP)
	return {"max_health": hp, "move_speed": spd, "touch_damage": dmg, "special_mult": growth}

## Seconds between spawns on the given wave (decays toward SPAWN_INTERVAL_FLOOR).
static func spawn_interval(wave: int) -> float:
	var w := maxi(wave - 1, 0)
	var interval: float = GameConfig.SPAWN_INTERVAL * pow(GameConfig.SPAWN_INTERVAL_DECAY, w)
	return maxf(interval, GameConfig.SPAWN_INTERVAL_FLOOR)

## Elites (Pack A): the elite-roll chance on this wave (0 before ELITE_MIN_WAVE, capped at
## ELITE_CHANCE_CAP). Pure -- no RNG -- so a probe can verify the curve headlessly; the actual
## roll (randf() against this) lives in Spawner, which also applies the Dawn Extraction surge's
## elite_chance_mult() on top.
static func elite_chance(wave: int) -> float:
	if wave < GameConfig.ELITE_MIN_WAVE:
		return 0.0
	return minf(GameConfig.ELITE_CHANCE_BASE + GameConfig.ELITE_CHANCE_PER_WAVE * float(wave), GameConfig.ELITE_CHANCE_CAP)

## Scaled stats for a boss spawned on the given wave. Reuses the enemy HP/damage
## growth curves on top of the boss base values; move speed is fixed (bosses are slow).
static func boss_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)
	var hp: float = GameConfig.BOSS_BASE_HP * pow(GameConfig.ENEMY_HP_GROWTH, w)
	var growth := pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var dmg: float = GameConfig.BOSS_TOUCH_DAMAGE * growth
	# Past the late wave, bosses ramp like trash does — otherwise trash HP outgrows
	# bosses and every 5th late wave becomes the EASY part of the run.
	if wave > GameConfig.ENEMY_LATE_WAVE:
		hp *= pow(GameConfig.BOSS_LATE_HP_GROWTH, wave - GameConfig.ENEMY_LATE_WAVE)
	return {"max_health": hp, "move_speed": GameConfig.BOSS_MOVE_SPEED, "touch_damage": dmg, "special_mult": growth}

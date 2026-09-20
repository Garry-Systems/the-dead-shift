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

## Scaled stats for a boss spawned on the given wave. Move speed is fixed (bosses are slow) and
## touch damage / special_mult still ride the shared ENEMY_DMG_GROWTH. HP does NOT: bosses have
## their own single compounding rate, GameConfig.BOSS_HP_GROWTH, deliberately steeper than trash's
## ENEMY_HP_GROWTH. Trash only has to keep pace with the player's in-run cards; a boss also has to
## keep pace with the gear ladder between runs (Rusted -> Lethal -> Savage -> Carnage), and the
## power-curve probe measured that combined growth at ~1.2-1.44/wave. The old double-compounding
## branch (BOSS_LATE_HP_GROWTH past ENEMY_LATE_WAVE) stays deleted — this is ONE rate applied at
## every wave, tuned by the probe to hold Larry's D5 "on-curve boss fight = 45-60s".
static func boss_stats(wave: int) -> Dictionary:
	var w := maxi(wave - 1, 0)
	var hp: float = GameConfig.BOSS_BASE_HP * pow(GameConfig.BOSS_HP_GROWTH, w)
	var growth := pow(GameConfig.ENEMY_DMG_GROWTH, w)
	var dmg: float = GameConfig.BOSS_TOUCH_DAMAGE * growth
	return {"max_health": hp, "move_speed": GameConfig.BOSS_MOVE_SPEED, "touch_damage": dmg, "special_mult": growth}

class_name BroodMother
extends BossBase
## Exercises SummonSpawner + ZoneFill + ProjectileEmitter over three phases. Combat-model
## exploit: decoy adds hijack the player's nearest-target auto-aim so fire wanders off the
## boss; acid zones deny the stand-still firing spots.

const BOSS_ID := "brood_mother"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.BROOD_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var zone := { "radius": 90.0, "dps": GameConfig.BROOD_ZONE_DPS, "duration": 4.0, "at": "player", "windup": 0.9 }
	return [
		{
			"at": 1.0, "cadence": 4.0,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.BROOD_SUMMON_COUNT, "windup": 0.9 } },
				{ "scene": Patterns.ZONE, "params": zone },
			],
		},
		{
			"at": 0.66, "cadence": 3.2,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.BROOD_SUMMON_COUNT, "decoy": true, "windup": 0.8 } },
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.EMITTER, "params": { "count": GameConfig.BROOD_RING_COUNT, "pattern": "ring", "speed": 180.0, "windup": 0.7 } },
			],
		},
		{
			"at": 0.33, "cadence": 2.6,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": 4, "decoy": true, "windup": 0.7 } },
				{ "scene": Patterns.EMITTER, "params": { "count": 10, "pattern": "ring", "speed": 200.0, "windup": 0.6 } },
				{ "scene": Patterns.ZONE, "params": zone },
			],
		},
	]

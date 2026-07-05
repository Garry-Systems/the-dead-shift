class_name HeatTyrant
extends BossBase
## OVERCLOX, the Heat Tyrant. Exercises ExpandingRing + AimedBand + DebuffApplier over three
## phases. Combat-model exploit: the <33% "Forced Vent" gun-jam removes auto-fire for a
## window, so the player must dash/kite with no DPS — attacking the stand-still-and-fire default.

const BOSS_ID := "heat_tyrant"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.HEAT_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var ring := { "radius": 200.0, "expand_time": 0.5, "damage": GameConfig.SLAM_DAMAGE, "windup": 0.8 }
	var band := { "length": GameConfig.AIMED_BAND_LENGTH, "damage": GameConfig.HEAT_BAND_DAMAGE, "windup": 0.9 }
	return [
		{
			"at": 1.0, "cadence": 3.5,
			"patterns": [
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.66, "cadence": 3.0,
			"patterns": [
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.33, "cadence": 2.6,
			"patterns": [
				{ "scene": Patterns.DEBUFF, "params": { "kind": "jam", "duration": GameConfig.HEAT_JAM_DURATION, "windup": 0.8 } },
				{ "scene": Patterns.RING, "params": ring },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
	]

class_name Brute
extends BossBase
## The original brute, ported to BossBase as the parity proof. One phase: a periodic
## telegraphed ground-slam (ExpandingRing) using the SLAM_* config.

const BOSS_ID := "brute"

func _build_phases() -> Array:
	return [
		{
			"at": 1.0,
			"cadence": GameConfig.SLAM_INTERVAL,
			"patterns": [
				{ "scene": Patterns.RING, "params": {
					"radius": GameConfig.SLAM_RADIUS,
					"expand_time": GameConfig.SLAM_EXPAND_TIME,
					"damage": GameConfig.SLAM_DAMAGE,
					"windup": GameConfig.SLAM_WINDUP,
				} },
			],
		},
	]

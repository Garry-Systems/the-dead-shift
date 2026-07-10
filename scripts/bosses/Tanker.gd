class_name Tanker
extends BossBase
## THE TANKER — the fuel-delivery driver who never left. Crawls between bursts; all the threat
## is in TrailDash: long charges that leak fuel puddles which ignite after a beat, carving the
## kite space into burning corridors (area denial that CHASES, vs the Fryer's static zones).
## P2 layers static fuel spills near the player; P3 is the JACKKNIFE — two chained dashes with
## a denser trail, capped with a tank-rupture ring when he stops. Combat-model exploit: the
## arena itself shrinks around your dodge lanes.

const BOSS_ID := "tanker"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.TANKER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var dash := { "speed": GameConfig.TANKER_CHARGE_SPEED, "duration": GameConfig.TANKER_CHARGE_DURATION,
		"windup": 0.9 }
	var spill := { "radius": 100.0, "dps": GameConfig.TANKER_POOL_DPS, "duration": GameConfig.TANKER_POOL_DURATION,
		"at": "player", "windup": 0.9 }
	var jackknife := { "speed": GameConfig.TANKER_CHARGE_SPEED, "duration": GameConfig.TANKER_CHARGE_DURATION,
		"windup": 0.9, "chain": 1, "spacing": GameConfig.TANKER_JACKKNIFE_SPACING }
	var rupture := { "radius": GameConfig.TANKER_RUPTURE_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.TANKER_RUPTURE_DAMAGE, "windup": GameConfig.SLAM_WINDUP }
	return [
		{
			"at": 1.0, "cadence": 4.6, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": dash },
			],
		},
		{
			"at": 0.66, "cadence": 4.0, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": dash },
				{ "scene": Patterns.ZONE, "params": spill },
			],
		},
		{
			"at": 0.33, "cadence": 3.4, "speed_mult": GameConfig.TANKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.TRAIL, "params": jackknife },
				{ "scene": Patterns.RING, "params": rupture },
			],
		},
	]

## Regalia over the shared sprite until real art loads: trucker cap + a coiled hose loop with
## nozzle. Palette C2/C4/C1 only.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-14, -34), Vector2(28, 8)), PixelTheme.ACCENT_DIM)    # cap crown
	draw_rect(Rect2(Vector2(-20, -26), Vector2(40, 4)), PixelTheme.ACCENT_DIM)    # cap brim
	draw_arc(Vector2(16, 10), 12.0, 0.0, TAU, 24, PixelTheme.ACCENT, 3.0)         # coiled hose
	draw_rect(Rect2(Vector2(26, 16), Vector2(8, 4)), PixelTheme.DARK)             # nozzle

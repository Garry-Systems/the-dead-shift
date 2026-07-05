class_name Fryer
extends BossBase
## THE FRYER — medium pace, area-denial. Drops fry-oil pools (ZoneFill) that deny the stand-
## still-and-fire spots the player relies on, and snaps heat-lamp bands (AimedBand) across the
## lane. Combat-model exploit mirrors Heat Tyrant's: the pools force movement, the bands punish
## standing in the open while moving.

const BOSS_ID := "fryer"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.FRYER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var zone := { "radius": 100.0, "dps": GameConfig.FRYER_ZONE_DPS, "duration": 4.0, "at": "player", "windup": 0.9 }
	var band := { "length": GameConfig.AIMED_BAND_LENGTH, "damage": GameConfig.FRYER_BAND_DAMAGE, "windup": 0.9 }
	return [
		{
			"at": 1.0, "cadence": 3.6,
			"patterns": [
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.66, "cadence": 3.0,
			"patterns": [
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.BAND, "params": band },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
		{
			"at": 0.33, "cadence": 2.5,
			"patterns": [
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.ZONE, "params": zone },
				{ "scene": Patterns.BAND, "params": band },
			],
		},
	]

## Regalia drawn OVER the shared enemy sprite (its Sprite2D sits at z_index -1 in the scene) —
## a wire fry basket held out front + its handle, palette C2/C4 only.
func _draw() -> void:
	var basket := PackedVector2Array([Vector2(-14, 8), Vector2(14, 8), Vector2(10, 32), Vector2(-10, 32), Vector2(-14, 8)])
	draw_polyline(basket, PixelTheme.ACCENT, 2.0)
	for x in [-10.0, 0.0, 10.0]:
		draw_line(Vector2(x, 10), Vector2(x * 0.7, 30), PixelTheme.ACCENT, 1.5)
	draw_line(Vector2(14, 8), Vector2(34, -8), PixelTheme.ACCENT_DIM, 4.0)   # handle

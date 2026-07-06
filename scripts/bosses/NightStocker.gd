class_name NightStocker
extends BossBase
## THE NIGHT STOCKER — fast, squishy. Telegraphs then dashes at the player's position-at-windup
## (ChargeDash) and drops a solid crate obstacle behind itself as it moves (CrateDrop), slowly
## turning the arena into a maze it can weave through faster than you. Combat-model note: low HP
## rewards landing shots on it specifically (unlike The Manager's adds-first pressure), but its
## charge punishes standing still to do so.

const BOSS_ID := "night_stocker"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.STOCKER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var charge := { "windup": 0.6 }   # every other key falls back to GameConfig.CHARGE_* defaults
	return [
		{
			"at": 1.0, "cadence": 3.0, "speed_mult": GameConfig.STOCKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.CRATE, "params": {} },
			],
		},
		{
			"at": 0.66, "cadence": 2.6, "speed_mult": GameConfig.STOCKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.CRATE, "params": {} },
				{ "scene": Patterns.CHARGE, "params": charge },
			],
		},
		{
			"at": 0.33, "cadence": 2.2, "speed_mult": GameConfig.STOCKER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.CRATE, "params": {} },
			],
		},
	]

## Regalia drawn OVER the shared enemy sprite (its Sprite2D sits at z_index -1 in the scene) —
## a stockroom cap + a pair of carried boxes, palette C1/C2/C4 only. Pack F (v0.1.55): skipped
## once the real art/bosses/night_stocker.png sprite loads (it bakes the same cap+boxes into the
## art itself) — the staged-rollout fallback for a boss with no art.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-16, -44), Vector2(32, 8)), PixelTheme.ACCENT_DIM)   # cap brim
	draw_arc(Vector2(0, -44), 16.0, PI, TAU, 16, PixelTheme.ACCENT_DIM, 8.0)     # cap crown
	var box_a := Rect2(Vector2(22, -6), Vector2(16, 16))
	var box_b := Rect2(Vector2(24, 8), Vector2(16, 16))
	draw_rect(box_a, PixelTheme.DARK)
	draw_rect(box_a, PixelTheme.ACCENT, false, 2.0)
	draw_rect(box_b, PixelTheme.DARK)
	draw_rect(box_b, PixelTheme.ACCENT, false, 2.0)

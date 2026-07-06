class_name Courier
extends BossBase
## THE COURIER — mobile arena-crosser. Charges the length of the arena (ChargeDash, tuned
## longer/faster than the Stocker's), scatters radial parcel bursts (ProjectileEmitter "ring"),
## and carries a slow-you-down aura (DebuffApplier "slow") so you can't simply out-walk it
## between charges. Combat-model note: the slow aura is what makes the charges actually land —
## without it a full-speed player just steps out of the dash lane during the windup.

const BOSS_ID := "courier"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.COURIER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var charge := { "speed": GameConfig.COURIER_CHARGE_SPEED, "duration": GameConfig.COURIER_CHARGE_DURATION, "windup": 0.7 }
	var burst := { "count": GameConfig.COURIER_RING_COUNT, "pattern": "ring", "speed": 220.0, "windup": 0.7 }
	var slow := { "kind": "slow", "duration": GameConfig.COURIER_SLOW_DURATION, "factor": GameConfig.COURIER_SLOW_FACTOR, "windup": 0.6 }
	return [
		{
			"at": 1.0, "cadence": 4.0, "speed_mult": GameConfig.COURIER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.EMITTER, "params": burst },
			],
		},
		{
			"at": 0.66, "cadence": 3.4, "speed_mult": GameConfig.COURIER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.EMITTER, "params": burst },
				{ "scene": Patterns.DEBUFF, "params": slow },
			],
		},
		{
			"at": 0.33, "cadence": 2.8, "speed_mult": GameConfig.COURIER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.DEBUFF, "params": slow },
				{ "scene": Patterns.CHARGE, "params": charge },
				{ "scene": Patterns.EMITTER, "params": burst },
				{ "scene": Patterns.CHARGE, "params": charge },
			],
		},
	]

## Regalia drawn OVER the shared enemy sprite (its Sprite2D sits at z_index -1 in the scene) —
## a delivery helmet + a diagonal satchel strap with a pouch, palette C1/C2/C4 only. Pack F
## (v0.1.55): skipped once the real art/bosses/courier.png sprite loads (it bakes the same
## helmet+satchel into the art itself) — the staged-rollout fallback for a boss with no art.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_circle(Vector2(0, -34), 18.0, PixelTheme.ACCENT_DIM)
	draw_arc(Vector2(0, -34), 18.0, 0.0, TAU, 24, PixelTheme.ACCENT, 2.0)
	var strap := PackedVector2Array([Vector2(-16, -28), Vector2(-6, -28), Vector2(18, 30), Vector2(8, 30)])
	draw_colored_polygon(strap, PixelTheme.DARK)
	var pouch := Rect2(Vector2(4, 22), Vector2(20, 16))
	draw_rect(pouch, PixelTheme.ACCENT)
	draw_rect(pouch, PixelTheme.DARK, false, 2.0)

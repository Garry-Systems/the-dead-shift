class_name Manager
extends BossBase
## THE MANAGER — night-shift middle management. Tanky and slow: calls in staff adds
## (SummonSpawner) so you're never fighting just him, jams the gun (DebuffApplier "jam") to
## force a kite-with-no-DPS window, and throws a ground-slam tantrum (ExpandingRing) when
## pushed. Combat-model note: his own chase speed is deliberately weak — the adds + jam window
## are the real pressure, not his touch damage.

const BOSS_ID := "manager"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.MANAGER_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var ring := { "radius": GameConfig.SLAM_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.SLAM_DAMAGE, "windup": GameConfig.SLAM_WINDUP }
	var jam := { "kind": "jam", "duration": GameConfig.MANAGER_JAM_DURATION, "windup": 0.8 }
	return [
		{
			"at": 1.0, "cadence": 4.5, "speed_mult": GameConfig.MANAGER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.MANAGER_SUMMON_COUNT, "windup": 0.9 } },
				{ "scene": Patterns.RING, "params": ring },
			],
		},
		{
			"at": 0.66, "cadence": 3.8, "speed_mult": GameConfig.MANAGER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.MANAGER_SUMMON_COUNT, "windup": 0.85 } },
				{ "scene": Patterns.DEBUFF, "params": jam },
				{ "scene": Patterns.RING, "params": ring },
			],
		},
		{
			"at": 0.33, "cadence": 3.2, "speed_mult": GameConfig.MANAGER_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.DEBUFF, "params": jam },
				{ "scene": Patterns.SUMMON, "params": { "count": GameConfig.MANAGER_SUMMON_COUNT + 1, "windup": 0.8 } },
				{ "scene": Patterns.RING, "params": ring },
			],
		},
	]

## Regalia drawn OVER the shared enemy sprite (its Sprite2D sits at z_index -1 in the scene) —
## a dark necktie wedge + a lavender ID badge, palette C1/C4 only.
func _draw() -> void:
	var tie := PackedVector2Array([Vector2(-6, -30), Vector2(6, -30), Vector2(0, 26)])
	draw_colored_polygon(tie, PixelTheme.DARK)
	draw_polyline(PackedVector2Array([Vector2(-6, -30), Vector2(0, 26), Vector2(6, -30)]), PixelTheme.ACCENT, 2.0)
	var badge := Rect2(Vector2(16, -24), Vector2(14, 12))
	draw_rect(badge, PixelTheme.ACCENT)
	draw_rect(badge, PixelTheme.DARK, false, 2.0)

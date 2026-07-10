class_name Karen
extends BossBase
## THE KAREN — the roster's first CUSTOMER (everyone else is staff or monster). Weak touch,
## quick feet; the kit attacks the player's aim and footing: ScreamRing shoves you out of your
## firing stance, "LEAVING A REVIEW" slows you, decoy summons steal your auto-aim, and at 33%
## she gets you the manager — a one-shot alpha-elite big add that buffs the staff around it,
## plus the Manager's own jam on loan. Combat-model exploit: you can never plant and fire.

const BOSS_ID := "karen"

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.KAREN_HP / GameConfig.BOSS_BASE_HP

func _build_phases() -> Array:
	var scream := { "radius": GameConfig.KAREN_SCREAM_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.KAREN_SCREAM_DAMAGE, "windup": GameConfig.SLAM_WINDUP,
		"shove_speed": GameConfig.KAREN_SCREAM_SHOVE_SPEED }
	var review := { "kind": "slow", "duration": GameConfig.KAREN_REVIEW_SLOW_DURATION,
		"factor": GameConfig.KAREN_REVIEW_SLOW_FACTOR, "windup": 0.8 }
	var decoys := { "count": GameConfig.KAREN_DECOY_COUNT, "decoy": true, "windup": 0.9 }
	var jam := { "kind": "jam", "duration": GameConfig.MANAGER_JAM_DURATION, "windup": 0.8 }
	return [
		{
			"at": 1.0, "cadence": 4.2, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.DEBUFF, "params": review },
			],
		},
		{
			"at": 0.66, "cadence": 3.6, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.SUMMON, "params": decoys },
				{ "scene": Patterns.DEBUFF, "params": review },
			],
		},
		{
			"at": 0.33, "cadence": 3.2, "speed_mult": GameConfig.KAREN_SPEED_MULT,
			"on_enter": _call_the_manager,
			"patterns": [
				{ "scene": Patterns.SCREAM, "params": scream },
				{ "scene": Patterns.DEBUFF, "params": jam },
				{ "scene": Patterns.SUMMON, "params": decoys },
			],
		},
	]

## P3 one-shot (phase on_enter fires exactly once): the line, then the guy. NOT in the phase's
## round-robin list — the manager arrives ONCE. hp_mult stacks with apply_elite's own
## ELITE_HP_MULT; "alpha" = speed/damage aura, so the manager literally buffs the staff.
func _call_the_manager() -> void:
	CombatText.callout(global_position + Vector2(0, -60), "GET ME THE MANAGER!", PixelTheme.ACCENT)
	var p = Patterns.SUMMON.instantiate()
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.setup(self, _target, { "count": 1, "hp_mult": GameConfig.KAREN_MANAGER_HP_MULT,
		"elite_kind": "alpha", "windup": 1.0 })

## Regalia drawn OVER the shared enemy sprite until real art loads (Manager-tie idiom):
## sunglasses band + C4 glints, and a handbag on her arm. Palette C1/C4 only.
func _draw() -> void:
	if _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-15, -18), Vector2(30, 8)), PixelTheme.DARK)          # sunglasses band
	draw_rect(Rect2(Vector2(-10, -15), Vector2(4, 2)), PixelTheme.ACCENT)         # left lens glint
	draw_rect(Rect2(Vector2(4, -15), Vector2(4, 2)), PixelTheme.ACCENT)           # right lens glint
	var bag := Rect2(Vector2(18, 4), Vector2(13, 11))
	draw_rect(bag, PixelTheme.ACCENT)                                             # handbag
	draw_rect(bag, PixelTheme.DARK, false, 2.0)
	draw_line(Vector2(20, 4), Vector2(28, -6), PixelTheme.DARK, 2.0)              # strap

class_name ShakeMath
## Pure trauma-based screen-shake math (Pack D: Stats + juice, v0.1.51). No Node or autoload
## dependency (only GameConfig, itself autoload-free) — CameraShake.gd (the actual Camera2D
## node, which DOES touch the SaveManager EFFECTS toggle) delegates to these two functions, so a
## headless probe can verify the math directly without dragging in SaveManager and hitting the
## "--script mode doesn't see project autoloads" compile trap.

## The trauma a Shockwave.blast() of `radius` should add — a true linear ramp from
## GameConfig.SHAKE_TRAUMA_BLAST_MIN (at radius 0) to SHAKE_TRAUMA_BLAST_MAX (at radius >=
## SHAKE_TRAUMA_BLAST_REF_RADIUS): every radius in between lands proportionally between the two
## endpoints, so the MIN/MAX consts tune the whole ramp — not just clamp thresholds that only
## bite at extreme radii.
static func trauma_for_radius(radius: float) -> float:
	var t := clampf(radius / GameConfig.SHAKE_TRAUMA_BLAST_REF_RADIUS, 0.0, 1.0)
	return lerpf(GameConfig.SHAKE_TRAUMA_BLAST_MIN, GameConfig.SHAKE_TRAUMA_BLAST_MAX, t)

## One decay step (trauma drains linearly at GameConfig.SHAKE_DECAY/sec, floored at 0).
static func decay(trauma: float, delta: float) -> float:
	return maxf(trauma - GameConfig.SHAKE_DECAY * delta, 0.0)

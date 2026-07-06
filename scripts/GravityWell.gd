class_name GravityWell
extends Node2D
## Black Friday (`onhit_gravity`): a capped (GameConfig.MAX_GRAVITY_WELLS = 1), no-damage pull
## field. Every HAZARD_TICK_INTERVAL (5 Hz — the same cadence HazardZone/Mine use) every enemy
## within radius gets a knockback impulse toward the well's center via the EXISTING knockback
## channel (Enemy.apply_knockback) — the same one bite-and-bounce and Concussive already use, so
## the existing KNOCKBACK_DECAY (900/s) turns these pulsed impulses into a smooth drag (Risks
## #11) instead of adding a second movement channel. Deals NO damage; it feeds the player's own
## AoE talents (novas, Septic Shock, Daisy Cutter). Self-frees after `duration` with a brief
## white-pop collapse. Visual: a darkening C1 void core with three rotating C2 indigo arcs.

const GROUP := "gravity_wells"
const COLLAPSE_TIME := 0.2   # seconds the white-pop collapse flash takes
const _CORE_COLOR := Color(0.02, 0.0, 0.05)   # near-C1 void — darkens as the well nears collapse

var _radius := 0.0
var _duration := 0.0
var _time_left := 0.0
var _tick := 0.0
var _collapsing := false
var _collapse_age := 0.0

func setup(duration: float, radius: float) -> void:
	_duration = duration
	_time_left = duration
	_radius = radius
	add_to_group(GROUP)

func _process(delta: float) -> void:
	if _collapsing:
		_collapse_age += delta
		if _collapse_age >= COLLAPSE_TIME:
			queue_free()
			return
		queue_redraw()
		return
	_tick += delta
	if _tick >= GameConfig.HAZARD_TICK_INTERVAL:
		_pull(_tick)
		_tick = 0.0
	_time_left -= delta
	if _time_left <= 0.0:
		_collapsing = true
		_collapse_age = 0.0
		# Leave the cap group the moment the pull ends (mirrors Mine._detonate's hygiene):
		# the 0.2s collapse pop is pure cosmetics and must not block a fresh well from spawning.
		remove_from_group(GROUP)
	queue_redraw()

## Pulls every enemy in radius toward the well's center — a knockback impulse, not a teleport, so
## it stacks correctly with any other live knockback source (Risks #11: verified against
## Enemy._physics_process, which sums every source into one `_knockback` vector before decaying
## it — a contact bite-bounce impulse (700 px/s) numerically dominates a single well tick (140
## px/s), so the bounce-out still wins point-blank; nothing here double-ticks contact damage,
## since GravityWell never calls take_damage at all).
func _pull(_dt: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var r2 := _radius * _radius
	for e in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not e.has_method("apply_knockback"):
			continue
		var node := e as Node2D
		var to_center := global_position - node.global_position
		var d2 := to_center.length_squared()
		if d2 > r2 or d2 < 1.0:
			continue
		e.apply_knockback(to_center.normalized() * GameConfig.GRAVITY_WELL_PULL_SPEED)

func _draw() -> void:
	if _collapsing:
		var a := 1.0 - clampf(_collapse_age / COLLAPSE_TIME, 0.0, 1.0)
		draw_circle(Vector2.ZERO, _radius * 0.3 * (2.0 - a), Color(1, 1, 1, a * 0.8))
		return
	var t := clampf(1.0 - _time_left / _duration, 0.0, 1.0) if _duration > 0.0 else 0.0
	draw_circle(Vector2.ZERO, _radius * 0.35, Color(_CORE_COLOR.r, _CORE_COLOR.g, _CORE_COLOR.b, 0.35 + 0.25 * t))
	var spin := Time.get_ticks_msec() / 1000.0 * TAU * 0.6
	for i in 3:
		var a0 := spin + i * (TAU / 3.0)
		draw_arc(Vector2.ZERO, _radius * lerpf(0.9, 0.5, t), a0, a0 + 1.6, 10,
			Color(Enemy.FROZEN_TINT.r, Enemy.FROZEN_TINT.g, Enemy.FROZEN_TINT.b, 0.7), 4.0, true)

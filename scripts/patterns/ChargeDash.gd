class_name ChargeDash
extends AttackPattern
## A telegraphed charge. Windup = a bright line + glyph toward the aim point (the player's
## position snapshotted at setup, same as every other pattern's `_aim_point`). On telegraph end
## the BOSS ITSELF dashes at high speed toward that point for `duration`s, dealing `damage` once
## if it gets within `hit_radius` of the player along the way. Dodge = step off the line during
## the windup, same convention as AimedBand.
##
## Drives the boss's own velocity + move_and_slide() for the dash window (sets `boss.charging`
## true so BossBase's built-in chase stands down — see BossBase._physics_process). The boss
## keeps its normal bit4 cover collision mask throughout, so move_and_slide naturally slides/
## stops the dash at solid cover exactly like the built-in chase does — no separate wall logic.
##
## TIMING: the dash movement runs in _physics_process, NOT the base class's _process/_active —
## move_and_slide() applies one fixed physics-tick of `velocity` per CALL, so stepping it from
## the render frame would scale dash distance with the display's refresh rate (~2x on a 120Hz
## phone). Matching how BossBase/Enemy/Player all move, every body step here is physics-timed;
## _active stays untouched (the base class only uses it for the post-windup redraw loop).

var _speed := GameConfig.CHARGE_SPEED
var _duration := GameConfig.CHARGE_DURATION
var _damage := GameConfig.CHARGE_DAMAGE
var _hit_radius := GameConfig.CHARGE_HIT_RADIUS
var _dir := Vector2.RIGHT
var _time_left := 0.0
var _hit_player := false
var _boss_body: CharacterBody2D

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_speed = float(cfg.get("speed", GameConfig.CHARGE_SPEED))
	_duration = float(cfg.get("duration", GameConfig.CHARGE_DURATION))
	_damage = float(cfg.get("damage", GameConfig.CHARGE_DAMAGE)) * _special_mult_of(b)
	_hit_radius = float(cfg.get("hit_radius", GameConfig.CHARGE_HIT_RADIUS))
	_boss_body = b as CharacterBody2D

func _on_telegraph_end() -> void:
	var to_aim := _aim_point - global_position
	_dir = to_aim.normalized() if to_aim.length() > 0.001 else Vector2.RIGHT
	_time_left = _duration
	if _boss_body != null and is_instance_valid(_boss_body):
		_boss_body.charging = true

## The dash itself: physics-timed body movement + hit-once check + the dash window countdown
## (see the TIMING note in the class docs). Inert until the telegraph ends (`_fired`).
func _physics_process(delta: float) -> void:
	if not _fired or _time_left <= 0.0:
		return
	if _boss_body == null or not is_instance_valid(_boss_body):
		queue_free()
		return
	_boss_body.velocity = _dir * _speed
	_boss_body.move_and_slide()
	global_position = _boss_body.global_position   # keep the telegraph/hit-check anchored to the boss
	_check_hit()
	_time_left -= delta
	if _time_left <= 0.0:
		_end_charge()

func _check_hit() -> void:
	if _hit_player or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= _hit_radius:
		_hit_player = true
		player.take_damage(_damage, null, true)

func _end_charge() -> void:
	if _boss_body != null and is_instance_valid(_boss_body):
		_boss_body.charging = false
	queue_free()

## Guards against the pattern outliving its boss (e.g. the boss dies mid-dash) — nothing else
## would free this node since it isn't a child of the boss.
func _exit_tree() -> void:
	if _boss_body != null and is_instance_valid(_boss_body):
		_boss_body.charging = false

func _draw() -> void:
	var d := _aim_point - global_position
	var dir := d.normalized() if d.length() > 0.001 else _dir
	if _windup > 0.0:
		draw_line(Vector2.ZERO, dir * 320.0, Color(1.0, 0.85, 0.2, 0.55), 5.0)
		draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.3, 0.1, 0.35))

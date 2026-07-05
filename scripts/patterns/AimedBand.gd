class_name AimedBand
extends AttackPattern
## A snapped beam. Telegraph = a thin bright line from the boss through the aim point; on
## telegraph end the beam becomes damaging for `active_time`. The player is hit once if
## within `thickness` of the segment. Dodge = step off the line during the windup.

var _length := 1100.0
var _thickness := 26.0
var _damage := 30.0
var _active_time := 0.15
var _time_left := 0.0
var _hit_player := false
var _dir := Vector2.RIGHT

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_length = float(cfg.get("length", GameConfig.AIMED_BAND_LENGTH))
	_thickness = float(cfg.get("thickness", GameConfig.AIMED_BAND_THICKNESS))
	_damage = float(cfg.get("damage", GameConfig.AIMED_BAND_DAMAGE)) * _special_mult_of(b)
	_active_time = float(cfg.get("active_time", GameConfig.AIMED_BAND_ACTIVE))

func _on_telegraph_end() -> void:
	var aim := _aim_point - global_position
	_dir = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	_time_left = _active_time

func _active(delta: float) -> void:
	_check_hit()
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _check_hit() -> void:
	if _hit_player or player == null or not is_instance_valid(player):
		return
	var to_player := player.global_position - global_position
	var proj := to_player.dot(_dir)
	if proj < 0.0 or proj > _length:
		return
	var perp := (to_player - _dir * proj).length()
	if perp <= _thickness:
		_hit_player = true
		player.take_damage(_damage)

func _draw() -> void:
	var aim := _aim_point - global_position
	var d := aim.normalized() if aim.length() > 0.001 else _dir
	if _windup > 0.0:
		draw_line(Vector2.ZERO, d * _length, Color(1.0, 0.85, 0.2, 0.5), 3.0)
		return
	draw_line(Vector2.ZERO, _dir * _length, Color(1.0, 0.4, 0.1, 0.9), _thickness)

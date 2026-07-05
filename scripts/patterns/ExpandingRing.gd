class_name ExpandingRing
extends AttackPattern
## A ground-slam shockwave (the SlamWave port). Telegraph = a faint filled circle at the
## full radius; then a drawn ring expands 0 -> radius; the player takes `damage` once if
## caught by the ring's leading band. Frees itself when fully expanded. Dash is the counter.

const BAND_THICKNESS := 28.0   # px width of the damaging leading edge (matches SlamWave)

var _radius := 0.0
var _max_radius := 220.0
var _expand_time := 0.5
var _damage := 35.0
var _hit_player := false

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_max_radius = float(cfg.get("radius", GameConfig.SLAM_RADIUS))
	_expand_time = float(cfg.get("expand_time", GameConfig.SLAM_EXPAND_TIME))
	_damage = float(cfg.get("damage", GameConfig.SLAM_DAMAGE)) * _special_mult_of(b)

func _active(delta: float) -> void:
	var grow_rate := _max_radius / _expand_time
	_radius += grow_rate * delta
	_check_hit()
	if _radius >= _max_radius:
		queue_free()

func _check_hit() -> void:
	if _hit_player or player == null or not is_instance_valid(player):
		return
	var dist := global_position.distance_to(player.global_position)
	if dist <= _radius and dist >= _radius - BAND_THICKNESS:
		_hit_player = true
		player.take_damage(_damage)

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, _max_radius, Color(1.0, 0.3, 0.1, 0.15))
		return
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.1, 0.85), 6.0)

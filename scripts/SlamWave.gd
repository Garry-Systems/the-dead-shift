class_name SlamWave
extends Node2D
## A boss ground-slam shockwave. During the wind-up it draws a faint danger zone so
## the player can react; then an expanding ring grows from 0 to SLAM_RADIUS over
## SLAM_EXPAND_TIME. The player takes SLAM_DAMAGE once if caught by the ring's leading
## edge. Frees itself when fully expanded. Dash is the natural counter.

const BAND_THICKNESS := 28.0          # px width of the damaging leading edge

var _radius := 0.0
var _windup := GameConfig.SLAM_WINDUP
var _hit_player := false
var _player: Player

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player

func _process(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		queue_redraw()
		return

	var grow_rate: float = GameConfig.SLAM_RADIUS / GameConfig.SLAM_EXPAND_TIME
	_radius += grow_rate * delta
	queue_redraw()
	_check_hit()

	if _radius >= GameConfig.SLAM_RADIUS:
		queue_free()

func _check_hit() -> void:
	if _hit_player or _player == null or not is_instance_valid(_player):
		return
	var dist := global_position.distance_to(_player.global_position)
	if dist <= _radius and dist >= _radius - BAND_THICKNESS:
		_hit_player = true
		_player.take_damage(GameConfig.SLAM_DAMAGE)

func _draw() -> void:
	if _windup > 0.0:
		# Telegraph: faint filled danger zone at the full radius.
		draw_circle(Vector2.ZERO, GameConfig.SLAM_RADIUS, Color(1.0, 0.3, 0.1, 0.15))
		return
	# Expanding ring.
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(1.0, 0.4, 0.1, 0.85), 6.0)

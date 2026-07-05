class_name ProjectileEmitter
extends AttackPattern
## Emits BossProjectile hazards. Telegraph = a charge glyph on the boss. On telegraph end
## it emits `count` projectiles in a `pattern` shape:
##   "aimed"  — one shot at the aim point
##   "fan"    — `count` shots spread across `arc`, centered on the aim point
##   "ring"   — `count` shots evenly around the full circle
##   "spiral" — `count` shots emitted over `active`s, each rotated by `spin` from the last

const PROJECTILE_SCENE := preload("res://scenes/BossProjectile.tscn")

var _count := 8
var _pattern := "ring"
var _arc := PI
var _speed := 200.0
var _damage := 0.0
var _spin := 0.4
var _active_time := 1.0
var _base_angle := 0.0
var _emitted := 0
var _emit_clock := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_count = int(cfg.get("count", 8))
	_pattern = String(cfg.get("pattern", "ring"))
	_arc = float(cfg.get("arc", PI))
	_speed = float(cfg.get("speed", GameConfig.BOSS_PROJECTILE_SPEED))
	_damage = float(cfg.get("damage", GameConfig.BOSS_PROJECTILE_DAMAGE)) * _special_mult_of(b)
	_spin = float(cfg.get("spin", 0.4))
	_active_time = float(cfg.get("active", 1.0))

func _on_telegraph_end() -> void:
	_base_angle = (_aim_point - global_position).angle()
	if _pattern == "spiral":
		return   # spiral emits over time in _active
	_emit_burst()

func _emit_burst() -> void:
	match _pattern:
		"aimed":
			_spawn(_base_angle)
		"fan":
			for i in _count:
				var t := 0.0 if _count <= 1 else float(i) / float(_count - 1)
				_spawn(_base_angle + lerpf(-_arc * 0.5, _arc * 0.5, t))
		_:   # "ring"
			for i in _count:
				_spawn(_base_angle + TAU * float(i) / float(maxi(_count, 1)))

func _spawn(angle: float) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position
	proj.setup(Vector2.from_angle(angle), _speed, _damage)

func _active(delta: float) -> void:
	if _pattern != "spiral":
		queue_free()   # burst shapes are one-shot
		return
	_emit_clock -= delta
	if _emit_clock <= 0.0 and _emitted < _count:
		_emit_clock = _active_time / float(maxi(_count, 1))
		_spawn(_base_angle + _spin * float(_emitted))
		_emitted += 1
	if _emitted >= _count:
		queue_free()

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.6, 0.1, 0.4))

class_name ZoneFill
extends AttackPattern
## An acid/fire puddle. Telegraph = a filled circle at a target point ("boss" = where it
## spawned, "player" = the aim point, plus an optional `offset`). On telegraph end it becomes
## a damaging zone for `duration`, ticking `dps` to the player while inside. Denies the
## "stand still and fire" spots the player relies on.

var _radius := 90.0
var _dps := 18.0
var _duration := 4.0
var _time_left := 0.0
var _armed := false

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_radius = float(cfg.get("radius", GameConfig.ZONE_DEFAULT_RADIUS))
	_dps = float(cfg.get("dps", GameConfig.ZONE_DEFAULT_DPS))
	_duration = float(cfg.get("duration", GameConfig.ZONE_DEFAULT_DURATION))
	var at := String(cfg.get("at", "boss"))
	if at == "player":
		global_position = _aim_point
	if cfg.has("offset"):
		global_position += cfg["offset"]

func _on_telegraph_end() -> void:
	_armed = true
	_time_left = _duration

func _active(delta: float) -> void:
	if not _armed:
		return
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= _radius:
			player.take_damage(_dps * delta)
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	if _windup > 0.0:
		draw_circle(Vector2.ZERO, _radius, Color(0.4, 1.0, 0.2, 0.18))
		return
	draw_circle(Vector2.ZERO, _radius, Color(0.4, 0.9, 0.2, 0.35))

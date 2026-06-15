class_name DebuffApplier
extends AttackPattern
## Attacks the control scheme. Repositions onto the player every frame so its visuals
## follow them. Telegraph = a colored ring around the player. On telegraph end it applies a
## debuff for `duration`s: "jam" -> player.apply_fire_lock (no firing even while still),
## "slow" -> player.apply_slow. Keeps a pulsing aura (red = jam, blue = slow) while active.

var _kind := "jam"
var _duration := 2.0
var _factor := 0.5
var _time_left := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_kind = String(cfg.get("kind", "jam"))
	_duration = float(cfg.get("duration", GameConfig.DEBUFF_JAM_DURATION))
	_factor = float(cfg.get("factor", GameConfig.DEBUFF_SLOW_FACTOR))

func _process(delta: float) -> void:
	if player != null and is_instance_valid(player):
		global_position = player.global_position   # aura/telegraph follows the player
	super._process(delta)

func _on_telegraph_end() -> void:
	_time_left = _duration
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	if _kind == "slow":
		player.apply_slow(_factor, _duration)
	else:
		player.apply_fire_lock(_duration)

func _active(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _draw() -> void:
	var col := Color(1.0, 0.2, 0.2, 0.5) if _kind == "jam" else Color(0.3, 0.5, 1.0, 0.5)
	if _windup > 0.0:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 32, col, 3.0)
		return
	draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 32, col, 5.0)

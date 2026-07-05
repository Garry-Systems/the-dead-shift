class_name HazardZone
extends AttackPattern
## A lingering area-denial pool (fire/acid/electric) spawned by a destructible on death.
## The both-sides, throttled cousin of ZoneFill: damages enemies AND the player on a ~5 Hz
## tick (not every frame), refreshes slow (acid) / stun (electric), and arcs cyan bolts for
## electric. Built on AttackPattern for the telegraph -> active -> free lifecycle (ZoneFill is
## left untouched so the boss acid nest is unaffected). Draws one fading circle in the family's
## sanctioned exception color. Self-frees after `duration`.

var _color := Hazards.ORANGE
var _dps := 0.0
var _radius := 0.0
var _duration := 0.0
var _slow := 0.0
var _slow_dur := 0.0
var _stun := 0.0
var _chain := 0
var _drift := 0.0
var _drift_dir := Vector2.ZERO
var _armed := false
var _time_left := 0.0
var _tick := 0.0
var _hurts_player := true

## Configure from a Hazards.stats_for() dict. Caller sets global_position + add_child FIRST.
func configure_hazard(cfg: Dictionary) -> void:
	_color = cfg.get("color", Hazards.ORANGE)
	_dps = float(cfg.get("dps", 0.0))
	_radius = float(cfg.get("radius", 100.0))
	_duration = float(cfg.get("duration", 3.0))
	_slow = float(cfg.get("slow", 0.0))
	_slow_dur = float(cfg.get("slow_dur", 0.0))
	_stun = float(cfg.get("stun", 0.0))
	_chain = int(cfg.get("chain", 0))
	_drift = float(cfg.get("drift", 0.0))
	_hurts_player = bool(cfg.get("hurts_player", true))
	add_to_group("hazard_zones")
	if not _hurts_player:
		add_to_group("player_pools")   # player-placed pool (Acid Cannon); capped separately, see Bullet._detonate
	setup(null, null, {})                  # AttackPattern grabs the player from the group
	_windup = GameConfig.HAZARD_WINDUP     # short arm, bypassing the boss PATTERN_WINDUP clamp
	var ang := randf_range(0.0, TAU)
	_drift_dir = Vector2(cos(ang), sin(ang))

func _on_telegraph_end() -> void:
	_armed = true
	_time_left = _duration

func _active(delta: float) -> void:
	if not _armed:
		return
	if _drift > 0.0:
		global_position += _drift_dir * _drift * delta
	_tick += delta
	if _tick >= GameConfig.HAZARD_TICK_INTERVAL:
		_apply(_tick)
		_tick = 0.0
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()

func _apply(dt: float) -> void:
	var r2 := _radius * _radius
	var tree := get_tree()
	var enemies := tree.get_nodes_in_group("enemies")
	for e in enemies:
		if e == null or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_squared_to(global_position) > r2:
			continue
		e.take_damage(_dps * dt * GameConfig.ENEMY_HAZARD_DMG_MULT)
		if not is_instance_valid(e):
			continue
		if _slow > 0.0 and e.has_method("apply_slow"):
			e.apply_slow(_slow, _slow_dur)
		if _stun > 0.0 and e.has_method("apply_freeze"):
			e.apply_freeze(_stun)
	if _chain > 0:
		_zap_arc(enemies)
	if _hurts_player:
		var player := tree.get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			if (player as Node2D).global_position.distance_squared_to(global_position) <= r2:
				player.take_damage(_dps * dt * GameConfig.PLAYER_HAZARD_DMG_MULT)
				if _slow > 0.0 and player.has_method("apply_slow"):
					player.apply_slow(_slow, _slow_dur)

## Cosmetic cyan arcs to a few in-radius enemies (electric flavor; damage/stun already applied).
func _zap_arc(enemies: Array) -> void:
	var points: Array = [global_position]
	var r2 := _radius * _radius
	for e in enemies:
		if points.size() > _chain:
			break
		if e == null or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_squared_to(global_position) <= r2:
			points.append((e as Node2D).global_position)
	if points.size() >= 2:
		var bolt := Lightning.new()
		bolt.points = points
		get_tree().current_scene.add_child(bolt)

func _draw() -> void:
	if not _armed:
		draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.12))
		return
	var a := clampf(_time_left / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	draw_circle(Vector2.ZERO, _radius, Color(_color.r, _color.g, _color.b, 0.30 * a))

class_name Mine
extends Node2D
## Parting Gift (`onkill_mine`): a small pooled proximity mine dropped on a kill. Capped at
## GameConfig.MAX_PLAYER_MINES (oldest evicted — the same idiom as LeechMote / HazardZone's
## player_pools). Arms after GameConfig.MINE_ARM_DELAY, then a 5 Hz proximity tick (the same
## HAZARD_TICK_INTERVAL cadence HazardZone/GravityWell use) detonates the instant an enemy comes
## within GameConfig.MINE_PROXIMITY_RADIUS — via the proc-free TalentEngine.detonate() (raw area
## damage, no talent chaining — Risks #6) plus a budget-gated orange ring. Self-frees after
## GameConfig.MINE_TTL if nothing ever triggers it. Dark (unarmed) disc; blinks orange at
## GameConfig.MINE_BLINK_HZ once armed — the "live" tell.

const GROUP := "player_mines"

var _dmg := 0.0
var _radius := 0.0
var _armed := false
var _arm_timer := 0.0
var _tick := 0.0
var _ttl := 0.0
var _detonated := false

## Spawns a (capped) mine at `pos`. Caller does NOT add_child first — spawn() owns placement,
## like LeechMote.spawn().
static func spawn(pos: Vector2, dmg: float, radius: float, tree) -> void:
	if tree == null:
		return
	_evict_oldest(tree)
	var mine := Mine.new()
	mine._dmg = dmg
	mine._radius = radius
	mine.add_to_group(GROUP)
	tree.current_scene.add_child(mine)
	mine.global_position = pos

## Enforces MAX_PLAYER_MINES: frees the OLDEST live mine (group order == spawn order) before a
## new one spawns — same eviction shape as LeechMote._evict_oldest / HazardZone.cap_player_pools.
static func _evict_oldest(tree) -> void:
	var mines: Array = tree.get_nodes_in_group(GROUP)
	if mines.size() >= GameConfig.MAX_PLAYER_MINES:
		var oldest = mines[0]
		if is_instance_valid(oldest):
			oldest.remove_from_group(GROUP)
			oldest.queue_free()

func _ready() -> void:
	_arm_timer = GameConfig.MINE_ARM_DELAY
	_ttl = GameConfig.MINE_TTL

func _process(delta: float) -> void:
	if _detonated:
		return
	if not _armed:
		_arm_timer -= delta
		if _arm_timer <= 0.0:
			_armed = true
		queue_redraw()
		return
	_ttl -= delta
	if _ttl <= 0.0:
		queue_free()
		return
	_tick += delta
	if _tick >= GameConfig.HAZARD_TICK_INTERVAL:
		_tick = 0.0
		_check_proximity()
	queue_redraw()

func _check_proximity() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var r2 := GameConfig.MINE_PROXIMITY_RADIUS * GameConfig.MINE_PROXIMITY_RADIUS
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e as Node2D).global_position.distance_squared_to(global_position) <= r2:
			_detonate()
			return

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	remove_from_group(GROUP)
	var tree := get_tree()
	TalentEngine.detonate(global_position, _dmg, _radius, tree)
	TalentEngine.spawn_ring(global_position, _radius, Hazards.ORANGE, tree)
	queue_free()

func _draw() -> void:
	if not _armed:
		draw_circle(Vector2.ZERO, GameConfig.MINE_RADIUS_PX, Color(PixelTheme.TEXT_DIM.r, PixelTheme.TEXT_DIM.g, PixelTheme.TEXT_DIM.b, 0.6))
		return
	var blink := sin(Time.get_ticks_msec() / 1000.0 * TAU * GameConfig.MINE_BLINK_HZ) * 0.5 + 0.5
	var col := PixelTheme.TEXT_DIM.lerp(Hazards.ORANGE, blink)
	draw_circle(Vector2.ZERO, GameConfig.MINE_RADIUS_PX, col)

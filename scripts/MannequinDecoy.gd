class_name MannequinDecoy
extends Node2D
## Coworkers (T3): the decoy the Floor Mannequin companion places at the player's position.
## Draws enemy aggro by re-taunting (Enemy.taunt, T2) every TICK_INTERVAL any Enemy within
## `taunt_radius` — the re-tick is what keeps aggro locked on (taunt_time always outlives
## TICK_INTERVAL, so there's never a gap), soaks contact damage on its own HP pool via
## `take_damage` (the exact signature Enemy._touching_taunt_node's has_method-guarded call
## site already expects), and shatters + frees when its HP hits zero.
##
## `e is Enemy` (not a has_method guard) is the correct filter for the taunt call itself —
## Enemy.taunt()'s own doc comment states bosses are immune "for free" because BossBase never
## defines/calls taunt() (BossBase != Enemy, siblings under CharacterBody2D, not a hierarchy),
## so a static type check both excludes bosses AND statically guarantees the method exists —
## no has_method call needed for THAT particular call. take_damage below is still has_method-
## guarded at ITS call site (Enemy.gd), same as every other status effect in this codebase.

const GROUP := "coworker_decoys"
const TICK_INTERVAL := 0.5
const RADIUS_PX := 22.0
const SHATTER_TIME := 0.18
const COLOR := Color(0.239, 0.0, 0.6)   # C2 indigo (matches the Companion mannequin dot)

var taunt_radius := 0.0
var taunt_time := 0.0

var _health: Health
var _tick := 0.0
var _dying := false
var _shatter_t := 0.0

## Spawns a decoy at `pos`. Cap 1 alive: any existing decoy is freed FIRST (mirrors Mine.gd's
## evict-oldest idiom, cap size 1 instead of MAX_PLAYER_MINES). Caller does NOT add_child
## first — spawn() owns placement, like Mine.spawn()/LeechMote.spawn().
static func spawn(pos: Vector2, hp: float, radius: float, taunt_dur: float, tree) -> void:
	if tree == null:
		return
	_evict_existing(tree)
	var d := MannequinDecoy.new()
	d.taunt_radius = radius
	d.taunt_time = taunt_dur
	d._health = Health.new(hp)
	d.add_to_group(GROUP)
	tree.current_scene.add_child(d)
	d.global_position = pos

static func _evict_existing(tree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(n):
			n.remove_from_group(GROUP)
			n.queue_free()

func _physics_process(delta: float) -> void:
	if _dying:
		_shatter_t -= delta
		queue_redraw()
		if _shatter_t <= 0.0:
			queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK_INTERVAL
		_retaunt()

func _retaunt() -> void:
	var r2 := taunt_radius * taunt_radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and is_instance_valid(e) and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
			(e as Enemy).taunt(self, taunt_time)

func take_damage(amount: float) -> void:
	if _dying or _health == null:
		return
	_health.take_damage(amount)
	queue_redraw()
	if _health.is_dead():
		_die()

func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func _die() -> void:
	_dying = true
	_shatter_t = SHATTER_TIME
	remove_from_group(GROUP)
	queue_redraw()

func _draw() -> void:
	if _dying:
		# Small shatter: a few outward-radiating cracks, fading with _shatter_t.
		var a := clampf(_shatter_t / SHATTER_TIME, 0.0, 1.0)
		var col := Color(COLOR.r, COLOR.g, COLOR.b, a)
		for i in 6:
			var ang := TAU * float(i) / 6.0
			var reach := RADIUS_PX * (1.0 + (1.0 - a) * 1.5)
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(ang) * reach, col, 2.0)
		return
	draw_circle(Vector2.ZERO, RADIUS_PX, COLOR)
	draw_arc(Vector2.ZERO, RADIUS_PX, 0.0, TAU, 20, PixelTheme.DARK, 2.0)

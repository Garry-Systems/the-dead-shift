class_name Destructible
extends StaticBody2D
## A scatterable obstacle, built from an Obstacles row by ObstacleField (no scene/art —
## it draws itself). Solid cover (car/rubble) blocks movement + bullets + line of sight;
## non-solid props (barrel/drum/transformer/crate) are walk-through and take bullet damage.
## On death it spawns its hazard zone (barrels also burst via Shockwave + chain neighbors)
## or drops loot.

const _XP_GEM_SCENE := preload("res://scenes/XpGem.tscn")

var kind := "loot"
var shape := "circle"
var size := 18.0
var solid := false
var hp := 25.0
var hazard_id := ""
var loot := ""
var gem_count := 0
var color := Color(0.549, 0.522, 0.451)

var _health: Health
var _detonating := false
var _fuse := -1.0          # >= 0 = chain fuse counting down to detonation
var _hit_flash := 0.0

# Global per-frame chain-detonation budget (CHAIN_MAX_PER_TICK) so a dense barrel farm
# ripples across frames instead of detonating a whole wavefront on one frame.
static var _det_frame := -1
static var _det_count := 0

## Bake a row's fields. Call BEFORE add_child (so _ready can build the shape + layer).
func configure(row: Dictionary) -> void:
	kind = String(row["kind"])
	shape = String(row["shape"])
	size = float(row["size"])
	solid = bool(row["solid"])
	hp = float(row["hp"])
	hazard_id = String(row["hazard_id"])
	loot = String(row["loot"])
	gem_count = int(row["gem_count"])
	color = row.get("color", color)

func _ready() -> void:
	if hp >= 0.0:
		_health = Health.new(hp)
	_build_shape()
	add_to_group("destructibles")
	collision_layer = 0
	if solid:
		set_collision_layer_value(GameConfig.COVER_LAYER_BIT, true)
		add_to_group("cover")
	else:
		set_collision_layer_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)
	queue_redraw()

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	if shape == "rect":
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size * 2.0, size * 2.0)
		cs.shape = rect
	else:
		var circ := CircleShape2D.new()
		circ.radius = size
		cs.shape = circ
	add_child(cs)

func is_fusing() -> bool:
	return _fuse >= 0.0

func take_damage(amount: float) -> void:
	if hp < 0.0 or _detonating or _health == null:   # indestructible or already dying
		return
	_health.take_damage(amount)
	_hit_flash = 0.08
	queue_redraw()
	if _health.is_dead():
		_die()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			queue_redraw()
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			if not _claim_detonation_slot():
				_fuse = 0.001    # per-frame budget full — retry next frame (ripple)
				return
			_fuse = -1.0
			_die()

## Per-frame chain budget: at most CHAIN_MAX_PER_TICK fused barrels detonate per frame.
static func _claim_detonation_slot() -> bool:
	var frame := Engine.get_process_frames()
	if _det_frame != frame:
		_det_frame = frame
		_det_count = 0
	if _det_count >= GameConfig.CHAIN_MAX_PER_TICK:
		return false
	_det_count += 1
	return true

## A neighboring barrel lights this one after a short delay (ripple, not recursion).
func light_fuse() -> void:
	if _detonating or _fuse >= 0.0 or hazard_id != "fire":
		return
	_fuse = GameConfig.CHAIN_DELAY

func _die() -> void:
	if _detonating:
		return
	_detonating = true
	var tree := get_tree()
	# Barrel: instant Shockwave burst + chain-fuse nearby barrels.
	if hazard_id == "fire":
		var sw := Shockwave.new()
		tree.current_scene.add_child(sw)
		sw.global_position = global_position
		sw.blast(GameConfig.BARREL_BURST_RADIUS, GameConfig.BARREL_BURST_DAMAGE, GameConfig.BARREL_BURST_FORCE, null, null)
		var cr2 := GameConfig.BARREL_CHAIN_RADIUS * GameConfig.BARREL_CHAIN_RADIUS
		for d in tree.get_nodes_in_group("destructibles"):
			if d == self or not is_instance_valid(d):
				continue
			if (d as Node2D).global_position.distance_squared_to(global_position) <= cr2 and d.has_method("light_fuse"):
				d.light_fuse()
	# Lingering hazard zone (capped).
	if hazard_id != "" and tree.get_nodes_in_group("hazard_zones").size() < GameConfig.MAX_HAZARD_ZONES:
		var cfg := Hazards.stats_for(hazard_id)
		if not cfg.is_empty():
			var hz := HazardZone.new()
			tree.current_scene.add_child(hz)
			hz.global_position = global_position
			hz.configure_hazard(cfg)
	# Loot.
	if loot == "gems":
		_drop_loot(gem_count)
	queue_free()

func _drop_loot(n: int) -> void:
	var tree := get_tree()
	if _XP_GEM_SCENE != null:
		for i in n:
			var gem = _XP_GEM_SCENE.instantiate()
			tree.current_scene.add_child(gem)
			gem.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	RunStats.add_coins(GameConfig.CRATE_COIN_REWARD)

func _draw() -> void:
	var c := Color(1, 1, 1, 1) if _hit_flash > 0.0 else color
	var outline := Color(0.04, 0.0, 0.10)   # C1 void
	if shape == "rect":
		var r := Rect2(Vector2(-size, -size), Vector2(size * 2.0, size * 2.0))
		draw_rect(r, c)
		draw_rect(r, outline, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, size, c)
		draw_arc(Vector2.ZERO, size, 0.0, TAU, 24, outline, 2.0)

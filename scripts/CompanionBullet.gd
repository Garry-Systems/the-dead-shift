class_name CompanionBullet
extends Node2D
## Coworkers (T3): a lean, talent-free projectile for the Delivery Drone companion. Flies
## straight and deals raw `take_damage` to the first "enemies"-group member it comes within
## HIT_RADIUS of — a per-frame distance check (mirrors Mine.gd's `_check_proximity` proximity-
## tick idiom), not an Area2D/CollisionShape2D pair. Deliberately NOT `Bullet.gd`: that class
## is built around Gun's talent payload (crit rolls via TalentEngine.roll_damage, on-hit procs,
## pierce/ricochet, cover/destructible interaction) and is spawned from a PackedScene
## (`scenes/Bullet.tscn`) via `Gun._spawn_bullet` — none of that machinery is wanted here
## (Global Constraints: DRONE damage is always raw, no talents, no crit, ever), and stretching
## Bullet/Gun's Gun-only contract onto a non-Gun caller (talent_player would stay null) would
## be more coupling than this ~40-line mover needs. Still carries the drone's rolled trait id
## so CHILLING (slow) / PINNING (chance-pin) — which "ride the attack" on ANY companion hit,
## not just the cat's — still land here too.

const HIT_RADIUS := 14.0
const COLOR := Color(0.878, 0.898, 1.0)   # C4 lavender

var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := 0.0
var max_travel := 400.0
var trait_id := ""

var _traveled := 0.0

func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	_traveled += step.length()
	if _traveled >= max_travel:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var node := e as Node2D
		if global_position.distance_to(node.global_position) <= HIT_RADIUS:
			_hit(node)
			return
	queue_redraw()

func _hit(node: Node2D) -> void:
	if node.has_method("take_damage"):
		node.take_damage(damage)
	if trait_id == "chilling" and node.has_method("apply_slow"):
		node.apply_slow(GameConfig.COWORKER_TRAIT_CHILLING_SLOW, GameConfig.COWORKER_TRAIT_CHILLING_DUR)
	elif trait_id == "pinning" and node.has_method("apply_pin") and randf() < GameConfig.COWORKER_TRAIT_PINNING_CHANCE:
		node.apply_pin(GameConfig.COWORKER_CAT_PIN)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, COLOR)

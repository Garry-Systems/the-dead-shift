extends Node2D
## A boss-side hazard projectile. Travels in a direction, distance-checks the player each
## frame, deals flat `damage` once on contact, then frees. Also frees on lifetime. It is
## NOT in the "enemies" group (the player's bullets must not destroy it). Set up by
## ProjectileEmitter via setup().

const HIT_RADIUS := 22.0   # px contact radius against the player

var direction := Vector2.RIGHT
var speed := GameConfig.BOSS_PROJECTILE_SPEED
var damage := GameConfig.BOSS_PROJECTILE_DAMAGE

var _player: Node2D
var _life := 0.0

## Called by ProjectileEmitter right after add_child + positioning.
func setup(dir: Vector2, spd: float, dmg: float) -> void:
	direction = dir.normalized()
	speed = spd
	damage = dmg

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BOSS_PROJECTILE_LIFETIME:
		queue_free()
		return
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= HIT_RADIUS:
			_player.take_damage(damage)
			queue_free()

func _draw() -> void:
	# C3 (threat) hazard dot. Distinct from the player's C4 bullets.
	draw_circle(Vector2.ZERO, 8.0, Color(0.549, 0.522, 0.451, 1.0))

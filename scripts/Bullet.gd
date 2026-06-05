extends Area2D
## A projectile: flies in a fixed direction, damages the first zombie it overlaps,
## and despawns after a lifetime.

var direction := Vector2.RIGHT
var _life := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * GameConfig.BULLET_SPEED * delta
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("zombies"):
		body.take_damage(GameConfig.BULLET_DAMAGE)
		queue_free()

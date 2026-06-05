extends Area2D
## A projectile: flies in a fixed direction, damages the first zombie it overlaps,
## and despawns after a lifetime. Speed and damage are set by the gun that fires it
## (so gun upgrades carry through to the bullet); they default to the config values.

var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := GameConfig.BULLET_DAMAGE
var _life := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()

func _on_body_entered(body) -> void:
	if body.is_in_group("zombies"):
		body.take_damage(damage)
		queue_free()

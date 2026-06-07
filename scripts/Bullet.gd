extends Area2D
## A projectile: flies in a direction, damages enemies it overlaps, and despawns
## after a lifetime. Speed/damage and the talent payload (pierce, ricochet, burn)
## are set by the gun that fires it, so weapon talents carry through to the bullet.

var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var damage := GameConfig.BULLET_DAMAGE

# Talent payload (set by Gun._spawn_bullet; 0/false = vanilla bullet).
var pierce_count := 0          # extra enemies the bullet passes through
var ricochet_count := 0        # times it redirects to the next nearest enemy
var incendiary := false        # ignites enemies it hits
var burn_dps := 0.0
var burn_duration := 0.0

var _life := 0.0
var _hit: Array = []           # enemies already damaged (so pierce/ricochet don't re-hit)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life += delta
	if _life >= GameConfig.BULLET_LIFETIME:
		queue_free()

func _on_body_entered(body) -> void:
	if not body.is_in_group("enemies") or body in _hit:
		return

	_hit.append(body)
	body.take_damage(damage)
	if is_instance_valid(body):
		if body.has_method("flash_hit"):
			body.flash_hit()
		if incendiary:
			body.ignite(burn_dps, burn_duration)

	# Ricochet redirects toward a fresh target; pierce keeps flying straight.
	if ricochet_count > 0:
		ricochet_count -= 1
		var next := _nearest_unhit_enemy()
		if next != null:
			direction = (next.global_position - global_position).normalized()
		return
	if pierce_count > 0:
		pierce_count -= 1
		return
	queue_free()

func _nearest_unhit_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for z in get_tree().get_nodes_in_group("enemies"):
		if z in _hit:
			continue
		var node := z as Node2D
		var d := global_position.distance_squared_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best

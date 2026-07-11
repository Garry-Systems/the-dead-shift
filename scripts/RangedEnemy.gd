class_name RangedEnemy
extends Enemy
## A ranged "spitter": holds at a preferred distance and fires projectiles at the player on
## a cooldown. Inherits all of Enemy's health/flash/status/gem behavior; only the movement
## (keep-distance) and the fire action differ. Reuses the boss-side BossProjectile hazard.

const PROJECTILE_SCENE := preload("res://scenes/BossProjectile.tscn")

var _fire_cd := 0.0

func _ready() -> void:
	super._ready()
	# Stagger the first shot so a group of spitters doesn't volley in unison.
	_fire_cd = randf_range(0.0, GameConfig.RANGED_FIRE_INTERVAL)

## Hold a standoff distance: approach if too far, back off if too close, else hold and shoot.
func _desired_velocity() -> Vector2:
	var to_player := _target.global_position - global_position
	var dist := to_player.length()
	if dist < 0.001:
		return Vector2.ZERO
	var dir := to_player / dist
	var pref := GameConfig.RANGED_PREFERRED_DIST
	if dist > pref * 1.1:
		return dir * move_speed
	if dist < pref * 0.9:
		return -dir * move_speed
	return Vector2.ZERO

## Fire a projectile at the player when off cooldown and within range.
## ONE OF THEM: hold fire entirely while ghosted — top early-return, before the cooldown even
## ticks, so the cooldown resumes exactly where it left off once the window ends (no free volley
## banked up from 4s of held fire).
func _act(delta: float) -> void:
	if _target_ghosted():
		return
	_fire_cd -= delta
	if _fire_cd > 0.0:
		return
	if _target == null or not is_instance_valid(_target):
		return
	if global_position.distance_to(_target.global_position) > GameConfig.RANGED_FIRE_RANGE:
		return
	_fire_cd = GameConfig.RANGED_FIRE_INTERVAL
	var dir := (_target.global_position - global_position).normalized()
	var proj = PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position
	get_tree().current_scene.add_child(proj)
	proj.setup(dir, GameConfig.RANGED_PROJECTILE_SPEED, GameConfig.RANGED_PROJECTILE_DAMAGE * _special_mult * elite_damage_mult())

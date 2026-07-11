class_name ExploderEnemy
extends Enemy
## A volatile rusher: sprints at the player and detonates on contact OR when killed,
## dealing a single area hit instead of touch damage-over-time. Punishes clumping and
## standing still. Inherits all of Enemy's health / flash / status / gem behavior.
## Blast visual reuses the muzzle-flash sprite (no dedicated art in v1).

const BLAST_FX := preload("res://art/muzzle.png")

var _detonated := false

## Run the base enemy step (movement, debuffs, contact DPS — which is 0 here per the registry's
## dmg_mult, so Enemy's own contact-bite gate is a no-op for this type either way), then detonate
## if we're touching the player. This is Exploder's OWN proximity trigger, separate from the base
## Enemy contact-bite block — ONE OF THEM: gate it the same way (`not _target_ghosted()`), or a
## ghosted player standing still could still eat a "no chase, no contact damage" blast just by
## being walked into. Kill-triggered detonation (take_damage() below) is intentionally left
## UNGATED — that's a death side-effect of a bullet the player already fired, not the enemy
## targeting the player, so ghost has nothing to suppress there (see task-6-report.md).
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(self):
		return
	if not _detonated and not _target_ghosted() and _touching_player():
		_detonate()

## Killed by a bullet/DoT -> still detonate (drops its gem via super first).
func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if not _detonated and _health != null and _health.is_dead():
		_detonate()

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	if _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) <= GameConfig.EXPLODER_BLAST_RADIUS:
			_target.take_damage(GameConfig.EXPLODER_BLAST_DAMAGE * _special_mult)
	_spawn_blast_fx()
	queue_free()

## A brief expanding, fading burst at the detonation point (independent of this freed node).
func _spawn_blast_fx() -> void:
	var fx := Sprite2D.new()
	fx.texture = BLAST_FX
	fx.global_position = global_position
	fx.z_index = 2
	get_tree().current_scene.add_child(fx)
	var full := GameConfig.EXPLODER_BLAST_RADIUS / maxf(float(BLAST_FX.get_width()) * 0.5, 1.0)
	fx.scale = Vector2(full * 0.3, full * 0.3)
	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(fx, "scale", Vector2(full, full), 0.25)
	tw.tween_property(fx, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(fx.queue_free)

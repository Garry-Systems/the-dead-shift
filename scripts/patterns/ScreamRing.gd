class_name ScreamRing
extends ExpandingRing
## THE KAREN's scream nova. Identical telegraph/expand/damage-once to the parent ground slam —
## the parent's _check_hit already applies damage AND the boss-slam camera shake — so this
## subclass ONLY adds the knockback: a newly-hit player is shoved straight away from ring
## center via Player.apply_shove (decaying impulse; a dashing player is immune by design).

var _shove_speed := GameConfig.KAREN_SCREAM_SHOVE_SPEED

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_shove_speed = float(cfg.get("shove_speed", GameConfig.KAREN_SCREAM_SHOVE_SPEED))

func _check_hit() -> void:
	var was_hit := _hit_player
	super._check_hit()
	if _hit_player and not was_hit and player != null and is_instance_valid(player) and player.has_method("apply_shove"):
		var away := player.global_position - global_position
		var dir := away.normalized() if away.length() > 0.001 else Vector2.RIGHT
		player.apply_shove(dir * _shove_speed)

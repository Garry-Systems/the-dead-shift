class_name TrailDash
extends ChargeDash
## THE TANKER's leaking charge. The parent runs the whole telegraph/dash/hit protocol; this
## subclass drops a fire HazardZone every `spacing` px of dash travel (puddle first — the
## pool's windup IS the ignite delay — then flame), keeps the live-pool count under
## TANKER_TRAIL_MAX via drop-oldest on its own group, and optionally chains a second dash
## (`chain`: JACKKNIFE) that re-aims at the player's CURRENT position after a short
## re-telegraph. `charging` stays true across the whole chain so BossBase's chase never
## grabs the body between dashes; ChargeDash._exit_tree still resets it if the boss dies
## mid-chain.

const FUEL_GROUP := "tanker_fuel"

var _spacing := GameConfig.TANKER_TRAIL_SPACING
var _chain := 0
var _dist_acc := 0.0

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_spacing = maxf(float(cfg.get("spacing", GameConfig.TANKER_TRAIL_SPACING)), 1.0)   # floor at 1px — cfg spacing <= 0 must not hang the pool-drop while-loop
	_chain = int(cfg.get("chain", 0))

func _on_telegraph_end() -> void:
	super._on_telegraph_end()
	_dist_acc = 0.0

func _physics_process(delta: float) -> void:
	var before := global_position
	super._physics_process(delta)   # parent moves the boss and re-anchors global_position to it
	if not _fired:
		return
	_dist_acc += global_position.distance_to(before)
	while _dist_acc >= _spacing:
		_dist_acc -= _spacing
		_drop_pool()

## One fuel pool at the current position, capped drop-oldest on FUEL_GROUP. Pools also join
## the generic "hazard_zones" group inside configure_hazard — deliberately NOT checked against
## MAX_HAZARD_ZONES here: a boss move must not be starved by ambient barrel fires.
func _drop_pool() -> void:
	var pools := get_tree().get_nodes_in_group(FUEL_GROUP)
	if pools.size() >= GameConfig.TANKER_TRAIL_MAX:
		var oldest = pools[0]   # group order == spawn order
		if is_instance_valid(oldest):
			oldest.remove_from_group(FUEL_GROUP)   # leave immediately so a same-frame recount stays accurate
			oldest.queue_free()
	var hz := HazardZone.new()
	get_tree().current_scene.add_child(hz)
	hz.global_position = global_position
	hz.configure_hazard({ "color": Hazards.ORANGE, "dps": GameConfig.TANKER_POOL_DPS * _special_mult_of(boss),
		"radius": GameConfig.TANKER_POOL_RADIUS, "duration": GameConfig.TANKER_POOL_DURATION,
		"windup": GameConfig.TANKER_IGNITE_DELAY, "puddle": true, "hurts_player": true, "immune": boss })
	hz.add_to_group(FUEL_GROUP)

## JACKKNIFE: instead of freeing after dash 1, re-telegraph briefly and dash again at the
## player's CURRENT position. Each chained dash gets its own hit-once budget.
func _end_charge() -> void:
	if _chain > 0 and _boss_body != null and is_instance_valid(_boss_body):
		_chain -= 1
		_hit_player = false
		_fired = false
		_windup = GameConfig.TANKER_JACKKNIFE_RETELEGRAPH
		if player != null and is_instance_valid(player):
			_aim_point = player.global_position
		queue_redraw()
		return   # _boss_body.charging stays true through the re-telegraph
	super._end_charge()

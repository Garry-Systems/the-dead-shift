class_name AttackPattern
extends Node2D
## Base class for boss attack patterns. BossBase instantiates one of these into the world,
## positions it at the boss, then calls setup(). It draws its own telegraph during a windup,
## fires once when the telegraph ends, runs an active phase, then frees itself. Hit detection
## is distance-based (matching SlamWave/Enemy/Boss) — no Area2D / collision layers needed.

var boss: Node2D
var player: Node2D
var params: Dictionary = {}
var _windup := 0.8
var _aim_point := Vector2.ZERO   # player position snapshotted at telegraph start; dodge = move during windup
var _fired := false

## Called by BossBase immediately after add_child + positioning. Subclasses override and
## MUST call super.setup() first (it snapshots the aim point and clamps the windup).
func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	boss = b
	player = p
	params = cfg
	_windup = clampf(float(cfg.get("windup", 0.8)), GameConfig.PATTERN_WINDUP_MIN, GameConfig.PATTERN_WINDUP_MAX)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	_aim_point = player.global_position if (player != null and is_instance_valid(player)) else global_position

## Wave-growth multiplier baked into the owning boss at spawn. 1.0 when there is no
## boss (player-spawned HazardZones call setup(null, ...) and must stay flat).
func _special_mult_of(b: Node2D) -> float:
	if b != null and is_instance_valid(b) and "special_mult" in b:
		return float(b.special_mult)
	return 1.0

func _process(delta: float) -> void:
	if _windup > 0.0:
		_windup -= delta
		queue_redraw()
		if _windup <= 0.0:
			_fired = true
			_on_telegraph_end()
		return
	_active(delta)
	queue_redraw()

## One-shot when the telegraph ends (spawn the hit / emit / apply the debuff). Override.
func _on_telegraph_end() -> void:
	pass

## Per-frame after the telegraph; the subclass frees itself when done. Override.
func _active(_delta: float) -> void:
	pass

## Telegraph (during windup) + active visuals. Override.
func _draw() -> void:
	pass

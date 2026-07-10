class_name SummonSpawner
extends AttackPattern
## Spawns Enemy adds. Telegraph = faint circles where the adds will appear. On telegraph
## end it spawns `count` enemies using the current wave's stats (optionally * hp_mult).
## decoy = true spawns them right next to the player so the player's nearest-target auto-aim
## locks onto them instead of the boss (the auto-aim-steal mechanic). Enemy.tscn already
## carries its own xp_gem_scene export, so adds drop XP like normal enemies.

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")

var _count := 3
var _decoy := false
var _hp_mult := 1.0
var _elite_kind := ""    # optional promotion of every summoned add (Karen's MANAGER ON DUTY)
var _spots: Array[Vector2] = []

func setup(b: Node2D, p: Node2D, cfg: Dictionary) -> void:
	super.setup(b, p, cfg)
	_count = int(cfg.get("count", 3))
	_decoy = bool(cfg.get("decoy", false))
	_hp_mult = float(cfg.get("hp_mult", 1.0))
	_elite_kind = String(cfg.get("elite_kind", ""))
	_compute_spots()

## Elite promotion for a freshly-configured summon. DELIBERATELY bypasses the Spawner's
## endless/horde ambient-elite gate — a boss move must work in every mode the boss fights in
## (Boss Rush included). Static + guard-heavy so a headless probe can drive it directly.
static func promote(e: Node, kind: String) -> void:
	if kind != "" and e.has_method("apply_elite"):
		e.apply_elite(kind)

func _compute_spots() -> void:
	_spots.clear()
	var center := _aim_point if _decoy else global_position
	for i in _count:
		var a := TAU * float(i) / float(maxi(_count, 1))
		var r := randf_range(40.0, 90.0) if _decoy else randf_range(60.0, 140.0)
		_spots.append(center + Vector2(cos(a), sin(a)) * r)

func _on_telegraph_end() -> void:
	for spot in _spots:
		var stats := DifficultyManager.enemy_stats()
		stats["max_health"] = float(stats["max_health"]) * _hp_mult
		var e = ENEMY_SCENE.instantiate()
		e.configure(stats)
		SummonSpawner.promote(e, _elite_kind)
		get_tree().current_scene.add_child(e)
		e.global_position = spot
	queue_free()

func _draw() -> void:
	if _windup <= 0.0:
		return
	for spot in _spots:
		draw_circle(to_local(spot), 22.0, Color(0.6, 0.2, 0.8, 0.25))

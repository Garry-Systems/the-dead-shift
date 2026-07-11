class_name Turret
extends Node2D
## SENTRY TURRET (Jackson Killa's signature ability, "Company Equipment" v0.1.70 Task 4): a
## stationary, cap-1 auto-turret. On ABILITY_TURRET_INTERVAL it retargets the nearest "enemies"-
## group member within ABILITY_TURRET_RANGE and fires a talent-free CompanionBullet at it
## (Companion._fire_drone_shot's exact construction recipe — trait_id is always "", unlike the
## Drone companion which carries its coworker's rolled trait). Expires after
## ABILITY_TURRET_LIFETIME seconds. Reimplements the nearest-enemy scan locally
## (Companion._nearest_enemy's distance-squared idiom) rather than depending on Companion —
## Turret has no companion/trait concept of its own, it's pure ability hardware.
##
## Cap 1: spawn() evicts any existing "player_turret" member FIRST, synchronously
## (remove_from_group before queue_free — MannequinDecoy._evict_existing's exact idiom, so a
## same-frame respawn never sees two members in the group even though the evicted node's actual
## free is deferred to end of frame). class_name is required (not just a bare script) because
## AbilityController calls Turret.spawn() cross-file as a static method.

const GROUP := "player_turret"
const RADIUS_PX := 18.0               # visual footprint radius (fallback draw only)
const BODY_COLOR := Color("8C8573")   # C3 gray-tan — Companion fallback palette
const BARREL_COLOR := Color("E0E5FF")  # C4 lavender — Companion fallback palette
const SPRITE_PATH := "res://art/abilities/turret_prop.png"   # staged — art lands Task 9

var _life := GameConfig.ABILITY_TURRET_LIFETIME
var _fire_t := GameConfig.ABILITY_TURRET_INTERVAL

# --- Sprite (art wave): SPRITE_PATH, if it exists, replaces the drawn fallback shape ---
var _sprite: Sprite2D = null
var _sprite_loaded := false

## Spawns a turret at `pos`. Cap 1: any existing "player_turret" member is freed first. Caller
## does NOT add_child first — spawn() owns placement (MannequinDecoy.spawn()'s exact shape).
static func spawn(pos: Vector2, tree: SceneTree) -> void:
	if tree == null:
		return
	_evict_existing(tree)
	var t := Turret.new()
	t.add_to_group(GROUP)
	tree.current_scene.add_child(t)
	t.global_position = pos

static func _evict_existing(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(n):
			n.remove_from_group(GROUP)
			n.queue_free()

func _ready() -> void:
	_setup_sprite()

## Art wave: swaps in the staged SPRITE_PATH texture as a child Sprite2D if it exists (NEAREST
## filtering is the project-wide default, set explicitly anyway — Companion._setup_sprite's own
## belt-and-suspenders). `_sprite_loaded` then tells _draw() to skip the fallback shape.
func _setup_sprite() -> void:
	if not ResourceLoader.exists(SPRITE_PATH):
		return
	_sprite = Sprite2D.new()
	_sprite.texture = load(SPRITE_PATH)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite_loaded = true

## Lifetime countdown + fire cadence. Both timers roll once at construction and never re-roll
## (this codebase's "roll once, store forever" pattern) — they're flat cadences, not RNG ranges,
## so there's nothing to roll; they just count down from their GameConfig starting values.
func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_expire()
		return
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = GameConfig.ABILITY_TURRET_INTERVAL
		_retarget_and_fire()

## Nearest "enemies"-group member within ABILITY_TURRET_RANGE, or null. Mirrors
## Companion._nearest_enemy's distance-squared idiom, reimplemented locally (no Companion
## dependency — the brief is explicit that Turret must not reference Companion).
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := GameConfig.ABILITY_TURRET_RANGE * GameConfig.ABILITY_TURRET_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var node := e as Node2D
		var d: float = global_position.distance_squared_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

## Fires a talent-free CompanionBullet at the nearest enemy in range — Companion._fire_drone_shot's
## exact construction recipe (Companion.gd:254-261): direction set before damage/max_travel/
## trait_id, added to the tree, THEN global_position set (order matters — position-after-add_child
## is this codebase's established CompanionBullet spawn idiom). No-op if nothing is in range.
func _retarget_and_fire() -> void:
	var target := _nearest_enemy()
	if target == null:
		return
	var bullet := CompanionBullet.new()
	bullet.direction = (target.global_position - global_position).normalized()
	bullet.damage = GameConfig.ABILITY_TURRET_DAMAGE
	bullet.max_travel = GameConfig.ABILITY_TURRET_RANGE
	bullet.trait_id = ""   # talent-free per spec — unlike the Drone, which carries its coworker's rolled trait
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position

## Lifetime's up: a small flash then free. Reuses Shockwave.flash() (the established cosmetic-
## only ring FX — Ryan Ace's CLEAR OUT purge pulse uses the same call shape) rather than a
## modulate tween — cheaper (one pooled-free node vs. a Tween + timer) and it's already the
## codebase's go-to "something just ended here" visual.
func _expire() -> void:
	var fx := Shockwave.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.flash(GameConfig.ABILITY_TURRET_FLASH_RADIUS)
	queue_free()

func _draw() -> void:
	if _sprite_loaded:
		return
	draw_circle(Vector2.ZERO, RADIUS_PX, BODY_COLOR)
	draw_line(Vector2.ZERO, Vector2.RIGHT * (RADIUS_PX * 1.4), BARREL_COLOR, 4.0)

class_name Mascot
extends BossBase
## THE MASCOT — the store costume, three layers deep. Phase = costume layer: each threshold
## (0.66 / 0.33) SHEDS — a RING burst at the shed moment, then the collider radius AND Sprite2D
## scale are set to this phase's rung of the MASCOT_SCALE_L* ladder (1.15 -> 0.9 -> 0.7) off the
## Courier-clone .tscn's baked base (radius 46 / sprite scale 2.4), and move speed climbs via
## MASCOT_SPEED_MULT_L* (0.55 -> 0.9 -> 1.35). L1 FULL SUIT: slow, tanky — ground slam (RING) +
## summon 2 fans (SUMMON). L2 HALF SUIT: charges (RING) at Courier-class speed + slam (RING). L3
## THE PERFORMER: tiny, runner-fast, relentless melee + short erratic dashes (CHARGE, low
## cadence). HP is front-loaded (MASCOT_HP 2600) — the L1 tank IS most of the bar. Combat-model
## exploit: pacing — a DPS-check opener that becomes a dodge-check closer.
##
## Sprite: 3 generator variants (mascot_a/b/c, one per phase — layers visually shrinking). Each
## phase's on_enter loads its own art/bosses/mascot_<a|b|c>.png if it exists (Pack F staged
## idiom); if it doesn't, the shared Courier-clone texture stays and is tinted per phase instead
## (tint-scale fallback) — the scale ladder alone still sells "shrinking" either way. Missing art
## warns once per instance, not once per phase.

const BOSS_ID := "mascot"
const _PHASE_ART_IDS: Array[String] = ["mascot_a", "mascot_b", "mascot_c"]

var _base_radius := 46.0             # Courier-clone .tscn base — cached from the (post-duplicate) shape, see _ready
var _base_sprite_scale := Vector2(2.4, 2.4)  # Courier-clone .tscn base sprite scale
var _shared_tex: Texture2D           # the .tscn's baked shared enemy.png — the tint-scale fallback texture
var _warned_missing_art := false     # missing-art warning fires once per instance, not per phase

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.MASCOT_HP / GameConfig.BOSS_BASE_HP

func _ready() -> void:
	# Night Shift Stories T2 TRAP: boss .tscn CollisionShape2D shapes are baked as SubResources,
	# which Godot shares as ONE Resource object across every instance of the SAME .tscn — resizing
	# it on one instance resizes it on ALL of them. Duplicate it ONCE, here, before anything in
	# _build_phases()'s on_enter callbacks (or the L1 on_enter fired by _enter_phase(0) inside
	# super._ready() below) ever resizes it — otherwise Boss Rush's second concurrent Mascot spawn
	# would read/write the exact same CircleShape2D the first instance already shrunk, silently
	# sharing (and racing) hitboxes between unrelated boss bodies.
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape != null:
		col.shape = col.shape.duplicate()
		if col.shape is CircleShape2D:
			_base_radius = (col.shape as CircleShape2D).radius
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		_base_sprite_scale = spr.scale
		_shared_tex = spr.texture
	super._ready()

## Overrides BossBase's single-texture staged-art hook entirely (no super call): Mascot has
## THREE phase textures (mascot_a/b/c), not boss_id()'s one "art/bosses/mascot.png" — that hook
## would push a spurious "no sprite" warning every spawn. Real texture/scale/tint per phase is
## applied by _apply_phase_look instead, called from each phase's on_enter (including L1's,
## fired by _enter_phase(0) during super._ready() above).
func _setup_sprite() -> void:
	pass

func _build_phases() -> Array:
	var slam := { "radius": GameConfig.MASCOT_SLAM_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.MASCOT_SLAM_DAMAGE, "windup": GameConfig.SLAM_WINDUP }
	var fans := { "count": GameConfig.MASCOT_SUMMON_COUNT, "windup": 0.9 }
	var half_charge := { "speed": GameConfig.COURIER_CHARGE_SPEED, "duration": GameConfig.COURIER_CHARGE_DURATION, "windup": 0.7 }   # Courier-class speed, per spec
	var duel_charge := { "speed": GameConfig.MASCOT_L3_CHARGE_SPEED, "duration": GameConfig.MASCOT_L3_CHARGE_DURATION, "windup": 0.5 }
	return [
		{
			"at": 1.0, "cadence": GameConfig.MASCOT_CADENCE_L1, "speed_mult": GameConfig.MASCOT_SPEED_MULT_L1,
			"on_enter": _enter_l1,
			"patterns": [
				{ "scene": Patterns.RING, "params": slam },
				{ "scene": Patterns.SUMMON, "params": fans },
			],
		},
		{
			"at": 0.66, "cadence": GameConfig.MASCOT_CADENCE_L2, "speed_mult": GameConfig.MASCOT_SPEED_MULT_L2,
			"on_enter": _enter_l2,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": half_charge },
				{ "scene": Patterns.RING, "params": slam },
			],
		},
		{
			"at": 0.33, "cadence": GameConfig.MASCOT_CADENCE_L3, "speed_mult": GameConfig.MASCOT_SPEED_MULT_L3,
			"on_enter": _enter_l3,
			"patterns": [
				{ "scene": Patterns.CHARGE, "params": duel_charge },
			],
		},
	]

## L1 on_enter: NOT a shed (nothing has been shed yet) — just bakes in the FULL SUIT's bulked-up
## look at spawn (scale ladder rung 0, no RING burst).
func _enter_l1() -> void:
	_apply_phase_look(0, GameConfig.MASCOT_SCALE_L1)

## L2 on_enter: the first shed — half the suit comes off.
func _enter_l2() -> void:
	_cast_shed_ring()
	_apply_phase_look(1, GameConfig.MASCOT_SCALE_L2)

## L3 on_enter: the second shed — down to THE PERFORMER underneath.
func _enter_l3() -> void:
	_cast_shed_ring()
	_apply_phase_look(2, GameConfig.MASCOT_SCALE_L3)

## The shed-burst: an independent one-shot RING cast (Karen's _call_the_manager idiom — NOT part
## of the phase's own round-robin pattern list, fires exactly once per shed).
func _cast_shed_ring() -> void:
	var p = Patterns.RING.instantiate()
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.setup(self, _target, { "radius": GameConfig.MASCOT_SHED_RING_RADIUS, "expand_time": GameConfig.SLAM_EXPAND_TIME,
		"damage": GameConfig.MASCOT_SHED_RING_DAMAGE, "windup": GameConfig.PATTERN_WINDUP_MIN })

## Applies phase index `i`'s rung of the scale ladder (`mult`) to BOTH the (per-instance,
## duplicated — see _ready) collider radius and the Sprite2D scale, off the fixed Courier-clone
## base cached in _ready — never compounded onto the current (already-scaled) value, so a stray
## re-entry can never double-shrink the costume. Then tries mascot_<a|b|c>.png for this phase
## (Pack F staged idiom, canvas-ratio compensated like BossBase._setup_sprite); if it doesn't
## exist yet, falls back to the shared enemy.png tinted per phase (still scaled by the ladder —
## the shrink alone sells "shedding" even before Task 5's art lands).
func _apply_phase_look(i: int, mult: float) -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = _base_radius * mult
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	var art_id := _PHASE_ART_IDS[i]
	var path := "res://art/bosses/%s.png" % art_id
	if ResourceLoader.exists(path):
		spr.texture = load(path)
		spr.scale = _base_sprite_scale * mult * (GameConfig.SPRITE_ENEMY_PX / GameConfig.SPRITE_BOSS_PX)
		spr.modulate = Color(1, 1, 1, 1)
		_sprite_loaded = true
	else:
		if not _warned_missing_art:
			_warned_missing_art = true
			push_warning("Mascot: no phase sprite for '%s' — regenerate sprites (generator list drift?), tint-scale fallback in use" % art_id)
		spr.texture = _shared_tex
		spr.scale = _base_sprite_scale * mult
		spr.modulate = _tint_for_phase(i)

## Tint-scale fallback color per phase, strict palette only: L1 untinted (the full suit reads as
## a normal enemy), L2 ACCENT (C4 — the half-shed suit stands out), L3 ACCENT_DIM (C2 — the tiny
## performer underneath reads darker/wrong, the "the suit has always been on" unease).
func _tint_for_phase(i: int) -> Color:
	match i:
		1:
			return PixelTheme.ACCENT
		2:
			return PixelTheme.ACCENT_DIM
		_:
			return Color(1, 1, 1, 1)

class_name MysteryShopper
extends BossBase
## THE MYSTERY SHOPPER (boss #10, Night Shift Stories v0.1.68) — the roster's first CONCEALED
## boss. Spawns disguised as ordinary horde filler: the .tscn's baked Sprite2D is left at the
## exact shambler scale/texture (NOT the usual inflated boss look), no boss bar, no SHIFT CHANGE
## toast, and it drifts at a slow, trash-like pace with its cadence clock held (no casts) —
## `revealed()` returns false and Hud.gd (see its reveal-gating rework) simply doesn't show it.
##
## It reveals when either GameConfig.SHOPPER_REVEAL_DAMAGE of cumulative damage lands since the
## last cloak, or the player closes to SHOPPER_REVEAL_RANGE — then the bar/name/toast/flavor line
## all fire (via revealed() flipping true) and it fights: short CHARGE slash-lunges at a brisk,
## runner-class persistent chase pace. At every phase edge (0.66 / 0.33 health fraction) it
## re-cloaks: a shimmer draw-out, a teleport-blend to a rim point among the currently-live
## "enemies" (so the player has to re-find it, not just re-aim), the cumulative damage counter
## resets, and it re-skins back to the plain shambler disguise. Combat-model exploit: auto-aim
## keeps servicing trash, so the player has to read movement (subtly straighter pathing than
## trash is the fair tell) to catch it again.
##
## Concealed-boss seam: BossBase.revealed() defaults true and is otherwise untouched — this
## class is the ONLY place concealment behavior lives. Taunt/pin immunity is free: Enemy.taunt()
## callers all `(e as Enemy).taunt(...)`, and MysteryShopper extends BossBase, not Enemy, so the
## cast is null regardless of concealed/revealed state — same class-free immunity every boss gets.

const BOSS_ID := "mystery_shopper"

var _revealed := false
var _damage_since_cloak := 0.0

# Sprite state, managed entirely by this class (NOT BossBase._setup_sprite — that idiom is a
# one-shot, never-reverting upgrade; the Shopper needs to swap back and forth every re-cloak).
var _disguise_tex: Texture2D    # the .tscn's baked shared enemy texture, cached at _ready
var _disguise_scale := Vector2.ONE
var _real_tex: Texture2D        # art/bosses/mystery_shopper.png, loaded lazily on first reveal

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.SHOPPER_HP / GameConfig.BOSS_BASE_HP

## Whether the disguise is currently blown. Hud.gd reads this to gate the boss bar/name/toast.
func revealed() -> bool:
	return _revealed

func _build_phases() -> Array:
	var lunge := { "speed": GameConfig.SHOPPER_CHARGE_SPEED, "duration": GameConfig.SHOPPER_CHARGE_DURATION, "windup": 0.5 }
	var fight := [{ "scene": Patterns.CHARGE, "params": lunge }]
	# All 3 phases share the same concealed speed_mult/cadence/pattern shape — the phase table
	# exists here for the health-fraction re-cloak EDGES (0.66/0.33 -> on_enter _re_cloak), not
	# for pattern variety across the fight (the spec gives one cadence/lunge, not a per-phase
	# escalation like Courier/Karen/Tanker). speed_mult is the CONCEALED value on every entry —
	# _enter_phase() applies it immediately on every phase transition (== every re-cloak moment),
	# and _reveal() bumps _speed_mult to the revealed value directly until the next re-cloak.
	return [
		{ "at": 1.0, "cadence": GameConfig.SHOPPER_CADENCE, "speed_mult": GameConfig.SHOPPER_CONCEALED_SPEED_MULT, "patterns": fight },
		{ "at": 0.66, "cadence": GameConfig.SHOPPER_CADENCE, "speed_mult": GameConfig.SHOPPER_CONCEALED_SPEED_MULT, "patterns": fight, "on_enter": _re_cloak },
		{ "at": 0.33, "cadence": GameConfig.SHOPPER_CADENCE, "speed_mult": GameConfig.SHOPPER_CONCEALED_SPEED_MULT, "patterns": fight, "on_enter": _re_cloak },
	]

## Cached instead of loaded/applied: called once from BossBase._ready() (Pack F's automatic
## staged-sprite hook). Deliberately does NOT call super — the base version would immediately
## load+apply the real 48px art at spawn, which is exactly what concealment must NOT do. Real-art
## swap-in is deferred entirely to _reveal() (and reverted by _re_cloak()) instead.
func _setup_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_disguise_tex = spr.texture
	_disguise_scale = spr.scale
	# Concealed at spawn: the .tscn's baked shambler texture/scale is left exactly as authored —
	# no regalia, no real sprite. See _draw() (regalia only drawn once _revealed) and
	# _apply_real_sprite()/_apply_disguise_sprite() (the two-way texture/scale swap).

## Cumulative-damage reveal trigger (the other trigger, proximity, is checked every physics tick
## in _physics_process below since it isn't damage-driven).
func take_damage(amount: float) -> void:
	if not _revealed:
		_damage_since_cloak += amount
	super.take_damage(amount)
	if _dead or _revealed:
		return
	if _damage_since_cloak >= GameConfig.SHOPPER_REVEAL_DAMAGE:
		_reveal()

## Reuses BossBase's full chase/phase/cast loop via super, then layers the concealed-boss seam
## on top: the proximity reveal trigger, and holding the pattern-cast cadence clock while
## concealed (spec: "NO pattern casting while concealed (hold the cadence clock)") — patterns
## are still configured per-phase (see _build_phases) for when it's revealed, but the clock is
## pinned to a fresh full window every concealed tick so a reveal never opens on a stale/near-zero
## clock inherited from ticking uselessly while disguised.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	if not _revealed and _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) <= GameConfig.SHOPPER_REVEAL_RANGE:
			_reveal()
	if not _revealed and _phase_idx >= 0 and _phase_idx < phases.size():
		_pat_clock = float(phases[_phase_idx].get("cadence", 4.0))

func _reveal() -> void:
	if _revealed or _dead:
		return
	_revealed = true
	_speed_mult = GameConfig.SHOPPER_REVEALED_SPEED_MULT
	_apply_real_sprite()
	queue_redraw()

## Phase-edge on_enter (0.66 / 0.33): shimmer draw-out, teleport-blend into the live horde,
## damage counter reset, back to disguised. _speed_mult is already reset to the concealed value
## by _enter_phase() (it reads the phase dict's speed_mult BEFORE calling this on_enter).
func _re_cloak() -> void:
	_shimmer()
	global_position = _pick_rim_point()
	_revealed = false
	_damage_since_cloak = 0.0
	_apply_disguise_sprite()
	queue_redraw()

## Swaps the real 48px reveal sprite in (loaded once, then cached/reused across every later
## reveal in the same fight). Falls back to nothing (stays disguised-looking, _draw() below then
## supplies fallback regalia) if the art hasn't landed yet — the same staged-rollout tolerance
## every other boss's _setup_sprite has.
func _apply_real_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	if _real_tex == null:
		var path := "res://art/bosses/%s.png" % BOSS_ID
		if not ResourceLoader.exists(path):
			push_warning("MysteryShopper: no reveal sprite for boss id '%s' — regenerate sprites (generator list drift?)" % BOSS_ID)
			return
		_real_tex = load(path)
		_sprite_loaded = true
	spr.texture = _real_tex
	spr.scale = _disguise_scale * (GameConfig.SPRITE_ENEMY_PX / GameConfig.SPRITE_BOSS_PX)

## Swaps back to the plain shared shambler look (texture AND scale — the real sprite's canvas is
## a different native size, see SPRITE_ENEMY_PX/SPRITE_BOSS_PX, so scale must revert too or the
## disguise reads as an oddly-small shambler).
func _apply_disguise_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or _disguise_tex == null:
		return
	spr.texture = _disguise_tex
	spr.scale = _disguise_scale

## Brief fade-out/in on the Sprite2D — sells the re-cloak teleport-blend as a magic swap rather
## than a hard pop. Purely cosmetic; duration hardcoded like BossBase.flash_hit's own tween
## (no GameConfig const needed for a fixed cosmetic tween length).
func _shimmer() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.15, 0.1)
	tw.tween_property(spr, "modulate:a", 1.0, 0.1)

## Re-cloak reposition: teleport-blend into the CURRENT horde — a random position among the other
## live "enemies" group members reads as "which shambler was that?" far better than a fresh spot.
## Falls back to a fresh spawn-ring point (Spawner._pick_spawn_pos's own ring math, reimplemented
## locally — this file has no dependency on Spawner) if no other trash happens to be alive yet.
func _pick_rim_point() -> Vector2:
	var others: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is Node2D and is_instance_valid(e):
			others.append(e)
	if not others.is_empty():
		return (others[randi() % others.size()] as Node2D).global_position
	if _target == null or not is_instance_valid(_target):
		return global_position
	var angle := randf_range(0.0, TAU)
	return _target.global_position + Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS

## Fallback regalia (staged idiom, Pack F): sunglasses + a wire shopping basket, drawn ONLY while
## revealed and only until the real art lands — concealed always renders as the plain shared
## shambler texture with nothing extra drawn over it (the entire point of the disguise). Palette
## C1/C2/C4 only, matching every other boss's regalia.
func _draw() -> void:
	if not _revealed or _sprite_loaded:
		return
	draw_rect(Rect2(Vector2(-14, -20), Vector2(28, 7)), PixelTheme.DARK)      # sunglasses band
	draw_rect(Rect2(Vector2(-10, -18), Vector2(4, 3)), PixelTheme.ACCENT)     # left lens glint
	draw_rect(Rect2(Vector2(6, -18), Vector2(4, 3)), PixelTheme.ACCENT)       # right lens glint
	var basket := Rect2(Vector2(14, 10), Vector2(20, 14))
	draw_rect(basket, PixelTheme.ACCENT_DIM)                                 # shopping basket body
	draw_rect(basket, PixelTheme.DARK, false, 2.0)
	draw_line(Vector2(16, 10), Vector2(22, -2), PixelTheme.DARK, 2.0)        # basket handle

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
## all fire (via revealed() flipping true), the sprite visibly GROWS to boss size
## (SHOPPER_REVEALED_SCALE), contact damage switches on, and it fights: short CHARGE slash-lunges
## at a brisk, runner-class persistent chase pace. While concealed, contact damage is OFF entirely
## (touch_damage 0 — see _real_touch_damage). At every phase edge (0.66 / 0.33 health fraction) it
## re-cloaks: a fade-out at the old spot, then a teleport-blend to a rim point among the
## currently-live "enemies" (so the player has to re-find it, not just re-aim), the cumulative
## damage counter resets, and it re-skins back to the plain shambler disguise. Combat-model
## exploit: auto-aim keeps servicing trash, so the player has to read movement (subtly straighter
## pathing than trash is the fair tell) to catch it again.
##
## Concealed-boss seam: BossBase.revealed() defaults true and is otherwise untouched — this
## class is the ONLY place concealment behavior lives. Taunt/pin immunity is free: Enemy.taunt()
## callers all `(e as Enemy).taunt(...)`, and MysteryShopper extends BossBase, not Enemy, so the
## cast is null regardless of concealed/revealed state — same class-free immunity every boss gets.

const BOSS_ID := "mystery_shopper"

var _revealed := false
var _damage_since_cloak := 0.0

## The configured (wave-scaled) contact damage, held aside while concealed: she's shopping, not
## biting — the menace is the reveal, and an invisible 46px boss hitbox grinding boss-DPS contact
## damage under a shambler skin would be unreadably unfair. The live `touch_damage` is 0 while
## concealed and restored to this on reveal (BossBase itself is untouched — the toggle lives here).
var _real_touch_damage := GameConfig.BOSS_TOUCH_DAMAGE
var _warned_missing_art := false   # missing-art warning fires once per instance, not per reveal

# Sprite state, managed entirely by this class (NOT BossBase._setup_sprite — that idiom is a
# one-shot, never-reverting upgrade; the Shopper needs to swap back and forth every re-cloak).
var _disguise_tex: Texture2D    # the .tscn's baked shared enemy texture, cached at _ready
var _disguise_scale := Vector2.ONE
var _real_tex: Texture2D        # art/bosses/mystery_shopper.png, loaded lazily on first reveal

func boss_id() -> String:
	return BOSS_ID

func _hp_mult() -> float:
	return GameConfig.SHOPPER_HP / GameConfig.BOSS_BASE_HP

## Captures the wave-scaled touch damage the Spawner baked, then zeroes the live value while
## concealed (see _real_touch_damage's doc comment). _reveal()/_re_cloak() toggle it back and forth.
func configure(stats: Dictionary) -> void:
	super.configure(stats)
	_real_touch_damage = touch_damage
	if not _revealed:
		touch_damage = 0.0

func _ready() -> void:
	super._ready()
	# Covers the no-configure path (direct instantiation, e.g. probes): _real_touch_damage's
	# field default already equals the un-configured touch_damage (BOSS_TOUCH_DAMAGE), so the
	# reveal-restore works identically whether or not the Spawner ran configure() first.
	if not _revealed:
		touch_damage = 0.0

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
##
## She disguises as the most common shopper: the .tscn bakes the legacy shared art/enemy.png
## (a pre-Pack-F placeholder), but every live trash type has had its own per-type art since Pack F
## — left as-is, she'd be the ONLY blob-face on screen, concealment DOA. If the shambler's own
## art/enemies/shambler.png (the horde's most common type) exists, swap it onto the Sprite2D
## BEFORE caching, so the cache — and every re-cloak via _apply_disguise_sprite (~203), which just
## replays this cache — carries the real disguise instead of the legacy placeholder.
func _setup_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	var path := "res://art/enemies/shambler.png"
	if ResourceLoader.exists(path):
		spr.texture = load(path)
	_disguise_tex = spr.texture
	_disguise_scale = spr.scale
	# Concealed at spawn: scale is left exactly as authored — no regalia, no real sprite. Native
	# 32px canvas (GameConfig.SPRITE_ENEMY_PX) matches the shambler texture's, so no scale change
	# is needed on this swap (Enemy._setup_sprite's own comment confirms this for every trash
	# type). See _draw() (regalia only drawn once _revealed) and _apply_real_sprite()/
	# _apply_disguise_sprite() (the two-way texture/scale swap).

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
	touch_damage = _real_touch_damage   # disguise off, gloves off — normal boss contact resumes
	_apply_real_sprite()
	SoundManager.play("boss_roar")   # the roar IS the reveal beat — Spawner gates its own spawn-time roar off while concealed (see Spawner._spawn_boss)
	queue_redraw()

## Phase-edge on_enter (0.66 / 0.33): the re-cloak. STATE flips immediately — concealed (the HUD
## bar/name drop via revealed()), damage counter reset, contact damage back off. The VISUAL is an
## honest 2-step tween: fade out at the OLD spot (the spec's shimmer draw-out — she vanishes where
## you were shooting her), then, only once fully invisible, teleport-blend to a rim point among the
## live horde + re-skin to the shambler disguise (_finish_cloak), then fade back in among the
## crowd. _speed_mult is already reset to the concealed value by _enter_phase() (it reads the
## phase dict's speed_mult BEFORE calling this on_enter). If she's re-revealed mid-tween
## (proximity/damage), _finish_cloak skips itself and the tween just finishes the alpha ramp.
func _re_cloak() -> void:
	_revealed = false
	_damage_since_cloak = 0.0
	touch_damage = 0.0   # browsing again — contact damage stays off until the next reveal
	# Fireproof cloak: BossBase._physics_process ticks any live _burn_time/_burn_dps through
	# take_damage() every physics frame regardless of concealment, which would otherwise refill
	# _damage_since_cloak and force an auto-reveal ~1s after every cloak on an incendiary build.
	# The re-find game must survive fire builds — direct hits still count (this only zeroes the
	# ongoing burn channel, not damage already landed before the cloak).
	_burn_time = 0.0
	_burn_dps = 0.0
	queue_redraw()       # drops the fallback regalia immediately (its _draw gates on _revealed)
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		_finish_cloak()   # bare-script instance (no sprite to animate): just jump + re-skin
		return
	var tw := create_tween()
	tw.tween_property(spr, "modulate:a", 0.0, 0.12)
	tw.tween_callback(_finish_cloak)
	tw.tween_property(spr, "modulate:a", 1.0, 0.12)

## Second step of the re-cloak tween, run while the sprite is fully faded out: the teleport-blend
## into the live horde + the disguise re-skin — invisible when it happens, so the player only ever
## sees "she faded out over there", never the swap itself.
func _finish_cloak() -> void:
	if _revealed:
		return   # re-revealed during the fade-out — the reveal's own sprite swap already won
	global_position = _pick_rim_point()
	_apply_disguise_sprite()

## Swaps the revealed look in. The reveal visibly GROWS her from the shambler's baked 1.0 scale to
## boss size (SHOPPER_REVEALED_SCALE — Courier's baked .tscn value): with the real 48px art
## (loaded once, cached across re-reveals) the texture swaps and the scale compensates for the
## bigger canvas exactly like BossBase._setup_sprite does; while the art hasn't landed (Task 5),
## the shared 32px texture itself is blown up to the full boss scale instead — the size jump IS
## the reveal drama either way. Missing art warns once per instance, not per reveal.
func _apply_real_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	if _real_tex == null:
		var path := "res://art/bosses/%s.png" % BOSS_ID
		if ResourceLoader.exists(path):
			_real_tex = load(path)
			_sprite_loaded = true
		elif not _warned_missing_art:
			_warned_missing_art = true
			push_warning("MysteryShopper: no reveal sprite for boss id '%s' — regenerate sprites (generator list drift?)" % BOSS_ID)
	if _real_tex != null:
		spr.texture = _real_tex
	spr.scale = _revealed_sprite_scale(_real_tex != null)
	# Fallback regalia (_draw below) must render OVER the sprite while revealed. The other bosses
	# bake z_index = -1 into their .tscn for this, but the Shopper's stays 0 while concealed
	# (Enemy.tscn's sprite has no z_index — a baked -1 would draw her under overlapping shamblers,
	# a draw-order tell), so it's applied here on reveal and reverted on re-cloak instead.
	spr.z_index = -1

## The revealed Sprite2D scale. Split out (and branch-parameterized) so the probe can assert both
## the with-art and without-art math without needing Task 5's png on disk.
func _revealed_sprite_scale(has_art: bool) -> Vector2:
	if has_art:
		# 48px canvas: the same on-screen size compensation BossBase._setup_sprite applies.
		return Vector2.ONE * GameConfig.SHOPPER_REVEALED_SCALE * (GameConfig.SPRITE_ENEMY_PX / GameConfig.SPRITE_BOSS_PX)
	return Vector2.ONE * GameConfig.SHOPPER_REVEALED_SCALE

## Swaps back to the plain shared shambler look (texture AND scale AND z_index — the revealed
## look changes all three, and any one left behind is a tell under the disguise).
func _apply_disguise_sprite() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or _disguise_tex == null:
		return
	spr.texture = _disguise_tex
	spr.scale = _disguise_scale
	spr.z_index = 0   # Enemy.tscn parity — see _apply_real_sprite's z_index comment

## Re-cloak reposition: teleport-blend into the CURRENT horde — a random position among the other
## live "enemies" group members reads as "which shambler was that?" far better than a fresh spot.
## Falls back to a fresh spawn-ring point if no other trash happens to be alive yet —
## Spawner._pick_spawn_pos's exact idiom (reimplemented locally, no Spawner dependency): up to 8
## angle rerolls while the candidate sits inside the forecourt keep-out (a blind angle near the
## origin could drop her INSIDE the store building), else push the last candidate radially out.
func _pick_rim_point() -> Vector2:
	var others: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is Node2D and is_instance_valid(e):
			others.append(e)
	if not others.is_empty():
		return (others[randi() % others.size()] as Node2D).global_position
	if _target == null or not is_instance_valid(_target):
		return global_position
	var keep2 := GameConfig.FORECOURT_SPAWN_KEEPOUT * GameConfig.FORECOURT_SPAWN_KEEPOUT
	var pos := _target.global_position + Vector2.RIGHT * GameConfig.SPAWN_RADIUS
	for i in 8:
		var angle := randf_range(0.0, TAU)
		pos = _target.global_position + Vector2(cos(angle), sin(angle)) * GameConfig.SPAWN_RADIUS
		if pos.distance_squared_to(Vector2.ZERO) >= keep2:
			return pos
	var dir := pos.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	return dir * GameConfig.FORECOURT_SPAWN_KEEPOUT

## Fallback regalia (staged idiom, Pack F): sunglasses + a wire shopping basket, drawn ONLY while
## revealed and only until the real art lands — concealed always renders as the plain shared
## shambler texture with nothing extra drawn over it (the entire point of the disguise). Palette
## C1/C2/C4 only. Offsets are body-local px (this _draw is on the CharacterBody2D, unaffected by
## the Sprite2D's scale) and are sized for the REVEALED 2.4-scale sprite (~77px wide, spans ±38):
## they crib Karen's regalia numbers, which are authored for the same 2.4 baked sprite scale —
## band at y -20 sits on the face, basket at (14..34, 10..24) rides at her side.
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

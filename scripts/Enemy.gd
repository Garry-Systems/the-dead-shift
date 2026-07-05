class_name Enemy
extends CharacterBody2D
## An enemy: walks toward the player, has health, damages the player on contact,
## and drops an XP gem when it dies. Stats are baked once at spawn via configure()
## (the project's "roll once, store forever" pattern) so a wave-8 enemy keeps wave-8
## stats even into wave 9.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const KNOCKBACK_DECAY := 900.0    # px/s^2 the talent knockback impulse bleeds off
const FROZEN_TINT := Color("3D0099")   # C2 indigo — frozen tell (palette-compliant)
const PIN_TINT := Color("E0E5FF")      # C4 lavender — Nail Gun "nailed" tell (palette-compliant)

# Tint-ladder blends (Talent Overhaul Phase 1): weaker statuses tint by BLENDING toward the
# family color rather than a solid wash, so the ladder stays readable when several mild statuses
# overlap (the FLASH_CD lesson — pulses/blends, never solid washes). Frozen/pinned stay SOLID
# (above) because they're the strongest, rarest tells; everything below them blends.
const BURN_TINT := Hazards.ORANGE
const BURN_BLEND := 0.6
const POISON_TINT := Hazards.GREEN
const POISON_BLEND := 0.5
const MARK_TINT := Hazards.GOLD
const MARK_BLEND := 0.35
const SLOW_TINT := FROZEN_TINT          # same indigo family as freeze, just a weaker blend
const SLOW_BLEND := 0.4
const FEAR_TINT := Color("0A001A")      # C1 void — Night Terror's "feared" tell (palette-compliant)
const FEAR_BLEND := 0.8                 # near-solid — outranks burn/poison/mark/slow, below pin/frozen

const FLASH_CD := 0.15           # min seconds between hit-flashes. A continuous weapon (flame cone,
                                 # beam) or a rapid gun (Nail Gun) calls flash_hit far faster than the
                                 # 0.12s pop can fade, which pins the sprite SOLID WHITE and hides the
                                 # burn/freeze/pin tint. Throttling to readable pulses fixes that
                                 # (purely cosmetic — flash_hit never touches gameplay).

@export var xp_gem_scene: PackedScene

# Baked per-enemy stats (set by configure(); fall back to base config if spawned raw).
var max_health := GameConfig.ENEMY_MAX_HEALTH
var move_speed := GameConfig.ENEMY_MOVE_SPEED
var touch_damage := GameConfig.ENEMY_TOUCH_DAMAGE
var _special_mult := 1.0       # wave-growth factor for flat special damage (projectiles, blasts)

var _health: Health
var _target: Player
var _burn_dps := 0.0
var _burn_time := 0.0          # seconds of burn remaining (incendiary talent)
var _dot_dps := 0.0            # stacking poison DoT (Venom talent)
var _dot_time := 0.0
var _slow_factor := 1.0        # move-speed multiplier (Frostbite talent); 1.0 = unslowed
var _slow_time := 0.0
var _vuln_bonus := 0.0         # extra damage-taken fraction (Marked talent); 0 = none
var _vuln_time := 0.0
var _frozen := false           # Cold Snap: fully stopped while true
var _freeze_time := 0.0
var _pinned := false           # Nail Gun: rooted in place (movement only) while true
var _pin_time := 0.0
var _fear_time := 0.0          # seconds remaining feared (Night Terror talent); 0 = not feared
var _knockback := Vector2.ZERO # decaying impulse (Concussive talent)
var _contact_cd := 0.0         # bite cooldown: counts down between contact hits so we bounce, not stick
var _flash_mat: ShaderMaterial
var _flash_cd := 0.0            # counts down between hit-flashes (see FLASH_CD)
var _health_bar: EnemyHealthBar

## Bakes scaled stats at spawn. Called by the Spawner before/at add_child.
## Cast every Variant out of the dict explicitly to dodge the GDScript typing traps.
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"])
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	_special_mult = float(stats.get("special_mult", 1.0))
	_health = Health.new(max_health)

func _ready() -> void:
	add_to_group("enemies")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:                       # spawned without configure() -> base stats
		_health = Health.new(max_health)
	_setup_flash()
	_health_bar = EnemyHealthBar.new()
	_health_bar.position = Vector2(0, -28)
	_health_bar.z_index = 1
	add_child(_health_bar)

## Gives this sprite its own flash material so a hit flashes only this enemy.
func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	spr.material = _flash_mat

## Brief pop on bullet impact (called by Bullet, not by burn ticks). Throttled by FLASH_CD so
## continuous/rapid fire can't re-slam the flash and pin the sprite white. `tint` defaults to
## white; Curb Stomp (cc_bonus) passes C2 indigo on a "boosted hit" against a hampered target so
## the flash itself reads as "you punished a controlled target" instead of adding a new node.
func flash_hit(tint: Color = Color(1, 1, 1, 1)) -> void:
	if _flash_mat == null or _flash_cd > 0.0:
		return
	_flash_cd = FLASH_CD
	SoundManager.play("hit_enemy")   # single chokepoint: bullet/cone/beam/lightning all call flash_hit()
	_flash_mat.set_shader_parameter("flash_color", tint)
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.12)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

## Applies (or refreshes) an incendiary burn — damage over time, set by a bullet. Refreshes the
## tint only on the off->on transition (a re-ignite while already burning doesn't change the
## ladder's read, just the numbers underneath it).
func ignite(dps: float, duration: float) -> void:
	var was_active := _burn_time > 0.0
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)
	if not was_active:
		_refresh_tint()

## Talent (Frostbite): cut move speed by `factor` (0..1) for `duration`s. Strongest wins.
func apply_slow(factor: float, duration: float) -> void:
	var was_active := _slow_time > 0.0
	_slow_factor = minf(_slow_factor, clampf(1.0 - factor, 0.05, 1.0))
	_slow_time = maxf(_slow_time, duration)
	if not was_active:
		_refresh_tint()

## Talent (Venom): stacking poison DoT — adds to any existing tick.
func apply_dot(dps: float, duration: float) -> void:
	var was_active := _dot_time > 0.0
	_dot_dps += dps
	_dot_time = maxf(_dot_time, duration)
	if not was_active:
		_refresh_tint()

## Talent (Concussive): shove the enemy with an impulse that decays over time.
func apply_knockback(impulse: Vector2) -> void:
	_knockback += impulse

## Talent (Marked): take extra damage for a duration. Strongest application wins; capped in take_damage.
func apply_vulnerable(frac: float, duration: float) -> void:
	var was_active := _vuln_time > 0.0
	_vuln_bonus = maxf(_vuln_bonus, frac)
	_vuln_time = maxf(_vuln_time, duration)
	if not was_active:
		_refresh_tint()

## Talent (Cold Snap): fully stop the enemy for a duration. A hit while frozen shatters it.
func apply_freeze(duration: float) -> void:
	_freeze_time = maxf(_freeze_time, duration)
	if not _frozen:
		_frozen = true
		_refresh_tint()

func is_frozen() -> bool:
	return _frozen

func _thaw() -> void:
	_frozen = false
	_refresh_tint()

## Nail Gun: root the enemy in place for `duration`s (movement only — it can still act).
## Lavender "nailed" tell, distinct from the indigo freeze; does NOT set is_frozen().
func apply_pin(duration: float) -> void:
	_pin_time = maxf(_pin_time, duration)
	if not _pinned:
		_pinned = true
		_refresh_tint()

func is_pinned() -> bool:
	return _pinned

## Night Terror (`onhit_fear`): reverse this enemy's chase for `duration`s (movement-only — _act
## still runs, mirroring the Nail Gun pin pattern above). Capped at TALENT_FEAR_MAX_DURATION
## (Risks #10) so a feared ranged enemy can't drag off-screen. Boss-immune for free: BossBase
## never defines this method, so the has_method gate at every call site excludes it.
func apply_fear(duration: float) -> void:
	var was_active := _fear_time > 0.0
	_fear_time = maxf(_fear_time, minf(duration, GameConfig.TALENT_FEAR_MAX_DURATION))
	if not was_active:
		_refresh_tint()

## Septic Shock (`onhit_dot_detonate`): the total damage still owed by the active burn + poison
## channels, at their CURRENT per-tick rate — i.e. what `_physics_process` would deal if both
## ran to completion untouched. Read-only; pairs with clear_dots() below.
func dot_remaining() -> float:
	return _burn_dps * _burn_time + _dot_dps * _dot_time

## Septic Shock (`onhit_dot_detonate`): wipes both DoT channels (after their damage has been
## read via dot_remaining() and converted into an instant burst). Refreshes the tint only if a
## channel was actually active (mirrors every other status's off/on transition gate).
func clear_dots() -> void:
	var was_active := _burn_time > 0.0 or _dot_time > 0.0
	_burn_dps = 0.0
	_burn_time = 0.0
	_dot_dps = 0.0
	_dot_time = 0.0
	if was_active:
		_refresh_tint()

## Outbreak (`onkill_spread`): a same-frame-safe copy of this enemy's active statuses, for the
## killed-branch to read IMMEDIATELY (queue_free is deferred, so the corpse is still valid this
## frame — see Risks #5) and re-apply onto nearby enemies.
func status_snapshot() -> Dictionary:
	return {
		"burn_dps": _burn_dps, "burn_time": _burn_time,
		"dot_dps": _dot_dps, "dot_time": _dot_time,
		"slow_factor": _slow_factor, "slow_time": _slow_time,
	}

## Curb Stomp (`cc_bonus`): true while this enemy is slowed, frozen, or pinned — the CC
## archetype's payoff condition. Bosses are immune for free (has_method gate at the call site;
## BossBase never defines this method).
func is_hampered() -> bool:
	return _slow_factor < 1.0 or _frozen or _pinned

## Pure: persistent base tint by status precedence — frozen > pinned > feared > burning >
## poisoned > marked > slowed > neutral. Static so a probe can verify the precedence headlessly.
## Frozen/pinned are solid tells; feared is a near-solid blend; everything below blends toward
## its family color so overlapping mild statuses stay readable (see the BLEND consts).
static func _resolve_tint(frozen: bool, pinned: bool, feared: bool, burning: bool, poisoned: bool, marked: bool, slowed: bool) -> Color:
	if frozen:
		return FROZEN_TINT
	if pinned:
		return PIN_TINT
	if feared:
		return Color(1, 1, 1, 1).lerp(FEAR_TINT, FEAR_BLEND)
	if burning:
		return Color(1, 1, 1, 1).lerp(BURN_TINT, BURN_BLEND)
	if poisoned:
		return Color(1, 1, 1, 1).lerp(POISON_TINT, POISON_BLEND)
	if marked:
		return Color(1, 1, 1, 1).lerp(MARK_TINT, MARK_BLEND)
	if slowed:
		return Color(1, 1, 1, 1).lerp(SLOW_TINT, SLOW_BLEND)
	return Color(1, 1, 1, 1)

## Push the resolved tint to the flash material (no-op before the sprite material exists).
func _refresh_tint() -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("base_tint",
			_resolve_tint(_frozen, _pinned, _fear_time > 0.0, _burn_time > 0.0, _dot_time > 0.0, _vuln_time > 0.0, _slow_time > 0.0))

## Remaining-health fraction (for the above-head bar).
func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func _physics_process(delta: float) -> void:
	if _flash_cd > 0.0:
		_flash_cd -= delta
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta)
		if _health.is_dead():
			return
		if _burn_time <= 0.0:
			_burn_dps = 0.0
			_refresh_tint()

	if _dot_time > 0.0:
		_dot_time -= delta
		take_damage(_dot_dps * delta)
		if _health.is_dead():
			return
		if _dot_time <= 0.0:
			_dot_dps = 0.0
			_refresh_tint()

	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow_factor = 1.0
			_refresh_tint()

	if _vuln_time > 0.0:
		_vuln_time -= delta
		if _vuln_time <= 0.0:
			_vuln_bonus = 0.0
			_refresh_tint()

	if _freeze_time > 0.0:
		_freeze_time -= delta
		if _freeze_time <= 0.0:
			_thaw()

	if _pin_time > 0.0:
		_pin_time -= delta
		if _pin_time <= 0.0:
			_pinned = false
			_refresh_tint()

	if _fear_time > 0.0:
		_fear_time -= delta
		if _fear_time <= 0.0:
			_refresh_tint()

	if _target == null or not is_instance_valid(_target):
		return

	velocity = _desired_velocity() * _slow_factor

	if _knockback != Vector2.ZERO:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	if _frozen or _pinned:
		velocity = Vector2.ZERO

	move_and_slide()
	if not _frozen:
		_act(delta)

	# Bite-and-bounce (Larry 2026-06-21): on contact deal ONE discrete hit, then shove
	# ourselves away from the player so we don't clamp on and grind them down. The existing
	# knockback channel carries the bounce out; the chase brings us back for the next bite.
	# A short cooldown stops one touch from registering multiple hits across frames.
	# (Contact uses the slide collision, not a distance check: move_and_slide de-penetrates
	# us to the sum of the collider radii — 24+20=44 — just outside any small threshold.)
	if _contact_cd > 0.0:
		_contact_cd -= delta
	if _contact_cd <= 0.0 and _touching_player():
		_target.take_damage(touch_damage, self, true)   # attacker=self (Thorns), is_contact=true (Armor)
		var away := _target.global_position.direction_to(global_position)
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		apply_knockback(away * GameConfig.ENEMY_BOUNCE_SPEED)
		_contact_cd = GameConfig.ENEMY_CONTACT_HIT_CD

## Base movement intent (before slow/knockback). Override per enemy. Default = chase the player,
## but if we slid against solid cover last frame, steer tangentially around it (no pathfinding —
## just peel along the obstacle toward the player so a nav-less horde doesn't wedge on a car).
## Night Terror (`onhit_fear`): while feared, the chase vector is simply NEGATED — movement-only,
## no cover-steer — so a terrified enemy visibly reverses and runs (the primary read; no VFX).
func _desired_velocity() -> Vector2:
	var dir := (_target.global_position - global_position).normalized()
	if _fear_time > 0.0:
		return -dir * move_speed
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other != null and other is Node and (other as Node).is_in_group("cover"):
			var tangent := Vector2(-col.get_normal().y, col.get_normal().x)
			if tangent.dot(dir) < 0.0:
				tangent = -tangent
			return (dir + tangent * GameConfig.ENEMY_COVER_STEER).normalized() * move_speed
	return dir * move_speed

## Per-frame action hook (e.g. ranged firing). Default no-op. Called after movement.
func _act(_delta: float) -> void:
	pass

## True if this body's move_and_slide hit the player this frame — a robust contact
## check (a fixed distance failed because collisions de-penetrate us to the sum of the
## collider radii, just outside any small threshold).
func _touching_player() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == _target:
			return true
	return false

func take_damage(amount: float) -> void:
	if _health.is_dead():
		return
	if _vuln_bonus > 0.0:
		amount *= (1.0 + minf(_vuln_bonus, GameConfig.TALENT_VULN_MAX))
	_health.take_damage(amount)
	if _health.is_dead():
		RunStats.add_kill()
		SoundManager.play("die_enemy")   # the one alive->dead transition, whatever damage source caused it
		_drop_gem()
		queue_free()
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())

func _drop_gem() -> void:
	if xp_gem_scene == null:
		return
	var gem = xp_gem_scene.instantiate()
	# Elite/late kills pay proportionally: gem value scales with this enemy's baked
	# max HP over the wave-1 base (capped), so killing the big thing beats runner-farming.
	gem.value = clampi(roundi(max_health / GameConfig.ENEMY_MAX_HEALTH), 1, GameConfig.XP_GEM_VALUE_MAX)
	get_tree().current_scene.add_child(gem)
	gem.global_position = global_position

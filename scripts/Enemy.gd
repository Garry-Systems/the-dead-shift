class_name Enemy
extends CharacterBody2D
## An enemy: walks toward the player, has health, damages the player on contact,
## and drops an XP gem when it dies. Stats are baked once at spawn via configure()
## (the project's "roll once, store forever" pattern) so a wave-8 enemy keeps wave-8
## stats even into wave 9.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const RUNNER_SCENE := preload("res://scenes/Runner.tscn")   # Elites (Splitter): the children it spawns on death
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

## Pack F (v0.1.55): matches this scene's row id in Enemies.gd (e.g. "shambler", "runner") — the
## six Enemy-family scenes all share this ONE script, so a per-scene export is how each tells
## _setup_sprite() which art/enemies/<id>.png to look for. "" (the default) means "no per-type
## sprite" and is itself a valid, permanent choice, not just an unset placeholder.
@export var sprite_id: String = ""

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

# --- Elites (Pack A: Run variety) --- fields are .get-defaulted / left at their neutral default
# below, so a raw or summoned spawn (Splitter children, Hive broods, boss adds) that never gets
# apply_elite() called on it behaves exactly like today — the whole modifier system is additive.
var is_elite := false
var elite_kind := ""            # "" | "armored" | "volatile" | "splitter" | "alpha"
var _alpha_tick := 0.0          # Alpha aura: HAZARD_TICK_INTERVAL-cadence accumulator (never per-frame)
var _elite_buff_speed := 0.0    # incoming Alpha-aura buff (any enemy can receive this, not just elites)
var _elite_buff_dmg := 0.0
var _elite_buff_time := 0.0

## Bakes scaled stats at spawn. Called by the Spawner before/at add_child.
## Cast every Variant out of the dict explicitly to dodge the GDScript typing traps.
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"])
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	_special_mult = float(stats.get("special_mult", 1.0))
	_health = Health.new(max_health)

## Elites (Pack A): promotes this already-configured enemy to an elite of `kind`. Called by the
## Spawner right AFTER configure() (the "post-configure point"), before add_child — scales HP
## (Health.add_max keeps current == max since the enemy hasn't taken a hit yet), remembers the
## kind for take_damage/_drop_gem/_physics_process to read, and adds the family-colored tell
## ring. Never called for Splitter's own children (no elite inheritance) or bosses.
func apply_elite(kind: String) -> void:
	is_elite = true
	elite_kind = kind
	var old_max := max_health
	max_health *= GameConfig.ELITE_HP_MULT
	if _health != null:
		_health.add_max(max_health - old_max)
	var ring := EliteRing.new()
	ring.color = _elite_ring_color(kind)
	add_child(ring)

## Pure: the tell-ring color per modifier family. Static so a probe can verify it headlessly.
static func _elite_ring_color(kind: String) -> Color:
	match kind:
		"armored":
			return PixelTheme.TEXT_DIM   # C3 gray-tan — "metallic"
		"volatile":
			return Hazards.GREEN
		"splitter":
			return PixelTheme.ACCENT     # C4 lavender
		"alpha":
			return Hazards.GOLD
		_:
			return Color(1, 1, 1, 1)

## Elites (Armored): pure damage-reduction math, static so a probe can verify it headlessly.
static func armored_damage(amount: float) -> float:
	return amount * (1.0 - GameConfig.ELITE_ARMORED_DR)

## Elites (Splitter): pure HP math for a splitter's children, static so a probe can verify it
## headlessly. `elite_max_health` is the dying splitter's OWN (already elite-scaled) max_health.
static func splitter_child_hp(elite_max_health: float) -> float:
	return elite_max_health * GameConfig.ELITE_SPLITTER_CHILD_HP_FRAC

## Elites (Splitter): on death, spawns ELITE_SPLITTER_CHILD_COUNT plain Runners at
## splitter_child_hp() of THIS enemy's own max_health — speed/damage come from the current
## wave's normal runner stats (the Enemies registry), only HP is special-cased. Spawned directly
## (never through Spawner._spawn_enemy's elite roll), so a child can never be an elite itself and
## can never re-split.
func _spawn_splitter_children() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var runner_row := {}
	for e in Enemies.all():
		if String(e.get("id", "")) == "runner":
			runner_row = e
			break
	var stats: Dictionary
	if runner_row.is_empty():
		stats = {"max_health": max_health, "move_speed": move_speed, "touch_damage": touch_damage, "special_mult": _special_mult}
	else:
		stats = Enemies.stats_for(runner_row, DifficultyManager.wave)
	stats["max_health"] = splitter_child_hp(max_health)
	for i in GameConfig.ELITE_SPLITTER_CHILD_COUNT:
		var child = RUNNER_SCENE.instantiate()
		child.configure(stats)
		tree.current_scene.add_child(child)
		var ang := TAU * float(i) / float(GameConfig.ELITE_SPLITTER_CHILD_COUNT)
		child.global_position = global_position + Vector2(cos(ang), sin(ang)) * GameConfig.ELITE_SPLITTER_CHILD_OFFSET

## Elites (Alpha aura): buffs this enemy's speed/damage for `duration`s — strongest-wins,
## refreshed (same merge shape as apply_slow/apply_vulnerable). Any enemy can receive this (not
## just elites) — the Alpha's escort, matching the design's "enemies within 300px" wording.
func apply_elite_buff(speed_pct: float, dmg_pct: float, duration: float) -> void:
	_elite_buff_speed = maxf(_elite_buff_speed, speed_pct)
	_elite_buff_dmg = maxf(_elite_buff_dmg, dmg_pct)
	_elite_buff_time = maxf(_elite_buff_time, duration)

## Current damage multiplier from an Alpha's aura buff (1.0 = none). Read at every damage-
## dealing site an elite might reach (this enemy's own contact bite + RangedEnemy's projectile).
func elite_damage_mult() -> float:
	return 1.0 + _elite_buff_dmg

## Elites (Alpha): a HAZARD_TICK_INTERVAL-cadence re-apply-with-expiry aura — same idiom as
## Gun._tick_aura_slow — that keeps every enemy within ELITE_ALPHA_RADIUS topped up on a short-
## lived speed/damage buff. When this Alpha dies (queue_free), ticking simply stops and every
## buffed enemy's buff decays on its own within ELITE_ALPHA_BUFF_REFRESH seconds — leak-proof by
## construction, no buffed-set bookkeeping that could itself leak if the Alpha died mid-frame.
func _tick_alpha_aura(delta: float) -> void:
	_alpha_tick += delta
	if _alpha_tick < GameConfig.HAZARD_TICK_INTERVAL:
		return
	_alpha_tick = 0.0
	var r2 := GameConfig.ELITE_ALPHA_RADIUS * GameConfig.ELITE_ALPHA_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_method("apply_elite_buff"):
			if (e as Node2D).global_position.distance_squared_to(global_position) <= r2:
				e.apply_elite_buff(GameConfig.ELITE_ALPHA_SPEED_PCT, GameConfig.ELITE_ALPHA_DMG_PCT, GameConfig.ELITE_ALPHA_BUFF_REFRESH)

func _ready() -> void:
	add_to_group("enemies")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:                       # spawned without configure() -> base stats
		_health = Health.new(max_health)
	_setup_sprite()
	_setup_flash()
	_health_bar = EnemyHealthBar.new()
	_health_bar.position = Vector2(0, -28)
	_health_bar.z_index = 1
	add_child(_health_bar)

## Pack F (v0.1.55, staged rollout): swaps in this type's art/enemies/<sprite_id>.png if it
## exists; otherwise leaves the Sprite2D exactly as the .tscn baked it — the already-shipped
## shared enemy.png/ranged_enemy.png — so an enemy without art keeps rendering identically to
## before this pack. Native canvas size (GameConfig.SPRITE_ENEMY_PX) matches the old shared
## texture's, so no scale change is needed on swap (unlike BossBase's bigger 48px canvas).
func _setup_sprite() -> void:
	if sprite_id == "":
		return
	var path := "res://art/enemies/%s.png" % sprite_id
	if not ResourceLoader.exists(path):
		return
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null:
		spr.texture = load(path)

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

	if _elite_buff_time > 0.0:
		_elite_buff_time -= delta
		if _elite_buff_time <= 0.0:
			_elite_buff_speed = 0.0
			_elite_buff_dmg = 0.0

	if elite_kind == "alpha":
		_tick_alpha_aura(delta)

	if _target == null or not is_instance_valid(_target):
		return

	velocity = _desired_velocity() * _slow_factor * (1.0 + _elite_buff_speed)

	# Night Terror (`onhit_fear`): enforced HERE at the base, like the frozen/pin zeroing below,
	# so a subclass _desired_velocity override (RangedEnemy's standoff-keeping) can't bypass it —
	# every feared enemy flees directly away from the player. Movement-only: _act still runs, so
	# a feared spitter keeps firing over its shoulder while it runs.
	if _fear_time > 0.0:
		var flee := (global_position - _target.global_position).normalized()
		if flee == Vector2.ZERO:
			flee = Vector2.RIGHT
		velocity = flee * move_speed * _slow_factor * (1.0 + _elite_buff_speed)

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
		_target.take_damage(touch_damage * elite_damage_mult(), self, true)   # attacker=self (Thorns), is_contact=true (Armor)
		var away := _target.global_position.direction_to(global_position)
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		apply_knockback(away * GameConfig.ENEMY_BOUNCE_SPEED)
		_contact_cd = GameConfig.ENEMY_CONTACT_HIT_CD

## Base movement intent (before slow/knockback). Override per enemy. Default = chase the player,
## but if we slid against solid cover last frame, steer tangentially around it (no pathfinding —
## just peel along the obstacle toward the player so a nav-less horde doesn't wedge on a car).
## (Fear does NOT live here — it's enforced in _physics_process, like frozen/pin, so subclass
## overrides of this method are automatically covered.)
func _desired_velocity() -> Vector2:
	var dir := (_target.global_position - global_position).normalized()
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
	if elite_kind == "armored":
		amount = armored_damage(amount)
	if _vuln_bonus > 0.0:
		amount *= (1.0 + minf(_vuln_bonus, GameConfig.TALENT_VULN_MAX))
	_health.take_damage(amount)
	if _health.is_dead():
		RunStats.add_kill()
		if RunStats.coins_per_kill > 0.0:   # Pack E: the Janitor's passive flat coin-per-kill bonus
			RunStats.add_coins(int(RunStats.coins_per_kill))
		if is_elite:
			RunStats.add_coins(GameConfig.ELITE_COIN_BONUS)
			RunStats.add_elite_kill()
		# Pack C challenge board: "was it burning/poisoned/during a Power Surge at the moment it
		# died" — cheap state checks at the one chokepoint every kill already passes through.
		# _burn_dps/_dot_dps are only zeroed AFTER their tick's take_damage call (see
		# _physics_process), so a kill landed by the DoT tick itself still reads >0 here.
		if _burn_dps > 0.0:
			RunStats.add_fire_kill()
		if _dot_dps > 0.0:
			RunStats.add_poison_kill()
		if NightEvents.power_surge_active(get_tree()):
			RunStats.add_power_surge_kill()
		var moon_coins := NightEvents.blood_moon_coins(get_tree())
		if moon_coins > 0:
			RunStats.add_coins(moon_coins)
		SoundManager.play("die_enemy")   # the one alive->dead transition, whatever damage source caused it
		_drop_gem()
		if elite_kind == "volatile":
			EliteVolatileBlast.spawn(global_position,
				GameConfig.EXPLODER_BLAST_DAMAGE * GameConfig.ELITE_VOLATILE_MULT * _special_mult,
				GameConfig.EXPLODER_BLAST_RADIUS * GameConfig.ELITE_VOLATILE_MULT, get_tree())
		elif elite_kind == "splitter":
			_spawn_splitter_children()
		queue_free()
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())

func _drop_gem() -> void:
	if xp_gem_scene == null:
		return
	var gem = xp_gem_scene.instantiate()
	# Elite/late kills pay proportionally: gem value scales with this enemy's baked
	# max HP over the wave-1 base (capped), so killing the big thing beats runner-farming.
	var value := roundi(max_health / GameConfig.ENEMY_MAX_HEALTH)
	if is_elite:
		value = roundi(value * GameConfig.ELITE_GEM_VALUE_MULT)
	value = roundi(value * NightEvents.gem_value_mult(get_tree()))   # Fog Bank: x2 while active
	gem.value = clampi(value, 1, GameConfig.XP_GEM_VALUE_MAX)
	get_tree().current_scene.add_child(gem)
	gem.global_position = global_position

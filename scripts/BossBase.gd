class_name BossBase
extends CharacterBody2D
## Base class for all bosses. Carries the generic boss behavior (scaled stats, health, hit
## flash, incendiary burn, contact damage, chase, death reward) AND a phase/pattern engine.
## A concrete boss is just a .tscn (Sprite + Collision + the two scene exports) plus a script
## that overrides _build_phases(). It is in the "enemies" group (bullets/auto-aim hit it) and
## the "boss" group (the HUD shows its health bar).

const FLASH_SHADER := preload("res://shaders/flash.gdshader")

@export var xp_gem_scene: PackedScene
@export var relic_pickup_scene: PackedScene

var max_health := GameConfig.BOSS_BASE_HP
var move_speed := GameConfig.BOSS_MOVE_SPEED
var touch_damage := GameConfig.BOSS_TOUCH_DAMAGE
var special_mult := 1.0        # wave-growth factor patterns apply to their flat damage numbers

## True while a Charge-style pattern (see ChargeDash) is driving this body directly via its own
## velocity + move_and_slide (e.g. THE NIGHT STOCKER / THE COURIER dashing at the player's
## position-at-windup). BossBase's own chase-and-touch-damage stands down while this is true so
## the two don't fight over velocity on the same physics tick; the pattern clears it when the
## dash ends. Default false — every existing boss is unaffected.
var charging := false

var _health: Health
var _target: Player
var _burn_dps := 0.0
var _burn_time := 0.0
var _flash_mat: ShaderMaterial
var _dead := false     # set by _die() before queue_free (which is deferred) so a same-frame
						# post-mortem _physics_process (e.g. from the boss's own burn tick) bails

## Pack F (v0.1.55): true once this boss's real art/bosses/<boss_id()>.png sprite is loaded.
## Manager/NightStocker/Fryer/Courier's _draw() overlays (tie, cap+boxes, basket, helmet+
## satchel) check this and skip themselves once true — those props are baked into the real
## sprite art instead, so drawing both would double them up.
var _sprite_loaded := false

# --- Phase / pattern engine ---
var phases: Array = []     # built by _build_phases(); phases[0].at must be 1.0
var _phase_idx := -1
var _speed_mult := 1.0
var _pat_clock := 0.0      # counts down to the next pattern cast
var _pat_i := 0            # round-robin index into the current phase's patterns

## Bakes scaled stats at spawn (called by the Spawner). Applies the per-boss HP multiplier.
func configure(stats: Dictionary) -> void:
	max_health = float(stats["max_health"]) * _hp_mult()
	move_speed = float(stats["move_speed"])
	touch_damage = float(stats["touch_damage"])
	special_mult = float(stats.get("special_mult", 1.0))
	_health = Health.new(max_health)

## Per-boss HP multiplier on the wave-scaled base (1.0 = the brute). Override per boss.
func _hp_mult() -> float:
	return 1.0

## Per-boss base flash tint (default white = show the C3 enemy art). Override to recolor.
func _base_tint() -> Color:
	return Color(1.0, 1.0, 1.0, 1.0)

## Override per boss: this boss's BOSS_ID (matches its Bosses.gd registry row). Used by the HUD
## to look up the display name for the boss bar. Default "" (no name shown).
func boss_id() -> String:
	return ""

## Override per boss: returns the phase table. Each entry is a Dictionary:
##   { "at": float,           # enter when health_fraction() <= at; phases[0].at MUST be 1.0
##     "patterns": Array,     # entries: { "scene": PackedScene, "params": Dictionary }
##     "cadence": float,      # seconds between casts (default 4.0)
##     "speed_mult": float,   # chase-speed multiplier this phase (default 1.0)
##     "on_enter": Callable } # optional one-shot when the phase begins
func _build_phases() -> Array:
	return []

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
	# NOTE: bosses rely on move_and_slide alone to slide along cover toward the player —
	# no anti-wedge tangential steering like Enemy._desired_velocity (phone test = feel check).
	_target = get_tree().get_first_node_in_group("player") as Player
	if _health == null:
		_health = Health.new(max_health)
	_setup_sprite()
	_setup_flash()
	phases = _build_phases()
	_enter_phase(0)

## Pack F (v0.1.55, staged rollout): swaps in art/bosses/<boss_id()>.png if it exists, scaling
## the Sprite2D down by SPRITE_ENEMY_PX/SPRITE_BOSS_PX so the bigger 48px canvas reads at the
## SAME on-screen size the .tscn's hand-tuned scale already achieves with the old shared 32px
## enemy.png. If the sprite doesn't exist, the Sprite2D is left exactly as the .tscn baked it —
## the already-shipped shared texture — so a boss without art renders identically to before.
func _setup_sprite() -> void:
	var id := boss_id()
	if id == "":
		return
	var path := "res://art/bosses/%s.png" % id
	if not ResourceLoader.exists(path):
		# Every boss ships with art now — a miss means the sprite generator's hand-kept
		# boss list (home repo gen_palette_sprites.py BOSS_SPRITES) drifted from Bosses.gd.
		# Warn loudly instead of silently falling back to the generic texture.
		push_warning("BossBase: no sprite for boss id '%s' — regenerate sprites (generator list drift?)" % id)
		return
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	spr.texture = load(path)
	spr.scale *= GameConfig.SPRITE_ENEMY_PX / GameConfig.SPRITE_BOSS_PX
	_sprite_loaded = true

func _enter_phase(i: int) -> void:
	if i < 0 or i >= phases.size():
		return
	_phase_idx = i
	var ph: Dictionary = phases[i]
	_speed_mult = float(ph.get("speed_mult", 1.0))
	_pat_i = 0
	_pat_clock = float(ph.get("first_delay", GameConfig.BOSS_FIRST_CAST_DELAY))
	var cb = ph.get("on_enter", null)
	if cb is Callable and cb.is_valid():
		cb.call()

func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("base_tint", _base_tint())
	spr.material = _flash_mat

## `_tint` is accepted-and-ignored: the 4 hit sites pass Curb Stomp's boosted-hit tint with one
## shared signature (mirrors Enemy.flash_hit); bosses keep their plain white flash + _base_tint.
func flash_hit(_tint: Color = Color(1, 1, 1, 1)) -> void:
	if _flash_mat == null:
		return
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.12)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func ignite(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _burn_time > 0.0:
		_burn_time -= delta
		take_damage(_burn_dps * delta)
		if _dead:
			return

	if _target == null or not is_instance_valid(_target):
		return

	# Advance through phases whose threshold we've crossed (while, in case of a big burst).
	while _phase_idx + 1 < phases.size() and health_fraction() <= float(phases[_phase_idx + 1].get("at", 0.0)):
		_enter_phase(_phase_idx + 1)

	# Chase + contact damage. Contact uses the actual slide collision (robust vs collider
	# radii / sprite scale), matching the 2026-06-14 fix in Enemy/Boss. Skipped while a Charge
	# pattern owns this body's velocity/move_and_slide (see `charging`) — it has its own
	# distance-based hit-once contact damage instead of this continuous per-frame touch damage.
	if not charging:
		var dir := (_target.global_position - global_position).normalized()
		velocity = dir * (move_speed * _speed_mult)
		move_and_slide()
		if _touching_player():
			# is_contact=true so Armor reduces boss touch damage; attacker stays null ON PURPOSE —
			# Thorns is bite-only (a per-frame reflect on this continuous touch would shred bosses).
			_target.take_damage(touch_damage * delta, null, true)

	# Cast the next pattern when the clock runs out.
	_pat_clock -= delta
	if _pat_clock <= 0.0:
		_cast_next_pattern()
		var ph: Dictionary = phases[_phase_idx]
		_pat_clock = float(ph.get("cadence", 4.0))

func _cast_next_pattern() -> void:
	if _phase_idx < 0 or _phase_idx >= phases.size():
		return
	var pats: Array = phases[_phase_idx].get("patterns", [])
	if pats.is_empty():
		return
	var entry: Dictionary = pats[_pat_i % pats.size()]
	_pat_i += 1
	var p = (entry["scene"] as PackedScene).instantiate()
	# Position BEFORE add_child so the pattern's _ready (and any subclass _ready) sees the
	# real spawn point, not the scene origin. setup() runs after and may reposition further.
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.setup(self, _target, entry.get("params", {}))

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
	_health.take_damage(amount)
	if _health.is_dead():
		_die()

func _die() -> void:
	_dead = true
	_reward()
	queue_free()

func _reward() -> void:
	RunStats.add_boss()
	# In Boss Rush bosses die constantly, so its rewards are toned down vs Endless.
	var boss_rush: bool = RunConfig.mode == "boss_rush"
	# XP burst — scattered around the boss, enough to pop a level-up (fewer in Boss Rush).
	if xp_gem_scene != null:
		var gems := GameConfig.BOSS_XP_REWARD
		if boss_rush:
			gems = int(gems * GameConfig.BOSS_RUSH_REWARD_MULT)
		for i in gems:
			var gem = xp_gem_scene.instantiate()
			get_tree().current_scene.add_child(gem)
			var a := randf_range(0.0, TAU)
			gem.global_position = global_position + Vector2(cos(a), sin(a)) * randf_range(8.0, 64.0)
	# Heal — a strong top-up in Endless (BOSS_KILL_HEAL_FRAC); smaller in Boss Rush.
	if _target and is_instance_valid(_target):
		if boss_rush:
			_target.heal(_target.max_hp() * GameConfig.BOSS_RUSH_HEAL_FRAC)
		else:
			# Endless: a strong top-up, no longer a full reset — late bosses stay a
			# risk/reward spike instead of a free sustain valve.
			_target.heal(_target.max_hp() * GameConfig.BOSS_KILL_HEAL_FRAC)
	# Relic drop: always in Endless; only sometimes in Boss Rush so you aren't flooded.
	if not boss_rush or randf() < GameConfig.BOSS_RUSH_RELIC_CHANCE:
		var bar := get_tree().get_first_node_in_group("relic_bar")
		if bar != null and relic_pickup_scene != null:
			var id: String = bar.call("roll_drop")
			if id != "":
				var pickup = relic_pickup_scene.instantiate()
				pickup.relic_id = id
				get_tree().current_scene.add_child(pickup)
				pickup.global_position = global_position

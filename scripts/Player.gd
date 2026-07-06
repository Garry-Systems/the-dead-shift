class_name Player
extends CharacterBody2D
## The player avatar: movement (keyboard for desktop testing + joystick for mobile),
## health, contact damage, and a double-tap dash.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")
const HURT_FLASH_COOLDOWN := 0.18   # min gap between red pulses (contact damage is per-frame)

## Ryan's 8 directional rotations, indexed by 45° sector of the facing angle.
## Godot 2D angles: +x = east, +y = south (down), so the order below maps
## round(angle/45) -> sprite. Index 0 = east, going clockwise.
const DIR_TEX: Array[Texture2D] = [
	preload("res://art/ryan/east.png"),        # 0
	preload("res://art/ryan/south-east.png"),  # 1
	preload("res://art/ryan/south.png"),       # 2
	preload("res://art/ryan/south-west.png"),  # 3
	preload("res://art/ryan/west.png"),        # 4
	preload("res://art/ryan/north-west.png"),  # 5
	preload("res://art/ryan/north.png"),       # 6
	preload("res://art/ryan/north-east.png"),  # 7
]

var _health := Health.new(GameConfig.PLAYER_MAX_HEALTH)
var _dash := DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN)
var _last_move_dir := Vector2.RIGHT
var _has_moved := false          # true after the first move input (gates spawn fire)
var _last_tap_time := -999.0
var _last_input_time := -999.0   # de-dupes the same-frame emulated touch/mouse pair
var _is_dead := false

## Set by the VirtualJoystick. Vector2.ZERO means "no joystick input, use keyboard".
var joystick_direction := Vector2.ZERO

## Emitted each time the player gains a level (the upgrade UI listens for this).
signal leveled_up
## Emitted once when the player dies (the GameOver overlay listens for this).
signal died

## Mutable per-run stats (upgrade cards modify these).
var move_speed := GameConfig.PLAYER_MOVE_SPEED
var health_regen := GameConfig.PLAYER_HEALTH_REGEN
var xp_mult := 1.0             # "Fast Learner" card: multiplies every add_xp() amount (stacks)

## Pack 2 defensive upgrade-card state.
var _armor_mult := 1.0         # "Iron Skin" card: multiplies contact/bite damage taken (stacks down, e.g. 0.85 x 0.85)
var _dodge_chance := 0.0       # "Quick Step" card: chance (0..DODGE_CAP) to ignore any hit outright
var _thorns_mult := 0.0        # thorns card: reflected damage = incoming bite amount x this (0 = no thorns)
var has_second_wind := false   # true once the Second Wind card has been taken this run
var second_wind_used := false  # true once Second Wind has already saved this run (never again)

## The player's weapon node (gun upgrade cards modify it). Set in _ready.
var gun: Gun

## Progression (Phase 2). Gems grant XP; crossing a threshold levels you up.
var xp := 0
var level := 0
var pickup_radius := GameConfig.PICKUP_RADIUS
var _xp_to_next := 0
var _flash_mat: ShaderMaterial
var _flash_cd := 0.0
var _sprite: Sprite2D
var _facing := 2          # index into DIR_TEX; 2 = south (faces the camera at start)
var _fire_lock_time := 0.0   # boss "jam" debuff: gun can't fire while > 0
var _dash_ability := ""      # special dash effect for the chosen character ("" = plain dash); set by Main
var _ability_cd := 0.0       # Ryan's purge cooldown remaining (seconds); the dash movement is unaffected
## Boss "slow" debuff: one {factor, remaining} entry per source (see apply_slow) instead of a
## single merged factor/time pair — avoids mixing one source's strength with another source's
## duration. Live entries are ticked/pruned in _physics_process; effective move-speed multiplier
## is the MIN factor among them (see _current_slow_factor), 1.0 when the list is empty.
var _slow_stacks: Array = []

func _ready() -> void:
	add_to_group("player")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover (|= safe: keeps the default bit 1)
	_xp_to_next = XpCurve.xp_for_level(0)
	gun = get_node_or_null("Gun") as Gun
	_setup_flash()

## Per-instance flash material set to flash RED — the "I'm taking damage" indicator.
func _setup_flash() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		return
	_sprite = spr
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2, 1.0))
	spr.material = _flash_mat

func _physics_process(delta: float) -> void:
	_dash.tick(delta)
	if _flash_cd > 0.0:
		_flash_cd -= delta
	if _ability_cd > 0.0:
		_ability_cd -= delta
	if _fire_lock_time > 0.0:
		_fire_lock_time -= delta
	_tick_slow_stacks(delta)

	var dir := joystick_direction
	if dir == Vector2.ZERO:
		dir = _keyboard_dir()

	if dir != Vector2.ZERO:
		_last_move_dir = dir.normalized()
		_has_moved = true

	# Aim = facing = the last direction we moved. The sprite snaps to the nearest
	# of 8 poses; the gun fires at the precise angle (smooth 360 aim).
	_face(_last_move_dir)

	var speed := GameConfig.DASH_SPEED if _dash.is_dashing() else (move_speed * _current_slow_factor())
	var move_dir := _last_move_dir if _dash.is_dashing() else dir

	velocity = move_dir * speed

	# Drive the gun: fire in our faced direction, but hold fire while moving
	# (stop-to-shoot) and until the player has given a first move input (so we
	# don't auto-empty the mag facing right at spawn).
	if gun != null:
		gun.aim_direction = _last_move_dir
		gun.hold_fire = (GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO) or not _has_moved or _fire_lock_time > 0.0

	move_and_slide()

	if health_regen > 0.0:
		_health.heal(health_regen * delta)

## Swaps Ryan's sprite to the directional rotation nearest the move vector.
func _face(dir: Vector2) -> void:
	if _sprite == null:
		return
	var idx := int(round(rad_to_deg(dir.angle()) / 45.0)) % 8
	if idx < 0:
		idx += 8
	if idx != _facing:
		_facing = idx
		_sprite.texture = DIR_TEX[idx]

## Reads WASD / arrow keys directly (no Input Map setup needed for Phase 1 testing).
func _keyboard_dir() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	return d.normalized()

func _unhandled_input(event: InputEvent) -> void:
	# Double-tap (touch) OR double-click (mouse) triggers a dash.
	var tapped: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not tapped:
		return

	var now := Time.get_ticks_msec() / 1000.0
	# With touch<->mouse emulation on, one physical press can arrive as BOTH a touch and a
	# mouse event the same frame. Ignore the second so a single tap isn't counted twice.
	if now - _last_input_time < 0.05:
		return
	_last_input_time = now

	if now - _last_tap_time <= GameConfig.DASH_DOUBLE_TAP_WINDOW:
		if _dash.start_dash():
			_on_dash_started()
		_last_tap_time = -999.0  # consume, so a 3rd tap doesn't chain
	else:
		_last_tap_time = now

## Set by Main at run start from the chosen character. "shockwave" = Alstar's dash blast.
func set_dash_ability(ability: String) -> void:
	_dash_ability = ability

## Runs the moment a dash actually begins (gated by the dash cooldown). Plain characters do
## nothing extra; a character with a special dash ability resolves it here.
func _on_dash_started() -> void:
	SoundManager.play("dash")
	match _dash_ability:
		"shockwave":
			_spawn_shockwave()
		"purge":
			_purge_projectiles()

## Alstar Tuck: a radial blast at the dash origin — push + damage + the gun's on-hit talents.
func _spawn_shockwave() -> void:
	var sw := Shockwave.new()
	get_tree().current_scene.add_child(sw)
	sw.global_position = global_position
	sw.blast(GameConfig.CHAR_ALSTAR_SHOCK_RADIUS, GameConfig.CHAR_ALSTAR_SHOCK_DAMAGE,
		GameConfig.CHAR_ALSTAR_SHOCK_FORCE, gun, self)

## Ryan Ace: wipe every enemy projectile off the map, instant-reload an equipped AK, and fire
## a white screen flash + pulse ring. On its own cooldown — the dash (movement) still happens
## while it's recharging, it just doesn't purge.
func _purge_projectiles() -> void:
	if _ability_cd > 0.0:
		return
	_ability_cd = GameConfig.CHAR_RYAN_ABILITY_COOLDOWN
	SoundManager.play("purge")
	for p in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(p):
			p.queue_free()
	if gun != null and gun.weapon_id == "ak47":
		gun.instant_reload()
	get_tree().current_scene.add_child(ScreenFlash.new())   # full-screen white flash
	var fx := Shockwave.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	fx.flash(GameConfig.CHAR_RYAN_PURGE_FX_RADIUS)

## --- Dash-ability readouts for the HUD ---

## True if this run's character has the purge dash ability (gates the HUD cooldown readout).
func has_purge_ability() -> bool:
	return _dash_ability == "purge"

## Seconds left on the purge cooldown (0 = ready).
func ability_cooldown_remaining() -> float:
	return maxf(_ability_cd, 0.0)

## True while a dash is currently in progress. No dash-start signal exists, so the
## first-run hint controller polls this to detect the player's first dash.
func is_dashing() -> bool:
	return _dash.is_dashing()

## Called by enemies while they touch the player. `attacker` (default null) is the biter,
## passed ONLY from Enemy's contact-bite site (Thorns needs someone to reflect damage onto);
## every other caller (bosses, hazards, patterns) leaves it null and is unaffected. `is_contact`
## marks a melee bite/touch hit (vs. a ranged/AoE hit) — Armor and Thorns key off it.
func take_damage(amount: float, attacker = null, is_contact: bool = false) -> void:
	# Thorns fires off the raw incoming bite damage, independent of dodge/armor below (a spike
	# that jabs back whether or not the bite itself lands). Guard the attacker being alive so a
	# same-frame freed/despawned biter can't be reflected onto.
	if is_contact and _thorns_mult > 0.0 and attacker != null and is_instance_valid(attacker) and attacker.has_method("take_damage"):
		attacker.take_damage(amount * _thorns_mult)

	# Dodge rolls BEFORE any damage is applied: a dodged hit deals no damage and no hurt flash.
	if _dodge_chance > 0.0 and randf() < _dodge_chance:
		return

	if is_contact:
		amount *= _armor_mult

	_health.take_damage(amount)
	_hurt_flash()
	if amount > 0.0:
		CameraShake.add_trauma(GameConfig.SHAKE_TRAUMA_PLAYER_HURT)   # Pack D

	# Dead Man's Switch (onhurt_nova): retaliation blast after damage lands. Gun-held ICD; a
	# no-op on a weapon without the talent (try_hurt_nova checks talent_payload itself).
	if amount > 0.0 and gun != null and is_instance_valid(gun):
		gun.try_hurt_nova(self)

	if _health.is_dead():
		if has_second_wind and not second_wind_used:
			second_wind_used = true
			_health.heal(_health.maxhp * GameConfig.SECOND_WIND_HP_FRAC)   # current is 0 here (just clamped dead), so this sets it exactly
			get_tree().current_scene.add_child(ScreenFlash.new())
			return
		_die()

## Throttled red pulse — contact damage calls this every frame, so we rate-limit
## it to a periodic "ouch" rather than a solid red wash.
func _hurt_flash() -> void:
	if _flash_mat == null or _flash_cd > 0.0:
		return
	_flash_cd = HURT_FLASH_COOLDOWN
	SoundManager.play("player_hurt")   # inherits the same cooldown gate as the flash above
	_flash_mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.15)

func _set_flash(v: float) -> void:
	if _flash_mat != null:
		_flash_mat.set_shader_parameter("flash", v)

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	get_tree().paused = true
	died.emit()

## Grants XP (scaled by xp_mult, "Fast Learner" card) and resolves any resulting level-ups.
func add_xp(amount: int) -> void:
	amount = int(round(amount * xp_mult))
	xp += amount
	while xp >= _xp_to_next:
		xp -= _xp_to_next
		level += 1
		_xp_to_next = XpCurve.xp_for_level(level)
		_on_level_up()

## XP needed to reach the next level (used by the HUD bar).
func xp_to_next() -> int:
	return _xp_to_next

## Health readouts for the HUD (keeps _health private).
func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

func hp() -> float:
	return _health.current if _health != null else 0.0

func max_hp() -> float:
	return _health.maxhp if _health != null else 0.0

## Restores the player to full health (called by a boss death reward).
func full_heal() -> void:
	_health.heal(_health.maxhp)

## Talent hook (Bloodthirst lifesteal): restore a flat amount, clamped to max by Health.
func heal(amount: float) -> void:
	if _health != null:
		_health.heal(amount)

## Talent VFX (Bloodthirst/Leech/Mosquito lifesteal): a 1-frame rim pulse in `color` on the
## sprite — the LeechMote's landing tell. Independent of the hurt-flash shader channel (no
## gameplay meaning, so it never fights or gets throttled by the damage-taken flash cooldown).
func lifesteal_blip(color: Color) -> void:
	if _sprite == null:
		return
	_sprite.modulate = color
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.1)

## Relic hook: raise (or lower, when removed) max health. Reversible via a negative amount.
func relic_add_max_health(amount: float) -> void:
	_health.add_max(amount)

func _on_level_up() -> void:
	leveled_up.emit()

## --- Upgrade hooks (called by UpgradeApply.apply) ---
func upgrade_move_speed(pct: float) -> void:
	move_speed *= (1.0 + pct)

func upgrade_max_health(amount: float) -> void:
	_health.add_max(amount)

func upgrade_regen(amount: float) -> void:
	health_regen += amount

func upgrade_pickup_radius(pct: float) -> void:
	pickup_radius *= (1.0 + pct)

## "Iron Skin": cuts contact/bite damage taken. Multiplicative — stacks compound (0.85 x 0.85 ...).
func upgrade_armor(pct: float) -> void:
	_armor_mult *= (1.0 - pct)

## "Quick Step": raises the flat chance to ignore any hit outright. Capped at GameConfig.DODGE_CAP.
func upgrade_dodge(pct: float) -> void:
	_dodge_chance = minf(_dodge_chance + pct, GameConfig.DODGE_CAP)

## Dash-cooldown card: shrinks the dash's cooldown (multiplicative, stacks).
func upgrade_dash_cooldown(pct: float) -> void:
	_dash.upgrade_cooldown(pct)

## "Fast Learner": raises the XP multiplier applied in add_xp(). Multiplicative, stacks.
func upgrade_xp_gain(pct: float) -> void:
	xp_mult *= (1.0 + pct)

## Thorns: enemies that bite the player take `mult` x the bite's own raw damage back. Additive
## across stacks (two cards = 2x + 2x = 4x reflected).
func upgrade_thorns(mult: float) -> void:
	_thorns_mult += mult

## Second Wind: arms the once-per-run "cheat death" save (see take_damage). Re-picking this
## card is excluded from the pool once used — see Upgrades.player_cards().
func upgrade_second_wind() -> void:
	has_second_wind = true

## --- Boss debuff hooks (called by the DebuffApplier pattern) ---

## "Jam": the gun can't fire for `duration`s even while standing still. Longest wins.
func apply_fire_lock(duration: float) -> void:
	_fire_lock_time = maxf(_fire_lock_time, duration)

## "Slow": cut move speed by `factor` (0..1) for `duration`s. Each application is tracked as its
## own source instead of merging into one shared factor/time pair, so a weaker-but-longer source
## can't inherit a stronger source's multiplier (or vice versa) — see _current_slow_factor.
func apply_slow(factor: float, duration: float) -> void:
	_slow_stacks.append({ "factor": clampf(1.0 - factor, 0.1, 1.0), "remaining": duration })

## Decrements every live slow-stack entry's remaining time and drops expired ones (remaining <= 0).
func _tick_slow_stacks(delta: float) -> void:
	var i := _slow_stacks.size() - 1
	while i >= 0:
		var entry: Dictionary = _slow_stacks[i]
		var remaining: float = float(entry["remaining"]) - delta
		if remaining <= 0.0:
			_slow_stacks.remove_at(i)
		else:
			entry["remaining"] = remaining
		i -= 1

## Effective move-speed multiplier: the strongest (MIN factor) among all live slow sources,
## or 1.0 (unslowed) once the list is empty.
func _current_slow_factor() -> float:
	var f := 1.0
	for entry in _slow_stacks:
		f = minf(f, float(entry["factor"]))
	return f

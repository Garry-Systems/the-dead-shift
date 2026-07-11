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
# EMPLOYEE BENEFITS (Pack A) STRETCH BREAKS: Benefits is save-backed and static, so reading it
# at field-init time (before Characters.apply_base runs) is fine — see DashState._init.
var _dash := DashState.new(GameConfig.DASH_DURATION, GameConfig.DASH_COOLDOWN * Benefits.dash_cd_mult())
var _last_move_dir := Vector2.RIGHT
var _has_moved := false          # true after the first move input (gates spawn fire)
var _last_tap_time := -999.0
var _last_input_time := -999.0   # de-dupes the same-frame emulated touch/mouse pair
var _is_dead := false
var _shove_velocity := Vector2.ZERO   # external knockback (Karen's ScreamRing); decays via shove_step, never permanent

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

## EMPLOYEE BENEFITS (Pack A) UNION REP: the once-per-run benefits revive, fires BEFORE Second
## Wind (see take_damage). Deliberately NOT set from this field-init default — Characters.apply_base
## (the spawn-config pass) sets it from Benefits.has_revive() so a save bought mid-session applies
## next run predictably, the same reasoning has_second_wind/second_wind_used already follow.
var _union_rep_available := false
var _revive_invuln_time := 0.0   # seconds remaining of post-UNION-REP-revive invulnerability (no
                                  # pre-existing spawn-protection mechanism was found anywhere in
                                  # this codebase — grepped invuln/spawn_protect/_protect across
                                  # every .gd file and found nothing to reuse; this is a new,
                                  # minimal timer, gated the same way _fire_lock_time is)

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
## Boss "slow" debuff: one {factor, remaining} entry per source (see apply_slow) instead of a
## single merged factor/time pair — avoids mixing one source's strength with another source's
## duration. Live entries are ticked/pruned in _physics_process; effective move-speed multiplier
## is the MIN factor among them (see _current_slow_factor), 1.0 when the list is empty.
var _slow_stacks: Array = []

## ONE OF THEM (Zombie Bob, Company Equipment v0.1.70): seconds remaining of "the horde forgets
## Bob exists" — the truth Enemy._target_ghosted() reads every frame off THIS player instance
## (not the caster-only AbilityController). maxf-merge (see set_ghost), same idiom as
## _grant_invuln/apply_fire_lock — a recast before expiry extends, never shortens/resets.
var _ghost_time := 0.0

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
	if _fire_lock_time > 0.0:
		_fire_lock_time -= delta
	if _revive_invuln_time > 0.0:
		_revive_invuln_time -= delta
	if _ghost_time > 0.0:
		_ghost_time -= delta
	_tick_slow_stacks(delta)
	# Ring indicator redraw: unconditional every physics frame rather than gated on
	# _ghost_time>0, so the frame the window expires still redraws (clearing the ring) with no
	# separate "off" transition to track. _draw() itself is the sole no-op gate (see below).
	queue_redraw()

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

	# External shove rides on top of input; while it's live, velocity != ZERO also holds fire
	# via the stop-to-shoot gate below — a scream knocking you out of your firing stance is
	# the intended disruption, not a bug.
	if _shove_velocity != Vector2.ZERO:
		velocity += _shove_velocity
		_shove_velocity = shove_step(_shove_velocity, GameConfig.PLAYER_SHOVE_DECAY, delta)

	# Drive the gun: fire in our faced direction, but hold fire while moving
	# (stop-to-shoot) and until the player has given a first move input (so we
	# don't auto-empty the mag facing right at spawn).
	if gun != null:
		gun.aim_direction = _last_move_dir
		gun.hold_fire = (GameConfig.SHOOT_ONLY_WHILE_STILL and velocity != Vector2.ZERO) or not _has_moved or _fire_lock_time > 0.0

	move_and_slide()

	if health_regen > 0.0:
		heal(health_regen * delta)

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
	RelicEffects.on_dash_started(self)   # Relics Overhaul: static_soles electric trail
	match _dash_ability:
		"shockwave":
			_spawn_shockwave()
		"ak_reload":
			if gun != null and gun.weapon_id == "ak47":
				gun.instant_reload()
		"slick":
			_spawn_slick()
		"mine":
			_spawn_delivery_mine()

## Alstar Tuck: a radial blast at the dash origin — push + damage + the gun's on-hit talents.
func _spawn_shockwave() -> void:
	var sw := Shockwave.new()
	get_tree().current_scene.add_child(sw)
	sw.global_position = global_position
	sw.blast(GameConfig.CHAR_ALSTAR_SHOCK_RADIUS, GameConfig.CHAR_ALSTAR_SHOCK_DAMAGE,
		GameConfig.CHAR_ALSTAR_SHOCK_FORCE, gun, self)

## The Janitor: dash leaves a mop-bucket slick — a HazardZone tuned to hurt NOBODY (dps 0,
## hurts_player false) that only slows enemies standing in it. Rides the SAME shared
## player_pools cap as the Acid Cannon / Bile Spill (cap_player_pools() evicts the oldest
## member of that group first, exactly like Bullet._detonate() / TalentEngine's bile pool).
func _spawn_slick() -> void:
	HazardZone.cap_player_pools(get_tree())
	var cfg := {
		"color": PixelTheme.ACCENT, "dps": 0.0, "radius": GameConfig.CHAR_JANITOR_SLICK_RADIUS,
		"duration": GameConfig.CHAR_JANITOR_SLICK_DURATION,
		"slow": GameConfig.CHAR_JANITOR_SLICK_SLOW, "slow_dur": GameConfig.CHAR_JANITOR_SLICK_SLOW_DUR,
		"stun": 0.0, "chain": 0, "drift": 0.0, "hurts_player": false,
	}
	var zone := HazardZone.new()
	get_tree().current_scene.add_child(zone)
	zone.global_position = global_position
	zone.configure_hazard(cfg)

## The Delivery Girl: dash drops a standard Parting-Gift-style proximity mine. Reuses
## Mine.spawn() directly, so it shares the SAME GameConfig.MAX_PLAYER_MINES cap/group (and
## oldest-eviction) as the Parting Gift talent's own mines — no separate pool.
func _spawn_delivery_mine() -> void:
	Mine.spawn(global_position, GameConfig.CHAR_DELIVERY_MINE_DMG, GameConfig.CHAR_DELIVERY_MINE_RADIUS, get_tree())

## --- Dash state readout ---

## True while a dash is currently in progress. No dash-start signal exists, so the
## first-run hint controller polls this to detect the player's first dash.
func is_dashing() -> bool:
	return _dash.is_dashing()

## Called by enemies while they touch the player. `attacker` (default null) is the biter,
## passed ONLY from Enemy's contact-bite site (Thorns needs someone to reflect damage onto);
## every other caller (bosses, hazards, patterns) leaves it null and is unaffected. `is_contact`
## marks a melee bite/touch hit (vs. a ranged/AoE hit) — Armor and Thorns key off it.
func take_damage(amount: float, attacker = null, is_contact: bool = false) -> void:
	# EMPLOYEE BENEFITS (Pack A) UNION REP: post-revive invulnerability window — total immunity,
	# same shape as the dodge-roll early-return below.
	if _revive_invuln_time > 0.0:
		return
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
		RelicEffects.on_player_hurt(self)   # Relics Overhaul: adrenal_valve dash-cooldown refund

	# Dead Man's Switch (onhurt_nova): retaliation blast after damage lands. Gun-held ICD; a
	# no-op on a weapon without the talent (try_hurt_nova checks talent_payload itself).
	if amount > 0.0 and gun != null and is_instance_valid(gun):
		gun.try_hurt_nova(self)

	if _health.is_dead():
		# UNION REP (Pack A): the benefits revive fires BEFORE Second Wind (spec order) and
		# never in HARDCORE (one-life identity — same flag the heal-gate uses). Sets
		# _health.current directly rather than routing through heal() — revive isn't a heal;
		# Second Wind's own death-save below takes the same direct route (_health.heal() called
		# on the Health object itself, bypassing Player.heal()'s HARDCORE no-op gate), so this
		# matches how Second Wind already works. maxf(1.0, ...) guarantees a revive can never
		# leave current at 0 (which would just re-trigger is_dead() on the next hit).
		if _union_rep_available and not RunConfig.hardcore:
			_union_rep_available = false
			_health.current = maxf(1.0, max_hp() * GameConfig.BENEFIT_REVIVE_HEAL_FRAC)
			_grant_invuln(GameConfig.BENEFIT_REVIVE_INVULN)
			get_tree().current_scene.add_child(ScreenFlash.new())
			return
		# Relics Overhaul (dead_mans_vest): cheat death once per boss cycle, AFTER UNION REP and
		# BEFORE Second Wind (spec order) — a safe no-op when the relic isn't held/instance is gone.
		if RelicEffects.try_vest_save(self):
			return
		if has_second_wind and not second_wind_used:
			second_wind_used = true
			_health.heal(_health.maxhp * GameConfig.SECOND_WIND_HP_FRAC)   # current is 0 here (just clamped dead), so this sets it exactly
			get_tree().current_scene.add_child(ScreenFlash.new())
			return
		_die()

## EMPLOYEE BENEFITS (Pack A) UNION REP: grants (or extends) a window of total damage immunity —
## see the _revive_invuln_time early-return at the top of take_damage(). No pre-existing
## spawn-protection/invulnerability mechanism exists anywhere in this codebase (grepped and
## confirmed empty), so this is the new minimal chokepoint; reuse it for any future invuln source.
func _grant_invuln(seconds: float) -> void:
	_revive_invuln_time = maxf(_revive_invuln_time, seconds)

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

## Restores the player to full health (called by a boss death reward). Routed through heal()
## (Pack G) so HARDCORE's no-op gate covers it too, like every other heal source.
func full_heal() -> void:
	heal(_health.maxhp)

## Talent hook (Bloodthirst lifesteal): restore a flat amount, clamped to max by Health. The
## SINGLE no-op gate HARDCORE mode uses (Pack G, v0.1.58): every live heal source in the game
## routes through here — boss-kill/boss-rush heals (BossBase.gd), lifesteal talents
## (TalentEngine.gd), passive regen (the physics tick above), and full_heal() above — so gating
## just this one function blocks all of them under HARDCORE. Two exceptions bypass this gate by
## writing _health directly instead of calling this wrapper — both moot under HARDCORE by their
## OWN gating, not this one: Second Wind's death-save (_health.heal() called directly in
## take_damage(), below; has_second_wind can never be true on a HARDCORE run — see
## Upgrades.player_cards) and UNION REP's revive (_health.current set directly, same function,
## explicitly gated `not RunConfig.hardcore` since a save-bought benefit isn't card-pool-excluded).
func heal(amount: float) -> void:
	if RunConfig.hardcore:
		return
	# Relics Overhaul (blood_pact): every OTHER heal source disabled while held — the kill-heal
	# itself bypasses this via relic_kill_heal()/_apply_heal() below, not this wrapper.
	if RelicEffects.healing_disabled_except_kills:
		return
	_apply_heal(amount)

## Shared apply: managers_stapler's healing_factor and dead_mans_vest's healing_cap_frac both
## layer UNDER whichever gate let the call through (heal()'s hardcore/blood_pact gates, or
## relic_kill_heal()'s own hardcore-only gate) — so both relics still affect a blood_pact kill-heal
## if somehow held together. Cap only clamps THIS heal's growth: if current was already above the
## cap before this call (e.g. the cap relic was just equipped), it is never forced back down.
func _apply_heal(amount: float) -> void:
	if _health == null:
		return
	var pre := _health.current
	_health.heal(amount * RelicEffects.healing_factor)
	if RelicEffects.healing_cap_frac < 1.0:
		var cap := _health.maxhp * RelicEffects.healing_cap_frac
		_health.current = minf(_health.current, maxf(cap, pre))

## blood_pact: kills heal a sliver — the ONE heal source that survives healing_disabled_except_kills.
## Still hardcore-gated (per the design doc: "healing is already zero" under hardcore covers this too).
func relic_kill_heal(amount: float) -> void:
	if RunConfig.hardcore:
		return
	_apply_heal(amount)

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
## HARDCORE (Pack G fix round, adjudicated): max still grows but current does NOT rise with it —
## "you can build a bigger tank; you can't refill it" — the add_max side of the same rule
## Player.heal()'s no-op gate enforces, keyed off the same RunConfig.hardcore flag.
func relic_add_max_health(amount: float) -> void:
	_health.add_max(amount, not RunConfig.hardcore)

## adrenal_valve (RelicEffects): refunds `seconds` off the dash's current cooldown countdown.
func relic_refund_dash_cooldown(seconds: float) -> void:
	_dash.refund_cooldown(seconds)

## dead_mans_vest (RelicEffects): cheat-death revive at exactly 1 HP. Direct _health write, not
## heal() — mirrors UNION REP's own revive just above (a revive isn't a heal, and
## healing_cap_frac must never clip it back down the instant it lands). Reuses UNION REP's own
## invuln window (BENEFIT_REVIVE_INVULN) — both are "just cheated death" moments; no dedicated
## vest invuln const was authored for this relic.
func relic_vest_revive() -> void:
	_health.current = 1.0
	_grant_invuln(GameConfig.BENEFIT_REVIVE_INVULN)
	get_tree().current_scene.add_child(ScreenFlash.new())

func _on_level_up() -> void:
	leveled_up.emit()

## --- Upgrade hooks (called by UpgradeApply.apply) ---
func upgrade_move_speed(pct: float) -> void:
	move_speed *= (1.0 + pct)

## "Tough Hide" card. HARDCORE (Pack G fix round, adjudicated): max grows, current doesn't —
## same rule as relic_add_max_health above.
func upgrade_max_health(amount: float) -> void:
	_health.add_max(amount, not RunConfig.hardcore)

## Character baseline HP (Characters.apply_base, run start ONLY — e.g. Ryan's "Starts with
## 150 HP"). Deliberately NOT hardcore-gated: it applies at spawn while current == max, before
## any damage exists, so raising current with the new max is the STARTING tank size, not a
## "refill" (the adjudicated rule's rationale). A strict gate here would spawn hardcore Ryan at
## 100/150 with the missing 50 permanently unfillable — a fully dead perk, the same player-trap
## class the hardcore regen-card exclusion removes (see Upgrades.player_cards).
func grant_base_max_health(amount: float) -> void:
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
	# Relics Overhaul (rubber_soles): full slow immunity — static flag read, zero cost when the
	# relic isn't held. No stack is ever recorded, so a mid-run equip/unequip can't leave a stale
	# slow entry behind (nothing was ever appended while immune).
	if RelicEffects.slow_immune:
		return
	_slow_stacks.append({ "factor": clampf(1.0 - factor, 0.1, 1.0), "remaining": duration })

## Pure decay step for the shove impulse, split out so a headless probe can prove it always
## dies out (same probe-ability idiom as ShiftClock/Ranks).
static func shove_step(v: Vector2, decay: float, delta: float) -> Vector2:
	return v.move_toward(Vector2.ZERO, decay * delta)

## Knock the player away at `impulse` px/sec, decaying to zero. Ignored mid-dash (the player's
## committed dash beats the boss's shove). REPLACES any live shove — overlapping screams must
## not compound into a cross-arena launch.
func apply_shove(impulse: Vector2) -> void:
	if _dash.is_dashing():
		return
	_shove_velocity = impulse

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

## --- ONE OF THEM (Zombie Bob, AbilityController._cast_ghost) ---

## Arms (or extends) the ghost window. maxf-merge, same shape as apply_fire_lock/_grant_invuln —
## a recast before expiry extends, never shortens.
func set_ghost(duration: float) -> void:
	_ghost_time = maxf(_ghost_time, duration)

## True while ONE OF THEM is active. Enemy._target_ghosted() reads this every frame off its own
## `_target` reference — no signal/event needed, matching is_frozen()/is_pinned()'s own
## poll-not-push shape.
func is_ghost() -> bool:
	return _ghost_time > 0.0

## Additive indicator ring at the player's feet while ghosted — the C4-lavender, low-alpha
## "base ring" look VirtualJoystick already uses (draw_circle, Color(0.878, 0.898, 1.0, a)),
## reused here as an OUTLINE (draw_arc) so it reads as a ground marker, not a filled blob.
## Deliberately NOT a sprite modulate tint: `lifesteal_blip()` above already owns `_sprite.modulate`
## for its own transient tween-to-white, and a persistent ghost tint sharing that channel would
## get stomped mid-window (or fail to restore) the first time a lifesteal blip fires during the
## 4s. This ring is a separate additive layer — nothing to restore, nothing to fight.
func _draw() -> void:
	if not is_ghost():
		return
	var ring_col := Color(0.878, 0.898, 1.0, 0.55)   # C4 lavender @ low-ish alpha (brief's exact value)
	draw_arc(Vector2(0, 20), 14.0, 0.0, TAU, 24, ring_col, 3.0, true)

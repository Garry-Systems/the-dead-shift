class_name Cryptid
extends CharacterBody2D
## THE CRYPTID (Night Shift Stories, v0.1.68) — a bounty visitor that never attacks and flees the
## player; despawns uncaught after CRYPTID_WINDOW seconds. "Shimmer-drawn" per spec: no sprite, no
## .tscn — built entirely in script (mirrors Destructible.gd/MannequinDecoy.gd/
## BasementCratePickup.gd's own "no scene/art, builds its own collider" idiom) and rendered via a
## pure code _draw() (see bottom of file) — it never gets baked art, even after Task 5 (per the
## plan's own sprite list: "cryptid = shimmer-drawn (code)").
##
## Targetable: sits in the "enemies" group and exposes take_damage/health_fraction/flash_hit — the
## exact has_method-gated surface Bullet.gd/TalentEngine.process_hit already check for EVERY
## "enemies"-group member (Bullet.gd:57-135, scripts/loot/TalentEngine.gd:222+), neither of which
## ever branches on enemy TYPE. That means weapon talents' on-hit/on-kill procs (lifesteal, chain,
## burn, freeze, an explode-on-kill payload, ...) fire on a Cryptid kill exactly like they would on
## any trash enemy or boss — a natural, harmless consequence of reusing that shared pipeline, not
## something this file special-cases or needs to guard against (verified by reading both call
## sites; no Cryptid-specific plumbing exists or is needed for that part).
##
## It does NOT extend Enemy (no touch damage, no contact bounce, no burn/slow/pin status channels —
## none of that applies to a fleeing, non-attacking bounty) and does NOT reuse Enemy.take_damage's
## trash-kill chokepoint (RunStats.add_kill / RelicEffects.on_kill) — its own death pays a bespoke
## bounty (RunStats.add_coins + a crate) instead, the same "boss-shaped, not trash-shaped" reward
## split BossBase._reward() already uses (RunStats.add_boss() / RelicEffects.on_boss_kill(), NOT
## the trash-kill counters) — see _die() below.
##
## Flee steering is Enemy.gd:473-479's fear-flee vector math, reimplemented locally here (a
## VERIFIED SEAM per the task brief — Enemy.gd itself is untouched): flee = (self - target)
## .normalized(), Vector2.RIGHT fallback at zero distance, scaled by move_speed every physics tick.
##
## THE BASEMENT's straggler sweep (Basement._free_stragglers, scripts/Basement.gd:306-321) frees
## ANY "enemies"-group member too far from the surface point on ascend, with no further group
## filter beyond a special case for "boss" (Cryptid is never in that group). A live Cryptid still
## fleeing when the player descends keeps fleeing a `_target` that's now sitting at the fixed
## +24000,+24000 gauntlet offset for the whole gauntlet duration, so on ascend it's very likely
## stranded past BASEMENT_STRAGGLER_RADIUS from the real surface point — swept automatically, no
## extra code needed here. Verified by reading _free_stragglers, not by a dedicated
## Cryptid<->Basement interaction test (this file carries zero basement awareness of its own).

const _RADIUS := 20.0   # collider size — matches Enemy.tscn's own shambler CircleShape2D radius

const FLASH_CD := 0.15  # min seconds between hit-flashes — Enemy.gd's own FLASH_CD value (Enemy.gd:35),
                        # reimplemented locally for the exact reason it exists there: a continuous
                        # weapon (flame cone, beam) or a rapid gun calls flash_hit far faster than
                        # the pulse can fade, which machine-guns the "hit_enemy" sound and pins the
                        # shimmer's brighten solid. Throttling to readable pulses fixes both.

var move_speed := GameConfig.CRYPTID_MOVE_SPEED

var _health: Health
var _target: Player
var _time_left := 0.0
var _flash_t := 0.0
var _flash_cd := 0.0    # counts down between hit-flashes (see FLASH_CD)
var _dead := false
var _health_bar: EnemyHealthBar

func _ready() -> void:
	add_to_group("enemies")
	set_collision_mask_value(GameConfig.COVER_LAYER_BIT, true)   # collide with solid cover, same as Enemy._ready
	_target = get_tree().get_first_node_in_group("player") as Player
	_health = Health.new(GameConfig.CRYPTID_HP)
	_time_left = GameConfig.CRYPTID_WINDOW
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _RADIUS
	cs.shape = shape
	add_child(cs)
	_health_bar = EnemyHealthBar.new()
	_health_bar.position = Vector2(0, -28)
	_health_bar.z_index = 1
	add_child(_health_bar)

func health_fraction() -> float:
	if _health == null or _health.maxhp <= 0.0:
		return 0.0
	return _health.current / _health.maxhp

## Bullet.gd's has_method-gated hit-flash call, with Enemy.flash_hit's identical shared signature
## AND its FLASH_CD throttle (Enemy.gd:233-241 parity — throttled, not just same-shaped): `tint`
## is accepted-and-ignored (this file has no Sprite2D/ShaderMaterial to tint; the shimmer's own
## _draw() brightens on _flash_t instead, below), and a call landing inside the FLASH_CD window
## is a full no-op — no re-flash, no sound — so rapid weapons pulse instead of spamming.
func flash_hit(_tint: Color = Color(1, 1, 1, 1)) -> void:
	if _flash_cd > 0.0:
		return
	_flash_cd = FLASH_CD
	_flash_t = 0.12
	SoundManager.play("hit_enemy")   # same chokepoint Enemy.flash_hit uses (Enemy.gd:237)

func take_damage(amount: float) -> void:
	if _dead or _health.is_dead():
		return
	_health.take_damage(amount)
	if _health.is_dead():
		_die(true)
	elif _health_bar != null:
		_health_bar.set_fraction(health_fraction())

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _flash_cd > 0.0:
		_flash_cd -= delta
	if _flash_t > 0.0:
		_flash_t = maxf(_flash_t - delta, 0.0)
	_time_left -= delta
	if _time_left <= 0.0:
		_die(false)
		return
	if _target != null and is_instance_valid(_target):
		# Enemy.gd:473-479's fear-flee vector math, reimplemented here (verified seam — Enemy.gd
		# itself is untouched): flee directly away from the player, RIGHT fallback at zero distance.
		var flee := (global_position - _target.global_position).normalized()
		if flee == Vector2.ZERO:
			flee = Vector2.RIGHT
		velocity = flee * move_speed
		move_and_slide()
	queue_redraw()   # shimmer is time-based (Time.get_ticks_msec()), so it animates even standing still

func _die(killed: bool) -> void:
	_dead = true
	if killed:
		SoundManager.play("die_enemy")   # the one alive->dead transition chokepoint every enemy/boss uses (Enemy.gd:603)
		RunStats.add_coins(GameConfig.CRYPTID_COINS)
		SaveManager.add_crate(BasementLogic.crate_id_for(DifficultyManager.wave))
		SaveManager.save_game()   # the basement chokepoint idiom — Basement._start_reward pairs add_crate-equivalent grants with an immediate save the same way (Basement.gd:266-267)
		_banner("NOBODY WILL BELIEVE YOU", "")
	else:
		_banner("IT'S GONE", "")
	queue_free()

func _banner(text: String, sub: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("_show_banner", text, sub)

## Shimmer: a soft, pulsing near-translucent silhouette in the strict 4-color palette (C2 indigo
## core, C4 lavender rim) — "something's there, but you can't quite pin it down." Pulse period is
## deliberately unrelated to CRYPTID_WINDOW so the shimmer never reads as a countdown timer (the
## HUD banner + its own despawn own that job); a snappier _flash_t brighten layers on top for hit
## feedback, same spirit as Destructible._hit_flash / Enemy's shader flash but drawn, not shaded
## (there's no Sprite2D here to attach a ShaderMaterial to).
func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	var core_a := clampf(0.35 + 0.25 * pulse + _flash_t * 2.0, 0.0, 0.9)
	var rim_a := clampf(0.25 + 0.35 * pulse + _flash_t * 2.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, _RADIUS, Color(PixelTheme.ACCENT_DIM.r, PixelTheme.ACCENT_DIM.g, PixelTheme.ACCENT_DIM.b, core_a))
	draw_arc(Vector2.ZERO, _RADIUS + 3.0, 0.0, TAU, 20, Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, rim_a), 2.0)

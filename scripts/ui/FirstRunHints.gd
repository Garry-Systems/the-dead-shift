class_name FirstRunHints
extends Control
## First-run onboarding: four sequential HUD hints (move → shoot → dash → ability) shown only
## until SaveManager.tutorial_done() is true. Self-contained — Hud instantiates one and calls
## setup(player) once; everything else runs off _process. Non-blocking (mouse_filter IGNORE
## on every node here) so it never intercepts taps/drags meant for the joystick or gun.
## Works for both endless and boss rush — both modes run this same Hud/scene.

enum Stage { MOVE, SHOOT, DASH, ABILITY, DONE }

var _player: Player
var _stage: Stage = Stage.DONE   # DONE until setup() confirms a fresh (tutorial-not-done) run
var _label: Label

var _move_time := 0.0          # cumulative seconds of nonzero player velocity (hint 1)
var _fire_time := 0.0          # cumulative seconds the gun is aiming + unheld + not reloading (hint 2)
var _kills_at_stage_start := 0 # RunStats.kills snapshot when hint 2 starts, so any kill during it clears it
var _ability_time := 0.0       # seconds hint 4 has been showing (auto-clears at HINT_ABILITY_SECONDS)
var _ability_ctl: Node = null  # AbilityController group lookup, resolved when hint 4 starts

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_right = 1.0
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 140.0
	offset_bottom = 196.0
	visible = false

	var scrim := ColorRect.new()
	scrim.color = PixelTheme.OVERLAY_DIM   # C1 void, dim — a scrim strip behind the hint text
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelTheme.style_label(_label, 30, PixelTheme.TEXT)   # C4 #E0E5FF
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_constant_override("shadow_outline_size", 0)
	add_child(_label)

## Called once by Hud right after instancing. Stays hidden for the rest of the run if the
## tutorial is already done.
func setup(player: Player) -> void:
	_player = player
	if SaveManager.tutorial_done():
		_stage = Stage.DONE
		return
	_stage = Stage.MOVE
	_kills_at_stage_start = RunStats.kills
	_show_hint("DRAG ANYWHERE TO MOVE")

func _process(delta: float) -> void:
	if _stage == Stage.DONE or _player == null or not is_instance_valid(_player):
		return
	match _stage:
		Stage.MOVE:
			if _player.velocity != Vector2.ZERO:
				_move_time += delta
			if _move_time >= GameConfig.HINT_MOVE_SECONDS:
				_advance_to_shoot()
		Stage.SHOOT:
			var gun := _player.gun
			# Mirrors the Gun._process early-return conditions: aiming, not holding fire (i.e.
			# standing still, per SHOOT_ONLY_WHILE_STILL), not mid-reload — the closest
			# observable proxy for "actually firing" without a dedicated Gun signal.
			# Lightning (Tesla) is excluded from the TIME fallback: _fire_lightning silently
			# no-ops (no shot, no ammo/cooldown spent) when no conductor is in range, so
			# "eligible" isn't "firing" there — Tesla users clear this hint via first kill.
			if gun != null and gun.fire_mode != "lightning" \
					and not gun.is_reloading() and not gun.hold_fire and gun.aim_direction != Vector2.ZERO:
				_fire_time += delta
			if RunStats.kills > _kills_at_stage_start or _fire_time >= GameConfig.HINT_FIRE_SECONDS:
				_advance_to_dash()
		Stage.DASH:
			if _player.is_dashing():
				_advance_to_ability()
		Stage.ABILITY:
			# Cleared by a cast (the cooldown arming is the observable) or by the timeout —
			# the hint must never block a player who'd rather bank the ability for a boss.
			_ability_time += delta
			var cast := _ability_ctl != null and is_instance_valid(_ability_ctl) \
					and not bool(_ability_ctl.call("is_ready"))
			if cast or _ability_time >= GameConfig.HINT_ABILITY_SECONDS:
				_finish()
		_:
			pass

func _advance_to_shoot() -> void:
	_stage = Stage.SHOOT
	_show_hint("STAND STILL TO SHOOT")

func _advance_to_dash() -> void:
	_stage = Stage.DASH
	_show_hint("DOUBLE-TAP TO DASH")

## Hint 4 (v0.1.72): the ability button otherwise just appears with no explanation. Skipped
## outright when the character has no castable active — no row, or a passive row like Bob's
## SECOND SHIFT whose try_cast() always refuses (the button renders armed/spent, never casts).
func _advance_to_ability() -> void:
	_ability_ctl = get_tree().get_first_node_in_group("ability_controller")
	var row: Dictionary = _ability_ctl.call("ability_row") if _ability_ctl != null else {}
	if row.is_empty() or bool(row.get("passive", false)):
		_finish()
		return
	_stage = Stage.ABILITY
	_ability_time = 0.0
	_show_hint("TAP THE BADGE TO FIRE YOUR ABILITY")

func _finish() -> void:
	_stage = Stage.DONE
	visible = false
	# Memory only — see SaveManager.set_tutorial_done for why we don't save_game() here.
	SaveManager.set_tutorial_done()

func _show_hint(text: String) -> void:
	_label.text = text
	visible = true

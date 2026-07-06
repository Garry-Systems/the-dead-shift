class_name CameraShake
extends Camera2D
## Trauma-based screen shake (Pack D: Stats + juice, v0.1.51), attached to the player's Camera2D
## (which had no script/behavior before this, so there's nothing existing to fight). Trauma
## decays linearly over time; the VISIBLE offset is trauma^2 x per-axis noise x SHAKE_MAX_OFFSET —
## the standard screen-shake curve, so mild trauma barely reads while a big hit is a real punch.
## Reached via the static `instance` (mirrors CombatText/Juice) so every shake source just calls
## CameraShake.add_trauma(amount) without holding a node reference. Per-frame math only (sin
## calls on scalars) — no allocations, safe every frame even mid-horde.
##
## Respects the save-level EFFECTS toggle (SaveManager.shake_on()): gated at add-time AND
## enforced every frame in _process, so toggling it off stops an in-flight shake dead instantly
## instead of waiting for the current trauma to decay out.

static var instance: CameraShake = null

var _trauma := 0.0
var _phase := 0.0   # per-instance phase offset so the two axes don't move in lockstep

func _ready() -> void:
	instance = self
	_phase = randf() * TAU

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _process(delta: float) -> void:
	if not SaveManager.shake_on():
		_trauma = 0.0
		offset = Vector2.ZERO
		return
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = ShakeMath.decay(_trauma, delta)
	var power := _trauma * _trauma
	var t := (Time.get_ticks_msec() / 1000.0) * GameConfig.SHAKE_FREQ
	offset = Vector2(sin(t + _phase), sin(t * 1.3 + _phase + 1.7)) * power * GameConfig.SHAKE_MAX_OFFSET

## Adds trauma (clamped to 1.0; decays over time — see _process). No-op without a live camera, or
## with the EFFECTS toggle off.
static func add_trauma(amount: float) -> void:
	if instance == null or not SaveManager.shake_on():
		return
	instance._trauma = clampf(instance._trauma + amount, 0.0, 1.0)

## The trauma a Shockwave.blast() of `radius` should add. Thin pass-through to ShakeMath (the
## dependency-free, probe-friendly home for the actual formula) — kept here too so call sites
## (Shockwave.gd, EliteVolatileBlast.gd) don't need to know ShakeMath exists.
static func trauma_for_radius(radius: float) -> float:
	return ShakeMath.trauma_for_radius(radius)

class_name Destructible
extends StaticBody2D
## A scatterable obstacle, built from an Obstacles row by ObstacleField (no scene/art —
## it draws itself). Solid cover (car/rubble) blocks movement + bullets + line of sight;
## non-solid props (barrel/drum/transformer/crate) are walk-through and take bullet damage.
## On death it spawns its hazard zone (barrels also burst via Shockwave + chain neighbors)
## or drops loot.

const _XP_GEM_SCENE := preload("res://scenes/XpGem.tscn")

var kind := "loot"
var shape := "circle"
var size := 18.0
var size_y := 18.0   # Transfer Stores (v0.1.65): rect half-height. Absent row field -> configure()
                     # defaults this to `size` (square, today's behavior). Only "rect" shape reads
                     # it; "circle" rows ignore it entirely.
var solid := false
var hp := 25.0
var hazard_id := ""
var loot := ""
var gem_count := 0
var color := Color(0.549, 0.522, 0.451)
var burst_radius := GameConfig.BARREL_BURST_RADIUS   # Shockwave blast radius on a "fire" death (row-overridable)
var burst_damage := GameConfig.BARREL_BURST_DAMAGE   # Shockwave blast damage on a "fire" death (row-overridable)
var burst_force := GameConfig.BARREL_BURST_FORCE     # Shockwave knockback force on a "fire" death (row-overridable)
var hazard_scale := 1.0                              # scales the lingering hazard zone's dps + radius (row-overridable)
var no_cull := false   # true for a fixed world fixture (Forecourt) — ObstacleField must never cull this
var chain_id := ""    # Transfer Stores (Task 3): optional row field, absent -> "" (no chain).
                       # Shares the fuse/budget below with the pre-existing barrel (hazard_id ==
                       # "fire") chain, but only lights same-chain_id neighbors — see light_fuse().
var wail := false      # PARKING GARAGE (Task 4): optional row field, absent -> false (a plain
                       # car everywhere outside the garage gimmick). See _start_wail() below.

var _health: Health
var _detonating := false
var _fuse := -1.0          # >= 0 = chain fuse counting down to detonation
var _hit_flash := 0.0
# PARKING GARAGE (Task 4): car alarm wail state. `_wailed` is a one-way latch (one wail per car
# EVER, per the brief) — set the instant a wail is triggered and never cleared, so a second
# take_damage (even after the wail already ended, or while it's running) can never restart it.
var _wailed := false
var _wailing := false      # currently in an active WAIL_TIME window (drives taunts + the ring draw)
var _wail_time := 0.0
var _wail_taunt_t := 0.0   # countdown to the next taunt tick — starts at 0.0 so the FIRST
                           # _process() tick after the wail starts fires immediately (same
                           # idiom as MannequinDecoy._tick/TICK_INTERVAL)
static var _last_wail_sfx_ms := -1000000000   # shared across every wailing car — see _play_wail_sfx()

# Global per-frame chain-detonation budget (CHAIN_MAX_PER_TICK) so a dense barrel farm
# ripples across frames instead of detonating a whole wavefront on one frame.
static var _det_frame := -1
static var _det_count := 0

## Bake a row's fields. Call BEFORE add_child (so _ready can build the shape + layer).
func configure(row: Dictionary) -> void:
	kind = String(row["kind"])
	shape = String(row["shape"])
	size = float(row["size"])
	size_y = float(row.get("size_y", size))   # absent -> square, byte-identical to every existing row
	solid = bool(row["solid"])
	hp = float(row["hp"])
	hazard_id = String(row["hazard_id"])
	loot = String(row["loot"])
	gem_count = int(row["gem_count"])
	color = row.get("color", color)
	burst_radius = float(row.get("burst_radius", GameConfig.BARREL_BURST_RADIUS))
	burst_damage = float(row.get("burst_damage", GameConfig.BARREL_BURST_DAMAGE))
	burst_force = float(row.get("burst_force", GameConfig.BARREL_BURST_FORCE))
	hazard_scale = float(row.get("hazard_scale", 1.0))
	chain_id = String(row.get("chain_id", ""))   # absent -> "", byte-identical to every existing row
	wail = bool(row.get("wail", false))          # absent -> false, byte-identical to every existing row

func _ready() -> void:
	if hp >= 0.0:
		_health = Health.new(hp)
	_build_shape()
	add_to_group("destructibles")
	collision_layer = 0
	if solid:
		set_collision_layer_value(GameConfig.COVER_LAYER_BIT, true)
		add_to_group("cover")
	else:
		set_collision_layer_value(GameConfig.DESTRUCTIBLE_LAYER_BIT, true)
	queue_redraw()

func _build_shape() -> void:
	var cs := CollisionShape2D.new()
	if shape == "rect":
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size * 2.0, size_y * 2.0)
		cs.shape = rect
	else:
		var circ := CircleShape2D.new()
		circ.radius = size
		cs.shape = circ
	add_child(cs)

func is_fusing() -> bool:
	return _fuse >= 0.0

func take_damage(amount: float) -> void:
	if hp < 0.0 or _detonating or _health == null:   # indestructible or already dying
		return
	_health.take_damage(amount)
	_hit_flash = 0.08
	queue_redraw()
	if _health.is_dead():
		_die()
	elif wail and not _wailed:
		# PARKING GARAGE (Task 4): "the FIRST take_damage that doesn't kill it" — this elif only
		# ever reaches on a SURVIVING hit (the is_dead() branch above already returned via _die()
		# otherwise), and `_wailed` latches true inside _start_wail() so no later hit (lethal or
		# not) can re-enter this branch for the same car.
		_start_wail()

func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0:
			queue_redraw()
	if _fuse >= 0.0:
		if _detonating:
			_fuse = -1.0    # already dying via another path — drop the fuse, spend no chain slot
		else:
			_fuse -= delta
			if _fuse <= 0.0:
				if not _claim_detonation_slot():
					_fuse = 0.001    # per-frame budget full — retry next frame (ripple)
					return
				_fuse = -1.0
				_die()
	# PARKING GARAGE (Task 4): wail tick — decays WAIL_TIME, re-taunting every WAIL_TAUNT_TICK.
	if _wailing:
		_wail_time -= delta
		if _wail_time <= 0.0:
			_wailing = false
			remove_from_group("wailing_cars")
		else:
			_wail_taunt_t -= delta
			if _wail_taunt_t <= 0.0:
				_wail_taunt_t = GameConfig.WAIL_TAUNT_TICK
				_taunt_nearby()
		queue_redraw()   # pulsing ring needs a redraw every tick, not just on state transitions

## Per-frame chain budget: at most CHAIN_MAX_PER_TICK fused barrels detonate per frame.
static func _claim_detonation_slot() -> bool:
	var frame := Engine.get_process_frames()
	if _det_frame != frame:
		_det_frame = frame
		_det_count = 0
	if _det_count >= GameConfig.CHAIN_MAX_PER_TICK:
		return false
	_det_count += 1
	return true

## A neighboring destructible lights this one after a short delay (ripple, not recursion).
## Two independent chain triggers share this ONE fuse timer + the per-frame detonation budget
## below (Transfer Stores, Task 3 -- generalized from the barrel-only mechanism found here):
##   - barrels: _die()'s fire-blast loop calls this with NO argument (source_chain_id == ""),
##     exactly as it always has -- the "hazard_id != 'fire' -> return" branch below is the
##     ORIGINAL guard, untouched, so barrel chaining is byte-for-byte what it was before this task.
##   - chain_id rows (mart's "shelf"): _die()'s new chain_id loop calls this WITH its own
##     chain_id -- this only lights a neighbor whose chain_id matches, so shelves chain shelves
##     and never cross-trigger a barrel (or vice versa).
func light_fuse(source_chain_id: String = "") -> void:
	if _detonating or _fuse >= 0.0:
		return
	if source_chain_id == "":
		if hazard_id != "fire":   # legacy barrel-chain guard — unchanged
			return
	elif chain_id == "" or chain_id != source_chain_id:
		return
	_fuse = GameConfig.CHAIN_DELAY

## PARKING GARAGE (Task 4): begins this car's ONE lifetime wail. Enforces WAIL_MAX_CONCURRENT
## on the "wailing_cars" group FIRST (drop-oldest — see _cap_wailing_cars), then arms the timer/
## tick and joins the group. Called only from take_damage()'s `wail and not _wailed` branch, which
## already latches `_wailed` — but the flag is (re-)set here too as the actual, authoritative
## "has this car ever wailed" bit, since silence_wail() below never touches it.
func _start_wail() -> void:
	_wailed = true
	var tree := get_tree()
	if tree != null:
		_cap_wailing_cars(tree)
	_wailing = true
	_wail_time = GameConfig.WAIL_TIME
	_wail_taunt_t = 0.0   # first _process() tick fires a taunt immediately — no initial dead air
	add_to_group("wailing_cars")
	queue_redraw()

## Enforces WAIL_MAX_CONCURRENT on "wailing_cars": if already at cap, SILENCES (not frees) the
## OLDEST member (group order == spawn/trigger order — same assumption Mine._evict_oldest/
## HazardZone.cap_player_pools already rely on) before this car joins. "Silence, don't free" per
## the brief: an alarm car that gets capped out keeps existing as a normal (now-permanently-quiet)
## car — it already spent its one lifetime wail, so silencing it costs nothing further.
func _cap_wailing_cars(tree) -> void:
	var cars: Array = tree.get_nodes_in_group("wailing_cars")
	if cars.size() >= GameConfig.WAIL_MAX_CONCURRENT:
		var oldest = cars[0]
		if is_instance_valid(oldest) and oldest.has_method("silence_wail"):
			oldest.silence_wail()

## Stops an active wail without freeing the car (see _cap_wailing_cars above). `_wailed` is left
## true — a silenced car can never restart (one wail per car ever), it just stops mid-window.
func silence_wail() -> void:
	if not _wailing:
		return
	_wailing = false
	remove_from_group("wailing_cars")
	queue_redraw()

## Every WAIL_TAUNT_TICK while wailing: taunts every Enemy within WAIL_TAUNT_RADIUS toward this
## car (same `e is Enemy` static-type guard as MannequinDecoy._retaunt() — bosses are immune "for
## free" since BossBase never defines/calls taunt()) and plays a throttled alarm sting.
func _taunt_nearby() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_play_wail_sfx()
	var r2 := GameConfig.WAIL_TAUNT_RADIUS * GameConfig.WAIL_TAUNT_RADIUS
	for e in tree.get_nodes_in_group("enemies"):
		if e is Enemy and is_instance_valid(e) and global_position.distance_squared_to((e as Node2D).global_position) <= r2:
			(e as Enemy).taunt(self, GameConfig.WAIL_TAUNT_DUR)

## Reuses "boss_roar" (the loudest, most "look over here" existing SFX id — grepped SoundManager's
## SFX_IDS; no "alarm"/"ui_denied" id actually exists in this codebase, so the brief's suggested
## names were speculative) as a placeholder car-alarm sting, throttled via a STATIC (shared across
## every wailing car, not per-instance) min-gap so a dense multi-car wail can't machine-gun it —
## SoundManager.play()'s own MIN_INTERVAL_MS dict only throttles per-id calls made close together
## in time regardless of caller, but WAIL_SFX_MIN_GAP_MS below is a second, independent throttle
## layered on top of that (deliberately looser than SoundManager's own gate would need — this one
## exists so the alarm reads as a periodic "whoop-whoop", not a per-tick retrigger every 0.5s).
func _play_wail_sfx() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_wail_sfx_ms < GameConfig.WAIL_SFX_MIN_GAP_MS:
		return
	_last_wail_sfx_ms = now
	SoundManager.play("boss_roar")

func _die() -> void:
	if _detonating:
		return
	_detonating = true
	var tree := get_tree()
	# Barrel: instant Shockwave burst + chain-fuse nearby barrels. UNCHANGED from before this task.
	if hazard_id == "fire":
		var sw := Shockwave.new()
		tree.current_scene.add_child(sw)
		sw.global_position = global_position
		sw.blast(burst_radius, burst_damage, burst_force, null, null)
		RelicEffects.on_hazard_burst(global_position, burst_radius, burst_damage, burst_force)   # Relics Overhaul: double_fuse echo
		var cr2 := GameConfig.BARREL_CHAIN_RADIUS * GameConfig.BARREL_CHAIN_RADIUS
		for d in tree.get_nodes_in_group("destructibles"):
			if d == self or not is_instance_valid(d):
				continue
			if (d as Node2D).global_position.distance_squared_to(global_position) <= cr2 and d.has_method("light_fuse"):
				d.light_fuse()
	# BIG MART (Transfer Stores, Task 3): chain_id collapse. A second, independent chain trigger --
	# any row carrying a non-empty chain_id lights same-chain_id neighbors within
	# SHELF_CHAIN_RADIUS, reusing the SAME fuse + CHAIN_MAX_PER_TICK budget as the barrel chain
	# above (see light_fuse()). A chained shelf falls through to its normal death below -- gems via
	# _drop_loot, no blast/hazard (hazard_id == "" on the shelf row, so neither the blast branch
	# above nor the hazard-zone branch below ever fires for it).
	if chain_id != "":
		var scr2 := GameConfig.SHELF_CHAIN_RADIUS * GameConfig.SHELF_CHAIN_RADIUS
		for d in tree.get_nodes_in_group("destructibles"):
			if d == self or not is_instance_valid(d):
				continue
			if (d as Node2D).global_position.distance_squared_to(global_position) <= scr2 and d.has_method("light_fuse"):
				d.light_fuse(chain_id)
	# Lingering hazard zone (capped).
	if hazard_id != "" and tree.get_nodes_in_group("hazard_zones").size() < GameConfig.MAX_HAZARD_ZONES:
		var cfg := Hazards.stats_for(hazard_id)
		if not cfg.is_empty():
			if hazard_scale != 1.0:
				cfg["dps"] = float(cfg.get("dps", 0.0)) * hazard_scale
				cfg["radius"] = float(cfg.get("radius", 0.0)) * hazard_scale
			var hz := HazardZone.new()
			tree.current_scene.add_child(hz)
			hz.global_position = global_position
			hz.configure_hazard(cfg)
	# Loot.
	if loot == "gems":
		_drop_loot(gem_count)
		RelicEffects.on_crate_loot(global_position)   # Relics Overhaul: spare_parts extra gem + coin-burst chance
	queue_free()

func _drop_loot(n: int) -> void:
	var tree := get_tree()
	if _XP_GEM_SCENE != null:
		for i in n:
			var gem = _XP_GEM_SCENE.instantiate()
			tree.current_scene.add_child(gem)
			gem.global_position = global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
	RunStats.add_coins(GameConfig.CRATE_COIN_REWARD)

func _draw() -> void:
	var c := Color(1, 1, 1, 1) if _hit_flash > 0.0 else color
	var outline := Color(0.04, 0.0, 0.10)   # C1 void
	if shape == "rect":
		var r := Rect2(Vector2(-size, -size_y), Vector2(size * 2.0, size_y * 2.0))
		draw_rect(r, c)
		draw_rect(r, outline, false, 2.0)
	else:
		draw_circle(Vector2.ZERO, size, c)
		draw_arc(Vector2.ZERO, size, 0.0, TAU, 24, outline, 2.0)
	# PARKING GARAGE (Task 4): pulsing C4 ring overlay while wailing — the "dinner bell" tell, on
	# top of whichever base shape was just drawn above (a car is a "rect", but this reads generic
	# in case a future non-car row ever carries "wail":true).
	if _wailing:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		var base_r := maxf(size, size_y)
		var ring_r := base_r + 12.0 + pulse * 8.0
		var ring_col := Color(PixelTheme.ACCENT.r, PixelTheme.ACCENT.g, PixelTheme.ACCENT.b, 0.35 + 0.35 * pulse)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, ring_col, 3.0)

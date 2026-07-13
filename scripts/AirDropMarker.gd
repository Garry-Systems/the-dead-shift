extends Node2D
## AIR DROP (The Delivery Girl): a telegraph ring that sits at a SNAPSHOT of the caster's
## position (set by AbilityController._cast_air_drop right after spawn), then slams a
## talent-free Shockwave blast + a healing/gem care package after ABILITY_AIRDROP_DELAY seconds.
##
## Scene-owned, NOT player-owned: this node is a get_tree().current_scene child with no reference
## back to the player at all (position is copied once, at cast time). The drop therefore lands
## on schedule even if the caster dies, dashes off-screen, or the run otherwise moves on mid-
## telegraph — there is nothing here that COULD depend on the caster still existing. No
## class_name (AbilityController instantiates it via a plain preload/new — nothing else needs a
## cross-file static reference to this type).

const HEALTH_PACK_SCRIPT := preload("res://scripts/HealthPack.gd")
const XP_GEM_SCENE := preload("res://scenes/XpGem.tscn")   # same scene Enemy._drop_gem uses

func _ready() -> void:
	z_index = 40
	# Pause-safe telegraph: process_always=false (3rd arg) means a level-up card / pause menu
	# opening mid-telegraph HOLDS the countdown instead of burning it down behind the overlay —
	# the double_fuse-echo pause contract (RelicEffects). ignore_time_scale is left false (4th
	# arg, default) — nothing here fights over Engine.time_scale, so the delay simply rides
	# whatever scale is active (hit-stop included).
	get_tree().create_timer(GameConfig.ABILITY_AIRDROP_DELAY, false, false).timeout.connect(_land)

func _draw() -> void:
	# Telegraph ring: faint fill + a brighter edge arc, C4 — the Shockwave._draw ring idiom.
	# Static (never changes over the telegraph), so one automatic first draw is enough — no
	# queue_redraw() needed (the Turret.gd fallback-shape precedent).
	var col := PixelTheme.ACCENT
	draw_circle(Vector2.ZERO, GameConfig.ABILITY_AIRDROP_RADIUS, Color(col.r, col.g, col.b, 0.12))
	draw_arc(Vector2.ZERO, GameConfig.ABILITY_AIRDROP_RADIUS, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.5), 3.0, true)

## Split out from the timer callback so a probe can drive the drop directly without waiting out
## ABILITY_AIRDROP_DELAY.
func _land() -> void:
	var fx := Shockwave.new()
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position
	# null gun / null player: AIR DROP carries no weapon talents (Shockwave.blast's gun/player
	# args are both optional — verified in Shockwave.gd, still pushes + damages with neither).
	# hit_destructibles = true: a crate under the drop bursts.
	fx.blast(GameConfig.ABILITY_AIRDROP_RADIUS, GameConfig.ABILITY_AIRDROP_DAMAGE,
		GameConfig.ABILITY_AIRDROP_FORCE, null, null, true)
	_spawn_care_package()
	queue_free()

## Scatters ABILITY_AIRDROP_PACKS HealthPacks + ABILITY_AIRDROP_GEMS XpGems ~60px around the
## impact point, evenly spaced by angle. Deterministic, not RNG-driven — purely cosmetic scatter,
## either would be fine here.
func _spawn_care_package() -> void:
	var total := GameConfig.ABILITY_AIRDROP_PACKS + GameConfig.ABILITY_AIRDROP_GEMS
	var slot := 0
	for i in GameConfig.ABILITY_AIRDROP_PACKS:
		var pack: Node2D = HEALTH_PACK_SCRIPT.new()
		_place_scattered(pack, slot, total)
		slot += 1
	for i in GameConfig.ABILITY_AIRDROP_GEMS:
		# Value set before add_child, position set after — the exact order Enemy._drop_gem uses
		# at its own xp_gem_scene spawn site.
		var gem = XP_GEM_SCENE.instantiate()
		gem.value = GameConfig.ABILITY_AIRDROP_GEM_VALUE
		_place_scattered(gem, slot, total)
		slot += 1

func _place_scattered(node: Node2D, slot: int, total: int) -> void:
	get_tree().current_scene.add_child(node)
	var ang := TAU * float(slot) / maxf(float(total), 1.0)
	node.global_position = global_position + Vector2(cos(ang), sin(ang)) * 60.0

class_name BasementCratePickup
extends Area2D
## THE BASEMENT (Pack E) gauntlet reward. Walking into it AUTO-COLLECTS a freshly rolled weapon
## at `rarity_floor` and grants it straight into the permanent Inventory — same "spawn and
## forget, auto-collect on touch" idiom as RelicPickup (scripts/RelicPickup.gd: body_entered +
## is_in_group("player") + immediate queue_free, no modal, so a pickup can never strand itself
## mid-run).
##
## Verify-first note (Task 4 brief): the brief pointed at THE NIGHT STOCKER's CrateDrop
## (Patterns.CRATE, scripts/patterns/CrateDrop.gd) as "the in-run crate-pickup entity" to reuse.
## That's a codebase divergence from the brief's assumption — CrateDrop drops a plain solid
## Destructible cover obstacle (loot "", no rarity, no grant call of any kind); it's terrain, not
## a reward. There is no existing in-run entity that "grants a crate". The actual
## floor-parameterized weapon-grant chokepoint in this codebase is Inventory.add(inst) — its own
## doc comment calls it out as "the single chokepoint every weapon-granting path funnels
## through" (crate opens via commit_crate, daily/milestone gun rewards, DEV grants) — fed by
## LootRoller.roll(Rarity.roll(floor, Rarity.MAX_ID), "") exactly like Rewards.roll_milestone's
## own gun-reward branch. That pairing is already floor-parameterized (Rarity.roll's first arg),
## so nothing needed a new optional param grafted on. Reuses the existing
## art/crates/_crate.png placeholder icon (Crates.icon()'s own no-per-crate-art fallback) instead
## of a new code-drawn shape, since real crate art already exists in the project.

signal collected

var rarity_floor := 1

var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var spr := Sprite2D.new()
	spr.texture = load("res://art/crates/_crate.png")
	spr.scale = Vector2(2.0, 2.0)
	add_child(spr)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 32.0
	cs.shape = shape
	add_child(cs)

func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	Inventory.add(LootRoller.roll(Rarity.roll(rarity_floor, Rarity.MAX_ID), ""))
	collected.emit()
	queue_free()

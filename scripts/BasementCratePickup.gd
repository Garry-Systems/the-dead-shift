class_name BasementCratePickup
extends Area2D
## THE BASEMENT (Pack E) gauntlet reward. Walking into it AUTO-COLLECTS one unopened crate of
## `crate_id` (BasementLogic.crate_id_for maps the wave's rarity floor onto a real registry
## crate) straight into the persistent crate stash — same "spawn and forget, auto-collect on
## touch" idiom as RelicPickup (scripts/RelicPickup.gd: body_entered + is_in_group("player") +
## immediate queue_free, no modal, so a pickup can never strand itself mid-run).
##
## Grant route: SaveManager.add_crate(crate_id) — the same call MainMenu._grant_reward's "crate"
## branch uses (and the same dict math ChallengeProgress._grant_crate /
## CommendationProgress._add_crate duplicate for their autoload-free contexts). add_crate is
## memory-only ("caller saves" — the SaveManager mutator convention), and every granting
## chokepoint pairs it with its own SaveManager.save_game() flush (MainMenu._check_free_rewards,
## Inventory.add); this is a mid-run grant with no guaranteed later flush before a crash/
## force-quit could eat it, so it flushes immediately too. Crates ignore the weapon-inventory cap
## (MainMenu's inventory-full fallback converts a GUN reward into a crate for exactly that
## reason), so there is no failure path to handle. The player opens it from the STORE like any
## other owned crate.
##
## Icon: Crates.icon(crate_id) — per-crate art if present (all four ids BasementLogic maps onto
## ship art), else the shared _crate.png placeholder, the registry's own fallback rule.

var crate_id := ""

var _collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var spr := Sprite2D.new()
	spr.texture = Crates.icon(crate_id)
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
	SaveManager.add_crate(crate_id)
	SaveManager.save_game()
	queue_free()

class_name AuraRing
extends Node2D
## Closing Time (`aura_slow`): a persistent, faint circle outline at the aura's edge — the only
## CONSTANT (non-proc) visual in the roster. A single child of the Gun for as long as aura_slow
## is active (created once in Gun._setup_aura_ring, freed with the Gun); follows the gun/player
## automatically via normal scene-tree parenting, so it never needs repositioning. Deliberately
## NOT routed through TalentEngine's per-frame VFX budget — that budget is for transient proc
## spawns; this is one long-lived node, same as HazardZone's own _draw().

const ALPHA := 0.08

var radius := 0.0
var color := Color(0.239, 0.0, 0.6)   # C2 indigo (matches Enemy.FROZEN_TINT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.r, color.g, color.b, ALPHA), 2.0, true)

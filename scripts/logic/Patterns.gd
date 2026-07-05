class_name Patterns
## Registry of boss attack-pattern scenes, preloaded so phase tables can reference them as
## Patterns.RING / Patterns.BAND / ... without per-boss @export wiring. Mirrors the
## data-registry style of Weapons.gd and Relics.gd.

const RING := preload("res://scenes/patterns/ExpandingRing.tscn")
const BAND := preload("res://scenes/patterns/AimedBand.tscn")
const ZONE := preload("res://scenes/patterns/ZoneFill.tscn")
const EMITTER := preload("res://scenes/patterns/ProjectileEmitter.tscn")
const SUMMON := preload("res://scenes/patterns/SummonSpawner.tscn")
const DEBUFF := preload("res://scenes/patterns/DebuffApplier.tscn")
const CHARGE := preload("res://scenes/patterns/ChargeDash.tscn")
const CRATE := preload("res://scenes/patterns/CrateDrop.tscn")

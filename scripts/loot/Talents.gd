class_name Talents
## The talent catalog — original, gritty-themed weapon abilities for the auto-fire
## top-down shooter. Pure data (mirrors Weapons / Affixes). Each talent declares a tier
## (which affix slot it rolls into: 1=common, 3=rare), an unlock-level range (gates it
## behind that weapon's persistent level), a `kind` the TalentEngine knows how to fire,
## and `mods` = {min,max} ranges. A rolled instance stores one 0..1 quality per mod and
## the real value is min + (max-min)*roll — same scheme as affix stats.
##
## kinds (how the engine reads each on hit/kill):
##   crit            passive  — crit chance + crit damage
##   onkill_frenzy   on kill  — temporary fire-rate surge
##   onhit_knockback on hit   — shove the enemy back
##   onhit_ignite    on hit   — burn damage-over-time
##   onhit_slow      on hit   — cut enemy move speed
##   onhit_chain     on hit   — arc bonus damage to nearby enemies
##   onhit_dot       on hit   — stacking poison damage-over-time
##   onhit_lifesteal on hit   — heal the player
##   onkill_explode  on kill  — corpse detonates for area damage
##   onhit_execute   on hit   — instakill enemies below a health threshold

static func all() -> Array:
	return [
		# --- Tier 1 (common) ---
		{
			"id": "killshot", "name": "Killshot", "kind": "crit", "tier": 1,
			"color": Color("ff3b3b"), "level_required": {"min": 1, "max": 3},
			"desc": "%s%% chance to crit for +%s%% damage",
			"mods": [ {"min": 8, "max": 18}, {"min": 40, "max": 80} ],
		},
		{
			"id": "bloodrush", "name": "Bloodrush", "kind": "onkill_frenzy", "tier": 1,
			"color": Color("ff7a18"), "level_required": {"min": 2, "max": 5},
			"desc": "Kills surge fire rate +%s%% for %ss",
			"mods": [ {"min": 15, "max": 30}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "concussive", "name": "Concussive", "kind": "onhit_knockback", "tier": 1,
			"color": Color("9d9d9d"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance to knock the target back",
			"mods": [ {"min": 15, "max": 30}, {"min": 120, "max": 260} ],
		},
		# --- Tier 2 (uncommon) ---
		{
			"id": "napalm", "name": "Napalm", "kind": "onhit_ignite", "tier": 2,
			"color": Color("ff5a1f"), "level_required": {"min": 5, "max": 10},
			"desc": "%s%% chance to set ablaze: %s dmg/s for %ss",
			"mods": [ {"min": 18, "max": 35}, {"min": 12, "max": 30}, {"min": 2, "max": 4} ],
		},
		{
			"id": "frostbite", "name": "Frostbite", "kind": "onhit_slow", "tier": 2,
			"color": Color("4ec3ff"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to slow the target %s%% for %ss",
			"mods": [ {"min": 25, "max": 45}, {"min": 25, "max": 50}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "livewire", "name": "Live Wire", "kind": "onhit_chain", "tier": 2,
			"color": Color("8be9ff"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance to arc to %s enemies for %s%% damage",
			"mods": [ {"min": 20, "max": 35}, {"min": 2, "max": 4}, {"min": 35, "max": 60} ],
		},
		# --- Tier 3 (rare) ---
		{
			"id": "venom", "name": "Venom", "kind": "onhit_dot", "tier": 3,
			"color": Color("57d957"), "level_required": {"min": 12, "max": 20},
			"desc": "%s%% chance to poison: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 30, "max": 50}, {"min": 10, "max": 22}, {"min": 3, "max": 5} ],
		},
		{
			"id": "bloodthirst", "name": "Bloodthirst", "kind": "onhit_lifesteal", "tier": 3,
			"color": Color("c41e3a"), "level_required": {"min": 14, "max": 22},
			"desc": "%s%% chance on hit to heal %s health",
			"mods": [ {"min": 8, "max": 18}, {"min": 2, "max": 6} ],
		},
		{
			"id": "gutbomb", "name": "Gut Bomb", "kind": "onkill_explode", "tier": 3,
			"color": Color("ff4422"), "level_required": {"min": 12, "max": 20},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 50, "max": 100}, {"min": 20, "max": 50}, {"min": 70, "max": 130} ],
		},
		{
			"id": "executioner", "name": "Executioner", "kind": "onhit_execute", "tier": 3,
			"color": Color("8b0000"), "level_required": {"min": 15, "max": 25},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 8, "max": 15} ],
		},
	]

static func get_talent(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return {}

static func of_tier(tier: int) -> Array:
	var out: Array = []
	for t in all():
		if t["tier"] == tier:
			out.append(t)
	return out

## Random talent of a tier (for an affix's "random" slot). Empty dict if none.
static func random_of_tier(tier: int) -> Dictionary:
	var pool := of_tier(tier)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

## Real value of a talent's mod index given the stored 0..1 roll.
static func resolve(def: Dictionary, idx: int, roll: float) -> float:
	var m: Dictionary = def["mods"][idx]
	return m["min"] + (m["max"] - m["min"]) * roll

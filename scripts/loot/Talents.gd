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
##   onhit_vulnerable on hit   — mark the target to take extra damage for a duration
##   onhit_freeze     on hit   — fully stop the target; a hit while frozen shatters it (AoE)
##   onkill_surge     on kill  — next shots gain bonus pierce + extra pellets
##   onreload_nova    on reload — finishing a reload blasts an AoE around the player
##   overpen          passive  — bonus pierce; each enemy pierced grows the shot's damage

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
		# --- Data talents (reuse existing behaviors) ---
		{
			"id": "pilotlight", "name": "Pilot Light", "kind": "onhit_ignite", "tier": 1,
			"color": Color("ff8c42"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance to ignite: %s dmg/s for %ss",
			"mods": [ {"min": 12, "max": 24}, {"min": 6, "max": 14}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "tar", "name": "Tar", "kind": "onhit_slow", "tier": 1,
			"color": Color("6fb7d6"), "level_required": {"min": 1, "max": 5},
			"desc": "%s%% chance to slow the target %s%% for %ss",
			"mods": [ {"min": 20, "max": 35}, {"min": 15, "max": 30}, {"min": 1.5, "max": 3.0} ],
		},
		{
			"id": "marksman", "name": "Marksman", "kind": "crit", "tier": 2,
			"color": Color("ff5b5b"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to crit for +%s%% damage",
			"mods": [ {"min": 12, "max": 22}, {"min": 70, "max": 130} ],
		},
		{
			"id": "adrenaline", "name": "Adrenaline", "kind": "onkill_frenzy", "tier": 2,
			"color": Color("ffae42"), "level_required": {"min": 5, "max": 12},
			"desc": "Kills surge fire rate +%s%% for %ss",
			"mods": [ {"min": 30, "max": 50}, {"min": 2.0, "max": 4.0} ],
		},
		{
			"id": "haymaker", "name": "Haymaker", "kind": "onhit_knockback", "tier": 2,
			"color": Color("b0b0b0"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to knock the target back hard",
			"mods": [ {"min": 25, "max": 45}, {"min": 280, "max": 460} ],
		},
		{
			"id": "rot", "name": "Rot", "kind": "onhit_dot", "tier": 2,
			"color": Color("7bd957"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance to poison: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 25, "max": 40}, {"min": 8, "max": 16}, {"min": 2, "max": 4} ],
		},
		{
			"id": "leech", "name": "Leech", "kind": "onhit_lifesteal", "tier": 2,
			"color": Color("d65a6a"), "level_required": {"min": 8, "max": 16},
			"desc": "%s%% chance on hit to heal %s health",
			"mods": [ {"min": 10, "max": 20}, {"min": 1, "max": 4} ],
		},
		{
			"id": "cluster", "name": "Cluster", "kind": "onkill_explode", "tier": 2,
			"color": Color("ff6644"), "level_required": {"min": 6, "max": 14},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 40, "max": 70}, {"min": 12, "max": 30}, {"min": 60, "max": 110} ],
		},
		{
			"id": "mercy", "name": "Mercy", "kind": "onhit_execute", "tier": 2,
			"color": Color("a05050"), "level_required": {"min": 10, "max": 18},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 5, "max": 10} ],
		},
		{
			"id": "hollowpoint", "name": "Hollowpoint", "kind": "crit", "tier": 3,
			"color": Color("ff1f1f"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to crit for +%s%% damage",
			"mods": [ {"min": 20, "max": 32}, {"min": 100, "max": 180} ],
		},
		{
			"id": "inferno", "name": "Inferno", "kind": "onhit_ignite", "tier": 3,
			"color": Color("ff3300"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to set ablaze: %s dmg/s for %ss",
			"mods": [ {"min": 28, "max": 48}, {"min": 30, "max": 60}, {"min": 3, "max": 5} ],
		},
		{
			"id": "glacial", "name": "Glacial", "kind": "onhit_slow", "tier": 3,
			"color": Color("7fdfff"), "level_required": {"min": 12, "max": 22},
			"desc": "%s%% chance to slow the target %s%% for %ss",
			"mods": [ {"min": 35, "max": 55}, {"min": 50, "max": 75}, {"min": 3, "max": 5} ],
		},
		{
			"id": "arcwelder", "name": "Arc Welder", "kind": "onhit_chain", "tier": 3,
			"color": Color("bff3ff"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to arc to %s enemies for %s%% damage",
			"mods": [ {"min": 30, "max": 45}, {"min": 3, "max": 5}, {"min": 55, "max": 90} ],
		},
		{
			"id": "plague", "name": "Plague", "kind": "onhit_dot", "tier": 3,
			"color": Color("3fbf3f"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance to poison: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 40, "max": 60}, {"min": 18, "max": 34}, {"min": 4, "max": 6} ],
		},
		{
			"id": "daisycutter", "name": "Daisy Cutter", "kind": "onkill_explode", "tier": 3,
			"color": Color("ff2200"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 70, "max": 100}, {"min": 40, "max": 80}, {"min": 140, "max": 240} ],
		},
		{
			"id": "reaper", "name": "Reaper", "kind": "onhit_execute", "tier": 3,
			"color": Color("700000"), "level_required": {"min": 18, "max": 28},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 15, "max": 25} ],
		},
		# --- New behaviors (engine arms in TalentEngine, hooks in Enemy/Gun/Bullet) ---
		{
			"id": "marked", "name": "Marked", "kind": "onhit_vulnerable", "tier": 2,
			"color": Color("ffd166"), "level_required": {"min": 5, "max": 12},
			"desc": "%s%% chance to mark: target takes +%s%% damage for %ss",
			"mods": [ {"min": 20, "max": 40}, {"min": 15, "max": 35}, {"min": 3, "max": 5} ],
		},
		{
			"id": "overflow", "name": "Overflow", "kind": "onkill_surge", "tier": 2,
			"color": Color("ff9f1c"), "level_required": {"min": 6, "max": 12},
			"desc": "Kills grant +%s pierce & +%s shots for %ss",
			"mods": [ {"min": 1, "max": 2}, {"min": 1, "max": 2}, {"min": 2, "max": 4} ],
		},
		{
			"id": "backblast", "name": "Backblast", "kind": "onreload_nova", "tier": 2,
			"color": Color("ff6b35"), "level_required": {"min": 5, "max": 12},
			"desc": "Finishing a reload blasts %s damage (radius %s)",
			"mods": [ {"min": 25, "max": 60}, {"min": 120, "max": 220} ],
		},
		{
			"id": "coldsnap", "name": "Cold Snap", "kind": "onhit_freeze", "tier": 3,
			"color": Color("a8e6ff"), "level_required": {"min": 14, "max": 22},
			"desc": "%s%% chance to freeze %ss; a hit on a frozen enemy shatters for %s dmg (radius %s)",
			"mods": [ {"min": 10, "max": 22}, {"min": 1.0, "max": 2.0}, {"min": 40, "max": 90}, {"min": 80, "max": 140} ],
		},
		{
			"id": "railbreaker", "name": "Railbreaker", "kind": "overpen", "tier": 3,
			"color": Color("c0c0c0"), "level_required": {"min": 12, "max": 22},
			"desc": "Shots pierce +%s enemies, +%s%% damage per pierce",
			"mods": [ {"min": 2, "max": 4}, {"min": 15, "max": 30} ],
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

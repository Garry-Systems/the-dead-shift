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
##
## --- Talent Overhaul Phase 2 kinds (29 new talents; see TalentEngine.resolve_payload) ---
##   onhit_pin         on hit    — root the target in place (reuses the Nail Gun's pin channel)
##   onkill_ammo       on kill   — refund rounds into the mag
##   cc_bonus          passive   — +% damage vs a hampered (slowed/frozen/pinned) target
##   first_shot_bonus  passive   — the first shot after a reload deals +% damage
##   low_mag_bonus     passive   — +% damage that scales as the mag empties
##   onhit_fear        on hit    — reverse the target's movement for a duration
##   onkill_bolt       on kill   — the corpse arcs a chain bolt (kill-gated onhit_chain sibling)
##   onkill_pool       on kill   — the corpse spills an enemy-only hazard pool
##   onkill_mine       on kill   — the corpse leaves a pooled proximity mine
##   onhurt_nova       on player hurt — a retaliation blast, gun-held ICD, carries no talents
##   onhit_dot_detonate on hit   — bursts the target's remaining burn/poison as instant damage
##   onkill_spread     on kill   — copies the corpse's active statuses onto nearby enemies
##   oncrit_echo       on crit   — schedules a second, non-crittable hit on the same target
##   onhit_gravity     on hit    — spawns a capped, no-damage pull well (feeds other AoE talents)
##   lowhp_frenzy      passive   — fire-rate surge while the player is below an HP threshold
##   aura_slow         passive   — slows every enemy within a radius of the player

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
			"desc": "%s%% chance to knock the target back (%s force)",
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
			"desc": "%s%% chance to knock the target back hard (%s force)",
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
		# --- Talent Overhaul Phase 3: 29 new talents (2026-07-05 design) — tiers 15/22/23 ---
		# --- Tier 1 (10 new) ---
		{
			"id": "static_cling", "name": "Static Cling", "kind": "onhit_chain", "tier": 1,
			"color": Color("6fe0ff"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance to arc to %s enemies for %s%% damage",
			"mods": [ {"min": 10, "max": 20}, {"min": 1, "max": 2}, {"min": 25, "max": 40} ],
		},
		{
			"id": "scratch", "name": "Scratch", "kind": "onhit_dot", "tier": 1,
			"color": Color("6bcf6b"), "level_required": {"min": 1, "max": 5},
			"desc": "%s%% chance to infect: %s dmg/s for %ss (stacks)",
			"mods": [ {"min": 15, "max": 30}, {"min": 4, "max": 9}, {"min": 2, "max": 3} ],
		},
		{
			"id": "mosquito", "name": "Mosquito", "kind": "onhit_lifesteal", "tier": 1,
			"color": Color("e6537a"), "level_required": {"min": 2, "max": 5},
			"desc": "%s%% chance on hit to heal %s health",
			"mods": [ {"min": 6, "max": 12}, {"min": 1, "max": 2} ],
		},
		{
			"id": "firecracker", "name": "Firecracker", "kind": "onkill_explode", "tier": 1,
			"color": Color("ff8855"), "level_required": {"min": 2, "max": 5},
			"desc": "%s%% chance a kill detonates for %s damage (radius %s)",
			"mods": [ {"min": 30, "max": 50}, {"min": 8, "max": 16}, {"min": 50, "max": 80} ],
		},
		{
			"id": "chalk_outline", "name": "Chalk Outline", "kind": "onhit_vulnerable", "tier": 1,
			"color": Color("e6c35c"), "level_required": {"min": 1, "max": 5},
			"desc": "%s%% chance to mark: target takes +%s%% damage for %ss",
			"mods": [ {"min": 12, "max": 25}, {"min": 8, "max": 15}, {"min": 2, "max": 3} ],
		},
		{
			"id": "short_fuse", "name": "Short Fuse", "kind": "onreload_nova", "tier": 1,
			"color": Color("ff7f3f"), "level_required": {"min": 2, "max": 5},
			"desc": "Finishing a reload blasts %s damage (radius %s)",
			"mods": [ {"min": 10, "max": 22}, {"min": 80, "max": 130} ],
		},
		{
			"id": "pink_slip", "name": "Pink Slip", "kind": "onhit_execute", "tier": 1,
			"color": Color("990000"), "level_required": {"min": 2, "max": 5},
			"desc": "Instantly kills enemies below %s%% health",
			"mods": [ {"min": 3, "max": 6} ],
			"callout": "FIRED.",
		},
		{
			"id": "deadbolt", "name": "Deadbolt", "kind": "onhit_pin", "tier": 1,
			"color": Color("e0e5ff"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance to nail the target in place for %ss",
			"mods": [ {"min": 8, "max": 16}, {"min": 0.4, "max": 0.8} ],
		},
		{
			"id": "brass_picker", "name": "Brass Picker", "kind": "onkill_ammo", "tier": 1,
			"color": Color("b8c2ff"), "level_required": {"min": 1, "max": 4},
			"desc": "%s%% chance a kill loads %s round back into the mag",
			"mods": [ {"min": 15, "max": 30}, {"min": 1, "max": 1} ],
		},
		{
			"id": "curb_stomp", "name": "Curb Stomp", "kind": "cc_bonus", "tier": 1,
			"color": Color("3d0099"), "level_required": {"min": 2, "max": 5},
			"desc": "+%s%% damage to slowed, frozen or pinned enemies",
			"mods": [ {"min": 15, "max": 30} ],
		},
		# --- Tier 2 (9 new) ---
		{
			"id": "cold_shoulder", "name": "Cold Shoulder", "kind": "onhit_freeze", "tier": 2,
			"color": Color("7fd0f0"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance to freeze %ss; a hit on a frozen enemy shatters for %s dmg (radius %s)",
			"mods": [ {"min": 6, "max": 14}, {"min": 0.6, "max": 1.2}, {"min": 20, "max": 45}, {"min": 60, "max": 100} ],
		},
		{
			"id": "rebar", "name": "Rebar", "kind": "overpen", "tier": 2,
			"color": Color("a8a8a8"), "level_required": {"min": 6, "max": 12},
			"desc": "Shots pierce +%s enemies, +%s%% damage per pierce",
			"mods": [ {"min": 1, "max": 2}, {"min": 8, "max": 16} ],
		},
		{
			"id": "clock_in", "name": "Clock In", "kind": "first_shot_bonus", "tier": 2,
			"color": Color("cfd6ff"), "level_required": {"min": 5, "max": 10},
			"desc": "First shot after a reload deals +%s%% damage",
			"mods": [ {"min": 40, "max": 80} ],
		},
		{
			"id": "last_call", "name": "Last Call", "kind": "low_mag_bonus", "tier": 2,
			"color": Color("ff9955"), "level_required": {"min": 5, "max": 12},
			"desc": "Up to +%s%% damage as the mag runs dry",
			"mods": [ {"min": 30, "max": 60} ],
		},
		{
			"id": "night_terror", "name": "Night Terror", "kind": "onhit_fear", "tier": 2,
			"color": Color("4a2f6b"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance to terrify: the target flees for %ss",
			"mods": [ {"min": 10, "max": 20}, {"min": 1.0, "max": 2.0} ],
		},
		{
			"id": "death_rattle", "name": "Death Rattle", "kind": "onkill_bolt", "tier": 2,
			"color": Color("9ff0ff"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance a kill arcs to %s enemies for %s%% damage",
			"mods": [ {"min": 25, "max": 45}, {"min": 2, "max": 3}, {"min": 40, "max": 70} ],
		},
		{
			"id": "bile_spill", "name": "Bile Spill", "kind": "onkill_pool", "tier": 2,
			"color": Color("5fbf3f"), "level_required": {"min": 6, "max": 12},
			"desc": "%s%% chance a kill spills bile: %s dmg/s pool for %ss (radius %s)",
			"mods": [ {"min": 20, "max": 35}, {"min": 8, "max": 16}, {"min": 2, "max": 4}, {"min": 60, "max": 100} ],
		},
		{
			"id": "parting_gift", "name": "Parting Gift", "kind": "onkill_mine", "tier": 2,
			"color": Color("b8895a"), "level_required": {"min": 8, "max": 14},
			"desc": "%s%% chance a kill leaves a mine: %s damage (radius %s)",
			"mods": [ {"min": 20, "max": 40}, {"min": 30, "max": 60}, {"min": 90, "max": 150} ],
		},
		{
			"id": "dead_mans_switch", "name": "Dead Man's Switch", "kind": "onhurt_nova", "tier": 2,
			"color": Color("d6dcff"), "level_required": {"min": 8, "max": 14},
			"desc": "Taking a hit detonates %s damage (radius %s)",
			"mods": [ {"min": 30, "max": 70}, {"min": 130, "max": 220} ],
		},
		# --- Tier 3 (10 new) ---
		{
			"id": "rampage", "name": "Rampage", "kind": "onkill_frenzy", "tier": 3,
			"color": Color("ff5522"), "level_required": {"min": 12, "max": 20},
			"desc": "Kills surge fire rate +%s%% for %ss",
			"mods": [ {"min": 45, "max": 70}, {"min": 3, "max": 5} ],
		},
		{
			"id": "mag_dump", "name": "Mag Dump", "kind": "onkill_surge", "tier": 3,
			"color": Color("b3bcff"), "level_required": {"min": 14, "max": 24},
			"desc": "Kills grant +%s pierce & +%s shots for %ss",
			"mods": [ {"min": 2, "max": 3}, {"min": 2, "max": 3}, {"min": 3, "max": 5} ],
		},
		{
			"id": "powder_keg", "name": "Powder Keg", "kind": "onreload_nova", "tier": 3,
			"color": Color("ff5500"), "level_required": {"min": 12, "max": 22},
			"desc": "Finishing a reload blasts %s damage (radius %s)",
			"mods": [ {"min": 70, "max": 130}, {"min": 200, "max": 300} ],
		},
		{
			"id": "death_warrant", "name": "Death Warrant", "kind": "onhit_vulnerable", "tier": 3,
			"color": Color("ffcc33"), "level_required": {"min": 14, "max": 24},
			"desc": "%s%% chance to mark: target takes +%s%% damage for %ss",
			"mods": [ {"min": 25, "max": 45}, {"min": 40, "max": 70}, {"min": 4, "max": 6} ],
			"vuln_ring": 34.0,
		},
		{
			"id": "septic_shock", "name": "Septic Shock", "kind": "onhit_dot_detonate", "tier": 3,
			"color": Color("5ce65c"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance to rupture burn & poison: %s%% of remaining DoT damage bursts (radius %s)",
			"mods": [ {"min": 15, "max": 25}, {"min": 150, "max": 250}, {"min": 90, "max": 140} ],
		},
		{
			"id": "outbreak", "name": "Outbreak", "kind": "onkill_spread", "tier": 3,
			"color": Color("2fbf2f"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance a kill spreads its burn, poison & slow to enemies within %s",
			"mods": [ {"min": 40, "max": 70}, {"min": 120, "max": 180} ],
		},
		{
			"id": "double_tap", "name": "Double Tap", "kind": "oncrit_echo", "tier": 3,
			"color": Color("ffd700"), "level_required": {"min": 15, "max": 25},
			"desc": "Crits have a %s%% chance to hit again for %s%% damage",
			"mods": [ {"min": 25, "max": 45}, {"min": 50, "max": 80} ],
		},
		{
			"id": "black_friday", "name": "Black Friday", "kind": "onhit_gravity", "tier": 3,
			"color": Color("4b0082"), "level_required": {"min": 15, "max": 25},
			"desc": "%s%% chance to rip open a gravity well: drags the horde for %ss (radius %s)",
			"mods": [ {"min": 5, "max": 10}, {"min": 1.5, "max": 2.5}, {"min": 140, "max": 220} ],
		},
		{
			"id": "graveyard_shift", "name": "Graveyard Shift", "kind": "lowhp_frenzy", "tier": 3,
			"color": Color("8b1a2b"), "level_required": {"min": 12, "max": 20},
			"desc": "Below %s%% health: fire rate +%s%%",
			"mods": [ {"min": 30, "max": 50}, {"min": 20, "max": 40} ],
		},
		{
			"id": "closing_time", "name": "Closing Time", "kind": "aura_slow", "tier": 3,
			"color": Color("5b3a99"), "level_required": {"min": 14, "max": 24},
			"desc": "Enemies within %s are slowed %s%%",
			"mods": [ {"min": 120, "max": 170}, {"min": 20, "max": 35} ],
		},
	]

static func get_talent(id: String) -> Dictionary:
	for t in all():
		if t["id"] == id:
			return t
	return {}

## Highest talent tier that exists in the catalog. Talent slots beyond this cap here, so a
## rarity asking for more talents than there are tiers (Apocalypse = 4, Armageddon = 5) fills
## the extra slot(s) with another top-tier talent instead of silently dropping them.
const MAX_TIER := 3

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

## Random talent of a tier whose id is NOT already a key in `exclude` — so one weapon never
## rolls the same talent twice when two slots draw from the same tier. Empty dict if the tier
## is exhausted.
static func random_of_tier_excluding(tier: int, exclude: Dictionary) -> Dictionary:
	var pool: Array = []
	for t in of_tier(tier):
		if not exclude.has(String(t["id"])):
			pool.append(t)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

## Real value of a talent's mod index given the stored 0..1 roll.
static func resolve(def: Dictionary, idx: int, roll: float) -> float:
	var m: Dictionary = def["mods"][idx]
	return m["min"] + (m["max"] - m["min"]) * roll

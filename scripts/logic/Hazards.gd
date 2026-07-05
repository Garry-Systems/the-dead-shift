class_name Hazards
## Lookup-only registry of hazard-zone tuning (like Bosses.gd). A Destructible reads
## stats_for(hazard_id) on death and hands it to a HazardZone. Numbers live in GameConfig.

# The sanctioned gameplay-color exceptions to the strict 4-color palette
# (alongside FlameCone orange / Lightning cyan). Do NOT replace with palette lookups.
const ORANGE := Color(1.0, 0.55, 0.1)   # fire       — palette exception
const GREEN  := Color(0.4, 1.0, 0.2)    # toxic      — palette exception
const CYAN   := Color(0.2, 1.0, 1.0)    # electric   — palette exception (matches Lightning.COLOR)
const GOLD   := Color(1.0, 0.843, 0.0)  # marks/crit — palette exception (matches Rarity's Armageddon "molten gold")
# Blood/execute — newly sanctioned 2026-07-05 (Talent Overhaul design), player-sourced only;
# the enemy-projectile bright red (Color("ff3b3b")-family) stays a separate, distinct exception.
const BLOOD_RED := Color(0.769, 0.118, 0.227)  # #C41E3A

## Tuning dict for a hazard family, or {} for an unknown id.
static func stats_for(hazard_id: String) -> Dictionary:
	match hazard_id:
		"fire":
			return { "color":ORANGE, "dps":GameConfig.FIRE_DPS, "radius":GameConfig.FIRE_RADIUS, "duration":GameConfig.FIRE_DURATION,
				"slow":0.0, "slow_dur":0.0, "stun":0.0, "chain":0, "drift":0.0 }
		"acid":
			return { "color":GREEN, "dps":GameConfig.ACID_DPS, "radius":GameConfig.ACID_RADIUS, "duration":GameConfig.ACID_DURATION,
				"slow":GameConfig.ACID_SLOW_FACTOR, "slow_dur":GameConfig.ACID_SLOW_DURATION, "stun":0.0, "chain":0, "drift":GameConfig.ACID_DRIFT_SPEED }
		"electric":
			return { "color":CYAN, "dps":GameConfig.ELEC_DPS, "radius":GameConfig.ELEC_RADIUS, "duration":GameConfig.ELEC_DURATION,
				"slow":0.0, "slow_dur":0.0, "stun":GameConfig.ELEC_STUN_DURATION, "chain":GameConfig.ELEC_CHAIN_COUNT, "drift":0.0 }
		_:
			return {}

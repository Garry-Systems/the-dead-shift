class_name LootRoller
## Turns "give me a weapon of rarity R" into a saved instance dict. Pure function, no
## state. The instance stores only ids + 0..1 quality rolls (never final stats), so it
## is tiny to save and rebalances retroactively when affix ranges change.
##
## Instance shape:
##   { uid, base, affix, rarity, level, xp, stats:{stat_id: roll 0..1} }

## Roll a full instance. base_id "" = pick a random base weapon from Weapons.all().
static func roll(rarity: int, base_id: String = "") -> Dictionary:
	var affixes := Affixes.rollable_of_rarity(rarity)
	if affixes.is_empty():
		affixes = Affixes.rollable_of_rarity(1)
	var affix: Dictionary = affixes[randi() % affixes.size()]

	if base_id == "":
		var bases := Weapons.all()
		base_id = String(bases[randi() % bases.size()]["id"])

	var inst := {
		"uid": _uid(),
		"base": base_id,
		"affix": String(affix["id"]),
		"rarity": int(affix["rarity"]),
		"level": 1,
		"xp": 0,
		"stats": {},
		"talents": [],
	}

	# Choose how many of the affix's stats roll, then roll each as a 0..1 quality.
	var keys: Array = affix.get("stats", {}).keys()
	keys.shuffle()
	var n: int = clampi(randi_range(int(affix["min_stats"]), int(affix["max_stats"])), 0, keys.size())
	for i in n:
		inst["stats"][keys[i]] = snappedf(randf(), 0.001)

	inst["talents"] = _roll_talents(affix)
	return inst

## Roll the affix's talent slots: slot index i (0-based) pulls a random talent of tier
## i+1, so higher-rarity affixes (more slots) reach the stronger tier-2/3 talents. Each
## talent stores a 0..1 roll per mod and an unlock_level rolled from its level_required.
static func _roll_talents(affix: Dictionary) -> Array:
	var count := randi_range(int(affix.get("min_talents", 0)), int(affix.get("max_talents", 0)))
	var out: Array = []
	for slot in count:
		var def := Talents.random_of_tier(slot + 1)
		if def.is_empty():
			continue
		var rolls: Array = []
		for m in def["mods"]:
			rolls.append(snappedf(randf(), 0.01))
		var lr: Dictionary = def["level_required"]
		out.append({
			"id": String(def["id"]),
			"unlock_level": randi_range(int(lr["min"]), int(lr["max"])),
			"rolls": rolls,
		})
	return out

## Roll using a crate def: resolve its rarity (explicit floor/ceil ladder), then roll.
static func roll_from_crate(crate: Dictionary) -> Dictionary:
	var rarity := Rarity.roll(int(crate.get("rarity_floor", 1)), int(crate.get("rarity_ceil", Rarity.MAX_ID)))
	return roll(rarity, String(crate.get("force_base", "")))

static func _uid() -> String:
	# Unique enough for local single-player: time + counter-ish randomness.
	return "%d_%d" % [Time.get_ticks_usec(), randi()]

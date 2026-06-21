class_name Rewards
## Pure roll logic for the free reward systems — daily login + every-10-games milestone.
## No state, no nodes: returns a reward descriptor; the caller (MainMenu) grants + reveals it.
## A reward descriptor = { "kind": "crate", "crate_id": String }
##                     or { "kind": "gun",   "inst": Dictionary }   (a freshly rolled weapon)

## Daily login: a random crate, weighted toward cheaper ones (premium = a rare thrill).
static func roll_daily() -> Dictionary:
	return { "kind": "crate", "crate_id": random_crate_id() }

## Every-10-games milestone: a 50/50 coin-flip between a random crate and a random rolled gun.
static func roll_milestone() -> Dictionary:
	if randf() < 0.5:
		return { "kind": "crate", "crate_id": random_crate_id() }
	# A fair-ladder rarity (same odds as a floor-1 crate pull), random base.
	return { "kind": "gun", "inst": LootRoller.roll(Rarity.roll(1, Rarity.MAX_ID), "") }

## Pick a crate id weighted toward the cheap end of the lineup. Weights are derived from the
## crate's price so any future crate auto-slots in; tune the thresholds to reshape the curve.
static func random_crate_id() -> String:
	var all := Crates.all()
	if all.is_empty():
		return ""
	var total := 0
	var weights: Array = []   # parallel to `all`
	for c in all:
		var w := _daily_weight(int(c.get("price", 0)))
		weights.append(w)
		total += w
	if total <= 0:
		return String(all[0]["id"])
	var r := randi_range(1, total)
	var acc := 0
	for i in all.size():
		acc += int(weights[i])
		if r <= acc:
			return String(all[i]["id"])
	return String(all[all.size() - 1]["id"])

## Price → daily-pool weight. Cheaper crates are far likelier; the 9k/30k premiums are a
## rare long-shot. Tunable.
static func _daily_weight(price: int) -> int:
	if price <= 200:
		return 40       # Scrap, Footlocker
	elif price <= 500:
		return 16       # 50/50, the gun-pool crates
	elif price <= 1000:
		return 8        # Munitions
	elif price <= 3000:
		return 3        # Titan
	return 1            # Apex, Apocalypse — the rare thrill

class_name Rewards
## Pure roll logic for the free reward systems — daily login + every-10-games milestone.
## No state, no nodes: returns a reward descriptor; the caller (MainMenu) grants + reveals it.
## A reward descriptor = { "kind": "crate", "crate_id": String }
##                     or { "kind": "gun",   "inst": Dictionary }   (a freshly rolled weapon)
## No autoload references in this file on purpose — keeps it probeable headless via `--script`
## (autoloads aren't registered in that mode; see pack2-report.md's "Probe complication").

## Daily login: a random crate, weighted toward cheaper ones (premium = a rare thrill).
## `streak` (Pack 4, GameConfig.DAILY_STREAK_*) escalates crate quality the longer the player
## has logged in consecutively: see random_crate_id().
static func roll_daily(streak: int = 0) -> Dictionary:
	return { "kind": "crate", "crate_id": random_crate_id(streak) }

## Every-10-games milestone: a 50/50 coin-flip between a random crate and a random rolled gun.
static func roll_milestone() -> Dictionary:
	if randf() < 0.5:
		return { "kind": "crate", "crate_id": random_crate_id() }
	# A fair-ladder rarity (same odds as a floor-1 crate pull), random base.
	return { "kind": "gun", "inst": LootRoller.roll(Rarity.roll(1, Rarity.MAX_ID), "") }

## Pick a crate id weighted toward the cheap end of the lineup. Weights are derived from the
## crate's price so any future crate auto-slots in; tune the thresholds to reshape the curve.
## `streak` ≥ GameConfig.DAILY_STREAK_TIER_UP shifts the weight lookup one tier toward the
## pricier end (see _daily_weight); `streak` ≥ GameConfig.DAILY_STREAK_FLOOR additionally
## upgrades a below-munitions_cache pick up to it (see _apply_streak_floor). streak=0 (the
## default) reproduces the original unweighted-shift behavior exactly — every existing caller
## (roll_milestone, MainMenu's inventory-full conversion) is untouched.
static func random_crate_id(streak: int = 0) -> String:
	var all := Crates.all()
	if all.is_empty():
		return ""
	var tier_shift := 1 if streak >= GameConfig.DAILY_STREAK_TIER_UP else 0
	var total := 0
	var weights: Array = []   # parallel to `all`
	for c in all:
		var w := _daily_weight(int(c.get("price", 0)), tier_shift)
		weights.append(w)
		total += w
	var picked: String
	if total <= 0:
		picked = String(all[0]["id"])
	else:
		var r := randi_range(1, total)
		var acc := 0
		picked = String(all[all.size() - 1]["id"])
		for i in all.size():
			acc += int(weights[i])
			if r <= acc:
				picked = String(all[i]["id"])
				break
	if streak >= GameConfig.DAILY_STREAK_FLOOR:
		picked = _apply_streak_floor(picked)
	return picked

## Price → daily-pool weight tiers (threshold, weight), ordered cheapest to priciest. Cheaper
## crates are far likelier normally; the 9k/30k premiums are a rare long-shot. Tunable — this
## single list drives both the default weighting and the streak tier-up shift.
const _DAILY_WEIGHT_TIERS := [
	{ "max_price": 200,  "weight": 40 },  # Scrap, Footlocker
	{ "max_price": 500,  "weight": 16 },  # 50/50, the gun-pool crates
	{ "max_price": 1000, "weight": 8 },   # Munitions
	{ "max_price": 3000, "weight": 3 },   # Titan
	{ "max_price": -1,   "weight": 1 },   # Apex, Apocalypse — the rare thrill (-1 = no ceiling)
]

## Price → daily-pool weight. `tier_shift` moves the tier lookup toward the pricier end (each
## step re-uses the NEXT tier's weight, capped at the last), so a streak bonus reshapes the
## same curve instead of needing a second parallel weight table.
static func _daily_weight(price: int, tier_shift: int = 0) -> int:
	var idx := _DAILY_WEIGHT_TIERS.size() - 1
	for i in _DAILY_WEIGHT_TIERS.size():
		var max_price := int(_DAILY_WEIGHT_TIERS[i]["max_price"])
		if max_price < 0 or price <= max_price:
			idx = i
			break
	idx = mini(idx + tier_shift, _DAILY_WEIGHT_TIERS.size() - 1)
	return int(_DAILY_WEIGHT_TIERS[idx]["weight"])

## GameConfig.DAILY_STREAK_FLOOR+: upgrade a pick cheaper than munitions_cache up to it.
## Never downgrades — a pick already at munitions_cache's price or above is left alone.
static func _apply_streak_floor(picked: String) -> String:
	var floor_price := int(Crates.get_crate("munitions_cache").get("price", 0))
	if int(Crates.get_crate(picked).get("price", 0)) >= floor_price:
		return picked
	return "munitions_cache"

## Pure streak-update rule (Pack 4), extracted so it's probeable headless without SaveManager.
## `last_claim_date`/`today` are "YYYY-MM-DD" strings in SaveManager.today_string()'s format
## ("" = never claimed). Rule: consecutive day (last == yesterday) -> streak+1; a gap or a
## first-ever claim -> reset to 1; same-day (last == today) -> unchanged (this can't actually
## happen via the real claim flow — SaveManager.is_daily_due() gates the caller before this
## ever runs twice in one day — but it's handled explicitly rather than folded into "gap reset"
## so a defensive/direct call never double-counts a day).
static func next_streak(last_claim_date: String, today: String, current: int) -> int:
	if last_claim_date == today:
		return current
	if last_claim_date != "" and last_claim_date == _day_before(today):
		return current + 1
	return 1

## One calendar day before `date_str` ("YYYY-MM-DD"), via Unix-time arithmetic (never string
## math) so month/year boundaries are correct. Both conversions (Time.get_unix_time_from_
## datetime_string / Time.get_date_string_from_unix_time) treat the date as midnight UTC — an
## arbitrary but internally CONSISTENT anchor, so "-86400 seconds" is always exactly one
## calendar day regardless of the player's real timezone or DST. The input/output strings
## themselves come from SaveManager.today_string() (local calendar date), so this only ever
## does pure date-string arithmetic on those values — it never touches real local time. Note
## the actual midnight boundary a claim resets on is therefore the player's LOCAL midnight
## (today_string()'s), same as the existing is_daily_due()/mark_daily_claimed() mechanism.
static func _day_before(date_str: String) -> String:
	var unix_time := Time.get_unix_time_from_datetime_string(date_str + "T00:00:00")
	return Time.get_date_string_from_unix_time(int(unix_time) - 86400)

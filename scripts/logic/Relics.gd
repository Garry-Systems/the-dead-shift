class_name Relics
## Passive relic data + generic, fully-reversible apply/remove. Each relic adjusts one
## numeric stat on the player or its gun. apply() returns a value the caller stores and
## passes back into remove() to reverse the effect precisely:
##
## modes:
##   "add"     -> returns the flat delta added; remove() subtracts it back.
##   "pct"     -> returns the multiplicative ratio applied (1.0 + amount); remove()
##                divides it back out instead of subtracting a stale flat delta, so
##                upgrade cards that multiply the same stat in between don't drift.
##   "pct_neg" -> returns the ratio applied (1.0 - amount); remove() divides it back out.
##   "special" -> returns the flat delta; handled by a dedicated Player hook (vital_surge / max health)

static func all() -> Array:
	return [
		{"id": "glass_edge",    "name": "Glass Edge",    "desc": "+25% Damage",        "target": "gun",    "prop": "damage",        "mode": "pct",     "amount": GameConfig.RELIC_DAMAGE_PCT},
		{"id": "heavy_rounds",  "name": "Heavy Rounds",  "desc": "+30% Bullet Speed",  "target": "gun",    "prop": "bullet_speed",  "mode": "pct",     "amount": GameConfig.RELIC_BULLET_SPEED_PCT},
		{"id": "long_scope",    "name": "Long Scope",    "desc": "+30% Range",         "target": "gun",    "prop": "gun_range",     "mode": "pct",     "amount": GameConfig.RELIC_RANGE_PCT},
		{"id": "hairpin",       "name": "Hairpin",       "desc": "+15% Fire Rate",     "target": "gun",    "prop": "fire_interval", "mode": "pct_neg", "amount": GameConfig.RELIC_FIRE_RATE_PCT},
		{"id": "field_kit",     "name": "Field Kit",     "desc": "+1.5 HP / sec",      "target": "player", "prop": "health_regen",  "mode": "add",     "amount": GameConfig.RELIC_REGEN},
		{"id": "lodestone",     "name": "Lodestone",     "desc": "+40% Pickup Radius", "target": "player", "prop": "pickup_radius", "mode": "pct",     "amount": GameConfig.RELIC_PICKUP_PCT},
		{"id": "featherweight", "name": "Featherweight", "desc": "+15% Move Speed",    "target": "player", "prop": "move_speed",    "mode": "pct",     "amount": GameConfig.RELIC_MOVE_SPEED_PCT},
		{"id": "vital_surge",   "name": "Vital Surge",   "desc": "+40 Max Health",     "target": "player", "prop": "max_health",    "mode": "special", "amount": GameConfig.RELIC_MAX_HEALTH},
	]

## The relic dict for an id, or an empty dict if unknown.
static func get_relic(id: String) -> Dictionary:
	for r in all():
		if r["id"] == id:
			return r
	return {}

## Applies a relic and returns the value remove() needs for exact reversal (see modes above).
static func apply(player: Player, id: String) -> float:
	var r := get_relic(id)
	if r.is_empty():
		return 0.0

	if String(r["mode"]) == "special":
		var amt := float(r["amount"])
		player.relic_add_max_health(amt)
		return amt

	var obj: Object = player if String(r["target"]) == "player" else player.gun
	var prop: String = String(r["prop"])
	var cur: float = float(obj.get(prop))
	match String(r["mode"]):
		"add":
			var delta: float = float(r["amount"])
			obj.set(prop, cur + delta)
			return delta
		"pct":
			var ratio: float = 1.0 + float(r["amount"])
			obj.set(prop, cur * ratio)
			return ratio
		"pct_neg":
			var ratio: float = 1.0 - float(r["amount"])
			obj.set(prop, cur * ratio)
			return ratio
	return 0.0

## Reverses a previously-applied relic using the value apply() returned (a flat delta for
## "add"/"special", a multiplicative ratio for "pct"/"pct_neg").
static func remove(player: Player, id: String, delta: float) -> void:
	var r := get_relic(id)
	if r.is_empty():
		return

	if String(r["mode"]) == "special":
		player.relic_add_max_health(-delta)
		return

	var obj: Object = player if String(r["target"]) == "player" else player.gun
	var prop: String = String(r["prop"])
	var cur: float = float(obj.get(prop))
	match String(r["mode"]):
		"add":
			obj.set(prop, cur - delta)
		"pct", "pct_neg":
			obj.set(prop, cur / delta)

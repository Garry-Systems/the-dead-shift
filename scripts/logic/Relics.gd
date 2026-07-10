class_name Relics
## Relic data (27, three families) + generic, fully-reversible apply/remove for the STANDARD
## family. Each STANDARD relic adjusts one numeric stat on the player, its gun, or a run-scoped
## RunStats accumulator. apply() returns a value the caller stores and passes back into remove()
## for exact reversal (see modes below). PROTOTYPE and CURSED relics are "mode": "hook" rows —
## their run-rule effects are owned by RelicEffects.gd (spawned per run), keyed off the "hook"
## field (== the relic id); apply()/remove() here deliberately no-op on them (see guard below)
## so RelicBar's existing take()/remove_relic() calls stay safe even before RelicEffects wires in.
##
## modes:
##   "add"     -> returns the flat delta added; remove() subtracts it back.
##   "pct"     -> returns the multiplicative ratio applied (1.0 + amount); remove()
##                divides it back out instead of subtracting a stale flat delta, so
##                upgrade cards that multiply the same stat in between don't drift.
##   "pct_neg" -> returns the ratio applied (1.0 - amount); remove() divides it back out.
##   "special" -> a STANDARD relic whose target isn't a plain player/gun property. Dispatched
##                by id (see _apply_special/_remove_special): vital_surge returns a flat delta
##                (Player.relic_add_max_health hook); tip_jar/punch_card return a multiplicative
##                ratio applied to a RunStats.*_mult accumulator, mirroring the "pct" idiom —
##                remove() divides the ratio back out.
##   "hook"    -> PROTOTYPE/CURSED relic. apply()/remove() no-op (push_warning on apply); the
##                run-rule effect lives in RelicEffects.gd, keyed by the "hook" field.

static func all() -> Array:
	return [
		# --- STANDARD (10): the numbers. ---
		{"id": "glass_edge",    "name": "Glass Edge",    "desc": "+25% Damage",        "family": "standard", "target": "gun",    "prop": "damage",        "mode": "pct",     "amount": GameConfig.RELIC_DAMAGE_PCT},
		{"id": "heavy_rounds",  "name": "Heavy Rounds",  "desc": "+30% Bullet Speed",  "family": "standard", "target": "gun",    "prop": "bullet_speed",  "mode": "pct",     "amount": GameConfig.RELIC_BULLET_SPEED_PCT},
		{"id": "long_scope",    "name": "Long Scope",    "desc": "+30% Range",         "family": "standard", "target": "gun",    "prop": "gun_range",     "mode": "pct",     "amount": GameConfig.RELIC_RANGE_PCT},
		{"id": "hairpin",       "name": "Hairpin",       "desc": "+15% Fire Rate",     "family": "standard", "target": "gun",    "prop": "fire_interval", "mode": "pct_neg", "amount": GameConfig.RELIC_FIRE_RATE_PCT},
		{"id": "field_kit",     "name": "Field Kit",     "desc": "+1.5 HP / sec",      "family": "standard", "target": "player", "prop": "health_regen",  "mode": "add",     "amount": GameConfig.RELIC_REGEN},
		{"id": "lodestone",     "name": "Lodestone",     "desc": "+40% Pickup Radius", "family": "standard", "target": "player", "prop": "pickup_radius", "mode": "pct",     "amount": GameConfig.RELIC_PICKUP_PCT},
		{"id": "featherweight", "name": "Featherweight", "desc": "+15% Move Speed",    "family": "standard", "target": "player", "prop": "move_speed",    "mode": "pct",     "amount": GameConfig.RELIC_MOVE_SPEED_PCT},
		{"id": "vital_surge",   "name": "Vital Surge",   "desc": "+40 Max Health",     "family": "standard", "target": "player", "prop": "max_health",    "mode": "special", "amount": GameConfig.RELIC_MAX_HEALTH},
		{"id": "tip_jar",       "name": "Tip Jar",       "desc": "+15% Coin Gain",     "family": "standard", "target": "runstats", "prop": "coin_mult",      "mode": "special", "amount": GameConfig.RELIC_TIP_JAR_PCT},
		{"id": "punch_card",    "name": "Punch Card",    "desc": "+20% Weapon XP",     "family": "standard", "target": "runstats", "prop": "weapon_xp_mult", "mode": "special", "amount": GameConfig.RELIC_PUNCH_CARD_PCT},

		# --- PROTOTYPE (10): run-rule relics ("someone left this in the back room"). ---
		# mode "hook" -> apply()/remove() no-op here; RelicEffects.gd owns the actual behavior,
		# keyed by "hook" (== id), magnitudes read straight from the RELIC_* consts above.
		{"id": "static_soles",   "name": "Static Soles",   "desc": "dash leaves a live wire. osha was first to go.",              "family": "prototype", "hook": "static_soles",   "mode": "hook"},
		{"id": "double_fuse",    "name": "Double Fuse",    "desc": "crates blow twice. the encore hits for half as much.",        "family": "prototype", "hook": "double_fuse",    "mode": "hook"},
		{"id": "magnet_coil",    "name": "Magnet Coil",    "desc": "chain 5 kills fast enough and every gem on screen comes to you.", "family": "prototype", "hook": "magnet_coil",    "mode": "hook"},
		{"id": "intercom",       "name": "The Intercom",   "desc": "drop an elite and the trash nearby remembers they have legs.", "family": "prototype", "hook": "intercom",       "mode": "hook"},
		{"id": "accelerant",     "name": "Accelerant",     "desc": "anything already on fire takes extra from everything else.",  "family": "prototype", "hook": "accelerant",     "mode": "hook"},
		{"id": "overtime_clock", "name": "Broken Timeclock", "desc": "every boss kill stalls the clock 10 seconds. management denies this.", "family": "prototype", "hook": "overtime_clock", "mode": "hook"},
		{"id": "spare_parts",    "name": "Spare Parts",    "desc": "crates and shelves drop an extra gem, sometimes a coin burst.", "family": "prototype", "hook": "spare_parts",    "mode": "hook"},
		{"id": "rubber_soles",   "name": "Rubber Soles",   "desc": "slows don't stick anymore. your feet got a little quicker too.", "family": "prototype", "hook": "rubber_soles",   "mode": "hook"},
		{"id": "adrenal_valve",  "name": "Adrenal Valve",  "desc": "getting bit refunds dash cooldown. silver lining, technically.", "family": "prototype", "hook": "adrenal_valve",  "mode": "hook"},
		{"id": "chain_letter",   "name": "Chain Letter",   "desc": "every gun punches one extra body through before it stops.",   "family": "prototype", "hook": "chain_letter",   "mode": "hook"},

		# --- CURSED (7): devil's bargains — opt-in only, slot B. ---
		{"id": "managers_stapler", "name": "The Manager's Stapler",  "desc": "big damage bump. every heal in the building now heals half.",      "family": "cursed", "hook": "managers_stapler", "mode": "hook"},
		{"id": "expired_drink",    "name": "Expired Energy Drink",   "desc": "faster everything, less of you to hit. floor's 40, don't push it.", "family": "cursed", "hook": "expired_drink",    "mode": "hook"},
		{"id": "company_card",     "name": "Company Credit Card",    "desc": "coins double while you hold it. corporate claws back 25% at close.", "family": "cursed", "hook": "company_card",     "mode": "hook"},
		{"id": "blood_pact",       "name": "Blood Pact",             "desc": "kills heal a sliver. every other way to heal just clocked out.",   "family": "cursed", "hook": "blood_pact",       "mode": "hook"},
		{"id": "cursed_nametag",   "name": "Cursed Nametag",         "desc": "elites show up way more and now they tip in gems and coins.",     "family": "cursed", "hook": "cursed_nametag",   "mode": "hook"},
		{"id": "overstocked",      "name": "Overstocked",            "desc": "two more relic slots. twenty fewer max hp. inventory over health.", "family": "cursed", "hook": "overstocked",      "mode": "hook"},
		{"id": "dead_mans_vest",   "name": "Dead Man's Vest",        "desc": "cheat death once a boss cycle, at 1 hp. healing capped at half.",  "family": "cursed", "hook": "dead_mans_vest",   "mode": "hook"},
	]

## The relic dict for an id, or an empty dict if unknown.
static func get_relic(id: String) -> Dictionary:
	for r in all():
		if r["id"] == id:
			return r
	return {}

## "standard" | "prototype" | "cursed" for a known id; "" if unknown.
static func family_of(id: String) -> String:
	return String(get_relic(id).get("family", ""))

## Un-held ids of the given family, excluding dead_mans_vest whenever hardcore is true
## (one-life identity wins — its cheat-death never gets offered, not even in slot B).
static func pool(family: String, held: Array, hardcore: bool) -> Array:
	var out: Array = []
	for r in all():
		var id: String = String(r["id"])
		if String(r["family"]) != family:
			continue
		if id in held:
			continue
		if hardcore and id == "dead_mans_vest":
			continue
		out.append(id)
	return out

## Rolls the two RELIC CHOICE cards. Card A is drawn 60% STANDARD / 40% PROTOTYPE and is NEVER
## cursed. Card B is drawn GameConfig.RELIC_CURSED_CHANCE CURSED, else the same 60/40 mix as A;
## it can never duplicate a held relic OR card A. Degrades gracefully as the un-held pool thins:
## returns [a_id, b_id] normally, [a_id] if a second distinct card can't be found, or [] if even
## card A can't be found (nothing un-held left to offer).
static func roll_choice(held: Array, hardcore: bool) -> Array:
	var a_id := _roll_a(held, hardcore)
	if a_id == "":
		return []
	var b_id := _roll_b(held, hardcore, a_id)
	if b_id == "":
		return [a_id]
	return [a_id, b_id]

## 60% "standard" / 40% "prototype" — the mix used by card A, and by card B when it isn't cursed.
static func _ab_family() -> String:
	return "standard" if randf() < 0.6 else "prototype"

## Card A: rolled family first, falling back to the OTHER standard/prototype family if that pool
## is thin. Deliberately never touches the cursed pool — card A is never cursed, even degraded.
static func _roll_a(held: Array, hardcore: bool) -> String:
	var fam := _ab_family()
	var other := "prototype" if fam == "standard" else "standard"
	var p := pool(fam, held, hardcore)
	if p.is_empty():
		p = pool(other, held, hardcore)
	if p.is_empty():
		return ""
	return p[randi() % p.size()]

## Card B: RELIC_CURSED_CHANCE cursed, else A's 60/40 mix; excludes card A on top of held. Falls
## back through the remaining families (cursed included — B CAN be cursed) so a thin pool still
## offers something before the card degrades to "no second card".
static func _roll_b(held: Array, hardcore: bool, a_id: String) -> String:
	var excl: Array = held.duplicate()
	excl.append(a_id)
	var fam := "cursed" if randf() < GameConfig.RELIC_CURSED_CHANCE else _ab_family()
	var order: Array = [fam]
	for f in ["standard", "prototype", "cursed"]:
		if not (f in order):
			order.append(f)
	for f in order:
		var p := pool(f, excl, hardcore)
		if not p.is_empty():
			return p[randi() % p.size()]
	return ""

## Applies a relic and returns the value remove() needs for exact reversal (see modes above).
## No-ops (with a warning) for "hook"-mode (PROTOTYPE/CURSED) relics — RelicEffects.gd owns those.
static func apply(player: Player, id: String) -> float:
	var r := get_relic(id)
	if r.is_empty():
		return 0.0

	if String(r["mode"]) == "hook":
		push_warning("Relics.apply: '%s' is a hook-mode relic (family=%s) — RelicEffects owns it, no-op" % [id, r.get("family", "")])
		return 0.0

	if String(r["mode"]) == "special":
		return _apply_special(player, id, r)

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
## "add"/vital_surge, a multiplicative ratio for "pct"/"pct_neg"/tip_jar/punch_card). No-op for
## "hook"-mode relics (nothing was ever applied here for them).
static func remove(player: Player, id: String, delta: float) -> void:
	var r := get_relic(id)
	if r.is_empty():
		return

	if String(r["mode"]) == "hook":
		return

	if String(r["mode"]) == "special":
		_remove_special(id, player, delta)
		return

	var obj: Object = player if String(r["target"]) == "player" else player.gun
	var prop: String = String(r["prop"])
	var cur: float = float(obj.get(prop))
	match String(r["mode"]):
		"add":
			obj.set(prop, cur - delta)
		"pct", "pct_neg":
			obj.set(prop, cur / delta)

## "special"-mode STANDARD relics that don't target a plain player/gun property.
## vital_surge: flat delta via the dedicated Player max-health hook (heals the same amount too).
## tip_jar/punch_card: multiplicative ratio applied straight to a RunStats run-scoped
## accumulator (RunStats is an autoload — global, no instance needed), mirroring "pct".
static func _apply_special(player: Player, id: String, r: Dictionary) -> float:
	match id:
		"vital_surge":
			var amt := float(r["amount"])
			player.relic_add_max_health(amt)
			return amt
		"tip_jar":
			var ratio := 1.0 + float(r["amount"])
			RunStats.coin_mult *= ratio
			return ratio
		"punch_card":
			var ratio := 1.0 + float(r["amount"])
			RunStats.weapon_xp_mult *= ratio
			return ratio
	return 0.0

static func _remove_special(id: String, player: Player, delta: float) -> void:
	match id:
		"vital_surge":
			player.relic_add_max_health(-delta)
		"tip_jar":
			RunStats.coin_mult /= delta
		"punch_card":
			RunStats.weapon_xp_mult /= delta

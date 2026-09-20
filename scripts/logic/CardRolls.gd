class_name CardRolls
## Pure level-up card roll logic (Power Curve, v0.1.74). Every OFFERED card rolls a rarity tier
## (GameConfig.CARD_TIER_WEIGHTS) and then a value inside that tier's band. Autoload-free and
## seedable (takes the RNG) — same discipline as Upgrades.gd — so a headless probe can verify it.

## id -> {kind, base, fmt}. kind: "pct" (fraction, shown as whole %), "flat" (number shown as is),
## "int" (whole +N, Epic adds damage), "barrel" (+N barrels at a rolled damage share),
## "crit" (crit-chance points from its own table), "fixed" (never rolls).
static func spec(id: String) -> Dictionary:
	match id:
		"move_speed":    return {"kind": "pct", "base": GameConfig.UPGRADE_MOVE_SPEED_PCT, "fmt": "+%d%% Move Speed"}
		"max_health":    return {"kind": "flat", "base": GameConfig.UPGRADE_MAX_HEALTH, "fmt": "+%s Max Health", "step": 1.0}
		"regen":         return {"kind": "flat", "base": GameConfig.UPGRADE_REGEN, "fmt": "+%s Health / sec", "step": 0.1}
		"pickup":        return {"kind": "pct", "base": GameConfig.UPGRADE_PICKUP_PCT, "fmt": "+%d%% Pickup Radius"}
		"armor":         return {"kind": "pct", "base": GameConfig.UPGRADE_ARMOR_PCT, "fmt": "-%d%% Contact Damage Taken"}
		"dodge":
			# Quick Step must disclose the hard ceiling (F3) so the card doesn't read as unlimited
			# stacking. Built by plain concatenation, NOT a %-pass over the cap — the two literal
			# "%%" pairs below are untouched here and only resolve (to one "%" each) the ONE time
			# roll()'s "pct" branch formats this fmt with the rolled value.
			var cap := int(round(GameConfig.DODGE_CAP * 100.0))
			return {"kind": "pct", "base": GameConfig.UPGRADE_DODGE_PCT, "fmt": "+%d%% Dodge Chance (cap " + str(cap) + "%%)"}
		"dash_cooldown": return {"kind": "pct", "base": GameConfig.UPGRADE_DASH_CD_PCT, "fmt": "-%d%% Dash Cooldown"}
		"xp_gain":       return {"kind": "pct", "base": GameConfig.UPGRADE_XP_PCT, "fmt": "+%d%% XP Gain"}
		"coin_gain":     return {"kind": "pct", "base": GameConfig.UPGRADE_COIN_PCT, "fmt": "+%d%% Coin Payout"}
		"thorns":        return {"kind": "flat", "base": GameConfig.UPGRADE_THORNS_MULT, "fmt": "Biters Take %sx Their Own Damage", "step": 0.1}
		"crit":          return {"kind": "crit", "base": 0.0, "fmt": "+%d%% Crit Chance (crits deal 2x or more)"}
		"second_wind":   return {"kind": "fixed", "base": 0.0, "fmt": ""}
		"damage":        return {"kind": "pct", "base": GameConfig.UPGRADE_DAMAGE_PCT, "fmt": "+%d%% Damage"}
		"fire_rate":     return {"kind": "pct", "base": GameConfig.UPGRADE_FIRE_RATE_PCT, "fmt": "+%d%% Fire Rate"}
		"bullet_speed":  return {"kind": "pct", "base": GameConfig.UPGRADE_BULLET_SPEED_PCT, "fmt": "+%d%% Bullet Speed"}
		"range":         return {"kind": "pct", "base": GameConfig.UPGRADE_RANGE_PCT, "fmt": "+%d%% Range"}
		"choke":         return {"kind": "pct", "base": GameConfig.UPGRADE_CHOKE_PCT, "fmt": "-%d%% Spread"}
		"reload":        return {"kind": "pct", "base": GameConfig.UPGRADE_RELOAD_PCT, "fmt": "-%d%% Reload Time"}
		"mag":           return {"kind": "pct", "base": GameConfig.UPGRADE_MAG_PCT, "fmt": "+%d%% Magazine"}
		"incendiary":    return {"kind": "flat", "base": GameConfig.UPGRADE_BURN_DPS, "fmt": "Hits burn for +%s dmg/sec", "step": 0.1}
		"pierce":        return {"kind": "int", "base": 0.0, "fmt": "Bullets pierce +%d enemy", "fmt_plural": "Bullets pierce +%d enemies"}
		"ricochet":      return {"kind": "int", "base": 0.0, "fmt": "Bullets bounce to +%d enemy", "fmt_plural": "Bullets bounce to +%d enemies"}
		"projectile":    return {"kind": "barrel", "base": 0.0, "fmt": "+%d Projectile at %d%% damage", "fmt_plural": "+%d Projectiles at %d%% damage"}
	push_warning("CardRolls: no spec for card id '%s'" % id)
	return {}

static func roll_tier(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in GameConfig.CARD_TIER_WEIGHTS:
		total += int(w)
	var pick := rng.randi_range(1, total)
	for i in GameConfig.CARD_TIER_WEIGHTS.size():
		pick -= int(GameConfig.CARD_TIER_WEIGHTS[i])
		if pick <= 0:
			return i
	return 0

## Returns a rolled COPY of a catalog card: + tier, value, amount, desc, band. The displayed number
## IS the applied number (values are rounded to their display step before being stored).
static func roll(card: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := card.duplicate()
	var s := spec(String(card["id"]))
	var kind := String(s.get("kind", "fixed"))
	var tier := GameConfig.CARD_SECOND_WIND_TIER if kind == "fixed" else roll_tier(rng)
	out["tier"] = tier
	out["value"] = 0.0
	out["amount"] = 0
	out["band"] = ""
	match kind:
		"pct":
			var band: Array = GameConfig.CARD_TIER_BANDS[tier]
			var base := float(s["base"])
			var v := roundf(base * rng.randf_range(float(band[0]), float(band[1])) * 100.0) / 100.0
			out["value"] = maxf(v, 0.01)
			out["desc"] = String(s["fmt"]) % roundi(out["value"] * 100.0)
			out["band"] = "band %d-%d%%" % [roundi(base * float(band[0]) * 100.0), roundi(base * float(band[1]) * 100.0)]
		"flat":
			var band: Array = GameConfig.CARD_TIER_BANDS[tier]
			var base := float(s["base"])
			var step := float(s.get("step", 1.0))
			var v := roundf(base * rng.randf_range(float(band[0]), float(band[1])) / step) * step
			out["value"] = maxf(v, step)
			out["desc"] = String(s["fmt"]) % _num(out["value"], step)
			out["band"] = "band %s-%s" % [_num(base * float(band[0]), step), _num(base * float(band[1]), step)]
		"int":
			out["amount"] = int(GameConfig.CARD_INT_AMOUNT[tier])
			# Legendary plural grammar: only the top tier ever grants amount > 1 (CARD_INT_AMOUNT).
			var fmt_i: String = String(s["fmt_plural"]) if out["amount"] > 1 and s.has("fmt_plural") else String(s["fmt"])
			out["desc"] = fmt_i % out["amount"]
			if tier == 2:
				out["value"] = GameConfig.CARD_INT_EPIC_DAMAGE_PCT
				out["desc"] += " and +%d%% Damage" % roundi(GameConfig.CARD_INT_EPIC_DAMAGE_PCT * 100.0)
		"barrel":
			var share: Array = GameConfig.CARD_BARREL_SHARE[tier]
			out["amount"] = int(GameConfig.CARD_INT_AMOUNT[tier])
			if card.get("lightning", false):
				# Tesla "Extra Arc" (F5): jumps at full strength, not a damage-shared pellet — no
				# damage share to roll, no band to show.
				out["value"] = 1.0
				out["band"] = ""
				var jumps_fmt: String = "+%d Chain Jump" if out["amount"] == 1 else "+%d Chain Jumps"
				out["desc"] = jumps_fmt % out["amount"]
			else:
				out["value"] = roundf(rng.randf_range(float(share[0]), float(share[1])) * 100.0) / 100.0
				var fmt_b: String = String(s["fmt_plural"]) if out["amount"] > 1 and s.has("fmt_plural") else String(s["fmt"])
				out["desc"] = fmt_b % [out["amount"], roundi(out["value"] * 100.0)]
				out["band"] = "band %d-%d%%" % [roundi(float(share[0]) * 100.0), roundi(float(share[1]) * 100.0)]
		"crit":
			var cb: Array = GameConfig.CARD_CRIT_CHANCE[tier]
			out["value"] = float(rng.randi_range(int(cb[0]), int(cb[1])))
			out["desc"] = String(s["fmt"]) % int(out["value"])
			out["band"] = "band %d-%d%%" % [int(cb[0]), int(cb[1])]
	return out

static func _num(v: float, step: float) -> String:
	return str(int(roundf(v))) if step >= 1.0 else "%.1f" % v

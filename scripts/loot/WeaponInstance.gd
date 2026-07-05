class_name WeaponInstance
## Helpers that read a rolled instance dict (see LootRoller) against its base Weapons def
## and Affixes template. Stateless — the dict itself is the source of truth and what gets
## saved. Used by the inventory, the weapon-select UI, and Gun.apply_loot().

## "Superior AK-47" — affix prefix + base weapon name.
static func display_name(inst: Dictionary) -> String:
	var affix := Affixes.get_affix(String(inst.get("affix", "")))
	var base := _base_def(inst)
	var prefix: String = affix.get("name", "")
	var bname: String = base.get("name", String(inst.get("base", "?")))
	return ("%s %s" % [prefix, bname]).strip_edges()

static func color(inst: Dictionary) -> Color:
	return Rarity.color(int(inst.get("rarity", 1)))

static func rarity_name(inst: Dictionary) -> String:
	return Rarity.tier_name(int(inst.get("rarity", 1)))

## Roll-quality label for a 0..1 roll (the god-roll readout).
static func quality_label(roll: float) -> String:
	if roll >= 1.0: return "PERFECT"
	if roll >= 0.95: return "NEAR MAX"
	if roll >= 0.75: return "HIGH"
	if roll >= 0.5: return "GOOD"
	if roll >= 0.25: return "FAIR"
	return "LOW"

## { stat_id: final_value } resolved from the stored 0..1 rolls. % stats are values like
## 18.5 (meaning +18.5%); flat stats are rounded ints (meaning +N).
static func resolved_stats(inst: Dictionary) -> Dictionary:
	var affix := Affixes.get_affix(String(inst.get("affix", "")))
	var out := {}
	for stat_id in inst.get("stats", {}).keys():
		var v := Affixes.resolve(affix, stat_id, float(inst["stats"][stat_id]))
		out[stat_id] = roundi(v) if Affixes.is_flat(stat_id) else v
	return out

## A short one-line stat summary for tooltips: "+18% DMG  +2 MULTISHOT  +14% MAG".
static func stat_summary(inst: Dictionary) -> String:
	const LABELS := {
		"damage": "DMG", "fire_rate": "RoF", "bullet_speed": "SPD", "range": "RNG",
		"reload": "RLD", "mag": "MAG", "multishot": "MULTI", "pierce": "PIERCE", "ricochet": "RICO",
	}
	var parts: Array[String] = []
	for stat_id in resolved_stats(inst):
		var v: float = resolved_stats(inst)[stat_id]
		var label: String = LABELS.get(stat_id, stat_id.to_upper())
		if Affixes.is_flat(stat_id):
			parts.append("+%d %s" % [int(v), label])
		else:
			parts.append("+%d%% %s" % [roundi(v), label])
	return "  ".join(parts)

## Talents whose unlock_level has been reached at the instance's current level.
static func active_talents(inst: Dictionary) -> Array:
	var lvl := int(inst.get("level", 1))
	var out: Array = []
	for t in inst.get("talents", []):
		if int(t.get("unlock_level", 0)) <= lvl:
			out.append(t)
	return out

## Lowest unlock_level among this instance's still-locked talents (unlock_level > current
## level). -1 if every talent is already active (or the instance has none) — used by the
## pay-stub's "next talent at LVk" line.
static func next_locked_talent_level(inst: Dictionary) -> int:
	var lvl := int(inst.get("level", 1))
	var best := -1
	for t in inst.get("talents", []):
		var unlock := int(t.get("unlock_level", 0))
		if unlock > lvl and (best == -1 or unlock < best):
			best = unlock
	return best

## Tooltip line for talents. Active ones plain; still-locked ones tagged with the weapon
## level they unlock at — e.g. "Napalm, Live Wire, Venom (Lv14)".
static func talent_summary(inst: Dictionary) -> String:
	var lvl := int(inst.get("level", 1))
	var parts: Array[String] = []
	for t in inst.get("talents", []):
		var def := Talents.get_talent(String(t.get("id", "")))
		if def.is_empty():
			continue
		var nm: String = def["name"]
		if int(t.get("unlock_level", 0)) > lvl:
			nm += " (Lv%d)" % int(t["unlock_level"])
		parts.append(nm)
	return ", ".join(parts)

## The base Weapons def this instance is built on (empty dict if the id is gone).
static func base_def(inst: Dictionary) -> Dictionary:
	return _base_def(inst)

static func _base_def(inst: Dictionary) -> Dictionary:
	for def in Weapons.all():
		if def["id"] == String(inst.get("base", "")):
			return def
	return {}

## The tile icon for this instance: per-weapon art if present, else the shared placeholder.
static func icon(inst: Dictionary) -> Texture2D:
	var id := String(base_def(inst).get("id", ""))
	var path := "res://art/weapons/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://art/weapons/_placeholder.png")

## Level/XP progress for the inspection popup. needed = level*100 (the Inventory curve in
## Inventory.add_run_xp); frac is 0..1 toward the next level (0 when needed is 0).
static func xp_progress(inst: Dictionary) -> Dictionary:
	var lvl := int(inst.get("level", 1))
	var xp := int(inst.get("xp", 0))
	var needed := lvl * 100
	var frac: float = (float(xp) / float(needed)) if needed > 0 else 0.0
	return { "level": lvl, "xp": xp, "needed": needed, "frac": clampf(frac, 0.0, 1.0) }

## Ordered display rows of the gun's REAL stats = base Weapons def + rolled affix bonuses,
## computed with the SAME formulas Gun.apply_loot/upgrade_* use so the popup matches in-run
## behavior. Each row: { label, value, bonus } — bonus is "" when no affix rolled that stat.
## Character perks / in-run upgrade cards are intentionally excluded: this is the weapon's
## intrinsic profile (what you compare between drops).
static func full_stats(inst: Dictionary) -> Array:
	var base := _base_def(inst)
	if base.is_empty():
		return []
	var s := resolved_stats(inst)   # only rolled stats present; % as e.g. 11.0, flat as ints

	var damage: float = float(base["damage"]) * (1.0 + _pct(s, "damage"))
	var interval: float = float(base["fire_interval"]) * (1.0 - _pct(s, "fire_rate"))
	var rate: float = (1.0 / interval) if interval > 0.0 else 0.0
	var rng: float = float(base["range"]) * (1.0 + _pct(s, "range"))
	var reload: float = float(base["reload_time"]) * (1.0 - _pct(s, "reload"))
	var mag: int = int(ceil(float(base["mag_size"]) * (1.0 + _pct(s, "mag"))))
	var bspeed: float = float(base["bullet_speed"]) * (1.0 + _pct(s, "bullet_speed"))
	var shots: int = int(base["projectiles"]) + int(s.get("multishot", 0))
	var pierce: int = int(s.get("pierce", 0))
	var ricochet: int = int(s.get("ricochet", 0))

	var affix := Affixes.get_affix(String(inst.get("affix", "")))
	var rows: Array = []
	rows.append(_merge({ "label": "DAMAGE", "value": str(roundi(damage)), "bonus": _pct_bonus(s, "damage") }, _stat_quality(inst, affix, "damage", true)))
	rows.append(_merge({ "label": "FIRE RATE", "value": "%.1f/s" % rate, "bonus": _pct_bonus(s, "fire_rate") }, _stat_quality(inst, affix, "fire_rate", true)))
	rows.append(_merge({ "label": "RANGE", "value": str(roundi(rng)), "bonus": _pct_bonus(s, "range") }, _stat_quality(inst, affix, "range", true)))
	rows.append(_merge({ "label": "RELOAD", "value": "%.1fs" % reload, "bonus": _pct_bonus(s, "reload") }, _stat_quality(inst, affix, "reload", true)))
	rows.append(_merge({ "label": "MAGAZINE", "value": str(mag), "bonus": _pct_bonus(s, "mag") }, _stat_quality(inst, affix, "mag", true)))
	# Conditional rows: shown only when relevant, so the block stays clean but never hides a
	# rolled bonus (bullet_speed/multishot/pierce/ricochet only roll on higher rarities).
	if s.has("bullet_speed"):
		rows.append(_merge({ "label": "BULLET SPD", "value": str(roundi(bspeed)), "bonus": _pct_bonus(s, "bullet_speed") }, _stat_quality(inst, affix, "bullet_speed", true)))
	if shots > 1:
		rows.append(_merge({ "label": "MULTISHOT", "value": str(shots), "bonus": _flat_bonus(s, "multishot") }, _stat_quality(inst, affix, "multishot", false)))
	if pierce > 0:
		rows.append(_merge({ "label": "PIERCE", "value": str(pierce), "bonus": _flat_bonus(s, "pierce") }, _stat_quality(inst, affix, "pierce", false)))
	if ricochet > 0:
		rows.append(_merge({ "label": "RICOCHET", "value": str(ricochet), "bonus": _flat_bonus(s, "ricochet") }, _stat_quality(inst, affix, "ricochet", false)))
	return rows

## Detailed talent rows for the popup. Each: { name, color, effect, locked, unlock_level }.
## `effect` = the catalog desc filled with this instance's resolved rolled values. `color` is
## the catalog hint (returned for completeness) — the UI colors active vs locked itself (C4 /
## C3) to honor the locked 4-color palette.
static func talent_details(inst: Dictionary) -> Array:
	var lvl := int(inst.get("level", 1))
	var out: Array = []
	for t in inst.get("talents", []):
		var def := Talents.get_talent(String(t.get("id", "")))
		if def.is_empty():
			continue
		var unlock := int(t.get("unlock_level", 0))
		var rolls: Array = t.get("rolls", [])
		var q := 0.0
		if rolls.size() > 0:
			for r in rolls:
				q += float(r)
			q /= rolls.size()
		out.append({
			"name": String(def["name"]),
			"color": def.get("color", Color.WHITE),
			"effect": _talent_effect(def, rolls),
			"locked": unlock > lvl,
			"unlock_level": unlock,
			"quality": q,
			"quality_label": quality_label(q),
		})
	return out

# --- private formatters for the inspection helpers ---

# 0..1 multiplier from a resolved percent stat (e.g. 11.0 -> 0.11); 0 if the stat wasn't rolled.
static func _pct(stats: Dictionary, id: String) -> float:
	return float(stats.get(id, 0.0)) / 100.0

# "+11%" for a rolled percent stat, "" if not rolled.
static func _pct_bonus(stats: Dictionary, id: String) -> String:
	if not stats.has(id):
		return ""
	return "+%d%%" % roundi(float(stats[id]))

# "+2" for a rolled flat stat, "" if not rolled.
static func _flat_bonus(stats: Dictionary, id: String) -> String:
	if not stats.has(id):
		return ""
	return "+%d" % int(stats[id])

# Roll-quality info for a stat row: {} if the stat wasn't rolled, else {roll, lo, hi, fixed}.
# lo/hi are the affix bonus endpoints as display strings ("+12%" / "+2").
static func _stat_quality(inst: Dictionary, affix: Dictionary, stat_id: String, is_pct: bool) -> Dictionary:
	if not inst.get("stats", {}).has(stat_id):
		return {}
	var roll := float(inst["stats"][stat_id])
	var rng: Array = affix.get("stats", {}).get(stat_id, [0, 0])
	var lo: float = rng[0]
	var hi: float = rng[1]
	var lo_s: String = ("+%d%%" % roundi(lo)) if is_pct else ("+%d" % int(lo))
	var hi_s: String = ("+%d%%" % roundi(hi)) if is_pct else ("+%d" % int(hi))
	return { "roll": roll, "lo": lo_s, "hi": hi_s, "fixed": (lo == hi) }

# Shallow-merge the quality keys into a row dict (no-op if quality is {} - base/unrolled stat).
static func _merge(row: Dictionary, quality: Dictionary) -> Dictionary:
	for k in quality:
		row[k] = quality[k]
	return row

# Fill a talent's desc format string with its resolved rolled mod values.
static func _talent_effect(def: Dictionary, rolls: Array) -> String:
	var mods: Array = def.get("mods", [])
	var vals: Array = []
	for i in mods.size():
		var roll: float = float(rolls[i]) if i < rolls.size() else 0.0
		vals.append(_fmt_num(Talents.resolve(def, i, roll)))
	return String(def.get("desc", "")) % vals

# Round to int for whole-ish or large values; one decimal for small fractionals (e.g. 2.4s).
static func _fmt_num(v: float) -> String:
	if absf(v - roundf(v)) < 0.05 or absf(v) >= 10.0:
		return str(roundi(v))
	return "%.1f" % v

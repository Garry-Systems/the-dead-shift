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

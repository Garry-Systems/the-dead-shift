class_name TalentEngine
## Fires talent effects during combat. Stateless. The Gun resolves its active talents
## (those whose unlock_level <= the weapon's level) into a flat "payload" ONCE on equip;
## every bullet then carries that payload and asks the engine to apply it on hit/kill.
## Resolving once and reading a plain dict per bullet keeps this cheap on mobile.

## Build the per-shot payload from a weapon's active talents (see WeaponInstance).
## payload = { crit_chance: %, crit_mult: x, procs: [ {kind, chance, ...}, ... ] }
static func resolve_payload(active_talents: Array) -> Dictionary:
	var payload := { "crit_chance": 0.0, "crit_mult": 1.0, "procs": [] }
	for t in active_talents:
		var def := Talents.get_talent(String(t.get("id", "")))
		if def.is_empty():
			continue
		var rolls: Array = t.get("rolls", [])
		var v := func(i): return Talents.resolve(def, i, float(rolls[i])) if i < rolls.size() else 0.0
		match String(def["kind"]):
			"crit":
				payload["crit_chance"] += v.call(0)
				payload["crit_mult"] += v.call(1) / 100.0
			"onkill_frenzy":
				payload["procs"].append({ "kind": "frenzy", "rof": v.call(0), "dur": v.call(1) })
			"onhit_knockback":
				payload["procs"].append({ "kind": "knockback", "chance": v.call(0), "force": v.call(1) })
			"onhit_ignite":
				payload["procs"].append({ "kind": "ignite", "chance": v.call(0), "dps": v.call(1), "dur": v.call(2) })
			"onhit_slow":
				payload["procs"].append({ "kind": "slow", "chance": v.call(0), "slow": v.call(1), "dur": v.call(2) })
			"onhit_chain":
				payload["procs"].append({ "kind": "chain", "chance": v.call(0), "jumps": int(round(v.call(1))), "dmg": v.call(2) })
			"onhit_dot":
				payload["procs"].append({ "kind": "dot", "chance": v.call(0), "dps": v.call(1), "dur": v.call(2) })
			"onhit_lifesteal":
				payload["procs"].append({ "kind": "lifesteal", "chance": v.call(0), "heal": v.call(1) })
			"onkill_explode":
				payload["procs"].append({ "kind": "explode", "chance": v.call(0), "dmg": v.call(1), "radius": v.call(2) })
			"onhit_execute":
				payload["procs"].append({ "kind": "execute", "threshold": v.call(0) })
	return payload

## Roll the damage for one hit (applies crit). Returns { damage, crit }.
static func roll_damage(base: float, payload: Dictionary) -> Dictionary:
	if not payload.is_empty() and randf() * 100.0 < float(payload.get("crit_chance", 0.0)):
		return { "damage": base * float(payload.get("crit_mult", 1.0)), "crit": true }
	return { "damage": base, "crit": false }

## Apply every proc for one bullet impact. `base_damage` is pre-crit (chain/explode scale
## off it). `killed` = the impact already killed `body`. ctx = { player, gun, dir, tree }.
static func process_hit(body, hit_pos: Vector2, base_damage: float, killed: bool, payload: Dictionary, ctx: Dictionary) -> void:
	if payload.is_empty():
		return
	var alive: bool = (not killed) and is_instance_valid(body)
	for proc in payload.get("procs", []):
		match String(proc["kind"]):
			"lifesteal":
				if _roll(proc["chance"]) and ctx.get("player") != null and is_instance_valid(ctx["player"]):
					ctx["player"].heal(float(proc["heal"]))
			"chain":
				if _roll(proc["chance"]):
					_chain(hit_pos, body, base_damage * float(proc["dmg"]) / 100.0, int(proc["jumps"]), ctx)
			"frenzy":
				if killed and ctx.get("gun") != null and is_instance_valid(ctx["gun"]):
					ctx["gun"].add_frenzy(float(proc["rof"]) / 100.0, float(proc["dur"]))
			"explode":
				if killed and _roll(proc["chance"]):
					_explode(hit_pos, float(proc["dmg"]), float(proc["radius"]), ctx)
			"ignite":
				if alive and _roll(proc["chance"]) and body.has_method("ignite"):
					body.ignite(float(proc["dps"]), float(proc["dur"]))
			"slow":
				if alive and _roll(proc["chance"]) and body.has_method("apply_slow"):
					body.apply_slow(float(proc["slow"]) / 100.0, float(proc["dur"]))
			"dot":
				if alive and _roll(proc["chance"]) and body.has_method("apply_dot"):
					body.apply_dot(float(proc["dps"]), float(proc["dur"]))
			"knockback":
				if alive and _roll(proc["chance"]) and body.has_method("apply_knockback"):
					var dir: Vector2 = ctx.get("dir", Vector2.ZERO)
					body.apply_knockback(dir * float(proc["force"]))
			"execute":
				if alive and body.has_method("health_fraction") and body.health_fraction() <= float(proc["threshold"]) / 100.0:
					body.take_damage(1_000_000.0)

## Public area-damage helper (used by Gun reload-nova and freeze-shatter). Thin wrapper
## over _explode so callers don't need to build a ctx dict.
static func detonate(pos: Vector2, dmg: float, radius: float, tree) -> void:
	_explode(pos, dmg, radius, { "tree": tree })

static func _roll(chance_pct) -> bool:
	return randf() * 100.0 < float(chance_pct)

## Arc bonus damage from `from_pos` to up to `jumps` nearest enemies, skipping `first`.
static func _chain(from_pos: Vector2, first, dmg: float, jumps: int, ctx: Dictionary) -> void:
	var tree = ctx.get("tree")
	if tree == null:
		return
	var hit := [first]
	var pos := from_pos
	for i in jumps:
		var nxt := _nearest_excluding(pos, hit, 260.0, tree)
		if nxt == null:
			break
		nxt.take_damage(dmg)
		if is_instance_valid(nxt) and nxt.has_method("flash_hit"):
			nxt.flash_hit()
		hit.append(nxt)
		pos = nxt.global_position

## Area damage to every enemy within `radius` of `pos`.
static func _explode(pos: Vector2, dmg: float, radius: float, ctx: Dictionary) -> void:
	var tree = ctx.get("tree")
	if tree == null:
		return
	var r2 := radius * radius
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e as Node2D).global_position.distance_squared_to(pos) <= r2:
			e.take_damage(dmg)

static func _nearest_excluding(pos: Vector2, exclude: Array, max_dist: float, tree) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist * max_dist
	for e in tree.get_nodes_in_group("enemies"):
		if e in exclude or not is_instance_valid(e):
			continue
		var d: float = (e as Node2D).global_position.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = e
	return best

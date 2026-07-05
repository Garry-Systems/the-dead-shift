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
			"onhit_vulnerable":
				payload["procs"].append({ "kind": "vulnerable", "chance": v.call(0), "amount": v.call(1), "dur": v.call(2) })
			"onhit_freeze":
				payload["procs"].append({ "kind": "freeze", "chance": v.call(0), "dur": v.call(1), "shatter": v.call(2), "radius": v.call(3) })
			"onkill_surge":
				payload["procs"].append({ "kind": "surge", "pierce": int(round(v.call(0))), "shots": int(round(v.call(1))), "dur": v.call(2) })
			"onreload_nova":
				# reload_nova is a single payload key: two talents of this kind on one weapon
				# (Backblast + a future Short Fuse/Powder Keg) must MERGE, not overwrite —
				# sum the damage, take the larger radius (Risks #8 / Short Fuse engine note).
				var nova_dmg: float = v.call(0)
				var nova_radius: float = v.call(1)
				if payload.has("reload_nova"):
					var prev_nova: Dictionary = payload["reload_nova"]
					nova_dmg += float(prev_nova.get("dmg", 0.0))
					nova_radius = maxf(nova_radius, float(prev_nova.get("radius", 0.0)))
				payload["reload_nova"] = { "dmg": nova_dmg, "radius": nova_radius }
			"overpen":
				# Same overwrite bug as reload_nova (Risks #8 / Rebar engine note): sum pierce,
				# take the larger growth rate.
				var pierce: int = int(round(v.call(0)))
				var growth: float = v.call(1)
				if payload.has("overpen"):
					var prev_overpen: Dictionary = payload["overpen"]
					pierce += int(prev_overpen.get("pierce", 0))
					growth = maxf(growth, float(prev_overpen.get("growth", 0.0)))
				payload["overpen"] = { "pierce": pierce, "growth": growth }
	return payload

## Roll the damage for one hit (applies crit). Returns { damage, crit }.
static func roll_damage(base: float, payload: Dictionary) -> Dictionary:
	if not payload.is_empty() and randf() * 100.0 < float(payload.get("crit_chance", 0.0)):
		return { "damage": base * float(payload.get("crit_mult", 1.0)), "crit": true }
	return { "damage": base, "crit": false }

## --- Per-frame transient-VFX budget (Risks #2) ------------------------------------------
## Gameplay (damage/status) never checks this — only cosmetic ring/lightning/mote spawns do,
## so a horde-wide proc storm (chain + explode + shatter rings all landing the same frame)
## sheds VISUAL load instead of ever dropping a proc's actual effect. Frame-keyed static
## counter, mirroring Destructible._claim_detonation_slot's idiom.
static var _vfx_frame := -1
static var _vfx_count := 0

static func _claim_vfx_slot() -> bool:
	var frame := Engine.get_process_frames()
	if _vfx_frame != frame:
		_vfx_frame = frame
		_vfx_count = 0
	if _vfx_count >= GameConfig.TALENT_VFX_MAX_PER_FRAME:
		return false
	_vfx_count += 1
	return true

## Budget-gated colored Shockwave ring (visual only — flash() does no damage/knockback). Every
## onhit/onkill/onreload proc ring in the game routes through this one helper so the frame
## budget is enforced in exactly one place.
static func spawn_ring(pos: Vector2, radius: float, color: Color, tree) -> void:
	if tree == null or radius <= 0.0 or not _claim_vfx_slot():
		return
	var sw := Shockwave.new()
	tree.current_scene.add_child(sw)
	sw.global_position = pos
	sw.color = color
	sw.flash(radius)

## Budget-gated LeechMote + a rim blip on the player — the lifesteal tell (Bloodthirst/Leech).
## Counts as ONE vfx spawn (mote + blip together), so a lifesteal-heavy build still only ever
## costs the budget once per proc, not twice.
static func _spawn_lifesteal_vfx(from_pos: Vector2, player, tree) -> void:
	if tree == null or not _claim_vfx_slot():
		return
	LeechMote.spawn(from_pos, player, tree)
	if player.has_method("lifesteal_blip"):
		player.lifesteal_blip(Hazards.BLOOD_RED)

## Apply every proc for one bullet impact. `base_damage` is pre-crit (chain/explode scale
## off it). `killed` = the impact already killed `body`. ctx = { player, gun, dir, tree, crit }
## (`crit` = whether this hit's own roll_damage() crit — Phase 1 threads it through for the
## floating gold number; Phase 2's Double Tap reads the same key).
static func process_hit(body, hit_pos: Vector2, base_damage: float, killed: bool, payload: Dictionary, ctx: Dictionary) -> void:
	if payload.is_empty():
		return
	var alive: bool = (not killed) and is_instance_valid(body)
	var tree = ctx.get("tree")
	for proc in payload.get("procs", []):
		match String(proc["kind"]):
			"lifesteal":
				if _roll(proc["chance"]) and ctx.get("player") != null and is_instance_valid(ctx["player"]):
					var player = ctx["player"]
					player.heal(float(proc["heal"]))
					_spawn_lifesteal_vfx(hit_pos, player, tree)
			"chain":
				if _roll(proc["chance"]):
					_chain(hit_pos, body, base_damage * float(proc["dmg"]) / 100.0, int(proc["jumps"]), ctx)
			"frenzy":
				if killed and ctx.get("gun") != null and is_instance_valid(ctx["gun"]):
					ctx["gun"].add_frenzy(float(proc["rof"]) / 100.0, float(proc["dur"]))
			"explode":
				if killed and _roll(proc["chance"]):
					_explode(hit_pos, float(proc["dmg"]), float(proc["radius"]), ctx)
					spawn_ring(hit_pos, float(proc["radius"]), Hazards.ORANGE, tree)
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
					spawn_ring(hit_pos, GameConfig.TALENT_EXECUTE_RING_RADIUS, Hazards.BLOOD_RED, tree)
					CombatText.callout(hit_pos, "EXECUTED", Hazards.BLOOD_RED)
			"vulnerable":
				if alive and _roll(proc["chance"]) and body.has_method("apply_vulnerable"):
					body.apply_vulnerable(float(proc["amount"]) / 100.0, float(proc["dur"]))
					spawn_ring(hit_pos, GameConfig.TALENT_VULN_RING_RADIUS, Hazards.GOLD, tree)
			"freeze":
				if alive and body.has_method("apply_freeze"):
					if body.has_method("is_frozen") and body.is_frozen():
						var shatter_radius := float(proc["radius"])
						detonate(hit_pos, float(proc["shatter"]), shatter_radius, tree)
						spawn_ring(hit_pos, shatter_radius, Enemy.FROZEN_TINT, tree)
						spawn_ring(hit_pos, shatter_radius * GameConfig.TALENT_SHATTER_CORE_FRAC, Color(1, 1, 1, 1), tree)
						CombatText.callout(hit_pos, "SHATTER", Enemy.FROZEN_TINT)
					elif _roll(proc["chance"]):
						body.apply_freeze(float(proc["dur"]))
			"surge":
				if killed and ctx.get("gun") != null and is_instance_valid(ctx["gun"]):
					ctx["gun"].add_surge(int(proc["pierce"]), int(proc["shots"]), float(proc["dur"]))

## Public area-damage helper (used by Gun reload-nova and freeze-shatter). Thin wrapper
## over _explode so callers don't need to build a ctx dict.
static func detonate(pos: Vector2, dmg: float, radius: float, tree) -> void:
	_explode(pos, dmg, radius, { "tree": tree })

static func _roll(chance_pct) -> bool:
	return randf() * 100.0 < float(chance_pct)

## Arc bonus damage from `from_pos` to up to `jumps` nearest enemies, skipping `first`. Also
## draws the real cyan Lightning bolt along the exact walk (Live Wire/Arc Welder/Static Cling/
## Death Rattle all share this — previously the single biggest invisible-proc gap in the game).
static func _chain(from_pos: Vector2, first, dmg: float, jumps: int, ctx: Dictionary) -> void:
	var tree = ctx.get("tree")
	if tree == null:
		return
	var hit := [first]
	var pos := from_pos
	var points: Array = [from_pos]
	for i in jumps:
		var nxt := _nearest_excluding(pos, hit, 260.0, tree)
		if nxt == null:
			break
		nxt.take_damage(dmg)
		if is_instance_valid(nxt) and nxt.has_method("flash_hit"):
			nxt.flash_hit()
		hit.append(nxt)
		pos = nxt.global_position
		points.append(pos)
	if points.size() >= 2:
		_spawn_chain_lightning(points, tree)

## Budget-gated: the visual bolt sheds load first under a horde-wide proc storm; the damage
## above never does.
static func _spawn_chain_lightning(points: Array, tree) -> void:
	if not _claim_vfx_slot():
		return
	var bolt := Lightning.new()
	bolt.points = points
	tree.current_scene.add_child(bolt)

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

class_name TalentEngine
## Fires talent effects during combat. Stateless. The Gun resolves its active talents
## (those whose unlock_level <= the weapon's level) into a flat "payload" ONCE on equip;
## every bullet then carries that payload and asks the engine to apply it on hit/kill.
## Resolving once and reading a plain dict per bullet keeps this cheap on mobile.

## Build the per-shot payload from a weapon's active talents (see WeaponInstance).
## payload = { crit_chance: %, crit_mult: x, procs: [ {kind, chance, ...}, ... ],
##   reload_nova?: {dmg,radius}, overpen?: {pierce,growth},         (Phase 1, merged not overwritten)
##   cc_bonus?: frac, first_shot?: frac, last_call?: frac,          (Phase 2 passives, Gun-read)
##   lowhp_frenzy?: {threshold,rof}, aura_slow?: {radius,slow}, hurt_nova?: {dmg,radius} }
## Per-hit `procs` entries add these Phase 2 kinds: pin, ammo, bolt, pool, spread, mine, fear,
## gravity, dot_detonate, echo — each fires from TalentEngine.process_hit exactly like the
## Phase 1 kinds (chain/dot/lifesteal/explode/knockback/execute/vulnerable/freeze/frenzy/surge).
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
				# `callout` lets a talent override the default "EXECUTED" word (Pink Slip: "FIRED.")
				# — a generic per-talent override, not a hardcoded id check in the engine.
				payload["procs"].append({ "kind": "execute", "threshold": v.call(0),
					"callout": String(def.get("callout", "EXECUTED")) })
			"onhit_vulnerable":
				# `ring` lets a talent override the default mark-ring radius (Death Warrant rolls
				# a visibly bigger pulse than Marked/Chalk Outline — same generic override shape).
				payload["procs"].append({ "kind": "vulnerable", "chance": v.call(0), "amount": v.call(1), "dur": v.call(2),
					"ring": float(def.get("vuln_ring", GameConfig.TALENT_VULN_RING_RADIUS)) })
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

			# --- Phase 2: new proc kinds (per-hit procs first, then Gun-passive payload keys) ---
			"onhit_pin":
				# Deadbolt: reuses the Nail Gun's apply_pin channel verbatim (boss-immunity comes
				# free via the has_method gate at the call site in process_hit).
				payload["procs"].append({ "kind": "pin", "chance": v.call(0), "dur": v.call(1) })
			"onkill_ammo":
				# Brass Picker: Gun.refund_rounds() no-ops mid-reload.
				payload["procs"].append({ "kind": "ammo", "chance": v.call(0), "rounds": int(round(v.call(1))) })
			"onkill_bolt":
				# Death Rattle: 100% reuse of _chain (Static Cling's onhit_chain sibling, but
				# kill-gated) — the corpse arcs a bolt through the horde.
				payload["procs"].append({ "kind": "bolt", "chance": v.call(0), "jumps": int(round(v.call(1))), "dmg": v.call(2) })
			"onkill_pool":
				# Bile Spill: spawns an enemy-only HazardZone sharing the Acid Cannon's
				# MAX_PLAYER_POOLS cap (Risks #3). Kill-gated = a natural rate limit; no ICD needed.
				payload["procs"].append({ "kind": "pool", "chance": v.call(0), "dps": v.call(1), "dur": v.call(2), "radius": v.call(3) })
			"onkill_spread":
				# Outbreak: copies the corpse's status_snapshot() onto nearby enemies.
				payload["procs"].append({ "kind": "spread", "chance": v.call(0), "radius": v.call(1) })
			"onkill_mine":
				# Parting Gift: pooled Mine node, capped at MAX_PLAYER_MINES.
				payload["procs"].append({ "kind": "mine", "chance": v.call(0), "dmg": v.call(1), "radius": v.call(2) })
			"onhit_fear":
				# Night Terror: Enemy.apply_fear (has_method-gated — boss-immune for free).
				payload["procs"].append({ "kind": "fear", "chance": v.call(0), "dur": v.call(1) })
			"onhit_gravity":
				# Black Friday: pooled GravityWell, capped at MAX_GRAVITY_WELLS (1 live).
				payload["procs"].append({ "kind": "gravity", "chance": v.call(0), "dur": v.call(1), "radius": v.call(2) })
			"onhit_dot_detonate":
				# Septic Shock: converts remaining burn+poison damage into an instant burst.
				payload["procs"].append({ "kind": "dot_detonate", "chance": v.call(0), "frac": v.call(1) / 100.0, "radius": v.call(2) })
			"oncrit_echo":
				# Double Tap: only fires when ctx['crit'] is true (the same plumbing the crit
				# floating numbers already use — free, per Risks #4/#6).
				payload["procs"].append({ "kind": "echo", "chance": v.call(0), "dmg": v.call(1) })
			"cc_bonus":
				# Curb Stomp: a single summed key like overpen/reload_nova, but merged as MAX —
				# only one talent uses this kind today; Risks #9 says don't let it stack across
				# copies if that ever changes.
				payload["cc_bonus"] = maxf(float(payload.get("cc_bonus", 0.0)), v.call(0) / 100.0)
			"first_shot_bonus":
				# Clock In: additive across copies (matches the codebase's compounding-percent
				# convention for stacked damage bonuses — see upgrade_damage).
				payload["first_shot"] = float(payload.get("first_shot", 0.0)) + v.call(0) / 100.0
			"low_mag_bonus":
				# Last Call: additive across copies, same convention as first_shot above.
				payload["last_call"] = float(payload.get("last_call", 0.0)) + v.call(0) / 100.0
			"lowhp_frenzy":
				# Graveyard Shift: {threshold, rof} merged as MAX (only one talent uses this kind
				# today; future-proofed the same way reload_nova/overpen are).
				var lf_threshold: float = v.call(0) / 100.0
				var lf_rof: float = v.call(1) / 100.0
				if payload.has("lowhp_frenzy"):
					var prev_lf: Dictionary = payload["lowhp_frenzy"]
					lf_threshold = maxf(lf_threshold, float(prev_lf.get("threshold", 0.0)))
					lf_rof = maxf(lf_rof, float(prev_lf.get("rof", 0.0)))
				payload["lowhp_frenzy"] = { "threshold": lf_threshold, "rof": lf_rof }
			"aura_slow":
				# Closing Time: {radius, slow} merged as MAX, same shape as lowhp_frenzy above.
				var aura_radius: float = v.call(0)
				var aura_slow_frac: float = v.call(1) / 100.0
				if payload.has("aura_slow"):
					var prev_aura: Dictionary = payload["aura_slow"]
					aura_radius = maxf(aura_radius, float(prev_aura.get("radius", 0.0)))
					aura_slow_frac = maxf(aura_slow_frac, float(prev_aura.get("slow", 0.0)))
				payload["aura_slow"] = { "radius": aura_radius, "slow": aura_slow_frac }
			"onhurt_nova":
				# Dead Man's Switch: {dmg, radius} merged exactly like reload_nova (sum dmg, max
				# radius) — the same Risks #8 shape, future-proofed against a second source.
				var hn_dmg: float = v.call(0)
				var hn_radius: float = v.call(1)
				if payload.has("hurt_nova"):
					var prev_hn: Dictionary = payload["hurt_nova"]
					hn_dmg += float(prev_hn.get("dmg", 0.0))
					hn_radius = maxf(hn_radius, float(prev_hn.get("radius", 0.0)))
				payload["hurt_nova"] = { "dmg": hn_dmg, "radius": hn_radius }
	return payload

## Roll the damage for one hit (applies crit). Returns { damage, crit }.
static func roll_damage(base: float, payload: Dictionary) -> Dictionary:
	if not payload.is_empty() and randf() * 100.0 < float(payload.get("crit_chance", 0.0)):
		return { "damage": base * float(payload.get("crit_mult", 1.0)), "crit": true }
	return { "damage": base, "crit": false }

## Clock In (`first_shot_bonus`, consumed once) + Last Call (`low_mag_bonus`, scales with
## emptiness) combined into one shot-level damage multiplier. Pure + static so a probe can
## verify both formulas headlessly. `armed` is Gun._first_shot_armed BEFORE the call — the
## CALLER clears the flag itself (this function has no side effects). Percent bonuses compound
## multiplicatively, matching the codebase's existing convention for stacked damage bonuses
## (Gun.upgrade_damage: `damage *= (1.0 + pct)` per card).
static func shot_damage_mult(payload: Dictionary, armed: bool, ammo: int, mag_size: int) -> float:
	var mult := 1.0
	if armed:
		mult *= (1.0 + float(payload.get("first_shot", 0.0)))
	var last_call_frac: float = float(payload.get("last_call", 0.0))
	if last_call_frac > 0.0 and mag_size > 0:
		mult *= (1.0 + last_call_frac * (1.0 - float(ammo) / float(mag_size)))
	return mult

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
					CombatText.callout(hit_pos, String(proc.get("callout", "EXECUTED")), Hazards.BLOOD_RED)
			"vulnerable":
				if alive and _roll(proc["chance"]) and body.has_method("apply_vulnerable"):
					body.apply_vulnerable(float(proc["amount"]) / 100.0, float(proc["dur"]))
					spawn_ring(hit_pos, float(proc.get("ring", GameConfig.TALENT_VULN_RING_RADIUS)), Hazards.GOLD, tree)
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
			"pin":
				if alive and _roll(proc["chance"]) and body.has_method("apply_pin"):
					body.apply_pin(float(proc["dur"]))
			"ammo":
				if killed and _roll(proc["chance"]) and ctx.get("gun") != null and is_instance_valid(ctx["gun"]):
					ctx["gun"].refund_rounds(int(proc["rounds"]))
			"bolt":
				if killed and _roll(proc["chance"]):
					_chain(hit_pos, body, base_damage * float(proc["dmg"]) / 100.0, int(proc["jumps"]), ctx)
			"pool":
				if killed and _roll(proc["chance"]) and tree != null:
					_spawn_bile_pool(hit_pos, proc, tree)
			"spread":
				if killed and _roll(proc["chance"]) and body.has_method("status_snapshot"):
					_spread_status(hit_pos, body, body.status_snapshot(), float(proc["radius"]), tree)
			"mine":
				if killed and _roll(proc["chance"]):
					Mine.spawn(hit_pos, float(proc["dmg"]), float(proc["radius"]), tree)
			"fear":
				if alive and _roll(proc["chance"]) and body.has_method("apply_fear"):
					body.apply_fear(float(proc["dur"]))
			"gravity":
				if alive and _roll(proc["chance"]):
					_spawn_gravity_well(hit_pos, float(proc["dur"]), float(proc["radius"]), tree)
			"dot_detonate":
				if alive and _roll(proc["chance"]) and body.has_method("dot_remaining") and body.has_method("clear_dots"):
					var remaining: float = body.dot_remaining()
					if remaining > 0.0:
						var burst: float = remaining * float(proc["frac"])
						var rupture_radius: float = float(proc["radius"])
						body.clear_dots()
						detonate(hit_pos, burst, rupture_radius, tree)
						spawn_ring(hit_pos, rupture_radius, Hazards.GREEN, tree)
						spawn_ring(hit_pos, rupture_radius * GameConfig.TALENT_RUPTURE_INNER_FRAC, Hazards.ORANGE, tree)
						CombatText.callout(hit_pos, "RUPTURE", Hazards.GREEN)
			"echo":
				if alive and bool(ctx.get("crit", false)) and _roll(proc["chance"]):
					_echo_hit(body, hit_pos, base_damage * float(proc["dmg"]) / 100.0, tree)

## Curb Stomp (`cc_bonus`): passive pre-crit damage multiplier vs a hampered (slowed/frozen/
## pinned) target. `hampered` is precomputed by the caller (each hit site already needs a
## has_method("is_hampered") check to decide the flash tint, so this stays a pure multiply).
static func apply_cc_bonus(dmg: float, payload: Dictionary, hampered: bool) -> float:
	if not hampered:
		return dmg
	return dmg * (1.0 + float(payload.get("cc_bonus", 0.0)))

## The flash tint for a single hit: C2 indigo when Curb Stomp's bonus actually applied (a
## "boosted hit" on a hampered target), white otherwise. One helper so every hit site that
## calls flash_hit shares the same tell instead of repeating the condition.
static func cc_flash_tint(hampered: bool) -> Color:
	return Enemy.FROZEN_TINT if hampered else Color(1, 1, 1, 1)

## Bile Spill (`onkill_pool`): an enemy-only HazardZone at the kill site, sharing the Acid
## Cannon's MAX_PLAYER_POOLS cap (Risks #3) via the same static every player-pool spawner rides.
static func _spawn_bile_pool(pos: Vector2, proc: Dictionary, tree) -> void:
	HazardZone.cap_player_pools(tree)
	var zone := HazardZone.new()
	tree.current_scene.add_child(zone)
	zone.global_position = pos
	zone.configure_hazard({
		"color": Hazards.GREEN, "dps": float(proc["dps"]), "radius": float(proc["radius"]),
		"duration": float(proc["dur"]), "slow": 0.0, "slow_dur": 0.0, "stun": 0.0, "chain": 0,
		"drift": 0.0, "hurts_player": false,
	})

## Outbreak (`onkill_spread`): reads the corpse's status_snapshot() (already captured by the
## caller BEFORE this call — Risks #5, never re-read after a deferred queue_free) and re-applies
## every active channel onto up to TALENT_OUTBREAK_SPREAD_CAP nearest enemies in radius (a hard
## target cap, group scan like _explode). `corpse` is excluded from its own spread.
static func _spread_status(pos: Vector2, corpse, snap: Dictionary, radius: float, tree) -> void:
	if tree == null:
		return
	var burn_dps: float = float(snap.get("burn_dps", 0.0))
	var burn_time: float = float(snap.get("burn_time", 0.0))
	var dot_dps: float = float(snap.get("dot_dps", 0.0))
	var dot_time: float = float(snap.get("dot_time", 0.0))
	var slow_factor: float = float(snap.get("slow_factor", 1.0))
	var slow_time: float = float(snap.get("slow_time", 0.0))
	if burn_time <= 0.0 and dot_time <= 0.0 and slow_time <= 0.0:
		return   # nothing active on the corpse to spread
	var r2 := radius * radius
	var targets: Array = []
	for e in tree.get_nodes_in_group("enemies"):
		if e == corpse or not is_instance_valid(e):
			continue
		if (e as Node2D).global_position.distance_squared_to(pos) <= r2:
			targets.append(e)
	targets.sort_custom(func(a, b): return (a as Node2D).global_position.distance_squared_to(pos) < (b as Node2D).global_position.distance_squared_to(pos))
	for i in mini(targets.size(), GameConfig.TALENT_OUTBREAK_SPREAD_CAP):
		var e = targets[i]
		if burn_time > 0.0 and e.has_method("ignite"):
			e.ignite(burn_dps, burn_time)
		if dot_time > 0.0 and e.has_method("apply_dot"):
			e.apply_dot(dot_dps, dot_time)
		if slow_time > 0.0 and slow_factor < 1.0 and e.has_method("apply_slow"):
			e.apply_slow(1.0 - slow_factor, slow_time)
	spawn_ring(pos, radius, Hazards.GREEN, tree)
	CombatText.callout(pos, "OUTBREAK", Hazards.GREEN)

## Black Friday (`onhit_gravity`): capped at MAX_GRAVITY_WELLS (a second proc while one is live
## is simply skipped, not queued — no "next in line" behavior needed for a 1-slot cap).
static func _spawn_gravity_well(pos: Vector2, duration: float, radius: float, tree) -> void:
	if tree == null or tree.get_nodes_in_group(GravityWell.GROUP).size() >= GameConfig.MAX_GRAVITY_WELLS:
		return
	var well := GravityWell.new()
	tree.current_scene.add_child(well)
	well.global_position = pos
	well.setup(duration, radius)
	CombatText.callout(pos, "BLACK FRIDAY", Enemy.FROZEN_TINT)

## Double Tap (`oncrit_echo`): schedules a second hit at `dmg` a beat after the first, on the
## SAME target, if it's still alive. Deals raw take_damage — never re-enters process_hit, so it
## cannot itself crit or re-trigger echo/on-crit procs (recursion-proof by construction, Risks
## #6). Uses a Tween (the project's existing delayed-callback idiom — Enemy/Player flash fades,
## ScreenFlash) instead of `await`, so this stays a plain fire-and-forget static call.
static func _echo_hit(body, hit_pos: Vector2, dmg: float, tree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var tw: Tween = tree.current_scene.create_tween()
	tw.tween_interval(GameConfig.TALENT_ECHO_DELAY)
	tw.tween_callback(_resolve_echo.bind(body, hit_pos, dmg))

## The echo's actual hit, run after the delay above. Re-validates aliveness (something else may
## have killed the target in the meantime) before dealing damage.
static func _resolve_echo(body, hit_pos: Vector2, dmg: float) -> void:
	if not is_instance_valid(body):
		return
	if not (body.has_method("health_fraction") and body.health_fraction() > 0.0):
		return
	body.take_damage(dmg)
	if not is_instance_valid(body):
		return
	if body.has_method("flash_hit"):
		body.flash_hit()
	# source_id 0 (the proximity fallback) + a Y offset past the crit ICD's dedupe radius, so
	# this renders as a SECOND number "stacking under" the original crit instead of being
	# suppressed as a same-enemy re-crit (see GameConfig.TALENT_ECHO_TEXT_OFFSET).
	CombatText.crit(hit_pos + Vector2(0.0, GameConfig.TALENT_ECHO_TEXT_OFFSET), dmg, 0)

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

extends SceneTree
## Throwaway logic probe for the obstacle/hazard registries. Run headless:
##   ...console.exe --path "...mobile-game" --headless --editor --script res://probe_obstacles.gd
## class_name globals (Obstacles/Hazards/GameConfig) are available in --script mode; autoloads
## and physics (LineOfSight) are NOT — those are verified by F5. Pure data only here.

func _init() -> void:
	var fails := 0

	# 1. Registry shape: 6 rows, all required keys present.
	var rows := Obstacles.all()
	if rows.size() != 6:
		print("PROBE FAIL: expected 6 obstacle rows, got %d" % rows.size()); fails += 1
	for row in rows:
		for key in ["id","kind","shape","size","solid","hp","hazard_id","loot","gem_count","weight","min_wave"]:
			if not row.has(key):
				print("PROBE FAIL: row %s missing key %s" % [row.get("id","?"), key]); fails += 1

	# 2. Wave gating: pick(1) never returns a min_wave>1 type (drum=2, transformer=3).
	for i in 400:
		var r1 := Obstacles.pick(1)
		if int(r1["min_wave"]) > 1:
			print("PROBE FAIL: pick(1) returned %s (min_wave %d)" % [r1["id"], r1["min_wave"]]); fails += 1
			break

	# 3. High wave can include gated types (statistical sanity over 400 picks).
	var seen := {}
	for i in 400:
		seen[String(Obstacles.pick(20)["id"])] = true
	if not seen.has("transformer"):
		print("PROBE FAIL: pick(20) never produced a transformer in 400 tries"); fails += 1

	# 4 + 5. Hazard tuning: families valid; fire no-slow, acid slows, electric stuns+chains.
	var fire := Hazards.stats_for("fire")
	var acid := Hazards.stats_for("acid")
	var elec := Hazards.stats_for("electric")
	if fire.is_empty() or float(fire["dps"]) <= 0.0:
		print("PROBE FAIL: fire hazard invalid"); fails += 1
	if float(fire["slow"]) != 0.0:
		print("PROBE FAIL: fire should not slow"); fails += 1
	if float(acid["slow"]) <= 0.0:
		print("PROBE FAIL: acid should slow"); fails += 1
	if float(elec["stun"]) <= 0.0 or int(elec["chain"]) <= 0:
		print("PROBE FAIL: electric should stun + chain"); fails += 1
	if not Hazards.stats_for("none").is_empty():
		print("PROBE FAIL: unknown hazard id should return {}"); fails += 1

	if fails == 0:
		print("PROBE PASS: all obstacle/hazard logic checks green")
	else:
		print("PROBE FAILED: %d check(s)" % fails)
	quit()

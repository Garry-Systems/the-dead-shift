class_name CommendationProgress
## Pure save-dict merge math for the Commendations wall (Pack H: v0.1.59). Mirrors
## ChallengeProgress.gd's shape exactly: no Node/autoload dependency — SaveManager delegates here
## and writes the returned dict back into its own `_data`, so a headless probe can verify the
## grant math directly against a plain Dictionary.
##
## Exactly-once guarantee: identical to every other lifetime record in this game (LifetimeRecords.
## merge_run / ChallengeProgress.apply_counters), NOT via any guard inside this file — a badge is
## marked earned (appended to `commendations_earned`) as the FIRST step of granting it, so a
## defensive double-call within the same tick sees it already recorded and skips it. The real
## once-per-badge guarantee across an app-kill window is "memory-only until SaveManager.save_game()
## succeeds": check_and_grant() is called from inside the SAME RunStats.paid_out-guarded flush
## block that already protects the coin payout / rank XP / lifetime records / challenge counters
## (GameOver._finish_run, PauseMenu._abandon_run_payout), and that block calls save_game() exactly
## once at the end. A process kill mid-flush loses the WHOLE run's tally uniformly (coins, rank XP,
## lifetime records, challenge counters, AND any commendation just granted) — there is no window
## where a commendation is granted but the run's other results aren't, or vice versa. The
## menu-entry call site (MainMenu._check_free_rewards) saves at its own single chokepoint the same
## way the challenge-crate-reward queue already does.

## Ids in Commendations.all() whose condition is met per `data` but not yet in
## `data.commendations_earned`.
static func newly_earned_ids(data: Dictionary) -> Array:
	var earned: Array = data.get("commendations_earned", [])
	var new_ids: Array = []
	for row in Commendations.all():
		var id := String(row["id"])
		if id in earned:
			continue
		if Commendations.is_earned(row, data):
			new_ids.append(id)
	return new_ids

## Grants every newly-earned commendation (see newly_earned_ids): marks it earned, adds its
## tiered rank XP + one-time crate (through the SAME dict math as SaveManager.add_rank_xp/
## add_crate — duplicated here so this file stays Node/autoload-free, matching
## ChallengeProgress._grant_crate's convention), and queues the id for reveal at the next menu
## entry (SaveManager.take_pending_commendation_rewards). Returns a NEW dict; no-op copy if
## nothing newly qualifies.
static func check_and_grant(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var new_ids := newly_earned_ids(out)
	if new_ids.is_empty():
		return out
	var earned: Array = (out.get("commendations_earned", []) as Array).duplicate()
	var pending: Array = (out.get("pending_commendation_rewards", []) as Array).duplicate()
	for id in new_ids:
		earned.append(id)   # marked BEFORE the grant math below — see the exactly-once doc comment above
		var row := Commendations.by_id(String(id))
		var tier: Dictionary = row.get("tier", {})
		out = _add_rank_xp(out, int(tier.get("rank_xp", 0)))
		out = _add_crate(out, String(tier.get("crate_id", "")))
		pending.append(id)
	out["commendations_earned"] = earned
	out["pending_commendation_rewards"] = pending
	return out

## Duplicates SaveManager.add_rank_xp's dict math exactly (same threshold-crossing detection +
## "stamp pending_promotion_from_rank only the first time a window opens" rule), so this file has
## zero autoload dependency, matching LifetimeRecords/ChallengeProgress. A commendation-driven
## promotion behaves IDENTICALLY to a run-payout-driven one: if this pushes rank_xp past a
## threshold, pending_promotion is set here in the SAME save-dict transform, and the EXISTING
## MainMenu._check_free_rewards promotion check (which runs immediately after the commendation-
## reveal queueing loop — see that function's call order) picks it up and queues its own PROMOTED
## popup right after the COMMENDATION EARNED popup(s), in the same pass.
static func _add_rank_xp(data: Dictionary, amount: int) -> Dictionary:
	var out := data.duplicate(true)
	if amount <= 0:
		return out
	var before := Ranks.rank_for(int(out.get("rank_xp", 0)))
	out["rank_xp"] = int(out.get("rank_xp", 0)) + amount
	var after := Ranks.rank_for(int(out["rank_xp"]))
	if after > before:
		if not bool(out.get("pending_promotion", false)):
			out["pending_promotion_from_rank"] = before
		out["pending_promotion"] = true
	return out

## Duplicates SaveManager.add_crate's dict math (identical shape to ChallengeProgress._grant_crate).
static func _add_crate(data: Dictionary, crate_id: String) -> Dictionary:
	var out := data.duplicate(true)
	var crates: Dictionary = (out.get("crates", {}) as Dictionary).duplicate()
	crates[crate_id] = int(crates.get(crate_id, 0)) + 1
	out["crates"] = crates
	return out

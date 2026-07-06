class_name ChallengeProgress
## Pure save-dict merge math for the challenge board (Pack C: Challenges + daily shift, v0.1.53).
## Mirrors LifetimeRecords.gd's shape exactly: no Node/file dependency — SaveManager delegates
## here and writes the returned dict back into its own `_data`, so a headless probe can verify
## the arithmetic directly against a plain Dictionary. NOT idempotent (same caveat as
## LifetimeRecords.merge_run): calling apply_counters()/bump_counter() twice for the same event
## double-counts. Exactly-once for the run-scoped path is the CALLER's RunStats.paid_out guard
## (GameOver._finish_run / PauseMenu._abandon_run_payout); the menu-action path
## (crates_opened/fusions_done) has no such guard because each call already corresponds to
## exactly one real, non-repeatable action (a crate settling, a fusion succeeding) — there is no
## death-vs-quit race to guard against for a button press.
##
## Rotation model — deliberately the SIMPLEST honest one, not "keep in-progress, replace only the
## completed slots": the active challenge ids are a PURE FUNCTION of the date string
## (Challenges.active_ids_for) — nothing about *which* challenges are active is ever stored, so
## there is nothing to desync. Only PROGRESS is stored, and it belongs to exactly one date
## (`challenge_date`). The instant ensure_rotation() sees `data.challenge_date != today`, it wipes
## `challenge_progress`/`challenge_completed` back to {}/[] and stamps `challenge_date = today` —
## ALL active challenges reroll AND all progress resets, every single day, unconditionally. A
## challenge finished today that happens to be re-picked tomorrow simply starts over at 0. This
## is a deliberate simplicity trade-off per the brief ("pick the simplest honest model and
## document it") over a more elaborate "carry over unfinished progress" scheme.

## Ensures `data`'s rotation bookkeeping belongs to `today` ("YYYY-MM-DD"); wipes progress/
## completed on a date change. Always goes through this before reading OR writing progress so a
## stale rotation can never leak into a new day's numbers. Returns the (possibly mutated) dict.
static func ensure_rotation(data: Dictionary, today: String) -> Dictionary:
	var out := data.duplicate(true)
	if String(out.get("challenge_date", "")) != today:
		out["challenge_date"] = today
		out["challenge_progress"] = {}
		out["challenge_completed"] = []
	return out

## Run-scoped flush: applies every challenge active TODAY whose counter_key is present in
## `counters` (a plain Dictionary of this run's tallies — see GameOver/PauseMenu call sites for
## exactly what they supply). Rows whose counter_key isn't in `counters` are left untouched.
static func apply_counters(data: Dictionary, counters: Dictionary, today: String) -> Dictionary:
	var out := ensure_rotation(data, today)
	for id in Challenges.active_ids_for(today):
		var row := Challenges.by_id(id)
		if row.is_empty():
			continue
		var key := String(row["counter_key"])
		if not counters.has(key):
			continue
		out = _apply_one(out, row, float(counters[key]))
	return out

## Immediate single-counter bump (crate opened / weapon fused). `amount` is an increment (agg
## "sum" is the only aggregation any menu-action row currently uses, but "max" is honored too for
## symmetry). No-op for challenges not active today or not matching `counter_key`.
static func bump_counter(data: Dictionary, counter_key: String, amount: float, today: String) -> Dictionary:
	var out := ensure_rotation(data, today)
	for id in Challenges.active_ids_for(today):
		var row := Challenges.by_id(id)
		if row.is_empty() or String(row["counter_key"]) != counter_key:
			continue
		out = _apply_one(out, row, amount)
	return out

## Aggregates `value` into `row`'s progress ("sum": add; "max": keep the larger) and, on a
## not-yet-completed -> target-reached transition, marks it completed, grants its reward crate
## (dict math identical to SaveManager.add_crate — duplicated here so this stays a pure
## Dictionary transform), and queues the crate id for reveal at the next menu entry
## (SaveManager.take_pending_challenge_rewards). Re-crossing the target on a later run within the
## same day's rotation is a no-op past the first crossing — one reward per rotation slot per day.
static func _apply_one(data: Dictionary, row: Dictionary, value: float) -> Dictionary:
	var out := data.duplicate(true)
	var id := String(row["id"])

	var progress: Dictionary = (out.get("challenge_progress", {}) as Dictionary).duplicate()
	var prior := float(progress.get(id, 0.0))
	var updated: float = (prior + value) if String(row["agg"]) == "sum" else maxf(prior, value)
	progress[id] = updated
	out["challenge_progress"] = progress

	var completed: Array = (out.get("challenge_completed", []) as Array).duplicate()
	if id in completed:
		return out   # already claimed this rotation slot — no repeat reward
	if updated < float(row["target"]):
		return out

	completed.append(id)
	out["challenge_completed"] = completed
	out["challenges_completed_total"] = int(out.get("challenges_completed_total", 0)) + 1
	out = _grant_crate(out, String(row["reward_crate_id"]))
	var pending: Array = (out.get("pending_challenge_rewards", []) as Array).duplicate()
	pending.append(String(row["reward_crate_id"]))
	out["pending_challenge_rewards"] = pending
	return out

## Grants one unopened crate — the same dict math as SaveManager.add_crate(), duplicated here
## (rather than called) so this file has zero Node/autoload dependency, matching LifetimeRecords.
static func _grant_crate(data: Dictionary, crate_id: String) -> Dictionary:
	var out := data.duplicate(true)
	var crates: Dictionary = (out.get("crates", {}) as Dictionary).duplicate()
	crates[crate_id] = int(crates.get(crate_id, 0)) + 1
	out["crates"] = crates
	return out

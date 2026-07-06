class_name LifetimeRecords
## Pure save-data merge math for lifetime records (Pack D: Stats + juice, v0.1.51). No Node or
## file dependency — SaveManager.add_lifetime_run() calls merge_run() and writes the resulting
## dict into its own _data, so a headless probe can verify the arithmetic directly against a
## plain Dictionary without touching the real save file.
##
## NOT idempotent: calling merge_run() twice for the same run double-counts everything, by
## design. Exactly-once-per-run is enforced entirely by the CALLER-side RunStats.paid_out guard
## (GameOver._finish_run / PauseMenu._abandon_run_payout both `if RunStats.paid_out: return` then
## set it true before ever reaching this function) — the same guard that already protects the
## coin payout from a double death+quit race. This function has no guard of its own.

## Returns a NEW dict = `data` with the lifetime-record keys incremented by one run's results.
## Missing keys default the same way SaveManager's own accessors do (0 / 0.0 / {}), so this is
## safe to call against a bare `{}` (a fresh save) or a fully-populated `_data`.
static func merge_run(data: Dictionary, kills: int, bosses: int, elites: int, coins_earned: int,
		run_time: float, weapon_base_id: String) -> Dictionary:
	var out := data.duplicate(true)
	out["total_kills"] = int(out.get("total_kills", 0)) + maxi(kills, 0)
	out["total_bosses"] = int(out.get("total_bosses", 0)) + maxi(bosses, 0)
	out["total_elites"] = int(out.get("total_elites", 0)) + maxi(elites, 0)
	out["total_coins_earned"] = int(out.get("total_coins_earned", 0)) + maxi(coins_earned, 0)
	out["best_clockout_seconds"] = maxf(float(out.get("best_clockout_seconds", 0.0)), run_time)
	if weapon_base_id != "" and kills > 0:
		var gk: Dictionary = (out.get("gun_kills", {}) as Dictionary).duplicate()
		gk[weapon_base_id] = int(gk.get(weapon_base_id, 0)) + kills
		out["gun_kills"] = gk
	return out

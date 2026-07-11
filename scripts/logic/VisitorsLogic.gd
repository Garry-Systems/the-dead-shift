class_name VisitorsLogic
## Pure gate/pick math for VISITORS (Night Shift Stories, v0.1.68). Controller = scripts/
## Visitors.gd; kept pure so it's probe-able without a live scene tree — mirrors
## BasementLogic.gd's own doc-comment rationale verbatim (scripts/logic/BasementLogic.gd:2-3).

## Allowed RunConfig.mode values, mirroring BasementLogic.ALLOWED_MODES: OVERTIME/HARDCORE/DAILY
## are all flags layered on top of mode == "endless" (they inherit this list for free); only
## HORDE NIGHT is its own top-level mode string, and BOSS RUSH is deliberately excluded (spec:
## "endless + horde only, NOT boss_rush").
const ALLOWED_MODES := ["endless", "horde"]

## Gate for rolling a visitor at a wave-edge: wave floor met, mode allowed, no visitor already
## active, VISITOR_COOLDOWN elapsed since the last one arrived, per-run cap not hit, player not
## inside THE BASEMENT gauntlet. GATE-FIRST: callers (Visitors._on_wave_edge) only ever consume a
## seeded RunConfig.rand_float() AFTER this returns true — see roll()/pick() below, which both
## take the already-rolled value/index rather than reading RunConfig themselves, so this whole
## chain stays probe-able with stubbed numbers instead of live RNG (Basement._roll_door's exact
## "does NOT re-check the gate; callers are responsible" split, mirrored here).
static func can_roll(wave: int, mode: String, active: bool, cooldown_left: float, count_this_run: int, in_basement: bool) -> bool:
	if wave < GameConfig.VISITOR_MIN_WAVE:
		return false
	if not ALLOWED_MODES.has(mode):
		return false
	if active:
		return false
	if cooldown_left > 0.0:
		return false
	if count_this_run >= GameConfig.VISITOR_MAX_PER_RUN:
		return false
	if in_basement:
		return false
	return true

## Chance roll for whether a visitor actually arrives once can_roll() allows it. Caller passes
## RunConfig.rand_float() (daily-seeded when a Daily Shift run is active).
static func roll(rand01: float) -> bool:
	return rand01 < GameConfig.VISITOR_CHANCE

## Seeded uniform pick among visitor kinds not yet seen this run (no repeats/run, per spec).
## `all_kinds` is the full roster (Visitors._ALL_VISITORS); `seen` is this run's already-picked
## kinds; caller passes RunConfig.rand_int() (daily-seeded). Falls back to the full roster if
## every kind has already been seen — VISITOR_MAX_PER_RUN (2) caps count below the 3-kind roster
## size today, so that branch is dead code at current constants, kept as a non-crashing safety
## net (not a silent behavior trap) in case a future balance pass ever raises the cap to 3.
static func pick(all_kinds: Array, seen: Array, rand_i: int) -> String:
	var remaining: Array = []
	for k in all_kinds:
		if k not in seen:
			remaining.append(k)
	if remaining.is_empty():
		remaining = all_kinds.duplicate()
	if remaining.is_empty():
		return ""
	return remaining[rand_i % remaining.size()]

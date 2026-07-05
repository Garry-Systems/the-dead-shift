class_name ShiftClock
## Pure run_time -> night-shift clock math (mirrors DifficultyCurve / XpCurve — no node or
## scene dependency, so it's probeable in isolation). The shift starts at
## GameConfig.SHIFT_START_HOUR (10:00 PM) and "dawn" lands at GameConfig.SHIFT_END_HOUR
## (6:00 AM); the clock keeps climbing past dawn since the run continues (endless doesn't
## end at sunrise).

const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24

## run_time (seconds) at which the shift clock first reads SHIFT_END_HOUR (dawn) — Hud
## fires the DAWN banner + coin bonus once per run when run_time crosses this.
static func dawn_run_time() -> float:
	return float(_shift_duration_minutes()) * GameConfig.SHIFT_SECONDS_PER_MINUTE

## "H:MM AM/PM" clock reading (12-hour, no leading zero on the hour) for the given run_time
## (seconds elapsed since the shift started at SHIFT_START_HOUR).
static func clock_string(run_time: float) -> String:
	var total_minutes := int(run_time / GameConfig.SHIFT_SECONDS_PER_MINUTE)
	var start_minutes := GameConfig.SHIFT_START_HOUR * MINUTES_PER_HOUR
	var clock_minutes := (start_minutes + total_minutes) % (HOURS_PER_DAY * MINUTES_PER_HOUR)
	var hour24 := clock_minutes / MINUTES_PER_HOUR
	var minute := clock_minutes % MINUTES_PER_HOUR
	var hour12 := hour24 % 12
	if hour12 == 0:
		hour12 = 12
	var ampm := "AM" if hour24 < 12 else "PM"
	return "%d:%02d %s" % [hour12, minute, ampm]

## Minutes from SHIFT_START_HOUR to SHIFT_END_HOUR, crossing midnight (22 -> 6 = 8 hours = 480min).
static func _shift_duration_minutes() -> int:
	var hours := (GameConfig.SHIFT_END_HOUR - GameConfig.SHIFT_START_HOUR + HOURS_PER_DAY) % HOURS_PER_DAY
	return hours * MINUTES_PER_HOUR

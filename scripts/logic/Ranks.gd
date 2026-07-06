class_name Ranks
## Pure Employee Rank ladder math (Pack G: v0.1.58). Rank is DERIVED from lifetime rank_xp —
## nothing but the XP itself is ever stored (mirrors ChallengeProgress's pure-rotation-from-date
## idiom). No node/autoload dependency, so a headless --script probe can verify every threshold
## boundary directly against GameConfig's tables.

## mode id -> required rank (1-indexed) to unlock. The ONLY table any launch path/mode-select
## button may consult to decide a lock — see MainMenu.gd's mode-select buttons and their
## defensive re-checks in _start_run/_start_hardcore/_start_overtime (mirrors the DAILY SHIFT
## precedent: the button is disabled AND the launch function still re-checks).
const UNLOCKS := {
	"horde": GameConfig.RANK_HORDE_UNLOCK,
	"overtime": GameConfig.RANK_OVERTIME_UNLOCK,
	"hardcore": GameConfig.RANK_HARDCORE_UNLOCK,
}

## Display names for the unlockable modes (mode id -> label), shared by the mode-select buttons'
## lock text and the PROMOTED popup's "Unlocked: ..." line so both always agree.
const MODE_DISPLAY_NAMES := {
	"horde": "HORDE NIGHT",
	"overtime": "OVERTIME",
	"hardcore": "HARDCORE",
}

## Rank (1..RANK_COUNT) reached at total lifetime `xp`. Never below 1, never above RANK_COUNT.
static func rank_for(xp: int) -> int:
	var r := 1
	for i in GameConfig.RANK_THRESHOLDS.size():
		if xp >= GameConfig.RANK_THRESHOLDS[i]:
			r = i + 1
	return r

## Display name for a 1-indexed rank (clamped into range).
static func name_for(rank: int) -> String:
	var idx := clampi(rank, 1, GameConfig.RANK_COUNT) - 1
	return String(GameConfig.RANK_NAMES[idx])

## XP threshold a 1-indexed rank is reached at (clamped into range).
static func threshold(rank: int) -> int:
	var idx := clampi(rank, 1, GameConfig.RANK_COUNT) - 1
	return int(GameConfig.RANK_THRESHOLDS[idx])

## Fraction (0..1) of progress from the current rank's threshold toward the next rank's —
## 1.0 once at the max rank (nothing left to progress toward).
static func progress_in_rank(xp: int) -> float:
	var r := rank_for(xp)
	if r >= GameConfig.RANK_COUNT:
		return 1.0
	var lo := threshold(r)
	var hi := threshold(r + 1)
	if hi <= lo:
		return 1.0
	return clampf(float(xp - lo) / float(hi - lo), 0.0, 1.0)

## True once `xp` has reached the rank required to unlock `mode_id` ("horde"/"overtime"/
## "hardcore"). Unknown mode ids are always unlocked (no entry in UNLOCKS = no gate).
static func is_unlocked(mode_id: String, xp: int) -> bool:
	if not UNLOCKS.has(mode_id):
		return true
	return rank_for(xp) >= int(UNLOCKS[mode_id])

## Display label for a mode id (falls back to an upper-cased id for anything not in the table).
static func mode_display_name(mode_id: String) -> String:
	return String(MODE_DISPLAY_NAMES.get(mode_id, mode_id.to_upper()))

## "UNLOCKS AT <RANK NAME>" text for a locked mode-select button.
static func lock_text(mode_id: String) -> String:
	if not UNLOCKS.has(mode_id):
		return ""
	return "UNLOCKS AT %s" % name_for(int(UNLOCKS[mode_id]))

class_name Flavor
## Every piece of ambient voice in one pure registry (roadmap-4 Pack 0). Surfaces read via
## the getters; a missing id returns "" and the surface hides itself — flavor can never
## crash gameplay. All lines <= 70 chars (phone width). Lowercase deadpan is the voice.

const BOSS_LINES := {
	"brute": "big guy from aisle 5. he was like this before.",
	"brood_mother": "she's not on the schedule. her kids are.",
	"heat_tyrant": "the AC guy never came. this is what happened.",
	"manager": "he never clocked out. now he never will.",
	"night_stocker": "restocking since the incident. don't block the aisles.",
	"fryer": "the fryer station is technically still operational.",
	"courier": "signature required. he will collect it.",
	"karen": "she asked for corporate. corporate is dead.",
	"tanker": "pump 3 called for a refill. he's still delivering.",
}

const DEATH_QUIPS := [
	"your shift has been covered.",
	"cleanup on every aisle.",
	"you are no longer eligible for the health plan.",
	"break room's open. permanently.",
	"your name tag will be reissued.",
	"clocking you out. someone had to.",
	"the night shift always finds staff.",
	"leave the vest. they always leave the vest.",
	"corporate has been notified. nobody answered.",
	"the coffee was still warm.",
	"employee of the month is posthumous this month.",
	"the register doesn't count itself. well. it does now.",
]

## Indexed by rank (index 0 = rank 1 TRAINEE ... index 9 = rank 10 FRANCHISE OWNER) — size must
## match the Ranks ladder.
const RANK_BLURBS := [
	"you get a vest. the vest does nothing.",
	"you may now run the register unsupervised. congratulations?",
	"you've unlocked the horde. that's not a benefit.",
	"keys to the ice machine. guard them.",
	"overtime approved. sleep is not.",
	"someone has to order more shells. it's you now.",
	"hardcore clearance. the insurance no longer applies.",
	"you know where the mop is. you know where everything is.",
	"you basically run this place. it shows.",
	"it's yours now. all of it. even the basement.",
]

const STAFF_MEMOS := [
	"MEMO: the walk-in stays CLOSED after 2AM.",
	"MEMO: do not refund the dead. no exceptions.",
	"MEMO: pump 3 is fine. stop reporting pump 3.",
	"MEMO: if the manager speaks to you, you didn't hear it.",
	"MEMO: the mop is not a weapon. update: the mop is a weapon.",
	"MEMO: night shift differential remains $0.25/hr.",
	"MEMO: the freezer hum is normal. the freezer voice is not.",
	"MEMO: the slushie machine is self-cleaning. leave it alone.",
	"MEMO: report all bites to HR. HR reports to no one.",
	"MEMO: dawn deliveries resume when dawn does.",
	"MEMO: employee discount does not apply to ammunition.",
	"MEMO: the corkboard is for APPROVED notices only.",
	"MEMO: lost & found is full. stop finding things.",
	"MEMO: smile. customers can tell.",
	"MEMO: BIG MART is not our competitor. BIG MART is a warning.",
	"MEMO: do not park on level 3.",
]

static func boss_line(id: String) -> String:
	return String(BOSS_LINES.get(id, ""))

static func death_quip() -> String:
	return DEATH_QUIPS[randi() % DEATH_QUIPS.size()]

## rank is 1-indexed (1 = TRAINEE ... RANK_COUNT = FRANCHISE OWNER), matching Ranks.rank_for().
static func rank_blurb(rank: int) -> String:
	if rank < 1 or rank > RANK_BLURBS.size():
		return ""
	return RANK_BLURBS[rank - 1]

static func staff_memo() -> String:
	return STAFF_MEMOS[randi() % STAFF_MEMOS.size()]

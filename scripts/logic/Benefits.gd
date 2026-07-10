class_name Benefits
## EMPLOYEE BENEFITS (roadmap-4 Pack A): permanent scrap-funded flat tracks. Pure logic —
## costs, caps, and effect math live here; SaveManager holds the wallet + levels; Main.gd
## applies the effects once at run start. RNG/rarity untouched by design (flat QoL only).

const TRACKS := [
	{ "id": "insurance",      "name": "INSURANCE",      "flavor": "the plan covers bites now. mostly.",        "cap": 5 },
	{ "id": "comfy_shoes",    "name": "COMFY SHOES",    "flavor": "non-slip. blood-resistant. regulation.",     "cap": 5 },
	{ "id": "night_school",   "name": "NIGHT SCHOOL",   "flavor": "learn on the job. faster.",                  "cap": 5 },
	{ "id": "signing_bonus",  "name": "SIGNING BONUS",  "flavor": "a little something up front.",               "cap": 5 },
	{ "id": "second_opinion", "name": "SECOND OPINION", "flavor": "don't like the options? ask again.",         "cap": 3 },
	{ "id": "stretch_breaks", "name": "STRETCH BREAKS", "flavor": "five minutes. your legs will thank you.",    "cap": 5 },
	{ "id": "register_skim",  "name": "REGISTER SKIM",  "flavor": "we round in your favor now.",                "cap": 5 },
	{ "id": "pack_rat",       "name": "PACK RAT",       "flavor": "the back room remembers everything.",        "cap": 5 },
	{ "id": "union_rep",      "name": "UNION REP",      "flavor": "one call. one favor. once.",                 "cap": 1 },
]

static func _track(id: String) -> Dictionary:
	for t in TRACKS:
		if String(t["id"]) == id:
			return t
	return {}

static func cap(id: String) -> int:
	return int(_track(id).get("cap", 0))

## Scrap cost of buying `next_level` (1-based) of a track; -1 = unknown track or over cap.
static func cost(id: String, next_level: int) -> int:
	var t := _track(id)
	if t.is_empty() or next_level < 1 or next_level > int(t["cap"]):
		return -1
	if id == "union_rep":
		return GameConfig.BENEFIT_REVIVE_COST
	return int(GameConfig.BENEFIT_COSTS[next_level - 1])

static func level(id: String) -> int:
	return mini(SaveManager.benefit_level(id), cap(id))

## Buys the next level if affordable; persists via SaveManager. False = capped or short.
static func try_buy(id: String) -> bool:
	var next := level(id) + 1
	var c := cost(id, next)
	if c < 0 or not SaveManager.spend_scrap(c):
		return false
	SaveManager.set_benefit_level(id, next)
	SaveManager.save_game()
	return true

# --- effect getters (the ONLY read points gameplay uses) ---
static func hp_bonus() -> float:
	return level("insurance") * GameConfig.BENEFIT_HP_PER_LVL

static func speed_mult() -> float:
	return 1.0 + level("comfy_shoes") * GameConfig.BENEFIT_SPEED_PER_LVL

static func xp_mult() -> float:
	return 1.0 + level("night_school") * GameConfig.BENEFIT_XP_PER_LVL

static func start_cash() -> int:
	return level("signing_bonus") * GameConfig.BENEFIT_CASH_PER_LVL

static func reroll_charges() -> int:
	return level("second_opinion")

static func dash_cd_mult() -> float:
	return 1.0 - level("stretch_breaks") * GameConfig.BENEFIT_DASH_CD_PER_LVL

static func coin_mult() -> float:
	return 1.0 + level("register_skim") * GameConfig.BENEFIT_COIN_PER_LVL

static func scrap_mult() -> float:
	return 1.0 + level("pack_rat") * GameConfig.BENEFIT_SCRAP_PER_LVL

static func has_revive() -> bool:
	return level("union_rep") >= 1

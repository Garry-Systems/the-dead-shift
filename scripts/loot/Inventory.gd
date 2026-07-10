extends Node
## AUTOLOAD ("Inventory"). The player's persistent weapon collection + the equipped pick.
## Stored inside the existing SaveManager save (keys "weapons" / "equipped_weapon"); coins
## are the existing SaveManager wallet — no separate currency. No class_name: the autoload
## name is already global. Emits signals the UI binds to instead of polling.

signal inventory_changed()
signal coins_changed(amount: int)
signal scrap_changed(amount: int)   # EMPLOYEE BENEFITS (Pack A): new SCRAP total after a deconstruct banks its byproduct
signal item_added(inst: Dictionary)
signal equipped_changed(uid: String)

const MAX_WEAPONS := 120                # mobile cap; deconstruct to free space

# One-time, non-destructive remap of the pre-rename affix ids (from the first slice build)
# to the gritty ladder, so existing saves keep their weapons instead of going blank.
const _AFFIX_MIGRATION := {
	"worn": "rusted", "standard": "salvaged", "specialized": "hardened",
	"superior": "lethal", "highend": "savage", "ascended": "merciless", "cosmic": "carnage",
}

func _ready() -> void:
	var list := weapons()
	var changed := false
	for it in list:
		var aid := String(it.get("affix", ""))
		if _AFFIX_MIGRATION.has(aid):
			it["affix"] = _AFFIX_MIGRATION[aid]
			changed = true
	if changed:
		SaveManager.set_weapons(list)
		SaveManager.save_game()

# --- currency (delegates to the existing wallet) ---
func coins() -> int:
	return SaveManager.coins()

# --- queries ---
func weapons() -> Array:
	return SaveManager.weapons_raw()

func count() -> int:
	return weapons().size()

func is_full() -> bool:
	return count() >= MAX_WEAPONS

func get_item(uid: String) -> Dictionary:
	for it in weapons():
		if String(it.get("uid", "")) == uid:
			return it
	return {}

func equipped_uid() -> String:
	return SaveManager.equipped_weapon()

func equipped_instance() -> Dictionary:
	return get_item(equipped_uid())

# --- mutations ---
## Adds a rolled instance. Auto-equips it if nothing is equipped yet. Returns false if full.
## The single chokepoint every weapon-granting path funnels through (crate opens via
## commit_crate, daily/milestone gun rewards, DEV grants, and any future path — e.g. Pack B's
## weapon fusion, if it ever mints a fresh instance) — so it's also where a rarity-9 (Armageddon)
## pull is counted for the lifetime records (Pack D) and a rarity-8 (Apocalypse) pull for the
## OVER THE RAINBOW commendation (Pack H).
func add(inst: Dictionary) -> bool:
	if is_full():
		return false
	var list := weapons()
	list.append(inst)
	SaveManager.set_weapons(list)
	var rarity_id := int(inst.get("rarity", 1))
	if rarity_id == Rarity.MAX_ID:
		SaveManager.add_armageddon_pulled()
	elif rarity_id == Rarity.RAINBOW_ID:
		SaveManager.add_apocalypse_pulled()
	if equipped_uid() == "":
		SaveManager.set_equipped_weapon(String(inst.get("uid", "")))
		equipped_changed.emit(equipped_uid())
	SaveManager.save_game()
	item_added.emit(inst)
	inventory_changed.emit()
	return true

func equip(uid: String) -> bool:
	if get_item(uid).is_empty():
		return false
	SaveManager.set_equipped_weapon(uid)
	SaveManager.save_game()
	equipped_changed.emit(uid)
	return true

## Scraps a weapon for coins (rarity-based payout) plus a SCRAP byproduct (payout/10,
## min 1, PACK RAT-multiplied — Pack A). Can't scrap the equipped one. Returns the COIN
## payout (unchanged contract); the scrap side is surfaced via scrap_changed.
func deconstruct(uid: String) -> int:
	var it := get_item(uid)
	if it.is_empty() or uid == equipped_uid():
		return 0
	var band: Array = Rarity.tier(int(it.get("rarity", 1))).scrap
	var payout := randi_range(int(band[0]), int(band[1]))
	var list := weapons()
	list = list.filter(func(w): return String(w.get("uid", "")) != uid)
	SaveManager.set_weapons(list)
	SaveManager.add_coins(payout)
	# EMPLOYEE BENEFITS (Pack A): deconstructs also bank SCRAP — an ADDITIVE byproduct, the
	# coins payout above is untouched. PACK RAT multiplies the byproduct only.
	var scrap_gain := roundi(maxi(1, payout / 10) * Benefits.scrap_mult())
	SaveManager.add_scrap(scrap_gain)
	SaveManager.save_game()
	coins_changed.emit(coins())
	scrap_changed.emit(SaveManager.scrap())   # mirrors coins_changed: the new wallet total
	inventory_changed.emit()
	return payout

## Store purchase: spend coins and add an UNOPENED crate to the collection.
## Returns false on unknown crate or not enough coins. (Crates don't count against the
## weapon cap, so inventory-full does not block buying.)
func buy_crate(crate_id: String) -> bool:
	var crate := Crates.get_crate(crate_id)
	if crate.is_empty():
		return false
	if not SaveManager.spend_coins(int(crate["price"])):
		return false
	SaveManager.add_crate(crate_id)
	SaveManager.save_game()
	coins_changed.emit(coins())
	inventory_changed.emit()
	return true

## Finalize an opened crate: consume one crate + add the rolled winner. Atomic.
## Returns false if no crate owned / inventory full / empty roll. The opener supplies the
## winner so the reel and the award are the same instance.
func commit_crate(crate_id: String, winner: Dictionary) -> bool:
	if SaveManager.crate_count(crate_id) <= 0 or is_full() or winner.is_empty():
		return false
	SaveManager.remove_crate(crate_id)
	add(winner)   # appends, auto-equips if none, saves, emits
	# Challenge board (Pack C): "open N crates" is a menu action, not a run-payout event — this is
	# the one chokepoint every actual crate settle passes through, so it's bumped immediately
	# (no paid_out guard needed; a settle here only ever happens once per real open).
	SaveManager.bump_challenge_counter("crates_opened", 1)
	# Commendations (Pack H): the LIFETIME twin of the line above — never resets, for BIG SPENDER.
	SaveManager.add_crate_opened()
	SaveManager.save_game()
	return true

## Awards XP to the equipped weapon (call at end of run). Levels up on the level*100 curve
## via the shared WeaponInstance.apply_xp() chokepoint (also used by Pack B's weapon fusion),
## so talent unlocks trigger identically from either path.
func add_run_xp(amount: int) -> void:
	var uid := equipped_uid()
	var it := get_item(uid)
	if it.is_empty() or amount <= 0:
		return
	WeaponInstance.apply_xp(it, amount)
	# it is a reference into the saved array; persist the mutation.
	SaveManager.set_weapons(weapons())
	SaveManager.save_game()
	inventory_changed.emit()

# --- Pack B: weapon fusion (v0.1.52) ---

## Owned duplicates of `target_uid`'s base weapon that FEED may consume as a sacrifice: same
## base id, not the currently-equipped weapon (mirrors deconstruct's equipped guard — belt-
## and-suspenders alongside fuse()'s own guard below), and not the viewed instance itself.
func eligible_fusion_sacrifices(target_uid: String) -> Array:
	var target := get_item(target_uid)
	if target.is_empty():
		return []
	var base_id := String(target.get("base", ""))
	var eq := equipped_uid()
	var out: Array = []
	for it in weapons():
		var uid := String(it.get("uid", ""))
		if uid == target_uid or uid == eq:
			continue
		if String(it.get("base", "")) == base_id:
			out.append(it)
	return out

## FEED: consumes `sacrifice_uid` (an owned same-base duplicate — never the equipped weapon,
## never the target itself) to grant `target_uid` weapon XP = the sacrifice's scrap-band
## midpoint x GameConfig.FUSION_XP_MULT, through the shared WeaponInstance.apply_xp() path so
## level-ups/talent-unlocks trigger exactly like end-of-run XP. If the sacrifice's rarity is
## >= the target's, ALSO rerolls the target's single lowest-quality stat roll. The sacrifice's
## removal and the target's XP/reroll mutation are written in the SAME set_weapons() + one
## save_game() call, so there's no window where the dup is gone but the XP wasn't applied (or
## vice versa). Returns {} on any guard failure (equipped-as-sacrifice, unknown uid, same
## instance, different base). On success:
##   { xp_gained, leveled_up, new_level, unlocked: Array[String],
##     rerolled: {} or { stat_id, old, new } }
func fuse(target_uid: String, sacrifice_uid: String) -> Dictionary:
	if sacrifice_uid == target_uid or sacrifice_uid == equipped_uid():
		return {}   # equipped can NEVER be the sacrifice (feeding INTO it is fine — see eligible_fusion_sacrifices)
	var target := get_item(target_uid)
	var sac := get_item(sacrifice_uid)
	if target.is_empty() or sac.is_empty():
		return {}
	if String(sac.get("base", "")) != String(target.get("base", "")):
		return {}   # same-BASE duplicates only

	var sac_rarity := int(sac.get("rarity", 1))
	var target_rarity := int(target.get("rarity", 1))
	var xp_gained := int(round(Rarity.scrap_midpoint(sac_rarity) * GameConfig.FUSION_XP_MULT))
	var before_level := int(target.get("level", 1))
	# target is a reference into the saved array — apply_xp/reroll_lowest_stat mutate it in place.
	var unlocked := WeaponInstance.apply_xp(target, xp_gained)

	var rerolled := {}
	if sac_rarity >= target_rarity:
		rerolled = WeaponInstance.reroll_lowest_stat(target)

	var list := weapons().filter(func(w): return String(w.get("uid", "")) != sacrifice_uid)
	SaveManager.set_weapons(list)   # persists both the sacrifice's removal AND target's mutation
	SaveManager.add_fusion()
	# Challenge board (Pack C): "fuse N weapons" is a menu action, not a run-payout event — bumped
	# immediately at this one chokepoint (no paid_out guard needed; reaching here already means
	# exactly one real fusion just succeeded).
	SaveManager.bump_challenge_counter("fusions_done", 1)
	SaveManager.save_game()
	inventory_changed.emit()

	return {
		"xp_gained": xp_gained,
		"leveled_up": int(target.get("level", 1)) > before_level,
		"new_level": int(target.get("level", 1)),
		"unlocked": unlocked,
		"rerolled": rerolled,
	}

## Curated first-launch seed (Pack 1): exactly 3 gray (rarity 1) starters — pistol, SMG,
## shotgun — via the existing roll/instance path, auto-equipping the pistol so PLAY works
## immediately. Plus a small coin float to try a crate. Idempotent (no-op once any weapon
## exists), which also means this ONLY ever runs on a truly fresh save — an existing save
## (any weapon count > 0) is left untouched even though MainMenu calls this every launch.
const _STARTER_BASE_IDS := ["pistol", "smg", "shotgun"]

func grant_starter() -> void:
	if count() > 0:
		return
	# Route each starter through add() — the single instance-granting chokepoint (cap-aware,
	# saves, emits, counts Armageddon pulls) — instead of a raw set_weapons batch, so the
	# "every path funnels through add()" invariant on add() stays literally true. A few extra
	# save_game() calls don't matter on this once-ever fresh-save path.
	var pistol_uid := ""
	for base_id in _STARTER_BASE_IDS:
		var inst := LootRoller.roll(1, base_id)
		if base_id == "pistol":
			pistol_uid = String(inst["uid"])
		add(inst)   # never full here (fresh save); auto-equips the first added if nothing is equipped
	if equipped_uid() != pistol_uid:
		equip(pistol_uid)   # normally a no-op: add() already auto-equipped the pistol (added first)
	if coins() < 150:
		SaveManager.add_coins(150 - coins())
	SaveManager.save_game()

## DEV (temporary): append one weapon of every rarity tier (1..MAX, random base each) so all
## tiers can be inspected/felt at once. Repeatable. Reuses add() (cap-aware, auto-equips the
## first if nothing equipped, saves, emits). Returns the number actually added.
## REMOVE before release — paired with SaveManager.grant_dev_bonus (the 10k-coin grant).
func grant_all_rarities() -> int:
	var added := 0
	for tier in range(1, Rarity.MAX_ID + 1):
		if not add(LootRoller.roll(tier, "")):
			break   # inventory full
		added += 1
	return added

## DEV (temporary): add one unopened crate of every type so all crates can be opened/felt at
## once. Repeatable; crates ignore the weapon cap. Returns how many crate types were granted.
## REMOVE before release — paired with the other DEV grants.
func grant_one_of_each_crate() -> int:
	var added := 0
	for crate in Crates.all():
		SaveManager.add_crate(String(crate.get("id", "")))
		added += 1
	SaveManager.save_game()
	inventory_changed.emit()
	return added

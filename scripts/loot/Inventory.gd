extends Node
## AUTOLOAD ("Inventory"). The player's persistent weapon collection + the equipped pick.
## Stored inside the existing SaveManager save (keys "weapons" / "equipped_weapon"); coins
## are the existing SaveManager wallet — no separate currency. No class_name: the autoload
## name is already global. Emits signals the UI binds to instead of polling.

signal inventory_changed()
signal coins_changed(amount: int)
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
## pull is counted for the lifetime records (Pack D).
func add(inst: Dictionary) -> bool:
	if is_full():
		return false
	var list := weapons()
	list.append(inst)
	SaveManager.set_weapons(list)
	if int(inst.get("rarity", 1)) == Rarity.MAX_ID:
		SaveManager.add_armageddon_pulled()
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

## Scraps a weapon for coins (rarity-based payout). Can't scrap the equipped one.
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
	SaveManager.save_game()
	coins_changed.emit(coins())
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
	return true

## Awards XP to the equipped weapon (call at end of run). Levels up on the level*100 curve.
## v1 has no talents gated on level yet, but this keeps the meta-progression data real.
func add_run_xp(amount: int) -> void:
	var uid := equipped_uid()
	var it := get_item(uid)
	if it.is_empty() or amount <= 0:
		return
	it["xp"] = int(it.get("xp", 0)) + amount
	var lvl := int(it.get("level", 1))
	while it["xp"] >= lvl * 100:
		it["xp"] -= lvl * 100
		lvl += 1
	it["level"] = lvl
	# it is a reference into the saved array; persist the mutation.
	SaveManager.set_weapons(weapons())
	SaveManager.save_game()
	inventory_changed.emit()

## Curated first-launch seed (Pack 1): exactly 3 gray (rarity 1) starters — pistol, SMG,
## shotgun — via the existing roll/instance path, auto-equipping the pistol so PLAY works
## immediately. Plus a small coin float to try a crate. Idempotent (no-op once any weapon
## exists), which also means this ONLY ever runs on a truly fresh save — an existing save
## (any weapon count > 0) is left untouched even though MainMenu calls this every launch.
const _STARTER_BASE_IDS := ["pistol", "smg", "shotgun"]

func grant_starter() -> void:
	if count() > 0:
		return
	var list := weapons()
	var pistol_uid := ""
	for base_id in _STARTER_BASE_IDS:
		var inst := LootRoller.roll(1, base_id)
		if base_id == "pistol":
			pistol_uid = String(inst["uid"])
		list.append(inst)
	SaveManager.set_weapons(list)
	SaveManager.set_equipped_weapon(pistol_uid)
	if coins() < 150:
		SaveManager.add_coins(150 - coins())
	SaveManager.save_game()
	equipped_changed.emit(pistol_uid)
	inventory_changed.emit()

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

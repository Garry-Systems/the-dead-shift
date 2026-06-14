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
func add(inst: Dictionary) -> bool:
	if is_full():
		return false
	var list := weapons()
	list.append(inst)
	SaveManager.set_weapons(list)
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

## Buys + opens a crate: spends coins, rolls an instance, adds it. Returns the instance
## (empty dict on failure: unknown crate, not enough coins, or inventory full).
func open_crate(crate_id: String) -> Dictionary:
	var crate := Crates.get_crate(crate_id)
	if crate.is_empty():
		return {}
	if coins() < int(crate["price"]):
		return {}
	if is_full():
		return {}
	if not SaveManager.spend_coins(int(crate["price"])):
		return {}
	var inst := LootRoller.roll_from_crate(crate)
	add(inst)                              # add() saves + emits item_added/inventory_changed
	coins_changed.emit(coins())
	return inst

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

## First-launch seed so the inventory isn't empty: one starter weapon per base, plus a
## small coin float to try a crate. Deliberately does NOT auto-equip — the menu forces
## the player to pick a weapon on their first PLAY. Idempotent (no-op once any weapon exists).
func grant_starter() -> void:
	if count() > 0:
		return
	var list := weapons()
	for def in Weapons.all():
		list.append(LootRoller.roll(1, String(def["id"])))
	SaveManager.set_weapons(list)
	if coins() < 150:
		SaveManager.add_coins(150 - coins())
	SaveManager.save_game()
	inventory_changed.emit()

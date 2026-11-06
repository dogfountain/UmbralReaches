extends RefCounted
## Vendors buy (r33, WoW's sell and buyback): every merchant in Hearthward takes gear you are not
## wearing and a few plain materials for grave ash, and keeps what you sold this night on a
## buyback shelf (the last LootDB.BUYBACK_CAP sales) at the price paid. ui/shop.gd shows it as the
## SELL and BUY BACK tabs. Pure static; state in Travel.system_state("vendor") = {buyback: [...]}
## (old saves have none: it starts empty). Load by path (no class_name):
##   const Vendor := preload("res://core/items/vendor.gd")
## Rows are shaped like village_shop.gd's: {id, name, text, price, left, ok, why, group} plus
## "piece" (gear) or "item" (an ItemDB id) and "quality".

const GearDB := preload("res://core/items/gear_db.gd")
const GearStats := preload("res://core/items/gear_stats.gd")
const LootDB := preload("res://core/items/loot_db.gd")
const SID := "vendor"


static func state() -> Dictionary:
	var st := Travel.system_state(SID)
	if not (st.get("buyback") is Array):
		st["buyback"] = []
	return st


static func _worn_uids() -> Dictionary:
	var out := {}
	for p: Dictionary in GearStats.worn(GearStats.state()).values():
		out[int(p.uid)] = true
	return out


## What the night charged for a material you can sell back: the fire's smelt (HearthDB.SMELT), the shop's fragment.
const COST_NOTE := {"ember_shard": 6, "relic_fragment": 14}


## A piece worth a second thought: named, or Hallowed and better. Selling it asks once.
static func asks(p: Dictionary) -> bool:
	return String(p.get("named", "")) != "" or int(p.get("rarity", 0)) >= 2


## What can be sold now: unworn gear (the piece you would miss first), then sellable materials.
static func sell_rows() -> Array:
	var out: Array = []
	var worn := _worn_uids()
	var bag: Array = (GearStats.state().bag as Array).duplicate()
	bag.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("rarity", 0)) != int(b.get("rarity", 0)):
			return int(a.get("rarity", 0)) > int(b.get("rarity", 0))
		var na := String(a.get("named", "")) != ""
		var nb := String(b.get("named", "")) != ""
		if na != nb:
			return na
		if GearDB.item_level(a) != GearDB.item_level(b):
			return GearDB.item_level(a) > GearDB.item_level(b)
		return int(a.get("uid", 0)) < int(b.get("uid", 0)))
	for p: Dictionary in bag:
		if worn.has(int(p.get("uid", -1))):
			continue
		out.append({"id": "gear:%d" % int(p.uid), "name": String(p.get("name", "gear")), "piece": p, "quality": int(p.get("rarity", 0)),
			"text": "%s %s, item level %d." % [LootDB.quality_name(int(p.get("rarity", 0))), String(GearDB.SLOT_NAMES.get(String(p.slot), "")), GearDB.item_level(p)],
			"price": LootDB.sell_price_piece(p), "left": -1, "group": "Gear", "ask": asks(p), "ok": true, "why": "", "sub": "ilvl %d" % GearDB.item_level(p)})
	for id: String in LootDB.SELL_ITEM:
		var n := Travel.count(id)
		if n <= 0:
			continue
		out.append({"id": "item:" + id, "item": id, "name": String(ItemDB.def(id).get("name", id)), "quality": LootDB.item_quality(id),
			"text": String(ItemDB.def(id).get("text", "")) + ("  The night charged %d ash for it; it pays %d." % [int(COST_NOTE[id]), LootDB.sell_price_item(id)] if COST_NOTE.has(id) else ""),
			"price": LootDB.sell_price_item(id), "left": n, "group": "Materials",
			"ok": true, "why": "", "sub": "%d carried, sells one" % n})
	return out


## Sell one row (by id from sell_rows). {ok, say, ash}.
static func sell(row_id: String) -> Dictionary:
	var price := 0
	var entry := {}
	if row_id.begins_with("gear:"):
		var uid := int(row_id.trim_prefix("gear:"))
		var st := GearStats.state()
		var p := GearStats.find(st, uid)
		if p.is_empty():
			return {"ok": false, "say": "That is not in the satchel."}
		if _worn_uids().has(uid):
			return {"ok": false, "say": "Take it off first."}
		price = LootDB.sell_price_piece(p)
		(st.bag as Array).erase(p)
		entry = {"kind": "gear", "piece": p, "price": price}
	elif row_id.begins_with("item:"):
		var id := row_id.trim_prefix("item:")
		price = LootDB.sell_price_item(id)
		if price <= 0 or Travel.count(id) <= 0:
			return {"ok": false, "say": "Nobody here wants that."}
		Travel.items[id] = Travel.count(id) - 1
		if Travel.count(id) <= 0:
			Travel.items.erase(id)
		Events.item_gained.emit(id, -1, Travel.count(id))
		entry = {"kind": "item", "id": id, "n": 1, "price": price}
	else:
		return {"ok": false, "say": "That's not for sale."}
	Travel.give("grave_ash", price, false)
	var bb: Array = state().buyback
	bb.push_front(entry)
	while bb.size() > LootDB.BUYBACK_CAP:
		bb.pop_back()
	_changed()
	return {"ok": true, "say": "Done. %d ash." % price, "ash": price}


## The buyback shelf as rows (newest first).
static func buyback_rows() -> Array:
	var out: Array = []
	var bb: Array = state().buyback
	var ash := Travel.count("grave_ash")
	for i in bb.size():
		var e: Variant = bb[i]
		if not (e is Dictionary):
			continue
		var d := e as Dictionary
		var price := int(d.get("price", 0))
		var row := {"id": "bb:%d" % i, "price": price, "left": -1, "group": "Sold tonight"}
		var drops := bb.size() >= LootDB.BUYBACK_CAP and i == bb.size() - 1      # the shelf is full: this one goes next
		if String(d.get("kind", "")) == "gear":
			var p: Dictionary = d.get("piece", {})
			row["name"] = String(p.get("name", "gear"))
			row["piece"] = p
			row["quality"] = int(p.get("rarity", 0))
			row["text"] = "You sold this. Buy it back for what you were paid."
			row["sub"] = "ilvl %d" % GearDB.item_level(p)
			if drops:
				row["text"] += " The shelf is full: the next sale drops this one."
		else:
			var id := String(d.get("id", ""))
			row["name"] = String(ItemDB.def(id).get("name", id))
			row["item"] = id
			row["quality"] = LootDB.item_quality(id)
			row["text"] = "You sold this. Buy it back for what you were paid."
			row["sub"] = "x%d" % int(d.get("n", 1))
			if drops:
				row["text"] += " The shelf is full: the next sale drops this one."
		var why := ""
		if ash < price:
			why = "You need %d more grave ash." % (price - ash)
		elif String(d.get("kind", "")) == "gear" and (GearStats.state().bag as Array).size() >= GearDB.BAG_CAP:
			why = "Your satchel's gear is full."
		row["ok"] = why == ""
		row["why"] = why
		out.append(row)
	return out


## Buy back shelf entry `row_id` ("bb:<i>"). {ok, say}.
static func buy_back(row_id: String) -> Dictionary:
	var i := int(row_id.trim_prefix("bb:"))
	var bb: Array = state().buyback
	if i < 0 or i >= bb.size():
		return {"ok": false, "say": "That's gone."}
	for r: Dictionary in buyback_rows():
		if String(r.id) == row_id and not bool(r.ok):
			return {"ok": false, "say": String(r.why)}
	var d: Dictionary = bb[i]
	var price := int(d.get("price", 0))
	Travel.items["grave_ash"] = Travel.count("grave_ash") - price
	if Travel.count("grave_ash") <= 0:
		Travel.items.erase("grave_ash")
	Events.item_gained.emit("grave_ash", -price, Travel.count("grave_ash"))
	bb.remove_at(i)
	if String(d.get("kind", "")) == "gear":
		var GearRuntime: GDScript = load("res://core/items/gear_runtime.gd")
		GearRuntime.call("store", d.get("piece", {}))
	else:
		Travel.give(String(d.get("id", "")), int(d.get("n", 1)), false)
	_changed()
	return {"ok": true, "say": "Back where it belongs."}


static func _changed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var k := tree.get_first_node_in_group("progression")
		if k and k.has_method("refresh"):
			k.call("refresh")
	Travel.save_soon()

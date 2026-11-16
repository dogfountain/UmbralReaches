extends RefCounted
## What Hearthward's two merchants sell (village system; no class_name). ui/shop.gd shows it.
##   grisel  the ash-wife's cart: the village's projects (VillageCast.WARES: oil, rope, slates, thatch;
##           each restores something), relic fragments, and anything ItemDB prices
##   keep    the Kindled Keg's slate: ale (eases the Gloom), a round for the room (the regulars
##           toast you and remember it), rumours (each points at a task, a place or a person)
## Everything costs grave ash. Goods have a stock that comes back each village night (and on load);
## projects are bought once. stock(who) -> rows for the shop; buy(who, id) -> {ok, say}.
## Load by path: const VillageShop := preload("res://core/life/village/village_shop.gd")

const Cast := preload("res://core/life/village/village_cast.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Book := preload("res://core/story/quest_book.gd")
const HearthDB := preload("res://core/life/progression/hearth_db.gd")

const EastVillage := preload("res://core/life/village/village_east_marches.gd")   ## the east marches: Orrin Vail's stall
const Towns := preload("res://core/life/village/village_reach_towns.gd")   ## the towns: Gorse's smokehouse, the Last Lamp

const MERCHANTS := {
	"grisel": {"name": "Grisel the ash-wife", "greet": "Ash, then. Let's see it. Oil, rope, slate, thatch: whatever keeps the village lit."},
	"keep": {"name": "The Kindled Keg", "greet": "Ale's one. The room's six. Rumours cost what they're worth, which is two. Bread and stew if you're staying."},
	# the Hearthfire's trades (core/life/progression/hearth_db.gd): open as Hearthward's fire grows
	"hild": {"name": "Hild's forge", "greet": "Heat's up. Say what you want made, and pay in what you took off them."},
	"bet": {"name": "Bet Reed's garden", "greet": "Beans, bees and bitter things. Eat what I give you; it's better than it tastes."},
	# --- the east marches ---
	"orrin": EastVillage.MERCHANT_ORRIN,
	# --- the towns ---
	"gorse": Towns.MERCHANTS["gorse"], "vell": Towns.MERCHANTS["vell"],
}

const GOODS := {
	# --- the east marches ---
	"orrin": EastVillage.GOODS_ORRIN,
	# --- the towns ---
	"gorse": Towns.GOODS["gorse"], "vell": Towns.GOODS["vell"],
	"grisel": [
		{"id": "relic_fragment", "item": "relic_fragment", "price": 14, "stock": 2,
			"say": "Bell-bronze, or a saint. Don't ask which. The fires won't."},
	],
	"keep": [
		{"id": "ale", "name": "A mug of the Keg's ale", "glyph": "mug", "price": 1, "stock": 3,
			"text": "Warm, brown and bitter. Takes 14 Gloom off at once: drink it for the walk. In my fire, where the Gloom is already falling, you will not see it.",
			"say": "Mind the foam. It's the only thing in the valley that rises."},
		{"id": "round", "name": "Stand the room a round", "glyph": "mugs", "price": 6, "stock": 1,
			"text": "Every mug in the Keg filled on your ash. The regulars drink to you, and they remember who paid.",
			"say": "On the kindled one! Drink up, you sour lot."},
		{"id": "rumour", "name": "A rumour", "glyph": "ear", "price": 2, "stock": 4,
			"text": "What the room's been saying when it thinks nobody's listening. The keep is always listening.",
			"say": ""},
	],
}

## [cond, line]: the first unheard one whose condition holds; heard ones are remembered (by index in
## the save: add new rumours at the END only).
const RUMOURS := [
	["!q:edda_tongs", "Hild's been asking after her grandmother's tongs. Abel trims Edda's candles in the Kindlers' Yard. Ask her."],
	["!q:slow_way", "Ostrin's father went down the fen with a lantern, after his wife. Some say the lantern's still down there. Some say he is."],
	["!q:forty_first", "Oswin counts waystones in his sleep. Forty, he says. He wants the forty-first before he goes up. Somebody should walk him."],
	["!q:names_yard", "Abel won't carve a number on a stone. Says the Order left the names lying about the valley on slates, and he wants them."],
	["!q:keg_thief", "Somebody's been at the back keg after I bank the fire. If you hear who, I'm buying."],
	["!v:oil", "Grisel will trade you lamp oil for grave ash. Fennick's round gets longer. So does his complaining."],
	["!kindled:4", "Four braziers in the valley: the north meadow, the glade shrine, the Barrow Field, the fen. Light them and the dark leans less."],
	["!seal:oss_gallery", "The Ossuary is under the Waiting Field, past the First Pilgrims' Tomb: a bone bridge over the quarry to a gate hall. The gallery past it is sealed. Mind the bones that stand up."],
	["!met:wyck", "There's a hermit in the far Thornwood, past the camps. Buries birds face down. Small fire. Ask him about the Rooted, if you like long answers."],
	["!v:pell", "Pell went north toward the light. Nine winters, red hood. Nan still chalks a circle for her every night."],
	["secrets:1", "You've been poking about where the Order hid things. So did the Order. They didn't come back for most of it either."],
	["boss:thornwarden", "Hesk says the oaks are quieter since the Ring. Says it like a man who misses something."],
	["!elite:hobb", "Something knocks on the east road after dark. Three slow knocks, door to door. Maud won't say whose knock it is. She knows."],
	["boss:bone_abbot", "The lay brothers at the Barrow lodge have stopped counting. One of them asked me what came after nine hundred. I said ale."],
	["seal:summit", "The ward on the Crossing's down. Brannoc's been polishing a bell clapper all week. Won't say what for."],
	["qd:slow_way", "Ostrin's been civil. Twice. I'm keeping a tally in case it's catching."],
	["qd:names_yard", "Folk have started reading the names in the Yard out loud on the way past. Abel pretends not to listen."],
	["qd:edda_tongs", "Hild's forge rings different since the tongs came home. Or it's my ears. Brannoc says it's his ears."],
	["boss:ascended_warden", "Nobody's sure what to do with a night that doesn't lean on them. Brannoc's taken up whistling. It's worse than the dark."],
]

static var _sold := {}            ## "who/id" -> bought this village night
static var _night := -1
static var _slot := -1            ## the save slot the sold list belongs to


static func _restock(tree: SceneTree) -> void:
	var v := tree.root.find_child("Village", true, false) if tree else null
	var n := int(v.get("nights")) if v else 0
	if n != _night or _slot != Travel.slot:
		_night = n
		_slot = Travel.slot
		_sold.clear()


## Rows for the shop: [{id, name, text, price, glyph or item, left (-1 = once), ok, why, group}].
static func stock(who: String, tree: SceneTree) -> Array:
	_restock(tree)
	var out: Array = []
	var ws := VState.world(tree)
	var ash := VState.ash()
	if who == "grisel":
		for w: Dictionary in Cast.WARES:
			if VState.test(String(w.get("if", "")), ws, tree):
				out.append({"id": String(w.id), "name": String(w.text), "text": String(w.get("info", w.get("say", ""))),
					"price": int(w.price), "glyph": String(w.get("glyph", w.id)), "left": -1, "group": "For the village"})
	for g: Dictionary in GOODS.get(who, []):
		var left := int(g.stock) - int(_sold.get("%s/%s" % [who, g.id], 0))
		var row := {"id": String(g.id), "price": int(g.price), "left": left, "group": "Goods"}
		if g.has("item"):
			var def := ItemDB.def(String(g.item))
			row["name"] = String(def.get("name", g.item))
			row["text"] = String(def.get("text", ""))
			row["item"] = String(g.item)
		else:
			row["name"] = String(g.name)
			row["text"] = String(g.text)
			row["glyph"] = String(g.glyph)
		out.append(row)
	_hearth_rows(who, tree, out)
	if who == "grisel":
		# progression's consumables, when it prices any
		for item_id: String in ItemDB.DEFS:
			var def2: Dictionary = ItemDB.DEFS[item_id]
			if def2.has("price") and int(def2.price) > 0:
				out.append({"id": "item:" + item_id, "item": item_id, "name": String(def2.get("name", item_id)), "text": String(def2.get("text", "")),
					"price": int(def2.price), "left": -1, "group": "Goods"})
	for r: Dictionary in out:
		if r.has("hearth"):
			continue                                       # the Hearthfire runtime said why already
		var why := ""
		if who == "keep" and String(r.id) == "rumour" and int(r.left) != 0 and not has_rumour(tree):
			r["left"] = 0
			why = "The room has nothing new tonight."      # never sell ash for "nothing new"
		elif int(r.left) == 0:
			why = "Sold out until tomorrow night."
		elif ash < int(r.price):
			why = "You need %d more grave ash." % (int(r.price) - ash)
		r["ok"] = why == ""
		r["why"] = why
	return out


## Buy `id` from `who`. {ok, say} (say: the merchant's line, or why not).
static func buy(who: String, id: String, tree: SceneTree) -> Dictionary:
	var row := {}
	for r: Dictionary in stock(who, tree):
		if String(r.id) == id:
			row = r
	if row.is_empty():
		return {"ok": false, "say": "That's not for sale."}
	if not bool(row.ok):
		return {"ok": false, "say": String(row.why)}
	if row.has("hearth"):
		return _hearth_buy(who, row, tree)
	if not VState.pay(int(row.price)):
		return {"ok": false, "say": "Not enough ash."}
	if int(row.left) > 0:
		_sold["%s/%s" % [who, id]] = int(_sold.get("%s/%s" % [who, id], 0)) + 1
	var say := "Done."
	if who == "grisel":
		for w: Dictionary in Cast.WARES:
			if String(w.id) == id:
				for a in String(w.get("do", "")).split(","):
					a = a.strip_edges()
					if a.begins_with("v:"):
						VState.set_flag(a.trim_prefix("v:"))
				say = String(w.get("say", say))
				var v := tree.root.find_child("Village", true, false) if tree else null
				if v and v.has_method("refresh"):
					v.call("refresh", true)
		if row.has("item"):
			Travel.give(String(row.item), 1)
			say = _goods_say(who, id, "Here. Don't waste it.")
		Book.add_att("grisel", 1 if int(row.price) >= 10 else 0)
	else:
		if row.has("item"):
			Travel.give(String(row.item), 1)              # an item on any merchant's board is handed over (it was only the ash-wife's)
			say = _goods_say(who, id, "Here.")
		match id:
			"ale":
				var p := tree.get_first_node_in_group(Groups.PLAYER) if tree else null
				if p and p.has_method("add_gloom"):
					p.call("add_gloom", -14.0)
				say = _goods_say(who, id, say)
			"round":
				for npc: String in ["keep", "hesk", "harrow", "brannoc"]:
					Book.add_att(npc, 1)
				var ks := tree.get_first_node_in_group("keg_scenes") if tree else null
				if ks and ks.has_method("play"):
					ks.call_deferred("play", "round")
				say = _goods_say(who, id, say)
			"rumour":
				say = rumour(tree)
	VState.save()
	return {"ok": true, "say": say}


static func _goods_say(who: String, id: String, fallback: String) -> String:
	for g: Dictionary in GOODS.get(who, []):
		if String(g.id) == id and String(g.get("say", "")) != "":
			return String(g.say)
	return fallback


## Whether a rumour the wanderer has not heard holds now.
static func has_rumour(tree: SceneTree) -> bool:
	var st := Book.st()
	var heard: Dictionary = st.rumours if st.get("rumours") is Dictionary else {}
	var ws := VState.world(tree)
	for i in RUMOURS.size():
		if not heard.has(str(i)) and VState.test(String(RUMOURS[i][0]), ws, tree):
			return true
	return false


## The next rumour worth telling (remembered in Travel.story["rumours"]).
static func rumour(tree: SceneTree) -> String:
	var st := Book.st()
	if not (st.get("rumours") is Dictionary):
		st["rumours"] = {}
	var heard: Dictionary = st.rumours
	var ws := VState.world(tree)
	for i in RUMOURS.size():
		var r: Array = RUMOURS[i]
		if heard.has(str(i)) or not VState.test(String(r[0]), ws, tree):
			continue
		heard[str(i)] = true
		return String(r[1])
	return "Nothing new. The dark's quiet tonight. That's the worst kind."


# --- the Hearthfire's trades (hearth.gd does the work; these are the shop's rows) -----------------

static func _hearth(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("hearth") if tree else null


## Meals on the Keg's slate and in Bet's garden; Hild's works and smelting at her forge.
static func _hearth_rows(who: String, tree: SceneTree, out: Array) -> void:
	var h := _hearth(tree)
	for m: Dictionary in HearthDB.MEALS:
		if String(m.who) != who:
			continue
		var why := String(h.call("why_not_eat", String(m.id))) if h else "The fire is out."
		out.append({"id": "meal:" + String(m.id), "name": String(m.name), "text": String(m.text), "price": int(m.price),
			"glyph": String(m.glyph), "left": -1, "group": "To eat and drink", "sub": "%s, %s" % [String(HearthDB.KINDS[String(m.kind)]).to_lower(), HearthDB.fmt_secs(float(m.secs))],
			"ok": why == "", "why": why, "hearth": true})
	# r33 loot: gathering trades (ash-blooms, grave-iron; hearth.gd trade_rows / trade)
	if h and h.has_method("trade_rows"):
		out.append_array(h.call("trade_rows", who))
	if who != "hild":
		return
	for w: Dictionary in HearthDB.WORKS:
		var done := h != null and HearthDB.works(h.call("hs")).has(String(w.id))
		if done:
			continue
		var why := String(h.call("why_not_work", String(w.id))) if h else "The forge is cold."
		var text := String(w.text)
		if int(w.get("frag", 0)) > 0:
			text += " Takes %d relic fragment." % int(w.frag)
		out.append({"id": "work:" + String(w.id), "name": String(w.name), "text": text, "price": int(w.price),
			"glyph": String(w.glyph), "left": -1, "group": "For the fires", "ok": why == "", "why": why, "hearth": true})
	if h and bool(h.call("shards_supported")):
		var why := String(h.call("why_not_smelt"))
		out.append({"id": "smelt", "name": "Smelt ash into an ember shard", "price": int(HearthDB.SMELT.ash),
			"text": "Hild renders %d grave ash down to one ember shard, for raising and reforging your gear at a fire." % int(HearthDB.SMELT.ash),
			"glyph": "cinder", "left": -1, "sub": "as often as you like", "group": "For your gear", "ok": why == "", "why": why, "hearth": true})


static func _hearth_buy(who: String, row: Dictionary, tree: SceneTree) -> Dictionary:
	var h := _hearth(tree)
	if h == null:
		return {"ok": false, "say": "The fire is out."}
	var id := String(row.id)
	var res := "?"
	var say := "Done."
	if id.begins_with("meal:"):
		var mid := id.trim_prefix("meal:")
		res = String(h.call("eat", mid))
		say = String(HearthDB.meal(mid).get("say", say))
	elif id.begins_with("work:"):
		var wid := id.trim_prefix("work:")
		res = String(h.call("buy_work", wid))
		say = String(HearthDB.work(wid).get("say", say))
	elif id == "smelt":
		res = String(h.call("smelt"))
		say = "There. It's warm. It'll stay warm. Don't ask me why; it's your ash."
	elif id.begins_with("trade:"):   # r33 loot: a gathering trade
		res = String(h.call("trade", id.trim_prefix("trade:")))
		say = "Done. Bring me more of it."
	if res != "":
		return {"ok": false, "say": res}
	Book.add_att(who, 1 if int(row.price) >= 10 else 0)
	VState.save()
	return {"ok": true, "say": say}

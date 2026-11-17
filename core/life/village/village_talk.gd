extends Node
## Conversations with Hearthward's people (village system; no class_name). Uses the story's
## dialogue box (ui/dialogue.gd, owned by the story director in group "story") through its public
## API only: open(), line(), close(), is_open(), typing() and its advanced/chosen/closed signals.
## The story director ignores those signals while it is not running a conversation of its own.
## The box's portrait only knows dwarves, so this driver opens it with no portrait and, if the
## box exposes its portrait viewport, puts the villager's own rig in it (jaw moving while the line
## types); without it the box simply shows no portrait.
## Data: village_talk_db.gd. Actions in `do` go through QuestBook.run first (tasks, attitudes,
## gifts, payments, `shop:who`), then met:/v: here. A payment that fails shows a "not enough ash"
## line and returns to the node. `shop:grisel` opens the ash-wife's shop (ui/shop.gd, through the
## story director) when the conversation ends.

const DB := preload("res://core/life/village/village_talk_db.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const Dialogue := preload("res://ui/dialogue.gd")
const Rig := preload("res://core/life/village/villager_rig.gd")
const Life := preload("res://core/npc/npc_life.gd")
const Voice := preload("res://core/npc/npc_voice.gd")
const QuestBook := preload("res://core/story/quest_book.gd")
const QuestGiver := preload("res://core/story/quest_giver.gd")
const Guide := preload("res://core/story/guide.gd")
const GuideLines := preload("res://core/story/guide_lines.gd")

var director: Node
var ui: CanvasLayer
var conv := ""
var node_id := ""
var who: Node3D
var player: Node3D
var _choices: Array = []
var _syn := {}
var _portrait: Node3D
var _t := 0.0
var _life: Life
var said: Array[String] = []          ## lines shown (tests)
var _shop_after := ""
var _quest_after := ""               ## "offer:id" / "turnin:id": the task screen to open after (r33)
var _poor := false
var last_npc: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func active() -> bool:
	return conv != ""


## Start talking with villager `v`. false when the box is busy or missing.
func start(v: Node3D, by: Node) -> bool:
	var story := get_tree().get_first_node_in_group("story")
	var box: Variant = story.get("ui") if story else null
	if box == null or not is_instance_valid(box) or bool(box.call("is_open")):
		return false
	var cid := String(v.get("id"))
	if not DB.CONV.has(cid):
		return false
	ui = box
	conv = cid
	who = v
	last_npc = v
	_shop_after = ""
	player = by as Node3D
	for sig: Array in [["advanced", _on_advanced], ["chosen", _on_chosen], ["closed", _on_closed]]:
		if not ui.is_connected(String(sig[0]), sig[1]):
			ui.connect(String(sig[0]), sig[1])
	ui.call("open", String(DB.CONV[cid].name), {})
	ui.call("set_voice", Voice.for_node(v), String(DB.CONV[cid].name))   # her own voice (family by age/sex)
	ui.call("set_mood", QuestBook.att(cid))
	_portrait_in(v)
	_show(_start_node(cid))
	return true


func _start_node(cid: String) -> String:
	var ws := VState.world(get_tree())
	for pair: Array in DB.CONV[cid].start:
		if VState.test(String(pair[0]), ws, get_tree()):
			return String(pair[1])
	return "hub"


func _node(id: String) -> Dictionary:
	if id == "#syn":
		return _syn
	if id == "#guide":
		return {"say": _guide_answer(), "next": "hub"}
	return (DB.CONV[conv].nodes as Dictionary).get(id, {})


func _text(n: Dictionary) -> String:
	var ws := VState.world(get_tree())
	var s := String(n.get("say", ""))
	if n.has("say_if"):
		for pair: Array in n.say_if:
			if VState.test(String(pair[0]), ws, get_tree()):
				s = String(pair[1])
				if pair.size() > 2 and String(pair[2]) != "":
					_do(String(pair[2]))          # a line said once, then retired
				break
	s = s.replace("{ash}", str(VState.ash())).replace("{hollows}", str(VState.hollows(get_tree()))).replace("{kindled}", str(int(ws.kindled)))
	return s


func _show(id: String) -> void:
	node_id = id
	var n := _node(id)
	if n.is_empty() or id == "":
		_end()
		return
	if n.has("do"):
		_do(String(n["do"]))
	_choices.clear()
	var ws := VState.world(get_tree())
	if true:
		for ch: Dictionary in n.get("choices", []):
			if ch.has("if") and not VState.test(String(ch["if"]), ws, get_tree()):
				continue
			if bool(ch.get("once", false)) and _picked(ch):
				continue
			_choices.append(ch)
	# r33: an offered task's mark becomes a line in the hub (the available / hand-in mark: the accept and
	# turn-in screens, ui/quest_offer.gd, open when the conversation ends)
	if id == "hub":
		_choices = QuestGiver.merge(_choices, conv, get_tree())
		if _guide_answer() != "":
			# a guided first act: anyone can be asked the way (core/story/guide.gd), before the goodbye
			_choices.insert(maxi(0, _choices.size() - 1), {"text": GuideLines.ASK, "to": "#guide"})
	var labels: Array[String] = []
	var marks: Array[String] = []
	for ch2: Dictionary in _choices:
		labels.append(QuestBook.label(String(ch2.text), String(ch2.get("do", ""))))
		marks.append(QuestBook.task_mark(ch2))
	var text := _text(n)
	said.append("%s: %s" % [conv, text])
	ui.call("set_mood", QuestBook.att(conv))
	ui.call("line", String(DB.CONV[conv].name), text, labels, marks)
	if is_instance_valid(who):
		who.set("speaking", true)


## What this person says when asked "Which way?" ("" while the guide is off).
func _guide_answer() -> String:
	var g := get_tree().get_first_node_in_group("guide") as Guide
	return g.answer() if g != null else ""


func _picked(ch: Dictionary) -> bool:
	var d := VState.data()
	if not d.has("picked"):
		d["picked"] = {}
	return (d.picked as Dictionary).has("%s:%s" % [conv, ch.text])


## Apply a node's or choice's actions (QuestBook first: tasks, attitudes, gifts, ash, shops).
## Sets _poor when a payment failed (and nothing after it ran).
func _do(actions: String) -> void:
	var r := QuestBook.run(actions)
	_poor = bool(r.poor)
	if String(r.shop) != "":
		_shop_after = String(r.shop)
	for a: String in r.rest:
		if a == "shop":
			_shop_after = "grisel"
		elif a.begins_with("met:"):
			VState.set_met(a.trim_prefix("met:"))
		elif a.begins_with("v:"):
			VState.set_flag(a.trim_prefix("v:"))


func _on_advanced() -> void:
	if conv == "":
		return
	var n := _node(node_id)
	if not _choices.is_empty():
		return
	var nx := String(n.get("next", ""))
	if nx == "":
		_end()
	else:
		_show(nx)


func _on_chosen(i: int) -> void:
	if conv == "" or i < 0 or i >= _choices.size():
		return
	var ch: Dictionary = _choices[i]
	if ch.has("quest_ui"):
		_quest_after = String(ch.quest_ui)
		_end()
		return
	if String(ch.get("do", "")) != "":
		_do(String(ch["do"]))
		if _poor:
			_syn = {"say": "You haven't the ash for that. ({ash} in your satchel.)", "next": node_id}
			_show("#syn")
			return
	var d := VState.data()
	if not d.has("picked"):
		d["picked"] = {}
	(d.picked as Dictionary)["%s:%s" % [conv, ch.text]] = true
	var to := String(ch.get("to", ""))
	if to == "":
		_end()
	else:
		_show(to)


func _end() -> void:
	var was_open := ui != null and is_instance_valid(ui) and bool(ui.call("is_open"))
	conv = ""
	node_id = ""
	_choices.clear()
	if is_instance_valid(who):
		who.set("speaking", false)
		who.set("attend", null)
	who = null
	_life = null                       # the next speaker's portrait gets her own blink and breath
	if is_instance_valid(_portrait):
		_portrait.queue_free()
	_portrait = null
	if ui and is_instance_valid(ui):
		for sig: Array in [["advanced", _on_advanced], ["chosen", _on_chosen], ["closed", _on_closed]]:
			if ui.is_connected(String(sig[0]), sig[1]):
				ui.disconnect(String(sig[0]), sig[1])
		if was_open:
			ui.call("close")
	VState.save()
	if _quest_after != "":
		var qa := _quest_after
		_quest_after = ""
		var st := get_tree().get_first_node_in_group("story")
		if st and st.has_method("open_quest"):
			st.call_deferred("open_quest", qa, String(DB.CONV.get(String(last_npc.get("id")) if is_instance_valid(last_npc) else "", {}).get("name", "")))
	if _shop_after != "":
		var shop_who := _shop_after
		_shop_after = ""
		var story := get_tree().get_first_node_in_group("story")
		if story and story.has_method("open_shop"):
			story.call_deferred("open_shop", shop_who, last_npc if is_instance_valid(last_npc) else null)


func _on_closed() -> void:
	if conv != "":
		_shop_after = ""
		_end()


# --- the portrait ---------------------------------------------------------------------------------

func _portrait_in(v: Node3D) -> void:
	var box := ui as Dialogue
	if box == null:
		return
	var data: Dictionary = v.get("data") if v.get("data") is Dictionary else {}
	var opts: Dictionary = (data.get("rig", {}) as Dictionary).duplicate()
	opts["name"] = String(v.get("id"))
	_portrait = Rig.create(opts)
	var hc: Vector3 = _portrait.get("hc")
	_portrait.position = Vector3(0, 1.37 - hc.y * Rig.SCALE, 0.02)
	box.show_portrait(_portrait)


func _process(delta: float) -> void:
	if conv != "" and (ui == null or not is_instance_valid(ui) or not bool(ui.call("is_open"))):
		_end()           # the box was closed without a signal (another system, a scene change)
		return
	if conv == "" or not is_instance_valid(_portrait):
		return
	_t += delta
	var typing := bool(ui.call("typing"))
	var pr := _portrait as DwarfRig
	pr.reset()
	for side in 2:
		pr.q(5 + side * 3, Quaternion(Vector3.FORWARD, 0.06 if side == 0 else -0.06))
		pr.q(6 + side * 3, Quaternion(Vector3.RIGHT, 0.3))
	if _life == null:
		_life = Life.new(hash(String(who.get("id")) if is_instance_valid(who) else "v"))
	_life.portrait(pr, delta, typing, 0.15)
	pr.apply()
	_portrait.call("update_glow")
	if is_instance_valid(who):
		who.set("speaking", typing)

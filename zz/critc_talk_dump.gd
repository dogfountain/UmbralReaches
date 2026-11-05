extends Node
## Every conversation, read as a player would (critique C): walks each conversation's graph from
## its start node through every choice, under four world states (a fresh arrival, midway, after
## the two bosses, after the ending), and writes the transcript to user://critc_talk.txt.
## Checks: no unreplaced {placeholders}, no empty lines, no line too long for the box (> 330
## characters), no node that can't be reached, every say_if has its fallback, and the same line
## never repeats across two different people.
##   HOME=<scratch>/home godot --headless --path . res://zz/critc_talk_dump.tscn
## Ends: TALKDUMP PASS / TALKDUMP FAIL n. In memory only (Travel._busy, the village in a sandbox).

const DialogueDB := preload("res://core/story/dialogue_db.gd")
const TalkDB := preload("res://core/life/village/village_talk_db.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Book := preload("res://core/story/quest_book.gd")

var fails := 0
var out := PackedStringArray()


func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("  FAIL ", what)


func _ready() -> void:
	Travel._busy = true
	var keep_story := Travel.story.duplicate(true)
	var keep_b := Travel.bosses_slain.duplicate()
	var keep_s := Travel.seals_broken.duplicate()
	var keep_sys := Travel.systems.duplicate(true)
	Book.quiet = true
	var states := {
		"fresh": [{}, {}, {"flags": {}}, {}, 0],
		"mid": [{"thornwarden": true}, {"henge": true}, {"flags": {"arrived": true, "met_keep": true},
			"quests": {"edda_tongs": {"s": 1, "d": false, "p": "", "f": {}}, "slow_way": {"s": 3, "d": false, "p": "", "f": {}},
				"keg_thief": {"s": 3, "d": false, "p": "covered", "f": {}}, "forty_first": {"s": 1, "d": false, "p": "", "f": {}},
				"names_yard": {"s": 1, "d": false, "p": "", "f": {}}}}, {"met": {"hild": true, "abel": true, "oswin": true, "nan": true}}, 2],
		"two": [{"thornwarden": true, "bone_abbot": true}, {"henge": true, "oss_gallery": true}, {"flags": {"arrived": true, "met_keep": true, "met_hesk": true, "met_harrow": true, "met_brannoc": true}}, {"met": {"hild": true, "fennick": true}}, 4],
		"end": [{"thornwarden": true, "bone_abbot": true, "ascended_warden": true}, {"henge": true, "oss_gallery": true, "summit": true},
			{"flags": {"arrived": true, "met_keep": true, "ending_told": true, "met_hesk": true, "met_harrow": true, "met_brannoc": true, "hesk_after": true, "harrow_after": true, "brannoc_after": true},
			"quests": {"edda_tongs": {"s": 3, "d": true, "p": "stone", "f": {}}, "forty_first": {"s": 2, "d": true, "p": "faith", "f": {}},
				"slow_way": {"s": 4, "d": true, "p": "truth", "f": {}}, "keg_thief": {"s": 4, "d": true, "p": "told", "f": {}},
				"names_yard": {"s": 2, "d": true, "p": "deep", "f": {}}}},
			{"restored": {"pell": true, "wenna": true, "reed_home": true, "wrights_home": true}, "met": {"hild": true, "abel": true, "oswin": true, "nan": true, "fennick": true, "wyck": true, "grisel": true, "wenna": true}}, 4],
	}
	var seen_lines := {}            # text -> speaker (repeats across people)
	for sn: String in states:
		var st: Array = states[sn]
		Travel.bosses_slain = st[0]
		Travel.seals_broken = st[1]
		Travel.story = (st[2] as Dictionary).duplicate(true)
		VState.sandbox = (st[3] as Dictionary).duplicate(true)
		VState.kindled_override = int(st[4])
		out.append("\n==================== %s ====================" % sn)
		var ws := VState.world(get_tree())
		ws["kindled"] = int(st[4])
		for cid: String in DialogueDB.CONV:
			_walk(cid, DialogueDB.CONV[cid], ws, false, seen_lines)
		for cid2: String in TalkDB.CONV:
			_walk(cid2, TalkDB.CONV[cid2], ws, true, seen_lines)
	var f := FileAccess.open("user://critc_talk.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(out))
		f.close()
	print("TALKDUMP wrote ", ProjectSettings.globalize_path("user://critc_talk.txt"))
	Travel.story = keep_story
	Travel.bosses_slain = keep_b
	Travel.seals_broken = keep_s
	Travel.systems = keep_sys
	VState.sandbox = null
	VState.kindled_override = -1
	print("TALKDUMP PASS" if fails == 0 else "TALKDUMP FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _test(village: bool, cond: String, ws: Dictionary) -> bool:
	return VState.test(cond, ws, get_tree()) if village else QuestDB_test(cond, ws)


func QuestDB_test(cond: String, ws: Dictionary) -> bool:
	return (DialogueDB.QuestDB as GDScript).call("test", cond, ws)


func _walk(cid: String, c: Dictionary, ws: Dictionary, village: bool, seen_lines: Dictionary) -> void:
	var nodes: Dictionary = c.nodes
	var start := ""
	for pair: Array in c.start:
		if _test(village, String(pair[0]), ws):
			start = String(pair[1])
			break
	out.append("\n--- %s (%s) opens on %s" % [c.name, cid, start])
	var reach := {}
	var todo: Array[String] = [start]
	# reachable over ALL start nodes and every choice (not only this state's): for the audit
	for pair2: Array in c.start:
		todo.append(String(pair2[1]))
	while not todo.is_empty():
		var id: String = todo.pop_back()
		if id == "" or reach.has(id) or not nodes.has(id):
			continue
		reach[id] = true
		var n: Dictionary = nodes[id]
		if n.has("next"):
			todo.append(String(n.next))
		for ch: Dictionary in n.get("choices", []):
			todo.append(String(ch.get("to", "")))
	for nid: String in nodes:
		if not reach.has(nid) and nid not in ["poor", "none"]:
			ok(false, "%s/%s can never be reached" % [cid, nid])
	# the transcript: every node this state can show, in graph order from the start
	var shown := {}
	var q: Array[String] = [start]
	while not q.is_empty():
		var id2: String = q.pop_front()
		if id2 == "" or shown.has(id2) or not nodes.has(id2):
			continue
		shown[id2] = true
		var n2: Dictionary = nodes[id2]
		var text := String(n2.get("say", ""))
		if n2.has("say_if"):
			for pair3: Array in n2.say_if:
				if _test(village, String(pair3[0]), ws):
					text = String(pair3[1])
					break
		text = text.replace("{kindled}", str(int(ws.get("kindled", 0)))).replace("{ash}", "37").replace("{hollows}", "4")
		var who := String(n2.get("who", c.name))
		out.append("  [%s] %s: %s" % [id2, who, text])
		ok(text.strip_edges() != "", "%s/%s says nothing here" % [cid, id2])
		ok(not text.contains("{"), "%s/%s leaves a placeholder: %s" % [cid, id2, text])
		ok(text.length() <= 330, "%s/%s too long for the box (%d)" % [cid, id2, text.length()])
		if text.length() > 24 and seen_lines.has(text) and String(seen_lines[text]) != cid:
			ok(false, "%s/%s repeats %s's line: %s" % [cid, id2, seen_lines[text], text])
		seen_lines[text] = cid
		for ch2: Dictionary in n2.get("choices", []):
			if ch2.has("if") and not _test(village, String(ch2["if"]), ws):
				continue
			out.append("      > %s%s" % [String(ch2.text), ("   {" + String(ch2.get("do", "")) + "}") if String(ch2.get("do", "")) != "" else ""])
			q.append(String(ch2.get("to", "")))
		if n2.has("next"):
			q.append(String(n2.next))

extends Node
## The Pilgrims' Threshold task (core/story/quest_chains_threshold.gd): its giver exists, its visit point is inside the
## Pilgrims' Chapel (chapel.gd, built at home and moved Endgame.O east), its steps are of known kinds. Ends: THRESHOLD QUEST TEST PASS / FAIL n
const TQ := preload("res://core/story/quest_chains_threshold.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const Chapel := preload("res://core/world/realm/rift/chapel.gd")
const KINDS := ["visit", "cond", "turnin", "slay", "collect", "find", "gather", "carry", "talk", "reach"]


func _ready() -> void:
	var fails := 0
	var mid := Endgame.w(Chapel.to_world(Vector3(0.0, 3.0, 0.0)))
	for id: String in TQ.QUESTS:
		var q: Dictionary = TQ.QUESTS[id]
		if not Cast.CAST.has(q.giver):
			fails += 1
			print("FAIL giver ", q.giver)
		for st: Dictionary in q.steps:
			if not String(st.kind) in KINDS:
				fails += 1
				print("FAIL kind ", st.kind)
			if st.has("at") and Vector2(mid.x, mid.z).distance_to(st.at) > 0.8:
				fails += 1
				print("FAIL step at ", st.at, " is not the chapel's middle ", mid)
	print("THRESHOLD QUEST TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	get_tree().quit(fails)

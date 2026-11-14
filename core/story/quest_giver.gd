extends RefCounted
## Who has a task for the wanderer, and what the mark over their head says (story, r33; no
## class_name). Pure static functions over quest_book.gd's state and the village's conditions, so
## the markers (quest_markers.gd), the conversation drivers (story.gd, village_talk.gd) and the
## tests agree:
##   state(npc)      "turnin" (something to hand in or say to them: the gold "?"), "available"
##                   (a task they would give: the gold mark), "progress" (a task of theirs under way:
##                   the grey "?"), or ""
##   gossip(npc)     the extra lines an offered task adds to their conversation hub: accept-screen
##                   tasks only; the old tasks are set in their own words
## An NPC id is a villager's `id` (village_cast.gd) or a Keg patron's `talk_id` (dialogue_db.gd).
## Load by path: const QuestGiver := preload("res://core/story/quest_giver.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const StoryDB := preload("res://core/story/quest_db.gd")
const VState := preload("res://core/life/village/village_state.gd")


## The id a node answers to as a giver ("" = not a person).
static func npc_id(n: Node) -> String:
	if n == null:
		return ""
	var tid: Variant = n.get("talk_id")
	if tid is String and String(tid) != "":
		return String(tid)
	if n.is_in_group("villager"):
		return String(n.get("id"))
	return ""


## Would `id` be offered now (giver's mark): not under way, not done (unless a daily from an
## earlier day), and its `avail` condition holds.
## Until the keep has spoken (`flag:met_keep`), nothing is offered: the first night opens on one
## tutorial errand (find the Kindled Keg), not a forest of gold marks.
static func available(id: String, tree: SceneTree = null, ws := {}) -> bool:
	var qd: Dictionary = Chains.QUESTS.get(id, {})
	if qd.is_empty() or Book.active(id):
		return false
	if Chains.hidden(id):                      # the slice: no dailies, no attunement chains
		return false
	if qd.has("found_at"):                     # found in the world (quest_world.gd starts it), never offered
		return false
	if Book.started(id) and not Book.repeatable(id):
		return false
	var state: Dictionary = ws if not ws.is_empty() else (VState.world(tree) if tree else _ws())
	if not StoryDB.test("flag:met_keep", state):
		return false
	var cond := Chains.avail_cond(id)
	if cond == "":
		return true
	return VState.test(cond, state, tree)


static func _ws() -> Dictionary:
	return {"flags": Travel.story.get("flags", {}), "kindled": 0, "seals": Travel.seals_broken,
		"bosses": Travel.bosses_slain, "items": Travel.items}


## Whom a task's current step wants to speak to ("" = nobody: out in the world).
static func talker(id: String) -> String:
	if not Book.active(id):
		return ""
	var stp := Chains.step(id, Book.step(id))
	return String(stp.get("who", "")) if String(stp.get("kind", "")) in ["talk", "turnin"] else ""


static func turnin_of(id: String) -> String:
	var steps: Array = (Chains.QUESTS.get(id, {}) as Dictionary).get("steps", [])
	for i in range(steps.size() - 1, -1, -1):
		if String(steps[i].kind) in ["turnin", "talk"]:
			return String(steps[i].get("who", Chains.giver(id)))
	return Chains.giver(id)


## The mark over `npc`'s head: [state, quest id, daily?]. Turn-ins first, then offers, then grey.
static func state(npc: String, tree: SceneTree = null) -> Array:
	if npc == "":
		return ["", "", false]
	for id: String in Chains.ORDER:
		if talker(id) == npc:
			return ["turnin", id, false]
	var daily_id := ""
	for id2: String in Chains.ORDER:
		if Chains.giver(id2) == npc and available(id2, tree):
			if String(Chains.QUESTS[id2].get("repeat", "")) == "daily":
				if daily_id == "":
					daily_id = id2
				continue
			return ["available", id2, false]
	if daily_id != "":
		return ["available", daily_id, true]
	for id3: String in Chains.ORDER:
		if Book.active(id3) and (Chains.giver(id3) == npc or turnin_of(id3) == npc):
			return ["progress", id3, false]
	return ["", "", false]


## r34: every giver's mark in one pass over the tasks ({npc: [state, quest id, daily?]}; npcs
## with no mark are absent). Same answer as state() per npc, at 48 tasks x 18 givers a refresh
## state() one by one cost ~0.9 ms; this is one walk of ORDER.
static func states(tree: SceneTree = null) -> Dictionary:
	var turn := {}
	var avail := {}
	var daily := {}
	var prog := {}
	var ws: Dictionary = VState.world(tree) if tree else _ws()
	for id: String in Chains.ORDER:
		var g := Chains.giver(id)
		if Book.active(id):
			var tk := talker(id)
			if tk != "" and not turn.has(tk):
				turn[tk] = id
			if not prog.has(g):
				prog[g] = id
			var ti := turnin_of(id)
			if not prog.has(ti):
				prog[ti] = id
		elif not avail.has(g) and available(id, tree, ws):
			if String(Chains.QUESTS[id].get("repeat", "")) == "daily":
				if not daily.has(g):
					daily[g] = id
			else:
				avail[g] = id
	var out := {}
	for npc: String in prog:
		out[npc] = ["progress", prog[npc], false]
	for npc2: String in daily:
		out[npc2] = ["available", daily[npc2], true]
	for npc3: String in avail:
		out[npc3] = ["available", avail[npc3], false]
	for npc4: String in turn:
		out[npc4] = ["turnin", turn[npc4], false]
	# r34 merge: the main story's own talk objectives (quest_db.gd "who"/"mark") mark their NPC too;
	# the keep had no mark at the start ("Find the keeper of the Kindled Keg") because the marks only
	# read the side chains. A side task's hand-in still wins over a main "available".
	for o: Dictionary in StoryDB.OBJECTIVES:
		var who := String(o.get("who", ""))
		if who == "" or not StoryDB.test(String(o.when), ws) or StoryDB.test(String(o.done), ws):
			continue
		var mk := String(o.get("mark", "available"))
		# the story's own errand outranks a side offer at the same person: the keep's "!" at the start used to
		# carry the Missing Ale's name (keg_thief), not "Find the keeper", and the map pin read as a side task
		if not out.has(who) or (mk == "turnin" and String(out[who][0]) != "turnin") or String(out[who][0]) == "progress" \
				or (mk == "available" and String(out[who][0]) == "available"):
			out[who] = [mk, "main:" + String(o.id), false]
	return out


## Lines an NPC's hub gains: [{text, quest_ui: "offer:id" | "turnin:id"}] (accept-screen tasks).
static func gossip(npc: String, tree: SceneTree = null) -> Array:
	var out: Array = []
	for id: String in Chains.ORDER:
		var qd: Dictionary = Chains.QUESTS[id]
		if not bool(qd.get("offer", false)):
			continue
		if Book.ready(id) and talker(id) == npc:
			out.append({"text": "?  %s" % String(qd.name), "quest_ui": "turnin:" + id, "to": ""})
		elif Chains.giver(id) == npc and available(id, tree):
			var tag := "  (daily)" if String(qd.get("repeat", "")) == "daily" else ""
			out.append({"text": "◆  %s%s" % [String(qd.name), tag], "quest_ui": "offer:" + id, "to": ""})
	return out


## A hub's choices with the offered tasks' lines set in before the last one (the leave line), so
## the hub's own first choice and its goodbye keep their places.
static func merge(choices: Array, npc: String, tree: SceneTree = null) -> Array:
	var g := gossip(npc, tree)
	if g.is_empty():
		return choices
	if choices.is_empty():
		return g
	var out: Array = choices.slice(0, choices.size() - 1)
	out.append_array(g)
	out.append(choices.back())
	return out

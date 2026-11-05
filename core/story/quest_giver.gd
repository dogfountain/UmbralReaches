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
static func available(id: String, tree: SceneTree = null) -> bool:
	var qd: Dictionary = Chains.QUESTS.get(id, {})
	if qd.is_empty() or Book.active(id):
		return false
	if Book.started(id) and not Book.repeatable(id):
		return false
	var cond := String(qd.get("avail", ""))
	if cond == "":
		return true
	return VState.test(cond, VState.world(tree) if tree else _ws(), tree)


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

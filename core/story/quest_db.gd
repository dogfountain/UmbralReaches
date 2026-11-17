extends RefCounted
## The story's objectives and the condition language the dialogue shares (docs/STORY.md).
## Pure data + static functions over a world-state snapshot `ws` so the tests can drive them:
##   ws = {"flags": {id: true}, "kindled": int (of the four), "seals": {id: true},
##         "bosses": {id: true}, "items": {id: count}}
## Objectives are not "accepted": each shows while its `when` holds and is done while its `done`
## holds, so the line always follows the real world (a seal broken before the keep sent you there
## simply counts). Load by path: const QuestDB := preload("res://core/story/quest_db.gd")

## The four braziers of the valley (RealmBosses.BRAZIERS; the spawn brazier is Hearthward's own). Their display names
## (Brazier.FIRE_NAMES): StairFoot "the meadow fire", Shrine "the glade's fire", Landing "the Barrow Field fire", Threshold "the fen fire".
const BRAZIERS := ["StairFoot", "Shrine", "Landing", "Threshold"]
## Tasks, attitudes and remembered choices: their condition terms live in quest_book.gd.
const QuestBook := preload("res://core/story/quest_book.gd")

## In display order. main = the story's spine (shown first); side = the kindling.
## r34 merge: "who" (an NPC id) + "mark" ("available" | "turnin") put the quest mark over that NPC's
## head while the objective is open (quest_giver.gd states(); the keep at the start and the end).
const OBJECTIVES := [
	{"id": "arrive", "main": true, "when": "", "done": "flag:met_keep", "who": "keep", "mark": "available",
		"text": "Find the keep in the Kindled Keg"},
	# a guided save's first step out (core/story/guide.gd: flag "guide" is set by a new game's opening): one fire before
	# the doors, so the first walk out of Hearthward is short and teaches the kindling. Gone once a fire or a door is taken.
	{"id": "first_fire", "main": true, "when": "flag:met_keep,flag:guide,!kindled:1,!seal:henge,!seal:oss_gallery,!boss:thornwarden,!boss:bone_abbot", "done": "kindled:1",
		"text": "Kindle the brazier in the meadow north of Hearthward"},
	# Two doors, one line: his sentence while both seals are shut. Breaking one swaps it for that fight,
	# and the other door is the next line. Either door first still counts.
	{"id": "doors", "main": true, "when": "flag:met_keep", "done": "seal:henge|boss:thornwarden|seal:oss_gallery|boss:bone_abbot",
		"text": "Pick a door: the thorn seal west, up the Thornwood's hill, or the gallery seal in the Ossuary, south down the Waiting Field's road"},
	{"id": "thorn_seal", "main": true, "when": "flag:met_keep,seal:oss_gallery|flag:met_keep,boss:bone_abbot", "done": "seal:henge|boss:thornwarden",
		"text": "Break the thorn seal below the western hill"},
	{"id": "thornwarden", "main": true, "when": "seal:henge", "done": "boss:thornwarden",
		"text": "Cut the Thorn Heart from the Thornwarden in the Ring"},
	{"id": "oss_seal", "main": true, "when": "flag:met_keep,seal:henge|flag:met_keep,boss:thornwarden", "done": "seal:oss_gallery|boss:bone_abbot",
		"text": "Break the gallery seal in the Ossuary, south down the Waiting Field's road"},
	{"id": "bone_abbot", "main": true, "when": "seal:oss_gallery", "done": "boss:bone_abbot",
		"text": "Take the Abbot's crown from the Bone Abbot"},
	# after both keepers: one line. The peal until four bells (the Marches' among them) are answered, then the climb, then the door.
	{"id": "peal", "main": true, "when": "boss:thornwarden,boss:bone_abbot", "done": "peal:4|boss:ascended_warden",
		"text": "The door will hear a peal, not a crown: answer four of the Founder's bells, the Marches' among them (Ardel Wick at Saltmarket has the coal for the Spire). Brannoc has the first. The rest hang in the far countries"},
	{"id": "summit_seal", "main": true, "when": "boss:thornwarden,boss:bone_abbot,peal:4", "done": "seal:summit|boss:ascended_warden",
		"text": "Carry heart and crown to the summit ward across the Crossing"},
	{"id": "warden", "main": true, "when": "boss:thornwarden,boss:bone_abbot,peal:4,seal:summit", "done": "boss:ascended_warden",
		"text": "Shut the door: face what holds it at the summit"},
	{"id": "return", "main": true, "when": "boss:ascended_warden", "done": "flag:ending_told", "who": "keep", "mark": "turnin",
		"text": "Return to the Kindled Keg"},
	{"id": "kindle", "main": false, "when": "flag:met_keep,!boss:ascended_warden", "done": "kindled:4",
		"text": "Kindle the valley's four braziers", "count": "kindled", "of": 4},
]


## The objectives to show now: [{id, text, main}], main ones first, at most `limit`.
static func active(ws: Dictionary, limit := 3) -> Array:
	var out: Array = []
	for pass_main: bool in [true, false]:
		for o: Dictionary in OBJECTIVES:
			if bool(o.main) != pass_main:
				continue
			if not test(String(o.when), ws) or test(String(o.done), ws):
				continue
			var text := String(o.text)
			if o.has("count"):
				text += "  (%d/%d)" % [int(ws.get(String(o.count), 0)), int(o.of)]
			out.append({"id": o.id, "text": text, "main": o.main})
	return out.slice(0, limit)


static func objective(id: String) -> Dictionary:
	for o: Dictionary in OBJECTIVES:
		if o.id == id:
			return o
	return {}


## Condition language: terms joined by "," (AND) or "|" (OR, binds looser than ","); "!" negates
## a term. Terms: flag:x, seal:x, boss:x, item:x, kindled:n (at least n), bosses:n (at least n
## slain), "" = always; and the task terms of quest_book.gd (q:, qat:, qd:, qp:, att:, ash:, secret:,
## secrets:), read from Travel.story.
static func test(cond: String, ws: Dictionary) -> bool:
	cond = cond.strip_edges()
	if cond == "":
		return true
	for alt in cond.split("|"):
		var ok := true
		for term in alt.split(","):
			if not _term(term.strip_edges(), ws):
				ok = false
				break
		if ok:
			return true
	return false


static func _term(t: String, ws: Dictionary) -> bool:
	if t == "":
		return true
	if t.begins_with("!"):
		return not _term(t.substr(1), ws)
	var kv := t.split(":", true, 1)
	var key := kv[0]
	var val := kv[1] if kv.size() > 1 else ""
	match key:
		"flag":
			return bool((ws.get("flags", {}) as Dictionary).get(val, false))
		"seal":
			return (ws.get("seals", {}) as Dictionary).has(val)
		"boss":
			return (ws.get("bosses", {}) as Dictionary).has(val)
		"item":
			return int((ws.get("items", {}) as Dictionary).get(val, 0)) > 0
		"kindled":
			return int(ws.get("kindled", 0)) >= int(val)
		"bosses":
			return (ws.get("bosses", {}) as Dictionary).size() >= int(val)
	var qt: Variant = QuestBook.term(key, val)
	if qt != null:
		return bool(qt)
	push_warning("QuestDB: unknown condition term '%s'" % t)
	return false


## Every term the data uses parses (the tests call this).
static func audit_cond(cond: String) -> String:
	for alt in cond.split("|"):
		for term in alt.split(","):
			var t := term.strip_edges().trim_prefix("!")
			if t == "":
				continue
			var key := t.split(":")[0]
			if not key in ["flag", "seal", "boss", "item", "kindled", "bosses"] and not key in QuestBook.TERMS:
				return "bad term '%s' in '%s'" % [term, cond]
	return ""

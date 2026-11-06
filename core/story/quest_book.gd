extends RefCounted
## Quests, attitudes and remembered choices (story; no class_name). Pure static functions over
## Travel.story (saved in its own [story] section):
##   quests {id: {"s": step, "d": done, "p": pick, "f": {found key: true}, "t": touched tick}}
##   att    {npc id: int}            how someone feels about the wanderer (-5 .. 5)
##   tick   int                      bumps on every quest change (the newest task is shown first)
##   track  {id: false}              tasks the wanderer took off the tracker (ui/quest_log.gd)
## r33 per task: "n" the current step's count (slay / collect / seal), "of" a seal's guard total,
## "rw" the gear offered at the accept screen (one is chosen at the turn-in), "day" the date a
## daily was handed in, "c" how many times it was, "left" a carried coal's seconds.
## Quest data (names, steps, rewards): quest_chains.gd. The world side (pickups, the escort, the
## hollowed man, the props that show an outcome) is quest_world.gd; the conversations drive the
## steps through `run()` actions, and test them through `term()` conditions (QuestDB.test and
## VillageState.test both ask here).
##
## Actions (comma separated, in a dialogue node's or choice's `do`):
##   qs:id          start a quest (step 0)                qa:id      next step
##   qt:id:n        set step n                            qc:id      complete (reward, toast)
##   qp:id:val      remember the choice made              att:npc:n  attitude += n (n may be -2)
##   qx:id          set an unfinished task aside (as if never begun: it can be taken up again)
##   give:item:n    put n of an item in the satchel      pay:n      take n grave ash (fails -> {"poor"})
##   grant:charm:item:n   the charm if ItemDB has it (progression's), else n of item
##   shop:who       open a merchant's shop (ui/shop.gd)   scene:x    a tavern scene (keg_scenes.gd)
## Conditions (QuestDB terms):
##   q:id  started    q:id:n  at step n or past it (or done)    qat:id:n  active and on step n
##   qd:id done       qp:id:val  that choice was made           att:npc:n  attitude >= n
##   ash:n  that much grave ash      secret:group:id / secrets:n  the secrets system's record
##   elite:id  that named elite was put down (the encounters system's record)
## Load by path: const QuestBook := preload("res://core/story/quest_book.gd")

const Chains := preload("res://core/story/quest_chains.gd")
const GearDB := preload("res://core/items/gear_db.gd")
const GearRuntime := preload("res://core/items/gear_runtime.gd")
const ASH := "grave_ash"

## Tests: no toasts.
static var quiet := false
## Tests: the day the dailies count by ("" = today's date on this machine).
static var day_override := ""


static func st() -> Dictionary:
	var s := Travel.story
	if not (s.get("quests") is Dictionary):
		s["quests"] = {}
	if not (s.get("att") is Dictionary):
		s["att"] = {}
	if not s.has("tick"):
		s["tick"] = 0
	return s


static func q(id: String) -> Dictionary:
	var qs: Dictionary = st().quests
	return qs.get(id, {}) if qs.get(id) is Dictionary else {}


static func started(id: String) -> bool:
	return not q(id).is_empty()


static func done(id: String) -> bool:
	return bool(q(id).get("d", false))


static func active(id: String) -> bool:
	return started(id) and not done(id)


## The step index (-1 = not started).
static func step(id: String) -> int:
	var d := q(id)
	return int(d.get("s", 0)) if not d.is_empty() else -1


static func pick(id: String) -> String:
	return String(q(id).get("p", ""))


static func found(id: String) -> Dictionary:
	var d := q(id)
	if d.is_empty():
		return {}
	if not (d.get("f") is Dictionary):
		d["f"] = {}
	return d.f


static func _touch(d: Dictionary) -> void:
	var s := st()
	s["tick"] = int(s.get("tick", 0)) + 1
	d["t"] = s.tick


static func _changed(id: String) -> void:
	Events.quest_changed.emit(id, step(id), done(id))
	save()


static func save() -> void:
	Travel.save_soon()


# --- moving quests on ------------------------------------------------------------------------------

static func start(id: String) -> bool:
	if not Chains.QUESTS.has(id) or (started(id) and not repeatable(id)):
		return false
	var c := int(q(id).get("c", 0))
	var d := {"s": 0, "d": false, "p": "", "f": {}, "n": 0}
	if c > 0:
		d["c"] = c
	(st().quests as Dictionary)[id] = d
	_touch(d)
	_changed(id)
	_announce(id, 0, d)                        # the banner (ui/quest_log.gd) names the task
	return true


## Go to step `to` (-1 = the next one). Past the last step the quest completes.
static func advance(id: String, to := -1) -> void:
	if not active(id):
		return
	var d := q(id)
	var n := (Chains.QUESTS[id].steps as Array).size()
	var nx := int(d.s) + 1 if to < 0 else to
	if nx >= n:
		complete(id)
		return
	if nx == int(d.s):
		return
	d["s"] = nx
	d["n"] = 0
	d.erase("left")
	_touch(d)
	_changed(id)
	_announce(id, nx, d)


## Toast the step just landed on. A world condition that is already true (the heart already cut, the
## bells already rung) is spoken in the past from the step's `past`, then the task moves on at once.
static func _announce(id: String, s: int, d: Dictionary) -> void:
	var stp := Chains.step(id, s)
	if String(stp.get("kind", "")) == "cond" and stp.has("past"):
		var cond := String(stp.get("cond", "")).split(":", true, 1)
		var met: Variant = Travel.bosses_slain.has(cond[1]) if cond[0] == "boss" and cond.size() > 1 else (term(cond[0], cond[1]) if cond.size() > 1 else null)
		if met == true:
			_toast(String(stp.past))
			advance(id, s + 1)
			return
	_toast(String(Chains.step_text(id, s, d)))


static func complete(id: String, choice := -1) -> void:
	if not active(id):
		return
	var d := q(id)
	d["d"] = true
	d["s"] = (Chains.QUESTS[id].steps as Array).size()
	d["day"] = today()
	d["c"] = int(d.get("c", 0)) + 1
	d.erase("left")
	_touch(d)
	var got := grant(Chains.QUESTS[id].get("reward", {}))
	var pieces: Array = d.get("rw", [])
	if choice >= 0 and choice < pieces.size():
		var gl := GearRuntime.store((pieces[choice] as Dictionary).duplicate(true))
		got = (got.trim_suffix(")") + ", " if got != "" else "(") + String((pieces[choice] as Dictionary).get("name", "gear")) + ")"
		if not quiet and gl != "":
			Events.toast.emit(gl)
	d.erase("rw")
	_toast("Task done: %s.%s" % [String(Chains.QUESTS[id].name), ("  " + got) if got != "" else ""])
	# r34: the last task of a raid's attunement chain loosens the boss's hold
	for boss: String in Chains.ATTUNE:
		if String(Chains.ATTUNE[boss]) == id:
			if not (Travel.story.get("flags") is Dictionary):
				Travel.story["flags"] = {}
			(Travel.story.flags as Dictionary)["attuned_" + boss] = true
			_toast(String(ATTUNE_TOAST.get(boss, "")))
	_changed(id)


## r36 Act II: how many of the Founder's bells have been answered for (rung where they lie, or their
## tongue carried to Hearthward): the bell quest's choice is made at the bell, so a picked bell counts
## before it is handed in.
static func bells() -> int:
	var n := 0
	for id: String in Chains.BELLS:
		if pick(id) != "":
			n += 1
	return n


## r36: the bells whose tongues hang at the Keg (each costs the Ascended Warden some of his hold).
static func bells_carried() -> int:
	var n := 0
	for id: String in Chains.BELLS:
		if pick(id) == "carried":
			n += 1
	return n


## r34: the raids' attunements. True once the boss's pre-raid chain is handed in (Chains.ATTUNE);
## the raid fights read it (a loosened hold: the boss agents decide what that costs it).
static func attuned(boss: String) -> bool:
	var f: Variant = Travel.story.get("flags", {})
	return f is Dictionary and bool((f as Dictionary).get("attuned_" + boss, false))


const ATTUNE_TOAST := {
	"thornwarden": "Attuned: the Thornwarden will hold back a hand in the Ring.",
	"bone_abbot": "Attuned: the Bone Abbot's count is short. He doubts.",
	"ascended_warden": "Attuned: the great bell in the Warden's hand will ring wrong.",
}


## Set an unfinished task aside: forgotten as if never begun (the giver can offer it again). A
## finished task is never dropped.
static func drop(id: String) -> void:
	if not active(id):
		return
	(st().quests as Dictionary).erase(id)
	_toast("Set aside: %s." % String(Chains.QUESTS[id].name))
	_changed(id)


static func choose(id: String, val: String) -> void:
	var d := q(id)
	if d.is_empty():
		return
	d["p"] = val
	_touch(d)
	_changed(id)


## A found thing for a gather step (name slates, clues). Returns the count found.
static func find(id: String, key: String) -> int:
	var f := found(id)
	f[key] = true
	_touch(q(id))
	_changed(id)
	return f.size()


# --- r33: offered tasks, the turn-in, dailies, counts, the tracker --------------------------------

static func today() -> String:
	return day_override if day_override != "" else Time.get_date_string_from_system()


## A daily handed in on an earlier day may be taken up again.
static func repeatable(id: String) -> bool:
	var qd: Dictionary = Chains.QUESTS.get(id, {})
	return String(qd.get("repeat", "")) == "daily" and done(id) and String(q(id).get("day", "")) != today()


## Done today (a daily waiting for tomorrow).
static func resting(id: String) -> bool:
	return String((Chains.QUESTS.get(id, {}) as Dictionary).get("repeat", "")) == "daily" and done(id) and not repeatable(id)


## Every step behind it is done: only the turn-in is left.
static func ready(id: String) -> bool:
	return active(id) and String(Chains.step(id, step(id)).get("kind", "")) == "turnin"


## Take up an offered task (the accept screen): its gear choices are rolled now and kept, so the
## turn-in hands over what the accept screen showed.
static func accept(id: String) -> bool:
	if not start(id):
		return false
	var d := q(id)
	var pieces := offered_gear(id)
	if not pieces.is_empty():
		d["rw"] = pieces
	return true


## Hand a ready task in; `choice` picks one of the offered gear (-1 when there is none).
static func turn_in(id: String, choice := -1) -> bool:
	if not ready(id):
		return false
	var pieces: Array = q(id).get("rw", offered_gear(id))
	if not pieces.is_empty():
		q(id)["rw"] = pieces
		if choice < 0 or choice >= pieces.size():
			return false
	complete(id, choice)
	return true


## The gear a task offers at its turn-in: the accepted roll, else a fresh one (same for the same
## task on the same day and round, so the accept screen and the turn-in agree).
static func offered_gear(id: String) -> Array:
	var kept: Variant = q(id).get("rw")
	if kept is Array and not (kept as Array).is_empty():
		return kept
	var opts: Array = (Chains.QUESTS.get(id, {}) as Dictionary).get("choose", [])
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [id, today(), int(q(id).get("c", 0))])
	for o: Dictionary in opts:
		out.append(GearDB.make(rng, o))
	return out


## One more for the current counted step (a kill, a drop, a seal guard). Moves the task on when
## the count is full. Returns the new count.
static func bump(id: String, by := 1, total := -1) -> int:
	if not active(id):
		return 0
	var d := q(id)
	var s := int(d.s)
	var stp := Chains.step(id, s)
	if not String(stp.get("kind", "")) in Chains.COUNTED:
		return 0
	if total >= 0:
		d["of"] = total
	d["n"] = int(d.get("n", 0)) + by
	var c := Chains.count_of(id, s, d)
	_touch(d)
	progress("%s: %d/%d" % [String(stp.get("label", Chains.QUESTS[id].name)), int(c[0]), int(c[1])], int(c[0]) >= int(c[1]))
	if int(c[0]) >= int(c[1]) and String(stp.kind) != "seal":
		advance(id)
	else:
		_changed(id)
	return int(d.n)


## The objective toast in the middle of the screen (ui/quest_log.gd), e.g. "Bone ash: 3/5".
static func progress(text: String, full := false) -> void:
	if quiet:
		return
	var tree := Engine.get_main_loop() as SceneTree
	var lg: Node = tree.get_first_node_in_group("quest_log") if tree else null
	if lg and lg.has_method("progress"):
		lg.call("progress", text, full)


static func tracked(id: String) -> bool:
	var tr: Variant = st().get("track", {})
	return not (tr is Dictionary and (tr as Dictionary).get(id, true) == false)


static func set_tracked(id: String, on: bool) -> void:
	if not (st().get("track") is Dictionary):
		st()["track"] = {}
	if on:
		(st().track as Dictionary).erase(id)
	else:
		(st().track as Dictionary)[id] = false
	_changed(id)


static func att(npc: String) -> int:
	return int((st().att as Dictionary).get(npc, 0))


const NAMES := {"hild": "Hild", "fennick": "Fennick", "oswin": "Oswin", "nan": "Nan", "col": "Col", "bet": "Bet",
	"wenna": "Wenna", "wyck": "Wyck", "abel": "Abel", "grisel": "Grisel", "keep": "The keep", "hesk": "Hesk",
	"harrow": "Ostrin", "brannoc": "Brannoc", "ruan": "Gammer Ruan", "jory": "Jory", "ysolt": "Ysolt",
	"elspeth": "Elspeth", "linnet": "Linnet", "agathe": "Sister Agathe", "cadoc": "Cadoc"}


static func add_att(npc: String, n: int) -> void:
	var a: Dictionary = st().att
	a[npc] = clampi(int(a.get(npc, 0)) + n, -5, 5)
	if absi(n) >= 2 and NAMES.has(npc):
		_toast("%s will remember that." % String(NAMES[npc]))
	save()


## A choice's label as the box shows it: one that sets a task going is marked with the task diamond.
static func label(text: String, actions: String) -> String:
	return ("◆  " + text) if actions.contains("qs:") else text


## Give a reward {ash, items: {id: n}, charm: id, else: {id: n}} (a charm only if ItemDB knows it;
## otherwise `else`). Returns a short note of what was given.
static func grant(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	var a := int(r.get("ash", 0))
	if a > 0:
		Travel.give(ASH, a, false)
		parts.append("+%d grave ash" % a)
	var items: Dictionary = (r.get("items", {}) as Dictionary).duplicate()
	var charm := String(r.get("charm", ""))
	if charm != "":
		if ItemDB.DEFS.has(charm):
			items[charm] = 1
		else:
			for k: String in r.get("else", {}):
				items[k] = int(items.get(k, 0)) + int(r["else"][k])
	for id: String in items:
		Travel.give(id, int(items[id]), false)
		var nm := String(ItemDB.def(id).get("name", id))
		parts.append(nm if int(items[id]) == 1 else "%s x%d" % [nm, int(items[id])])
	# r36: a spell the story gives (the Founder's Peal): the Kindling learns it for free
	var sp := String(r.get("spell", ""))
	if sp != "":
		var ml := Engine.get_main_loop() as SceneTree
		var kn: Node = ml.get_first_node_in_group("progression") if ml else null
		if kn and kn.has_method("gift") and bool(kn.call("gift", sp)):
			parts.append("a spell")
	return "(" + ", ".join(parts) + ")" if not parts.is_empty() else ""


static func _toast(s: String) -> void:
	if not quiet and s != "":
		Events.toast.emit(s)


# --- actions and conditions ------------------------------------------------------------------------

## Run quest actions; unknown ones are left to the caller (flag:, v:, met:, shop). Returns
## {"poor": bool (a pay: failed and stopped the rest), "shop": who, "scene": id, "rest": [actions]}.
static func run(actions: String) -> Dictionary:
	var out := {"poor": false, "shop": "", "scene": "", "rest": []}
	for a0 in actions.split(","):
		var a := a0.strip_edges()
		if a == "":
			continue
		var p := a.split(":")
		match p[0]:
			"qs":
				start(p[1])
			"qa":
				advance(p[1])
			"qt":
				advance(p[1], int(p[2]))
			"qc":
				complete(p[1])
			"qx":
				drop(p[1])
			"qp":
				choose(p[1], p[2])
			"att":
				add_att(p[1], int(p[2]))
			"give":
				var n := int(p[2]) if p.size() > 2 else 1
				Travel.give(p[1], n, false)          # the Satchel's feed shows it
			"grant":
				# grant:charm:else_item:n -- the charm if ItemDB knows it, else n of else_item
				grant({"charm": p[1], "else": {p[2]: int(p[3]) if p.size() > 3 else 1}} if p.size() > 2 else {"items": {p[1]: 1}})
			"pay":
				var cost := int(p[1])
				if Travel.count(ASH) < cost:
					out.poor = true
					return out
				Travel.items[ASH] = Travel.count(ASH) - cost
				save()
			"teach":
				# r35: teach:ward -- the story teaches a spell (kindling.gd teach)
				var ml := Engine.get_main_loop() as SceneTree
				var kn: Node = ml.get_first_node_in_group("progression") if ml else null
				if kn and kn.has_method("teach") and p.size() > 1:
					kn.call("teach", p[1])
			"shop":
				out.shop = p[1] if p.size() > 1 else "grisel"
			"scene":
				out.scene = p[1]
			_:
				(out.rest as Array).append(a)
	return out


## A quest condition term, or null when `key` is not one of ours.
static func term(key: String, val: String) -> Variant:
	var p := val.split(":")
	match key:
		"q":
			if p.size() > 1:
				return done(p[0]) or step(p[0]) >= int(p[1])
			return started(p[0])
		"qat":
			return active(p[0]) and p.size() > 1 and step(p[0]) == int(p[1])
		"qd":
			return done(p[0])
		"qp":
			return p.size() > 1 and pick(p[0]) == p[1]
		"att":
			return p.size() > 1 and att(p[0]) >= int(p[1])
		"ash":
			return Travel.count(ASH) >= int(val)
		"secret":
			var s: Variant = Travel.systems.get("secrets", {})
			if not (s is Dictionary) or p.size() < 2:
				return false
			var g: Variant = (s as Dictionary).get(p[0], {})
			return g is Dictionary and (g as Dictionary).has(p[1])
		"elite":
			# a named elite put down (encounters: Travel.systems.encounters.slain)
			var en: Variant = Travel.systems.get("encounters", {})
			var sl: Variant = (en as Dictionary).get("slain", {}) if en is Dictionary else {}
			return sl is Dictionary and (sl as Dictionary).has(val)
		"bells":
			return bells() >= int(val)
		"secrets":
			var s2: Variant = Travel.systems.get("secrets", {})
			var f: Variant = (s2 as Dictionary).get("found", {}) if s2 is Dictionary else {}
			return f is Dictionary and (f as Dictionary).size() >= int(val)
	return null


const TERMS := ["q", "qat", "qd", "qp", "att", "ash", "secret", "secrets", "elite", "bells"]


# --- the objective line -----------------------------------------------------------------------------

## Lines for the tracked active quests, newest first: [{id, text, main: false, quest: true, title,
## n, of (0 = not counted), ready (only the turn-in left)}].
static func lines(limit := 2) -> Array:
	var act: Array = []
	for id: String in Chains.ORDER:
		if active(id) and tracked(id):
			act.append(id)
	act.sort_custom(func(a: String, b: String) -> bool: return int(q(a).get("t", 0)) > int(q(b).get("t", 0)))
	var out: Array = []
	for id: String in act.slice(0, limit):
		var c := Chains.count_of(id, step(id), q(id))
		out.append({"id": "quest:" + id, "text": Chains.step_text(id, step(id), q(id)), "main": false, "quest": true,
			"title": String(Chains.QUESTS[id].name), "n": int(c[0]), "of": int(c[1]), "ready": ready(id)})
	return out

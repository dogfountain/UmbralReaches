extends Node3D
## The world side of the task verbs that live on the ground (story; no class_name; docs/QUEST_VERBS.md). A child of
## quest_world.gd (group "quest_verbs"). From the tasks' state it keeps these things standing:
##   clues   one thing to examine at each clue spot of the current `clues` step (examined ones keep their line and
##           lose their glint); the last wanted one moves the task on. What was found is saved in the task as
##           "c:<key>" (quest_book.gd find; the condition qc:<task>:<key> reads it).
##   tracks  only the NEXT mark of a `tracks` step: a glint (and a prop if the mark has one). Coming within
##           VerbKit.MARK_R of it reads it out and reveals the one after; the last ends the step.
##   order   the things of an `order` step to touch. A touch in the right place counts ("o" in the task), a wrong
##           one starts the order again and wakes `wrong_spawns` foes round the thing; the whole order moves the
##           task on. The order itself is never shown.
##   leaves  what a finished task leaves standing for the way it ended (quest data `leaves`: {pick or "": {at, prop}}).
## Spots are floor points found at load (prepare()), so nothing is searched or built beyond the nodes of the one
## step under way. One 4 Hz distance check, and only while a trail is under way: no scans of the tree.
## Load by path: const VerbWorld := preload("res://core/story/verb_world.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QProps := preload("res://core/story/quest_props.gd")
const Pickup := preload("res://core/story/quest_pickup.gd")
const VerbKit := preload("res://core/story/verb_kit.gd")
const Kit := preload("res://core/story/encounter_kit.gd")

## "task:step:key" (a clue / a thing), "task:step:m<i>" (a mark), "leave:task" -> floor point.
static var spots := {}

var _nodes := {}                  ## spot key -> node standing now
var _ids: Array[String] = []      ## the tasks that have a verb step or leave something
var _track: Array = []            ## [[task, step, mark index, Vector3], ...] trails under way
var _foes: Array[Enemy] = []      ## what a wrong touch woke
var _t := 0.0


# --- before the people spawn ------------------------------------------------------------------------

## Find a floor for every clue, thing, mark and left prop. `finder`: Callable(near: Vector2, r: float) -> Vector3
## (Vector3.INF when there is none: the spot then stands on the designed land, as pickups do).
static func prepare(finder: Callable) -> void:
	spots.clear()
	for id: String in Chains.ORDER:
		var qd: Dictionary = Chains.QUESTS[id]
		var steps: Array = qd.steps
		for si in steps.size():
			var stp: Dictionary = steps[si]
			match String(stp.get("kind", "")):
				"clues":
					for c: Dictionary in stp.clues:
						_put("%s:%d:%s" % [id, si, c.key], c.at, finder)
				"tracks":
					for i in (stp.marks as Array).size():
						_put("%s:%d:m%d" % [id, si, i], (stp.marks[i] as Dictionary).at, finder)
				"order":
					for t: Dictionary in stp.things:
						_put("%s:%d:%s" % [id, si, t.key], t.at, finder)
		for pick: String in (qd.get("leaves", {}) as Dictionary):
			_put("leave:%s:%s" % [id, pick], qd.leaves[pick].at, finder)


static func _put(key: String, near: Vector2, finder: Callable) -> void:
	var p: Vector3 = finder.call(near, 0.3)
	if p == Vector3.INF:
		p = Vector3(near.x, RealmLayout.macro_height(near.x, near.y), near.y)
	spots[key] = p


## The saved line of a verb's task, for the tests: which clue keys the step wants.
static func clue_keys(id: String, si: int) -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in Chains.step(id, si).get("clues", []):
		out.append(String(c.key))
	return out


# --- runtime -----------------------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("quest_verbs")
	for id: String in Chains.ORDER:
		var qd: Dictionary = Chains.QUESTS[id]
		var any := qd.has("leaves")
		for stp: Dictionary in qd.steps:
			any = any or VerbKit.is_verb(String(stp.get("kind", "")))
		if any:
			_ids.append(id)
	set_process(false)
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: sync.call_deferred())
	sync()


func _exit_tree() -> void:
	Kit.clear_foes(_foes)


## Bring the world in line with the tasks' state (the quest-changed signal calls it; so do the tests).
func sync() -> void:
	if not is_inside_tree():
		return
	var want := {}                  ## spot key -> [kind, data...]
	_track.clear()
	var order_live := false
	for id: String in _ids:
		var qd: Dictionary = Chains.QUESTS[id]
		if Book.active(id):
			var si := Book.step(id)
			var stp := Chains.step(id, si)
			match String(stp.get("kind", "")):
				"clues":
					for c: Dictionary in stp.clues:
						want["%s:%d:%s" % [id, si, c.key]] = ["clue", c, Book.found(id).has(VerbKit.clue_key(String(c.key)))]
				"tracks":
					var i := Book.noted(id, "n")
					if i < (stp.marks as Array).size():
						var mk := "%s:%d:m%d" % [id, si, i]
						want[mk] = ["mark", stp.marks[i], false]
						_track.append([id, si, i, _spot(mk)])
				"order":
					order_live = true
					var o := Book.noted(id, "o")
					for t: Dictionary in stp.things:
						# lit while it is one of the places already touched in the right order
						var lit := false
						for j in mini(o, (stp.order as Array).size()):
							lit = lit or String(stp.order[j]) == String(t.key)
						want["%s:%d:%s" % [id, si, t.key]] = ["thing", t, lit]
		if Book.done(id) and qd.has("leaves"):
			var lv: Dictionary = qd.leaves
			var pick := Book.pick(id)
			if lv.has(pick) or lv.has(""):
				var k := pick if lv.has(pick) else ""
				want["leave:%s:%s" % [id, k]] = ["leave", lv[k], false]
				for extra: String in lv:             # "<pick>+1", "<pick>+2" ...: a pick may leave a string of lights (the Lamp-Road's posts)
					if extra.begins_with(k + "+"):
						want["leave:%s:%s" % [id, extra]] = ["leave", lv[extra], false]
	if not order_live:
		Kit.clear_foes(_foes)
	for k: String in _nodes.keys():
		if not want.has(k) or String((_nodes[k] as Node).get_meta("lit", "")) != str(want[k][2]):
			(_nodes[k] as Node).queue_free()
			_nodes.erase(k)
	for k2: String in want:
		if not _nodes.has(k2):
			_add(k2, want[k2])
	set_process(not _track.is_empty())


func _spot(key: String) -> Vector3:
	return spots.get(key, Vector3.INF)


func _add(key: String, w: Array) -> void:
	var at := _spot(key)
	if at == Vector3.INF:
		return
	var d: Dictionary = w[1]
	var kind := String(w[0])
	var holder: Node3D
	if kind in ["clue", "thing"]:
		var p: Pickup = Pickup.new()
		p.key = key
		p.world = self
		p.label = String(d.get("name", "a sign" if kind == "clue" else "a post"))
		p.verb = String(d.get("verb", "Look at" if kind == "clue" else "Touch"))
		holder = p
	else:
		holder = Node3D.new()
	holder.name = "%s_%s" % [kind.capitalize(), key.replace(":", "_")]
	add_child(holder)
	holder.global_position = at
	var prop := String(d.get("prop", ""))
	if prop != "":
		QProps.make(holder, "Look", prop, Transform3D(Basis(Vector3.UP, float(hash(key) % 628) * 0.01), at))
	if kind != "leave" and not bool(w[2]):
		QProps.glint(holder, true)
	holder.set_meta("lit", str(w[2]))
	_nodes[key] = holder


## The wanderer used a clue or a thing.
func take(key: String) -> void:
	var p := key.split(":")
	if p.size() < 3 or not Book.active(p[0]) or Book.step(p[0]) != int(p[1]):
		return
	var stp := Chains.step(p[0], int(p[1]))
	match String(stp.get("kind", "")):
		"clues":
			examine(p[0], p[2])
		"order":
			touch(p[0], p[2])


## Examine a clue of the task's current step: its line is read out, and the first time it is remembered
## (qc:<task>:<key>); the last one wanted moves the task on. Returns false when there is no such clue now.
func examine(qid: String, key: String) -> bool:
	var stp := Chains.step(qid, Book.step(qid))
	var clue := _pick(stp.get("clues", []), key)
	if clue.is_empty():
		return false
	_narrate(String(clue.text))
	if Book.found(qid).has(VerbKit.clue_key(key)):
		return true
	Book.find(qid, VerbKit.clue_key(key))
	var c := VerbKit.clue_count(stp, Book.q(qid))
	Book.progress("%s: %d/%d" % [String(stp.get("label", Chains.QUESTS[qid].name)), int(c[0]), int(c[1])], int(c[0]) >= int(c[1]))
	if int(c[0]) >= int(c[1]):
		Book.advance(qid)
	return true


## Touch a thing of the task's current `order` step. Right: it counts. Wrong: the order starts again and the
## step's `wrong_spawns` ({kind, n}) wake near the thing. All of it right: the task moves on. Returns true when right.
func touch(qid: String, key: String) -> bool:
	var si := Book.step(qid)
	var stp := Chains.step(qid, si)
	var thing := _pick(stp.get("things", []), key)
	var order: Array = stp.get("order", [])
	var o := Book.noted(qid, "o")
	if thing.is_empty() or order.is_empty():
		return false
	if o < order.size() and String(order[o]) == key:
		_narrate(String(thing.get("text", "")))
		if o + 1 >= order.size():
			Book.progress(String(stp.get("done", "It is done.")), true)
			Book.advance(qid)
		else:
			Book.note(qid, "o", o + 1)
		return true
	if o > 0:
		Book.note(qid, "o", 0)
	_narrate(String(stp.get("wrong", "Nothing answers. That was not the way.")))
	_wake(qid, stp, key)
	return false


func _wake(qid: String, stp: Dictionary, key: String) -> void:
	var ws: Dictionary = stp.get("wrong_spawns", {})
	if ws.is_empty():
		return
	Kit.prune(_foes)
	var at := _spot("%s:%d:%s" % [qid, Book.step(qid), key])
	var n := int(ws.get("n", 1))
	var a0 := randf() * TAU
	for i in n:
		if _foes.size() >= 6:
			break
		var a := a0 + TAU * float(i) / float(maxi(n, 1))
		var x := at.x + cos(a) * 6.0
		var z := at.z + sin(a) * 6.0
		var e := Kit.spawn_foe(self, String(ws.get("kind", "wretch")), Vector3(x, Kit.ground_y(self, x, z), z), qid)
		if e:
			_foes.append(e)


func _pick(list: Array, key: String) -> Dictionary:
	for e: Dictionary in list:
		if String(e.get("key", "")) == key:
			return e
	return {}


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	var pl := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	if pl == null:
		return
	for e: Array in _track:
		var at: Vector3 = e[3]
		if Vector2(pl.global_position.x - at.x, pl.global_position.z - at.z).length() < VerbKit.MARK_R:
			_reveal(String(e[0]), int(e[2]))
			return


## A trail's next mark was found: read out, and the one after is revealed (the last ends the step).
func _reveal(qid: String, i: int) -> void:
	var stp := Chains.step(qid, Book.step(qid))
	var marks: Array = stp.get("marks", [])
	if not Book.active(qid) or Book.noted(qid, "n") != i or i >= marks.size():
		return
	_narrate(String((marks[i] as Dictionary).text))
	Book.progress("%s: %d/%d" % [String(stp.get("label", Chains.QUESTS[qid].name)), i + 1, marks.size()], i + 1 >= marks.size())
	if i + 1 >= marks.size():
		Book.advance(qid)
	else:
		Book.note(qid, "n", i + 1)


func _narrate(s: String) -> void:
	if s == "":
		return
	var story := get_tree().get_first_node_in_group("story")
	var ui: Variant = story.get("ui") if story else null
	if ui is Object and is_instance_valid(ui as Object):
		Callable(ui as Object, "narrate").call([s])


## For the tests: what stands now.
func info() -> Dictionary:
	return {"nodes": _nodes.keys(), "track": _track.size(), "foes": _foes.size()}

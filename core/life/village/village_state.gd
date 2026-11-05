extends RefCounted
## The village's memory (village system; no class_name). Everything lives in
## Travel.system_state("village") (saved in the [systems] section of the save):
##   {"v": 1, "restored": {id: true}, "flags": {id: true}, "met": {villager: true},
##    "announced": {id: true}, "spent": int (grave ash given to the ash-wife)}
## `refresh()` checks VillageCast.RESTORE against the world (Travel progress, the story's flags,
## lit braziers, the village's own flags) and records what came true. A restoration never undoes:
## once the Wrights are home they stay home, even if a test or a new game clears progress in memory.
## Conditions: QuestDB terms + v:x, met:x, ash:n, hollows:n (see village_cast.gd).
## Load by path: const VillageState := preload("res://core/life/village/village_state.gd")

const Cast := preload("res://core/life/village/village_cast.gd")
const QuestDB := preload("res://core/story/quest_db.gd")
const ID := "village"
const ASH := "grave_ash"

## Test hook: a dictionary used instead of Travel.system_state("village") (never saved).
static var sandbox: Variant = null
## Test hook: the brazier count to use instead of asking the story director / the scene.
static var kindled_override := -1


static func data() -> Dictionary:
	var d: Dictionary = sandbox if sandbox is Dictionary else Travel.system_state(ID)
	for key: String in ["restored", "flags", "met", "announced"]:
		if not d.has(key) or not (d[key] is Dictionary):
			d[key] = {}
	if not d.has("v"):
		d["v"] = 1
	if not d.has("spent"):
		d["spent"] = 0
	return d


static func save() -> void:
	if sandbox is Dictionary:
		return
	Travel.save_soon()


static func restored(id: String) -> bool:
	return bool((data().restored as Dictionary).get(id, false))


static func flag(id: String) -> bool:
	var d := data()
	return bool((d.flags as Dictionary).get(id, false)) or bool((d.restored as Dictionary).get(id, false))


static func set_flag(id: String, on := true) -> void:
	var f: Dictionary = data().flags
	if on:
		f[id] = true
	else:
		f.erase(id)
	save()


static func met(id: String) -> bool:
	return bool((data().met as Dictionary).get(id, false))


static func set_met(id: String) -> void:
	(data().met as Dictionary)[id] = true
	save()


# --- the world ----------------------------------------------------------------------------------

static func kindled(tree: SceneTree) -> int:
	if kindled_override >= 0:
		return kindled_override
	if tree == null:
		return 0
	var story := tree.get_first_node_in_group("story")
	if story and story.has_method("kindled"):
		return int(story.call("kindled"))
	var scene := tree.current_scene
	var n := 0
	if scene:
		var saved: PackedStringArray = Travel.lit_by_path.get(scene.scene_file_path, PackedStringArray())
		for b: String in QuestDB.BRAZIERS:
			var node := scene.get_node_or_null("Zone/Braziers/" + b)
			if (node and bool(node.get("lit"))) or b in saved:
				n += 1
	return n


static func world(tree: SceneTree) -> Dictionary:
	var flags: Dictionary = Travel.story.get("flags", {}) if Travel.story.get("flags", {}) is Dictionary else {}
	return {"flags": flags, "kindled": kindled(tree), "seals": Travel.seals_broken, "bosses": Travel.bosses_slain,
		"items": Travel.items}


static func ash() -> int:
	return Travel.count(ASH)


## Times the wanderer has come back from the fire (the player's hollow count).
static func hollows(tree: SceneTree) -> int:
	if tree:
		var p := tree.get_first_node_in_group(Groups.PLAYER)
		if p and "hollow_count" in p:
			return int(p.get("hollow_count"))
	return Travel.saved_hollows


## Condition test: QuestDB's language plus v:x, met:x, ash:n, hollows:n.
static func test(cond: String, ws: Dictionary, tree: SceneTree = null) -> bool:
	cond = cond.strip_edges()
	if cond == "":
		return true
	for alt in cond.split("|"):
		var ok := true
		for term in alt.split(","):
			if not _term(term.strip_edges(), ws, tree):
				ok = false
				break
		if ok:
			return true
	return false


static func _term(t: String, ws: Dictionary, tree: SceneTree) -> bool:
	if t == "":
		return true
	if t.begins_with("!"):
		return not _term(t.substr(1), ws, tree)
	var kv := t.split(":", true, 1)
	var key := kv[0]
	var val := kv[1] if kv.size() > 1 else ""
	match key:
		"v":
			return flag(val)
		"met":
			return met(val)
		"ash":
			return ash() >= int(val)
		"hollows":
			return hollows(tree) >= int(val)
	return QuestDB.test(t, ws)


static func audit_cond(cond: String) -> String:
	for alt in cond.split("|"):
		for term in alt.split(","):
			var t := term.strip_edges().trim_prefix("!")
			if t == "":
				continue
			var key := t.split(":")[0]
			if not key in ["flag", "seal", "boss", "item", "kindled", "bosses", "v", "met", "ash", "hollows"] and not key in QuestDB.QuestBook.TERMS:
				return "bad term '%s' in '%s'" % [term, cond]
	return ""


## Record every restoration whose condition now holds. Returns the ids that came true just now.
static func refresh(tree: SceneTree) -> Array[String]:
	var ws := world(tree)
	var d := data()
	var fresh: Array[String] = []
	# restorations can depend on each other (the Harrows' roof needs its frame): settle in passes
	for _pass in 3:
		var changed := false
		for r: Dictionary in Cast.RESTORE:
			var id := String(r.id)
			if (d.restored as Dictionary).has(id):
				continue
			if test(String(r.when), ws, tree):
				(d.restored as Dictionary)[id] = true
				fresh.append(id)
				changed = true
		if not changed:
			break
	if not fresh.is_empty():
		save()
	return fresh


## Lamps on the lamplighter's round now (ids, in round order).
static func lamps() -> Array[String]:
	var sets := {"A": true, "B": restored("lamps_more"), "C": restored("lamps_all")}
	var out: Array[String] = []
	for l: Dictionary in Cast.LAMPS:
		if bool(sets.get(String(l.set), false)):
			out.append(String(l.id))
	return out


## Spend ash with the ash-wife. false (and nothing taken) if the satchel holds too little.
static func pay(n: int) -> bool:
	if ash() < n:
		return false
	Travel.items[ASH] = ash() - n
	data()["spent"] = int(data().get("spent", 0)) + n
	if not (sandbox is Dictionary):
		Travel.save_soon()
	return true

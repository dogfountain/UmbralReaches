extends Node
## Moves the r33 tasks on from what happens in the world (story; no class_name). One per night,
## added by the story director (story.gd) as "QuestRunner", group "quest_runner". Data:
## quest_chains.gd step kinds; state: quest_book.gd.
##   slay / collect   Events.enemy_killed: a foe of the step's `kinds`, in its `region`, counts
##                    (collect: with the step's `chance`); the count toast comes from QuestBook.bump
##   seal             Events.seal_progress counts the guards, Events.seal_broken (or a seal already
##                    broken) ends the step
##   cond / visit     checked at 4 Hz: a world condition (a boss down) / the wanderer within `r`
##   carry            a coal from the step before: `time` seconds to bring it within `r` of `to`;
##                    run out, or come back hollowed, and it goes out (the task falls back a step)
## No per-frame scans: one pass over ORDER (18 tasks) four times a second.
## Load by path: const QuestRunner := preload("res://core/story/quest_runner.gd")

const Book := preload("res://core/story/quest_book.gd")
const Chains := preload("res://core/story/quest_chains.gd")
const QuestDB := preload("res://core/story/quest_db.gd")

## Tests: every collect step drops (1.0), or the data's chance (-1).
static var chance_override := -1.0

var _tick := 0.0
var _carrying := ""               ## the task whose coal is burning down (found by check())
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("quest_runner")
	_rng.randomize()
	Events.enemy_killed.connect(_on_killed)
	Events.seal_progress.connect(_on_seal_progress)
	Events.seal_broken.connect(func(_id: String) -> void: check())
	Events.boss_slain.connect(func(_id: String) -> void: check())
	Events.hollowed.connect(_on_hollowed)
	Events.quest_changed.connect(func(_id: String, _s: int, _d: bool) -> void: _tick = minf(_tick, 0.05))


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


## The foe's kind: its script's file name ("wretch", "tollman", ...).
static func kind_of(e: Node) -> String:
	var s: Script = e.get_script() if e else null
	return s.resource_path.get_file().get_basename() if s else ""


## Is xz inside region `id` (RealmLayout.REGIONS: its own ground, not the blend's edge)?
static func in_region(id: String, x: float, z: float) -> bool:
	if id == "":
		return true
	for r: Dictionary in RealmLayout.REGIONS:
		if String(r.id) == id:
			return RealmLayout.place_weight(r, x, z) > 0.5
	return false


## Does a kill of `kind` at `xz` count for step `stp`?
static func counts(stp: Dictionary, kind: String, xz: Vector2) -> bool:
	var kinds: Array = stp.get("kinds", [])
	if not kinds.is_empty() and not kind in kinds:
		return false
	return in_region(String(stp.get("region", "")), xz.x, xz.y)


func _on_killed(e: Node) -> void:
	if e == null or not (e is Node3D) or e.has_meta(&"boss_id") or e.has_meta("quest"):
		return
	var kind := kind_of(e)
	var p := (e as Node3D).global_position
	note_kill(kind, Vector2(p.x, p.z))


## A foe of `kind` fell at `xz`: every slay / collect step that wants it counts (tests call this).
func note_kill(kind: String, xz: Vector2) -> void:
	for id: String in Chains.ORDER:
		if not Book.active(id):
			continue
		var stp := Chains.step(id, Book.step(id))
		var k := String(stp.get("kind", ""))
		if not k in ["slay", "collect"] or not counts(stp, kind, xz):
			continue
		if k == "collect":
			var ch := chance_override if chance_override >= 0.0 else float(stp.get("chance", 1.0))
			if _rng.randf() >= ch:
				continue
		Book.bump(id)


func _on_seal_progress(sid: String, cleared: int, total: int) -> void:
	for id: String in Chains.ORDER:
		if not Book.active(id):
			continue
		var stp := Chains.step(id, Book.step(id))
		if String(stp.get("kind", "")) == "seal" and String(stp.get("seal", "")) == sid:
			var have := int(Book.q(id).get("n", 0))
			if cleared > have:
				Book.bump(id, cleared - have, total)


func _on_hollowed() -> void:
	for id: String in Chains.ORDER:
		if Book.active(id) and String(Chains.step(id, Book.step(id)).get("kind", "")) == "carry":
			_gutter(id, "The coal went out with you.")


func _gutter(id: String, why: String) -> void:
	Book._toast(why)
	Book.advance(id, Book.step(id) - 1)


func _process(delta: float) -> void:
	# the carried coal burns down in real seconds (the world pauses with menus, and so does this)
	if _carrying != "":
		var id := _carrying
		var stp := Chains.step(id, Book.step(id))
		if Book.active(id) and String(stp.get("kind", "")) == "carry":
			var d := Book.q(id)
			var left := float(d.get("left", float(stp.get("time", 60.0)))) - delta
			d["left"] = left
			if left <= 0.0:
				_carrying = ""
				_gutter(id, "The coal has gone out. Fetch another from the green's fire.")
		else:
			_carrying = ""
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	check()


## One pass: steps the world has already answered move on.
func check() -> void:
	var ws: Dictionary = {}
	var pl := _player()
	for id: String in Chains.ORDER:
		if not Book.active(id):
			continue
		var stp := Chains.step(id, Book.step(id))
		match String(stp.get("kind", "")):
			"cond":
				if ws.is_empty():
					ws = _world()
				if QuestDB.test(String(stp.get("cond", "")), ws):
					Book.advance(id)
			"seal":
				var sid := String(stp.get("seal", ""))
				var d := Book.q(id)
				if int(d.get("of", 0)) <= 0:
					var tot := EnemySpawner.seal_total(sid)
					if tot > 0:
						d["of"] = tot
						# guards put down before the task was taken count too
						var kills: Variant = EnemySpawner._seal_kills.get(sid, {})
						d["n"] = maxi(int(d.get("n", 0)), (kills as Dictionary).size() if kills is Dictionary else 0)
				if Travel.seals_broken.has(sid):
					d["n"] = maxi(int(d.get("of", 1)), 1)
					Book.advance(id)
			"visit":
				if pl and _near(pl, stp.at as Vector2, float(stp.get("r", 8.0))):
					Book.progress("%s: discovered" % String(stp.get("label", "")), true)
					Book.advance(id)
			"carry":
				_carrying = id
				if pl and _near(pl, stp.to as Vector2, float(stp.get("r", 5.0))):
					Book.progress("%s: delivered" % String(stp.get("label", "")), true)
					Book.advance(id)


func _near(pl: Node3D, at: Vector2, r: float) -> bool:
	return Vector2(pl.global_position.x - at.x, pl.global_position.z - at.y).length() < r


func _world() -> Dictionary:
	var story := get_tree().get_first_node_in_group("story")
	if story and story.has_method("world"):
		return story.call("world")
	return {"flags": Travel.story.get("flags", {}), "kindled": 0, "seals": Travel.seals_broken,
		"bosses": Travel.bosses_slain, "items": Travel.items}

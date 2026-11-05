extends Node
## r36 Act II: renders of the Founder's seven bells where they stand, each with its keeper (windowed,
## the real night). A free camera 7 m off each bell, looking at it.
##   HOME=<scratch> godot --path . res://zz/bells_shots.tscn -- --out=<dir>
## -> <dir>/bell_<region>.png, and a BELLS line per bell: where the pickup and its keeper stand.
## Holds Travel._busy (no save); quits itself.

const Chains := preload("res://core/story/quest_chains.gd")
const Book := preload("res://core/story/quest_book.gd")

var main: Node
var out := "res://shots"
var _ran := false
var t := 0.0


func _init() -> void:
	Engine.set_meta(&"full_night", true)   # the 30-minute slice hides horses, watch, roaming events, dailies, attunements


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 240.0:
		get_tree().quit(1)
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done"):
		_ran = true
		_run()


func _run() -> void:
	await _frames(30)
	Book.start("founders_peal")
	for id: String in Chains.BELLS:
		Book.start(id)
		Book.advance(id)                    # past the keeper: the bell waits
	await _frames(10)
	var qw := get_tree().get_first_node_in_group("quests")
	if qw == null:
		for n in get_tree().root.find_children("*", "", true, false):
			if n.get_script() != null and String((n.get_script() as Script).resource_path).ends_with("quest_world.gd"):
				qw = n
				break
	var cam := Camera3D.new()
	cam.fov = 60.0
	get_tree().root.add_child(cam)
	for i in Chains.BELLS.size():
		var id := String(Chains.BELLS[i])
		var key := Chains.gather_keys(id, 1)[0]
		var p: Node3D = (qw.get("pickups") as Dictionary).get(key) if qw else null
		var keeper := String(Chains.BELL_KEEPERS[i])
		var kn: Node3D = null
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if (e as Node).get_meta("rare_id", "") == keeper:
				kn = e as Node3D
		if p == null:
			print("BELLS %s: NO PICKUP" % id)
			continue
		var at := p.global_position
		print("BELLS %s at %s, keeper %s at %s" % [id, at, keeper, kn.global_position if kn else "(not spawned)"])
		var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
		if player:
			player.global_position = at + Vector3(5.0, 0.5, 5.0)
		cam.global_position = at + Vector3(5.0, 2.6, 5.0)
		cam.look_at(at + Vector3.UP * 0.9, Vector3.UP)
		cam.make_current()
		await _frames(20)
		var img := get_viewport().get_texture().get_image()
		var path := "%s/bell_%s.png" % [out, id.trim_prefix("bell_")]
		img.save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

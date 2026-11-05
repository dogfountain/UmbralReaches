extends Node
## r36 renders (windowed, the real night): a watch-post with its watchmen in an assault, the wanderer
## on horseback, each breed at its hitching rail, and a rung bell standing lit.
##   HOME=<scratch> godot --path . res://zz/r36_shots.tscn -- --out=<dir>
## -> <dir>/r36_<name>.png. Never writes the save (Travel._busy); quits itself.

const Book := preload("res://core/story/quest_book.gd")

var main: Node
var out := "res://shots"
var _ran := false
var ride_view := "side"
var t := 0.0
var cam: Camera3D


func _init() -> void:
	Engine.set_meta(&"full_night", true)   # the 30-minute slice hides horses, watch, roaming events, dailies, attunements


func _ready() -> void:
	Travel._busy = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ride-view="):
			ride_view = a.trim_prefix("--ride-view=")
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	main = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	Travel._busy = true
	t += d
	if t > 300.0:
		get_tree().quit(1)
	if not _ran and is_instance_valid(main) and main.has_meta("realm_done") and main.get_node_or_null("Stables") != null:
		_ran = true
		_run()


func _run() -> void:
	await _frames(60)
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Player
	cam = Camera3D.new()
	cam.fov = 55.0
	get_tree().root.add_child(cam)
	# a watch-post under assault
	var w: Node3D = get_tree().get_nodes_in_group(&"watch_post")[0]
	var face: Vector3 = w.get("face")
	p.teleport(w.global_position - face * 9.0 + Vector3.UP * 0.5)
	await _wait(1.5)
	w.set("_next", 0.0)
	await _wait(5.0)
	var side := face.cross(Vector3.UP).normalized()
	await _shot("watch", w.global_position + face * 1.0 + side * 7.0 + Vector3.UP * 3.0, w.global_position + face * 4.0 + Vector3.UP * 0.8)
	for e in w.get("_wave"):
		if is_instance_valid(e):
			(e as Enemy).take_hit(999.0, null)
	# each breed at its rail
	for h: Node3D in get_tree().get_nodes_in_group(&"horse"):
		p.teleport(h.global_position + Vector3(4.0, 0.5, 4.0))
		await _wait(0.8)
		var hb := h.global_basis
		await _shot("horse_" + String(h.get("breed")), h.global_position + hb.x * 4.5 + hb.z * 1.5 + Vector3.UP * 1.8, h.global_position + Vector3.UP * 1.2)
	# on horseback, at a gallop on the meadow
	var hs: Node3D = get_tree().get_nodes_in_group(&"horse")[0]
	Travel.items["grave_ash"] = 300
	p.teleport(hs.global_position + Vector3(1.5, 0.5, 0.0))
	await _wait(0.3)
	hs.call("interact", p)
	hs.call("interact", p)
	var sp := hs.get_world_3d().direct_space_state
	var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-40.0, 60.0, 20.0), Vector3(-40.0, -40.0, 20.0), Layers.WORLD))
	if not hit.is_empty():
		hs.global_position = hit.position
	p.set("_debug_drive", true)
	p.set("_debug_wish", -hs.global_basis.z)
	p.set("_debug_sprint", true)
	await _wait(1.6)
	p.set("_debug_drive", false)
	p.set("_debug_wish", Vector3.ZERO)
	await _wait(1.2)                      # let it come to a stand for a clear look
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false          # the HUD off: a clean look at the rider
	var hb2 := hs.global_basis
	# one view a run (a second camera move in the same run rendered the first frame again)
	var views := {"side": [hb2.x * 3.6 + Vector3.UP * 1.9, Vector3.UP * 1.5], "front": [-hb2.z * 4.5 + hb2.x * 1.5 + Vector3.UP * 3.0, Vector3.UP * 1.6],
		"high": [hb2.x * 2.6 + hb2.z * 1.0 + Vector3.UP * 3.6, Vector3.UP * 1.5], "back": [hb2.z * 4.0 + hb2.x * 1.2 + Vector3.UP * 2.6, Vector3.UP * 1.6]}
	var vv: Array = views.get(ride_view, views["side"])
	await _shot("riding_" + ride_view, hs.global_position + (vv[0] as Vector3), hs.global_position + (vv[1] as Vector3))


	# a rung bell, lit
	Book.start("bell_orchard")
	Book.choose("bell_orchard", "rung")
	var rs := main.get_node_or_null("ReachState")
	if rs:
		rs.call("refresh")
	await _wait(0.5)
	var bell := main.get_node_or_null("RungBell_bell_orchard") as Node3D
	if bell:
		hs.call("dismount")
		p.teleport(bell.global_position + Vector3(4.0, 0.5, 4.0))
		await _wait(1.0)
		await _shot("rung_bell", bell.global_position + Vector3(3.5, 2.0, 3.5), bell.global_position + Vector3.UP * 1.0)
	get_tree().quit(0)


func _shot(nm: String, from: Vector3, at: Vector3) -> void:
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if c != cam:
			(c as Camera3D).current = false
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.make_current()
	await _frames(12)
	var img := get_viewport().get_texture().get_image()
	var path := "%s/r36_%s.png" % [out, nm]
	img.save_png(path if path.begins_with("/") else ProjectSettings.globalize_path(path))
	print("R36SHOT ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

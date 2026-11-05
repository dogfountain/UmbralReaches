extends Node
## Renders for the tasks, the shop and the Keg's scenes (windowed, real world):
##   HOME=<scratch>/home godot --path . res://zz/quest_shot.tscn -- --phase=before|after
## before: a fresh save (the keep met, no tasks). after: the five tasks finished (tongs back on the
## stone, names in the Yard, the mug by the fire, the lantern lit on the bar, Oswin's vigil), plus
## the shop, the ledger and a task conversation. -> shots/agentE_<what>_<phase>.png
## Never writes the save (Travel._busy, the village in a sandbox) and exits with OS.kill.

const Book := preload("res://core/story/quest_book.gd")
const QWorld := preload("res://core/story/quest_world.gd")
const VState := preload("res://core/life/village/village_state.gd")

var phase := "after"
var cam: Camera3D
var village: Node3D
var story: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			phase = a.trim_prefix("--phase=")
	get_window().size = Vector2i(1600, 1000)
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true, "met_harrow": true, "met_hesk": true, "met_brannoc": true}, "picked": {}}
	Travel.items = {"grave_ash": 46}
	VState.sandbox = {"met": {"hild": true, "grisel": true, "oswin": true, "abel": true, "nan": true}}
	if phase == "after":
		var qs := {}
		for id: String in ["edda_tongs", "names_yard", "keg_thief", "slow_way", "forty_first"]:
			qs[id] = {"s": 9, "d": true, "p": "", "f": {}, "t": 1}
		qs.edda_tongs.p = "stone"
		qs.keg_thief.p = "covered"
		qs.slow_way.p = "truth"
		qs.forty_first.p = "faith"
		Travel.story["quests"] = qs
		Travel.story["att"] = {"hild": 2, "abel": 3, "nan": 3, "harrow": 2, "keep": 1}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://shots/agentE_%s_%s.png" % [what, phase])
	get_viewport().get_texture().get_image().save_png(path)
	print("QUEST_SHOT ", path)


func _ui(on: bool) -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if cl.name in ["Dialogue", "Shop", "QuestLog"]:
			continue
		cl.visible = on


func _free_cam(at: Vector3, look: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 58.0
		cam.far = 400.0
		get_tree().root.add_child(cam)
	cam.current = true
	cam.global_position = at
	cam.look_at(look)


func _g(x: float, z: float) -> float:
	return RealmLayout.ground(village.get_world_3d().direct_space_state, x, z)


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		village = get_tree().root.find_child("Village", true, false) as Node3D
		if village and village.has_meta("village_done"):
			break
		if Time.get_ticks_msec() - t0 > 180000:
			print("QUEST_SHOT no village")
			_quit()
			return
	story = get_tree().get_first_node_in_group("story")
	await _wait(6.0)
	for e in get_tree().get_nodes_in_group(Groups.ENEMY):
		(e as Node).queue_free()
	village.set("time_scale", 0.0)
	# --- the world --------------------------------------------------------------------------------
	_ui(false)
	var ty: Vector3 = QWorld.spots.get("tongs", Vector3(-84.3, _g(-84.3, 44.2), 44.2))
	_free_cam(ty + Vector3(3.6, 1.5, -2.6), ty + Vector3(1.0, 0.2, 0.4))
	await _wait(1.2)
	await _shot("yard")
	_free_cam(ty + Vector3(0.7, 0.75, -0.9), ty + Vector3(0.0, 0.05, 0.0))
	await _wait(0.5)
	await _shot("tongs")
	var sp: Vector3 = QWorld.spots.get("stair", Vector3(-3.2, _g(-3.2, 2.6), 2.6))
	var wsp: Vector3 = QWorld.spots.get("waystone", sp + Vector3(-0.7, 0, -1.3))
	var away := (wsp - sp)
	away.y = 0.0
	away = away.normalized()
	_free_cam(wsp + away * 1.6 + away.cross(Vector3.UP) * 1.4 + Vector3.UP * 1.25, (sp + wsp) * 0.5 + Vector3.UP * 0.55)
	await _wait(1.0)
	print("QUEST_SHOT spots ", QWorld.spots)
	await _shot("stair")
	_free_cam(Vector3(-0.8, _g(-3.3, 34.5) + 1.3, 37.2), Vector3(-3.0, _g(-3.3, 34.5) + 0.1, 34.2))
	await _wait(1.0)
	await _shot("fire")
	var ks := get_tree().get_first_node_in_group("keg_scenes")
	if ks and phase == "after":
		ks.call("play", "song")
	_free_cam(Vector3(23.4, 1.25, 26.6), Vector3(15.8, 0.15, 31.2))
	await _wait(2.4)
	await _shot("keg")
	_free_cam(Vector3(18.5, 0.85, 31.0), Vector3(16.9, 0.4, 33.0))
	await _wait(0.6)
	await _shot("bar")
	if ks and phase == "after":
		ks.call("_finish")
		ks.call("play", "dice")
		var cast: Array = ks.get("_cast")
		var mid := Vector3(20.4, 0.1, 28.9)
		if cast.size() == 2:
			mid = ((cast[0] as Node3D).global_position + (cast[1] as Node3D).global_position) * 0.5 + Vector3.UP * 0.8
		_free_cam(mid + Vector3(1.3, 0.75, -0.9), mid)
		await _wait(2.3)
		await _shot("dice")
	# --- the UI (player camera, HUD on) ---------------------------------------------------------
	_ui(true)
	if cam:
		cam.current = false
	var p := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	var hild: Node3D = (village.get("villagers") as Dictionary).get("hild")
	if phase == "after":
		(Book.st().quests as Dictionary).erase("edda_tongs")      # show her asking
	if p and hild:
		var to := hild.global_position + Vector3(1.4, 0.0, -1.6)
		if p.has_method("teleport"):
			p.call("teleport", to)
		else:
			p.global_position = to
		await _wait(0.8)
		hild.call("interact", p)
		var ui: CanvasLayer = story.get("ui")
		for i in 12:
			await _wait(0.25)
			ui.call("finish_line")
			if int(ui.call("choice_count")) > 0:
				break
			ui.call("press")
		await _wait(0.4)
		await _shot("dialogue")
		ui.call("close")
		ui.emit_signal("closed")
		await _wait(0.5)
	if phase == "after":
		Book.start("edda_tongs")
		Book.advance("edda_tongs")
		Book.start("names_yard")
		Book.find("names_yard", "slate_glade")
		await _wait(1.2)
		story.call("open_shop", "grisel", (village.get("villagers") as Dictionary).get("grisel"))
		await _wait(1.6)
		await _shot("shop")
		(story.get("shop") as Object).call("close")
		await _wait(0.4)
		var lg := get_tree().get_first_node_in_group("quest_log")
		if lg:
			lg.call("open")
			await _wait(0.6)
			await _shot("ledger")
			lg.call("close")
	_quit()


func _quit() -> void:
	VState.sandbox = null
	OS.kill(OS.get_process_id())

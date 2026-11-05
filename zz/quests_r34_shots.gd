extends Node
## r34 quests: renders of the new givers at their outposts and the task screens (windowed, real world):
##   HOME=<scratch>/home godot --path . res://zz/quests_r34_shots.tscn
## -> shots/quests_r34_<giver>.png (a free camera on each giver, the mark over the head, HUD off),
##    shots/quests_r34_play_<giver>.png (the wanderer's camera, HUD on: the mark and the minimap's "!"),
##    shots/quests_r34_offer.png (the accept screen), shots/quests_r34_turnin.png (the turn-in screen).
## Never writes the save (Travel._busy, the village in a sandbox) and exits with OS.kill.

const Book := preload("res://core/story/quest_book.gd")
const VState := preload("res://core/life/village/village_state.gd")
const Cast := preload("res://core/life/village/village_cast.gd")

var cam: Camera3D
var village: Node3D
var story: Node
var player: Node3D
var only := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	get_window().size = Vector2i(1600, 1000)
	Travel._busy = true
	Travel.story = {"flags": {"arrived": true, "met_keep": true}, "picked": {}}
	Travel.items = {"grave_ash": 30}
	VState.sandbox = {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_run()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://shots/quests_r34_%s.png" % what)
	get_viewport().get_texture().get_image().save_png(path)
	print("QUESTS_R34_SHOT ", path)


func _ui(on: bool) -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := c as CanvasLayer
		if cl.name in ["Dialogue", "Shop", "QuestLog", "QuestOffer"]:
			continue
		cl.visible = on


func _free_cam(at: Vector3, look: Vector3) -> void:
	if cam == null:
		cam = Camera3D.new()
		cam.fov = 55.0
		cam.far = 400.0
		get_tree().root.add_child(cam)
	cam.current = true
	cam.global_position = at
	cam.look_at(look)


func _tp(to: Vector3) -> void:
	if player.has_method("teleport"):
		player.call("teleport", to)
	else:
		player.global_position = to


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		village = get_tree().root.find_child("Village", true, false) as Node3D
		if village and village.has_meta("village_done"):
			break
		if Time.get_ticks_msec() - t0 > 180000:
			print("QUESTS_R34_SHOT no village")
			_quit()
			return
	story = get_tree().get_first_node_in_group("story")
	player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	await _wait(5.0)
	village.set("time_scale", 0.0)
	var outs: Dictionary = village.get("outpost_at")
	var vs: Dictionary = village.get("villagers")
	# --- each giver at their fire, the mark over the head (free camera, HUD off) ----------------------
	for g: String in Cast.OUTPOSTS:
		if only != "" and g != only:
			continue
		var v: Node3D = vs.get(g)
		var f: Vector3 = outs.get(g, Vector3.INF)
		if v == null or f == Vector3.INF:
			print("QUESTS_R34_SHOT missing ", g)
			continue
		for e in get_tree().get_nodes_in_group(Groups.ENEMY):
			if (e as Node3D).global_position.distance_to(f) < 40.0:
				(e as Node).queue_free()
		_tp(f + Vector3(4.0, 0.5, 4.0))
		await _wait(2.5)
		_ui(false)
		var at := v.global_position
		var side := Vector3(at.x - f.x, 0.0, at.z - f.z)
		side = side.normalized() if side.length() > 0.3 else Vector3(1, 0, 0)
		var view := (side.rotated(Vector3.UP, 0.9) * 4.6) + Vector3.UP * 1.9
		_free_cam(at + view, at + Vector3.UP * 1.55)
		await _wait(1.4)
		await _shot(g)
		_ui(true)
		if cam:
			cam.current = false
	# --- the wanderer's view at Gammer Ruan's fire, HUD on --------------------------------------------
	var ruan: Node3D = vs.get("ruan")
	if ruan and (only == "" or only == "ruan"):
		var to := ruan.global_position + Vector3(3.0, 0.3, 4.2)
		_tp(to)
		var d := ruan.global_position - to
		player.set("_yaw", atan2(-d.x, -d.z))       # the wanderer's camera turned to her
		await _wait(6.0)                             # past the region's discovery banner
		await _shot("play_ruan")
		# the accept screen for her attunement chain's first task
		story.call("open_quest", "offer:keeper_wards", "Gammer Ruan")
		await _wait(1.2)
		await _shot("offer")
		var offer: CanvasLayer = story.get("offer_ui")
		offer.call("_confirm")
		await _wait(0.6)
		# the three wards found, back at her fire: the "?" and the turn-in screen
		for k: String in ["ward_holds", "ward_wood", "ward_glade"]:
			Book.find("keeper_wards", k)
		Book.advance("keeper_wards")
		await _wait(1.5)
		await _shot("play_ruan_turnin")
		story.call("open_quest", "turnin:keeper_wards", "Gammer Ruan")
		await _wait(1.2)
		await _shot("turnin")
		offer.call("close")
	_quit()


func _quit() -> void:
	VState.sandbox = null
	OS.kill(OS.get_process_id())

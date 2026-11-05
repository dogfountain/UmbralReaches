extends Node
## RealmLore renders, one process: godot --path . res://zz/realm_lore_shots.tscn -- --realm --realm-modules=land,lore [--set=hearth]
## Waits for the realm, then saves shots/realm_lore/<name>.png for each view of the set(s).
## View heights are above the local ground. --set=scraps frames every inscription from 3.5 m.
const VIEWS := {
	"spawn": [
		["sp_w", Vector3(0, 1.8, 30), Vector3(-20, 1.5, 38)],
		["sp_s", Vector3(2, 1.8, 30), Vector3(2, 1.0, 60)],
		["sp_e", Vector3(4, 1.8, 36), Vector3(30, 1.5, 42)],
		["sp_n", Vector3(-4, 1.8, 40), Vector3(-14, 1.0, 16)],
	],
	"hearth": [
		["hw_overview", Vector3(-4, 14, 70), Vector3(2, 0, 36)],
		["hw_maud", Vector3(-8, 3, 32), Vector3(-17, 1.5, 42)],
		["hw_harrow", Vector3(-10, 3.5, 20), Vector3(-19, 1, 13)],
		["hw_reed", Vector3(16, 3, 50), Vector3(24, 1.5, 43)],
		["hw_barn", Vector3(-25, 3.5, 45), Vector3(-33, 1, 37.5)],
		["hw_forge", Vector3(11, 3, 50), Vector3(11, 1, 60)],
		["hw_well", Vector3(-4, 2.5, 37), Vector3(-8, 1, 45)],
		["hw_shrine", Vector3(-3, 2.2, 25), Vector3(-8.5, 1.5, 19.5)],
		["hw_south", Vector3(-6, 3, 58), Vector3(-15, 1.5, 64)],
	],
	"chapel": [
		["ch_overview", Vector3(-50, 16, 70), Vector3(-75, 0, 48)],
		["ch_door", Vector3(-60, 2.5, 55), Vector3(-70, 2, 51)],
		["ch_nave", Vector3(-71, 2.2, 51.5), Vector3(-86, 1.5, 51.5)],
		["ch_yard", Vector3(-64, 3.5, 30), Vector3(-76, 0.5, 40)],
		["ch_altar", Vector3(-80, 2.6, 51.4), Vector3(-89, 1.6, 51.4)],
	],
	"road": [
		["rd_west", Vector3(-92, 3, 70), Vector3(-104, 2, 63)],
		["rd_mid", Vector3(-30, 3, 66), Vector3(-45, 1, 58)],
		["rd_east", Vector3(60, 3, 70), Vector3(80, 1, 63)],
		["rd_gate_e", Vector3(92, 3, 72), Vector3(104, 2, 66)],
	],
	"glade": [
		["gl_shrine", Vector3(-38, 3, 22), Vector3(-45, 1, 15)],
	],
	"barrows": [
		["br_over", Vector3(70, 10, -36), Vector3(92, 0, -58)],
		["br_seal", Vector3(78, 2.2, -48), Vector3(86, 1.2, -50)],
		["br_fen", Vector3(48, 3, 28), Vector3(56, 0, 21)],
		["br_fen2", Vector3(84, 3, 14), Vector3(92, 0, 8)],
	],
	"wilds": [
		["tw_saint", Vector3(-83, 3, 28), Vector3(-88, 0.5, 24)],
		["tw_rune", Vector3(-92, 3, 12), Vector3(-97, 1.2, 8)],
		["tw_hut", Vector3(-94, 3.5, 32), Vector3(-101, 1, 38)],
		["tw_bounds", Vector3(-48, 4, 20), Vector3(-56, 1, 12)],
	],
}
var t := 0.0
var cam: Camera3D
var queue: Array = []
var ready_at := -1.0
var next_at := 0.0
var cur: Array = []


func _ready() -> void:
	var sets: Array = VIEWS.keys()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--set="):
			sets = Array(a.trim_prefix("--set=").split(","))
	for s in sets:
		queue.append_array(VIEWS.get(s, []))
	get_window().size = Vector2i(1280, 800)
	get_window().always_on_top = true          # an occluded window stops drawing on macOS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/realm_lore"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(d: float) -> void:
	t += d
	if ready_at < 0.0:
		var rl := get_tree().root.find_child("RealmLore", true, false)
		if rl != null and rl.has_meta("scraps"):
			ready_at = t + 6.0
		elif t > 150.0:
			get_tree().quit()
		return
	if t < ready_at or cam != null:
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY): (n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
	var rl := get_tree().root.find_child("RealmLore", true, false)
	var want: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			want = a.trim_prefix("--ids=").split(",")
	if "--set=scraps" in OS.get_cmdline_user_args() or not want.is_empty():
		for sc in rl.find_children("Lore_*", "", true, false):
			if not want.is_empty() and not String(sc.get("lore_id")) in want:
				continue
			var p := (sc as Node3D).global_position
			# stand back from the carrier, on the sense point's side
			var mk: Vector3 = sc.get("mark") if sc.get("mark") != Vector3.INF else p + Vector3.UP * 0.5
			var away := Vector3(p.x - mk.x, 0, p.z - mk.z)
			away = away.normalized() if away.length() > 0.05 else Vector3(0.7, 0, 0.7)
			queue.append(["scrap_" + String(sc.get("lore_id")), mk + away * 3.6 + Vector3.UP * 1.3 + away.cross(Vector3.UP) * 1.2, mk, true])
	cam = Camera3D.new(); cam.fov = 62.0; cam.far = 400.0
	get_tree().root.add_child(cam); cam.current = true
	_run()


func _run() -> void:
	while not queue.is_empty():
		cur = queue.pop_front()
		var space := cam.get_world_3d().direct_space_state
		var at: Vector3 = cur[1]
		var look: Vector3 = cur[2]
		if cur.size() < 4:          # authored views: heights above the ground
			at.y += RealmLayout.ground(space, at.x, at.z)
			look.y += RealmLayout.ground(space, look.x, look.z)
		else:
			at.y = maxf(at.y, RealmLayout.ground(space, at.x, at.z) + 1.2)
		cam.global_position = at
		cam.look_at(look)
		# an occluded window skips its draws (macOS), so force them: a few frames for TAA-free
		# settling (fade-ins, visibility ranges), then read the viewport back
		for i in 8:
			await get_tree().process_frame
			RenderingServer.force_draw(true)
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/realm_lore/%s.png" % cur[0]))
		print("SHOT ", cur[0])
	print("SHOTS DONE")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST); OS.kill(OS.get_process_id())

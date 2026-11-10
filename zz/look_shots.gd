extends Node
## The game's look, measured: the real player camera (grade on, HUD off) at fixed views across
## the Realm, saved as shots/look_<name>.png plus one contact sheet shots/look_sheet.png.
## Compare colour stats against a reference with ffmpeg signalstats (see docs/HANDOFF.md).
##   godot --path . res://zz/look_shots.tscn [-- --tag=before]   (files get _<tag>)
##   --view=name,x,y,z,yaw,pitch   only this view (repeatable)
##   --set=ssr_enabled:false,shadow_quality:0   Settings fields in memory (never saved)
##   --moon=shadow_bias:0.1,shadow_normal_bias:2   DirectionalLight3D properties on every moon
##   --noflora-shadow   undergrowth/flora MultiMeshes cast no shadow
var VIEWS := [
	["spawn", Vector3(0.0, 0.2, 24.0), 0.0, -0.06],
	["meadow", Vector3(-20.0, 0.3, 40.0), 2.4, -0.04],
	["thornwood", Vector3(-80.0, 3.0, 10.0), 0.4, -0.02],
	["henge", Vector3(-62.0, 8.0, -12.0), 0.9, -0.05],
	["fen", Vector3(62.0, 0.0, 6.0), -0.6, -0.06],
	["crossing", Vector3(0.0, 0.8, -10.0), 0.0, 0.05],
	["tavern", Vector3(12.0, -0.5, 27.0), -0.9, -0.08],
	["summit", Vector3(0.0, 27.9, -92.0), 0.0, -0.05],
]
const SETTLE := 40
var p: Player
var f := 0
var i := -1
var wait := 0
var tag := ""
var files: Array[String] = []
var custom := false
var moon_props := {}
var noflora := false
var tuned := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Travel._busy = true   # never write Luke's save from a capture run
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = "_" + a.trim_prefix("--tag=")
		elif a.begins_with("--view="):
			if not custom:
				VIEWS = []
				custom = true
			var v := a.trim_prefix("--view=").split(",")
			VIEWS.append([v[0], Vector3(float(v[1]), float(v[2]), float(v[3])), float(v[4]), float(v[5])])
		elif a.begins_with("--moon="):
			for kv in a.trim_prefix("--moon=").split(","):
				moon_props[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
		elif a == "--noflora-shadow":
			noflora = true
		elif a.begins_with("--set="):
			for kv in a.trim_prefix("--set=").split(","):
				var k := kv.get_slice(":", 0)
				var val := kv.get_slice(":", 1)
				var cur: Variant = Settings.get(k)
				Settings.set(k, (val == "true") if cur is bool else (float(val) if cur is float else int(val)))
				print("LOOK set ", k, " = ", Settings.get(k))
	get_window().size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	f += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if not p.get_parent().has_meta("realm_done"):
		return
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	if not tuned:
		tuned = true
		for d in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
			for k: String in moon_props:
				d.set(k, moon_props[k])
			print("LOOK moon ", d.name, " bias ", d.get("shadow_bias"), " normal ", d.get("shadow_normal_bias"), " mode ", d.get("directional_shadow_mode"), " max ", d.get("directional_shadow_max_distance"))
		if noflora:
			var n := 0
			for m in get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
				if (m as Node).has_meta(&"flora"):
					(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					n += 1
			print("LOOK flora shadows off: ", n)
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if String(c.name) != "Grade":
			(c as CanvasLayer).visible = false
	if i >= 0 and i < VIEWS.size():
		_hold()
	if wait > 0:
		wait -= 1
		return
	if i >= 0:
		var path := ProjectSettings.globalize_path("res://shots/look_%s%s.png" % [VIEWS[i][0], tag])
		get_viewport().get_texture().get_image().save_png(path)
		files.append(path)
	i += 1
	if i >= VIEWS.size():
		_sheet()
		print("LOOK_SHOTS done")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		OS.kill(OS.get_process_id())
		return
	_hold()
	p.set_view(float(VIEWS[i][2]), float(VIEWS[i][3]))
	wait = SETTLE


func _hold() -> void:
	p.global_position = VIEWS[i][1]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _sheet() -> void:
	var tw := 480
	var th := 300
	var sheet := Image.create(tw * 4, th * 2, false, Image.FORMAT_RGB8)
	for k in files.size():
		var im := Image.load_from_file(files[k])
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((k % 4) * tw, (k / 4) * th))
	sheet.save_png(ProjectSettings.globalize_path("res://shots/look_sheet%s.png" % tag))

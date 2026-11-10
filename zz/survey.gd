extends Node
## Whole-zone visual survey: walks a grid over the zone and records the player's own view (lantern
## lit, HUD hidden) in four directions at every walkable point, tiled into contact sheets.
##   godot --path . res://zz/survey.tscn [-- --step=12 --only=x0,z0,x1,z1 --out=folder]
##   -> shots/survey/sheet_NN.png (4 points x 4 views each) + shots/survey/manifest.txt
## Rows are points, columns look north (-z), east, south, west.
const TILE := Vector2i(480, 300)
const PER_SHEET := 4
const SETTLE := 7                 ## frames after a view change before the capture
var step := 12.0
var area := Rect2(-60, -126, 120, 176)
var p: Player
var points: Array[Vector3] = []
var f := 0
var pi_ := 0                      ## point index
var vi := 0                       ## view index
var wait := 0
var sheet: Image
var manifest := PackedStringArray()
var dir := ""
var out_name := "survey"
const YAWS := [0.0, -PI * 0.5, PI, PI * 0.5]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	area = RealmLayout.BOUNDS                 # the redesigned zone (unless --only narrows it)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			step = float(a.trim_prefix("--step="))
		elif a.begins_with("--out="):
			out_name = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			var v := a.trim_prefix("--only=").split(",")
			area = Rect2(float(v[0]), float(v[1]), float(v[2]) - float(v[0]), float(v[3]) - float(v[1]))
	dir = ProjectSettings.globalize_path("res://shots/" + out_name)
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1440, 900)
	var main: Node = load("res://world/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)


func _process(_d: float) -> void:
	f += 1
	if p == null:
		p = get_tree().get_first_node_in_group(Groups.PLAYER) as Player
		return
	if f < 400:                   # world assembly, bank maps, falls, Ossuary streaming
		return
	if not p.get_parent().has_meta("realm_done"):
		return                    # the Realm builds over many frames; survey once it is done
	if points.is_empty():
		_plan()
		if points.is_empty():
			print("SURVEY no points"); _quit(); return
		wait = SETTLE * 3
		_aim()
	for n in get_tree().get_nodes_in_group(Groups.ENEMY):
		(n as Node).queue_free()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	_hold()
	if wait > 0:
		wait -= 1
		return
	_capture()
	vi += 1
	if vi >= YAWS.size():
		vi = 0
		pi_ += 1
	if pi_ >= points.size():
		_flush()
		print("SURVEY done %d points" % points.size())
		_quit()
		return
	_aim()
	wait = SETTLE


func _aim() -> void:
	_hold()
	p.set_view(YAWS[vi], -0.12)


func _hold() -> void:
	if pi_ >= points.size():
		return
	p.global_position = points[pi_]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _plan() -> void:
	var space := (p.get_world_3d()).direct_space_state
	var z := area.position.y
	while z <= area.end.y:
		var x := area.position.x
		while x <= area.end.x:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -30, z), Layers.WORLD)
			var hit := space.intersect_ray(q)
			if hit and (hit.position as Vector3).y > -14.0 and (hit.normal as Vector3).y > 0.5:
				points.append((hit.position as Vector3) + Vector3.UP * 0.1)
			x += step
		z += step
	print("SURVEY %d points, %d sheets" % [points.size(), ceili(float(points.size()) / PER_SHEET)])


func _capture() -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
	var slot := pi_ % PER_SHEET
	if sheet == null:
		sheet = Image.create(TILE.x * YAWS.size(), TILE.y * PER_SHEET, false, img.get_format())
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(vi * TILE.x, slot * TILE.y))
	if vi == 0:
		manifest.append("sheet %02d row %d: point %d at %s" % [pi_ / PER_SHEET, slot, pi_, points[pi_].snapped(Vector3.ONE * 0.1)])
	if vi == YAWS.size() - 1 and slot == PER_SHEET - 1:
		_flush()


func _flush() -> void:
	if sheet == null:
		return
	sheet.save_png("%s/sheet_%02d.png" % [dir, pi_ / PER_SHEET])
	sheet = null
	var fa := FileAccess.open(dir + "/manifest.txt", FileAccess.WRITE)
	fa.store_string("\n".join(manifest) + "\n")


func _quit() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	OS.kill(OS.get_process_id())

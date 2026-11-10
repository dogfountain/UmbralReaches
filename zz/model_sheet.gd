extends Node3D
## Review sheets for every .glb under res://art/models (windowed; the renders need a GPU).
##   godot --path . res://zz/model_sheet.tscn -- --out=<dir> [--only=<substring>]
## Per model: 4 views at 512 px (front, front-left 45 deg up 20, side, close-up at 0.35 of the
## framing distance, aimed at the AABB centre), saved as <out>/<model>_<view>.png. Skips the
## files in the Linux preset's exclude_filter. Prints MODELSHEET <model> tris=<n> size=<aabb>.

const FOV := 40.0
const RES := 512
const MODELS_DIR := "res://art/models"
const PRESETS := "res://export_presets.cfg"

var out := "/tmp"
var only := ""
var excluded: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out)
	excluded = _linux_excludes()
	var found: Array = []
	_collect(MODELS_DIR, found)
	found.sort()
	var todo: Array = []
	for p in found:
		if _excluded(p):
			print("MODELSHEET_SKIP %s excluded" % p)
			continue
		if only != "" and not String(p).contains(only):
			continue
		todo.append(p)
	print("MODELSHEET_START count=%d" % todo.size())
	_run(todo)


func _run(todo: Array) -> void:
	for p in todo:
		await _sheet_model(String(p))
	print("MODELSHEET_DONE count=%d" % todo.size())
	get_tree().quit()


func _linux_excludes() -> Array:
	var pats: Array = []
	var found := false
	for l in FileAccess.get_file_as_string(PRESETS).split("\n"):
		var s := l.strip_edges()
		if s == 'name="Linux"':
			found = true
		elif found and s.begins_with("exclude_filter="):
			var raw := s.trim_prefix("exclude_filter=").trim_prefix('"').trim_suffix('"')
			for q in raw.split(","):
				var pat := q.strip_edges()
				if pat != "":
					pats.append(pat)
			break
		elif found and s.begins_with("["):
			break
	return pats


func _collect(dir: String, acc: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir.path_join(f)
		if d.current_is_dir():
			if not f.begins_with("."):
				_collect(p, acc)
		elif f.ends_with(".glb"):
			acc.append(p)
		f = d.get_next()
	d.list_dir_end()


func _excluded(path: String) -> bool:
	var rel := path.trim_prefix("res://")
	for pat in excluded:
		if rel.match(pat):
			return true
	return false


func _meshes(n: Node, acc: Array) -> Array:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_meshes(c, acc)
	return acc


func _tris(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var arr := m.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		var verts = arr[Mesh.ARRAY_VERTEX]
		if idx is PackedInt32Array and idx.size() > 0:
			t += idx.size() / 3
		elif verts is PackedVector3Array:
			t += verts.size() / 3
	return t


func _sheet_model(path: String) -> void:
	var rel := path.trim_prefix(MODELS_DIR + "/").trim_suffix(".glb")
	var base := rel.replace("/", "__")
	var model: Node = null
	var scene := ResourceLoader.load(path) as PackedScene
	if scene != null:
		model = scene.instantiate()
	else:
		# no usable import for this file: read the glTF directly
		var gltf := GLTFDocument.new()
		var st := GLTFState.new()
		if gltf.append_from_file(ProjectSettings.globalize_path(path), st) == OK:
			model = gltf.generate_scene(st)
			print("MODELSHEET_NOTE %s loaded via GLTFDocument (no import)" % rel)
	if model == null:
		print("MODELSHEET_FAIL %s load" % rel)
		return
	var sv := SubViewport.new()
	sv.size = Vector2i(RES, RES)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv.msaa_3d = Viewport.MSAA_4X
	add_child(sv)
	sv.add_child(model)

	var tris := 0
	var box := AABB()
	var have := false
	for mi in _meshes(model, []):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		tris += _tris(m)
		var ab: AABB = (mi as Node3D).global_transform * m.get_aabb()
		if have:
			box = box.merge(ab)
		else:
			box = ab
			have = true
	var empty := not have or box.size.length() < 0.0001
	if empty:
		print("MODELSHEET_EMPTY %s no mesh geometry" % rel)
		box = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.0, 1.0))
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var d := r / sin(deg_to_rad(FOV * 0.5))

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.46, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)

	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.shadow_enabled = false
	sv.add_child(key)
	key.position = c + Vector3(-1.0, 1.0, 1.0).normalized() * 10.0
	key.look_at(c, Vector3.UP)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	sv.add_child(fill)
	fill.position = c + Vector3(1.0, 0.5, -1.0).normalized() * 10.0
	fill.look_at(c, Vector3.UP)

	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = maxf(0.01, d * 0.01)
	cam.far = d * 20.0 + r
	sv.add_child(cam)
	cam.make_current()

	var up20 := deg_to_rad(20.0)
	var fl45 := deg_to_rad(45.0)
	var frontleft := Vector3(-sin(fl45) * cos(up20), sin(up20), cos(fl45) * cos(up20))
	var specs := [
		["front", Vector3(0, 0, 1), d],
		["frontleft", frontleft, d],
		["side", Vector3(1, 0, 0), d],
		["close", Vector3(0, 0, 1), d * 0.35],
	]
	for s in specs:
		cam.global_position = c + (s[1] as Vector3) * (s[2] as float)
		cam.look_at(c, Vector3.UP)
		cam.reset_physics_interpolation()  # the project interpolates transforms; a jump would render half-way
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE
		for k in 3:
			await get_tree().process_frame
		var img := sv.get_texture().get_image()
		if img == null:
			print("MODELSHEET_FAIL %s %s no image" % [rel, s[0]])
			continue
		img.save_png(out.path_join("%s_%s.png" % [base, s[0]]))

	print("MODELSHEET %s tris=%d size=(%.3f, %.3f, %.3f)" % [rel, tris, box.size.x, box.size.y, box.size.z])
	model.queue_free()
	sv.queue_free()
	await get_tree().process_frame

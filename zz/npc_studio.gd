extends Node3D
## NPC studio (npc agent): villagers and dwarves one at a time, close up, warm key + azure fill,
## optionally under the game's colour grade. One PNG per rig per frame time.
##   godot --path . res://zz/npc_studio.tscn -- --who=v:hild,v:fennick,d:911:helm,d:keep
##     [--view=face|bust|full|side|back|three] [--grade] [--times=1.0,1.2] [--name=x]
##     [--pose=rest|blink|open|talk|walk]  (blink: lids shut; open: jaw open; talk/walk: animated)
## -> shots/npc_<name>_<who>_<view>[_i].png. Never touches the save (no world, no Travel).

const VRig := preload("res://core/life/village/villager_rig.gd")
const Cast := preload("res://core/life/village/village_cast.gd")
const KEEP := {"seated": false, "seed": 5150, "apron": true, "hat": "bare", "rag": true}

var t := 0.0
var cam: Camera3D
var nm := "s"
var view := "face"
var pose := "rest"
var grade := false
var times: Array[float] = [1.0]
var who: Array[String] = ["v:hild"]
var rigs: Array[Node3D] = []
var heads: Array[float] = []
var cur := 0
var ti := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--grade":
			grade = true
		var v := a.split("=")
		if v.size() < 2:
			continue
		match v[0]:
			"--who":
				who.clear()
				for x in v[1].split(","):
					who.append(x)
			"--view": view = v[1]
			"--pose": pose = v[1]
			"--name": nm = v[1]
			"--times":
				times.clear()
				for x in v[1].split(","):
					times.append(float(x))
	get_window().size = Vector2i(1280, 960)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.04, 0.08)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.3, 0.45, 0.85)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.2
	env.environment = e
	add_child(env)
	var key := OmniLight3D.new()
	key.light_color = Color(1.0, 0.62, 0.32)
	key.light_energy = 2.0
	key.omni_range = 6.0
	add_child(key)
	key.position = Vector3(0.9, 1.9, -1.4)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.73, 1.0)
	moon.light_energy = 0.35
	moon.rotation = Vector3(-0.8, -2.4, 0.0)
	add_child(moon)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.22, 0.2, 0.18)
	fl.material_override = fm
	add_child(fl)
	for w in who:
		var p := w.split(":")
		var r: Node3D
		if p[0] == "v":
			var opts: Dictionary = (Cast.CAST[p[1]].rig as Dictionary).duplicate()
			opts["name"] = p[1]
			r = VRig.create(opts)
		elif p[1] == "keep":
			r = DwarfRig.make(KEEP)
		else:
			r = DwarfRig.make({"seated": false, "seed": int(p[1]), "hat": p[2] if p.size() > 2 else ""})
		add_child(r)
		r.visible = false
		rigs.append(r)
		var top: float = r.call("head_top") if r.has_method("head_top") else 1.35
		heads.append(top)
	if grade:
		var cl := CanvasLayer.new()
		var cr := ColorRect.new()
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.material = load("res://world/post/grade_material.tres")
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(cr)
		add_child(cl)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_show(0)


func _show(i: int) -> void:
	for j in rigs.size():
		rigs[j].visible = j == i
	var top := heads[i]
	var face_y := top - 0.13 if top > 1.3 else top - 0.12
	match view:
		"face":
			cam.fov = 22.0
			cam.position = Vector3(0.12, face_y + 0.04, -0.85)
			cam.look_at(Vector3(0, face_y - 0.02, 0))
		"side":
			cam.fov = 24.0
			cam.position = Vector3(-0.85, face_y + 0.03, -0.2)
			cam.look_at(Vector3(0, face_y - 0.03, -0.05))
		"three":
			cam.fov = 24.0
			cam.position = Vector3(-0.55, face_y + 0.06, -0.7)
			cam.look_at(Vector3(0, face_y - 0.03, -0.03))
		"bust":
			cam.fov = 30.0
			cam.position = Vector3(0.25, face_y - 0.05, -1.5)
			cam.look_at(Vector3(0, face_y - 0.25, 0))
		"back":
			cam.fov = 40.0
			cam.position = Vector3(0.6, top * 0.75, 2.4)
			cam.look_at(Vector3(0, top * 0.5, 0))
		_:
			cam.fov = 40.0
			cam.position = Vector3(0.5, top * 0.62, -2.6)
			cam.look_at(Vector3(0, top * 0.5, 0))


func _process(d: float) -> void:
	t += d
	var r := rigs[cur]
	r.call("reset")
	match pose:
		"blink":
			r.call("q", 15, Quaternion(Vector3.RIGHT, -0.95))
		"open":
			r.call("q", 4, Quaternion(Vector3.RIGHT, -0.22))
		"talk":
			r.call("q", 4, Quaternion(Vector3.RIGHT, -0.12 * absf(sin(t * 9.0))))
			r.call("q", 15, Quaternion(Vector3.RIGHT, -0.95 * float(fmod(t, 3.0) < 0.12)))
	r.call("apply")
	if r.has_method("update_glow"):
		r.call("update_glow")
	if t > times[ti]:
		var suffix := "" if times.size() == 1 else "_%d" % ti
		var id := who[cur].replace(":", "_")
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/npc_%s_%s_%s%s.png" % [nm, id, view, suffix]))
		ti += 1
		if ti >= times.size():
			ti = 0
			t = 0.0
			cur += 1
			if cur >= rigs.size():
				print("NPC STUDIO done ", nm)
				get_tree().quit()
				return
			_show(cur)

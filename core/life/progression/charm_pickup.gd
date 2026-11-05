extends Interactable
## A charm lying in the world (progression): a small keepsake on a flat stone, turning slowly in a
## faint glint so it can be found at night. [E] puts it in the satchel (and on, if a cord is free).

const DB := preload("res://core/life/progression/upgrade_db.gd")

var item_id := ""
var _vis: Node3D
var _t := 0.0
var _glint: MeshInstance3D


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	_t = randf() * 6.0
	var d := ItemDB.def(item_id)
	var tint: Color = d.get("tint", Color.WHITE)
	var stone := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.32
	sm.bottom_radius = 0.38
	sm.height = 0.14
	sm.radial_segments = 9
	sm.rings = 1
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.19, 0.22)
	smat.roughness = 0.95
	sm.material = smat
	stone.mesh = sm
	stone.position = Vector3.UP * 0.05
	stone.rotation.y = randf() * TAU
	add_child(stone)
	_vis = Node3D.new()
	_vis.position = Vector3.UP * 0.55
	add_child(_vis)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.6
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 0.8
	var mi := MeshInstance3D.new()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match String(d.get("shape", "")):
		"ring", "bead":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.07
			tm.outer_radius = 0.11
			tm.rings = 16
			tm.ring_segments = 8
			mi.mesh = tm
			mi.rotation.x = PI * 0.5
		"candle":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.045
			cm.bottom_radius = 0.05
			cm.height = 0.16
			mi.mesh = cm
		"bell":
			var bm := CylinderMesh.new()
			bm.top_radius = 0.04
			bm.bottom_radius = 0.1
			bm.height = 0.16
			mi.mesh = bm
		_:
			var sp := SphereMesh.new()
			sp.radius = 0.08
			sp.height = 0.16
			mi.mesh = sp
	_vis.add_child(mi)
	_glint = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.42, 0.42)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gm.albedo_texture = Vfx.dot()
	gm.albedo_color = Color(tint.r * 1.6, tint.g * 1.4, tint.b * 1.2, 0.6)
	q.material = gm
	_glint.mesh = q
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.position = Vector3.UP * 0.55
	add_child(_glint)
	var motes := Vfx.emitter(Color(tint.r * 1.8, tint.g * 1.5, tint.b * 1.2), {"count": 8, "life": 1.8, "speed": Vector2(0.05, 0.2), "size": 0.025, "gravity": -0.3, "radius": 0.3, "turbulence": true})
	motes.position = Vector3.UP * 0.45
	add_child(motes)
	motes.emitting = true


var _near := true
var _check := 0.0


func _process(delta: float) -> void:
	_t += delta
	# six of these lie across the whole Realm: only turn and bob within sight of the camera
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		var cam := get_viewport().get_camera_3d()
		_near = cam == null or cam.global_position.distance_squared_to(global_position) < 60.0 * 60.0
	if not _near:
		return
	_vis.rotation.y += delta * 0.8
	_vis.position.y = 0.55 + sin(_t * 1.6) * 0.04
	_glint.scale = Vector3.ONE * (0.85 + 0.25 * sin(_t * 2.3))


func can_interact() -> bool:
	return Travel.count(item_id) <= 0


func interact_text() -> String:
	return "[%s]  Take %s" % [Interactable.prompt_key(), ItemDB.def(item_id).name]


func interact(_by: Node) -> void:
	if Travel.count(item_id) > 0:
		return
	Travel.give(item_id, 1)
	var st := Travel.system_state("progression")
	var worn := (st.get("worn", []) as Array).has(item_id)
	Events.toast.emit("%s. %s" % [ItemDB.def(item_id).name, "You wear it." if worn else "Your cords are full: wear it from the Kindling [K]."])
	remove_from_group(Groups.INTERACTABLE)
	Vfx.burst(global_position + Vector3.UP * 0.55, Color(2.4, 1.6, 0.8), {"count": 30, "life": 0.6, "speed": Vector2(1.0, 3.5), "size": 0.04, "gravity": -2.0, "trail": 0.06})
	Sfx.play("res://art/audio/ward_chime.wav", global_position, -6.0, 1.3)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE * 0.01, 0.4)
	tw.parallel().tween_property(_glint, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(queue_free)

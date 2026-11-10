class_name MirrorGate
extends Interactable
## Stone-framed looking-glass. The pane is a purple vortex you can step through.

@export var destination := "res://world/main.tscn"
@export var spawn := Vector3.ZERO
@export var spawn_yaw := 0.0
@export var prompt := "[E]  Step through the glass"
@export var toast := "The glass remembers another night."
@export var light_radius := 6.5
@export var fire_color := Color("#C24A3A")

const ARCH_W := 1.16
const ARCH_Y0 := 0.46
const ARCH_Y1 := 3.38
const TUBE := 0.09
const GLASS_Z := 0.03
const IRON_SEGS := 40
const RADIAL := 7

var _busy := false


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	if not has_node("Glass"):
		_build()
	LightGrid.register(self, light_radius, LightGrid.MIRROR)


func can_interact() -> bool:
	return not _busy and not Travel.busy()


func interact_reach() -> float:
	return 4.6


func interact_text() -> String:
	return prompt.replace("[E]", "[%s]" % Interactable.prompt_key())


func interact_feel() -> StringName:
	return &"cast"


func interact(by: Node) -> void:
	if _busy or Travel.busy():
		return
	_busy = true
	Events.toast.emit(toast)
	# Do not await. The gate is freed when the scene changes, and waiting on it
	# was cancelling the trip before the new night finished loading.
	Travel.go(destination, spawn, spawn_yaw, by)


func _on_threshold(body: Node) -> void:
	if body is Player:
		interact(body)


static func place(parent: Node, n_name: String, pos: Vector3, yaw: float, dest: String, at: Vector3, facing: float, prompt_text: String, toast_text: String, _glass_color: Color, light_color: Color) -> MirrorGate:
	var m := MirrorGate.new()
	m.name = n_name
	m.destination = dest
	m.spawn = at
	m.spawn_yaw = facing
	m.prompt = prompt_text
	m.toast = toast_text
	m.fire_color = light_color
	parent.add_child(m)
	m.position = pos
	m.rotation.y = yaw
	return m


func _hot() -> Color:
	return fire_color.lerp(Color(1.0, 0.92, 0.55), 0.7)


func _mid() -> Color:
	return fire_color.lerp(Color(1.0, 0.42, 0.08), 0.4)


func _cool() -> Color:
	return fire_color.darkened(0.4)


func _inward(t: float) -> Vector3:
	if t <= 1.0:
		return Vector3(1.0, 0.0, 0.0)
	if t <= 2.0:
		var a := PI * (t - 1.0)
		return Vector3(cos(a), -sin(a), 0.0)
	return Vector3(-1.0, 0.0, 0.0)


func _arch_point(t: float, inset := 0.0) -> Vector3:
	var p := Vector3.ZERO
	if t <= 1.0:
		p = Vector3(-ARCH_W, lerpf(ARCH_Y0, ARCH_Y1, t), 0.0)
	elif t <= 2.0:
		var a := PI * (t - 1.0)
		p = Vector3(-cos(a) * ARCH_W, ARCH_Y1 + sin(a) * ARCH_W, 0.0)
	else:
		p = Vector3(ARCH_W, lerpf(ARCH_Y1, ARCH_Y0, t - 2.0), 0.0)
	return p + _inward(t) * inset


func _tangent(t: float) -> Vector3:
	var d := _arch_point(minf(t + 0.02, 2.999)) - _arch_point(maxf(t - 0.02, 0.0))
	if d.length() < 0.0001:
		return Vector3.UP
	return d.normalized()


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.05, 0.05)
	iron.metallic = 0.88
	iron.roughness = 0.35
	var fire_mat := ShaderMaterial.new()
	fire_mat.shader = load("res://world/fire_frame.gdshader")
	fire_mat.set_shader_parameter("fire_hot", _hot())
	fire_mat.set_shader_parameter("fire_mid", _mid())
	fire_mat.set_shader_parameter("fire_cool", _cool())
	fire_mat.set_shader_parameter("intensity", 1.25)
	var glass_mat := ShaderMaterial.new()
	glass_mat.shader = load("res://world/portal_glass.gdshader")
	glass_mat.set_shader_parameter("vortex_deep", Vector3(fire_color.r * 0.16, fire_color.g * 0.06, fire_color.b * 0.18))
	glass_mat.set_shader_parameter("vortex_rift", Vector3(fire_color.r * 0.72, fire_color.g * 0.38, fire_color.b * 0.55))
	glass_mat.set_shader_parameter("vortex_hot", Vector3(fire_color.r, fire_color.g * 0.85, fire_color.b))
	glass_mat.set_shader_parameter("intensity", 0.8)

	if not _stone_frame():
		var arch := MeshInstance3D.new()
		arch.mesh = _iron_tube()
		arch.material_override = iron
		arch.name = "IronArch"
		add_child(arch)
		var flame := MeshInstance3D.new()
		flame.mesh = _flame_ribbon()
		flame.material_override = fire_mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.name = "Fire"
		add_child(flame)

	var glass := MeshInstance3D.new()
	glass.mesh = _glass_fill()
	glass.material_override = glass_mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.name = "Glass"
	add_child(glass)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 2.5, 0.4)
	light.light_color = fire_color
	light.light_energy = 1.3
	light.omni_range = 8.0
	light.name = "Light"
	add_child(light)

	var body := StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for side in [-ARCH_W, ARCH_W]:
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.22
		shape.height = 4.2
		col.shape = shape
		col.position = Vector3(side, 2.2, 0.0)
		body.add_child(col)

	# Walking into the opening travels. The prompt is only a hint; the glass itself used to do nothing.
	var threshold := Area3D.new()
	threshold.name = "Threshold"
	threshold.collision_layer = 0
	threshold.collision_mask = Layers.PLAYER
	threshold.monitoring = true
	threshold.monitorable = false
	threshold.body_entered.connect(_on_threshold)
	var volume := CollisionShape3D.new()
	var opening := BoxShape3D.new()
	# Deeper toward the approach (+Z) so the summit walk hits it before the rim.
	opening.size = Vector3(1.7, 2.4, 2.4)
	volume.shape = opening
	volume.position = Vector3(0.0, 1.15, 1.0)
	threshold.add_child(volume)
	add_child(threshold)


func _stone_frame() -> bool:
	if not ResourceLoader.exists("res://art/models/stone_frame.glb"):
		return false
	var frame := (load("res://art/models/stone_frame.glb") as PackedScene).instantiate()
	frame.name = "StoneFrame"
	add_child(frame)
	var stone: Material = load("res://art/materials/stone.tres")
	var meshes: Array = []
	if frame is MeshInstance3D:
		meshes.append(frame)
	meshes.append_array(frame.find_children("*", "MeshInstance3D", true, false))
	if meshes.is_empty():
		frame.queue_free()
		return false
	for node in meshes:
		var mi := node as MeshInstance3D
		mi.material_override = stone
	return true


func _iron_tube() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := IRON_SEGS
	for i in ring:
		var t := 3.0 * float(i) / float(ring - 1)
		var p := _arch_point(t, 0.0)
		var y := _tangent(t)
		var x := y.cross(Vector3.FORWARD)
		if x.length() < 0.001:
			x = y.cross(Vector3.RIGHT)
		x = x.normalized()
		var z := x.cross(y).normalized()
		for j in RADIAL:
			var a := TAU * float(j) / float(RADIAL)
			var off := x * cos(a) * TUBE + z * sin(a) * TUBE
			st.set_uv(Vector2(float(i) / float(ring - 1), float(j) / float(RADIAL)))
			st.add_vertex(p + off)
	for i in ring - 1:
		for j in RADIAL:
			var a := i * RADIAL + j
			var b := i * RADIAL + (j + 1) % RADIAL
			var c := (i + 1) * RADIAL + j
			var d := (i + 1) * RADIAL + (j + 1) % RADIAL
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	return st.commit()


func _glass_fill() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 36
	var peak := ARCH_Y1 + ARCH_W
	var pts: PackedVector3Array = PackedVector3Array()
	for i in n:
		var t := 3.0 * float(i) / float(n - 1)
		pts.append(_arch_point(t, TUBE))
	var centre := Vector3(0.0, (ARCH_Y0 + peak) * 0.48, GLASS_Z)
	st.set_uv(Vector2(0.5, 0.48))
	st.set_normal(Vector3.FORWARD)
	st.add_vertex(centre)
	for i in n:
		var p := pts[i]
		p.z = GLASS_Z
		st.set_uv(Vector2(p.x / ARCH_W * 0.5 + 0.5, (p.y - ARCH_Y0) / (peak - ARCH_Y0)))
		st.set_normal(Vector3.FORWARD)
		st.add_vertex(p)
	for i in n - 1:
		st.add_index(0)
		st.add_index(i + 1)
		st.add_index(i + 2)
	# The fan walks the arch but never joins the two feet, which left a hole shaped like a triangle.
	st.add_index(0)
	st.add_index(n)
	st.add_index(1)
	st.generate_normals()
	return st.commit()


func _flame_ribbon() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	for i in segs:
		var t := 3.0 * float(i) / float(segs - 1)
		var inner := _arch_point(t, TUBE * 0.35)
		var outer := _arch_point(t, -TUBE - 0.22)
		outer.y += 0.12
		inner.z = 0.01
		outer.z = 0.01
		var u := float(i) / float(segs - 1)
		st.set_uv(Vector2(u, 0.0))
		st.add_vertex(inner)
		st.set_uv(Vector2(u, 1.0))
		st.add_vertex(outer)
	for i in segs - 1:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	st.generate_normals()
	return st.commit()


func _embers(mat: Material) -> void:
	var p := GPUParticles3D.new()
	p.position = Vector3(0.0, 2.3, 0.1)
	p.amount = 56
	p.lifetime = 1.3
	p.preprocess = 0.7
	p.visibility_aabb = AABB(Vector3(-3, -1, -1), Vector3(6, 7, 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.2, 2.0, 0.08)
	pm.direction = Vector3.UP
	pm.spread = 16.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.0, 0.7, 0.0)
	pm.scale_min = 0.35
	pm.scale_max = 1.05
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.16)
	q.material = mat
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.name = "Embers"
	add_child(p)

extends RefCounted
## A cottage's fireplace and its lime-washed lining (no class_name: preload by path). Built for the West
## Marches' gabled houses (realm_pois_west_marches.gd), all in the house's local frame (+z the front, `b` its yaw):
##  - surround(): the chimney breast on the back wall with a lintel, piers, a hearth slab and a mantel, and the
##    plaster that lines the inside of the walls (a warm neutral, so firelight reads amber, not terracotta);
##  - fire(): logs on iron dogs, a bed of coals, crossed flame cards (the brazier's shader), a few rising
##    embers and the room's fire light.

const FLOOR := 0.66                 ## top of the floor slab (_house)
const OPEN_W := 1.0                 ## the firebox opening
const OPEN_H := 0.95
const PIER := 0.65

## The lime-wash: warm, rough, faintly mottled. The caller registers it in OssKit._mats.
static func plaster() -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.seed = 37
	n.frequency = 0.05
	n.fractal_octaves = 3
	var img := n.get_image(256, 256, false, false, true)
	img.convert(Image.FORMAT_RGB8)
	img.adjust_bcs(1.0, 0.1, 1.0)             # a faint mottle, not a marbling
	img.adjust_bcs(1.5, 1.0, 1.0)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.56, 0.5)
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.8
	return m


## Chimney breast with its firebox, plus the plaster lining. `cx` is the chimney's x in the house frame.
static func surround(k: OssKit, base: Vector3, b: Basis, w: float, d: float, h: float, t: float, dw: float, cx: float, dh := 2.4) -> void:
	var zb := -d * 0.5 + t + 0.35                 # breast centre: flush with the back wall's inner face
	var top := h + 0.2
	var hi := top - FLOOR
	var pier_x := OPEN_W * 0.5 + PIER * 0.5
	for sx: float in [-1.0, 1.0]:
		k.box("stone", base + b * Vector3(cx + sx * pier_x, FLOOR + OPEN_H * 0.5, zb), Vector3(PIER, OPEN_H, 0.7), b, true, 0.9)
	k.box("stone", base + b * Vector3(cx, FLOOR + OPEN_H + (hi - OPEN_H) * 0.5, zb), Vector3(OPEN_W + PIER * 2.0, hi - OPEN_H, 0.7), b, true, 0.9)
	k.box("stone", base + b * Vector3(cx, FLOOR + OPEN_H + 0.05, zb + 0.4), Vector3(OPEN_W + PIER * 2.0 + 0.3, 0.12, 0.2), b, false, 0.82)      # the lintel's lip
	k.box("stone", base + b * Vector3(cx, FLOOR + 1.3, zb + 0.5), Vector3(OPEN_W + PIER * 2.0 + 0.5, 0.09, 0.4), b, false, 0.85)      # mantel
	k.box("stone", base + b * Vector3(cx, FLOOR + 0.045, zb + 0.55), Vector3(OPEN_W + PIER * 2.0 + 0.3, 0.09, 1.1), b, false, 0.8)    # hearth slab
	k.box("dark", base + b * Vector3(cx, FLOOR + OPEN_H * 0.5, -d * 0.5 + t + 0.03), Vector3(OPEN_W, OPEN_H, 0.05), b, false, 0.2)    # soot on the back
	k.box("dark", base + b * Vector3(cx, FLOOR + 0.1, zb), Vector3(OPEN_W, 0.02, 0.66), b, false, 0.15)                                   # ash floor
	# the plaster lining, 3 cm proud of each inner face
	var y0 := 0.9
	var wh := h - y0
	var ym := y0 + wh * 0.5
	var p := "r37_plaster"
	var e := 0.016
	k.box(p, base + b * Vector3(0, ym, -d * 0.5 + t + e), Vector3(w - t * 2.0, wh, 0.03), b, false, 1.0)
	for sx: float in [-1.0, 1.0]:
		k.box(p, base + b * Vector3(sx * (w * 0.5 - t - e), ym, 0), Vector3(0.03, wh, d - t * 2.0), b, false, 1.0)
		var seg := (w - dw) * 0.5 - t
		if seg > 0.2:
			k.box(p, base + b * Vector3(sx * (dw * 0.5 + seg * 0.5 + t * 0.5), ym, d * 0.5 - t - e), Vector3(seg, wh, 0.03), b, false, 1.0)
		for j in 4:                                       # the stepped gable inside
			var hw := (d - 0.6) * (1.0 - float(j) / 4.2)
			k.box(p, base + b * Vector3(sx * (w * 0.5 - t - e), h + 0.3 + 0.5 * float(j), 0), Vector3(0.03, 0.5, hw), b, false, 1.0)
	k.box(p, base + b * Vector3(0, dh + (h - dh) * 0.5 + 0.1, d * 0.5 - t - e), Vector3(dw + 0.3, h - dh, 0.03), b, false, 1.0)


## The fire itself. `host` owns every node; the fire sits in the breast's firebox. `s`: the house's scale about
## `base` (scale_pilot.gd): the firebox is that much bigger and further from the foot, and so is the fire.
static func fire(host: Node3D, base: Vector3, b: Basis, d: float, t: float, cx: float, id: String, s := 1.0) -> void:
	var zb := -d * 0.5 + t + 0.35
	var root := Node3D.new()
	root.name = id + "Hearth"
	host.add_child(root)
	root.global_transform = Transform3D(b.scaled(Vector3.ONE * s), base + b * (Vector3(cx, FLOOR, zb) * s))
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.1, 0.11)
	iron.roughness = 0.6
	iron.metallic = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.13, 0.08)
	wood.roughness = 0.95
	wood.emission_enabled = true
	wood.emission = Color(1.0, 0.3, 0.06)
	wood.emission_energy_multiplier = 0.25
	# andirons: two low iron dogs with a bar
	for sx: float in [-0.36, 0.36]:
		root.add_child(_mesh(_box(Vector3(0.05, 0.16, 0.05)), iron, Vector3(sx, 0.08, 0.1)))
		root.add_child(_mesh(_box(Vector3(0.05, 0.05, 0.4)), iron, Vector3(sx, 0.14, -0.05)))
	# logs: two across the dogs, one laid on top
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.075
	cyl.height = 0.78
	cyl.radial_segments = 8
	cyl.rings = 1
	var lg1 := _mesh(cyl, wood, Vector3(0, 0.2, -0.02))
	lg1.rotation = Vector3(0, 0, PI * 0.5)
	root.add_child(lg1)
	var lg2 := _mesh(cyl, wood, Vector3(0.04, 0.2, 0.17))
	lg2.rotation = Vector3(0.05, 0.1, PI * 0.5)
	root.add_child(lg2)
	var lg3 := _mesh(cyl, wood, Vector3(-0.05, 0.32, 0.07))
	lg3.rotation = Vector3(0.0, -0.35, PI * 0.5 + 0.08)
	root.add_child(lg3)
	# the coals: a mottled red-orange bed under the logs
	var nz := FastNoiseLite.new()
	nz.seed = 11
	nz.frequency = 0.09
	var timg := nz.get_image(64, 64, false, false, true)
	timg.convert(Image.FORMAT_RGB8)
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.2, 0.05, 0.02)
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.32, 0.07)
	coal.emission_texture = ImageTexture.create_from_image(timg)
	coal.emission_energy_multiplier = 1.05
	root.add_child(_mesh(_box(Vector3(0.86, 0.05, 0.5)), coal, Vector3(0, 0.03, -0.02)))
	# the flame: two crossed cards on the brazier's own shader
	var shader := load("res://world/brazier_flame.gdshader") as Shader
	if shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter(&"intensity", 0.8)
		var qm := QuadMesh.new()
		qm.size = Vector2(0.74, 0.86)
		qm.material = sm
		for i in 2:
			var f := _mesh(qm, null, Vector3(0, 0.55, -0.02))
			f.rotation.y = float(i) * PI * 0.5 + 0.35
			f.ignore_occlusion_culling = true
			root.add_child(f)
	var em := Vfx.emitter(Color(1.0, 0.5, 0.14), {"count": 7, "life": 1.8, "speed": Vector2(0.25, 0.6), "size": 0.03, "gravity": -0.35, "radius": 0.2, "additive": true, "spread": 20.0})
	if em != null:
		em.name = "Sparks"
		root.add_child(em)
		em.position = Vector3(0, 0.45, 0)
		em.emitting = true
	# the light: in the firebox's mouth, so the walls and floor take it
	Interiors.light(host, id + "Fire", root.global_position + b * (Vector3(0, 0.55, 0.45) * s), Interiors.FIRE, 1.05, 5.0 * s, false, 0.14).set_meta(&"fire", true)


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _mesh(m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if mat != null:
		mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A hung lantern about the size of a hand: a ring and chain, an iron cap and foot, a glass body that glows.
## Origin at the glass's centre.
static func lantern() -> Node3D:
	var n := Node3D.new()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09, 0.09, 0.1)
	iron.roughness = 0.6
	iron.metallic = 0.6
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(1.0, 0.62, 0.28)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.68, 0.32)
	glass.emission_energy_multiplier = 0.38
	var body := CylinderMesh.new()
	body.top_radius = 0.06
	body.bottom_radius = 0.05
	body.height = 0.16
	body.radial_segments = 6
	body.rings = 1
	n.add_child(_mesh(body, glass, Vector3.ZERO))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.01
	cap.bottom_radius = 0.085
	cap.height = 0.07
	cap.radial_segments = 6
	cap.rings = 1
	n.add_child(_mesh(cap, iron, Vector3(0, 0.115, 0)))
	var foot := CylinderMesh.new()
	foot.top_radius = 0.055
	foot.bottom_radius = 0.04
	foot.height = 0.03
	foot.radial_segments = 6
	foot.rings = 1
	n.add_child(_mesh(foot, iron, Vector3(0, -0.095, 0)))
	n.add_child(_mesh(_box(Vector3(0.008, 0.3, 0.008)), iron, Vector3(0, 0.3, 0)))      # the chain up to the beam
	return n

class_name ProcMesh
extends RefCounted
## Shared procedural-mesh and material helpers, used by EquipmentPiece and anything else that
## builds primitive-mesh geometry at runtime. Pulling these out of CharacterRig is what makes a
## new body part/clothing/item a few data fields instead of copy-pasted construction code.

static func node(parent: Node, n_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = n_name
	n.position = pos
	if parent == null:
		push_error("ProcMesh.node parent null '%s'" % n_name)
		return n
	parent.add_child(n)
	return n


static func mesh(parent: Node, n_name: String, m: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n_name
	if m == null:
		push_error("ProcMesh.mesh null mesh '%s'" % n_name)
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		push_error("ProcMesh.mesh parent null '%s'" % n_name)
		return mi
	parent.add_child(mi)
	return mi


static func cyl(top: float, bottom: float, h: float, radial := 12, rings := 1) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = radial
	c.rings = rings
	return c


static func sphere(r: float, h: float, radial := 12, rings := 6) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = radial
	s.rings = rings
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func std_mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.rim_enabled = true
	m.rim = 0.14 # x0.35: tuned at the old 0.4 moon (1.5 since 13 Nov)
	m.rim_tint = 0.8
	return m


static func glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

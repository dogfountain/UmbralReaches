extends EquipmentPiece
## One generated part of the wanderer (core/player/wanderer_gen.gd) dressed in its materials.
## Cloth surfaces get the robe wave shader (with this part's hem parameters); leather, iron, wood
## and the rest are StandardMaterial3D with the generated textures (core/player/wanderer_tex.gd).
## The built MeshInstance carries meta "wave" when it has cloth, so CharacterRig feeds it the
## per-frame stride/foot uniforms. Load by path (no class_name).
## With `merged` on (CharacterRig sets it while it dresses the wanderer) the piece builds only its
## root: a driver node carrying meta "gen_parts", and wanderer_body.gd bakes every part into one
## skinned mesh posed from those drivers.

const WGen := preload("res://core/player/wanderer_gen.gd")
const WTex := preload("res://core/player/wanderer_tex.gd")
const ROBE_WAVE := preload("res://core/player/robe_wave.gdshader")
const ROBE_MAGIC := "res://art/textures/robe_magic.png"

@export var part := "coat"
@export var mesh_name := ""
## robe_wave hem parameters: anchor_y, cloth_len, leg_push, wave_scale (mesh-local)
@export var wave := Vector4(0.28, 1.42, 1.0, 1.0)

static var _mats := {}
static var merged := false


func build(socket: Node3D) -> Node3D:
	if socket == null:
		push_error("WandererPiece.build socket null (%s)" % part)
		return Node3D.new()
	var root := ProcMesh.node(socket, node_name if node_name != "Piece" else part.capitalize(), offset)
	root.rotation_degrees = rotation_deg
	root.set_meta("dressed", true)
	if merged:
		root.set_meta("gen_parts", [[part, wave]])
		return root
	var mi := MeshInstance3D.new()
	mi.name = mesh_name if mesh_name != "" else "Mesh"
	mi.mesh = WGen.mesh(part)
	root.add_child(mi)
	var cloth := false
	for s in mi.mesh.get_surface_count():
		var mat := material(mi.mesh.surface_get_name(s), wave)
		cloth = cloth or mat is ShaderMaterial
		mi.set_surface_override_material(s, mat)
	if cloth:
		mi.set_meta("wave", true)
	return root


static func material(surf: String, wv := Vector4(0.28, 1.42, 1.0, 1.0)) -> Material:
	var key := surf
	if surf in ["cloth", "lining", "trim", "tunic", "tunic_trim"]:
		key = "%s|%s" % [surf, wv]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match surf:
		"cloth":
			m = _cloth(wv, "wool", Color(1, 1, 1), 0.72, 0.0, Vector2(2.2, 2.2), 0.9, 0.55)
		"tunic":
			m = _cloth(wv, "wool", Color(0.86, 0.78, 0.66), 0.3, 0.0, Vector2(2.6, 2.6), 0.92, 0.6)
		"lining":
			m = _cloth(wv, "wool", Color(0.4, 0.33, 0.27), 0.0, 0.0, Vector2(3.0, 3.0), 0.95, 0.0)
		"trim", "tunic_trim":
			m = _cloth(wv, "trim", Color(1, 1, 1), 0.0, 1.1, Vector2(1.0 / 0.24, 1.0), 0.75, 0.3)
		"leather", "strap":
			m = _std("leather", Color(1, 1, 1), Vector3(5, 5, 1), 0.0)
		"cord":
			m = _std("leather", Color(1.5, 1.3, 1.05), Vector3(2, 8, 1), 0.0)
		"glass":
			m = ProcMesh.glow_mat(Color(2.6, 1.6, 0.7))
		"orb":
			m = ProcMesh.glow_mat(Color(1.3, 0.55, 3.2))
		"grip":
			m = _std("leather", Color(0.85, 0.8, 0.75), Vector3(6, 14, 1), 0.0)
		"sole":
			m = _std("leather", Color(0.45, 0.42, 0.42), Vector3(6, 6, 1), 0.0)
		"iron":
			m = _std("iron", Color(1, 1, 1), Vector3(6, 6, 1), 0.85)
		"wood", "staff":
			m = _std("wood", Color(1.55, 1.45, 1.4), Vector3(1, 1, 1), 0.0)
		"pants":
			m = _std("wool", Color(0.75, 0.72, 0.72), Vector3(3, 3, 1), 0.0)
		"wrap":
			m = _std("wool", Color(1.5, 1.2, 0.8), Vector3(4, 4, 1), 0.0)
		_:
			m = _std("leather", Color(1, 1, 1), Vector3(4, 4, 1), 0.0)
	m.resource_name = surf
	_mats[key] = m
	return m


static func _cloth(wv: Vector4, tex: String, tint: Color, magic: float, glyph: float, uv: Vector2, rough: float, grime: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROBE_WAVE
	m.set_shader_parameter("albedo_tex", WTex.tex(tex))
	m.set_shader_parameter("normal_tex", WTex.tex(tex + "_n"))
	var magic_tex := load(ROBE_MAGIC) as Texture2D
	if magic_tex:
		m.set_shader_parameter("magic_tex", magic_tex)
	m.set_shader_parameter("anchor_y", wv.x)
	m.set_shader_parameter("cloth_len", wv.y)
	m.set_shader_parameter("leg_push", wv.z)
	m.set_shader_parameter("wave_scale", wv.w)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("magic_amt", magic)
	m.set_shader_parameter("glyph_glow", glyph)
	m.set_shader_parameter("alpha_rough", 0.0 if tex == "trim" else 1.0)
	m.set_shader_parameter("roughness_amt", rough)
	m.set_shader_parameter("hem_grime", grime)
	m.set_shader_parameter("rim_color", Vector3(0.46, 0.34, 0.27))
	m.set_shader_parameter("glow_energy", 0.08)
	m.set_shader_parameter("magic_scale", 0.42)
	m.set_shader_parameter("rim_amt", 0.4 if magic > 0.0 else 0.2)
	return m


static func _std(tex: String, tint: Color, uv: Vector3, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = WTex.tex(tex)
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = WTex.tex(tex + "_n")
	m.normal_scale = 1.0
	m.roughness_texture = WTex.tex(tex)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	m.roughness = 1.0
	m.metallic = metal
	m.metallic_specular = 0.45
	m.uv1_scale = uv
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.7
	return m

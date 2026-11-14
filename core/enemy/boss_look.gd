extends RefCounted
## The materials a built boss wears (boss_tile.gdshader): one per surface of its model, named in Blender
## (tools/blender/boss_build_*.py). Tiles are the wanderer's (wanderer_tex.gd), tinted by the mesh's vertex colours.
## Load by path (no class_name): const BossLook := preload("res://core/enemy/boss_look.gd")

const WTex := preload("res://core/player/wanderer_tex.gd")
const SHADER := preload("res://core/enemy/boss_tile.gdshader")

## surface name -> [tile, uv scale, metallic, roughness factor, normal depth, sheen, keep the tile's own colour]
const SURFACES := {
	"wool": ["wool", Vector2(2.2, 2.2), 0.0, 1.0, 1.0, 0.5, false],
	"linen": ["wool", Vector2(3.4, 3.4), 0.0, 1.05, 0.6, 0.35, false],
	"trim": ["trim", Vector2(1.0 / 0.24, 1.0), 0.3, 1.0, 1.0, 0.2, true],
	"leather": ["leather", Vector2(2.0, 2.0), 0.0, 1.0, 1.0, 0.0, false],
	"bone": ["leather", Vector2(1.3, 1.3), 0.0, 0.8, 0.45, 0.2, false],
	"gilt": ["iron", Vector2(3.0, 3.0), 1.0, 0.5, 0.6, 0.0, false],
	"iron": ["iron", Vector2(2.0, 2.0), 0.9, 0.9, 1.0, 0.0, false],
	"wood": ["wood", Vector2(1.5, 1.5), 0.0, 1.0, 1.0, 0.0, false],
	"stone": ["iron", Vector2(0.8, 0.8), 0.0, 1.5, 1.4, 0.0, false],
	"glow": ["iron", Vector2(1.0, 1.0), 0.0, 1.0, 0.0, 0.0, false],
}
static var _means := {}


## Mean luminance of a tile: the shader divides by it, so a tinted surface keeps the tint's own value.
static func _mean(tile: String) -> float:
	if not _means.has(tile):
		var im := WTex.img(tile).duplicate() as Image
		if im.is_compressed():
			im.decompress()
		im.resize(16, 16, Image.INTERPOLATE_BILINEAR)
		var acc := 0.0
		for y in 16:
			for x in 16:
				var c := im.get_pixel(x, y).srgb_to_linear()
				acc += c.r * 0.3 + c.g * 0.59 + c.b * 0.11
		_means[tile] = maxf(acc / 256.0, 0.02)
	return _means[tile]


## kind -> {emit_col, emit_energy, emit_pulse, rim_col, rim_amount}
const KINDS := {
	&"bone_abbot": {"emit_col": Color(1.0, 0.66, 0.3), "emit_energy": 3.2, "emit_pulse": 0.18, "rim_col": Color(1.0, 0.7, 0.32), "rim_amount": 0.05},
	&"ascended_warden": {"emit_col": Color(1.0, 0.9, 0.62), "emit_energy": 3.0, "emit_pulse": 0.1, "rim_col": Color(1.0, 0.88, 0.55), "rim_amount": 0.06},
	&"hierarch": {"emit_col": Color(1.0, 0.55, 0.2), "emit_energy": 3.4, "emit_pulse": 0.15, "rim_col": Color(0.9, 0.85, 0.5), "rim_amount": 0.04},
	&"anchoress": {"emit_col": Color(1.0, 0.78, 0.45), "emit_energy": 2.8, "emit_pulse": 0.25, "rim_col": Color(0.8, 0.6, 0.4), "rim_amount": 0.04},
	&"wretch": {"emit_col": Color(1.0, 0.45, 0.15), "emit_energy": 3.0},
	&"husk": {"emit_col": Color(1.0, 0.45, 0.12), "emit_energy": 3.2, "emit_pulse": 0.35},
	&"chanter": {"emit_col": Color(0.6, 1.0, 0.4), "emit_energy": 3.0, "emit_pulse": 0.25},
	&"tollman": {"emit_col": Color(1.0, 0.65, 0.3), "emit_energy": 2.8},
	&"pilgrim": {"emit_col": Color(1.0, 0.75, 0.4), "emit_energy": 2.6},
	&"gaunt": {"emit_col": Color(0.75, 0.85, 1.0), "emit_energy": 2.8},
	&"quiller": {"emit_col": Color(0.7, 0.85, 1.0), "emit_energy": 2.8},
	&"ossuant": {"emit_col": Color(1.0, 0.8, 0.45), "emit_energy": 3.0},
	&"bulwark": {"emit_col": Color(1.0, 0.55, 0.2), "emit_energy": 3.2},
	&"spitter": {"emit_col": Color(0.4, 1.0, 0.7), "emit_energy": 3.0, "emit_pulse": 0.4, "pulse_rate": 3.0},
	&"cinder_caster": {"emit_col": Color(1.0, 0.45, 0.1), "emit_energy": 3.4, "emit_pulse": 0.3},
	&"crawler": {"emit_col": Color(1.0, 0.4, 0.15), "emit_energy": 3.0, "emit_pulse": 0.3},
	&"mite": {"emit_col": Color(0.3, 1.0, 0.85), "emit_energy": 2.6, "emit_pulse": 0.45, "pulse_rate": 2.6},
	&"burrower": {"emit_col": Color(1.0, 0.55, 0.2), "emit_energy": 2.4, "emit_pulse": 0.3},
	&"leaper": {"emit_col": Color(1.0, 0.45, 0.15), "emit_energy": 3.0},
	&"thornwarden": {"emit_col": Color(1.0, 0.45, 0.12), "emit_energy": 3.5, "emit_pulse": 0.3, "rim_col": Color(1.0, 0.42, 0.1), "rim_amount": 0.0},
}
static var _mats := {}


static func has(kind: StringName) -> bool:
	return KINDS.has(kind)


## The material for one surface of a kind's model (shared by every instance; flash and dissolve are per instance).
static func material(kind: StringName, surface: String) -> ShaderMaterial:
	var key := "%s|%s" % [kind, surface]
	if _mats.has(key):
		return _mats[key]
	var s: Array = SURFACES.get(surface, SURFACES["wool"])
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tile", WTex.tex(String(s[0])))
	m.set_shader_parameter("tile_n", WTex.tex(String(s[0]) + "_n"))
	m.set_shader_parameter("uv_scale", s[1])
	m.set_shader_parameter("metallic", s[2])
	m.set_shader_parameter("rough_k", s[3])
	m.set_shader_parameter("normal_depth", s[4])
	m.set_shader_parameter("sheen", s[5])
	m.set_shader_parameter("tile_mean", 0.0 if bool(s[6]) else _mean(String(s[0])))
	m.set_shader_parameter("rune_glow", 0.55 if surface == "trim" else 0.0)
	var k: Dictionary = KINDS.get(kind, {})
	for p: String in k:
		m.set_shader_parameter(p, k[p])
	_mats[key] = m
	return m


## Dress every surface of a built model's meshes by its name; returns the meshes (Enemy.set_flesh).
static func dress(kind: StringName, meshes: Array[MeshInstance3D]) -> Array[MeshInstance3D]:
	var phase := randf() * TAU
	for mi in meshes:
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var nm := ""
			var sm := mi.mesh.surface_get_material(i)
			if sm != null:
				nm = sm.resource_name
			if nm == "" and mi.mesh is ArrayMesh:
				nm = (mi.mesh as ArrayMesh).surface_get_name(i)
			mi.set_surface_override_material(i, material(kind, nm.to_lower().split(".")[0]))
		mi.set_instance_shader_parameter(&"pulse_phase", phase)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return meshes

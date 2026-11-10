extends RefCounted
## The Casting Pits at the Founder's Pits (realm_pois_r34.gd `_foundry_pits`): the molten surface in the pits and the
## bell's clay mould lying on its side in the big pit. Self-contained mesh and shader builders.

const MOLTEN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float seed = 0.0;
float h(vec2 p) { return fract(sin(dot(p + seed, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float t = TIME * 0.12;
	float f = n(p * 3.0 + vec2(t, -t)) * 0.55 + n(p * 7.0 - vec2(t * 1.7, t)) * 0.3 + n(p * 15.0 + t) * 0.15;
	float crust = smoothstep(0.52, 0.7, f + d * 0.4);
	float vein = 1.0 - smoothstep(0.0, 0.07, abs(n(p * 5.0 + vec2(t * 0.5, t)) - 0.5));
	float heat = clamp(1.2 - d * 0.75 - crust * 0.7, 0.0, 1.0);
	vec3 melt = mix(vec3(1.5, 0.26, 0.03), vec3(2.6, 1.25, 0.3), pow(heat, 1.3));
	vec3 slag = vec3(0.03, 0.02, 0.018) + vec3(1.4, 0.3, 0.02) * vein * (1.0 - d * 0.5) + vec3(0.2, 0.04, 0.0) * heat;
	ALBEDO = mix(melt, slag, crust);
}
"""


## A pit of molten metal: a round surface, a drifting crust of slag over a bright melt (thickest at the kerb).
static func molten(host: Node3D, at: Vector3, radius: float, seed_v: float) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 28
	cm.rings = 1
	var sh := Shader.new()
	sh.code = MOLTEN_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("seed", seed_v)
	var mi := MeshInstance3D.new()
	mi.name = "Molten"
	mi.mesh = cm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = at


## The profile of a founder's bell, radius over height (lip at 0): flared lip, waist, rounded crown.
const BELL_PROFILE := [Vector2(1.0, 0.0), Vector2(0.95, 0.14), Vector2(0.8, 0.42), Vector2(0.64, 0.85), Vector2(0.55, 1.3),
	Vector2(0.52, 1.65), Vector2(0.44, 1.93), Vector2(0.26, 2.12), Vector2(0.0, 2.2)]


static func bell_radius(y: float) -> float:
	for i in BELL_PROFILE.size() - 1:
		var a: Vector2 = BELL_PROFILE[i]
		var c: Vector2 = BELL_PROFILE[i + 1]
		if y <= c.y:
			return lerpf(a.x, c.x, (y - a.y) / maxf(c.y - a.y, 0.001))
	return 0.0


## A bell's clay mould, local +Y up from the lip: a dark loam cope (outer face and hollow inside), three banded iron straps,
## a lifting eye on the crown. `xf` places its lip centre.
static func bell_mould(host: Node3D, xf: Transform3D) -> void:
	var root := Node3D.new()
	root.name = "BellMould"
	host.add_child(root)
	root.global_transform = xf
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 20
	var prof: Array = BELL_PROFILE
	for pass_i in 2:
		var inner := pass_i == 1
		for i in prof.size() - 1:
			var p0: Vector2 = prof[i]
			var p1: Vector2 = prof[i + 1]
			var o0 := 0.0 if not inner else 0.16
			for j in seg:
				var a0 := TAU * float(j) / float(seg)
				var a1 := TAU * float(j + 1) / float(seg)
				var r0 := maxf(p0.x - o0, 0.0) if not inner else maxf(p0.x - 0.16, 0.0)
				var r1 := maxf(p1.x - o0, 0.0) if not inner else maxf(p1.x - 0.16, 0.0)
				var y0 := p0.y if not inner else minf(p0.y, 2.0) * 0.92
				var y1 := p1.y if not inner else minf(p1.y, 2.0) * 0.92
				var v00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
				var v01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
				var v10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
				var v11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
				for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
					st.set_uv(Vector2(v.x + v.z, v.y))
					st.add_vertex(v)
	# the lip's thickness: a ring joining the outer face to the hollow
	for j in seg:
		var a0 := TAU * float(j) / float(seg)
		var a1 := TAU * float(j + 1) / float(seg)
		for v: Vector3 in [Vector3(cos(a0) * 1.0, 0, sin(a0) * 1.0), Vector3(cos(a0) * 0.84, 0, sin(a0) * 0.84), Vector3(cos(a1) * 0.84, 0, sin(a1) * 0.84),
				Vector3(cos(a0) * 1.0, 0, sin(a0) * 1.0), Vector3(cos(a1) * 0.84, 0, sin(a1) * 0.84), Vector3(cos(a1) * 1.0, 0, sin(a1) * 1.0)]:
			st.set_uv(Vector2(v.x + v.z, 0.0))
			st.add_vertex(v)
	st.generate_normals()
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.2, 0.125, 0.085)
	clay.roughness = 0.95
	clay.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cope := MeshInstance3D.new()
	cope.name = "Cope"
	cope.mesh = st.commit()
	cope.material_override = clay
	root.add_child(cope)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.095, 0.09)
	iron.metallic = 0.7
	iron.roughness = 0.5
	for by: float in [0.22, 0.9, 1.55]:
		var r := bell_radius(by) + 0.02
		var tm := TorusMesh.new()
		tm.inner_radius = r - 0.045
		tm.outer_radius = r + 0.045
		tm.rings = 20
		tm.ring_segments = 8
		var band := MeshInstance3D.new()
		band.mesh = tm
		band.material_override = iron
		band.position = Vector3(0, by, 0)
		band.scale = Vector3(1.0, 2.2, 1.0)
		root.add_child(band)
	var eye := TorusMesh.new()
	eye.inner_radius = 0.16
	eye.outer_radius = 0.27
	var eye_mi := MeshInstance3D.new()
	eye_mi.mesh = eye
	eye_mi.material_override = iron
	eye_mi.position = Vector3(0, 2.3, 0)
	eye_mi.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(eye_mi)

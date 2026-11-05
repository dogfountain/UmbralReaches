extends RefCounted
## A beam of caught light for the secrets' light puzzles (no class_name): traced flat in xz at one
## height through bronze mirrors (each throws whatever reaches it the way it faces), blockers
## (circles that stop it unless they say otherwise) and targets (an eye that wants it), and drawn
## as warm, faint additive ribbons. Peak brightness stays under the glow threshold.
##   const Beam := preload("res://core/life/secrets/beam.gd")
##   var hit := Beam.trace(from, dir, elements)       -> {pts: [Vector2], hit: target id or ""}
##   Beam.draw(holder, pts, y)                         (rebuilds the ribbons under `holder`)
## element = {kind: "mirror" | "block" | "target", id, at: Vector2, r, out: Vector2 (mirror),
##            pass: Callable(dir: Vector2) -> bool (block: may the beam go through this way?)}

const MAX_LEN := 40.0
const MAX_BOUNCE := 8
static var _mat: ShaderMaterial


## Forget the shared material (see Kit.release: static resources must not outlive the servers).
static func release() -> void:
	_mat = null


## The eight directions a mirror can face (index 0 = +x, counter-clockwise seen from above:
## 2 = -z "north", 4 = -x, 6 = +z).
static func dir8(i: int) -> Vector2:
	var a := float(posmod(i, 8)) * TAU / 8.0
	return Vector2(cos(a), -sin(a)).normalized()


static func trace(from: Vector2, dir: Vector2, elements: Array, seg_max := MAX_LEN) -> Dictionary:
	var pts: Array[Vector2] = [from]
	var p := from
	var d := dir.normalized()
	var left := seg_max
	var skip := ""
	for bounce in MAX_BOUNCE:
		var best_t := left
		var best: Dictionary = {}
		for e: Dictionary in elements:
			if String(e.get("id", "")) == skip:
				continue
			var t := _ray_circle(p, d, e.at, float(e.get("r", 0.4)))
			if t < 0.0 or t >= best_t:
				continue
			if String(e.kind) == "block" and (e.get("pass") is Callable) and bool((e.pass as Callable).call(d)):
				continue
			best_t = t
			best = e
		if best.is_empty():
			pts.append(p + d * left)
			return {"pts": pts, "hit": ""}
		var kind := String(best.kind)
		var at: Vector2 = best.at
		if kind == "mirror":
			pts.append(at)
			left = seg_max
			p = at
			d = (best.out as Vector2).normalized()
			skip = String(best.id)
			continue
		pts.append(p + d * best_t)
		return {"pts": pts, "hit": String(best.id) if kind == "target" else ""}
	return {"pts": pts, "hit": ""}


## Distance along the ray to the circle (first crossing), or -1.
static func _ray_circle(p: Vector2, d: Vector2, c: Vector2, r: float) -> float:
	var m := p - c
	var b := m.dot(d)
	var cc := m.dot(m) - r * r
	if cc > 0.0 and b > 0.0:
		return -1.0
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return maxf(t, 0.0)


## Replace the ribbons under `holder` with one per segment of `pts` (xz) at height `y`.
static func draw(holder: Node3D, pts: Array, y: float, width := 0.22) -> void:
	for c in holder.get_children():
		c.queue_free()
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		segment(holder, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), width)


## One ribbon from a to b (world space): two crossed quads, UV.x across, UV.y along.
static func segment(holder: Node3D, a: Vector3, b: Vector3, width := 0.22) -> MeshInstance3D:
	var len := a.distance_to(b)
	if len < 0.05:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var u := Vector3.RIGHT * width * 0.5 if k == 0 else Vector3.UP * width * 0.5
		var v0 := Vector3(0, 0, 0)
		var v1 := Vector3(0, 0, -len)
		var q := [v0 - u, v0 + u, v1 + u, v1 - u]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, len), Vector2(0, len)]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[idx])
			st.add_vertex(q[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 70.0
	holder.add_child(mi)
	var fwd := (b - a).normalized()
	var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(fwd, up), a)
	mi.set_instance_shader_parameter(&"len", len)
	return mi


static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = BEAM_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat


## Warm caught light: bright thread in the middle, soft edges, motes drifting along it, fading
## in over the first half metre so it seems to leave the mirror rather than start at it.
const BEAM_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform float len = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float core = smoothstep(0.35, 0.0, x);
	float soft = smoothstep(1.0, 0.0, x) * 0.35;
	float ends = smoothstep(0.0, 0.5, UV.y) * smoothstep(len, len - 0.3, UV.y);
	float motes = smoothstep(0.78, 0.95, n(vec2(UV.x * 3.0, UV.y * 2.2 - TIME * 1.4))) * 0.8;
	float flick = 0.88 + 0.12 * sin(TIME * 7.0 + UV.y * 3.0);
	vec3 col = vec3(1.0, 0.46, 0.12) * (core * 0.9 + soft + motes * soft * 2.0) * ends * flick;
	ALBEDO = col * 0.6;
}
"""

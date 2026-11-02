class_name CreatureMesh
extends RefCounted
## Organic procedural meshes for enemies: swept tubes (limbs, necks, tails, ribs, claws) and lumpy
## ellipsoids (skulls, bellies, humps), merged into ONE ArrayMesh per rig joint. A body is one draw
## call per joint instead of five-plus primitives, and it reads as flesh rather than stacked pipes.
## EnemyBody caches the result per (kind, joint), so every enemy of a kind shares the buffers.
##
## Vertex channels read by flesh.gdshader:
##   COLOR.rgb  local tint (gums redder, rags darker, scars paler)
##   COLOR.a    1 = flesh, 0 = bone / claw / tooth (glossier, paler, no veins)
##   UV2.x      emission mask (eyes, glands, hollows)   UV2.y  rag mask (matte, no sheen)
##   UV         x = around the tube, y = metres along it (veins flow along limbs)
##
## Winding: Godot front faces are clockwise, i.e. cross(v1 - v0, v2 - v0) points INTO the surface
## (same convention bake_main.gd asserts for the terrain). _tri() enforces it against the known
## outward direction, so no part of a body can come out inside-out.

var _st := SurfaceTool.new()
var _pos := PackedVector3Array()
var _out := PackedVector3Array()
var _seed := 0.0


func _init(seed_value := 0) -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_seed = float(seed_value) * 17.31


func commit() -> ArrayMesh:
	_st.generate_tangents()
	return _st.commit()


# --- noise ------------------------------------------------------------------------------------

static func _hash(p: Vector3) -> float:
	var h := sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453
	return h - floorf(h)


func noise(p: Vector3) -> float:
	p += Vector3(_seed, _seed * 0.7, _seed * 1.3)
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector3(3.0, 3.0, 3.0) - f * 2.0)
	var x00 := lerpf(_hash(i), _hash(i + Vector3(1, 0, 0)), f.x)
	var x10 := lerpf(_hash(i + Vector3(0, 1, 0)), _hash(i + Vector3(1, 1, 0)), f.x)
	var x01 := lerpf(_hash(i + Vector3(0, 0, 1)), _hash(i + Vector3(1, 0, 1)), f.x)
	var x11 := lerpf(_hash(i + Vector3(0, 1, 1)), _hash(i + Vector3(1, 1, 1)), f.x)
	return lerpf(lerpf(x00, x10, f.y), lerpf(x01, x11, f.y), f.z)


func fbm(p: Vector3) -> float:
	return noise(p) * 0.62 + noise(p * 2.13 + Vector3(5.2, 1.3, 7.7)) * 0.38


# --- primitives -------------------------------------------------------------------------------

func _vert(p: Vector3, n: Vector3, uv: Vector2, col: Color, bone: float, glow: float, rag: float) -> int:
	_st.set_normal(n)
	_st.set_uv(uv)
	_st.set_uv2(Vector2(glow, rag))
	_st.set_color(Color(col.r, col.g, col.b, 1.0 - bone))
	_st.add_vertex(p)
	_pos.append(p)
	_out.append(n)
	return _pos.size() - 1


func _tri(a: int, b: int, c: int) -> void:
	var outward := _out[a] + _out[b] + _out[c]
	var face := (_pos[b] - _pos[a]).cross(_pos[c] - _pos[a])
	_st.add_index(a)
	if face.dot(outward) > 0.0:
		_st.add_index(c)
		_st.add_index(b)
	else:
		_st.add_index(b)
		_st.add_index(c)


## Sweep a ring along `pts` with per-point `radii` (0 radius = sharp point: claws, spikes, teeth).
## `squash` flattens the cross-section (x = along the frame normal, y = binormal).
func tube(pts: PackedVector3Array, radii: PackedFloat32Array, sides := 9, col := Color.WHITE,
		bone := 0.0, lumps := 0.12, glow := 0.0, squash := Vector2.ONE, rag := 0.0) -> void:
	var n := pts.size()
	if n < 2 or radii.size() != n:
		push_error("CreatureMesh.tube: need >= 2 points and one radius per point")
		return
	var tans: Array[Vector3] = []
	for i in n:
		tans.append((pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized())
	var refv := Vector3.UP if absf(tans[0].dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var nrm := tans[0].cross(refv).normalized()
	var start := _pos.size()
	var along := 0.0
	for i in n:
		if i > 0:
			var axis := tans[i - 1].cross(tans[i])
			if axis.length_squared() > 1e-10:
				nrm = nrm.rotated(axis.normalized(), tans[i - 1].angle_to(tans[i]))
			along += pts[i].distance_to(pts[i - 1])
		var bin := tans[i].cross(nrm).normalized()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			var dir := nrm * cos(a) * squash.x + bin * sin(a) * squash.y
			var d := dir.normalized()
			var bump := 1.0 + lumps * (fbm(pts[i] * 9.0 + d * 1.7) - 0.5) * 2.0
			_vert(pts[i] + dir * radii[i] * bump, d, Vector2(float(s) / float(sides), along), col, bone, glow, rag)
	for i in n - 1:
		for s in sides:
			var a0 := start + i * sides + s
			var a1 := start + i * sides + (s + 1) % sides
			var b0 := a0 + sides
			var b1 := a1 + sides
			_tri(a0, b0, a1)
			_tri(a1, b0, b1)
	# round the ends that still have width
	for end: int in [0, n - 1]:
		if radii[end] <= 0.002:
			continue
		var t: Vector3 = tans[end] * (-1.0 if end == 0 else 1.0)
		var tip := _vert(pts[end] + t * radii[end] * 0.55, t, Vector2(0.5, along if end > 0 else 0.0), col, bone, glow, rag)
		var ring: int = start + end * sides
		for s in sides:
			_tri(tip, ring + s, ring + (s + 1) % sides)


## Lumpy ellipsoid. `basis` orients it; `radii` are the semi-axes before orientation.
func blob(center: Vector3, radii: Vector3, basis := Basis.IDENTITY, col := Color.WHITE, bone := 0.0,
		lumps := 0.1, glow := 0.0, rings := 8, segs := 12, rag := 0.0) -> void:
	var start := _pos.size()
	for r in rings + 1:
		var v := float(r) / float(rings)
		var phi := PI * v
		for s in segs:
			var th := TAU * float(s) / float(segs)
			var unit := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var bump := 1.0 + lumps * (fbm(center * 3.0 + unit * 2.3) - 0.5) * 2.0
			var p := center + basis * (unit * radii * bump)
			var nn := (basis * Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)).normalized()
			_vert(p, nn, Vector2(float(s) / float(segs), v), col, bone, glow, rag)
	for r in rings:
		for s in segs:
			var a0 := start + r * segs + s
			var a1 := start + r * segs + (s + 1) % segs
			var b0 := a0 + segs
			var b1 := a1 + segs
			_tri(a0, b0, a1)
			_tri(a1, b0, b1)


# --- composites -------------------------------------------------------------------------------

## A curved claw/talon/spike: thick base to a sharp point, bent toward `bend`.
func claw(base: Vector3, dir: Vector3, length: float, width: float, bend := Vector3.ZERO, col := Color(0.9, 0.85, 0.72)) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 5:
		var t := float(k) / 4.0
		pts.append(base + dir * length * t + bend * length * t * t)
		radii.append(width * (1.0 - t) * (1.0 - t * 0.3))
	radii[4] = 0.0
	tube(pts, radii, 6, col, 1.0, 0.0)


## A limb segment from a to b with a slight organic arc and a swollen joint at a.
func limb(a: Vector3, b: Vector3, r0: float, r1: float, col := Color.WHITE, arc := Vector3.ZERO, lumps := 0.14) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 6:
		var t := float(k) / 5.0
		pts.append(a.lerp(b, t) + arc * sin(t * PI))
		var swell := 1.0 + 0.28 * exp(-t * t * 40.0) + 0.22 * exp(-pow(t - 0.32, 2.0) * 22.0) - 0.08 * exp(-pow(t - 0.85, 2.0) * 40.0)
		radii.append(lerpf(r0, r1, t) * swell)
	tube(pts, radii, 9, col, 0.0, lumps)


## Spine/vertebra bumps along a polyline (bone).
func vertebrae(pts: PackedVector3Array, size: float, count: int, out_dir: Vector3) -> void:
	for k in count:
		var t := float(k) / float(maxi(count - 1, 1))
		var f := t * float(pts.size() - 1)
		var i := mini(int(f), pts.size() - 2)
		var p := pts[i].lerp(pts[i + 1], f - float(i))
		var s := size * (1.0 - 0.45 * absf(t - 0.4))
		blob(p + out_dir * s * 0.4, Vector3(s * 0.9, s * 0.7, s), Basis.IDENTITY, Color(0.92, 0.88, 0.78), 1.0, 0.05, 0.0, 4, 6)


## Rib arc: from the spine around one side toward the front.
func rib(spine: Vector3, side: float, radius: float, height: float, thick: float, reach := 0.8) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 7:
		var t := float(k) / 6.0
		var a := t * PI * reach
		pts.append(spine + Vector3(side * sin(a) * radius, height * (1.0 - t) * 0.3 - t * 0.04, cos(a) * radius * 0.9 - radius * 0.9))
		radii.append(thick * (1.0 - t * 0.5))
	tube(pts, radii, 5, Color(0.9, 0.86, 0.75), 1.0, 0.05)

extends RefCounted
## Mesh builder for the tavern dwarves (DwarfRig). Like CreatureMesh (swept tubes, lumpy
## ellipsoids) but made for a textured, soft-skinned character:
##   - UV in metres (u around the part, v along it), so the detail textures keep one texel density
##   - UV2.x = material layer (MAT_*: picks the detail texture + roughness in dwarf.gdshader)
##   - COLOR.rgb = the part's tint, COLOR.a = baked ambient occlusion (crevices, under the beard)
##   - up to two bones per vertex: `bind(a)` binds rigidly, `bind_blend(a, b, p0, p1)` fades from a
##     to b along the segment p0 -> p1 (elbows, knees, the beard from jaw to chest)
## Every primitive also writes its volume into a coarse occupancy grid; `bake_ao()` then darkens
## each vertex by how much of its outward hemisphere is filled (beard on chest, arm on flank...).
## Load by path: const DwarfMesh := preload("res://core/npc/dwarf_mesh.gd")

const MAT_SKIN := 0
const MAT_CLOTH := 1        ## wool weave
const MAT_LINEN := 2        ## fine weave: shirts, aprons, patches
const MAT_LEATHER := 3
const MAT_HAIR := 4
const MAT_METAL := 5
const MAT_WOOD := 6
const MAT_FOAM := 7
const MAT_EYE := 8
const MAT_FUR := 9
const LAYERS := 10

const CELL := 0.0125                     ## AO grid cell (m); models pass: was 0.025, too coarse to see hair lying 6 mm off a scalp
const GRID_MIN := Vector3(-0.6, -0.05, -0.75)
const GRID_N := Vector3i(96, 128, 108)   ## covers x -0.6..0.6, y -0.05..1.55, z -0.75..0.6

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()
var _col := PackedColorArray()
var _bones := PackedInt32Array()
var _w := PackedFloat32Array()
var _idx := PackedInt32Array()
var _seed := 0.0
var _ba := 0
var _bb := 0
var _p0 := Vector3.ZERO
var _p1 := Vector3.ZERO
var _blend := false
var _occ := PackedByteArray()
var ao_strength := 1.0


func _init(seed_value := 0) -> void:
	_seed = float(seed_value) * 13.37
	_occ.resize(GRID_N.x * GRID_N.y * GRID_N.z)


func vertex_count() -> int:
	return _v.size()


# --- binding --------------------------------------------------------------------------------

func bind(bone: int) -> void:
	_ba = bone
	_bb = bone
	_blend = false


## Weight fades a -> b over the segment p0 -> p1 (smoothstep of the projection).
func bind_blend(a: int, b: int, p0: Vector3, p1: Vector3) -> void:
	_ba = a
	_bb = b
	_p0 = p0
	_p1 = p1
	_blend = a != b


func _weights(p: Vector3) -> Vector2:
	if not _blend:
		return Vector2(1.0, 0.0)
	var d := _p1 - _p0
	var t := clampf((p - _p0).dot(d) / maxf(d.length_squared(), 1e-6), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return Vector2(1.0 - t, t)


# --- noise ----------------------------------------------------------------------------------

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


# --- vertices -------------------------------------------------------------------------------

func _vert(p: Vector3, n: Vector3, uv: Vector2, col: Color, mat: int, ao := 1.0) -> int:
	_v.append(p)
	_n.append(n)
	_uv.append(uv)
	_uv2.append(Vector2(float(mat), 0.0))
	_col.append(Color(col.r, col.g, col.b, ao))
	var w := _weights(p)
	_bones.append_array(PackedInt32Array([_ba, _bb, 0, 0]))
	_w.append_array(PackedFloat32Array([w.x, w.y, 0.0, 0.0]))
	return _v.size() - 1


## A vertex with explicit skinning (bone a, bone b, share of b): the sculpted face (npc_face.gd)
## weights its own vertices (lower lip and chin on the jaw, a slit along the mouth line).
func vert_w(p: Vector3, n: Vector3, uv: Vector2, col: Color, mat: int, ao: float, a: int, b: int, w: float) -> int:
	_v.append(p)
	_n.append(n)
	_uv.append(uv)
	_uv2.append(Vector2(float(mat), 0.0))
	_col.append(Color(col.r, col.g, col.b, ao))
	_bones.append_array(PackedInt32Array([a, b, 0, 0]))
	_w.append_array(PackedFloat32Array([1.0 - w, w, 0.0, 0.0]))
	return _v.size() - 1


func tri(a: int, b: int, c: int) -> void:
	_tri(a, b, c)


func occ_ellipsoid(c: Vector3, r: Vector3) -> void:
	_occ_ellipsoid(c, r, Basis.IDENTITY)


func _tri(a: int, b: int, c: int) -> void:
	# Godot front faces are clockwise: cross(b - a, c - a) must point INTO the surface
	var outward := _n[a] + _n[b] + _n[c]
	var face := (_v[b] - _v[a]).cross(_v[c] - _v[a])
	_idx.append(a)
	if face.dot(outward) > 0.0:
		_idx.append(c)
		_idx.append(b)
	else:
		_idx.append(b)
		_idx.append(c)


# --- primitives -------------------------------------------------------------------------------

## Swept tube. opts: lumps (0.06), squash (Vector2), folds [amp, count] (pleats round the tube),
## ripple [amp, freq] (rings along it: sleeve bunching, knee wrinkles), caps (true), ao (1.0),
## shade (0.0: darken the underside by this much), twist (rad along the length)
func tube(pts: PackedVector3Array, radii: PackedFloat32Array, sides: int, col: Color, mat: int, opts := {}) -> void:
	var n := pts.size()
	if n < 2 or radii.size() != n:
		push_error("DwarfMesh.tube: need >= 2 points and one radius per point")
		return
	var lumps: float = opts.get("lumps", 0.04)
	var squash: Vector2 = opts.get("squash", Vector2.ONE)
	var folds: Vector2 = opts.get("folds", Vector2.ZERO)
	var ripple: Vector2 = opts.get("ripple", Vector2.ZERO)
	var ao: float = opts.get("ao", 1.0)
	var twist: float = opts.get("twist", 0.0)
	var refv: Vector3 = opts.get("ref", Vector3.ZERO)
	var tans: Array[Vector3] = []
	for i in n:
		tans.append((pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized())
	if refv == Vector3.ZERO:
		refv = Vector3.UP if absf(tans[0].dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var nrm := tans[0].cross(refv).normalized()
	var start := _v.size()
	var along := 0.0
	var mean_r := 0.0
	for r in radii:
		mean_r += r
	mean_r /= float(n)
	var circ := TAU * maxf(mean_r, 0.004)
	var total := 0.0
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
	for i in n:
		if i > 0:
			var axis := tans[i - 1].cross(tans[i])
			if axis.length_squared() > 1e-10:
				nrm = nrm.rotated(axis.normalized(), tans[i - 1].angle_to(tans[i]))
			along += pts[i].distance_to(pts[i - 1])
		var bin := tans[i].cross(nrm).normalized()
		var tw := twist * (along / maxf(total, 1e-4))
		var rip := 1.0 + ripple.x * sin(along * ripple.y * TAU)
		for s in sides + 1:
			var a := TAU * float(s) / float(sides) + tw
			var dir := nrm * cos(a) * squash.x + bin * sin(a) * squash.y
			var d := dir.normalized()
			var bump := 1.0 + lumps * (fbm(pts[i] * 9.0 + d * 1.7) - 0.5) * 2.0
			bump *= 1.0 + folds.x * (sin(a * folds.y + fbm(pts[i] * 5.0) * 2.0) * 0.5 + 0.5 * sin(a * folds.y * 2.0 + 1.3) * 0.4)
			bump *= rip
			var p := pts[i] + dir * radii[i] * bump
			var sh := 1.0 - 0.18 * clampf(-d.y, 0.0, 1.0)
			_vert(p, d, Vector2(float(s) / float(sides) * circ, along), col, mat, ao * sh)
		_occ_capsule(pts[maxi(i - 1, 0)], pts[i], radii[i] * 0.92 * minf(squash.x, squash.y))
	for i in n - 1:
		for s in sides:
			var a0 := start + i * (sides + 1) + s
			var a1 := a0 + 1
			var b0 := a0 + sides + 1
			var b1 := a1 + sides + 1
			_tri(a0, b0, a1)
			_tri(a1, b0, b1)
	if not opts.get("caps", true):
		return
	for end: int in [0, n - 1]:
		if radii[end] <= 0.002:
			continue
		var t: Vector3 = tans[end] * (-1.0 if end == 0 else 1.0)
		var tip := _vert(pts[end] + t * radii[end] * 0.5, t, Vector2(0.5 * circ, along if end > 0 else -radii[end] * 0.5), col, mat, ao)
		var ring: int = start + end * (sides + 1)
		for s in sides:
			_tri(tip, ring + s, ring + s + 1)


## Lumpy ellipsoid. opts: lumps (0.05), rings (8), segs (12), phi [from, to] (0..1 of pole to
## pole: a partial shell, e.g. an eyelid), folds [amp, count, from_v] (vertical pleats below from_v),
## ao (1.0), occ (true: fills the AO grid)
func blob(center: Vector3, radii: Vector3, basis: Basis, col: Color, mat: int, opts := {}) -> void:
	var lumps: float = opts.get("lumps", 0.05)
	var rings: int = opts.get("rings", 8)
	var segs: int = opts.get("segs", 12)
	var phi: Vector2 = opts.get("phi", Vector2(0.0, 1.0))
	var folds: Vector3 = opts.get("folds", Vector3.ZERO)
	var ao: float = opts.get("ao", 1.0)
	var start := _v.size()
	var circ := TAU * (radii.x + radii.z) * 0.5
	var height := PI * radii.y
	for r in rings + 1:
		var v := lerpf(phi.x, phi.y, float(r) / float(rings))
		var ph := PI * v
		for s in segs + 1:
			var th := TAU * float(s) / float(segs)
			var unit := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var bump := 1.0 + lumps * (fbm(center * 3.0 + unit * 2.3) - 0.5) * 2.0
			if folds.x > 0.0 and v > folds.z:
				var k := smoothstep(folds.z, minf(folds.z + 0.25, 1.0), v)
				bump *= 1.0 + folds.x * k * (sin(th * folds.y + fbm(center + unit) * 3.0) * 0.5 + 0.5)
			var p := center + basis * (unit * radii * bump)
			var nn := (basis * Vector3(unit.x / radii.x, unit.y / radii.y, unit.z / radii.z)).normalized()
			var sh := 1.0 - 0.2 * clampf(-nn.y, 0.0, 1.0)
			_vert(p, nn, Vector2(float(s) / float(segs) * circ, v * height), col, mat, ao * sh)
	for r in rings:
		for s in segs:
			var a0 := start + r * (segs + 1) + s
			var a1 := a0 + 1
			var b0 := a0 + segs + 1
			var b1 := a1 + segs + 1
			_tri(a0, b0, a1)
			_tri(a1, b0, b1)
	if opts.get("occ", true) and phi == Vector2(0.0, 1.0):
		_occ_ellipsoid(center, radii * 0.92, basis)


## A vertical loft of elliptical rings (torsos, coat bodies): ring i at height ys[i], centred on
## (0, ys[i], zc[i]), radii rx[i] across and rz[i] front-back; `front` (per ring, may be empty) adds
## a forward bulge on the front half (bust, belly). One continuous skin instead of stacked blobs.
## opts: folds [amp, count] (vertical pleats, strongest toward the bottom), lumps, caps_top (false),
## ao (1.0), seam (a darker line of `seam` width down each side), wrinkle (horizontal creases amp)
func loft(ys: PackedFloat32Array, rx: PackedFloat32Array, rz: PackedFloat32Array, zc: PackedFloat32Array, front: PackedFloat32Array, sides: int, col: Color, mat: int, opts := {}) -> void:
	var n := ys.size()
	var folds: Vector2 = opts.get("folds", Vector2.ZERO)
	var lumps: float = opts.get("lumps", 0.01)
	var ao: float = opts.get("ao", 1.0)
	var wrinkle: float = opts.get("wrinkle", 0.0)
	var seam: float = opts.get("seam", 0.0)
	var P := PackedVector3Array()
	P.resize(n * (sides + 1))
	var y0 := ys[0]
	var y1 := ys[n - 1]
	for i in n:
		var tb := clampf((y1 - ys[i]) / maxf(y1 - y0, 1e-4), 0.0, 1.0)     # 0 top .. 1 bottom
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var dx := sin(a)
			var dz := -cos(a)
			var r := Vector2(rx[i] * dx, rz[i] * dz)
			if front.size() == n and dz < 0.0:
				r.y -= front[i] * pow(-dz, 2.0) * (1.0 - absf(dx) * 0.6)
			var bump := 1.0 + lumps * (fbm(Vector3(dx * 3.0, ys[i] * 6.0, dz * 3.0)) - 0.5) * 2.0
			bump *= 1.0 + folds.x * tb * (sin(a * folds.y + fbm(Vector3(a, ys[i] * 3.0, 0.0)) * 2.0) * 0.5 + 0.5)
			bump *= 1.0 - wrinkle * pow(maxf(0.0, sin(ys[i] * 90.0 + dx * 2.0)), 6.0) * (1.0 - tb * 0.5)
			P[i * (sides + 1) + s] = Vector3(r.x * bump, ys[i], zc[i] + r.y * bump)
	var start := _v.size()
	var circ := 0.0
	for s in sides:
		circ += P[s].distance_to(P[s + 1])
	var along := 0.0
	for i in n:
		if i > 0:
			along += absf(ys[i] - ys[i - 1])
		for s in sides + 1:
			var k := i * (sides + 1) + s
			var sp := s + 1 if s < sides else 1
			var sm := s - 1 if s > 0 else sides - 1
			var du := P[i * (sides + 1) + sp] - P[i * (sides + 1) + sm]
			var dv := P[mini(i + 1, n - 1) * (sides + 1) + s] - P[maxi(i - 1, 0) * (sides + 1) + s]
			var nn := du.cross(dv).normalized()
			var outward := Vector3(P[k].x, 0.0, P[k].z - zc[i])
			if nn.dot(outward) < 0.0:
				nn = -nn
			var a2 := TAU * float(s) / float(sides)
			var c2 := col
			if seam > 0.0 and absf(absf(sin(a2)) - 1.0) < seam:
				c2 = col.darkened(0.3)
			var sh := 1.0 - 0.18 * clampf(-nn.y, 0.0, 1.0)
			_vert(P[k], nn, Vector2(float(s) / float(sides) * circ, along), c2, mat, ao * sh)
		_occ_ellipsoid(Vector3(0, ys[i], zc[i]), Vector3(rx[i], 0.03, rz[i]) * 0.92, Basis.IDENTITY)
	for i in n - 1:
		for s in sides:
			var a0 := start + i * (sides + 1) + s
			var a1 := a0 + 1
			var b0 := a0 + sides + 1
			var b1 := a1 + sides + 1
			_tri(a0, b0, a1)
			_tri(a1, b0, b1)


## A closed ring (torus) through `pts` treated as a loop: belts, hoops, cuffs, rims.
func ring(center: Vector3, radius: Vector2, thick: float, height: float, basis: Basis, col: Color, mat: int, sides := 20, opts := {}) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		pts.append(center + basis * Vector3(cos(a) * radius.x, 0.0, sin(a) * radius.y))
		radii.append(thick)
	var o := opts.duplicate()
	o["caps"] = false
	o["squash"] = Vector2(height / thick, 1.0) if height > 0.0 else Vector2.ONE
	o["ref"] = basis.y
	tube(pts, radii, int(o.get("ring_sides", 6)), col, mat, o)


## Two-sided cloth from a (cols+1) x (rows+1) grid of points (row-major); `out` = which way the
## front faces (normals are flipped to agree with it); the back is `t` behind the front.
func sheet(grid: Array[Vector3], cols: int, rows: int, col: Color, mat: int, t: float, out: Vector3) -> void:
	var w := cols + 1
	var nrm: Array[Vector3] = []
	for r in rows + 1:
		for c in w:
			var i := r * w + c
			var du: Vector3 = grid[r * w + mini(c + 1, cols)] - grid[r * w + maxi(c - 1, 0)]
			var dv: Vector3 = grid[mini(r + 1, rows) * w + c] - grid[maxi(r - 1, 0) * w + c]
			var n := du.cross(dv).normalized()
			if n.dot(out) < 0.0:
				n = -n
			nrm.append(n)
	for face in 2:
		var start := _v.size()
		var sgn := 1.0 if face == 0 else -1.0
		var vlen := 0.0
		for r in rows + 1:
			if r > 0:
				vlen += grid[r * w].distance_to(grid[(r - 1) * w])
			var ulen := 0.0
			for c in w:
				var i := r * w + c
				if c > 0:
					ulen += grid[i].distance_to(grid[i - 1])
				var p: Vector3 = grid[i] - nrm[i] * (t if face == 1 else 0.0)
				_vert(p, nrm[i] * sgn, Vector2(ulen, vlen), col.darkened(0.06 * float(face)), mat, 1.0 - 0.15 * float(face))
		for r in rows:
			for c in cols:
				var a0 := start + r * w + c
				_tri(a0, a0 + w, a0 + 1)
				_tri(a0 + 1, a0 + w, a0 + w + 1)


## A tapered strand of hair from `root` following `dir` with gravity and curl: the beard is laid
## from dozens of these. `w` = root radius.
func strand(root: Vector3, dir: Vector3, length: float, w: float, col: Color, curl := Vector3.ZERO, sag := 0.5, seg := 5, sides := 4) -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var p := root
	var d := dir.normalized()
	var step := length / float(seg)
	for i in seg + 1:
		var t := float(i) / float(seg)
		pts.append(p)
		radii.append(w * (1.0 - t * 0.85))
		d = (d + Vector3.DOWN * sag * step * 4.0 + curl * step * 6.0).normalized()
		p += d * step
	tube(pts, radii, sides, col, MAT_HAIR, {"lumps": 0.0, "squash": Vector2(1.0, 0.6), "ao": 0.92})


## Flattened plait: alternating lobes down a path, the classic dwarf braid.
func braid(pts: PackedVector3Array, w: float, col: Color, lobes := 7) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	for k in lobes:
		var t := (float(k) + 0.5) / float(lobes)
		var p := _along(pts, t * total)
		var tg := (_along(pts, minf(t * total + 0.01, total)) - _along(pts, maxf(t * total - 0.01, 0.0))).normalized()
		var side := tg.cross(Vector3.BACK).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var s := 1.0 if k % 2 == 0 else -1.0
		var r := w * (1.0 - t * 0.35)
		var b := Basis(side.rotated(tg, 0.0), tg, side.cross(tg).normalized()).orthonormalized()
		b = b * Basis(Vector3.BACK, s * 0.5)
		blob(p + side * s * r * 0.35, Vector3(r * 0.8, total / float(lobes) * 0.75, r * 0.6), b, col.lightened(0.04 * s), MAT_HAIR, {"lumps": 0.0, "rings": 5, "segs": 8, "ao": 0.9})


static func _along(pts: PackedVector3Array, dist: float) -> Vector3:
	var acc := 0.0
	for i in range(1, pts.size()):
		var l := pts[i].distance_to(pts[i - 1])
		if acc + l >= dist:
			return pts[i - 1].lerp(pts[i], (dist - acc) / maxf(l, 1e-5))
		acc += l
	return pts[pts.size() - 1]


# --- ambient occlusion ------------------------------------------------------------------------

func _cell(p: Vector3) -> int:
	var c := ((p - GRID_MIN) / CELL).floor()
	if c.x < 0 or c.y < 0 or c.z < 0 or c.x >= GRID_N.x or c.y >= GRID_N.y or c.z >= GRID_N.z:
		return -1
	return int(c.x) + GRID_N.x * (int(c.y) + GRID_N.y * int(c.z))


func _occ_ellipsoid(c: Vector3, r: Vector3, b: Basis) -> void:
	var ext := maxf(r.x, maxf(r.y, r.z))
	if ext < CELL * 0.6:
		return
	var inv := b.inverse()
	var lo := c - Vector3.ONE * ext
	var x := lo.x
	while x <= c.x + ext:
		var y := lo.y
		while y <= c.y + ext:
			var z := lo.z
			while z <= c.z + ext:
				var q: Vector3 = inv * (Vector3(x, y, z) - c)
				if (q / r).length_squared() <= 1.0:
					var i := _cell(Vector3(x, y, z))
					if i >= 0:
						_occ[i] = 1
				z += CELL
			y += CELL
		x += CELL


func _occ_capsule(a: Vector3, b: Vector3, r: float) -> void:
	if r < CELL * 0.6:
		return
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3.ONE * r
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)) + Vector3.ONE * r
	var ab := b - a
	var l2 := maxf(ab.length_squared(), 1e-8)
	var x := lo.x
	while x <= hi.x:
		var y := lo.y
		while y <= hi.y:
			var z := lo.z
			while z <= hi.z:
				var p := Vector3(x, y, z)
				var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
				if p.distance_squared_to(a + ab * t) <= r * r:
					var i := _cell(p)
					if i >= 0:
						_occ[i] = 1
				z += CELL
			y += CELL
		x += CELL


## Hemisphere occlusion per vertex from the occupancy grid (rest pose), written into COLOR.a.
func bake_ao() -> void:
	var dirs: Array[Vector3] = []
	for i in 10:
		var phi := acos(1.0 - (float(i) + 0.5) / 10.0)      # upper hemisphere, cosine-ish spread
		var th := float(i) * 2.39996
		dirs.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)))
	var steps: Array[float] = [0.014, 0.035, 0.07, 0.13]   # models pass: a near probe for contact (hair on scalp, cuff on wrist)
	for vi in _v.size():
		var n := _n[vi]
		var t := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var bt := n.cross(t)
		var hit := 0.0
		var tot := 0.0
		var p := _v[vi] + n * (CELL * 0.6)
		for d in dirs:
			var w := Vector3(t * d.x + n * d.y + bt * d.z)
			var wgt := d.y
			for k in steps.size():
				var i := _cell(p + w * steps[k])
				tot += wgt
				if i >= 0 and _occ[i] == 1:
					hit += wgt * (1.0 if k < 3 else 0.6)
					break
		var occl := clampf(hit / maxf(tot, 1e-4) * 1.6, 0.0, 1.0) * ao_strength
		var c := _col[vi]
		c.a = c.a * (1.0 - 0.82 * occl)
		_col[vi] = c


# --- output -----------------------------------------------------------------------------------

func arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = _v
	a[Mesh.ARRAY_NORMAL] = _n
	a[Mesh.ARRAY_TEX_UV] = _uv
	a[Mesh.ARRAY_TEX_UV2] = _uv2
	a[Mesh.ARRAY_COLOR] = _col
	a[Mesh.ARRAY_BONES] = _bones
	a[Mesh.ARRAY_WEIGHTS] = _w
	a[Mesh.ARRAY_INDEX] = _idx
	# tangents for the detail normal maps (MikkTSpace through SurfaceTool keeps every channel)
	var st := SurfaceTool.new()
	st.create_from_arrays(a)
	st.generate_tangents()
	return st.commit_to_arrays()


## Plain (unskinned) mesh: props such as the served tankards.
func commit_static() -> ArrayMesh:
	var a := arrays()
	a[Mesh.ARRAY_BONES] = null
	a[Mesh.ARRAY_WEIGHTS] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m

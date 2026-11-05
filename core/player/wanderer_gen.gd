extends RefCounted
## The wanderer's generated gear (meshes only; materials come from wanderer_piece.gd). Everything is
## built here from code, deterministic, and cached through GenCache, so a warm load just reads the
## meshes. Each part is authored in its socket's local space (CharacterRig: limbs hang along -Y from
## their joint, the body faces -Z, +X is the wanderer's right). Surfaces are named for their material:
## cloth, lining, trim, tunic, tunic_trim, leather, sole, iron, wood, grip, pants, wrap.
##
## Parts:
##   coat     chest   long split-front coat: shaped torso, cinched waist, folds that deepen to the hem,
##                    an embroidered placket and hem band, torn hem; the under-tunic in the split
##   mantle   chest   shoulder capelet with dagged edge and embroidered band
##   gear     chest   belt, buckle and tongue, baldric strap, belt pouch, charms, mantle clasp
##   hood     head    deep cowl with a rolled, overhanging brim and an embroidered face edge
##   tail     hood_peak  the hood's long drooping point (liripipe)
##   sleeve   shoulder   upper sleeve with a cap and bunching at the elbow
##   bell     elbow   flared forearm sleeve with dagged cuff and band
##   glove_r / glove_l  hand   leather fist round a bar (right: centred on the staff), cuff, knuckle plate
##   boot     foot    shaped last, sole and heel, shaft with turned cuff, straps and buckles
##   thigh / shin  hip / knee   trousers and wrapped shins
##   satchel  pelvis  hip bag with flap and buckle (its root is the strap pivot, the rig swings it)
##   staff    hand_r  carved, knotted shaft with rune columns, leather grip bound with cord, iron
##                    bands, a cup and a crown of thorned iron claws round the orb
##   orb      Orb     the orb (surface "orb", the swirl shader) and its two iron rings (orb-local)
##   lantern  hand_l  bail, cap, horn-glass drum ("glass", emissive), cage bars and foot
## Surfaces added for the merged body (wanderer_body.gd): strap (stitched leather: u across 0..1),
## staff (carved rune wood), cord, glass, orb.
## Load by path (no class_name): const WGen := preload("res://core/player/wanderer_gen.gd")

const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/player/wanderer_gen.gd"

# coat landmarks (chest space; the chest joint is 1.28 m above the feet at rest)
const Y_TOP := 0.30
const Y_HEM := -1.17
const BELT_Y := -0.29
const TRIM_W := 0.042
const BAND_HI := Y_HEM + 0.15
const BAND_LO := Y_HEM + 0.085
const COAT_KEYS := [
	[0.30, 0.095, 0.085, 0.004], [0.25, 0.17, 0.112, 0.008], [0.18, 0.235, 0.135, 0.01],
	[0.10, 0.255, 0.145, 0.006], [-0.02, 0.238, 0.146, 0.0], [-0.18, 0.205, 0.136, 0.0],
	[-0.29, 0.186, 0.126, 0.0], [-0.42, 0.212, 0.146, 0.004], [-0.65, 0.262, 0.185, 0.012],
	[-0.90, 0.315, 0.228, 0.02], [-1.17, 0.37, 0.27, 0.03],
]
const MANTLE_KEYS := [
	[0.305, 0.112, 0.1, 0.008], [0.28, 0.175, 0.13, 0.01], [0.24, 0.272, 0.172, 0.012],
	[0.19, 0.335, 0.2, 0.01], [0.12, 0.368, 0.222, 0.008], [0.05, 0.388, 0.238, 0.01], [-0.06, 0.405, 0.252, 0.014],
]
const HOOD_KEYS := [
	[0.275, 0.025, 0.03, 0.06], [0.25, 0.08, 0.1, 0.05], [0.21, 0.122, 0.142, 0.035],
	[0.14, 0.148, 0.168, 0.02], [0.06, 0.156, 0.178, 0.012], [-0.03, 0.152, 0.172, 0.014],
	[-0.09, 0.158, 0.168, 0.018], [-0.14, 0.172, 0.158, 0.02],
]

static var _mem := {}


static func mesh(part: String) -> ArrayMesh:
	if _mem.has(part):
		return _mem[part]
	var key := "wanderer|" + part
	var m := GenCache.load_mesh(key, SELF)
	if m == null:
		m = build(part)
		GenCache.save_mesh(key, SELF, m)
	_mem[part] = m
	return m


static func build(part: String) -> ArrayMesh:
	var S := {}
	match part:
		"coat":
			_coat(S)
			_tunic(S)
		"mantle":
			_mantle(S)
		"gear":
			_gear(S)
		"hood":
			_hood(S)
		"tail":
			_tail(S)
		"sleeve":
			_sleeve(S)
		"bell":
			_bell(S)
		"glove_r":
			_glove(S, false)
		"glove_l":
			_glove(S, true)
		"boot":
			_boot(S)
		"thigh":
			_thigh(S)
		"shin":
			_shin(S)
		"satchel":
			_satchel(S)
		"staff":
			_staff(S)
		"orb":
			_orb(S)
		"lantern":
			_lantern(S)
		_:
			push_error("WandererGen: unknown part " + part)
	return _finish(S)


# --- mesh plumbing ----------------------------------------------------------------------------

static func _st(S: Dictionary, n: String) -> SurfaceTool:
	if not S.has(n):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		S[n] = st
	return S[n]


static func _finish(S: Dictionary) -> ArrayMesh:
	var m := ArrayMesh.new()
	for n: String in S:
		var st: SurfaceTool = S[n]
		st.index()
		st.generate_tangents()
		st.commit(m)
		m.surface_set_name(m.get_surface_count() - 1, n)
	return m


static func _tri(st: SurfaceTool, p: Array, n: Array, uv: Array) -> void:
	# wind so the face's front (Godot: clockwise) agrees with the given normals
	var order := [0, 1, 2]
	var avg: Vector3 = n[0] + n[1] + n[2]
	if ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[2] as Vector3) - (p[0] as Vector3)).dot(avg) > 0.0:
		order = [0, 2, 1]
	for k: int in order:
		st.set_normal(n[k])
		st.set_uv(uv[k])
		st.add_vertex(p[k])


## Emit a (nc+1) x (nr+1) vertex grid (i = r * (nc + 1) + c) as quads, each face into the surface
## pick(c, r) names ("" skips it). UVs per surface from uvs[name] (or uvs["*"]).
static func _grid(S: Dictionary, P: PackedVector3Array, N: PackedVector3Array, uvs: Dictionary, nc: int, nr: int, pick: Callable, push := {}) -> void:
	var w := nc + 1
	for r in nr:
		for c in nc:
			var s: String = pick.call(c, r)
			if s == "":
				continue
			var st := _st(S, s)
			var UV: PackedVector2Array = uvs.get(s, uvs.get("*"))
			var off: float = push.get(s, 0.0)
			var q := [r * w + c, r * w + c + 1, (r + 1) * w + c + 1, (r + 1) * w + c]
			var p := []
			var n := []
			var t := []
			for id: int in q:
				p.append(P[id] + N[id] * off)
				n.append(N[id])
				t.append(UV[id])
			_tri(st, [p[0], p[1], p[2]], [n[0], n[1], n[2]], [t[0], t[1], t[2]])
			_tri(st, [p[0], p[2], p[3]], [n[0], n[2], n[3]], [t[0], t[2], t[3]])


## Smooth normals of a grid by central differences, oriented along out(p).
static func _normals(P: PackedVector3Array, nc: int, nr: int, closed: Array, out: Callable) -> PackedVector3Array:
	var w := nc + 1
	var N := PackedVector3Array()
	N.resize(P.size())
	for r in nr + 1:
		for c in w:
			var cl := maxi(c - 1, 0)
			var cr := mini(c + 1, nc)
			if closed[r]:
				if c == 0:
					cl = nc - 1
				if c == nc:
					cr = 1
			var du := P[r * w + cr] - P[r * w + cl]
			var dv := P[mini(r + 1, nr) * w + c] - P[maxi(r - 1, 0) * w + c]
			var n := du.cross(dv)
			var o: Vector3 = out.call(P[r * w + c])
			if n.length_squared() < 1e-14:
				n = o
			n = n.normalized()
			if n.dot(o) < 0.0:
				n = -n
			N[r * w + c] = n
	return N


## UVs in metres: u = arc length along each row, v = arc length down each column.
static func _arc_uv(P: PackedVector3Array, nc: int, nr: int) -> PackedVector2Array:
	var w := nc + 1
	var UV := PackedVector2Array()
	UV.resize(P.size())
	var vacc := PackedFloat32Array()
	vacc.resize(w)
	for r in nr + 1:
		var u := 0.0
		for c in w:
			var i := r * w + c
			if c > 0:
				u += P[i].distance_to(P[i - 1])
			if r > 0:
				vacc[c] += P[i].distance_to(P[i - w])
			UV[i] = Vector2(u, vacc[c])
	return UV


## Monotone-ish cubic through profile keys [[y, a, b, c...], ...] sorted by descending y.
static func _profile(keys: Array, y: float) -> PackedFloat32Array:
	var n := keys.size()
	var out := PackedFloat32Array()
	var dims := (keys[0] as Array).size() - 1
	out.resize(dims)
	if y >= float(keys[0][0]):
		for d in dims:
			out[d] = float(keys[0][d + 1])
		return out
	if y <= float(keys[n - 1][0]):
		for d in dims:
			out[d] = float(keys[n - 1][d + 1])
		return out
	var i := 0
	while i < n - 2 and y < float(keys[i + 1][0]):
		i += 1
	var y1 := float(keys[i][0])
	var y2 := float(keys[i + 1][0])
	var t := (y - y1) / (y2 - y1)
	var i0 := maxi(i - 1, 0)
	var i3 := mini(i + 2, n - 1)
	for d in dims:
		var v0 := float(keys[i0][d + 1])
		var v1 := float(keys[i][d + 1])
		var v2 := float(keys[i + 1][d + 1])
		var v3 := float(keys[i3][d + 1])
		var m1 := (v2 - v0) / (float(keys[i0][0]) - y2) * (y1 - y2) if i0 != i + 1 else 0.0
		var m2 := (v3 - v1) / (y1 - float(keys[i3][0])) * (y1 - y2) if i3 != i else 0.0
		var t2 := t * t
		var t3 := t2 * t
		out[d] = (2.0 * t3 - 3.0 * t2 + 1.0) * v1 + (t3 - 2.0 * t2 + t) * m1 + (-2.0 * t3 + 3.0 * t2) * v2 + (t3 - t2) * m2
	return out


static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + 78.233) * 43758.5453, 1.0)


## Rounded ridges: soft valleys, fuller crests (how heavy wool folds).
static func _ridge(f: float) -> float:
	return signf(f) * pow(absf(f), 0.75)


static func _ellipse_n(th: float, rx: float, rz: float) -> Vector3:
	return Vector3(sin(th) * rz, 0.0, -cos(th) * rx).normalized()


## A tube along a polyline with per-point radius (closed ring of `sides`), capped at the end.
static func _tube(S: Dictionary, surf: String, pts: Array, radii: Array, sides: int, cap_end := true, uv_len := 1.0) -> void:
	var nr := pts.size() - 1
	var P := PackedVector3Array()
	var UV := PackedVector2Array()
	var prev_side := Vector3.ZERO
	var along := 0.0
	for r in pts.size():
		var p: Vector3 = pts[r]
		var t: Vector3
		if r == 0:
			t = (pts[1] as Vector3) - p
		elif r == nr:
			t = p - (pts[r - 1] as Vector3)
		else:
			t = (pts[r + 1] as Vector3) - (pts[r - 1] as Vector3)
		t = t.normalized()
		if r > 0:
			along += p.distance_to(pts[r - 1])
		var side := prev_side
		if side == Vector3.ZERO or absf(side.dot(t)) > 0.95:
			side = t.cross(Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT)
		side = (side - t * side.dot(t)).normalized()
		prev_side = side
		var up := t.cross(side)
		for c in sides + 1:
			var a := TAU * float(c) / float(sides)
			P.append(p + (side * cos(a) + up * sin(a)) * float(radii[r]))
			UV.append(Vector2(float(c) / float(sides), along / uv_len))
	var closed := []
	for r in nr + 1:
		closed.append(true)
	var centers := pts
	var w := sides + 1
	var N := _normals(P, sides, nr, closed, func(q: Vector3) -> Vector3:
		var best := 0
		var bd := 1e9
		for k in centers.size():
			var d := q.distance_squared_to(centers[k])
			if d < bd:
				bd = d
				best = k
		return (q - (centers[best] as Vector3)))
	_grid(S, P, N, {"*": UV}, sides, nr, func(_c: int, _r: int) -> String: return surf)
	if cap_end:
		var st := _st(S, surf)
		var tip: Vector3 = pts[nr]
		var tn := (tip - (pts[nr - 1] as Vector3)).normalized()
		for c in sides:
			_tri(st, [P[nr * w + c], P[nr * w + c + 1], tip + tn * float(radii[nr]) * 0.6], [tn, tn, tn], [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.05, 0.1)])


## Rounded box (a subdivided cube pushed out to rounded edges), centred at `at`, rotated by `basis`.
static func _rbox(S: Dictionary, surf: String, size: Vector3, rad: float, at: Vector3, basis := Basis.IDENTITY, segs := 4, unit_uv := false) -> void:
	var st := _st(S, surf)
	var inner := size * 0.5 - Vector3.ONE * rad
	inner = inner.max(Vector3.ZERO)
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var grid := []
		for i in segs + 1:
			var row := []
			for j in segs + 1:
				var q := nrm + a * (float(i) / float(segs) * 2.0 - 1.0) + b * (float(j) / float(segs) * 2.0 - 1.0)
				var p := q * size * 0.5
				var core := p.clamp(-inner, inner)
				var d := p - core
				var n := d.normalized() if d.length_squared() > 1e-12 else nrm
				var tuv := Vector2(float(j) / float(segs), float(i) / float(segs))
				row.append([at + basis * (core + n * rad), (basis * n).normalized(), tuv if unit_uv else tuv * maxf(size.x, maxf(size.y, size.z))])
			grid.append(row)
		for i in segs:
			for j in segs:
				var v00: Array = grid[i][j]
				var v01: Array = grid[i][j + 1]
				var v11: Array = grid[i + 1][j + 1]
				var v10: Array = grid[i + 1][j]
				_tri(st, [v00[0], v01[0], v11[0]], [v00[1], v01[1], v11[1]], [v00[2], v01[2], v11[2]])
				_tri(st, [v00[0], v11[0], v10[0]], [v00[1], v11[1], v10[1]], [v00[2], v11[2], v10[2]])


## A ring (torus) of radius R, tube r, in the plane with normal `axis`.
static func _torus(S: Dictionary, surf: String, at: Vector3, axis: Vector3, R: float, r: float, seg := 14, sides := 6) -> void:
	var a := axis.normalized()
	var u := a.cross(Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var v := a.cross(u)
	var pts := []
	var radii := []
	for i in seg + 1:
		var t := TAU * float(i) / float(seg)
		pts.append(at + (u * cos(t) + v * sin(t)) * R)
		radii.append(r)
	_tube(S, surf, pts, radii, sides, false)


# --- coat -------------------------------------------------------------------------------------

static func _coat_rows() -> PackedFloat32Array:
	var rows := PackedFloat32Array()
	var y := Y_TOP
	while y > BAND_HI + 0.012:
		rows.append(y)
		y -= 0.024 if y > -0.5 else 0.03
	for k in 3:
		rows.append(lerpf(BAND_HI, BAND_LO, float(k) / 2.0))
	for k in range(1, 5):
		rows.append(lerpf(BAND_LO, Y_HEM, float(k) / 4.0))
	return rows


static func _opening(y: float) -> float:
	# half-angle of the split at the front, 0 above the belt (closed: an embroidered placket)
	if y > BELT_Y - 0.03:
		return 0.0
	return 0.03 + 0.42 * smoothstep(BELT_Y - 0.03, Y_HEM + 0.05, y)


static func _tatter(th: float, seed: int) -> float:
	# + shortens the hem: torn notches; - lengthens: a few hanging tongues
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := 0.0
	for k in 17:
		var c := rng.randf() * TAU
		var wdt := rng.randf_range(0.035, 0.12)
		var dep := rng.randf_range(0.025, 0.07)
		var d := absf(wrapf(th - c, -PI, PI))
		t = maxf(t, dep * pow(maxf(0.0, 1.0 - d / wdt), 0.8))      # torn notches, V-shaped
	for k in 8:
		var c := rng.randf() * TAU
		var wdt := rng.randf_range(0.03, 0.07)
		var d := absf(wrapf(th - c, -PI, PI))
		t -= rng.randf_range(0.025, 0.06) * pow(maxf(0.0, 1.0 - d / wdt), 0.45)   # hanging tongues
	t += 0.01 * sin(th * 23.0 + 1.3) + 0.007 * sin(th * 41.0) + 0.006 * absf(sin(th * 67.0 + 0.4))
	return minf(t, 0.08)


## A point on the coat's outer surface at angle th (0 = front centre, +pi/2 = right) and height y.
static func coat_point(th: float, y: float, fold := true) -> Vector3:
	var k := _profile(COAT_KEYS, y)
	var rx := k[0]
	var rz := k[1]
	var p := Vector3(sin(th) * rx, y, -cos(th) * rz + k[2])
	if not fold:
		return p
	var n := _ellipse_n(th, rx, rz)
	var below := smoothstep(BELT_Y - 0.05, Y_HEM + 0.1, y)
	var back := 0.5 - 0.5 * cos(th)
	var phi := _opening(y)
	var edge := 1.0
	if phi > 0.0:
		edge = smoothstep(0.0, 0.32, minf(th - phi, TAU - phi - th))
	var amp := (0.005 + 0.04 * pow(below, 1.15)) * (0.6 + 0.4 * back) * edge
	var f := 0.55 * sin(6.0 * th + 0.8 + 1.5 * y) + 0.3 * sin(11.0 * th + 2.0 - 2.0 * y) + 0.16 * sin(17.0 * th + 0.4 + 3.0 * y) + 0.1 * sin(29.0 * th + 1.7 + 6.0 * y)
	# deep pipe folds: heavy wool hanging from the belt at the back and the hips
	var pipe := 0.0
	for c: float in [PI, PI - 0.42, PI + 0.42, 1.75, TAU - 1.75]:
		pipe += exp(-pow(wrapf(th - c, -PI, PI) / 0.085, 2.0))
	pipe *= 0.016 * pow(below, 0.9) * edge
	var gather := 0.0075 * exp(-pow((y - BELT_Y) / 0.07, 2.0)) * sin(26.0 * th) * smoothstep(0.012, 0.03, absf(y - BELT_Y))
	var drape := 0.005 * sin(5.0 * th + 1.0) * smoothstep(0.22, -0.05, y) * (1.0 - below)
	return p + n * (amp * _ridge(f) + pipe + gather + drape)


static func _coat(S: Dictionary) -> void:
	var rows := _coat_rows()
	var nr := rows.size() - 1
	var nc := 128
	var w := nc + 1
	var P := PackedVector3Array()
	var closed := []
	var band_r0 := -1
	var band_r1 := -1
	var lin_r0 := 0
	for r in nr + 1:
		var y := rows[r]
		if band_r0 < 0 and y <= BAND_HI + 0.001:
			band_r0 = r
		if band_r1 < 0 and y <= BAND_LO + 0.001:
			band_r1 = r
		if y > -0.24:
			lin_r0 = r + 1
		var phi := _opening(y)
		closed.append(phi == 0.0)
		var rr := _profile(COAT_KEYS, y)
		var ravg := (rr[0] + rr[1]) * 0.5
		var dt := TRIM_W / ravg
		for c in w:
			var th: float
			if c == 0:
				th = phi
			elif c == 1:
				th = phi + dt
			elif c == nc - 1:
				th = TAU - phi - dt
			elif c == nc:
				th = TAU - phi
			else:
				th = lerpf(phi + dt, TAU - phi - dt, float(c - 1) / float(nc - 2))
			var yy := y
			if y < BAND_LO:
				yy = y - _tatter(th, 1234) * (BAND_LO - y) / (BAND_LO - Y_HEM) * 1.0
			P.append(coat_point(th, yy))
	var out := func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z - 0.01)
	var N := _normals(P, nc, nr, closed, out)
	var UV := _arc_uv(P, nc, nr)
	# trim UVs: hem band across rows band_r0..band_r1, placket across columns 0-1 and nc-1..nc
	var TU := PackedVector2Array()
	TU.resize(P.size())
	for r in nr + 1:
		for c in w:
			var i := r * w + c
			if r >= band_r0 and r <= band_r1 and c > 0 and c < nc:
				TU[i] = Vector2(UV[i].x, clampf((rows[r] - BAND_HI) / (BAND_LO - BAND_HI), 0.0, 1.0))
			else:
				var across := 0.0 if (c == 0 or c == nc) else 1.0
				TU[i] = Vector2(UV[i].y, across)
	var pick := func(c: int, r: int) -> String:
		if r >= band_r0 and r < band_r1:
			return "trim"
		if (c == 0 or c == nc - 1) and r < band_r0:
			return "trim"
		return "cloth"
	_grid(S, P, N, {"cloth": UV, "trim": TU}, nc, nr, pick, {"trim": 0.0025})
	# lining: below the belt only (the inside above is never seen), offset in, facing inward
	var PL := PackedVector3Array()
	var NL := PackedVector3Array()
	PL.resize(P.size())
	NL.resize(P.size())
	for i in P.size():
		PL[i] = P[i] - N[i] * 0.009
		NL[i] = -N[i]
	_grid(S, PL, NL, {"*": UV}, nc, nr, func(_c: int, r: int) -> String: return "lining" if r >= lin_r0 else "")
	# edges: the hem and the two front edges below the belt, a cloth thickness
	var st := _st(S, "lining")
	for c in nc:
		var i0 := nr * w + c
		var i1 := i0 + 1
		var dn := Vector3.DOWN
		_tri(st, [P[i0], P[i1], PL[i1]], [dn, dn, dn], [UV[i0], UV[i1], UV[i1]])
		_tri(st, [P[i0], PL[i1], PL[i0]], [dn, dn, dn], [UV[i0], UV[i1], UV[i0]])
	for r in range(lin_r0, nr):
		for c: int in [0, nc]:
			var i0 := r * w + c
			var i1 := (r + 1) * w + c
			var side := (P[r * w + (1 if c == 0 else nc - 1)] - P[i0]).normalized() * -1.0
			_tri(st, [P[i0], P[i1], PL[i1]], [side, side, side], [UV[i0], UV[i1], UV[i1]])
			_tri(st, [P[i0], PL[i1], PL[i0]], [side, side, side], [UV[i0], UV[i1], UV[i0]])


## The under-tunic: a front panel inside the coat, seen through the split below the belt.
static func _tunic(S: Dictionary) -> void:
	var y0 := BELT_Y + 0.04
	var y1 := Y_HEM + 0.06
	var nr := 26
	var nc := 36
	var w := nc + 1
	var P := PackedVector3Array()
	var closed := []
	var band := 3
	for r in nr + 1:
		closed.append(false)
		var y := lerpf(y0, y1, float(r) / float(nr))
		for c in w:
			var th := lerpf(-1.75, 1.75, float(c) / float(nc))
			var k := _profile(COAT_KEYS, y)
			var rx := k[0] * 0.9 - 0.012
			var rz := k[1] * 0.86 - 0.012
			var p := Vector3(sin(th) * rx, y, -cos(th) * rz + k[2])
			var below := smoothstep(BELT_Y, Y_HEM, y)
			var f := 0.6 * sin(9.0 * th + 0.3 + 2.0 * y) + 0.4 * sin(15.0 * th + 1.1)
			p += _ellipse_n(th, rx, rz) * (0.003 + 0.012 * below) * _ridge(f)
			if r == nr:
				p.y += 0.012 * sin(th * 19.0) + 0.01 * sin(th * 7.0 + 2.0)
			P.append(p)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z))
	var UV := _arc_uv(P, nc, nr)
	var TU := PackedVector2Array()
	TU.resize(P.size())
	for r in nr + 1:
		for c in w:
			TU[r * w + c] = Vector2(UV[r * w + c].x, clampf(float(r - (nr - band)) / float(band), 0.0, 1.0))
	_grid(S, P, N, {"tunic": UV, "tunic_trim": TU}, nc, nr, func(_c: int, r: int) -> String: return "tunic_trim" if r >= nr - band else "tunic")


# --- mantle -----------------------------------------------------------------------------------

static func _mantle(S: Dictionary) -> void:
	var nr := 20
	var nc := 96
	var w := nc + 1
	var dags := 14
	var P := PackedVector3Array()
	var closed := []
	var band0 := 13
	var band1 := 15
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var dag_len := PackedFloat32Array()
	for k in dags:
		dag_len.append(rng.randf_range(0.75, 1.2))
	for r in nr + 1:
		closed.append(true)
		var v := float(r) / float(nr)
		for c in w:
			var th := TAU * float(c) / float(nc)
			var back := 0.5 - 0.5 * cos(th)
			var side := absf(sin(th))
			var bottom := 0.0 - 0.07 * back + 0.025 * side * (1.0 - back)
			# dags: pointed tongues below the band
			var fk := th / TAU * float(dags)
			var kk := int(fk) % dags
			var tri := 1.0 - absf(fposmod(fk, 1.0) - 0.5) * 2.0
			var dag := 0.055 * pow(tri, 1.6) * dag_len[kk]
			var vb := float(band1) / float(nr)
			var y := lerpf(0.305, bottom, v / vb) if v <= vb else lerpf(bottom, bottom - dag, (v - vb) / (1.0 - vb))
			var k := _profile(MANTLE_KEYS, y)
			var rx := k[0] + (0.012 if v > vb else 0.0) * (v - vb)
			var rz := k[1]
			var p := Vector3(sin(th) * rx, y, -cos(th) * rz + k[2])
			var lower := smoothstep(0.2, 0.0, y)
			var f := 0.6 * sin(9.0 * th + 0.5) + 0.4 * sin(16.0 * th + 1.7 + 4.0 * y)
			p += _ellipse_n(th, rx, rz) * (0.002 + 0.012 * lower) * _ridge(f)
			P.append(p)
	var out := func(p: Vector3) -> Vector3: return Vector3(p.x, 0.25, p.z)
	var N := _normals(P, nc, nr, closed, out)
	var UV := _arc_uv(P, nc, nr)
	var TU := PackedVector2Array()
	TU.resize(P.size())
	for r in nr + 1:
		for c in w:
			var i := r * w + c
			TU[i] = Vector2(UV[i].x, clampf(float(r - band0) / float(band1 - band0), 0.0, 1.0))
	_grid(S, P, N, {"cloth": UV, "trim": TU}, nc, nr, func(_c: int, r: int) -> String: return "trim" if r >= band0 and r < band1 else "cloth", {"trim": 0.002})
	var PL := PackedVector3Array()
	var NL := PackedVector3Array()
	for i in P.size():
		PL.append(P[i] - N[i] * 0.008)
		NL.append(-N[i])
	_grid(S, PL, NL, {"*": UV}, nc, nr, func(_c: int, r: int) -> String: return "lining" if r >= 4 else "")
	var st := _st(S, "lining")
	for c in nc:
		var i0 := nr * w + c
		var dn := Vector3.DOWN
		_tri(st, [P[i0], P[i0 + 1], PL[i0 + 1]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0 + 1]])
		_tri(st, [P[i0], PL[i0 + 1], PL[i0]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0]])


# --- hood -------------------------------------------------------------------------------------

static func _hood_phi(y: float) -> float:
	var e := (y - 0.05) / 0.145
	return 0.98 * sqrt(maxf(0.0, 1.0 - e * e)) if absf(e) < 1.0 else 0.0


## The hood in two layers: the outer cowl with its rolled brim and embroidered edge, and a recessed
## under-hood (a lighter layer) whose narrower opening frames the void face a little deeper in.
static func _hood(S: Dictionary) -> void:
	_hood_shell(S, 1.0, 1.0, 0.0, 0.275, -0.14, "cloth", "lining", true)
	_hood_shell(S, 0.9, 0.8, 0.014, 0.245, -0.1, "tunic", "lining", false)


static func _hood_shell(S: Dictionary, rs: float, open_k: float, zback: float, y_top: float, y_bot: float, outer: String, inner: String, brim: bool) -> void:
	var nr := 30 if brim else 20
	var nc := 72 if brim else 48
	var w := nc + 1
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		var y := lerpf(y_top, y_bot, float(r) / float(nr))
		var phi := _hood_phi(y) * open_k
		closed.append(phi == 0.0)
		var k := _profile(HOOD_KEYS, y)
		var rx := k[0] * rs
		var rz := k[1] * rs
		var ravg := (rx + rz) * 0.5
		var dt := minf(0.035 / maxf(ravg, 0.02), 0.5)
		for c in w:
			var th: float
			if c == 0:
				th = phi
			elif c == 1:
				th = phi + dt
			elif c == nc - 1:
				th = TAU - phi - dt
			elif c == nc:
				th = TAU - phi
			else:
				th = lerpf(phi + dt, TAU - phi - dt, float(c - 1) / float(nc - 2))
			var p := Vector3(sin(th) * rx, y, -cos(th) * rz + k[2] + zback)
			var front := minf(th, TAU - th)
			var e := front - phi
			if phi == 0.0:
				var dy := minf(absf(y - 0.195), absf(y + 0.095))
				e = front + dy * 3.0
			var roll := exp(-pow(e / 0.3, 2.0)) if brim else 0.0
			var top := smoothstep(0.02, 0.17, y)
			# the brim: near the face opening the cloth rolls forward and over, deepening the cowl
			p.z -= roll * (0.055 + 0.035 * top)
			p.y -= roll * 0.018 * top
			p += _ellipse_n(th, rx, rz) * roll * 0.014
			# folds, stronger in the drape over the shoulders and in a few creases at the back
			var drape := smoothstep(-0.02, -0.14, y)
			var f := 0.6 * sin(7.0 * th + 0.9) + 0.4 * sin(12.0 * th + 2.0 + 6.0 * y) + 0.15 * sin(19.0 * th + 9.0 * y)
			var crease := 0.006 * exp(-pow(wrapf(th - PI - 0.5, -PI, PI) / 0.07, 2.0)) * smoothstep(0.2, 0.0, y)
			crease += 0.005 * exp(-pow(wrapf(th - PI + 0.6, -PI, PI) / 0.06, 2.0)) * smoothstep(0.22, 0.02, y)
			p += _ellipse_n(th, rx, rz) * ((0.003 + 0.013 * drape) * _ridge(f) + crease) * (1.0 - roll)
			# a seam ridge over the crown
			p.y += 0.004 * exp(-pow(wrapf(th - PI, -PI, PI) / 0.12, 2.0)) * smoothstep(0.1, 0.24, y)
			P.append(p)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y * 0.4, p.z - 0.02))
	var UV := _arc_uv(P, nc, nr)
	var TU := PackedVector2Array()
	TU.resize(P.size())
	for r in nr + 1:
		for c in w:
			TU[r * w + c] = Vector2(UV[r * w + c].y, 0.0 if (c == 0 or c == nc) else 1.0)
	var pick := func(c: int, r: int) -> String:
		if brim and (not closed[r] or not closed[r + 1]):
			if c == 0 or c == nc - 1:
				return "trim"
		return outer
	_grid(S, P, N, {outer: UV, "trim": TU}, nc, nr, pick, {"trim": 0.002})
	var PL := PackedVector3Array()
	var NL := PackedVector3Array()
	for i in P.size():
		PL.append(P[i] - N[i] * 0.007)
		NL.append(-N[i])
	_grid(S, PL, NL, {"*": UV}, nc, nr, func(_c: int, _r: int) -> String: return inner)
	var st := _st(S, inner)
	for r in nr:
		if closed[r] and closed[r + 1]:
			continue
		for c: int in [0, nc]:
			var i0 := r * w + c
			var i1 := (r + 1) * w + c
			var side := (P[r * w + (1 if c == 0 else nc - 1)] - P[i0]).normalized() * -1.0
			_tri(st, [P[i0], P[i1], PL[i1]], [side, side, side], [UV[i0], UV[i1], UV[i1]])
			_tri(st, [P[i0], PL[i1], PL[i0]], [side, side, side], [UV[i0], UV[i1], UV[i0]])
	if not brim:
		# the under-hood's lower edge: a cloth thickness so it doesn't read as paper
		for c in nc:
			var i0 := nr * w + c
			var dn := Vector3.DOWN
			_tri(st, [P[i0], P[i0 + 1], PL[i0 + 1]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0 + 1]])
			_tri(st, [P[i0], PL[i0 + 1], PL[i0]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0]])


static func _tail(S: Dictionary) -> void:
	var pts := []
	var radii := []
	var p0 := Vector3(0, -0.05, 0.0)
	var p1 := Vector3(0, 0.035, 0.07)
	var p2 := Vector3(0.008, -0.05, 0.17)
	var p3 := Vector3(0.012, -0.21, 0.22)
	for i in 15:
		var t := float(i) / 14.0
		var a := p0.lerp(p1, t)
		var b := p1.lerp(p2, t)
		var cc := p2.lerp(p3, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(cc, t), t))
		radii.append(lerpf(0.05, 0.009, pow(t, 0.8)))
	_tube(S, "cloth", pts, radii, 12, true, 0.5)


# --- sleeves ----------------------------------------------------------------------------------

static func _sleeve(S: Dictionary) -> void:
	var keys := [[0.095, 0.0], [0.088, 0.035], [0.072, 0.06], [0.045, 0.078], [0.0, 0.088], [-0.12, 0.085], [-0.24, 0.08], [-0.33, 0.082], [-0.36, 0.088]]
	var nr := 24
	var nc := 28
	var w := nc + 1
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		closed.append(true)
		var y := lerpf(0.095, -0.36, float(r) / float(nr))
		var rad := _profile(keys, y)[0]
		for c in w:
			var th := TAU * float(c) / float(nc)
			var rx := rad
			var rz := rad * 0.88
			var p := Vector3(sin(th) * rx, y, -cos(th) * rz)
			var bunch := smoothstep(-0.16, -0.3, y)
			var f := 0.6 * sin(5.0 * th + 0.4 + 9.0 * y) + 0.4 * sin(8.0 * th + 1.2)
			var ring := sin(y * 70.0 + th) * 0.004 * bunch
			p += _ellipse_n(th, rx, rz) * ((0.002 + 0.006 * bunch) * _ridge(f) + ring) * smoothstep(0.06, 0.0, y)
			P.append(p)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, maxf(p.y, 0.0) * 2.0, p.z))
	_grid(S, P, N, {"*": _arc_uv(P, nc, nr)}, nc, nr, func(_c: int, _r: int) -> String: return "cloth")


static func _bell(S: Dictionary) -> void:
	var keys := [[0.04, 0.078], [-0.04, 0.083], [-0.13, 0.098], [-0.2, 0.113], [-0.27, 0.128]]
	var nr := 18
	var nc := 56
	var w := nc + 1
	var dags := 9
	var band0 := 12
	var band1 := 14
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		closed.append(true)
		var v := float(r) / float(nr)
		for c in w:
			var th := TAU * float(c) / float(nc)
			var fk := th / TAU * float(dags)
			var tri := 1.0 - absf(fposmod(fk, 1.0) - 0.5) * 2.0
			var y := lerpf(0.04, -0.245, minf(v / (float(band1) / float(nr)), 1.0))
			if r > band1:
				var torn := 0.35 if _hash(int(fk) * 7 + 3) > 0.72 else 1.0          # a few dags torn short
				y = lerpf(-0.245, -0.27 - 0.052 * pow(tri, 1.25) * (0.55 + 0.8 * _hash(int(fk))) * torn - 0.006 * sin(th * 31.0), float(r - band1) / float(nr - band1))
			var rad := _profile(keys, y)[0]
			var p := Vector3(sin(th) * rad, y, -cos(th) * rad * 0.92 + 0.012 * smoothstep(-0.05, -0.27, y))
			var f := 0.6 * sin(6.0 * th + 0.3) + 0.4 * sin(10.0 * th + 1.9 + 8.0 * y)
			p += _ellipse_n(th, rad, rad * 0.92) * (0.002 + 0.008 * smoothstep(-0.02, -0.25, y)) * _ridge(f)
			P.append(p)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z - 0.006))
	var UV := _arc_uv(P, nc, nr)
	var TU := PackedVector2Array()
	TU.resize(P.size())
	for r in nr + 1:
		for c in w:
			TU[r * w + c] = Vector2(UV[r * w + c].x, clampf(float(r - band0) / float(band1 - band0), 0.0, 1.0))
	_grid(S, P, N, {"cloth": UV, "trim": TU}, nc, nr, func(_c: int, r: int) -> String: return "trim" if r >= band0 and r < band1 else "cloth", {"trim": 0.0015})
	var PL := PackedVector3Array()
	var NL := PackedVector3Array()
	for i in P.size():
		PL.append(P[i] - N[i] * 0.006)
		NL.append(-N[i])
	_grid(S, PL, NL, {"*": UV}, nc, nr, func(_c: int, r: int) -> String: return "lining" if r >= 6 else "")
	var st := _st(S, "lining")
	for c in nc:
		var i0 := nr * w + c
		var dn := Vector3.DOWN
		_tri(st, [P[i0], P[i0 + 1], PL[i0 + 1]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0 + 1]])
		_tri(st, [P[i0], PL[i0 + 1], PL[i0]], [dn, dn, dn], [UV[i0], UV[i0 + 1], UV[i0]])


# --- gloves -------------------------------------------------------------------------------------
# Canonical fist: wrist at (0, 0.085, 0), the hand runs down -Y, palm faces -Z, and a bar along X at
# BAR (0, 0, -0.042) is held against the palm. glove_r is moved so the bar centre is the origin
# (the rig lays it along the staff); glove_l keeps the wrist at the origin and is mirrored in X.

const BAR := Vector3(0.0, 0.0, -0.042)


static func _glove(S: Dictionary, left: bool) -> void:
	var G := {}
	# back of the hand: a rounded slab from wrist to knuckles
	_rbox(G, "leather", Vector3(0.084, 0.072, 0.034), 0.014, Vector3(0.0, 0.05, -0.002))
	# knuckle plate and studs
	_rbox(G, "iron", Vector3(0.078, 0.022, 0.012), 0.005, Vector3(0.0, 0.022, 0.016), Basis(Vector3.RIGHT, -0.35))
	for k in 4:
		var x := -0.027 + 0.018 * float(k)
		_rbox(G, "iron", Vector3(0.008, 0.008, 0.006), 0.003, Vector3(x, 0.024, 0.024))
	# fingers: three phalanges curling round the bar
	var lens := [1.0, 1.08, 1.02, 0.86]
	var fr := [0.0102, 0.0108, 0.0102, 0.0092]
	for k in 4:
		var x := 0.031 - 0.0205 * float(k)
		var R := 0.03 + float(fr[k]) + 0.001
		var start := atan2(0.037, 0.02)
		var sweep := (0.098 * float(lens[k])) / R
		var pts := []
		var radii := []
		var n := 12
		for i in n + 1:
			var t := float(i) / float(n)
			var a := start - sweep * t
			pts.append(BAR + Vector3(x, cos(a) * R, sin(a) * R))
			var joint := exp(-pow((t - 0.45) / 0.07, 2.0)) + exp(-pow((t - 0.75) / 0.06, 2.0))
			radii.append(float(fr[k]) * (1.0 + 0.12 * joint) * lerpf(1.0, 0.85, t))
		_tube(G, "leather", pts, radii, 8, true, 0.2)
	# thumb: from the heel of the palm round the far side of the bar
	var tp := [Vector3(0.042, 0.062, -0.012), Vector3(0.046, 0.035, -0.035), Vector3(0.036, 0.012, -0.072), Vector3(0.012, 0.004, -0.088), Vector3(-0.004, 0.006, -0.088)]
	_tube(G, "leather", tp, [0.016, 0.0135, 0.012, 0.011, 0.0095], 8, true, 0.2)
	# gauntlet cuff: flared leather up the forearm, an iron band at the wrist
	var cuff := []
	var cr := []
	for i in 7:
		var t := float(i) / 6.0
		cuff.append(Vector3(0.0, lerpf(0.07, 0.16, t), lerpf(0.0, 0.006, t)))
		cr.append(lerpf(0.04, 0.054, pow(t, 1.4)))
	_tube(G, "strap", cuff, cr, 14, false, 0.3)
	_torus(G, "iron", Vector3(0.0, 0.082, 0.0), Vector3.UP, 0.043, 0.0045, 16, 6)
	_torus(G, "leather", Vector3(0.0, 0.158, 0.006), Vector3.UP, 0.054, 0.004, 16, 6)
	# models pass: sewn, not moulded: a seam of cord stitches down the back of the hand between the
	# fingers (where the leather panels meet), and a running stitch round the cuff's mouth
	for k in 3:
		var sx := 0.0205 - 0.0205 * float(k)
		for i in 6:
			var y := lerpf(0.072, 0.03, float(i) / 5.0)
			_rbox(G, "cord", Vector3(0.0022, 0.0055, 0.0018), 0.0008, Vector3(sx, y, 0.0155 + 0.004 * sin(float(i))), Basis(Vector3.FORWARD, 0.5 if i % 2 == 0 else -0.5), 1)
	for i in 22:
		var a := TAU * float(i) / 22.0
		var c := Vector3(sin(a) * 0.0545, 0.152, 0.006 + cos(a) * 0.0545)
		_rbox(G, "cord", Vector3(0.0055, 0.0022, 0.0018), 0.0008, c, Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, 0.4), 1)
	var shift := -BAR if not left else Vector3(0.0, -0.085, 0.0)
	var mirror := -1.0 if left else 1.0
	for n: String in G:
		var src: SurfaceTool = G[n]
		var arr := src.commit_to_arrays()
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var st := _st(S, n)
		for i in range(0, pos.size(), 3):
			var p := []
			var nn := []
			var tt := []
			for j in 3:
				var q := pos[i + j] + shift
				var m := nrm[i + j]
				q.x *= mirror
				m.x *= mirror
				p.append(q)
				nn.append(m)
				tt.append(uv[i + j])
			_tri(st, p, nn, tt)


# --- boots --------------------------------------------------------------------------------------

static func _boot(S: Dictionary) -> void:
	# sole outline: half-width along z (heel +z, toe -z)
	var hw_keys := [[0.058, 0.0], [0.05, 0.026], [0.025, 0.035], [-0.03, 0.039], [-0.085, 0.046], [-0.12, 0.041], [-0.142, 0.027], [-0.152, 0.0]]
	var top_keys := [[0.058, 0.1], [0.03, 0.105], [-0.01, 0.092], [-0.05, 0.072], [-0.09, 0.055], [-0.125, 0.044], [-0.152, 0.03]]
	var ns := 22
	var na := 14
	var sole_t := 0.018
	# upper: cross-sections along z, an arch from one sole edge over to the other
	var P := PackedVector3Array()
	var closed := []
	for r in ns + 1:
		closed.append(false)
		var z := lerpf(0.058, -0.152, float(r) / float(ns))
		var hw := _profile(hw_keys, z)[0] + 0.004
		var top := _profile(top_keys, z)[0]
		for c in na + 1:
			var a := PI * float(c) / float(na)            # 0 right edge .. PI left edge
			var x := cos(a) * hw
			var yy := sole_t + pow(maxf(sin(a), 0.0), 0.7) * (top - sole_t)
			var bulge := 1.0 + 0.08 * sin(a)
			P.append(Vector3(x * bulge, yy, z))
	var N := _normals(P, na, ns, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y - 0.03, p.z + 0.02) - Vector3(0, 0, -0.04))
	_grid(S, P, N, {"*": _arc_uv(P, na, ns)}, na, ns, func(_c: int, _r: int) -> String: return "leather")
	# heel cap
	var st := _st(S, "leather")
	var hc := Vector3(0.0, 0.06, 0.062)
	for c in na:
		_tri(st, [P[c], P[c + 1], hc], [Vector3.BACK, Vector3.BACK, Vector3.BACK], [Vector2(0, 0), Vector2(0.05, 0), Vector2(0.02, 0.05)])
	# sole: the outline extruded, plus a heel block
	var outline := []
	for i in 24:
		var z := lerpf(0.058, -0.152, float(i) / 23.0)
		outline.append(Vector2(_profile(hw_keys, z)[0] + 0.006, z))
	var ring := []
	for o: Vector2 in outline:
		ring.append(Vector3(o.x, 0.0, o.y))
	for i in range(outline.size() - 1, -1, -1):
		var o: Vector2 = outline[i]
		ring.append(Vector3(-o.x, 0.0, o.y))
	var ss := _st(S, "sole")
	var cnt := ring.size()
	for i in cnt:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % cnt]
		var out := Vector3(b.z - a.z, 0.0, -(b.x - a.x)).normalized()
		if out.dot(Vector3(a.x, 0.0, a.z + 0.045)) < 0.0:
			out = -out
		var top := Vector3.UP * sole_t
		_tri(ss, [a, b, b + top], [out, out, out], [Vector2(0, 0), Vector2(0.02, 0), Vector2(0.02, 0.02)])
		_tri(ss, [a, b + top, a + top], [out, out, out], [Vector2(0, 0), Vector2(0.02, 0.02), Vector2(0, 0.02)])
		var cen := Vector3(0.0, 0.0, -0.045)
		_tri(ss, [cen, a, b], [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], [Vector2(0.5, 0.5), Vector2(a.x, a.z) * 4.0, Vector2(b.x, b.z) * 4.0])
	_rbox(S, "sole", Vector3(0.07, 0.022, 0.05), 0.006, Vector3(0.0, -0.006, 0.03))
	# shaft and turned cuff
	var shaft := []
	var sr := []
	for i in 19:
		var t := float(i) / 18.0
		shaft.append(Vector3(0.0, lerpf(0.06, 0.205, t), 0.012 - 0.004 * t))
		# slouched leather: soft rings of creases, deeper at the ankle
		sr.append(lerpf(0.05, 0.057, t) + 0.0032 * sin(t * 21.0 + 0.6) * (1.2 - t) + 0.0015 * sin(t * 37.0))
	_tube(S, "leather", shaft, sr, 18, false, 0.3)
	# laces up the instep, crossed, with a knot at the top
	var lace := []
	var lr := []
	for i in 11:
		var t := float(i) / 10.0
		var z := lerpf(-0.082, -0.018, t)
		var top := _profile(top_keys, z)[0]
		var x := 0.02 * (1.0 if i % 2 == 0 else -1.0)
		lace.append(Vector3(x, top * (1.0 - 0.15 * (x * x) / 0.0004) + 0.004, z))
		lr.append(0.0028)
	_tube(S, "cord", lace, lr, 5, false, 0.1)
	_rbox(S, "cord", Vector3(0.016, 0.01, 0.012), 0.004, Vector3(0.0, _profile(top_keys, -0.016)[0] + 0.008, -0.014))
	var cuff := [Vector3(0.0, 0.178, 0.009), Vector3(0.0, 0.2, 0.008), Vector3(0.0, 0.226, 0.007)]
	_tube(S, "leather", cuff, [0.063, 0.067, 0.069], 16, false, 0.2)
	_torus(S, "leather", Vector3(0.0, 0.226, 0.007), Vector3.UP, 0.066, 0.005, 18, 6)
	# straps and buckles round the shaft, one over the instep
	for y: float in [0.095, 0.15]:
		_torus(S, "leather", Vector3(0.0, y, 0.01), Vector3.UP, 0.056, 0.0055, 18, 5)
		_rbox(S, "iron", Vector3(0.006, 0.018, 0.016), 0.002, Vector3(0.058, y, 0.004))
	var instep := []
	var ir := []
	for i in 9:
		var a := PI * float(i) / 8.0
		instep.append(Vector3(cos(a) * 0.05, sole_t + sin(a) * 0.07, -0.035))
		ir.append(0.006)
	_tube(S, "leather", instep, ir, 6, false, 0.2)
	_rbox(S, "iron", Vector3(0.016, 0.014, 0.005), 0.002, Vector3(0.036, 0.062, -0.04), Basis(Vector3.FORWARD, 0.8))


# --- legs ---------------------------------------------------------------------------------------

static func _limb(S: Dictionary, surf: String, keys: Array, y0: float, y1: float, nr: int, nc: int, fold_amt: float, wrap: bool) -> void:
	var w := nc + 1
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		closed.append(true)
		var y := lerpf(y0, y1, float(r) / float(nr))
		var rad := _profile(keys, y)[0]
		for c in w:
			var th := TAU * float(c) / float(nc)
			var rx := rad
			var rz := rad * 0.92
			var p := Vector3(sin(th) * rx, y, -cos(th) * rz)
			var f := 0.6 * sin(4.0 * th + 0.4 + 6.0 * y) + 0.4 * sin(7.0 * th + 1.7)
			var d := fold_amt * _ridge(f)
			if wrap:
				var band := fposmod(y / 0.032 + th / TAU, 1.0)
				d += 0.003 * smoothstep(0.0, 0.12, band) * smoothstep(1.0, 0.82, band)
			p += _ellipse_n(th, rx, rz) * d
			P.append(p)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z))
	_grid(S, P, N, {"*": _arc_uv(P, nc, nr)}, nc, nr, func(_c: int, _r: int) -> String: return surf)


static func _thigh(S: Dictionary) -> void:
	_limb(S, "pants", [[0.07, 0.088], [-0.1, 0.08], [-0.3, 0.068], [-0.44, 0.062]], 0.07, -0.44, 16, 20, 0.004, false)


static func _shin(S: Dictionary) -> void:
	_limb(S, "wrap", [[0.04, 0.062], [-0.08, 0.057], [-0.22, 0.05], [-0.3, 0.049]], 0.04, -0.3, 22, 18, 0.0015, true)


# --- belt, strap, pouch, charms, clasp ---------------------------------------------------------

static func _band(S: Dictionary, surf: String, y_top: float, y_bot: float, off: float, thick: float) -> void:
	var nc := 72
	var rows := [[y_top, off - thick], [y_top + 0.002, off], [y_top - 0.004, off + thick], [y_bot + 0.004, off + thick], [y_bot - 0.002, off], [y_bot, off - thick]]
	var nr := rows.size() - 1
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		closed.append(true)
		var y: float = rows[r][0]
		var o: float = rows[r][1]
		for c in nc + 1:
			var th := TAU * float(c) / float(nc)
			var k := _profile(COAT_KEYS, y)
			P.append(Vector3(sin(th) * k[0], y, -cos(th) * k[1] + k[2]) + _ellipse_n(th, k[0], k[1]) * o)
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z))
	var A := _arc_uv(P, nc, nr)
	var across := [-0.1, 0.0, 0.06, 0.94, 1.0, 1.1]
	var UV := PackedVector2Array()
	UV.resize(P.size())
	for r in nr + 1:
		for c in nc + 1:
			UV[r * (nc + 1) + c] = Vector2(across[r], A[2 * (nc + 1) + c].x / ((y_top - y_bot) * 4.0))
	_grid(S, P, N, {"*": UV}, nc, nr, func(_c: int, _r: int) -> String: return surf)


## Coat surface point + outward normal (folds included), lifted off by `off`.
static func _on_coat(th: float, y: float, off: float) -> Array:
	var p := coat_point(th, y)
	var px := coat_point(th + 0.01, y)
	var py := coat_point(th, y - 0.01)
	var n := (px - p).cross(py - p).normalized()
	if n.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
		n = -n
	return [p + n * off, n]


static func _gear(S: Dictionary) -> void:
	# belt
	_band(S, "strap", BELT_Y + 0.028, BELT_Y - 0.028, 0.017, 0.005)
	var bk := _profile(COAT_KEYS, BELT_Y)
	var front_z := -bk[1] - 0.024
	# buckle: an iron frame and prong
	var bc := Vector3(0.0, BELT_Y, front_z)
	for e: Array in [[Vector3(0.0, 0.031, 0.0), Vector3(0.062, 0.009, 0.008)], [Vector3(0.0, -0.031, 0.0), Vector3(0.062, 0.009, 0.008)],
			[Vector3(0.027, 0.0, 0.0), Vector3(0.009, 0.07, 0.008)], [Vector3(-0.027, 0.0, 0.0), Vector3(0.009, 0.07, 0.008)]]:
		_rbox(S, "iron", e[1], 0.003, bc + (e[0] as Vector3))
	_rbox(S, "iron", Vector3(0.006, 0.055, 0.005), 0.002, bc + Vector3(-0.004, 0.0, -0.002), Basis(Vector3.FORWARD, 0.15))
	# belt tongue hanging from the buckle
	var tongue := []
	var tr := []
	for i in 8:
		var t := float(i) / 7.0
		var y := BELT_Y - 0.01 - t * 0.13
		var on := _on_coat(-0.12 - t * 0.04, y, 0.014 + 0.004 * t)
		tongue.append(on[0])
		tr.append(0.0)
	_strip(S, "strap", tongue, 0.036, 0.004)
	# baldric: right shoulder to left hip, a tilted loop round the body on the coat's surface
	var strap := []
	for i in 73:
		var th := TAU * float(i) / 72.0
		var y := 0.0
		for it in 4:
			var p := coat_point(th, y, false)
			y = -0.052 + 1.46 * p.x
		y = clampf(y, -0.42, 0.26)
		strap.append(_on_coat(th, y, 0.016 + 0.008 * smoothstep(-0.25, -0.4, y))[0])
	_strip(S, "strap", strap, 0.04, 0.005, true)
	# strap rings at the hip end
	var ring_at: Vector3 = _on_coat(-1.6, -0.37, 0.03)[0]
	_torus(S, "iron", ring_at, Vector3.RIGHT, 0.017, 0.0035, 14, 6)
	# a pouch on the belt at the right front
	var pa: Array = _on_coat(0.95, BELT_Y - 0.075, 0.035)
	var pn: Vector3 = pa[1]
	var pb := Basis.looking_at(-pn, Vector3.UP)
	_rbox(S, "leather", Vector3(0.09, 0.085, 0.042), 0.014, pa[0], pb)
	_rbox(S, "strap", Vector3(0.094, 0.04, 0.012), 0.006, (pa[0] as Vector3) + Vector3.UP * 0.03 + pn * 0.02, pb * Basis(Vector3.RIGHT, -0.25), 4, true)
	_rbox(S, "iron", Vector3(0.014, 0.014, 0.006), 0.003, (pa[0] as Vector3) + Vector3.UP * 0.01 + pn * 0.028, pb)
	# charms: an iron ring and a rune disc on a cord from the belt, left front
	var ca: Vector3 = _on_coat(-0.55, BELT_Y - 0.03, 0.022)[0]
	var cb: Vector3 = _on_coat(-0.55, BELT_Y - 0.12, 0.03)[0]
	_tube(S, "leather", [ca, ca.lerp(cb, 0.5) + Vector3(0, 0, -0.004), cb], [0.0025, 0.0025, 0.0025], 5, false)
	var cn: Vector3 = _on_coat(-0.55, BELT_Y - 0.13, 0.0)[1]
	_torus(S, "iron", cb + Vector3.DOWN * 0.016, cn.cross(Vector3.UP).normalized(), 0.015, 0.003, 14, 6)
	var disc_c := cb + Vector3.DOWN * 0.05 + cn * 0.004
	_disc(S, "iron", disc_c, cn, 0.02, 0.005)
	# mantle clasp: two bosses and a short bar under the chin
	var cz := -_profile(MANTLE_KEYS, 0.2)[1] - 0.01
	for sx: float in [-1.0, 1.0]:
		_disc(S, "iron", Vector3(sx * 0.04, 0.2, cz + 0.004), Vector3(sx * 0.25, 0.1, -1.0).normalized(), 0.02, 0.008)
	_tube(S, "iron", [Vector3(-0.035, 0.2, cz - 0.004), Vector3(0.0, 0.192, cz - 0.009), Vector3(0.035, 0.2, cz - 0.004)], [0.003, 0.003, 0.003], 6, false)


## A flat strap (with thickness) along a polyline lying on a surface: width across, `thick` deep.
static func _strip(S: Dictionary, surf: String, pts: Array, width: float, thick: float, loop := false) -> void:
	var nr := pts.size() - 1
	var P := PackedVector3Array()
	var closed := []
	for r in nr + 1:
		closed.append(false)
		var p: Vector3 = pts[r]
		var t: Vector3 = ((pts[mini(r + 1, nr)] as Vector3) - (pts[maxi(r - 1, 0)] as Vector3)).normalized()
		var n := Vector3(p.x, 0.0, p.z).normalized()
		var across := t.cross(n).normalized() * width * 0.5
		n = across.cross(t).normalized()
		if n.dot(Vector3(p.x, 0.0, p.z)) < 0.0:
			n = -n
		P.append(p - across - n * thick)
		P.append(p - across)
		P.append(p - across * 0.6 + n * thick * 0.4)
		P.append(p + across * 0.6 + n * thick * 0.4)
		P.append(p + across)
		P.append(p + across - n * thick)
	var nc := 5
	var N := _normals(P, nc, nr, closed, func(q: Vector3) -> Vector3: return Vector3(q.x, 0.0, q.z))
	var A := _arc_uv(P, nc, nr)
	var across := [-0.1, 0.0, 0.2, 0.8, 1.0, 1.1]
	var UV := PackedVector2Array()
	UV.resize(P.size())
	for r in nr + 1:
		for c in nc + 1:
			UV[r * (nc + 1) + c] = Vector2(across[c], A[r * (nc + 1) + 2].y / (width * 4.0))
	_grid(S, P, N, {"*": UV}, nc, nr, func(_c: int, _r: int) -> String: return surf)


static func _disc(S: Dictionary, surf: String, at: Vector3, n: Vector3, r: float, h: float) -> void:
	var a := n.normalized()
	var u := a.cross(Vector3.UP if absf(a.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var v := a.cross(u)
	var st := _st(S, surf)
	var seg := 14
	for i in seg:
		var t0 := TAU * float(i) / float(seg)
		var t1 := TAU * float(i + 1) / float(seg)
		var e0 := (u * cos(t0) + v * sin(t0))
		var e1 := (u * cos(t1) + v * sin(t1))
		var top := at + a * h
		var dome := top + a * h * 0.5
		_tri(st, [dome, top + e0 * r, top + e1 * r], [a, (a + e0 * 0.5).normalized(), (a + e1 * 0.5).normalized()], [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0)])
		_tri(st, [top + e0 * r, at + e0 * r, at + e1 * r], [e0, e0, e1], [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)])
		_tri(st, [top + e0 * r, at + e1 * r, top + e1 * r], [e0, e1, e1], [Vector2(0, 0), Vector2(1, 1), Vector2(1, 0)])


# --- satchel (pelvis; origin = the strap pivot, the bag hangs below it) -----------------------

static func _satchel(S: Dictionary) -> void:
	var c := Vector3(-0.03, -0.1, 0.0)
	_rbox(S, "leather", Vector3(0.07, 0.15, 0.19), 0.022, c)
	# flap: over the top and down the outer face
	_rbox(S, "strap", Vector3(0.012, 0.11, 0.196), 0.005, c + Vector3(-0.04, 0.02, 0.0), Basis(Vector3.FORWARD, 0.06), 4, true)
	_rbox(S, "strap", Vector3(0.078, 0.012, 0.196), 0.005, c + Vector3(-0.002, 0.075, 0.0), Basis.IDENTITY, 4, true)
	# buckle strap and buckle on the flap
	_rbox(S, "strap", Vector3(0.006, 0.09, 0.028), 0.002, c + Vector3(-0.048, -0.01, 0.0), Basis.IDENTITY, 2, true)
	_rbox(S, "iron", Vector3(0.006, 0.026, 0.032), 0.002, c + Vector3(-0.051, -0.04, 0.0))
	# seam piping round the gusset
	var pip := []
	var pr := []
	for i in 13:
		var a := PI * float(i) / 12.0
		pip.append(c + Vector3(0.036, -0.065 * sin(a) + 0.0, 0.093 * cos(a)))
		pr.append(0.003)
	_tube(S, "leather", pip, pr, 5, false)
	# strap rings at the top corners and the strap stub up to the pivot
	for sz: float in [-0.085, 0.085]:
		_torus(S, "iron", c + Vector3(0.0, 0.08, sz), Vector3.BACK, 0.012, 0.003, 12, 5)
		_tube(S, "leather", [c + Vector3(0.0, 0.09, sz), Vector3(0.0, 0.0, sz * 0.3)], [0.006, 0.006], 6, false)


# --- staff (hand_r; the hand grips at the origin, the head node is at y 1.27, orb 1.44) -------
# A hero object: a carved, knotted shaft (surface "staff": rune columns whose grooves glow faintly,
# see WandererTex._staff), a leather grip bound with crossed cord, iron bands at the knots, a
# ferrule spike, and under the orb an iron cup with a crown of five thorned, knuckled claws.

static func _staff_axis(y: float) -> Vector3:
	return Vector3(0.013 * sin(y * 1.7 + 0.4) + 0.004 * sin(y * 5.3), y, 0.009 * sin(y * 2.3 + 1.0) + 0.003 * sin(y * 6.1 + 2.0))


static func _staff(S: Dictionary) -> void:
	var y0 := -0.66
	var y1 := 1.15
	var nr := 140
	var nc := 18
	var w := nc + 1
	var P := PackedVector3Array()
	var UV := PackedVector2Array()
	var closed := []
	var knots := [[-0.35, 0.007, 0.4], [0.3, 0.008, 2.6], [0.47, 0.011, 1.2], [0.66, 0.007, 4.4], [0.84, 0.009, 3.1]]
	for r in nr + 1:
		closed.append(true)
		var y := lerpf(y0, y1, float(r) / float(nr))
		var base := lerpf(0.024, 0.031, smoothstep(y0, 0.4, y)) + 0.005 * smoothstep(0.95, 1.15, y)
		var twist := y * 2.2
		for c in w:
			var th := TAU * float(c) / float(nc)
			# carved spiral flutes and gnarled lumps that twist up the shaft
			var flute := 0.0014 * pow(maxf(0.0, sin(4.0 * (th + twist) + 0.3)), 6.0)
			var lump := 0.0013 * sin(th * 3.0 + y * 13.0) + 0.0008 * sin(th * 5.0 - y * 21.0)
			for kn: Array in knots:
				var g := exp(-pow((y - float(kn[0])) / 0.024, 2.0))
				lump += float(kn[1]) * g * pow(maxf(0.0, cos(th - float(kn[2]))), 1.5) + 0.002 * g
			var rad := base - flute + lump
			P.append(_staff_axis(y) + Vector3(sin(th) * rad, 0.0, -cos(th) * rad))
			UV.append(Vector2(float(c) / float(nc), y * 1.6))
	var N := _normals(P, nc, nr, closed, func(p: Vector3) -> Vector3: return p - _staff_axis(p.y))
	_grid(S, P, N, {"*": UV}, nc, nr, func(_c: int, r: int) -> String:
		var y := lerpf(y0, y1, (float(r) + 0.5) / float(nr))
		return "" if y > -0.16 and y < 0.18 else "staff")
	# two broken-off branch stubs at the knots
	for kn: Array in [knots[2], knots[4]]:
		var y: float = kn[0]
		var dir := Vector3(sin(float(kn[2])), 0.35, -cos(float(kn[2]))).normalized()
		var root := _staff_axis(y) + Vector3(dir.x, 0.0, dir.z) * 0.026
		_tube(S, "wood", [root - dir * 0.006, root + dir * 0.014, root + dir * 0.026], [0.011, 0.008, 0.0055], 8, true, 0.1)
	# grip: a leather wrap with raised turns, bound over with crossed cord
	var GP := PackedVector3Array()
	var GU := PackedVector2Array()
	var gr := 40
	var gy0 := -0.16
	var gy1 := 0.18
	for r in gr + 1:
		var y := lerpf(gy0, gy1, float(r) / float(gr))
		for c in w:
			var th := TAU * float(c) / float(nc)
			var band := fposmod(y / 0.022 + th / TAU, 1.0)
			var rad := 0.0335 + 0.0028 * smoothstep(0.0, 0.18, band) * smoothstep(1.0, 0.8, band)
			GP.append(_staff_axis(y) + Vector3(sin(th) * rad, 0.0, -cos(th) * rad))
			GU.append(Vector2(float(c) / float(nc) * 0.2, y))
	var gclosed := []
	for r in gr + 1:
		gclosed.append(true)
	var GN := _normals(GP, nc, gr, gclosed, func(p: Vector3) -> Vector3: return p - _staff_axis(p.y))
	_grid(S, GP, GN, {"*": GU}, nc, gr, func(_c: int, _r: int) -> String: return "grip")
	for hand: float in [1.0, -1.0]:
		var cp := []
		var cr := []
		for i in 49:
			var t := float(i) / 48.0
			var y := lerpf(gy0 + 0.01, gy1 - 0.01, t)
			var th := hand * t * TAU * 2.5 + (0.0 if hand > 0.0 else PI)
			cp.append(_staff_axis(y) + Vector3(sin(th), 0.0, -cos(th)) * 0.0372)
			cr.append(0.0022)
		_tube(S, "cord", cp, cr, 5, false, 0.05)
	# wrap ends: thick collars of cord, and two tails with knots hanging from the top one
	for y: float in [gy0, gy1]:
		_torus(S, "cord", _staff_axis(y), Vector3.UP, 0.036, 0.0042, 18, 6)
		_torus(S, "cord", _staff_axis(y + (0.008 if y > 0.0 else -0.008)), Vector3.UP, 0.0355, 0.004, 18, 6)
	for k in 2:
		var a0 := 0.9 + float(k) * 0.5
		var start := _staff_axis(gy1) + Vector3(sin(a0), 0.0, -cos(a0)) * 0.038
		var tail := [start, start + Vector3(sin(a0) * 0.012, -0.05, -cos(a0) * 0.012), start + Vector3(sin(a0) * 0.02, -0.1 - 0.02 * float(k), -cos(a0) * 0.02 + 0.006)]
		_tube(S, "cord", tail, [0.0024, 0.0022, 0.002], 5, false, 0.05)
		_rbox(S, "cord", Vector3(0.008, 0.01, 0.008), 0.0035, tail[2] as Vector3)
	# ferrule and spike
	var fy := [-0.6, -0.64, -0.69, -0.73, -0.78]
	var fpts := []
	for y: float in fy:
		fpts.append(_staff_axis(y))
	_tube(S, "iron", fpts, [0.031, 0.03, 0.027, 0.02, 0.006], 14, true, 0.2)
	_torus(S, "iron", _staff_axis(-0.6), Vector3.UP, 0.031, 0.004, 16, 6)
	# iron bands where the shaft once split
	for e: Array in [[-0.35, 0.034], [0.3, 0.036]]:
		_torus(S, "iron", _staff_axis(float(e[0]) - 0.03), Vector3.UP, float(e[1]), 0.0035, 18, 6)
		_torus(S, "iron", _staff_axis(float(e[0]) + 0.03), Vector3.UP, float(e[1]), 0.0035, 18, 6)
	# collar rings under the head
	for e: Array in [[1.06, 0.039, 0.006], [1.1, 0.042, 0.007], [1.14, 0.038, 0.005]]:
		_torus(S, "iron", _staff_axis(float(e[0])), Vector3.UP, float(e[1]), float(e[2]), 18, 6)
	var top := _staff_axis(1.15)
	# the cup: a flared iron calyx the orb sits in
	var cup := []
	var cupr := []
	for i in 9:
		var t := float(i) / 8.0
		cup.append(top + Vector3(0.0, lerpf(0.0, 0.16, t), 0.0))
		cupr.append(lerpf(0.034, 0.062, pow(t, 1.6)) - 0.006 * sin(t * PI))
	_tube(S, "iron", cup, cupr, 20, false, 0.2)
	_torus(S, "iron", top + Vector3(0.0, 0.16, 0.0), Vector3.UP, 0.062, 0.005, 20, 6)
	# the crown: five iron claws from the cup rim, knuckled, thorned, curling in over the orb
	for k in 5:
		var a0 := TAU * float(k) / 5.0 + 0.3
		var pts := []
		var radii := []
		var ctrl := [Vector2(0.058, 1.3), Vector2(0.14, 1.35), Vector2(0.142, 1.53), Vector2(0.035, 1.6)]
		for i in 23:
			var t := float(i) / 22.0
			var a := (ctrl[0] as Vector2).lerp(ctrl[1], t)
			var b := (ctrl[1] as Vector2).lerp(ctrl[2], t)
			var cc := (ctrl[2] as Vector2).lerp(ctrl[3], t)
			var q := a.lerp(b, t).lerp(b.lerp(cc, t), t)
			var ang := a0 + 0.5 * t
			pts.append(Vector3(top.x + cos(ang) * q.x, q.y + top.y - 1.15, top.z + sin(ang) * q.x))
			var knuckle := exp(-pow((t - 0.3) / 0.05, 2.0)) + exp(-pow((t - 0.62) / 0.045, 2.0))
			radii.append(lerpf(0.0105, 0.0022, pow(t, 0.85)) * (1.0 + 0.35 * knuckle))
		_tube(S, "iron", pts, radii, 8, true, 0.3)
		for j: float in [0.18, 0.42, 0.72]:
			var idx := int(j * 22.0)
			var base_p: Vector3 = pts[idx]
			var outward := Vector3(base_p.x - top.x, 0.0, base_p.z - top.z).normalized()
			var lift := Vector3.UP * (0.018 if j < 0.5 else -0.004)
			_tube(S, "iron", [base_p, base_p + outward * 0.016 + lift * 0.5, base_p + outward * 0.03 + lift], [0.0045, 0.0022, 0.0006], 5, false)
	# a hanging charm under the collar: cord and an iron crescent (static)
	var hang: Vector3 = _staff_axis(1.07) + Vector3(0.042, 0.0, 0.0)
	_tube(S, "cord", [hang, hang + Vector3(0.006, -0.05, 0.0), hang + Vector3(0.008, -0.09, 0.004)], [0.0018, 0.0018, 0.0018], 5, false)
	var cres := []
	var crr := []
	for i in 9:
		var a := lerpf(0.5, TAU - 0.5, float(i) / 8.0)
		cres.append(hang + Vector3(0.008, -0.11, 0.004) + Vector3(sin(a) * 0.018, cos(a) * 0.018, 0.0))
		crr.append(0.0035 * sin(PI * float(i) / 8.0) + 0.001)
	_tube(S, "iron", cres, crr, 6, false)


# --- orb (orb-local: the rig bobs, spins and swells this node) --------------------------------

static func _orb(S: Dictionary) -> void:
	var st := _st(S, "orb")
	var rings := 18
	var segs := 28
	var r := 0.07
	for i in rings:
		for j in segs:
			var q := []
			for e: Vector2i in [Vector2i(i, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1), Vector2i(i + 1, j)]:
				var ph := PI * float(e.x) / float(rings)
				var th := TAU * float(e.y) / float(segs)
				q.append(Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th)))
			var uv := [Vector2(float(j) / segs, float(i) / rings), Vector2(float(j + 1) / segs, float(i) / rings), Vector2(float(j + 1) / segs, float(i + 1) / rings), Vector2(float(j) / segs, float(i + 1) / rings)]
			_tri(st, [q[0] * r, q[1] * r, q[2] * r], [q[0], q[1], q[2]], [uv[0], uv[1], uv[2]])
			_tri(st, [q[0] * r, q[2] * r, q[3] * r], [q[0], q[2], q[3]], [uv[0], uv[2], uv[3]])
	_torus(S, "iron", Vector3.ZERO, Basis(Vector3.RIGHT, 1.2) * Vector3.UP, 0.092, 0.0035, 32, 6)
	_torus(S, "iron", Vector3.ZERO, Basis(Vector3.BACK, 1.1) * Vector3.UP, 0.08, 0.003, 28, 6)


# --- lantern (hand_l root; the light sits at y -0.24) --------------------------------------------

static func _lantern(S: Dictionary) -> void:
	# bail handle the fist holds, a ring, the pierced cap, the horn-glass drum in a cage, the foot
	var bail := []
	var br := []
	for i in 13:
		var a := lerpf(-1.25, 1.25, float(i) / 12.0)
		bail.append(Vector3(sin(a) * 0.04, -0.045 + cos(a) * 0.04, 0.0))
		br.append(0.0034)
	_tube(S, "iron", bail, br, 6, false)
	_torus(S, "iron", Vector3(0.0, -0.05, 0.0), Vector3.FORWARD, 0.011, 0.003, 12, 5)
	var cap := [Vector3(0, -0.06, 0), Vector3(0, -0.075, 0), Vector3(0, -0.1, 0), Vector3(0, -0.122, 0)]
	_tube(S, "iron", cap, [0.012, 0.03, 0.054, 0.064], 16, false, 0.1)
	_torus(S, "iron", Vector3(0.0, -0.06, 0.0), Vector3.UP, 0.012, 0.004, 12, 5)
	_torus(S, "iron", Vector3(0.0, -0.124, 0.0), Vector3.UP, 0.064, 0.0045, 24, 6)
	# glass: a slightly barrelled drum, glowing (the gear shader's emission, brightest mid-height)
	var gl := []
	var glr := []
	for i in 9:
		var t := float(i) / 8.0
		gl.append(Vector3(0.0, lerpf(-0.126, -0.312, t), 0.0))
		glr.append(0.05 + 0.006 * sin(t * PI))
	_tube(S, "glass", gl, glr, 16, false, 0.2)
	# cage: six bars and a middle band
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.26
		var bars := []
		var bw := []
		for i in 7:
			var t := float(i) / 6.0
			var rr := 0.06 + 0.006 * sin(t * PI)
			bars.append(Vector3(cos(a) * rr, lerpf(-0.124, -0.315, t), sin(a) * rr))
			bw.append(0.0032)
		_tube(S, "iron", bars, bw, 5, false)
	_torus(S, "iron", Vector3(0.0, -0.22, 0.0), Vector3.UP, 0.0655, 0.0032, 24, 5)
	var foot := [Vector3(0, -0.314, 0), Vector3(0, -0.322, 0), Vector3(0, -0.336, 0), Vector3(0, -0.342, 0)]
	_tube(S, "iron", foot, [0.064, 0.066, 0.058, 0.03], 18, true, 0.1)

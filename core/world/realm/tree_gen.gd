extends RefCounted
## Procedural trees and plants for the Realm (flora module, docs/REALM_PLAN.md). No class_name:
##   const TreeGen := preload("res://core/world/realm/tree_gen.gd")
##   var k: Dictionary = TreeGen.kind("oak_2")
## A kind id is "<species>_<variant>" (variants are seeded, so the same id always gives the same
## plant). Returns {
##   solid: ArrayMesh or null   bark / wood / caps (opaque; give it LODs: MeshChunks.with_lods)
##   cards: ArrayMesh or null   alpha cards on the foliage atlas (NEVER LOD these: they collapse)
##   h: height, r: trunk radius at 1 m (collision; 0 = none), spread: crown radius,
##   tall: bool (a tree: cast shadows, collide) }
## The plant stands at the origin on y = 0; trunks and roots reach 0.6 m below so slopes never
## show a gap under them.
##
## Trunks and branches are swept tubes with parallel-transport frames, bark UVs (u around in
## whole texture tiles, v metres along), buttress fluting and root flare at the base, roots that
## dive into the soil, vertex colour for occlusion and moss. Leaves are clusters of crossed alpha
## cards (art/textures/realm_foliage_atlas.png, 4 x 4 cells) with baked crown normals and crown
## occlusion so a crown reads as a volume instead of a pile of planes.

const LEAF_MAT := "res://art/materials/realm_foliage.tres"
const GROUND_MAT := "res://art/materials/realm_foliage_ground.tres"
const BARK := {
	"oak": "res://art/materials/realm_foliage_bark_oak.tres",
	"pine": "res://art/materials/realm_foliage_bark_pine.tres",
	"birch": "res://art/materials/realm_foliage_bark_birch.tres",
	"dead": "res://art/materials/realm_foliage_bark_dead.tres",
}
const CAP_MAT := "res://art/materials/realm_foliage_cap.tres"
const GLOW_MAT := "res://art/materials/realm_foliage_glow.tres"
const EMBER_MAT := "res://art/materials/realm_foliage_ember.tres"     ## r34 flora: cinders in the ash

## atlas cells (tools/gen_realm_foliage.gd)
const C_OAK := 0
const C_BIRCH := 1
const C_PINE := 2
const C_WILLOW := 3
const C_SHRUB := 4
const C_BRAMBLE := 5
const C_FERN := 6
const C_GRASS := 7
const C_FLOWERS := 8
const C_HEATHER := 9
const C_REEDS := 10
const C_CATTAIL := 11
const C_TWIGS := 12
const C_LITTER := 13
const C_MOSS := 14
const C_HANG := 15

## species -> variant count
const VARIANTS := {
	"oak": 4, "pine": 3, "birch": 3, "willow": 3, "snag": 3, "sapling": 3,
	"shrub": 2, "bramble": 2, "fern": 2, "grass": 2, "tallgrass": 1, "flowers": 2, "heather": 1,
	"reeds": 1, "cattail": 1, "litter": 1, "moss": 1, "mushroom": 2, "glowcap": 1,
	"log": 2, "stump": 2, "roots": 1,
	# r34 flora: the new regions' own plants (realm_flora.gd LOOKS)
	"fruit": 3, "cypress": 2, "yew": 2, "windtree": 2,
	"gorse": 2, "deadbush": 1, "ashdrift": 1, "cinders": 1, "lily": 1, "scaffold": 2,
}

static var _cache := {}


const GenCache := preload("res://core/world/realm/gen_cache.gd")
const SELF := "res://core/world/realm/tree_gen.gd"

static func kind(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var tp := Time.get_ticks_usec()
	var disk: Variant = GenCache.load_var("tree|" + id, SELF)
	if disk is Dictionary:
		var dd: Dictionary = (disk as Dictionary).duplicate()
		dd.solid = GenCache.load_mesh("tree|solid|" + id, SELF) if dd.get("has_solid", false) else null
		dd.cards = GenCache.load_mesh("tree|cards|" + id, SELF) if dd.get("has_cards", false) else null
		if (dd.solid != null or not dd.get("has_solid", false)) and (dd.cards != null or not dd.get("has_cards", false)):
			_cache[id] = dd
			Realm.prof_add("gen: trees (disk)", tp)
			return dd
	var base := id.trim_suffix("@far")
	var cut := base.rfind("_")
	var sp := base.substr(0, cut)
	var v := int(base.substr(cut + 1))
	var g := Gen.new(sp.hash() % 100000 + v * 7919)
	g.far = id.ends_with("@far")
	var d: Dictionary = g.call("make_" + sp, v)
	_cache[id] = d
	var meta := {}
	for k in d:
		if k != "solid" and k != "cards":
			meta[k] = d[k]
	meta.has_solid = d.solid != null
	meta.has_cards = d.cards != null
	if d.solid != null:
		GenCache.save_mesh("tree|solid|" + id, SELF, d.solid)
	if d.cards != null:
		GenCache.save_mesh("tree|cards|" + id, SELF, d.cards)
	GenCache.save_var("tree|" + id, SELF, meta)
	Realm.prof_add("gen: trees", tp)
	return d


## "<id>@far": the same tree (same seed, same skeleton and crown) for distance: no twigs, fewer
## sides and rings, half the leaf clusters at 1.4x the size. RealmFlora swaps to it by visibility
## range per chunk (a LOD for the cards that cannot collapse them).
const FAR := ["oak", "pine", "birch", "willow"]


static func ids(species: String) -> Array[String]:
	var out: Array[String] = []
	for v in int(VARIANTS.get(species, 0)):
		out.append("%s_%d" % [species, v])
	return out


class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var t := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var c := PackedColorArray()
	var i := PackedInt32Array()
	var mat: Material

	func add(p: Vector3, nn: Vector3, u: Vector2, col: Color, u2 := Vector2.ZERO, tg := Vector3.RIGHT) -> int:
		v.append(p)
		n.append(nn)
		uv.append(u)
		uv2.append(u2)
		c.append(col)
		t.append_array(PackedFloat32Array([tg.x, tg.y, tg.z, 1.0]))
		return v.size() - 1

	func tri(a: int, b: int, cc: int) -> void:
		i.append_array(PackedInt32Array([a, b, cc]))

	func commit_to(m: ArrayMesh, tangents: bool) -> void:
		if i.is_empty():
			return
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		if tangents:
			arr[Mesh.ARRAY_TANGENT] = t
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = i
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, mat)


class Gen:
	var rng := RandomNumberGenerator.new()
	var wood := Surf.new()
	var glow := Surf.new()
	var leaf := Surf.new()
	var anchors: Array = []          # [pos, dir, size, depth]
	var tile := 1.4                  # bark tile size, metres
	var moss := 0.0                  # moss on up-facing bark and the base
	var bark_col := Color.WHITE
	var char_amt := 0.0              # blackened bark
	var h := 0.0
	var trunk_r := 0.0
	var far := false
	var glow_mat := GLOW_MAT
	var _seed := 0.0

	func _init(s: int) -> void:
		rng.seed = s
		_seed = float(s % 1000) * 0.137

	# --- noise -------------------------------------------------------------------------------
	func _hash(p: Vector3) -> float:
		var x := sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7 + _seed) * 43758.5453
		return x - floorf(x)

	func noise(p: Vector3) -> float:
		var i := p.floor()
		var f := p - i
		f = f * f * (Vector3(3, 3, 3) - f * 2.0)
		var a := lerpf(lerpf(_hash(i), _hash(i + Vector3(1, 0, 0)), f.x), lerpf(_hash(i + Vector3(0, 1, 0)), _hash(i + Vector3(1, 1, 0)), f.x), f.y)
		var b := lerpf(lerpf(_hash(i + Vector3(0, 0, 1)), _hash(i + Vector3(1, 0, 1)), f.x), lerpf(_hash(i + Vector3(0, 1, 1)), _hash(i + Vector3(1, 1, 1)), f.x), f.y)
		return lerpf(a, b, f.z)

	func rvec() -> Vector3:
		return Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))

	# --- tubes -------------------------------------------------------------------------------
	## Sweep a ring along pts. opts: flute (amp), flute_n, flute_h, lumps, cap (close the far end
	## with a wood disc), cap0 (close the start), surf (Surf), col (Color)
	func tube(pts: PackedVector3Array, radii: PackedFloat32Array, sides: int, opts := {}) -> void:
		var s: Surf = opts.get("surf", wood)
		var base_col: Color = opts.get("col", bark_col)
		var flute: float = opts.get("flute", 0.0)
		var flute_n: int = opts.get("flute_n", 7)
		var flute_h: float = opts.get("flute_h", 1.5)
		var lumps: float = opts.get("lumps", 0.08)
		var np := pts.size()
		var tans: Array[Vector3] = []
		for k in np:
			tans.append((pts[mini(k + 1, np - 1)] - pts[maxi(k - 1, 0)]).normalized())
		var refv := Vector3.FORWARD if absf(tans[0].dot(Vector3.UP)) > 0.9 else Vector3.UP
		var nrm := tans[0].cross(refv).normalized()
		var circ := maxi(1, roundi(TAU * radii[0] / tile))
		var start := s.v.size()
		var along := 0.0
		var y0 := pts[0].y
		var fphase := rng.randf() * TAU
		if far:
			if int(opts.get("depth", 0)) >= 3 or radii[0] < 0.035:
				return
			sides = maxi(3, roundi(sides * 0.55))
			if np > 3:
				var p2 := PackedVector3Array()
				var r2 := PackedFloat32Array()
				for k in np:
					if k % 2 == 0 or k == np - 1:
						p2.append(pts[k])
						r2.append(radii[k])
				pts = p2
				radii = r2
				np = pts.size()
				tans.clear()
				for k in np:
					tans.append((pts[mini(k + 1, np - 1)] - pts[maxi(k - 1, 0)]).normalized())
				nrm = tans[0].cross(refv).normalized()
		for k in np:
			if k > 0:
				var axis := tans[k - 1].cross(tans[k])
				if axis.length_squared() > 1e-10:
					nrm = nrm.rotated(axis.normalized(), tans[k - 1].angle_to(tans[k]))
				along += pts[k].distance_to(pts[k - 1])
			var bin := tans[k].cross(nrm).normalized()
			var hb := pts[k].y - y0
			for j in sides + 1:
				var a := TAU * float(j) / float(sides)
				var d := (nrm * cos(a) + bin * sin(a)).normalized()
				var r := radii[k]
				if flute > 0.0:
					var fl := exp(-maxf(hb, 0.0) / flute_h)
					r *= 1.0 + flute * fl * (pow(maxf(sin(a * flute_n + fphase), 0.0), 2.0) - 0.25)
				r *= 1.0 + lumps * (noise(pts[k] * 2.3 + d * 1.3) - 0.5) * 2.0
				var p := pts[k] + d * r
				var col := base_col
				# occlusion near the ground and in crotches, moss on the up side and the base
				var ao := clampf(0.55 + p.y * 0.25, 0.55, 1.0)
				var m := clampf(moss * (smoothstep(0.1, 0.7, d.y) * 0.8 + exp(-maxf(p.y, 0.0) / 1.4)), 0.0, 1.0)
				m *= 0.6 + 0.4 * noise(p * 1.7)
				col = Color(col.r * ao, col.g * ao, col.b * ao).lerp(Color(col.r * 0.42, col.g * 0.78, col.b * 0.5), m)
				if char_amt > 0.0:
					col = col.lerp(Color(0.12, 0.11, 0.11), char_amt * (0.6 + 0.4 * noise(p * 3.0)))
				var tg := (-nrm * sin(a) + bin * cos(a)).normalized()
				s.add(p, d, Vector2(float(j) / float(sides) * circ, along / tile), col, Vector2.ZERO, tg)
		for k in np - 1:
			for j in sides:
				var a0 := start + k * (sides + 1) + j
				var b0 := a0 + sides + 1
				# Godot front faces are clockwise seen from outside
				s.tri(a0, b0, a0 + 1)
				s.tri(a0 + 1, b0, b0 + 1)
		if opts.get("cap", false):
			_cap(s, start + (np - 1) * (sides + 1), sides, pts[np - 1], tans[np - 1])
		if opts.get("cap0", false):
			_cap(s, start, sides, pts[0], -tans[0])

	## Close a ring with a disc of end grain (lighter wood, rings in vertex colour).
	func _cap(s: Surf, ring: int, sides: int, centre: Vector3, out: Vector3) -> void:
		var wc := Color(0.55, 0.5, 0.45) if char_amt <= 0.0 else Color(0.1, 0.09, 0.09)
		var c := s.add(centre + out * 0.04, out, Vector2(0.5, 0.5), wc * 0.8)
		var first := s.v.size()
		for j in sides + 1:
			var p := s.v[ring + j]
			var rr := p.distance_to(centre)
			s.add(p, out, Vector2(0.5, 0.5) + Vector2(cos(TAU * j / sides), sin(TAU * j / sides)) * 0.5, wc * (0.7 + 0.3 * sin(rr * 40.0)))
		for j in sides:
			# winding: the disc faces `out`
			var a := first + j
			var b := first + j + 1
			var face := (s.v[a] - s.v[c]).cross(s.v[b] - s.v[c])
			if face.dot(out) > 0.0:
				s.tri(c, b, a)
			else:
				s.tri(c, a, b)

	func sides_for(r: float) -> int:
		return clampi(int(r * 22.0) + 4, 4, 16)

	## A branch path: start, initial dir, length, gravitropism (+up/-down per metre), wiggle.
	func path(start: Vector3, dir: Vector3, length: float, seg: float, up: float, wig: float) -> PackedVector3Array:
		var n := clampi(int(length / seg) + 1, 2, 24)
		var pts := PackedVector3Array([start])
		var d := dir.normalized()
		var p := start
		var step := length / float(n)
		for k in n:
			d = (d + Vector3.UP * up * step + rvec() * wig * step).normalized()
			if p.y < 1.2 and d.y < 0.1:
				d = (d + Vector3.UP * 0.4).normalized()
			p += d * step
			pts.append(p)
		return pts

	func radii_for(pts: PackedVector3Array, r0: float, r1: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k].distance_to(pts[k - 1])
		var acc := 0.0
		for k in pts.size():
			if k > 0:
				acc += pts[k].distance_to(pts[k - 1])
			var t := acc / maxf(total, 0.001)
			out.append(lerpf(r0, r1, pow(t, 0.85)))
		return out

	func at(pts: PackedVector3Array, t: float) -> Array:
		var f := clampf(t, 0.0, 1.0) * float(pts.size() - 1)
		var k := mini(int(f), pts.size() - 2)
		var p := pts[k].lerp(pts[k + 1], f - float(k))
		return [p, (pts[k + 1] - pts[k]).normalized()]

	## Recursive branching. P: depth arrays (index = depth of the CHILD):
	##  n, angle, len, start, up, r (child r0 / parent r at the fork), seg, wig;
	##  max_depth, leaf_from (depth that carries leaf anchors), leaf_per (anchors per metre)
	func grow(pts: PackedVector3Array, radii: PackedFloat32Array, depth: int, P: Dictionary) -> void:
		var sides := mini(sides_for(radii[0]), [14, 8, 5, 3][mini(depth, 3)])
		var opts := {"lumps": 0.06 if depth > 0 else 0.1, "depth": depth}
		if depth == 0:
			opts["flute"] = P.get("flute", 0.0)
			opts["flute_n"] = P.get("flute_n", 7)
			opts["flute_h"] = P.get("flute_h", 1.6)
		if P.get("broken", false) and depth == 0:
			opts["cap"] = true
		tube(pts, radii, sides, opts)
		var total := 0.0
		for k in range(1, pts.size()):
			total += pts[k].distance_to(pts[k - 1])
		if depth >= int(P.leaf_from):
			var n_l := maxi(1, int(total * float(P.leaf_per)))
			for k in n_l:
				var t := lerpf(0.35, 1.0, (float(k) + rng.randf()) / float(n_l))
				var q: Array = at(pts, t)
				anchors.append([q[0], q[1], depth])
		if depth >= int(P.max_depth):
			return
		var cd := depth + 1
		var nc: int = (P.n as Array)[cd]
		var golden := 2.39996
		var az := rng.randf() * TAU
		for k in nc:
			var t := lerpf(float((P.start as Array)[cd]), 0.97, (float(k) + rng.randf_range(0.2, 0.8)) / float(nc))
			var q: Array = at(pts, t)
			var pdir: Vector3 = q[1]
			az += golden + rng.randf_range(-0.3, 0.3)
			var side := pdir.cross(Vector3.UP if absf(pdir.y) < 0.95 else Vector3.RIGHT).normalized()
			side = side.rotated(pdir, az)
			var ang: float = float((P.angle as Array)[cd]) * rng.randf_range(0.8, 1.2)
			var dir := (pdir * cos(ang) + side * sin(ang)).normalized()
			var plen: float = total * float((P.len as Array)[cd]) * rng.randf_range(0.75, 1.15) * (1.0 - float(P.get("cone", 0.0)) * t)
			if plen < 0.3:
				continue
			var pr := lerpf(radii[0], radii[radii.size() - 1], t)
			var r0: float = maxf(pr * float((P.r as Array)[cd]), 0.012)
			var st: Vector3 = (q[0] as Vector3) - dir * pr * 0.5
			var cp := path(st, dir, plen, float((P.seg as Array)[cd]), float((P.up as Array)[cd]), float((P.wig as Array)[cd]))
			grow(cp, radii_for(cp, r0, r0 * 0.25), cd, P)

	## Roots flaring from the trunk base and diving into the soil.
	func roots(n: int, r: float, reach: float) -> void:
		var az := rng.randf() * TAU
		for k in n:
			az += TAU / float(n) * rng.randf_range(0.8, 1.2)
			var d := Vector3(cos(az), 0, sin(az))
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			var len_k := reach * rng.randf_range(0.7, 1.2)
			for j in 7:
				var t := float(j) / 6.0
				var y := lerpf(r * 1.6, -0.55, pow(t, 0.7)) + sin(t * PI) * 0.15
				pts.append(d * (r * 0.3 + len_k * t) + Vector3(0, y, 0) + d.cross(Vector3.UP) * sin(t * 4.0 + az) * 0.25 * t)
				radii.append(lerpf(r * 0.55, r * 0.1, t))
			tube(pts, radii, 7, {"lumps": 0.15})

	# --- cards -------------------------------------------------------------------------------
	func cell_uv(cell: int) -> Rect2:
		var e := 1.0 / 512.0
		return Rect2(float(cell % 4) * 0.25 + e, float(cell / 4) * 0.25 + e, 0.25 - 2.0 * e, 0.25 - 2.0 * e)

	## One quad: bottom centre b, half-width vector rt, up vector (full height) up. Normals are the
	## caller's volume normal per corner (nfn(pos) -> Vector3); colour per corner (cfn).
	func card(s: Surf, b: Vector3, rt: Vector3, up: Vector3, cell: int, nfn: Callable, cfn: Callable, sw0: float, sw1: float, flip := false) -> void:
		var r := cell_uv(cell)
		var u0 := r.position.x
		var u1 := r.end.x
		if flip:
			var tmp := u0
			u0 = u1
			u1 = tmp
		var ph := rng.randf()
		var ps := [b - rt, b + rt, b + rt + up, b - rt + up]
		var uvs := [Vector2(u0, r.end.y), Vector2(u1, r.end.y), Vector2(u1, r.position.y), Vector2(u0, r.position.y)]
		var sw := [sw0, sw0, sw1, sw1]
		var i0 := s.v.size()
		for k in 4:
			var p: Vector3 = ps[k]
			s.add(p, nfn.call(p), uvs[k], cfn.call(p), Vector2(sw[k], ph))
		s.tri(i0, i0 + 2, i0 + 1)
		s.tri(i0, i0 + 3, i0 + 2)

	## Leaf clusters on every anchor: `per` crossed cards of size sz, the card's twig end on the
	## anchor and its leaves leaning out along the branch and up.
	func crown_cards(cell: int, sz: Vector2, per: int, tint: Color, out_bias := 0.6, up_bias := 0.35, hang := false) -> float:
		if anchors.is_empty():
			return 0.0
		var c := Vector3.ZERO
		for a: Array in anchors:
			c += a[0] as Vector3
		c /= float(anchors.size())
		var cr := 0.0
		for a: Array in anchors:
			cr = maxf(cr, Vector2((a[0] as Vector3).x - c.x, (a[0] as Vector3).z - c.z).length())
		var crown_h := 0.0
		for a: Array in anchors:
			crown_h = maxf(crown_h, absf((a[0] as Vector3).y - c.y))
		var rad := Vector3(maxf(cr, 1.0), maxf(crown_h, 1.0), maxf(cr, 1.0))
		var nfn := func(p: Vector3) -> Vector3:
			var q := (p - c) / rad
			return (q.normalized() + Vector3.UP * 0.35).normalized()
		var cfn := func(p: Vector3) -> Color:
			var q := ((p - c) / rad).length()
			var occ := clampf(0.38 + 0.62 * pow(clampf(q, 0.0, 1.0), 0.8), 0.3, 1.0)
			occ *= clampf(0.82 + 0.18 * (p.y - c.y) / rad.y, 0.6, 1.1)
			var j := 0.9 + 0.2 * noise(p * 0.7)
			var top := clampf((p.y - c.y) / rad.y, 0.0, 1.0)      # the sunlit tops lean yellow-green, the core cool blue-green
			return Color(tint.r * occ * j * (1.0 + 0.16 * top), tint.g * occ * j * (1.0 + 0.05 * top), tint.b * occ * (2.0 - j) * (1.0 - 0.14 * top))
		var ai := -1
		for a: Array in anchors:
			ai += 1
			if far and ai % 2 == 1 and not hang:
				continue
			var p: Vector3 = a[0]
			var d: Vector3 = a[1]
			# a hanging curtain keeps its count and size at range: halved and 1.4x, its cards read as green slabs
			var s := rng.randf_range(sz.x, sz.y) * (1.4 if far and not hang else 1.0)
			var outw := Vector3(p.x - c.x, 0, p.z - c.z).normalized()
			if hang:
				# strands: narrow ribbons with real gaps between them (the texture's own gaps fill in at range, the
				# geometry's do not), scattered round the anchor, the rim's longest so the curtain follows a dome
				var rr := clampf(Vector2(p.x - c.x, p.z - c.z).length() / maxf(cr, 1.0), 0.0, 1.0)
				for k in per:
					var ra := rng.randf() * TAU
					var rt := Vector3(cos(ra), 0, sin(ra)) * s * rng.randf_range(0.075, 0.115)
					var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0)) * s * 0.3
					var tuck := s * rng.randf_range(0.05, 0.3)       # each ribbon's top tucked into the crown by its own amount: no level top edge
					var l := s * rng.randf_range(0.55, 1.25) * (0.6 + 0.6 * rr)
					card(leaf, p - Vector3.UP * (l - tuck) + outw * (0.2 + 0.6 * rr) + off, rt, Vector3.UP * l, cell, nfn, cfn, 1.0, 0.25, rng.randf() < 0.5)
				continue
			var up := (d * out_bias + outw * 0.3 + Vector3.UP * up_bias + rvec() * 0.35).normalized()
			var side := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized()
			var rot := rng.randf() * PI
			for k in per:
				var rt := side.rotated(up, rot + PI * float(k) / float(per)) * s * 0.5
				card(leaf, p - up * s * 0.12, rt, up * s, cell, nfn, cfn, 0.35, 1.0, rng.randf() < 0.5)
		return cr

	# --- assembly ----------------------------------------------------------------------------
	func done(tall: bool, spread: float, bark: String, cards_ground := false) -> Dictionary:
		wood.mat = load(BARK.get(bark, BARK.oak)) if bark != "cap" else load(CAP_MAT)
		glow.mat = load(glow_mat)
		leaf.mat = load(GROUND_MAT if cards_ground else LEAF_MAT)
		var solid: ArrayMesh = null
		if not wood.i.is_empty() or not glow.i.is_empty():
			solid = ArrayMesh.new()
			wood.commit_to(solid, true)
			glow.commit_to(solid, true)
		var cards: ArrayMesh = null
		if not leaf.i.is_empty():
			cards = ArrayMesh.new()
			leaf.commit_to(cards, false)
		return {"solid": solid, "cards": cards, "h": h, "r": trunk_r, "spread": spread, "tall": tall,
			"tris": (wood.i.size() + glow.i.size() + leaf.i.size()) / 3, "card_tris": leaf.i.size() / 3}

	# --- species -----------------------------------------------------------------------------
	func make_oak(v: int) -> Dictionary:
		tile = 1.6
		moss = 0.75
		bark_col = Color(1, 1, 1).lerp(Color(0.85, 0.9, 0.8), rng.randf())
		h = rng.randf_range(15.0, 23.0)
		trunk_r = rng.randf_range(0.7, 1.05) * (h / 19.0)
		var lean := Vector3(rng.randf_range(-0.12, 0.12), 1, rng.randf_range(-0.12, 0.12))
		var trunk_len := h * rng.randf_range(0.5, 0.6)
		var pts := path(Vector3(0, -0.6, 0), lean, trunk_len, 1.0, 0.0, 0.18)
		var radii := radii_for(pts, trunk_r * 1.15, trunk_r * 0.55)
		var P := {
			"n": [0, 5 + v % 3, 5, 3], "angle": [0, 0.95, 0.75, 0.7], "len": [0, 1.0, 0.5, 0.45],
			"start": [0, 0.45, 0.2, 0.25], "up": [0, 0.07, 0.04, 0.06], "r": [0, 0.6, 0.55, 0.55],
			"seg": [0, 1.5, 1.3, 1.2], "wig": [0, 0.3, 0.45, 0.5],
			"max_depth": 3, "leaf_from": 2, "leaf_per": 0.75, "flute": 0.32, "flute_n": 6 + v % 3, "flute_h": 1.7,
		}
		grow(pts, radii, 0, P)
		roots(6 + v % 3, trunk_r, trunk_r * 3.2)
		var cr := crown_cards(C_OAK, Vector2(2.5, 3.5), 2, Color(0.9, 0.95, 0.88))
		return done(true, cr, "oak")

	func make_birch(v: int) -> Dictionary:
		tile = 0.9
		moss = 0.15
		h = rng.randf_range(9.0, 14.0)
		var stems := 1 if v != 2 else 3
		trunk_r = rng.randf_range(0.17, 0.26) * (1.0 if stems == 1 else 0.75)
		for s in stems:
			var lean := Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.15, 0.15))
			if stems > 1:
				var a := TAU * s / stems + rng.randf()
				lean += Vector3(cos(a), 0, sin(a)) * 0.22
			var hl := h * rng.randf_range(0.8, 1.0)
			var pts := path(Vector3(0, -0.5, 0) + Vector3(lean.x, 0, lean.z) * 0.5, lean, hl, 0.9, 0.02, 0.08)
			var P := {
				"n": [0, 14 if stems == 1 else 9, 4 if stems == 1 else 3], "angle": [0, 0.75, 0.6], "len": [0, 0.4, 0.5],
				"start": [0, 0.3, 0.2], "up": [0, 0.05, -0.12], "r": [0, 0.45, 0.6],
				"seg": [0, 1.1, 0.9], "wig": [0, 0.3, 0.45], "cone": 0.55,
				"max_depth": 2, "leaf_from": 1, "leaf_per": 1.9,
			}
			grow(pts, radii_for(pts, trunk_r * 1.1, trunk_r * 0.2), 0, P)
		roots(4, trunk_r, 0.9)
		var cr := crown_cards(C_BIRCH, Vector2(1.4, 2.0), 2, Color(0.72, 0.8, 0.68), 0.4, 0.1)
		return done(true, cr, "birch")

	func make_pine(v: int) -> Dictionary:
		tile = 1.1
		moss = 0.2
		h = rng.randf_range(12.0, 19.0) if v >= 0 else rng.randf_range(3.0, 4.5)
		trunk_r = rng.randf_range(0.3, 0.45) * h / 15.0
		var pts := path(Vector3(0, -0.6, 0), Vector3(rng.randf_range(-0.04, 0.04), 1, rng.randf_range(-0.04, 0.04)), h, 1.4, 0.0, 0.05)
		var radii := radii_for(pts, trunk_r, 0.03)
		tube(pts, radii, mini(sides_for(trunk_r), 10), {"flute": 0.18, "flute_n": 5, "flute_h": 0.8})
		roots(5, trunk_r, 1.4)
		var crown_w := h * rng.randf_range(0.26, 0.34)
		var whorls := int(h / 0.7)
		var c := Vector3(0, h * 0.55, 0)
		var nfn := func(p: Vector3) -> Vector3:
			return (Vector3(p.x, (p.y - c.y) * 0.4, p.z).normalized() + Vector3.UP * 0.5).normalized()
		var cfn := func(p: Vector3) -> Color:
			var q := clampf(Vector2(p.x, p.z).length() / maxf(crown_w * (1.0 - p.y / h) + 0.4, 0.5), 0.0, 1.0)
			var occ := 0.4 + 0.6 * pow(q, 0.7)
			return Color(occ * 0.9, occ, occ * 0.95)
		var az := rng.randf() * TAU
		for wh in whorls:
			var t := lerpf(0.18, 0.98, float(wh) / float(whorls))
			var y := t * h - 0.6
			var bare := t < 0.22
			var nb := 4 + rng.randi_range(0, 2)
			for k in nb:
				az += 2.39996 + rng.randf_range(-0.4, 0.4)
				var reach := (crown_w * pow(1.0 - t, 0.9) + 0.35) * rng.randf_range(0.8, 1.15)
				if bare:
					reach *= 0.45
				var d := Vector3(cos(az), rng.randf_range(-0.35, -0.1), sin(az)).normalized()
				var bp := path(Vector3(0, y, 0), d, reach, 1.2, 0.18, 0.15)
				var br := maxf(trunk_r * (1.0 - t) * 0.35, 0.025)
				if far and br < 0.07 and not bare:
					rng.randf()                    # tube's phase draw: keep the stream in step with the near tree
				else:
					# from 38 m a whorl's thin limbs sit inside its needle sprays: the far pine
					# keeps only the stout lower ones (about half its wood triangles)
					tube(bp, radii_for(bp, br, br * 0.3), 3 if br < 0.06 else 4)
				if bare:
					continue
				# needle sprays along the branch, flat-ish and layered
				var n_s := maxi(1, int(reach / 0.65))
				for j in n_s:
					if far and j % 2 == 1 and j != n_s - 1:
						for r in 4:
							rng.randf()                # keep the stream in step with the near tree
						continue
					var q: Array = at(bp, lerpf(0.25, 1.0, float(j) / float(n_s)))
					var p: Vector3 = q[0]
					var dd: Vector3 = q[1]
					var s := rng.randf_range(1.5, 2.2) * clampf(reach / 2.0, 0.6, 1.0) * (1.35 if far else 1.0)
					var flat := Vector3(dd.x, dd.y * 0.3 - 0.05, dd.z).normalized()
					var rt := flat.cross(Vector3.UP).normalized() * s * 0.5
					card(leaf, p - flat * s * 0.2, rt, flat * s, C_PINE, nfn, cfn, 0.4, 1.0, rng.randf() < 0.5)
					var rt2 := Vector3.UP * s * 0.32 + rt * 0.3
					card(leaf, p - flat * s * 0.2, rt2, flat * s, C_PINE, nfn, cfn, 0.4, 1.0)
		# top leader tuft
		for k in 3:
			var up := (Vector3.UP + rvec() * 0.25).normalized()
			var rt := up.cross(Vector3.RIGHT).normalized().rotated(up, k * PI / 3.0) * 0.6
			card(leaf, Vector3(0, h - 2.0, 0), rt, up * 2.0, C_PINE, nfn, cfn, 0.3, 1.0)
		return done(true, crown_w, "pine")

	func make_willow(v: int) -> Dictionary:
		tile = 1.3
		moss = 0.6
		var dead := v == 2
		bark_col = Color(0.85, 0.85, 0.85)
		h = rng.randf_range(8.0, 11.0)
		trunk_r = rng.randf_range(0.5, 0.7)
		var lean := Vector3(rng.randf_range(-0.35, 0.35), 1, rng.randf_range(-0.35, 0.35))
		var pts := path(Vector3(0, -0.6, 0), lean, rng.randf_range(2.6, 3.6), 0.7, 0.0, 0.25)
		var P := {
			"n": [0, 5, 4, 3], "angle": [0, 0.75, 0.7, 0.8], "len": [0, 1.9, 0.55, 0.5],
			"start": [0, 0.75, 0.3, 0.3], "up": [0, 0.06, -0.05, -0.25], "r": [0, 0.6, 0.55, 0.5],
			"seg": [0, 0.9, 0.7, 0.6], "wig": [0, 0.4, 0.5, 0.6],
			"max_depth": 3 if not dead else 2, "leaf_from": 2, "leaf_per": 0.9 if not dead else 0.5,
			"flute": 0.4, "flute_n": 5, "flute_h": 1.0,
		}
		grow(pts, radii_for(pts, trunk_r * 1.2, trunk_r * 0.8), 0, P)
		roots(5, trunk_r, 2.0)
		var cr: float
		if dead:
			cr = crown_cards(C_HANG, Vector2(1.6, 2.6), 1, Color(0.8, 0.85, 0.75), 0.0, 0.0, true)
		else:
			# a rounded crown of leaf above, thin strands hanging round and under it (a willow is a dome, not curtains)
			cr = crown_cards(C_BIRCH, Vector2(2.0, 2.9), 2, Color(0.30, 0.31, 0.27), 0.3, 0.6)       # (0.25, 0.46, 0.34) read vivid emerald; now the oak crown value family: grey-green
			crown_cards(C_WILLOW, Vector2(2.8, 4.0), 8, Color(0.56, 0.55, 0.5), 0.0, 0.0, true)       # the strands (0.6, 0.78, 0.72) were emerald too: dusty, a touch lighter than the dome
		return done(true, cr, "oak" if not dead else "dead")

	func make_snag(v: int) -> Dictionary:
		tile = 1.4
		moss = 0.3 if v < 2 else 0.0
		char_amt = 0.85 if v == 2 else 0.0
		h = rng.randf_range(6.0, 11.0) if v < 2 else rng.randf_range(9.0, 15.0)        # the rift's burned oaks stand tall
		trunk_r = rng.randf_range(0.35, 0.6)
		var lean := Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2))
		var pts := path(Vector3(0, -0.6, 0), lean, h, 0.8, 0.0, 0.22)
		var P := {
			"n": [0, 5, 2], "angle": [0, 0.9, 0.7], "len": [0, 0.35, 0.5],
			"start": [0, 0.4, 0.3], "up": [0, 0.08, 0.1], "r": [0, 0.45, 0.55],
			"seg": [0, 0.7, 0.5], "wig": [0, 0.55, 0.6],
			"max_depth": 2, "leaf_from": 2, "leaf_per": 0.6, "broken": true,
			"flute": 0.35, "flute_n": 6, "flute_h": 1.4,
		}
		grow(pts, radii_for(pts, trunk_r * 1.15, trunk_r * 0.45), 0, P)
		roots(5, trunk_r, 2.2)
		var cr := crown_cards(C_TWIGS, Vector2(1.2, 1.9), 1, Color(0.7, 0.68, 0.66) if v < 2 else Color(0.25, 0.22, 0.22))
		return done(true, maxf(cr, 2.0), "dead")

	func make_sapling(v: int) -> Dictionary:
		tile = 0.8
		moss = 0.2
		h = rng.randf_range(2.5, 4.5)
		trunk_r = rng.randf_range(0.05, 0.09)
		var pts := path(Vector3(0, -0.3, 0), Vector3(rng.randf_range(-0.2, 0.2), 1, rng.randf_range(-0.2, 0.2)), h, 0.6, 0.0, 0.25)
		if v == 2:
			return make_pine(-1)
		if false:
			tube(pts, radii_for(pts, trunk_r, 0.01), 5)
			var nfn := func(p: Vector3) -> Vector3: return (Vector3(p.x, 0.3, p.z).normalized() + Vector3.UP * 0.5).normalized()
			var cfn := func(p: Vector3) -> Color: return Color(0.85, 0.95, 0.9)
			for wh in 5:
				var y := lerpf(0.4, h - 0.6, wh / 4.0)
				for k in 4:
					var a := TAU * k / 4.0 + wh
					var d := Vector3(cos(a), -0.15, sin(a)).normalized()
					var s := (1.0 - wh / 5.0) * 1.3 + 0.4
					card(leaf, Vector3(0, y, 0), d.cross(Vector3.UP) * s * 0.4, d * s, C_PINE, nfn, cfn, 0.3, 1.0)
			return done(false, 1.2, "pine")
		var P := {
			"n": [0, 6, 3], "angle": [0, 0.8, 0.7], "len": [0, 0.4, 0.5],
			"start": [0, 0.3, 0.3], "up": [0, 0.1, 0.0], "r": [0, 0.5, 0.6],
			"seg": [0, 0.5, 0.4], "wig": [0, 0.4, 0.5], "cone": 0.5,
			"max_depth": 2, "leaf_from": 1, "leaf_per": 1.6,
		}
		grow(pts, radii_for(pts, trunk_r, 0.01), 0, P)
		var cr := crown_cards(C_OAK if v == 0 else C_BIRCH, Vector2(0.8, 1.2), 2, Color(0.6, 0.66, 0.58))
		return done(false, cr, "oak" if v == 0 else "birch")

	## Dome of cluster cards (shrubs, brambles, heather): n cards over a half-ellipsoid.
	func dome(cell: int, n: int, rad: Vector3, sz: Vector2, tint: Color) -> void:
		var c := Vector3(0, rad.y * 0.15, 0)
		var nfn := func(p: Vector3) -> Vector3: return (((p - c) / rad).normalized() + Vector3.UP * 0.4).normalized()
		var cfn := func(p: Vector3) -> Color:
			var q := clampf(((p - c) / rad).length(), 0.0, 1.0)
			var occ := 0.45 + 0.55 * q
			return Color(tint.r * occ, tint.g * occ, tint.b * occ)
		for k in n:
			var a := rng.randf() * TAU
			var e := rng.randf_range(0.05, 1.2)
			var dir := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e))
			var p := c + dir * rad * rng.randf_range(0.2, 0.6)
			p.y = maxf(p.y, -0.1)
			var s := rng.randf_range(sz.x, sz.y)
			var up := (dir * 0.6 + Vector3.UP * 0.6).normalized()
			var rt := up.cross(Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT).normalized() * s * 0.5
			card(leaf, p - up * s * 0.25, rt, up * s, cell, nfn, cfn, 0.2, 1.0, rng.randf() < 0.5)
			card(leaf, p - up * s * 0.25, rt.rotated(up, PI * 0.5), up * s, cell, nfn, cfn, 0.2, 1.0, rng.randf() < 0.5)

	func make_shrub(v: int) -> Dictionary:
		tile = 0.6
		h = rng.randf_range(1.1, 1.8)
		for k in 5:
			var d := Vector3(rng.randf_range(-0.5, 0.5), 1, rng.randf_range(-0.5, 0.5))
			var pts := path(Vector3(0, -0.2, 0), d, h * 0.7, 0.4, 0.0, 0.3)
			tube(pts, radii_for(pts, 0.04, 0.01), 4)
		dome(C_SHRUB if v == 0 else C_OAK, 16, Vector3(h * 0.9, h, h * 0.9), Vector2(1.0, 1.4), Color(0.9, 0.95, 0.9))
		return done(false, h, "oak")

	func make_bramble(v: int) -> Dictionary:
		tile = 0.5
		h = rng.randf_range(0.9, 1.4)
		var w := rng.randf_range(1.6, 2.4)
		for k in 7:
			var a := rng.randf() * TAU
			var d := Vector3(cos(a), 0, sin(a))
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			var reach := w * rng.randf_range(0.6, 1.1)
			for j in 8:
				var t := j / 7.0
				pts.append(d * reach * t + Vector3(0, sin(t * PI) * h * 1.1 - 0.15, 0) + rvec() * 0.05)
				rr.append(lerpf(0.035, 0.015, t))
			tube(pts, rr, 4, {"col": Color(0.55, 0.32, 0.32)})
		dome(C_BRAMBLE, 14 + v * 4, Vector3(w, h, w), Vector2(1.0, 1.5), Color(0.9, 0.95, 0.9))
		return done(false, w, "oak")

	func make_fern(v: int) -> Dictionary:
		h = rng.randf_range(0.6, 1.0) * (1.0 if v == 0 else 1.35)
		var fronds := 8 + v * 3
		var r := cell_uv(C_FERN)
		var nfn := func(p: Vector3) -> Vector3: return (Vector3(p.x, 0.0, p.z).normalized() * 0.3 + Vector3.UP).normalized()
		var az := rng.randf() * TAU
		for f in fronds:
			az += TAU / fronds * rng.randf_range(0.7, 1.3)
			var d := Vector3(cos(az), 0, sin(az))
			var side := d.cross(Vector3.UP)
			var length := h * rng.randf_range(1.0, 1.5)
			var rise := rng.randf_range(0.9, 1.4)
			var width := length * 0.42
			var segs := 5
			var i0 := leaf.v.size()
			var ph := rng.randf()
			for j in segs + 1:
				var t := float(j) / segs
				# arch up and out, then droop
				var p := d * length * t * 0.85 + Vector3.UP * (sin(t * PI * 0.8) * h * rise * 0.7 - t * t * h * 0.25)
				var occ := 0.55 + 0.45 * t
				var col := Color(0.9 * occ, 1.0 * occ, 0.9 * occ)
				var vv := lerpf(r.end.y, r.position.y, t)
				var tw := side.rotated(d, sin(t * PI) * 0.25) * width * 0.5
				leaf.add(p - tw, nfn.call(p), Vector2(r.position.x, vv), col, Vector2(t, ph))
				leaf.add(p + tw, nfn.call(p), Vector2(r.end.x, vv), col, Vector2(t, ph))
			for j in segs:
				var a := i0 + j * 2
				leaf.tri(a, a + 2, a + 1)
				leaf.tri(a + 1, a + 2, a + 3)
		return done(false, h, "oak", true)

	## Crossed vertical cards round a point (grass, reeds): n cards, height range, width factor.
	func tuft(at_p: Vector3, cell: int, n: int, hh: Vector2, wk: float, tint: Color) -> void:
		var nfn := func(p: Vector3) -> Vector3: return (Vector3(p.x - at_p.x, 0, p.z - at_p.z) * 0.6 + Vector3.UP).normalized()
		var cfn := func(p: Vector3) -> Color:
			var q := clampf((p.y - at_p.y) / hh.y, 0.0, 1.0)
			var occ := 0.5 + 0.5 * q
			return Color(tint.r * occ, tint.g * occ, tint.b * occ)
		var rot := rng.randf() * PI
		for k in n:
			var a := rot + PI * float(k) / float(n) + rng.randf_range(-0.2, 0.2)
			var hgt := rng.randf_range(hh.x, hh.y)
			var rt := Vector3(cos(a), 0, sin(a)) * hgt * wk * 0.5
			var lean := Vector3(rng.randf_range(-0.15, 0.15), 1, rng.randf_range(-0.15, 0.15)).normalized()
			var sink := hgt * 0.12
			card(leaf, at_p - Vector3.UP * sink, rt, lean * (hgt + sink), cell, nfn, cfn, 0.0, 1.0, rng.randf() < 0.5)

	func make_grass(v: int) -> Dictionary:
		for k in 3:
			var p := Vector3(rng.randf_range(-0.45, 0.45), 0, rng.randf_range(-0.45, 0.45))
			tuft(p, C_GRASS, 3, Vector2(0.28, 0.62) * (1.0 + v * 0.2), 1.0, Color(0.95, 1.0, 0.95))
		h = 0.6
		return done(false, 0.9, "oak", true)

	func make_tallgrass(_v: int) -> Dictionary:
		for k in 5:
			var p := Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
			tuft(p, C_GRASS, 3, Vector2(0.8, 1.2), 0.9, Color(0.95, 0.98, 0.85))
		h = 1.2
		return done(false, 0.9, "oak", true)

	func make_flowers(v: int) -> Dictionary:
		for k in 4:
			var p := Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
			tuft(p, C_GRASS, 2, Vector2(0.3, 0.5), 1.1, Color(0.95, 1.0, 0.95))
		for k in 2 + v:
			var p := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			tuft(p, C_FLOWERS, 2, Vector2(0.4, 0.6), 1.0, Color(1, 1, 1))
		h = 0.6
		return done(false, 0.8, "oak", true)

	func make_heather(_v: int) -> Dictionary:
		for k in 4:
			var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			tuft(p, C_HEATHER, 3, Vector2(0.35, 0.55), 1.3, Color(0.95, 0.95, 1.0))
		h = 0.5
		return done(false, 0.7, "oak", true)

	func make_reeds(_v: int) -> Dictionary:
		for k in 4:
			var p := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
			tuft(p, C_REEDS, 3, Vector2(1.4, 2.1), 0.7, Color(0.95, 0.95, 0.85))
		h = 2.0
		return done(false, 0.7, "oak", true)

	func make_cattail(_v: int) -> Dictionary:
		for k in 3:
			var p := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
			tuft(p, C_CATTAIL, 3, Vector2(1.3, 1.9), 0.7, Color(0.95, 0.95, 0.85))
		h = 1.9
		return done(false, 0.6, "oak", true)

	## Flat cards lying on the ground (litter, moss): a few overlapping, slightly domed.
	func flats(cell: int, n: int, sz: Vector2, tint: Color) -> void:
		var nfn := func(p: Vector3) -> Vector3: return Vector3.UP
		var cfn := func(p: Vector3) -> Color: return tint
		for k in n:
			var p := Vector3(rng.randf_range(-0.6, 0.6), 0.03 + k * 0.012, rng.randf_range(-0.6, 0.6))
			var s := rng.randf_range(sz.x, sz.y)
			var a := rng.randf() * TAU
			var rt := Vector3(cos(a), 0, sin(a)) * s * 0.5
			var fw := Vector3(-sin(a), 0, cos(a)) * s
			card(leaf, p - fw * 0.5, rt, fw, cell, nfn, cfn, 0.0, 0.0)

	func make_litter(_v: int) -> Dictionary:
		flats(C_LITTER, 3, Vector2(1.2, 1.7), Color(0.8, 0.8, 0.8))
		return done(false, 1.0, "oak", true)

	func make_moss(_v: int) -> Dictionary:
		flats(C_MOSS, 2, Vector2(1.4, 2.0), Color(0.85, 1.0, 0.85))
		return done(false, 1.0, "oak", true)

	## Lathed mushroom: stem and cap; glowing caps go to the glow surface.
	func mushroom(at_p: Vector3, s: float, cap_col: Color, glowing: bool) -> void:
		var stem := PackedVector3Array()
		var rr := PackedFloat32Array()
		var tilt := rvec() * 0.15
		for j in 4:
			var t := j / 3.0
			stem.append(at_p + (Vector3.UP + tilt) * s * t * 1.1 - Vector3.UP * 0.05)
			rr.append(s * lerpf(0.16, 0.11, t))
		tube(stem, rr, 6, {"col": Color(0.82, 0.78, 0.68), "lumps": 0.05})
		var top := stem[3]
		var cs: Surf = glow if glowing else wood
		var segs := 10
		var prof := [Vector2(0.12, -0.08), Vector2(0.55, -0.1), Vector2(0.6, 0.0), Vector2(0.48, 0.18), Vector2(0.25, 0.3), Vector2(0.0, 0.34)]
		var start := cs.v.size()
		for k in prof.size():
			var q: Vector2 = prof[k]
			for j in segs + 1:
				var a := TAU * j / segs
				var d := Vector3(cos(a), 0, sin(a))
				var p := top + d * q.x * s + Vector3.UP * q.y * s
				var nn := (d * (1.0 - float(k) / prof.size()) + Vector3.UP).normalized() if k > 0 else Vector3.DOWN
				var col := cap_col * (0.6 if k == 0 else 1.0)
				cs.add(p, nn, Vector2(float(j) / segs, float(k) / prof.size()), col, Vector2.ZERO, d.cross(Vector3.UP))
		for k in prof.size() - 1:
			for j in segs:
				var a0 := start + k * (segs + 1) + j
				var b0 := a0 + segs + 1
				cs.tri(a0, a0 + 1, b0)
				cs.tri(a0 + 1, b0 + 1, b0)

	func make_mushroom(v: int) -> Dictionary:
		var cols := [Color(0.55, 0.38, 0.22), Color(0.7, 0.55, 0.32), Color(0.5, 0.18, 0.12)]
		for k in rng.randi_range(3, 6):
			var p := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
			mushroom(p, rng.randf_range(0.08, 0.2), cols[(v + k) % cols.size()] * rng.randf_range(0.8, 1.1), false)
		h = 0.3
		return done(false, 0.4, "cap")

	func make_glowcap(_v: int) -> Dictionary:
		for k in rng.randi_range(3, 5):
			var p := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			mushroom(p, rng.randf_range(0.07, 0.16), Color(0.9, 1.0, 0.95), true)
		h = 0.25
		return done(false, 0.4, "cap")

	func make_log(v: int) -> Dictionary:
		tile = 1.4
		moss = 1.0
		var length := rng.randf_range(4.0, 7.0)
		var r := rng.randf_range(0.3, 0.5)
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for j in 9:
			var t := j / 8.0
			pts.append(Vector3(lerpf(-length * 0.5, length * 0.5, t), r * 0.55 + sin(t * PI) * 0.06, sin(t * 3.0 + v) * 0.15))
			rr.append(r * lerpf(1.0, 0.75, t))
		tube(pts, rr, 12, {"cap": true, "cap0": true, "lumps": 0.12})
		for k in 3:
			var t := rng.randf_range(0.2, 0.85)
			var q: Array = at(pts, t)
			var d := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.3, 1.0), (1.0 if k % 2 == 0 else -1.0)).normalized()
			var bp := path(q[0], d, rng.randf_range(0.4, 1.0), 0.3, 0.0, 0.3)
			tube(bp, radii_for(bp, r * 0.25, r * 0.12), 5, {"cap": true})
		trunk_r = r
		h = r * 1.1
		flats(C_MOSS, 0, Vector2.ONE, Color.WHITE)
		return done(false, length * 0.5, "oak" if v == 0 else "dead")

	func make_stump(v: int) -> Dictionary:
		tile = 1.2
		moss = 0.8
		var r := rng.randf_range(0.35, 0.6)
		var hh := rng.randf_range(0.5, 1.1)
		var pts := PackedVector3Array([Vector3(0, -0.5, 0), Vector3(0, 0.1, 0), Vector3(0, hh * 0.5, 0), Vector3(0.02, hh, 0)])
		tube(pts, PackedFloat32Array([r * 1.35, r * 1.15, r, r * 0.95]), 14, {"cap": true, "flute": 0.35, "flute_n": 6, "flute_h": 0.5})
		roots(4 + v, r, r * 2.4)
		trunk_r = r
		h = hh
		return done(false, r * 2.0, "oak" if v == 0 else "dead")

	func make_roots(_v: int) -> Dictionary:
		tile = 1.0
		moss = 0.9
		for k in 3:
			var a := rng.randf() * TAU
			var d := Vector3(cos(a), 0, sin(a))
			var pts := PackedVector3Array()
			var rr := PackedFloat32Array()
			var length := rng.randf_range(2.0, 3.5)
			for j in 8:
				var t := j / 7.0
				pts.append(d * length * (t - 0.5) + Vector3(0, sin(t * PI) * 0.35 - 0.2, 0) + d.cross(Vector3.UP) * sin(t * 5.0 + a) * 0.3)
				rr.append(lerpf(0.16, 0.06, t))
			tube(pts, rr, 7, {"lumps": 0.2})
		return done(false, 1.5, "oak")


	# --- r34 flora: the new regions ------------------------------------------------------------

	## The Cinder Orchard's burned fruit trees: short, forked low into a goblet of crooked limbs, the
	## bark charred black and the tips broken; v2 still holds a few russet leaves.
	func make_fruit(v: int) -> Dictionary:
		tile = 0.9
		moss = 0.0
		char_amt = 0.8 if v != 2 else 0.55
		bark_col = Color(0.8, 0.74, 0.68)
		h = rng.randf_range(3.6, 5.0)
		trunk_r = rng.randf_range(0.16, 0.24)
		var lean := Vector3(rng.randf_range(-0.25, 0.25), 1, rng.randf_range(-0.25, 0.25))
		var pts := path(Vector3(0, -0.5, 0), lean, rng.randf_range(1.1, 1.6), 0.4, 0.0, 0.35)
		var P := {
			"n": [0, 4, 3, 2], "angle": [0, 0.8, 0.7, 0.6], "len": [0, 1.9, 0.5, 0.45],
			"start": [0, 0.8, 0.3, 0.3], "up": [0, 0.14, 0.05, 0.0], "r": [0, 0.72, 0.55, 0.5],
			"seg": [0, 0.45, 0.4, 0.35], "wig": [0, 0.55, 0.65, 0.65],
			"max_depth": 3, "leaf_from": 2, "leaf_per": 0.7, "broken": true,
			"flute": 0.3, "flute_n": 5, "flute_h": 0.6,
		}
		grow(pts, radii_for(pts, trunk_r * 1.25, trunk_r * 0.85), 0, P)
		roots(4, trunk_r, 1.0)
		var cr: float
		if v == 2:
			cr = crown_cards(C_OAK, Vector2(0.6, 0.9), 1, Color(0.78, 0.4, 0.22))
		else:
			cr = crown_cards(C_TWIGS, Vector2(0.9, 1.3), 1, Color(0.2, 0.18, 0.18))
		return done(true, maxf(cr, 2.0), "dead")

	## The Waiting Field's cypresses: a tall dark spindle of needle sprays packed round a straight stem.
	func make_cypress(v: int) -> Dictionary:
		tile = 0.9
		moss = 0.1
		h = rng.randf_range(9.0, 12.5) * (1.0 if v == 0 else 0.78)
		trunk_r = rng.randf_range(0.18, 0.26)
		var pts := path(Vector3(0, -0.6, 0), Vector3(rng.randf_range(-0.03, 0.03), 1, rng.randf_range(-0.03, 0.03)), h, 1.2, 0.0, 0.03)
		tube(pts, radii_for(pts, trunk_r, 0.03), 8, {"flute": 0.25, "flute_n": 5, "flute_h": 0.7})
		roots(4, trunk_r, 0.9)
		var w := h * rng.randf_range(0.1, 0.13)
		var c := Vector3(0, h * 0.45, 0)
		var nfn := func(p: Vector3) -> Vector3:
			return (Vector3(p.x, (p.y - c.y) * 0.2, p.z).normalized() + Vector3.UP * 0.3).normalized()
		var cfn := func(p: Vector3) -> Color:
			var q := clampf(Vector2(p.x, p.z).length() / maxf(w, 0.4), 0.0, 1.0)
			var occ := 0.35 + 0.65 * pow(q, 0.7)
			return Color(0.5 * occ, 0.66 * occ, 0.56 * occ)
		var n := int(h * (4.0 if far else 7.0))
		for k in n:
			var t := lerpf(0.06, 0.98, float(k) / float(n - 1))
			var wr := w * (smoothstep(0.0, 0.2, t) * (1.0 - pow(t, 1.5)) + 0.1)
			var az := rng.randf() * TAU
			var outw := Vector3(cos(az), 0, sin(az))
			var p := outw * wr * 0.35 + Vector3(0, t * h - 0.6, 0)
			var s := rng.randf_range(1.2, 1.7) * clampf(wr / w + 0.35, 0.45, 1.0) * (1.3 if far else 1.0)
			var up := (outw * 0.45 + Vector3.UP).normalized()
			var rt := outw.cross(Vector3.UP).normalized() * s * 0.38
			card(leaf, p - up * s * 0.3, rt, up * s, C_PINE, nfn, cfn, 0.15, 0.6, rng.randf() < 0.5)
		return done(true, w + 0.5, "pine")

	## A churchyard yew: a squat fluted bole, many limbs, a broad, near-black crown of needles.
	func make_yew(v: int) -> Dictionary:
		tile = 1.0
		moss = 0.5
		bark_col = Color(0.78, 0.6, 0.55)
		h = rng.randf_range(4.5, 6.5)
		trunk_r = rng.randf_range(0.32, 0.46)
		var pts := path(Vector3(0, -0.6, 0), Vector3(rng.randf_range(-0.1, 0.1), 1, rng.randf_range(-0.1, 0.1)), h * 0.35, 0.5, 0.0, 0.2)
		var P := {
			"n": [0, 6 + v, 4], "angle": [0, 1.0, 0.8], "len": [0, 2.3, 0.6],
			"start": [0, 0.35, 0.3], "up": [0, 0.12, 0.04], "r": [0, 0.6, 0.5],
			"seg": [0, 0.6, 0.5], "wig": [0, 0.35, 0.45],
			"max_depth": 2, "leaf_from": 1, "leaf_per": 1.5, "flute": 0.45, "flute_n": 6, "flute_h": 0.9,
		}
		grow(pts, radii_for(pts, trunk_r * 1.2, trunk_r * 0.7), 0, P)
		roots(5, trunk_r, 1.6)
		var cr := crown_cards(C_PINE, Vector2(1.4, 2.0), 2, Color(0.42, 0.55, 0.46), 0.5, 0.3)
		return done(true, maxf(cr, 2.0), "oak")

	## The moor's wind-bent thorns: a low stem thrown downwind (+x, the foliage shader's wind), the
	## crown streaming after it, flattened.
	func make_windtree(v: int) -> Dictionary:
		tile = 0.9
		moss = 0.45
		bark_col = Color(0.8, 0.78, 0.74)
		h = rng.randf_range(3.6, 5.2)
		trunk_r = rng.randf_range(0.15, 0.22)
		var pts := PackedVector3Array()
		for j in 8:
			var t := float(j) / 7.0
			pts.append(Vector3(pow(t, 1.5) * h * 0.8, -0.5 + t * h * 0.78 - t * t * h * 0.12, sin(t * 3.0 + v) * 0.2))
		var P := {
			"n": [0, 6, 3], "angle": [0, 0.55, 0.5], "len": [0, 0.5, 0.5],
			"start": [0, 0.45, 0.3], "up": [0, -0.06, -0.04], "r": [0, 0.55, 0.55],
			"seg": [0, 0.5, 0.4], "wig": [0, 0.3, 0.4],
			"max_depth": 2, "leaf_from": 1, "leaf_per": 1.4, "flute": 0.25, "flute_n": 4, "flute_h": 0.6,
		}
		grow(pts, radii_for(pts, trunk_r * 1.25, trunk_r * 0.35), 0, P)
		roots(4, trunk_r, 1.0)
		var cr := crown_cards(C_SHRUB if v == 0 else C_OAK, Vector2(0.9, 1.3), 2, Color(0.62, 0.7, 0.55), 0.9, 0.05)
		return done(true, maxf(cr, 1.5), "oak")

	## Gorse: a dark, spiny dome starred with gold (heather cells tinted to the yellow).
	func make_gorse(v: int) -> Dictionary:
		tile = 0.6
		h = rng.randf_range(0.8, 1.2)
		dome(C_BRAMBLE, 12 + v * 3, Vector3(h * 1.1, h, h * 1.1), Vector2(0.8, 1.1), Color(0.55, 0.68, 0.5))
		dome(C_HEATHER, 6, Vector3(h * 1.05, h * 1.05, h * 1.05), Vector2(0.5, 0.7), Color(1.5, 1.3, 0.25))
		return done(false, h * 1.1, "oak")

	## Soot-killed scrub at the Founder's Pits: bare twig domes.
	func make_deadbush(_v: int) -> Dictionary:
		tile = 0.6
		h = rng.randf_range(0.9, 1.4)
		for k in 4:
			var d := Vector3(rng.randf_range(-0.6, 0.6), 1, rng.randf_range(-0.6, 0.6))
			var pts := path(Vector3(0, -0.2, 0), d, h * 0.7, 0.35, 0.0, 0.35)
			tube(pts, radii_for(pts, 0.035, 0.01), 4, {"col": Color(0.3, 0.27, 0.26)})
		dome(C_TWIGS, 10, Vector3(h * 0.9, h, h * 0.9), Vector2(0.9, 1.3), Color(0.3, 0.27, 0.26))
		return done(false, h, "dead")

	## Grey ash drifted over the ground (litter cards, bleached).
	func make_ashdrift(_v: int) -> Dictionary:
		flats(C_LITTER, 3, Vector2(1.3, 1.9), Color(0.5, 0.48, 0.47))
		return done(false, 1.0, "oak", true)

	## Cinders still alive in the ash: a few small coals on the ember glow.
	func make_cinders(_v: int) -> Dictionary:
		glow_mat = EMBER_MAT
		for k in rng.randi_range(4, 7):
			var c := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
			var r := rng.randf_range(0.04, 0.09)
			var pts := PackedVector3Array([c + Vector3(0, -0.03, 0), c + Vector3(rng.randf_range(-0.05, 0.05), r * 0.8, 0)])
			tube(pts, PackedFloat32Array([r, r * 0.6]), 5, {"surf": glow, "col": Color(1.0, 0.55, 0.3), "cap": true, "lumps": 0.3})
		h = 0.1
		return done(false, 0.5, "cap")

	## Water-plants for the mere: a raft of notched pads lying on the surface (y = 0 is the water).
	func make_lily(_v: int) -> Dictionary:
		var segs := 9
		for k in rng.randi_range(4, 7):
			var c := Vector3(rng.randf_range(-0.7, 0.7), 0.005 + k * 0.004, rng.randf_range(-0.7, 0.7))
			var r := rng.randf_range(0.14, 0.3)
			var notch := rng.randf() * TAU
			var col := Color(0.2, 0.32, 0.16).lerp(Color(0.32, 0.36, 0.14), rng.randf())
			var ci := wood.add(c, Vector3.UP, Vector2(0.5, 0.5), col * 1.1)
			for j in segs + 1:
				var a := notch + 0.35 + (TAU - 0.7) * float(j) / float(segs)
				wood.add(c + Vector3(cos(a), 0, sin(a)) * r, Vector3.UP, Vector2(0.5, 0.5), col * 0.8)
			for j in segs:
				wood.tri(ci, ci + 1 + j, ci + 1 + j + 1)
			if rng.randf() < 0.3:
				mushroom(c + Vector3(0, -0.06, 0), 0.12, Color(0.85, 0.82, 0.75), false)
		h = 0.05
		return done(false, 0.9, "cap")

	## Quarry scaffolding fallen in the rubble: split planks and poles, a broken trestle.
	func make_scaffold(v: int) -> Dictionary:
		tile = 1.2
		moss = 0.15
		bark_col = Color(0.75, 0.68, 0.6)
		for k in 3 + v:
			var a := rng.randf() * TAU
			var d := Vector3(cos(a), 0, sin(a))
			var l := rng.randf_range(2.0, 3.6)
			var c := Vector3(rng.randf_range(-0.6, 0.6), 0.06 + k * 0.08, rng.randf_range(-0.6, 0.6))
			if k % 2 == 0:
				_plank(c, d, l, Vector2(0.28, 0.06))
			else:
				var pts := PackedVector3Array([c - d * l * 0.5 + Vector3(0, 0.05, 0), c + d * l * 0.5 + Vector3(0, 0.05, 0)])
				tube(pts, PackedFloat32Array([0.07, 0.06]), 6, {"cap": true, "cap0": true})
		if v == 1:
			# a trestle leg still standing, propped on its fellows
			var foot := Vector3(0.3, -0.1, 0.2)
			var pts := PackedVector3Array([foot, foot + Vector3(0.5, 1.4, 0.1)])
			tube(pts, PackedFloat32Array([0.08, 0.07]), 6, {"cap": true})
		h = 0.5
		return done(false, 1.8, "dead")

	func _plank(c: Vector3, d: Vector3, l: float, sz: Vector2) -> void:
		var sd := d.cross(Vector3.UP).normalized()
		var hx := d * l * 0.5
		var hz := sd * sz.x * 0.5
		var hy := Vector3.UP * sz.y * 0.5
		var col := bark_col * 0.85
		for f: Array in [[Vector3.UP, hy, hx, hz], [Vector3.DOWN, -hy, -hx, hz], [sd, hz, hx, -hy], [-sd, -hz, hx, hy], [d, hx, hz, hy], [-d, -hx, -hz, hy]]:
			var n: Vector3 = f[0]
			var o: Vector3 = f[1]
			var u: Vector3 = f[2]
			var w: Vector3 = f[3]
			var i0 := wood.v.size()
			var lu := u.length() / tile
			wood.add(c + o - u - w, n, Vector2(0, 0), col, Vector2.ZERO, u.normalized())
			wood.add(c + o + u - w, n, Vector2(lu, 0), col, Vector2.ZERO, u.normalized())
			wood.add(c + o + u + w, n, Vector2(lu, 0.2), col, Vector2.ZERO, u.normalized())
			wood.add(c + o - u + w, n, Vector2(0, 0.2), col, Vector2.ZERO, u.normalized())
			var face := (wood.v[i0 + 1] - wood.v[i0]).cross(wood.v[i0 + 2] - wood.v[i0])
			if face.dot(n) > 0.0:
				wood.tri(i0, i0 + 2, i0 + 1)
				wood.tri(i0, i0 + 3, i0 + 2)
			else:
				wood.tri(i0, i0 + 1, i0 + 2)
				wood.tri(i0, i0 + 2, i0 + 3)

class_name FarDetail
extends RefCounted
## far detail (docs/r37_expansion.md, "Far detail"). The camera sees VIEW_FAR metres (it was 82), so the world
## beyond the near field is always loaded, at very low detail, and detail fades in as you come up to it:
##   - terrain is one whole mesh plus the horizon ring (RealmLand); water, fog and sky do the rest
##   - trees: near mesh -> @far mesh (cross-faded at NEAR_END) -> a canopy shell per forest chunk (canopy_shell)
##   - everything else the Realm builds gets a visibility range with a DITHER FADE by its size (generic_range): small
##     clutter ends 70-130 m out, props 240 m, landmarks (>= 14 m) never end. Nothing is a hard cut.
##   - grass and small clutter keep their own short ranges and thin out (RealmFlora)
## For a landmark's own far mesh (a ~100-300 triangle silhouette of a tower, a wall, a statue):
##     var far := FarDetail.hull(aabb)                                   # or your own Mesh
##     FarDetail.register(host_node, far, xf, 90.0)                      # drawn from 90 m out to the horizon
## register() also fades the host's own meshes out at the same distance (cross-fade), so the near model stops where
## the far mesh starts. Anything you register stays loaded to the horizon (group cull_skip: nothing re-ranges it).

const VIEW_FAR := 420.0                  ## camera far plane (m); the fog has swallowed the world by then
const FAR_TREE_END := 150.0              ## the @far tree meshes end here (the canopy shell carries on)
const FAR_CARD_END := 85.0               ## far leaf cards (overdraw) end here; trunks and the canopy shell carry on
const CANOPY_BEGIN := 65.0              ## a forest chunk's canopy shell fades in from here
const SHELL_CELL := 2.0

static var _shell_mat: ShaderMaterial
static var _far_mat: StandardMaterial3D


## A low-poly far mesh for a landmark: its AABB as a box, tapered towards the top (`taper` 0 = a box, 1 = a point
## at the top: a tower or a roofed hall), the base sunk 0.5 m. Dark and matte: fog and the grade colour it.
static func hull(box: AABB, taper := 0.0, color := Color(0.16, 0.17, 0.2)) -> ArrayMesh:
	var p := box.position
	var s := box.size
	var inset := s * 0.5 * clampf(taper, 0.0, 1.0)
	var lo := PackedVector3Array([
		Vector3(p.x, p.y - 0.5, p.z), Vector3(p.x + s.x, p.y - 0.5, p.z), Vector3(p.x + s.x, p.y - 0.5, p.z + s.z), Vector3(p.x, p.y - 0.5, p.z + s.z)])
	var top := PackedVector3Array([
		Vector3(p.x + inset.x, p.y + s.y, p.z + inset.z), Vector3(p.x + s.x - inset.x, p.y + s.y, p.z + inset.z),
		Vector3(p.x + s.x - inset.x, p.y + s.y, p.z + s.z - inset.z), Vector3(p.x + inset.x, p.y + s.y, p.z + s.z - inset.z)])
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in 4:
		var k2 := (k + 1) % 4
		var b := verts.size()
		verts.append_array(PackedVector3Array([lo[k], lo[k2], top[k2], top[k]]))
		idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
	var b2 := verts.size()
	verts.append_array(top)
	idx.append_array(PackedInt32Array([b2, b2 + 1, b2 + 2, b2, b2 + 2, b2 + 3]))
	var nrms := PackedVector3Array()
	nrms.resize(verts.size())
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(color)
	# flat normals per face (each quad owns its four vertices)
	for q in range(0, verts.size() - 4, 4):
		var n := (verts[q + 1] - verts[q]).cross(verts[q + 2] - verts[q]).normalized()
		for j in 4:
			nrms[q + j] = -n if n.dot(verts[q] - (box.position + s * 0.5)) < 0.0 else n
	for j in 4:
		nrms[b2 + j] = Vector3.UP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, far_material())
	return m


## The shared matte material of far meshes (vertex colour, no shadows, no specular).
static func far_material() -> StandardMaterial3D:
	if _far_mat == null:
		_far_mat = StandardMaterial3D.new()
		_far_mat.vertex_color_use_as_albedo = true
		_far_mat.roughness = 1.0
		_far_mat.metallic_specular = 0.0
		_far_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _far_mat


## Draw `far` under `host` (a Node3D) from `near_end` metres out to the horizon, cross-fading with the host's own
## meshes, which stop at the same distance. `xf` is local to host. Returns the MeshInstance3D.
static func register(host: Node, far: Mesh, xf := Transform3D.IDENTITY, near_end := 90.0, material: Material = null, fade_host := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FarMesh"
	mi.mesh = far
	if material != null:
		mi.material_override = material
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var margin := maxf(8.0, near_end * 0.12)
	mi.visibility_range_begin = near_end
	mi.visibility_range_begin_margin = margin
	mi.visibility_range_end = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.extra_cull_margin = 4.0
	mi.set_meta(&"far_detail", true)
	mi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mi)
	if fade_host:
		near_ends(host, near_end, margin, mi)
	return mi


## The geometry under `node` ends at `end` metres (dither fade over `margin`), except `skip` and far meshes.
static func near_ends(node: Node, end: float, margin: float, skip: Node = null) -> int:
	var n := 0
	for c in node.find_children("*", "GeometryInstance3D", true, false):
		var gi := c as GeometryInstance3D
		if gi == skip or gi.has_meta(&"far_detail") or gi is GPUParticles3D:
			continue
		gi.visibility_range_end = end
		gi.visibility_range_end_margin = margin
		gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		gi.add_to_group(Groups.CULL_SKIP)
		n += 1
	if node is GeometryInstance3D and node != skip and not node.has_meta(&"far_detail"):
		var g := node as GeometryInstance3D
		g.visibility_range_end = end
		g.visibility_range_end_margin = margin
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		g.add_to_group(Groups.CULL_SKIP)
		n += 1
	return n


## The range a Realm-built mesh gets by its size (world extent of its AABB), with a dither fade. Returns true when it
## set one. Instances that already have a range, a far mesh, or sit in cull_skip are left alone.
static func generic_range(gi: GeometryInstance3D, extent: float) -> bool:
	if gi.visibility_range_end > 0.0 or gi.visibility_range_begin > 0.0 or gi.is_in_group(Groups.CULL_SKIP) or gi.has_meta(&"far_detail"):
		return false
	var end := 0.0
	var margin := 0.0
	if extent < 1.5:
		end = 70.0
		margin = 10.0
	elif extent < 5.0:
		end = 130.0
		margin = 16.0
	elif extent < 14.0:
		end = 240.0
		margin = 30.0
	else:
		return false                                 # landmarks: loaded to the horizon
	gi.visibility_range_end = end
	gi.visibility_range_end_margin = margin
	gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return true


## One forest chunk's canopy as a coarse heightfield shell: `trees` = [[base Vector3, height, crown radius, conifer]],
## the chunk's centre `c` and half size. Cells without crown sit 0.8 m under the ground (buried). Each tree stamps
## only the cells under its own crown (a broadleaf is a lumpy ellipsoid with a ragged rim, a conifer a narrow cone
## with a spire at the top), so the silhouette reads as individual crowns and the cost follows the tree count, not
## the cell count. Dark, matte, a little moon on the crown tops and a shaded foot: the fog gives it depth.
## Drawn from CANOPY_BEGIN to the horizon, fading in as the individual trees fade out.
static func canopy_shell(host: Node3D, c: Vector3, half: float, trees: Array, ground: Callable, nm: String) -> MeshInstance3D:
	var n := int(ceil(half * 2.0 / SHELL_CELL)) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	cols.resize(n * n)
	var gys := PackedFloat32Array()
	gys.resize(n * n)
	var tops := PackedFloat32Array()
	tops.resize(n * n)
	var shade := PackedFloat32Array()
	shade.resize(n * n)
	var spire := PackedFloat32Array()
	spire.resize(n * n)
	for j in n:
		for i in n:
			var k := j * n + i
			var gy: float = ground.call(c.x - half + float(i) * SHELL_CELL, c.z - half + float(j) * SHELL_CELL)
			gys[k] = gy
			tops[k] = gy - 0.8
	var any := false
	var x0 := c.x - half
	var z0 := c.z - half
	for t: Array in trees:
		var b: Vector3 = t[0]
		var r: float = t[2]
		var h: float = t[1]
		var conifer: bool = t[3]
		var reach := r * 1.35 if not conifer else r
		var lobes: Array[Vector4] = []
		if not conifer:
			lobes = _lobes(b)
		var i0 := maxi(int(floor((b.x - reach - x0) / SHELL_CELL)), 0)
		var i1 := mini(int(ceil((b.x + reach - x0) / SHELL_CELL)), n - 1)
		var j0 := maxi(int(floor((b.z - reach - z0) / SHELL_CELL)), 0)
		var j1 := mini(int(ceil((b.z + reach - z0) / SHELL_CELL)), n - 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var x := x0 + float(i) * SHELL_CELL
				var z := z0 + float(j) * SHELL_CELL
				var dx := x - b.x
				var dz := z - b.z
				var d2 := (dx * dx + dz * dz) / (r * r)
				var y: float
				var sh := 0.0
				var sp := 0.0
				if conifer:
					if d2 >= 1.0:
						continue
					var d := sqrt(d2)
					y = b.y + h * (0.16 + 0.84 * (1.0 - d))      # a cone: the tip is the tree's top
					sh = 1.0 - d
					sp = 1.0 - d
				else:
					# a broadleaf crown is a cluster of lobes (a centre and four round it), each a lumpy ellipsoid
					var lump := _vnoise(x * 0.37 + b.x * 0.11, z * 0.37 + b.z * 0.07)
					var bump := _vnoise(x * 0.85, z * 0.85)
					y = -INF
					for lb: Vector4 in lobes:                  # (x, z offset in crown radii, radius, height)
						var lx := dx - lb.x * r
						var lz := dz - lb.y * r
						var ld2 := (lx * lx + lz * lz) / (lb.z * lb.z * r * r)
						ld2 *= 1.0 - 0.6 * (lump - 0.5) - 0.4 * (bump - 0.5)      # a ragged rim
						if ld2 >= 1.0:
							continue
						var ly := b.y + h * lb.w * (0.42 + 0.56 * sqrt(1.0 - ld2)) * (0.93 + 0.08 * lump + 0.05 * bump)
						if ly > y:
							y = ly
							sh = 1.0 - ld2
					if y == -INF:
						continue
				var k := j * n + i
				if y > tops[k]:
					tops[k] = y
					shade[k] = sh
					spire[k] = sp
					any = true
	if not any:
		return null
	for j in n:
		for i in n:
			var k := j * n + i
			verts[k] = Vector3(x0 + float(i) * SHELL_CELL - c.x, tops[k] - c.y, z0 + float(j) * SHELL_CELL - c.z)
			var up := clampf((tops[k] - gys[k]) / 16.0, 0.0, 1.0)          # height over the ground: the foot sits in shade, the tops catch the moon
			var gx := x0 + float(i) * SHELL_CELL
			var gz := z0 + float(j) * SHELL_CELL
			var mott := 0.72 + 0.56 * _vnoise(gx * 0.9, gz * 0.9)           # leaf masses: lighter and darker lumps a few metres across
			var base := Color(0.03, 0.05, 0.05).lerp(Color(0.09, 0.15, 0.13), shade[k])
			base = base.lerp(Color(0.15, 0.24, 0.21), up * up * 0.5 + spire[k] * 0.12)
			cols[k] = Color(base.r * mott, base.g * mott, base.b * mott)
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array(PackedInt32Array([a, a + 1, a + n, a + 1, a + n + 1, a + n]))
	var nrms := PackedVector3Array()
	nrms.resize(n * n)
	for j in n:
		for i in n:
			var hl := verts[j * n + maxi(i - 1, 0)].y
			var hr := verts[j * n + mini(i + 1, n - 1)].y
			var hd := verts[maxi(j - 1, 0) * n + i].y
			var hu := verts[mini(j + 1, n - 1) * n + i].y
			nrms[j * n + i] = Vector3(-(hr - hl) / (2.0 * SHELL_CELL), 1.0, -(hu - hd) / (2.0 * SHELL_CELL)).normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = nrms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _shell_mat == null:
		_shell_mat = ShaderMaterial.new()
		_shell_mat.shader = load("res://core/world/canopy_shell.gdshader") as Shader
	m.surface_set_material(0, _shell_mat)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = m
	mi.position = c
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_begin = CANOPY_BEGIN
	mi.visibility_range_begin_margin = 30.0
	mi.visibility_range_end = 0.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.set_meta(&"far_detail", true)
	mi.add_to_group(Groups.CULL_SKIP)
	host.add_child(mi)
	return mi


## The lobes of one broadleaf crown, deterministic from its base: a centre and four round it (offset and radius in
## crown radii, height as a share of the tree's).
static func _lobes(b: Vector3) -> Array[Vector4]:
	var out: Array[Vector4] = [Vector4(0.0, 0.0, 0.78, 1.0)]
	var a0 := _h2(b.x * 1.3, b.z * 0.7) * TAU
	for q in 4:
		var a := a0 + float(q) * TAU * 0.25 + (_h2(b.x + float(q), b.z) - 0.5) * 0.7
		var off := 0.42 + 0.22 * _h2(b.z + float(q), b.x)
		out.append(Vector4(cos(a) * off, sin(a) * off, 0.5 + 0.16 * _h2(b.x * 0.3 + float(q), b.z * 0.5), 0.82 + 0.2 * _h2(float(q) + b.z, b.x * 0.9)))
	return out


## Cheap value noise 0..1 (the shell's lumps): hashed lattice, smooth between.
static func _vnoise(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _h2(ix, iz)
	var b := _h2(ix + 1.0, iz)
	var c := _h2(ix, iz + 1.0)
	var d := _h2(ix + 1.0, iz + 1.0)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _h2(x: float, z: float) -> float:
	return fposmod(sin(x * 127.1 + z * 311.7) * 43758.5453, 1.0)


## Collect one chunk's tall trees [[base, height, crown radius, conifer]] for its canopy shell (RealmFlora._emit).
static func note_crowns(canopy: Dictionary, key: Vector3i, list: Array, h: float, spread: float, conifer := false) -> void:
	if not canopy.has(key):
		canopy[key] = []
	for e: Array in list:
		var xf: Transform3D = e[0]
		var sc := xf.basis.get_scale().x
		(canopy[key] as Array).append([xf.origin, h * sc, maxf(spread * sc * (0.55 if conifer else 0.85), 1.0), conifer])


## A canopy shell for every collected chunk (key x, z in chunk units); returns how many were made.
static func shells(host: Node3D, canopy: Dictionary, chunk: float, ground: Callable) -> int:
	var made := 0
	for key: Vector3i in canopy:
		var cx := (key.x + 0.5) * chunk
		var cz := (key.y + 0.5) * chunk
		var gy: float = ground.call(cx, cz)
		if canopy_shell(host, Vector3(cx, gy, cz), chunk * 0.5 + 2.0, canopy[key], ground, "Canopy_%d_%d" % [key.x, key.y]) != null:
			made += 1
	return made


## Release the shared materials (RealmFlora / Realm.release_caches: no engine resource outlives the tree).
static func release() -> void:
	_shell_mat = null
	_far_mat = null

extends RefCounted
## THE STAR-FALL CRATER (the White Pans, south-east of Saltmarket). Lore: the night the sky began to turn, a
## star came down on the salt. It did not burst. It struck once, fused the pans to glass for sixty paces and
## stayed, hanging a few fathoms over its own grave, turning as the sky turns. The Order's surveyors called it a
## Wound and measured it; the salt-workers call it the Lamp and keep their rakes out of its rays.
##   - the crater: a shallow bowl of black glass, cracked into plates that the star lights from beneath, a raised
##     rim of fused crust, and a ragged skirt of glass giving out to salt (one heightfield, walkable)
##   - the crystals: great shards rooted in the rim and leaning off it, rays of lesser shards thrown outward
##     across the pans, a crown of small ones on the crest (solid; flat-shaded, glow rising to the tips)
##   - the heart: the star itself, a faceted core with long spikes, turning and pulsing over the middle, a
##     halo that makes it a point of light for miles, a ring of slow fragments in orbit, a hum, motes
##   - the climb: stepping slabs of fused glass spiralling in from the crater floor to a platform under the heart
##     (a secret: core/life/secrets/site_star_crater.gd)
## Everything animated is in the shaders. Three lights at most. Placed clear of the salt-works, derricks and pans,
## the camps and the salt track; every piece is tested against the physics world and the collision-less meshes.

const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const Soup := preload("res://core/world/realm/wonders/star_crater/shard_soup.gd")
const Shaders := preload("res://core/world/realm/wonders/star_crater/crater_shaders.gd")

const C := Vector2(178.0, 146.0)       ## the crater's centre (xz): flat salt between the hills and the salt track
const FLOOR_R := 8.0                   ## the glass floor
const RIM_R := 12.5                    ## the crest (varies round the ring)
const RIM_H := 2.1
const MESH_R := 24.0
const HEART_H := 13.0                  ## the heart over the floor
const STEPS := 14                      ## stepping slabs before the platform
const STEP_RISE := 0.52
const PROBE_LAYER := 1 << 30           ## stand-in bodies (nothing else uses it; freed after)

var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var g0 := 0.0
var heart := Vector3.ZERO
var host: Node3D
var _temp: Array[Node] = []
var _audit: Array[String] = []
var _last_hit := ""
var _segs: Array = []                  ## placed shards as [a, b, radius, cluster]: they keep clear of each other
var _gcache := {}
var _stats := {}


static func build(root: Node) -> void:
	var w := new()
	await w._run(root)


func _run(root: Node) -> void:
	rng.seed = 3801
	noise.seed = 77
	noise.frequency = 0.5
	space = (root as Node3D).get_world_3d().direct_space_state
	g0 = _ground(C.x, C.y, NAN)
	if is_nan(g0):
		push_warning("WONDER star_crater: no ground at %s" % C)
		return
	heart = Vector3(C.x, g0 + HEART_H, C.y)
	host = Node3D.new()
	host.name = "StarCrater"
	root.add_child(host)
	WorldLanes.register_terrace("star_crater", C, 14.0, g0)
	WorldLanes.register_site("star_crater_ground", Rect2(144.0, 120.0, 58.0, 60.0), g0 + 0.05, g0 + 0.05)
	_stand_ins(root)
	await root.get_tree().physics_frame
	var glass := _glass()
	var solids := Soup.new()
	_shards(solids)
	var slabs := Soup.new()
	var hulls := _stair(slabs)
	_commit_shards(solids)
	_commit_slabs(slabs, hulls)
	_heart()
	_fragments()
	_lights()
	_motes()
	_hum()
	var marker := Node3D.new()
	marker.name = "HeartPlatform"
	marker.set_meta("top", Vector3(C.x, g0 + 0.5 + STEP_RISE * float(STEPS), C.y))
	marker.set_meta("basis", Basis.IDENTITY)
	marker.set_meta("heart", heart)
	marker.set_meta("floor", g0)
	host.add_child(marker)
	marker.global_position = marker.get_meta("top")
	for b in _temp:
		b.queue_free()
	_temp.clear()
	var bn: Variant = Wayfinding.beacon(host, heart, "", Color(0.66, 0.86, 1.0), 0.0, 0.7, 0.0, false, 320.0)
	if bn is Node:
		(bn as Node).name = "Beacon_star_crater"
	print("WONDER star_crater at %s (ground %.2f): glass %d tris, %d great, %d ray, %d crown shards, %d steps" % [
		Vector2(C.x, C.y), g0, glass, int(_stats.get("great", 0)), int(_stats.get("ray", 0)), int(_stats.get("crown", 0)), STEPS])
	print("WONDER star_crater clearance: %s" % ("nothing touched" if _audit.is_empty() else "; ".join(_audit)))


# --- the ground ---------------------------------------------------------------------------------------

func _ground(x: float, z: float, fallback: float) -> float:
	var key := Vector2i(roundi(x * 4.0), roundi(z * 4.0))
	if _gcache.has(key):
		return _gcache[key]
	var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -30.0, z), Layers.WORLD))
	var y := fallback if h.is_empty() else (h.position as Vector3).y
	if not is_nan(fallback):
		y = clampf(y, fallback - 1.5, fallback + 2.5)       # a rock or a roof in the way is not the ground
	_gcache[key] = y
	return y


## The crest at bearing `th`: radius and height (the rim is not a ring).
func _rim(th: float) -> Vector2:
	var nx := cos(th) * 1.6
	var ny := sin(th) * 1.6
	return Vector2(RIM_R + noise.get_noise_2d(nx, ny) * 1.6, RIM_H * (1.0 + 0.45 * noise.get_noise_2d(nx + 31.0, ny - 17.0)))


## The crater's height above its floor at (x, z): flat glass, the rim rising to a ragged crest, the long skirt.
func _profile(x: float, z: float) -> float:
	var d := Vector2(x, z) - C
	var r := d.length()
	var rim := _rim(atan2(d.y, d.x))
	var h := 0.0
	if r > FLOOR_R:
		if r <= rim.x:
			var t := (r - FLOOR_R) / (rim.x - FLOOR_R)
			h = rim.y * t * t * (3.0 - 2.0 * t)
		else:
			var t2 := clampf((r - rim.x) / 9.0, 0.0, 1.0)
			h = rim.y * pow(1.0 - t2 * t2 * (3.0 - 2.0 * t2), 1.25)
	return h + 0.14 * noise.get_noise_2d(x * 0.9, z * 0.9) * smoothstep(0.15, 0.7, h / RIM_H)


## The glass surface's world height at (x, z).
func _surface(x: float, z: float) -> float:
	var r := Vector2(x, z).distance_to(C)
	var k := smoothstep(14.0, 19.0, r)
	var base := lerpf(g0 + 0.06, _ground(x, z, g0) + 0.12, k)
	return base + _profile(x, z)


func _glass() -> int:
	var radii: Array[float] = [0.0, 1.6, 3.2, 4.8, 6.2, 7.2, 8.0, 8.8, 9.6, 10.4, 11.2, 11.9, 12.6, 13.3, 14.2, 15.2, 16.5, 18.0, 19.6, 21.2, 22.8, 24.0]
	var n := 112
	var pos := PackedVector3Array()
	var ring_of: Array = []
	for ri in radii.size():
		var r := radii[ri]
		var start := pos.size()
		var cnt := 1 if ri == 0 else n
		for i in cnt:
			var a := TAU * float(i) / float(n)
			var x := C.x + cos(a) * r
			var z := C.y + sin(a) * r
			pos.append(Vector3(x, _surface(x, z), z))
		ring_of.append([start, cnt])
	var idx := PackedInt32Array()
	for ri in range(1, radii.size()):
		var inner: Array = ring_of[ri - 1]
		var outer: Array = ring_of[ri]
		for i in n:
			var j := (i + 1) % n
			var o0: int = outer[0] + i
			var o1: int = outer[0] + j
			if ri == 1:
				idx.append_array([inner[0], o0, o1])
			else:
				var i0: int = inner[0] + i
				var i1: int = inner[0] + j
				idx.append_array([i0, o0, o1, i0, o1, i1])
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for t in range(0, idx.size(), 3):
		var fn := (pos[idx[t + 1]] - pos[idx[t]]).cross(pos[idx[t + 2]] - pos[idx[t]])
		for q in 3:
			nrm[idx[t + q]] += fn
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 1e-9 else Vector3.UP
		if nrm[i].y < 0.0:
			nrm[i] = -nrm[i]
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Shaders.GLASS
	sm.shader = sh
	sm.set_shader_parameter("centre", Vector3(C.x, g0, C.y))
	var mi := MeshInstance3D.new()
	mi.name = "Glass"
	mi.mesh = mesh
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GlassBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = _solid(mesh)
	body.add_child(cs)
	host.add_child(body)
	return idx.size() / 3


# --- the crystals -------------------------------------------------------------------------------------

func _crystal_mat(strength := 1.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Shaders.CRYSTAL
	sm.shader = sh
	sm.set_shader_parameter("heart", heart)
	sm.set_shader_parameter("strength", strength)
	return sm


func _hue() -> Array:
	var h := rng.randf_range(0.5, 0.74)
	return [Color.from_hsv(h + 0.04, rng.randf_range(0.7, 0.9), rng.randf_range(0.06, 0.14)), Color.from_hsv(h - 0.02, rng.randf_range(0.5, 0.72), rng.randf_range(0.26, 0.44))]


func _gap(th: float) -> bool:
	var home := atan2(-C.y, -C.x)                 # towards Hearthward: the way in stays open
	return absf(angle_difference(th, home)) < 0.34 or absf(angle_difference(th, 0.0)) < 0.38


## One crystal after its clearance checks: off the tracks and camps, clear of the world's collision and the
## collision-less meshes, and of the shards already placed (except its own cluster). Returns whether it stands.
func _shard(soup: Soup, root: Vector3, dir: Vector3, length: float, radius: float, cluster: int, label: String, sink := 0.8) -> bool:
	dir = dir.normalized()
	var tip := root + dir * length
	for p: Vector3 in [root, tip, root + dir * length * 0.5]:
		if RealmLayout.path_dist(Vector2(p.x, p.z)) < 5.0 + radius:
			_stats["skipped"] = int(_stats.get("skipped", 0)) + 1
			return false
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a: Vector3 = cmp.at
			if Vector2(a.x, a.z).distance_to(Vector2(p.x, p.z)) < 16.0:
				_stats["skipped"] = int(_stats.get("skipped", 0)) + 1
				return false
	for s: Array in _segs:
		if int(s[3]) == cluster:
			continue
		var cp := Geometry3D.get_closest_points_between_segments(root, tip, s[0], s[1])
		if cp[0].distance_to(cp[1]) < radius + float(s[2]) + 0.25:
			return false
	var q := Quaternion(Vector3.UP, dir)
	var span := maxf(length - 0.9, 0.2)
	var xf := Transform3D(Basis(q), root + dir * (0.6 + span * 0.5))
	if not _clear(xf, Vector3(radius * 1.9, span, radius * 1.9), 0.15, true):
		_audit.append("%s left out (%s)" % [label, _last_hit])
		return false
	var cols := _hue()
	var sides := 6 if radius > 0.45 else 5
	var skew := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
	soup.crystal(root, dir, length, radius, sides, skew, rng.randf_range(-0.5, 0.5), cols[0], cols[1], rng, sink)
	_segs.append([root, tip, radius, cluster])
	return true


func _shards(soup: Soup) -> void:
	var cluster := 0
	# the great shards: rooted on the rim's outer crest, leaning off it
	var count := 11
	var off := rng.randf() * TAU
	for i in count:
		var th := off + TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		if _gap(th):
			continue
		var rim := _rim(th)
		var rr := rim.x + rng.randf_range(0.2, 1.4)
		var x := C.x + cos(th) * rr
		var z := C.y + sin(th) * rr
		var y := _surface(x, z)
		var radial := Vector3(cos(th), 0.0, sin(th))
		var tang := Vector3(-sin(th), 0.0, cos(th))
		var lean := deg_to_rad(rng.randf_range(14.0, 34.0))
		var len: float = rng.randf_range(12.0, 25.0)
		if i == 3 or i == 8:
			len = rng.randf_range(34.0, 40.0)
		var dir := (radial * sin(lean) + tang * rng.randf_range(-0.12, 0.12) + Vector3.UP * cos(lean))
		cluster += 1
		if _shard(soup, Vector3(x, y, z), dir, len, rng.randf_range(1.2, 1.9), cluster, "great shard %d" % i, 1.4):
			_stats["great"] = int(_stats.get("great", 0)) + 1
			for j in rng.randi_range(2, 3):
				var side := -1.0 if j % 2 == 0 else 1.0
				var rp := Vector3(x, y, z) + tang * side * rng.randf_range(1.3, 2.2) + radial * rng.randf_range(-0.5, 0.9)
				rp.y = _surface(rp.x, rp.z)
				var d2 := (dir.normalized() + tang * side * rng.randf_range(0.18, 0.4) + radial * rng.randf_range(0.0, 0.3)).normalized()
				if _shard(soup, rp, d2, len * rng.randf_range(0.28, 0.5), rng.randf_range(0.5, 0.9), cluster, "great shard %d companion" % i, 1.0):
					_stats["great"] = int(_stats.get("great", 0)) + 1
	# rays: lesser shards thrown outward across the pans, lying low, each smaller than the last
	var rays := 6
	var roff := rng.randf() * TAU
	for i in rays:
		var th := roff + TAU * float(i) / float(rays) + rng.randf_range(-0.1, 0.1)
		if _gap(th):
			continue
		var radial := Vector3(cos(th), 0.0, sin(th))
		for k in 4:
			var rr := 22.0 + 4.6 * float(k) + rng.randf_range(-0.8, 0.8)
			var x := C.x + cos(th) * rr + rng.randf_range(-0.8, 0.8)
			var z := C.y + sin(th) * rr + rng.randf_range(-0.8, 0.8)
			var y := _ground(x, z, g0) + 0.0
			var lean := deg_to_rad(rng.randf_range(58.0, 76.0))
			var dir := radial * sin(lean) + Vector3.UP * cos(lean)
			var len: float = float([8.5, 6.5, 4.8, 3.2][k]) * rng.randf_range(0.85, 1.15)
			cluster += 1
			if _shard(soup, Vector3(x, y, z), dir, len, [1.0, 0.8, 0.62, 0.48][k], cluster, "ray %d.%d" % [i, k], 0.9):
				_stats["ray"] = int(_stats.get("ray", 0)) + 1
	# the crown: small crystals along the crest between the great ones
	for i in 34:
		var th := rng.randf() * TAU
		if _gap(th):
			continue
		var rim := _rim(th)
		var rr := rim.x + rng.randf_range(-1.2, 2.0)
		var x := C.x + cos(th) * rr
		var z := C.y + sin(th) * rr
		var y := _surface(x, z)
		var az := th if rng.randf() < 0.7 else rng.randf() * TAU
		var lean := deg_to_rad(rng.randf_range(8.0, 52.0))
		var dir := Vector3(cos(az) * sin(lean), cos(lean), sin(az) * sin(lean))
		cluster += 1
		if _shard(soup, Vector3(x, y, z), dir, rng.randf_range(1.6, 4.6), rng.randf_range(0.28, 0.7), cluster, "crown %d" % i, 0.6):
			_stats["crown"] = int(_stats.get("crown", 0)) + 1


func _solid(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var sh := mesh.create_trimesh_shape()
	sh.backface_collision = true                 # walked on from above, and never fallen through from either side
	return sh


func _commit_shards(soup: Soup) -> void:
	var mesh := soup.build()
	var mi := MeshInstance3D.new()
	mi.name = "Shards"
	mi.mesh = mesh
	mi.material_override = _crystal_mat()
	mi.extra_cull_margin = 8.0
	host.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "ShardsBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = _solid(mesh)
	body.add_child(cs)
	host.add_child(body)


# --- the climb ----------------------------------------------------------------------------------------

## Stepping slabs of fused glass spiralling in and up from the crater floor, a platform under the heart.
## Returns each slab's convex hull (walkable), the platform's last.
func _stair(soup: Soup) -> Array:
	var hulls: Array = []
	var phi := atan2(-C.y, -C.x) + 0.35         # the first slab on the Hearthward side of the floor
	var kept := 0
	for k in STEPS + 1:
		var t := float(k) / float(STEPS)
		var top_y := g0 + 0.5 + STEP_RISE * float(k)
		var cols := [Color(0.03, 0.07, 0.12), Color(0.02, 0.05, 0.1), Color(0.3, 0.68, 0.95)]
		if k == STEPS:
			var hull := soup.slab(Vector3(C.x, top_y, C.y), 2.5, 0.6, 0.2, 2.8, cols[0], cols[1], cols[2], rng)
			hulls.append(hull)
			break
		var r := lerpf(7.4, 3.9, t)
		var at := Vector3(C.x + cos(phi) * r, top_y, C.y + sin(phi) * r)
		if not _clear(Transform3D(Basis.IDENTITY, at - Vector3(0, 1.0, 0)), Vector3(2.5, 2.6, 2.5), 0.1, true):
			_audit.append("step %d touches %s" % [k, _last_hit])
		var hull2 := soup.slab(at, 1.2, 0.45, rng.randf() * TAU, rng.randf_range(1.0, 2.3), cols[0], cols[1], cols[2], rng)
		hulls.append(hull2)
		kept += 1
		phi += 3.3 / r
	return hulls


func _commit_slabs(soup: Soup, hulls: Array) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Steps"
	mi.mesh = soup.build()
	mi.material_override = _crystal_mat(0.9)
	host.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "StepsBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	for hp: PackedVector3Array in hulls:
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = hp
		cs.shape = sh
		body.add_child(cs)
	host.add_child(body)


# --- the heart ----------------------------------------------------------------------------------------

func _heart() -> void:
	var s := Soup.new()
	var hr := RandomNumberGenerator.new()
	hr.seed = 9
	var phi := (1.0 + sqrt(5.0)) * 0.5
	var iv: Array[Vector3] = []
	for a: float in [-1.0, 1.0]:
		for b: float in [-phi, phi]:
			iv.append(Vector3(0.0, a, b))
			iv.append(Vector3(a, b, 0.0))
			iv.append(Vector3(b, 0.0, a))
	var core := Color(0.5, 0.8, 1.0, 0.45)
	s.centre = Vector3.ZERO
	var r0 := 0.62
	for i in iv.size():
		for j in range(i + 1, iv.size()):
			for k in range(j + 1, iv.size()):
				var e := 2.0 + 0.01
				if iv[i].distance_to(iv[j]) < e and iv[j].distance_to(iv[k]) < e and iv[i].distance_to(iv[k]) < e:
					s.tri(iv[i].normalized() * r0, iv[j].normalized() * r0, iv[k].normalized() * r0, core, core, core)
	# the spikes: twelve long ones on the icosahedron's points, eight short between
	var tint_a := Color(0.5, 0.85, 1.1)
	for v: Vector3 in iv:
		s.crystal(v.normalized() * 0.4, v.normalized(), hr.randf_range(1.9, 3.1), hr.randf_range(0.24, 0.38), 6, Vector3.ZERO, 0.3, tint_a, Color(1.0, 1.1, 1.2), hr, 0.0)
	for i in 8:
		var d := Vector3(1.0 if i & 1 else -1.0, 1.0 if i & 2 else -1.0, 1.0 if i & 4 else -1.0).normalized()
		s.crystal(d * 0.4, d, hr.randf_range(1.2, 1.6), 0.2, 5, Vector3.ZERO, 0.2, tint_a, Color(0.9, 1.05, 1.2), hr, 0.0)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Shaders.HEART
	sm.shader = sh
	var mi := MeshInstance3D.new()
	mi.name = "Heart"
	mi.mesh = s.build()
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_position = heart
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(64.0, 64.0)
	halo.mesh = q
	var hm := ShaderMaterial.new()
	var hs := Shader.new()
	hs.code = Shaders.HALO
	hm.shader = hs
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 20.0
	host.add_child(halo)
	halo.global_position = heart


func _fragments() -> void:
	var s := Soup.new()
	var fr := RandomNumberGenerator.new()
	fr.seed = 5
	var c0 := Color(0.12, 0.2, 0.4)
	var c1 := Color(0.6, 0.88, 1.0)
	s.crystal(Vector3(0, -0.5, 0), Vector3.UP, 1.0, 0.26, 5, Vector3(0.08, 0.0, 0.0), 0.4, c0, c1, fr, 0.0)
	s.crystal(Vector3(0.1, -0.2, 0), Vector3(0.5, -1.0, 0.2), 0.5, 0.18, 5, Vector3.ZERO, 0.2, c0, c1, fr, 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = s.build()
	var n := 20
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		var ph := fr.randf()
		var sign := 1.0 if i % 3 != 0 else -1.0
		mm.set_instance_custom_data(i, Color(fr.randf_range(5.4, 9.0), ph, sign * fr.randf_range(0.05, 0.14), fr.randf_range(-1.4, 3.0)))
	mm.custom_aabb = AABB(Vector3(-14, -6, -14), Vector3(28, 14, 28))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Fragments"
	mmi.multimesh = mm
	mmi.material_override = _orbit_mat()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 14.0
	host.add_child(mmi)
	mmi.global_position = heart


func _orbit_mat() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = Shaders.ORBIT
	sm.shader = sh
	sm.set_shader_parameter("heart", heart)
	sm.set_shader_parameter("strength", 1.0)
	return sm


# --- light, motes, hum --------------------------------------------------------------------------------

func _lights() -> void:
	var specs := [[heart, Color(0.62, 0.82, 1.0), 2.4, 46.0], [Vector3(C.x, g0 + 1.8, C.y), Color(0.45, 0.6, 1.0), 1.2, 15.0]]
	for sp: Array in specs:
		var l := OmniLight3D.new()
		l.name = "StarLight"
		l.light_color = sp[1]
		l.light_energy = sp[2]
		l.omni_range = sp[3]
		l.omni_attenuation = 0.9
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 120.0
		l.distance_fade_length = 30.0
		l.set_meta(&"light_class", &"realm")
		host.add_child(l)
		l.global_position = sp[0]


func _motes() -> void:
	var dust := Vfx.emitter(Color(0.8, 0.95, 1.5), {"count": 240, "life": 11.0, "speed": Vector2(0.1, 0.45), "size": 0.045, "gravity": -0.1, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if dust:
		dust.name = "GlassDust"
		var pm := (dust.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(20.0, 0.4, 20.0)
		dust.process_material = pm
		dust.visibility_aabb = AABB(Vector3(-26, -2, -26), Vector3(52, 30, 52))
		dust.preprocess = 8.0
		host.add_child(dust)
		dust.global_position = Vector3(C.x, g0 + 0.4, C.y)
		dust.emitting = true
	var spark := Vfx.emitter(Color(0.9, 1.1, 1.7), {"count": 60, "life": 6.0, "speed": Vector2(0.05, 0.2), "size": 0.06, "gravity": 0.05, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if spark:
		spark.name = "HeartSparks"
		var sm := (spark.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		sm.emission_sphere_radius = 3.2
		spark.process_material = sm
		spark.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
		spark.preprocess = 4.0
		host.add_child(spark)
		spark.global_position = heart
		spark.emitting = true


func _hum() -> void:
	var rate := 11025
	var n := rate * 4
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var trem := 0.8 + 0.2 * sin(TAU * 0.5 * t)
		var v := 0.5 * sin(TAU * 55.0 * t) + 0.3 * sin(TAU * 82.5 * t + sin(TAU * 0.25 * t)) + 0.14 * sin(TAU * 110.25 * t) + 0.05 * sin(TAU * 660.0 * t + 2.0 * sin(TAU * 0.25 * t))
		pcm.encode_s16(i * 2, clampi(int(v * trem * 11000.0), -32000, 32000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	var snd := AudioStreamPlayer3D.new()
	snd.name = "StarHum"
	snd.stream = wav
	snd.volume_db = -9.0
	snd.unit_size = 14.0
	snd.max_distance = 110.0
	snd.autoplay = true
	host.add_child(snd)
	snd.global_position = heart


# --- clearance ----------------------------------------------------------------------------------------

## Visual meshes with no collision (the salt-works' timber, props) in reach of the crater get a temporary
## trimesh body on PROBE_LAYER while pieces are placed; the ground, the water and the flora are left out.
func _stand_ins(root: Node) -> void:
	var area := AABB(Vector3(C.x - 48.0, -8.0, C.y - 48.0), Vector3(96.0, 70.0, 96.0))
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or host.is_ancestor_of(mi):
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb()
		if not bb.intersects(area) or bb.size.x * bb.size.z > 6000.0:
			continue
		var path := String(mi.get_path())
		if path.contains("Terrain") or path.contains("Flora") or path.contains("Water") or path.contains("Beacon") or path.contains("Sky"):
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		var body := StaticBody3D.new()
		body.name = "StandIn"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		body.set_meta(&"stands_for", path.trim_prefix("/root/Main/"))
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		host.add_child(body)
		body.global_transform = mi.global_transform
		_temp.append(body)


## True when a box `size` at `xf` touches nothing built (the ground excepted when `ground_ok`: a root keyed in).
func _clear(xf: Transform3D, size: Vector3, grow := 0.3, ground_ok := false) -> bool:
	var sh := BoxShape3D.new()
	sh.size = size + Vector3.ONE * grow * 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = xf
	q.collision_mask = Layers.WORLD | PROBE_LAYER
	for hit: Dictionary in space.intersect_shape(q, 24):
		var c := hit.get("collider") as Node
		if ground_ok and c != null and (String(c.name).begins_with("Terrain") or c.name == &"GlassBody"):
			continue
		_last_hit = String(c.get_meta(&"stands_for", c.get_path())) if c else "?"
		return false
	return true

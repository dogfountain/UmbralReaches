extends RefCounted
## THE STAR-FALL CRATER (the White Pans, south-east of Saltmarket). Lore: the night the sky began to turn, a
## star came down on the salt. It did not burst. It struck once, fused the pans to glass for sixty paces and
## stayed, hanging a few fathoms over its own grave, turning as the sky turns. The Order's surveyors called it a
## Wound and measured it; the salt-workers call it the Lamp and keep their rakes out of its rays.
##   - the crater: a shallow bowl of dark glass, cracked into plates that the star lights from beneath and mirrors
##     itself in, a raised rim of fused crust, a ragged skirt of glass giving out to salt (one heightfield, walkable)
##   - the crystals: three great quartz druses rooted in the rim and thrown outward, long points lying across the
##     pans: milky and lit from within at the root, clear to the point (Blender: art/models/wonders/star_crater_shards.glb,
##     tools/blender/wonder_star_crater.py)
##   - the star: a dense many-faceted core, hot white-gold within and violet at its facet edges, black glass crust
##     laid close over it with glowing seams, molten threads and a slow rain of motes beneath, chips, a halo, a hum
##   - the climb: a ridge of snapped quartz columns heaved up from the crater floor, curving in toward a shelf
##     under the star crowned with points (a secret: core/life/secrets/site_star_crater.gd)
## Everything animated is in the shaders. Two lights. Placed clear of the salt-works, derricks and pans, the camps and
## the salt track; every piece is tested against the physics world and the collision-less meshes.

const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const Shaders := preload("res://core/world/realm/wonders/star_crater/crater_shaders.gd")

const C := Vector2(178.0, 146.0)       ## the crater's centre (xz): flat salt between the hills and the salt track
const FLOOR_R := 8.0                   ## the glass floor
const RIM_R := 12.5                    ## the crest (varies round the ring)
const RIM_H := 2.1
const MESH_R := 24.0
const HEART_H := 16.5                  ## the heart over the floor (8.7 m over the shelf: looked up at, not into)
const PROBE_LAYER := 1 << 30           ## stand-in bodies (nothing else uses it; freed after)

var space: PhysicsDirectSpaceState3D
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var g0 := 0.0
var heart := Vector3.ZERO
var moon := Vector3(0.3, 0.75, 0.4)       ## towards the moon (the facets' glints)
var host: Node3D
var _temp: Array[Node] = []
var _audit: Array[String] = []
var _last_hit := ""
var _scenes := {}
var _meshes := {}
var _far_mats := {}
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
	var moon_light := root.get_node_or_null("Moon") as DirectionalLight3D
	if moon_light != null:
		moon = moon_light.global_transform.basis.z.normalized()
	host = Node3D.new()
	host.name = "StarCrater"
	root.add_child(host)
	WorldLanes.register_terrace("star_crater", C, 14.0, g0)
	WorldLanes.register_site("star_crater_ground", Rect2(144.0, 120.0, 58.0, 60.0), g0 + 0.05, g0 + 0.05)
	_stand_ins(root)
	await root.get_tree().physics_frame
	var glass := _glass()
	_shards()
	_ridge()
	_heart()
	_fragments()
	_lights()
	_motes()
	_hum()
	var marker := Node3D.new()
	marker.name = "HeartPlatform"
	marker.set_meta("top", Vector3(C.x, g0 + SHELF_TOP, C.y))
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
	for sc in _scenes.values():
		if sc != null:
			(sc as Node).free()
	print("WONDER star_crater at %s (ground %.2f): glass %d tris; %s" % [Vector2(C.x, C.y), g0, glass, str(_stats)])
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
	sm.set_shader_parameter("heart", heart)
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


# --- the Blender pieces --------------------------------------------------------------------------------

const MODELS := "res://art/models/wonders/"


func _scene(file: String) -> Node:
	if not _scenes.has(file):
		var ps := load(MODELS + file) as PackedScene
		_scenes[file] = ps.instantiate() if ps != null else null
	return _scenes[file]


## The piece's mesh, rebuilt without the importer's LODs: every face is fanned round points inside it that carry
## the shader's edge field (UV2.y), and a LOD folds those coplanar fans away, which turned whole faces into "edge"
## (pale slabs) from ten metres off. The pieces are a few thousand triangles each; the full mesh is cheap.
func _mesh(file: String, node: String) -> Mesh:
	var key := file + ":" + node
	if _meshes.has(key):
		return _meshes[key]
	var root := _scene(file)
	var n := root.find_child(node, true, false) as MeshInstance3D if root != null else null
	if n == null or n.mesh == null:
		return null
	var src := n.mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
	_meshes[key] = out
	return out


## Past FAR_M the piece swaps to the importer's mesh with its LODs (the inner fan points folded away) and a copy of
## its material that ignores the edge field, which those LODs no longer carry (it would read every face as edge).
const FAR_M := 150.0


func _far(file: String, node: String, near: MeshInstance3D, mat: Material) -> void:
	var root := _scene(file)
	var n := root.find_child(node, true, false) as MeshInstance3D if root != null else null
	if n == null or n.mesh == null or not mat is ShaderMaterial:
		return
	if not _far_mats.has(mat):
		var fm := (mat as ShaderMaterial).duplicate() as ShaderMaterial
		fm.set_shader_parameter("edge_field", 0.0)
		_far_mats[mat] = fm
	near.visibility_range_end = FAR_M
	near.visibility_range_end_margin = 8.0
	var far := MeshInstance3D.new()
	far.name = near.name + "_Far"
	far.mesh = n.mesh
	far.material_override = _far_mats[mat]
	far.transform = near.transform
	far.extra_cull_margin = near.extra_cull_margin
	far.cast_shadow = near.cast_shadow
	far.visibility_range_begin = FAR_M
	far.visibility_range_begin_margin = 8.0
	host.add_child(far)


## The collision hull the asset ships for `node` (its `-colonly` mesh becomes the body that follows it), as a convex
## shape with the points' y scaled below the top (z < 0 in Blender, y < 0 here) by `sy`.
func _hull(file: String, node: String, sy := 1.0) -> ConvexPolygonShape3D:
	var root := _scene(file)
	var n := root.find_child(node, true, false) if root != null else null
	if n == null:
		return null
	var body := root.get_child(n.get_index() + 1) as StaticBody3D
	if body == null:
		return null
	var cs := body.get_child(0) as CollisionShape3D
	var faces := (cs.shape as ConcavePolygonShape3D).get_faces()
	var seen := {}
	var pts := PackedVector3Array()
	for f in faces:
		var key := Vector3i(roundi(f.x * 100.0), roundi(f.y * 100.0), roundi(f.z * 100.0))
		if seen.has(key):
			continue
		seen[key] = true
		pts.append(Vector3(f.x, f.y * sy if f.y < 0.0 else f.y, f.z))
	var sh := ConvexPolygonShape3D.new()
	sh.points = pts
	return sh


func _glass_mat(shader_code: String, strength := 1.0) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = shader_code
	sm.shader = sh
	sm.set_shader_parameter("heart", heart)
	sm.set_shader_parameter("strength", strength)
	sm.set_shader_parameter("moon", moon)
	return sm


func _gap(th: float) -> bool:
	var home := atan2(-C.y, -C.x)                 # towards Hearthward: the way in stays open
	return absf(angle_difference(th, home)) < 0.34 or absf(angle_difference(th, 0.0)) < 0.38


## One placed model: mesh instance with the glass material, an optional solid body from its shipped hull. The piece
## is refused (and logged) when it touches the world, a track or a camp, or an earlier piece. Returns whether it stands.
func _put(file: String, node: String, xf: Transform3D, mat: Material, label: String, solid := true, sy := 1.0, foot := 0.0) -> bool:
	var mesh := _mesh(file, node)
	if mesh == null:
		push_warning("WONDER star_crater: no mesh %s in %s" % [node, file])
		return false
	var bb := mesh.get_aabb()
	var c := xf * (bb.get_center() * Vector3(1.0, sy, 1.0))
	for p: Vector3 in [xf.origin, c, xf * (bb.position + bb.size)]:
		if RealmLayout.path_dist(Vector2(p.x, p.z)) < 5.0:
			_stats["kept off a track"] = int(_stats.get("kept off a track", 0)) + 1
			return false
		for cmp: Dictionary in EnemySpawner.REALM_CAMPS:
			var a: Vector3 = cmp.at
			if Vector2(a.x, a.z).distance_to(Vector2(p.x, p.z)) < 10.0:
				_stats["kept off a camp"] = int(_stats.get("kept off a camp", 0)) + 1
				return false
	var half := bb.size * Vector3(0.5, 0.5 * sy, 0.5) * 0.8
	if foot > 0.0:
		half = Vector3(foot, bb.size.y * 0.5 * sy, foot)
	if not _clear(Transform3D(xf.basis.orthonormalized(), c), half * 2.0, 0.1, true):
		_audit.append("%s left out (%s)" % [label, _last_hit])
		return false
	var mi := MeshInstance3D.new()
	mi.name = label.replace(" ", "_")
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(xf.basis * Basis.from_scale(Vector3(1.0, sy, 1.0)), xf.origin)
	mi.extra_cull_margin = 6.0
	host.add_child(mi)
	_far(file, node, mi, mat)
	if solid:
		var sh := _hull(file, node, sy)
		if sh != null:
			var body := StaticBody3D.new()
			body.name = mi.name + "_Body"
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = sh
			body.add_child(cs)
			host.add_child(body)
			body.transform = xf
	return true


func _shards() -> void:
	var glass := _glass_mat(Shaders.CRYSTAL)
	# three great clusters thrown up and out of the rim (the model leans along +X: outward)
	var great := [["shard_great_a", deg_to_rad(95.0), 13.0], ["shard_great_b", deg_to_rad(175.0), 13.5], ["shard_great_c", deg_to_rad(-62.0), 13.0]]
	for g: Array in great:
		var th: float = g[1]
		var rr := _rim(th).x + 0.6
		var p := Vector3(C.x + cos(th) * rr, 0.0, C.y + sin(th) * rr)
		p.y = _surface(p.x, p.z) - 0.5
		if _put("star_crater_shards.glb", String(g[0]), Transform3D(Basis(Vector3.UP, -th), p), glass, String(g[0]), true, 1.0, 5.0):
			_stats["great"] = int(_stats.get("great", 0)) + 1
	# rays: a long crystal thrown low across the pans, lying along the line out from the impact
	var rays := [[50.0, 26.0, "shard_ray_a"], [130.0, 27.0, "shard_ray_b"], [160.0, 30.0, "shard_ray_a"], [-100.0, 27.0, "shard_ray_b"], [-72.0, 30.0, "shard_ray_a"], [118.0, 36.0, "shard_ray_b"]]
	for r: Array in rays:
		var th := deg_to_rad(float(r[0]))
		if _gap(th):
			continue
		var rr: float = r[1]
		var p := Vector3(C.x + cos(th) * rr, 0.0, C.y + sin(th) * rr)
		p.y = _ground(p.x, p.z, g0) - 0.4
		if _put("star_crater_shards.glb", String(r[2]), Transform3D(Basis(Vector3.UP, -th), p), glass, "%s_%d" % [r[2], int(r[0])], true, 1.0, 3.0):
			_stats["ray"] = int(_stats.get("ray", 0)) + 1


# --- the climb: a ridge of upthrust glass, and the shelf under the heart ---------------------------------

const SHELF_TOP := 7.78
const RIDGE_N := 10


func _ridge() -> void:
	var glass := _glass_mat(Shaders.CRYSTAL, 1.0)
	glass.set_shader_parameter("ripple", 1.0)
	var names := ["ridge_plate_a", "ridge_plate_b", "ridge_plate_c", "ridge_plate_d"]
	var rr := RandomNumberGenerator.new()
	rr.seed = 12
	var phi := atan2(-C.y, -C.x) + 0.3                # the ridge starts on the Hearthward side of the floor
	for k in RIDGE_N:
		var u := float(k) / float(RIDGE_N - 1)
		var r := lerpf(7.3, 5.4, u)
		var th := phi + 2.4 * u
		var top := g0 + 0.6 + 0.74 * float(k)
		var p := Vector3(C.x + cos(th) * r, top, C.y + sin(th) * r)
		var sy := maxf(1.0, (top - g0 + 0.8) / 4.4)
		var tilt := Basis(Vector3.RIGHT, rr.randf_range(-0.07, 0.07)) * Basis(Vector3.FORWARD, rr.randf_range(-0.07, 0.07))
		var xf := Transform3D(Basis(Vector3.UP, -th + rr.randf_range(-0.35, 0.35)) * tilt, p)       # points outward
		if not _put("star_crater_ridge.glb", names[k % 4], xf, glass, "ridge %d" % k, true, sy, 0.0):
			_audit.append("ridge plate %d missing" % k)
	var sy2 := (SHELF_TOP + 0.8) / 5.0
	var away := phi + 2.4 + PI                        # the shelf's crown of points stands away from where the ridge arrives
	_put("star_crater_ridge.glb", "ridge_shelf", Transform3D(Basis(Vector3.UP, -away), Vector3(C.x, g0 + SHELF_TOP, C.y)), glass, "shelf", true, sy2, 0.0)


func _solid(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var sh := mesh.create_trimesh_shape()
	sh.backface_collision = true                 # walked on from above, and never fallen through from either side
	return sh


# --- the star -------------------------------------------------------------------------------------------

func _heart() -> void:
	var hm := _glass_mat(Shaders.HEART)
	for n: String in ["heart_core", "heart_drips"]:
		var mesh := _mesh("star_crater_heart.glb", n)
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = n.capitalize().replace(" ", "")
		mi.mesh = mesh
		mi.material_override = hm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		host.add_child(mi)
		mi.global_position = heart
		_far("star_crater_heart.glb", n, mi, hm)
	# its crust: jagged plates of black glass laid close over the core, turning with it (the shell shader's rate is the
	# core's)
	var crust := _mesh("star_crater_heart.glb", "heart_shell")
	if crust != null:
		var mi := MeshInstance3D.new()
		mi.name = "HeartShell"
		mi.mesh = crust
		mi.material_override = _glass_mat(Shaders.SHELL)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
		host.add_child(mi)
		mi.global_position = heart
		_far("star_crater_heart.glb", "heart_shell", mi, mi.material_override)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	var q := QuadMesh.new()
	q.size = Vector2(64.0, 64.0)
	halo.mesh = q
	var hs := Shader.new()
	hs.code = Shaders.HALO
	var hmat := ShaderMaterial.new()
	hmat.shader = hs
	halo.material_override = hmat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.extra_cull_margin = 20.0
	host.add_child(halo)
	halo.global_position = heart


## Chips of the shell further out, at different distances, heights and rates: six shapes, two of each.
func _fragments() -> void:
	var fr := RandomNumberGenerator.new()
	fr.seed = 5
	var os := Shader.new()
	os.code = Shaders.ORBIT
	var om := ShaderMaterial.new()
	om.shader = os
	for n: String in ["frag_a", "frag_b", "frag_c", "frag_d", "frag_e", "frag_f"]:
		var mesh := _mesh("star_crater_heart.glb", n)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = 2
		for j in 2:
			mm.set_instance_transform(j, Transform3D.IDENTITY)
			var sign := 1.0 if fr.randf() < 0.65 else -1.0
			mm.set_instance_custom_data(j, Color(fr.randf_range(5.6, 8.0), fr.randf(), sign * fr.randf_range(0.03, 0.08), fr.randf_range(-0.5, 3.5)))
		mm.custom_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 8, 20))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Drift_" + n
		mmi.multimesh = mm
		mmi.material_override = om
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.extra_cull_margin = 10.0
		host.add_child(mmi)
		mmi.global_position = heart


# --- light, motes, hum --------------------------------------------------------------------------------

func _lights() -> void:
	# [where, colour, energy, range, fog]: a realm light keeps its own settings, and at full fog energy the star lit the
	# froxels round it into a white fog ball that washed out everything seen near it (the halo is the glow from afar)
	var specs := [[heart, Color(1.0, 0.86, 0.66), 3.2, 52.0, 0.12], [Vector3(C.x, g0 + 1.8, C.y), Color(0.45, 0.62, 1.0), 1.1, 15.0, 0.05]]
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
		l.light_volumetric_fog_energy = sp[4]
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
	# a slow rain of hot motes off the star, falling into the crater and going out on the way down
	var rain := Vfx.emitter(Color(1.6, 1.05, 0.5), {"count": 90, "life": 10.0, "speed": Vector2(0.0, 0.15), "size": 0.05, "gravity": -0.32, "damping": 0.0, "radius": 1.0, "turbulence": true, "explosive": 0.0})
	if rain:
		rain.name = "StarRain"
		var sm := (rain.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		sm.emission_sphere_radius = 2.0
		rain.process_material = sm
		rain.visibility_aabb = AABB(Vector3(-8, -20, -8), Vector3(16, 24, 16))
		rain.preprocess = 10.0
		host.add_child(rain)
		rain.global_position = heart + Vector3.DOWN * 1.6
		rain.emitting = true


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

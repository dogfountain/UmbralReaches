extends RefCounted
## The Ashen Rift's natural rock (RealmRift), from scratch (21 Nov): the basalt the lava cooled into, modelled in Blender
## (tools/blender/rift_rocks.py -> art/models/rift_rocks.glb) and set about the rift here:
##   - shores: broken basalt along both walls at the lava line (their backs buried in the rock)
##   - crust plates: thin cold rafts in the south, where the lava has crusted over
##   - islands: low basalt spread through the molten lake, the lava running wall to wall round them
##   - stacks: tall broken basalt in the molten east channel (the skyline from the Lip)
##   - the dressing: boulders, cooled spatter and heaved crust slabs crowding the walls' feet and ringing every island, the Watchers'
##     plinths and the way's isles (MultiMesh, no collision)
## The bigger pieces have their collision, so LavaWorks' bank mask gives each a crust lip and a glowing contact rim. Merged per material
## (two draws, cut in 24 m cells). On the rim, as before: ash drifts and spalls, glowing fissures with smoke and ember vents at their mouths.
## Keeps off the Cinder Way (its sites, lanes and rock), the Watchers' plinths, the old Ossuary site and every RealmLayout path.

const RockKitS := preload("res://core/world/realm/rock_kit.gd")
const ROCKS := "res://art/models/rift_rocks.glb"
const LAVA := -15.5
const BED := -19.5
const CHAPEL := Rect2(-25.0, -42.5, 14.5, 9.5)    ## the Pilgrims' Chapel cut into the west wall and its forecourt (rift/chapel.gd ORIGIN)

var vents: Array[Vector3] = []
var watchers: Array = []                ## [Vector3] the Watchers' feet (rift/threshold.gd): the plinths keep this clear
var rng := RandomNumberGenerator.new()
var space: PhysicsDirectSpaceState3D
var report: Array[String] = []
var _st := {}                           ## style -> SurfaceTool (the merged pieces)
var _body: StaticBody3D
var _variants := {}                     ## name -> [mesh, style, shapes [[Shape3D, Transform3D]], aabb]
var _placed: Array[Vector3] = []        ## the pieces put so far: (x, z, radius)
var _ringed: Array[Vector3] = []        ## the islands, plates and stacks out in the lava (the dressing rings them; not the shores)

const FISSURE_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
// UV.x across the crack (0..1), UV.y metres along it. A molten seam that breathes.
uniform vec3 hot : source_color = vec3(1.0, 0.34, 0.06);
uniform vec3 core : source_color = vec3(1.0, 0.7, 0.3);
float h(vec2 p){ return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float n(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	float a = abs(UV.x - 0.5) * 2.0;
	float w = 0.35 + 0.65 * n(vec2(UV.y * 1.3, 3.1));             // the seam swells and pinches
	float seam = 1.0 - smoothstep(w * 0.25, w, a);
	float pulse = 0.65 + 0.35 * sin(TIME * 0.9 + UV.y * 0.7 + n(vec2(UV.y * 0.4, TIME * 0.2)) * 4.0);
	float glow = 1.0 - smoothstep(0.0, w * 0.45, a);
	vec3 col = mix(hot * 0.55, mix(hot, core, glow), seam);
	ALBEDO = col * (0.75 + 0.6 * pulse);
	ALPHA = clamp(seam * (0.55 + 0.45 * pulse) + (1.0 - smoothstep(0.0, 1.0, a)) * 0.18, 0.0, 1.0) * smoothstep(0.0, 1.0, UV.y) * TAIL;
}"""


func build(root: Node, host: Node3D) -> void:
	rng.seed = 7071
	space = (root as Node3D).get_world_3d().direct_space_state
	_load_variants()
	if not _variants.is_empty():
		_body = StaticBody3D.new()
		_body.name = "RiftRockBody"
		_body.collision_layer = Layers.WORLD
		_body.collision_mask = 0
		host.add_child(_body)
		_shores()
		_lava_rock()
		_commit(host)
		_dress(host)
	await root.get_tree().process_frame
	_ash_fields(host)
	_fissures(host)
	_vents(host)
	for s in report:
		print("RIFT ", s)


# --- the modelled pieces ------------------------------------------------------------------------------

func _load_variants() -> void:
	var ps := load(ROCKS) as PackedScene
	if ps == null:
		report.append("rocks: %s missing" % ROCKS)
		return
	var inst := ps.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("-colonly") or not nm.contains("__") or mi.mesh == null:
			continue
		var key := nm.get_slice("__", 0)
		var style := nm.get_slice("__", 1).get_slice(".", 0).get_slice("_", 0)
		var shapes: Array = []
		var body := inst.find_child(key, true, false)
		if body == null:
			body = inst.find_child(key + "-colonly", true, false)
		if body != null:
			for cs in body.find_children("*", "CollisionShape3D", true, false):
				shapes.append([(cs as CollisionShape3D).shape, (cs as Node3D).transform])
		_variants[key] = [mi.mesh, style, shapes, mi.mesh.get_aabb()]
	inst.free()


## One piece at `xf` (rift coordinates) into the merged mesh and the shared body.
func _put(key: String, xf: Transform3D) -> void:
	var v: Array = _variants[key]
	var ab: AABB = v[3]
	_placed.append(Vector3(xf.origin.x, xf.origin.z, maxf(ab.size.x, ab.size.z) * 0.5))
	var style: String = v[1]
	if not _st.has(style):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[style] = st
	(_st[style] as SurfaceTool).append_from(v[0], 0, xf)
	for s: Array in v[2]:
		var cs := CollisionShape3D.new()
		cs.shape = s[0]
		cs.transform = xf * (s[1] as Transform3D)
		_body.add_child(cs)


func _commit(host: Node3D) -> void:
	for style: String in _st:
		var mi := MeshInstance3D.new()
		mi.name = "RiftRock_" + style
		mi.mesh = (_st[style] as SurfaceTool).commit()
		mi.material_override = RockKitS.material(style)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # lit from the lava below
		host.add_child(mi)
		MeshChunks.split(mi)
		mi.queue_free()


## The wall's x at height y and z (the first terrain hit going out from the middle), or NAN.
func _wall_x(side: float, y: float, z: float) -> float:
	var from := Vector3(side * 4.0, y, z)
	for i in 6:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(side * 50.0, y, z), Layers.WORLD))
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).x
		from = (hit.position as Vector3) + Vector3(side * 0.2, 0.0, 0.0)
	return NAN


## Broken basalt along both walls at the lava line, every 5-8 m, backs into the rock (local -x is a shore's back).
func _shores() -> void:
	var placed := 0
	for side: float in [-1.0, 1.0]:
		var z := -12.0
		while z > -100.0:
			z -= rng.randf_range(10.0, 15.0)
			var key := "Shore%d" % rng.randi_range(0, 1)
			if not _variants.has(key):
				continue
			var wx := _wall_x(side, LAVA + 0.6, z)
			if is_nan(wx):
				continue
			var top := LAVA + (_variants[key][3] as AABB).end.y
			if side > 0.0 and z < -21.0 and top > -7.5:
				continue                                    # the old Ossuary's wall: a bare cliff above y -7
			var p := Vector2(wx - side * 0.6, z)
			var half := (_variants[key][3] as AABB).size.z * 0.5 + 1.0
			if _blocked(p, top, 0.6) or _near_placed(p, 4.0) or Rect2(p.x - 3.5, p.y - half, 7.0, half * 2.0).intersects(CHAPEL):
				continue                                    # (a shore's length runs along the wall: none may reach into the chapel)
			var b := Basis(Vector3.UP, (0.0 if side < 0.0 else PI) + rng.randf_range(-0.15, 0.15))
			_put(key, Transform3D(b, Vector3(p.x, LAVA, p.y)))
			placed += 1
	report.append("shores: %d" % placed)


## Crust plates on the crusted south; a few islands spread through the molten lake (the two smaller kinds, at least ISLE_GAP apart: the
## lake is lava wall to wall round them, not a field of rock: twelve big ones and the shores had covered half of it); stacks in the
## channel under the summit.
const ISLE_GAP := 15.0


func _lava_rock() -> void:
	var n := {"Plate": 0, "Isle": 0, "Stack": 0}
	var want := [["Plate", 3, 3, Rect2(-17.0, -26.0, 45.0, 14.0)], ["Isle", 3, 5, Rect2(-20.0, -100.0, 52.0, 78.0)],
			["Stack", 3, 3, Rect2(11.0, -106.0, 13.0, 34.0)]]
	for w: Array in want:
		var kind: String = w[0]
		var r: Rect2 = w[3]
		var got := 0
		for i in 260:
			if got >= int(w[2]):
				break
			var key := "%s%d" % [kind, rng.randi_range(0, int(w[1]) - 1)]
			if kind == "Isle" and key == "Isle1":
				key = "Isle2"                            # (the small ones: Isle0 and Isle2)
			if not _variants.has(key):
				continue
			var ab: AABB = _variants[key][3]
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			var rad := maxf(ab.size.x, ab.size.z) * 0.5
			if kind != "Plate" and _near_placed(p, ISLE_GAP):
				continue
			if not _open_lava(p, rad * 0.6, LAVA + ab.end.y):
				continue
			_put(key, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, LAVA, p.y)))
			_ringed.append(_placed[_placed.size() - 1])
			got += 1
		n[kind] = int(n[kind]) + got
	report.append("lava rock: %d plates, %d islands, %d stacks" % [n.Plate, n.Isle, n.Stack])


func _near_placed(p: Vector2, gap: float) -> bool:
	for q: Vector3 in _placed:
		if p.distance_to(Vector2(q.x, q.y)) < gap:
			return true
	return false


## Open lava at p and round it (radius r): no rock of the way, the crag or another piece under it (rays down; the ground allowed), off
## the Watchers' plinths and the chapel, and the ground itself under the lava there.
func _open_lava(p: Vector2, r: float, top_y: float) -> bool:
	if CHAPEL.grow(1.0).has_point(p):
		return false
	for w: Vector3 in watchers:
		if p.distance_to(Vector2(w.x, w.z)) < 6.8 + r:
			return false
	var oss := AABB(Endgame.l(RealmLayout.OSSUARY_OLD.position), RealmLayout.OSSUARY_OLD.size)
	if p.x > 18.0 and p.y > oss.position.z and p.y < oss.end.z and top_y > oss.position.y - 1.0:
		return false                                 # the old Ossuary's east wall stays a bare cliff above y -7
	for k in 5:
		var o := Vector2.ZERO if k == 0 else Vector2(cos(TAU * float(k) / 4.0), sin(TAU * float(k) / 4.0)) * r
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x + o.x, 40.0, p.y + o.y), Vector3(p.x + o.x, BED - 6.0, p.y + o.y), Layers.WORLD))
		if hit.is_empty():
			return false                             # (no ground under it at all: outside the chasm)
		if not String((hit.collider as Node).name).begins_with("Terrain") or (hit.position as Vector3).y > LAVA - 0.3:
			return false                             # something built over it, or the bank itself
	return true


## The banks and the islands crowded with the small cooled basalt (boulders, spatter, heaved crust slabs): no collision, a MultiMesh a
## variant. Along both walls at the lava line every metre or two; in rings round the islands, the Watchers' plinths, the Cinder Way's
## isles, the Foot and the crag's foot; slabs strewn over the crusted south.
func _dress(host: Node3D) -> void:
	var kinds: Array[String] = []
	for k: String in _variants:
		if k.begins_with("Boulder") or k.begins_with("Spatter") or k.begins_with("Slab"):
			kinds.append(k)
	if kinds.is_empty():
		return
	kinds.sort()
	var xfs := {}
	for k in kinds:
		xfs[k] = []
	var pick := func(slab: float) -> String:
		var f := rng.randf()
		var pre := "Slab" if f < slab else ("Spatter" if f < slab + 0.3 else "Boulder")
		var opts: Array[String] = []
		for k in kinds:
			if k.begins_with(pre):
				opts.append(k)
		return opts[rng.randi() % opts.size()]
	var put := func(p: Vector2, key: String, s: float) -> void:
		if CHAPEL.has_point(p):
			return
		for w: Vector3 in watchers:
			if p.distance_to(Vector2(w.x, w.z)) < 4.6:
				return                                   # (on the plinth's top: the pillar stands there)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.15), s))
		(xfs[key] as Array).append(Transform3D(b, Vector3(p.x, LAVA - rng.randf_range(0.05, 0.35) * s, p.y)))
	# the walls' feet
	for side: float in [-1.0, 1.0]:
		var z := -9.0
		while z > -110.0:
			z -= rng.randf_range(1.6, 3.2)
			var wx := _wall_x(side, LAVA + 0.3, z)
			if is_nan(wx):
				continue
			put.call(Vector2(wx - side * rng.randf_range(0.1, 1.3), z + rng.randf_range(-0.6, 0.6)), pick.call(0.1), rng.randf_range(0.7, 1.4))
	# rings round what stands in the lava
	var rings: Array = []                         # [centre, radius]
	for q: Vector3 in _ringed:
		rings.append([Vector2(q.x, q.y), q.z * 0.85])
	for w: Vector3 in watchers:
		rings.append([Vector2(w.x, w.z), 6.2])
	for c: Array in [[Vector2(4.0, -28.6), 4.4], [Vector2(9.6, -37.2), 5.6], [Vector2(-6.5, -24.3), 5.2]]:
		rings.append(c)
	for c: Array in rings:
		var ctr: Vector2 = c[0]
		var rr: float = c[1]
		var m := int(TAU * rr / 3.0)
		for i in m:
			var a := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / float(m)
			put.call(ctr + Vector2(cos(a), sin(a)) * (rr + rng.randf_range(-0.5, 0.5)), pick.call(0.15), rng.randf_range(0.6, 1.2))
	var x := -23.0                                # the crag's foot, along the pool's north side (the west body stands 2.4 m further back)
	while x < 15.0:
		var zf := -50.7 if x < -5.0 else -48.3
		put.call(Vector2(x, rng.randf_range(zf + 0.2, zf + 1.9)), pick.call(0.05), rng.randf_range(0.8, 1.6))
		x += rng.randf_range(1.4, 2.6)
	# heaved crust slabs and spatter over the crusted south
	for i in 34:
		put.call(Vector2(rng.randf_range(-16.0, 18.0), rng.randf_range(-11.0, -24.0)), pick.call(0.6), rng.randf_range(0.7, 1.4))
	var count := 0
	for k in kinds:
		var list: Array = xfs[k]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _variants[k][0]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # static: interpolating a MultiMesh makes its add wait on the GPU (zz/stream_probe.gd)
		mmi.name = "RiftDress_" + k
		mmi.multimesh = mm
		mmi.material_override = RockKitS.material(String(_variants[k][1]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 220.0
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)
		count += list.size()
	report.append("dressing: %d boulders, spatter and slabs in %d variants" % [count, kinds.size()])


# --- placement guards ------------------------------------------------------------------------------

func _ground(x: float, z: float, from_y := 70.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, BED - 4.0, z), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	if not String((hit.collider as Node).name).begins_with("Terrain"):
		return NAN                                   # on something built: not ground
	return (hit.position as Vector3).y


## True where nothing may stand: the Cinder Way (sites + lanes), the Watchers, the Pilgrims' Chapel, paths, the Ossuary's old wall
## above y -7.
func _blocked(p: Vector2, top_y: float, pad := 1.5) -> bool:
	if CHAPEL.grow(pad).has_point(p):
		return true
	for w: Vector3 in watchers:
		if p.distance_to(Vector2(w.x, w.z)) < 7.4 + pad:
			return true
	for s: Dictionary in WorldLanes.sites:
		if String(s.name).begins_with("rift_") and not is_nan(WorldLanes.site_floor(s, p, pad)):
			return true
	for l: Array in WorldLanes.extra_lanes:
		if not String(l[0]).begins_with("rift_crossing"):
			continue
		var pts: Array = l[1]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			if p.distance_to(a + ab * t) < float(l[2]) + pad:
				return true
	if RealmLayout.path_dist(Endgame.w2(p)) < 1.2:
		return true                                  # (built at home, it stands Endgame.O east: the ways are where it will stand)
	var oss := AABB(Endgame.l(RealmLayout.OSSUARY_OLD.position), RealmLayout.OSSUARY_OLD.size)         # (the Ossuary left this wall; the old site stays a bare cliff)
	if p.x > maxf(oss.position.x - 0.5, 18.0) and p.x < oss.end.x and p.y > oss.position.z and p.y < oss.end.z and top_y > oss.position.y - 1.0:
		return true
	return false


# --- ash fields -----------------------------------------------------------------------------------------

## The rim shelves inside the rift rect, west and east of the trench: ash-rock drifts sunk in the ground and spalled basalt, seated on
## the real terrain (MultiMesh per mesh, culled at 60 m).
func _ash_fields(host: Node3D) -> void:
	var rk := RockKitS
	var meshes: Array[Mesh] = []
	for i in 3:
		meshes.append(rk.boulder(100 + i, Vector3(1.6, 0.5, 1.2), "ash"))
	for i in 2:
		meshes.append(rk.boulder(200 + i, Vector3(0.9, 0.8, 0.8), "basalt"))
	var xfs: Array = [[], [], [], [], []]
	var n := 0
	for i in 380:
		var west := rng.randf() < 0.7
		var p := Vector2(rng.randf_range(-31.0, -19.0) if west else rng.randf_range(19.0, 31.0), rng.randf_range(-118.0, -8.0))
		if not west and p.y < -20.0 and p.y > -112.0:
			continue                                     # the Ossuary's side
		var y := _ground(p.x, p.y)
		if is_nan(y) or y < LAVA + 1.5 or _blocked(p, y, 0.5):
			continue
		var kind := rng.randi_range(0, 4)
		var s := rng.randf_range(0.35, 1.3) * (1.0 if kind < 3 else 0.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s))
		(xfs[kind] as Array).append(Transform3D(b, Vector3(p.x, y - 0.12 * s, p.y)))
		n += 1
	for k in meshes.size():
		if (xfs[k] as Array).is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = (xfs[k] as Array).size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, xfs[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # static: interpolating a MultiMesh makes its add wait on the GPU (zz/stream_probe.gd)
		mmi.name = "AshDrift%d" % k
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 60.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)
	report.append("ash fields: %d drifts and spalls" % n)


# --- fissures and vents ------------------------------------------------------------------------------

## Molten seams draped on the ground (one mesh): wandering cracks on the rim shelves. Their mouths become smoke and ember vents. None
## by the Lip (the south rim stays cold: the lava has crusted there).
func _fissures(host: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var seeds: Array[Vector2] = []
	for i in 14:
		seeds.append(Vector2(rng.randf_range(-30.0, -21.0), rng.randf_range(-112.0, -30.0)))
	for i in 3:
		seeds.append(Vector2(rng.randf_range(28.0, 38.0), rng.randf_range(-19.0, -10.0)))      # (the east lip, back where the pit's wall now stands)
	for s in seeds:
		var pts: Array[Vector3] = []
		var p := s
		var head := rng.randf() * TAU
		var len := rng.randf_range(6.0, 16.0)
		var d := 0.0
		while d < len:
			var y := _ground(p.x, p.y)
			if is_nan(y) or _blocked(p, y, 0.6):
				break
			pts.append(Vector3(p.x, y + 0.04, p.y))
			head += rng.randf_range(-0.45, 0.45)
			p += Vector2(cos(head), sin(head)) * 0.5
			d += 0.5
		if pts.size() < 6:
			continue
		var w := rng.randf_range(0.25, 0.7)
		var m := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var dir := (b - a).normalized()
			var side := dir.cross(Vector3.UP).normalized()
			var t0 := float(i) / float(pts.size() - 1)
			var t1 := float(i + 1) / float(pts.size() - 1)
			var wa := w * sin(PI * clampf(t0, 0.05, 0.95))       # tapers at both ends
			var wb := w * sin(PI * clampf(t1, 0.05, 0.95))
			var m1 := m + a.distance_to(b)
			var q := [a - side * wa, a + side * wa, b + side * wb, b - side * wb]
			var uv := [Vector2(0, m), Vector2(1, m), Vector2(1, m1), Vector2(0, m1)]
			for k: int in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(uv[k])
				st.add_vertex(q[k])
			m = m1
		vents.append(pts[0])
		count += 1
	if count == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Fissures"
	mi.mesh = st.commit()
	var sh := Shader.new()
	sh.code = FISSURE_SHADER.replace("TAIL", "1.0")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 160.0
	host.add_child(mi)
	report.append("fissures: %d" % count)


## Smoke columns and ember spits at fissure mouths (every other one) and over the hot lava (the pool and the east channel).
func _vents(host: Node3D) -> void:
	var spots: Array[Vector3] = []
	for i in vents.size():
		if i % 2 == 0:
			spots.append(vents[i])
	for p: Vector2 in [Vector2(26.0, -40.0), Vector2(27.0, -66.0), Vector2(16.0, -82.0), Vector2(-12.0, -44.0)]:
		spots.append(Vector3(p.x, LAVA + 0.1, p.y))
	for p in spots:
		var smoke := Vfx.emitter(Color(0.16, 0.13, 0.13, 0.35), {"count": 14, "life": 7.0, "speed": Vector2(0.6, 1.3), "size": 2.4, "gravity": 0.25, "radius": 0.5, "spread": 12.0, "additive": false, "turbulence": true, "damping": 0.2, "grow": 0.5})
		if smoke:
			smoke.name = "VentSmoke"
			smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 18, 12))
			smoke.visibility_range_end = 160.0          # seen as far as its glowing seam is (beyond, a column over bare rim)
			smoke.visibility_range_end_margin = 20.0
			smoke.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			smoke.preprocess = 6.0
			var pm := (smoke.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
			var sc := Curve.new()
			sc.add_point(Vector2(0.0, 0.35))
			sc.add_point(Vector2(1.0, 1.0))
			var sct := CurveTexture.new()
			sct.curve = sc
			pm.scale_curve = sct
			smoke.process_material = pm
			host.add_child(smoke)
			smoke.global_position = p + Vector3.UP * 0.3
			smoke.emitting = true
		if p.y > LAVA + 1.0 and spots.find(p) % 2 == 1:
			continue                                     # every other rim vent only smokes
		var spit := Vfx.emitter(Color(1.8, 0.6, 0.12), {"count": 18, "life": 2.4, "speed": Vector2(0.8, 2.6), "size": 0.05, "gravity": -1.2, "radius": 0.3, "spread": 25.0, "turbulence": true})
		if spit:
			spit.name = "VentEmbers"
			spit.preprocess = 2.0
			host.add_child(spit)
			spit.global_position = p + Vector3.UP * 0.1
			spit.emitting = true
	report.append("vents: %d" % spots.size())

extends RefCounted
## Ashen Rift set dressing (RealmRift): what turns the straight old trench into a wound.
##   - basalt organ pipes crowding both lava banks (hex column bundles; the east bank stays below
##     the Ossuary's floor, under y -7) and basalt cliffs (RockKit) at the waterline of the walls
##   - columned stacks and cooled-crust islands out in the river (the islands have collision, so
##     LavaWorks' bank mask gives each its own crust shelf and glowing contact rim)
##   - ash fields on the rim shelves: buried ash-rock drifts and spalled basalt (MultiMesh)
##   - glowing fissures draped over the rim ground and the slopes by the forecourt, with smoke and
##     ember vents at their mouths (positions handed to LavaWorks too)
## Keeps off the Crossing (its sites and lane), the Ossuary's volume and every RealmLayout path.

const Basalt := preload("res://core/world/realm/rift/basalt.gd")
const LAVA := -15.5
const BED := -19.5

var vents: Array[Vector3] = []
var star_z := INF                       ## RealmRift.STAR_Z: south of it (z greater) the Threshold, no volcanic dressing
var rng := RandomNumberGenerator.new()
var space: PhysicsDirectSpaceState3D
var report: Array[String] = []

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
	_bank_pipes(host)
	_cliffs(host)
	_islands(host)
	await root.get_tree().process_frame
	_ash_fields(host)
	_fissures(host)
	_vents(host)
	for s in report:
		print("RIFT ", s)


# --- placement guards ------------------------------------------------------------------------------

func _ground(x: float, z: float, from_y := 70.0) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, BED - 4.0, z), Layers.WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return NAN
	if not String((hit.collider as Node).name).begins_with("Terrain"):
		return NAN                                   # on something built: not ground
	return (hit.position as Vector3).y


## True where nothing may stand: the Crossing (sites + lane), paths, the Ossuary above y -7.
func _blocked(p: Vector2, top_y: float, pad := 1.5) -> bool:
	if p.distance_to(Vector2(-8.3, -50.0)) < 10.0:
		return true                                  # the Spindle and its turn
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
	if RealmLayout.path_dist(p) < 1.2:
		return true
	var oss := RealmLayout.OSSUARY_OLD         # (the Ossuary left this wall; the old site stays clear of rocks and pipes: a bare cliff)
	if p.x > oss.position.x - 0.5 and p.x < oss.end.x and p.y > oss.position.z and p.y < oss.end.z and top_y > oss.position.y - 1.0:
		return true
	return false


# --- basalt -------------------------------------------------------------------------------------------

## Organ pipes along both banks: bundles stepping up against the walls, lowest at the waterline.
func _bank_pipes(host: Node3D) -> void:
	var st := Basalt.new_tool()
	var n := 0
	var bundles := 0
	for side: float in [-1.0, 1.0]:
		var z := -14.0
		while z > -117.0:
			z -= rng.randf_range(5.0, 9.0)
			var x := side * rng.randf_range(15.5, 18.0)
			var r := rng.randf_range(2.0, 3.8)
			var east_low := side > 0.0 and z > -111.0 and z < -21.0
			var hi := rng.randf_range(-9.0, -2.0) if not east_low else rng.randf_range(-12.5, -8.0)
			if side < 0.0 and rng.randf() < 0.3:
				hi = rng.randf_range(1.0, 5.0)                 # a few tall ones against the west wall
			if z > star_z - 2.0 or _blocked(Vector2(x, z), hi, 2.0):
				continue
			var wall := side
			var top := func(d: float) -> float:
				return lerpf(hi, LAVA + 0.6, clampf(d * d, 0.0, 1.0)) + rng.randf_range(-1.2, 0.6)
			# columns nearer the wall stand taller: shift the bundle's high point towards it
			n += Basalt.bundle(st, rng, Vector3(x + wall * r * 0.35, BED, z), r, rng.randf_range(0.42, 0.6), top, 0.8,
				func(p: Vector2) -> bool: return _blocked(p, hi, 1.2))
			bundles += 1
	# columned stacks out in the river (low, broken), and a tall one by the first tower
	for c: Array in [[Vector2(9.0, -27.0), 2.4, -11.0], [Vector2(11.0, -58.0), 3.0, -12.0], [Vector2(-6.0, -78.0), 2.6, -9.5],
			[Vector2(8.0, -86.0), 2.2, -12.5], [Vector2(-11.0, -16.0), 1.8, -10.0], [Vector2(7.5, -40.5), 2.0, -9.0], [Vector2(-14.0, -88.0), 2.8, -6.0]]:
		var p: Vector2 = c[0]
		var hi: float = c[2]
		if p.y > star_z - 2.0 or _blocked(p, hi, 1.0):
			continue
		n += Basalt.bundle(st, rng, Vector3(p.x, BED, p.y), float(c[1]), 0.48, func(d: float) -> float: return lerpf(hi, LAVA + 0.4, d * d) + rng.randf_range(-1.5, 0.5), 0.8)
		bundles += 1
	var mi := Basalt.commit(st, host, "BankPipes", "basalt", false)
	if mi:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # lit from the lava below
		MeshChunks.split(mi)                                                 # 24 m cells with LODs
		mi.queue_free()
	report.append("basalt: %d bundles, %d columns" % [bundles, n])


## Basalt cliff faces (RockKit) at the foot of the walls: they break the trench's straight banks.
func _cliffs(host: Node3D) -> void:
	var rk := Basalt.rock_kit()
	if rk == null:
		report.append("cliffs: RockKit missing, skipped")
		return
	var placed := 0
	for side: float in [-1.0, 1.0]:
		var z := -16.0
		while z > -116.0:
			var len := rng.randf_range(7.0, 11.0)
			var zc := z - len * 0.5
			z -= len + rng.randf_range(2.0, 9.0)
			var east_low := side > 0.0 and zc > -112.0 and zc < -20.0
			var h := rng.randf_range(5.0, 9.0) if not east_low else rng.randf_range(4.0, 6.5)
			var base := LAVA - 1.2
			if east_low and base + h > -7.2:
				h = -7.2 - base
			var x := side * 18.6
			if zc > star_z - 2.0 or _blocked(Vector2(x - side * 2.0, zc), base + h, 1.0):
				continue
			var mesh: Mesh = rk.call("cliff", rng.randi(), Vector3(len, h, 3.2), "basalt")
			var xf := Transform3D(Basis(Vector3.UP, -side * PI * 0.5 + rng.randf_range(-0.12, 0.12)), Vector3(x, base, zc))
			var mi: MeshInstance3D = rk.call("spawn", host, mesh, xf, false, 180.0)
			mi.name = "BasaltCliff%d" % placed
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			placed += 1
	report.append("cliffs: %d basalt faces" % placed)


## Cooled-crust islands: flat ash rocks awash in the river, with collision for the bank mask.
func _islands(host: Node3D) -> void:
	var rk := Basalt.rock_kit()
	if rk == null:
		return
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(-15.0, 15.0), rng.randf_range(-112.0, -14.0))
		if p.y > star_z - 4.0 or _blocked(p, LAVA + 1.0, 2.5):
			continue
		if p.y < -88.0 and absf(p.x) < 15.0:
			continue                                     # under the summit dais: never seen
		var s := Vector3(rng.randf_range(2.5, 6.5), rng.randf_range(0.9, 1.6), rng.randf_range(2.0, 5.0))
		var mesh: Mesh = rk.call("boulder", rng.randi(), s, "ash")
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, LAVA - s.y * 0.55, p.y))
		var mi: MeshInstance3D = rk.call("spawn", host, mesh, xf, true, 200.0)
		mi.name = "CrustIsland%d" % placed
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		placed += 1
	report.append("crust islands: %d" % placed)


# --- ash fields -----------------------------------------------------------------------------------------

## The rim shelves inside the rift rect, west and east of the trench: ash-rock drifts sunk in the
## ground and spalled basalt, seated on the real terrain (MultiMesh per mesh, culled at 90 m).
func _ash_fields(host: Node3D) -> void:
	var rk := Basalt.rock_kit()
	if rk == null:
		return
	var meshes: Array[Mesh] = []
	for i in 3:
		meshes.append(rk.call("boulder", 100 + i, Vector3(1.6, 0.5, 1.2), "ash"))
	for i in 2:
		meshes.append(rk.call("boulder", 200 + i, Vector3(0.9, 0.8, 0.8), "basalt"))
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
		if p.y > star_z and y < -2.0:
			continue                                     # the Threshold's terraces stand on that slope
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
		mmi.name = "AshDrift%d" % k
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 60.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		host.add_child(mmi)
	report.append("ash fields: %d drifts and spalls" % n)


# --- fissures and vents ------------------------------------------------------------------------------

## Molten seams draped on the ground (one mesh): wandering cracks on the rim shelves and down the
## slopes beside the forecourt. Their mouths become smoke and ember vents.
func _fissures(host: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	var seeds: Array[Vector2] = []
	for i in 14:
		seeds.append(Vector2(rng.randf_range(-30.0, -21.0), rng.randf_range(-112.0, -14.0)))
	for i in 4:
		seeds.append(Vector2(rng.randf_range(-15.0, -7.0) * (1.0 if i % 2 == 0 else -1.0), rng.randf_range(-11.0, -6.0)))
	for i in 3:
		seeds.append(Vector2(rng.randf_range(20.0, 30.0), rng.randf_range(-19.0, -10.0)))
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
		if s.y > star_z:
			continue                                     # the Threshold: no seams by the forecourt (a lit line read as a beam)
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


## Smoke columns and ember spits at fissure mouths (every other one) and over the river.
func _vents(host: Node3D) -> void:
	var spots: Array[Vector3] = []
	for i in vents.size():
		if i % 2 == 0:
			spots.append(vents[i])
	for p: Vector2 in [Vector2(6.0, -20.0), Vector2(-9.0, -66.0), Vector2(10.0, -72.0), Vector2(-4.0, -30.0)]:
		if p.y < star_z:
			spots.append(Vector3(p.x, LAVA + 0.1, p.y))
	for p in spots:
		var star := p.z > star_z                       # a star seam's mouth breathes a pale mist, no fire
		var smoke := Vfx.emitter(Color(0.36, 0.32, 0.52, 0.22) if star else Color(0.16, 0.13, 0.13, 0.35), {"count": 14, "life": 7.0, "speed": Vector2(0.6, 1.3), "size": 2.4, "gravity": 0.25, "radius": 0.5, "spread": 12.0, "additive": false, "turbulence": true, "damping": 0.2, "grow": 0.5})
		if smoke:
			smoke.name = "VentSmoke"
			smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 18, 12))
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
		if star or (p.y > LAVA + 1.0 and spots.find(p) % 2 == 1):
			continue                                     # every other rim vent only smokes
		var spit := Vfx.emitter(Color(1.8, 0.6, 0.12), {"count": 18, "life": 2.4, "speed": Vector2(0.8, 2.6), "size": 0.05, "gravity": -1.2, "radius": 0.3, "spread": 25.0, "turbulence": true})
		if spit:
			spit.name = "VentEmbers"
			spit.preprocess = 2.0
			host.add_child(spit)
			spit.global_position = p + Vector3.UP * 0.1
			spit.emitting = true
	report.append("vents: %d" % spots.size())

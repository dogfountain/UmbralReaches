extends RefCounted
## The rift's breath: a column of smoke out of the lava at the rift's head, leaning away downwind (east-south-east,
## over the old flows and the fen) so it clears the summit's dais. Seen from the whole north of the Realm, it marks
## where the night ends; from the village it rises behind the summit's right shoulder. Three nested shells of a bent
## tube (plume.gdshader, ~4 k triangles in all, at most three layers of overdraw), on the horizon's range like the
## other landmarks, and a few slow puffs where it leaves the lava for the near view.

const SHADER := preload("res://core/world/realm/rift/plume.gdshader")
const RINGS := 30
const SIDES := 22
## The spine, from the lava up: [x, y, z, radius]. Rises steeply out of the chasm, then leans with the wind.
const SPINE := [
	[13.0, -16.5, -113.0, 4.5], [14.5, -6.0, -112.0, 6.5], [18.0, 6.0, -110.5, 9.0], [24.0, 18.0, -108.0, 12.0],
	[33.0, 31.0, -104.0, 15.5], [45.0, 45.0, -98.5, 19.5], [60.0, 60.0, -92.0, 24.0], [78.0, 75.0, -84.0, 29.0],
	[99.0, 89.0, -75.0, 35.0], [122.0, 101.0, -65.0, 42.0],
]
const SHELLS := [[1.0, 0.0, 0.72, 0.045], [0.78, 3.7, 0.8, 0.055], [0.55, 7.9, 0.88, 0.066]]   ## radius scale, seed, density, rise


static func build(host: Node3D) -> void:
	var root := Node3D.new()
	root.name = "RiftPlume"
	root.add_to_group(Groups.CULL_SKIP)
	host.add_child(root)
	var moon := _moon_dir(host)
	for k in SHELLS.size():
		var s: Array = SHELLS[k]
		var mi := MeshInstance3D.new()
		mi.name = "Shell%d" % k
		mi.mesh = _tube(float(s[0]))
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("seed", float(s[1]))
		m.set_shader_parameter("density", float(s[2]))
		m.set_shader_parameter("rise", float(s[3]))
		m.set_shader_parameter("moon_dir", moon)
		m.render_priority = -1 - k                       # outer shells draw first
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.ignore_occlusion_culling = true
		mi.add_to_group(Groups.CULL_SKIP)
		root.add_child(mi)
	_puffs(root)


## Towards the moon (atmosphere.gd's key light), for the shells' lit side.
static func _moon_dir(_host: Node3D) -> Vector3:
	var el := deg_to_rad(Atmosphere.MOON_ELEVATION)
	var b := deg_to_rad(Atmosphere.MOON_BEARING)
	return Vector3(sin(b) * cos(el), sin(el), -cos(b) * cos(el))


## A tube along SPINE (Catmull-Rom between its points), open at both ends, normals outward.
static func _tube(scale: float) -> ArrayMesh:
	var pts: Array[Vector3] = []
	var rad: Array[float] = []
	var n := SPINE.size()
	for i in RINGS:
		var t := float(i) / float(RINGS - 1) * float(n - 1)
		var a := mini(int(t), n - 2)
		var f := t - a
		var p0: Array = SPINE[maxi(a - 1, 0)]
		var p1: Array = SPINE[a]
		var p2: Array = SPINE[a + 1]
		var p3: Array = SPINE[mini(a + 2, n - 1)]
		var v := Vector3.ZERO
		for c in 3:
			v[c] = _cr(float(p0[c]), float(p1[c]), float(p2[c]), float(p3[c]), f)
		pts.append(v)
		rad.append(lerpf(float(p1[3]), float(p2[3]), f) * scale)
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in RINGS:
		var fwd := (pts[mini(i + 1, RINGS - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.FORWARD).normalized()
		if side.length() < 0.5:
			side = Vector3.RIGHT
		var up := side.cross(fwd).normalized()
		for j in SIDES + 1:
			var ang := TAU * float(j) / float(SIDES)
			var dir := side * cos(ang) + up * sin(ang)
			# a little lumpiness so the silhouette is not a perfect cone
			var r := rad[i] * (1.0 + 0.1 * sin(ang * 3.0 + i * 0.7) + 0.06 * sin(ang * 5.0 - i * 1.3))
			verts.append(pts[i] + dir * r)
			nrms.append(dir)
			uvs.append(Vector2(float(j) / float(SIDES), float(i) / float(RINGS - 1)))
			uv2.append(Vector2(rad[i], 0.0))
	for i in RINGS - 1:
		for j in SIDES:
			var a := i * (SIDES + 1) + j
			var b := a + SIDES + 1
			idx.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))      # clockwise seen from outside (Godot's front)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-40.0, -20.0, -160.0), Vector3(220.0, 150.0, 140.0))     # the billows push past the rings
	return m


static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t2 * t)


## Slow, lava-lit puffs where the column leaves the river (the near view from the crossing and the east rim).
static func _puffs(root: Node3D) -> void:
	var base: Array = SPINE[0]
	var p := Vfx.emitter(Color(0.2, 0.17, 0.17, 0.4), {"count": 12, "life": 9.0, "speed": Vector2(1.2, 2.2), "size": 5.0, "gravity": 0.15,
		"radius": 3.0, "spread": 14.0, "additive": false, "turbulence": true, "damping": 0.1, "grow": 0.55, "dir": Vector3(0.35, 1.0, 0.15)})
	if p == null:
		return
	p.name = "PlumePuffs"
	p.visibility_aabb = AABB(Vector3(-14, -2, -14), Vector3(30, 34, 30))
	p.preprocess = 9.0
	root.add_child(p)
	p.position = Vector3(float(base[0]), float(base[1]) + 1.5, float(base[2]))
	p.emitting = true

extends RefCounted
## The vistas pass's places, called from realm_vistas.gd (RealmPois REACH_POIS: reserve() before the stamp and the
## flora, build() after), beside its moon shafts and lookouts. What makes the doubled Realm read from a ridge or a
## road bend, on top of the landform (RealmRelief) and the sky (world/sky/sky_vistas.gdshaderinc):
##
## - The March beacons: the Order's signal towers on the high ground at the Marches' edge, one in sight of the next, out
##   since the sky went dark (tools/blender/vista_beacon.py). Two stand on the downs' scarp, over the Long Arches and
##   over Fallowmere; one on a spur of the Crowns between the Empty Plinth and the Greyfell. A stair winds up the
##   outside to the basket; the wanderer kindles it (a Lamp: the gesture, the save, the ash) and its fire and smoke are
##   seen across the Realm (beacon_fire.gd), and the other lit beacons answer. The view from the top is the vista.
## - Sightlines: tree-free fans where a way comes over the scarp's lip or crosses into a Reach, so the land opens there.
## - The scarp's cliffs: stratified rock faces along the downs' south escarpment and a talus of boulders at its foot.
## - Valley mist: sheets laid over the low ground (the Long Arches' valley, the Reedmere, the Drowned Nave's basin, the
##   Southwood's hollows, the Kings' Barrows' vale, Corvin's Mere, the Hollow Fen) that pool in it (valley_mist.gdshader).
##   `-- --no-vistas` turns these places off, `-- --no-vista-sky` the sky's far ranges and veils (A/B).

const Kit37 := preload("res://core/world/realm/west_marches_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const BeaconFire := preload("res://core/world/realm/vistas/beacon_fire.gd")
const MIST := preload("res://core/world/realm/vistas/valley_mist.gdshader")
const FALL := preload("res://core/world/realm/vistas/veil_fall.gdshader")
const SPRAY := preload("res://core/world/realm/vistas/fall_spray.gdshader")

const BEACON := "vista_beacon.glb"
const BEACON_FAR := "res://art/models/vista_beacon_far.glb"
const FLOOR := 20.9                    ## the beacon's platform over its origin (vista_beacon.py FLOOR)
const BASKET := 0.62                   ## the basket's foot over the platform
const NEAR_END := 120.0                ## the far mesh takes over here
## id, title, where (xz), the side its stair starts on (toward the way it is reached from)
const BEACONS := [
	{"id": "arches", "title": "the Arches Beacon", "at": Vector2(40.0, 249.0), "from": Vector2(84.0, 235.0)},
	{"id": "fallow", "title": "the Fallow Beacon", "at": Vector2(-116.0, 250.0), "from": Vector2(-150.0, 240.0)},
	{"id": "crowns", "title": "the Crown Beacon", "at": Vector2(-262.0, -127.0), "from": Vector2(-240.0, -100.0)},
]
## Sightlines kept free of trees: [from, toward, reach m, half width at the far end]
const SIGHTS := [
	[Vector2(88.0, 252.0), Vector2(0.0, 342.0), 56.0, 18.0],      # arches_link over the lip: the Long Arches below
	[Vector2(-149.0, 254.0), Vector2(-200.0, 330.0), 50.0, 16.0],  # fallow_way over the lip: Fallowmere and the meres
	[Vector2(40.0, 249.0), Vector2(15.0, 310.0), 44.0, 22.0],      # under the Arches Beacon, looking south over the arches
	[Vector2(-116.0, 250.0), Vector2(-150.0, 310.0), 44.0, 22.0],  # under the Fallow Beacon, over Fallowmere
	[Vector2(-258.0, 57.0), Vector2(-330.0, 40.0), 34.0, 12.0],    # the road into the West Reach
	[Vector2(258.0, 65.0), Vector2(330.0, 52.0), 34.0, 12.0],      # the road into the East Reach: Lastlight ahead
]
## Valley mist: [centre, size, metres of mist over the lowest ground, density]
const MISTS := [
	[Vector2(0.0, 356.0), Vector2(170.0, 84.0), 3.2, 0.5],          # the Long Arches' dry valley
	[Vector2(-302.0, 322.0), Vector2(150.0, 150.0), 2.2, 0.55],      # the Reedmere
	[Vector2(318.0, 164.0), Vector2(70.0, 98.0), 2.4, 0.5],          # the Drowned Nave's basin
	[Vector2(176.0, 334.0), Vector2(150.0, 110.0), 2.6, 0.42],       # the Southwood's hollows
	[Vector2(-298.0, 160.0), Vector2(56.0, 150.0), 2.4, 0.4],        # the Kings' Barrows' vale
	[Vector2(107.0, 121.0), Vector2(90.0, 64.0), 2.0, 0.45],         # Corvin's Mere
	[Vector2(75.0, -22.0), Vector2(70.0, 112.0), 2.0, 0.4],          # the Hollow Fen
	[Vector2(-214.0, -112.0), Vector2(64.0, 56.0), 2.0, 0.38],      # the Empty Plinth's valley head, under the fall
]
## High falls down the Crowns' face: [x, the z it breaks out of the rock, the z it may run to at most, width at the
## lip, width at the foot]. The Sorrow is born here: it falls into the Empty Plinth's moss, sinks, and rises again at
## its spring (RealmLayout.RIVER's head) south down the valley.
const FALLS := [
	[-214.0, -159.0, -112.0, 3.6, 11.0],
]

static var built := {}                 ## what the last build made (tests, the shots)
static var _spots := {}                ## beacon id -> {at: Vector3, yaw}


static func off() -> bool:
	return "--no-vistas" in OS.get_cmdline_user_args()


# --- reserve (before the terrain stamp and the flora) ----------------------------------------------------------------

static func reserve(root: Node) -> void:
	_spots.clear()
	if off():
		return
	for b: Dictionary in BEACONS:
		var at := _clear_spot(b.at as Vector2)
		var y := _seat(at)
		var to: Vector2 = (b.from as Vector2) - at
		_spots[b.id] = {"at": Vector3(at.x, y, at.y), "yaw": atan2(to.x, to.y)}
		Flora.tree_clear.append([at, 15.0])
		WorldLanes.register_site("vista_beacon_" + String(b.id), Rect2(at - Vector2(4.6, 4.6), Vector2(9.2, 9.2)), y, y)
	for s: Array in SIGHTS:
		var a: Vector2 = s[0]
		var dir := ((s[1] as Vector2) - a).normalized()
		var reach := float(s[2])
		var d := 0.0
		while d <= reach:
			var w := lerpf(5.0, float(s[3]), d / reach)
			Flora.tree_clear.append([a + dir * d, w])
			d += maxf(5.0, w * 0.8)


## The tiling set at the beacon's scale: its stones are geometry, so the set is only their grain (a gentler normal).
static var _mats := {}
static func _mat(set_name: String) -> StandardMaterial3D:
	if not _mats.has(set_name):
		var m := Kit37.mat(set_name).duplicate() as StandardMaterial3D
		m.normal_scale = 0.4 if set_name == "hewn" else 0.7
		m.uv1_scale = Vector3(1.6, 1.6, 1.6) if set_name == "hewn" else Vector3.ONE
		_mats[set_name] = m
	return _mats[set_name]


## A spot near `p` off every way (6 m), off the water.
static func _clear_spot(p: Vector2) -> Vector2:
	if RealmLayout.path_dist(p) >= 6.0 and not Land.in_water(p.x, p.y):
		return p
	for r: float in [3.0, 6.0, 9.0, 12.0]:
		for k in 12:
			var q := p + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * r
			if RealmLayout.path_dist(q) >= 6.0 and not Land.in_water(q.x, q.y):
				return q
	return p


## The foot's seat: a little above the lowest ground round the foot (the buried skirt takes the rest of the slope).
static func _seat(at: Vector2) -> float:
	var lo := INF
	var hi := -INF
	for k in 12:
		var q := at + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * 3.1
		var h := Land.height_at(q.x, q.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	return lerpf(lo, hi, 0.3)


# --- build (after the flora) -----------------------------------------------------------------------------------------

static func build(holder: Node3D) -> void:
	built.clear()
	if "--no-vista-sky" in OS.get_cmdline_user_args():
		var we := holder.get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we and we.environment and we.environment.sky and we.environment.sky.sky_material is ShaderMaterial:
			(we.environment.sky.sky_material as ShaderMaterial).set_shader_parameter("vistas", 0.0)
	if off():
		return
	var t0 := Time.get_ticks_msec()
	var host := Node3D.new()
	host.name = "VistaPlaces"
	holder.add_child(host)
	var space := holder.get_world_3d().direct_space_state
	var n_b := 0
	for b: Dictionary in BEACONS:
		if _spots.has(b.id) and _beacon(host, b):
			n_b += 1
	var n_c := _scarp_cliffs(host, space)
	var n_m := _mists(host)
	var n_f := _falls(host)
	built = {"beacons": n_b, "cliffs": n_c, "mists": n_m, "falls": n_f}
	print("REALM_POI vista places built %s in %d ms" % [built, Time.get_ticks_msec() - t0])


static func _beacon(host: Node3D, b: Dictionary) -> bool:
	var sp: Dictionary = _spots[b.id]
	var at: Vector3 = sp.at
	var xf := Transform3D(Basis(Vector3.UP, float(sp.yaw)), at)
	var root := Kit37.place(host, BEACON, xf, {})
	if root == null:
		return false
	root.name = "Beacon_" + String(b.id)
	root.set_meta("site", "vista_beacon_" + String(b.id))
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var nm := String(mi.name)
		if nm.contains("-colonly"):
			continue
		var set_name := nm.get_slice("__", 1).get_slice(".", 0).get_slice("_", 0) if nm.contains("__") else "hewn"
		mi.material_override = _mat(set_name)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if set_name == "iron" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# far off: the 140-triangle silhouette, from NEAR_END to the horizon
	var far_scene := load(BEACON_FAR) as PackedScene
	if far_scene != null:
		var fs := far_scene.instantiate()
		var fm := fs.find_children("*", "MeshInstance3D", true, false)
		if not fm.is_empty():
			FarDetail.register(root, (fm[0] as MeshInstance3D).mesh, Transform3D.IDENTITY, NEAR_END, _mat("hewn"))
		fs.free()
	# the kindling: a Lamp in the basket (its own cresset body hidden: the basket is the model's)
	var lamp := Lamp.new()
	lamp.name = "Lamp_beacon_" + String(b.id)
	lamp.lamp_id = "vista_beacon_" + String(b.id)
	lamp.look = "cresset"
	lamp.power = 1.8
	root.add_child(lamp)
	lamp.position = Vector3(0.0, FLOOR + BASKET - 0.15, 0.0)
	var body := lamp.get_node_or_null("Body") as Node3D
	if body:
		body.visible = false
	# the fire seen across the Realm, and its moment
	var fire := BeaconFire.new()
	fire.name = "BeaconFire"
	fire.lamp = lamp
	fire.title = String(b.title)
	fire.position = Vector3(0.0, FLOOR + BASKET + 0.25, 0.0)
	root.add_child(fire)
	# a glide perch on the parapet, a grapple anchor on the hoist (as the other tall places)
	var perch := Marker3D.new()
	perch.name = "GlidePerch"
	perch.position = Vector3(0.0, FLOOR + 0.1, 0.0)
	perch.add_to_group(&"glide_perch")
	root.add_child(perch)
	return true


## Rock faces on the downs' scarp where it is steep, a talus of boulders at their feet. Off the ways and the sites.
static func _scarp_cliffs(host: Node3D, space: PhysicsDirectSpaceState3D) -> int:
	var made := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4141
	var x := -170.0
	while x <= 174.0:
		var step := rng.randf_range(7.0, 10.5)
		var face := _steepest(x)
		x += step
		if face.z < 2.4:
			continue                          # not steep here (a combe where a way goes down)
		var p := Vector2(face.x, face.y)
		if RealmLayout.path_dist(p) < 12.0 or WorldLanes.site_at(p, 4.0).size() > 0 or rng.randf() < 0.18:
			continue
		# the face's run: the scarp's line wanders, so the rock faces along it
		var a := _steepest(face.x - 3.0)
		var c := _steepest(face.x + 3.0)
		var along := Vector2(c.x - a.x, c.y - a.y).normalized()
		var out := Vector2(along.y, -along.x)
		if out.y < 0.0:
			out = -out                         # the face looks down, south
		var top := Land.height_at(p.x - out.x * 6.0, p.y - out.y * 6.0)
		var foot := Land.height_at(p.x + out.x * 6.0, p.y + out.y * 6.0)
		var drop := top - foot
		if drop < 4.0:
			continue
		var w := rng.randf_range(8.0, 11.5)
		var hgt := clampf(drop * rng.randf_range(0.62, 0.8), 3.5, 11.0)
		var style := "mossy" if rng.randf() < 0.35 else "granite"
		var mesh := RockKit.cliff(rng.randi(), Vector3(w, hgt, 3.4), style)
		var base := Vector3(p.x + out.x * 2.2, foot + drop * 0.12, p.y + out.y * 2.2)
		var b := Basis(Vector3.UP, atan2(out.x, out.y)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-14.0, -4.0))) * Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-7.0, 7.0)))
		RockKit.spawn(host, mesh, Transform3D(b, base))
		made += 1
		# talus: a few fallen blocks out on the floor below the face
		for k in rng.randi_range(2, 4):
			var tq := Vector2(p.x, p.y) + out * rng.randf_range(5.5, 11.0) + along * rng.randf_range(-w * 0.5, w * 0.5)
			if RealmLayout.path_dist(tq) < 3.0 or Land.in_water(tq.x, tq.y):
				continue
			var s := rng.randf_range(0.7, 2.0)
			var bm := RockKit.boulder(rng.randi(), Vector3(s * 1.3, s * 0.8, s), style)
			var ty := RealmLayout.ground(space, tq.x, tq.y)
			RockKit.spawn(host, bm, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(tq.x, ty - 0.15 * s, tq.y)), s > 1.1)
	return made


## Where the scarp is steepest at x (z 236..296): Vector3(x, z, drop over 2 m).
static func _steepest(x: float) -> Vector3:
	var best := Vector3(x, 262.0, 0.0)
	var z := 236.0
	while z <= 296.0:
		var d := Land.height_at(x, z - 1.0) - Land.height_at(x, z + 1.0)
		if d > best.z:
			best = Vector3(x, z, d)
		z += 1.0
	return best


static func _mists(host: Node3D) -> int:
	var made := 0
	for i in MISTS.size():
		var m: Array = MISTS[i]
		var c: Vector2 = m[0]
		var sz: Vector2 = m[1]
		var lo := INF
		var x := c.x - sz.x * 0.5
		while x <= c.x + sz.x * 0.5:
			var z := c.y - sz.y * 0.5
			while z <= c.y + sz.y * 0.5:
				lo = minf(lo, maxf(Land.height_at(x, z), Land.water_y_at(x, z) if Land.in_water(x, z) else -INF))
				z += 6.0
			x += 6.0
		var mi := MeshInstance3D.new()
		mi.name = "ValleyMist%d" % i
		var pm := PlaneMesh.new()
		pm.size = sz
		var mat := ShaderMaterial.new()
		mat.shader = MIST
		mat.set_shader_parameter("depth_m", float(m[2]))
		mat.set_shader_parameter("density", float(m[3]))
		mat.set_shader_parameter("seed", float(i) * 7.31)
		pm.material = mat
		mi.mesh = pm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(c.x, lo + float(m[2]), c.y)
		mi.set_meta(&"far_detail", true)
		mi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mi)
		made += 1
	return made


## A ribbon laid down the face from where the water breaks out of the rock to where the ground eases (the slope over
## 4 m falls under 0.35), standing a little off the rock and more as it drops (it leaves the face), then spray.
static func _falls(host: Node3D) -> int:
	var made := 0
	for f: Array in FALLS:
		var x := float(f[0])
		var z := float(f[1])
		var pts: Array[Vector3] = []
		var drop := 0.0
		var top := Land.height_at(x, z)
		while z <= float(f[2]):
			var h := Land.height_at(x, z)
			var slope := (h - Land.height_at(x, z + 4.0)) / 4.0
			drop = top - h
			var wx := x + 1.2 * sin(z * 0.21)
			pts.append(Vector3(wx, h + 0.7 + drop * 0.035, z + 0.35 + drop * 0.02))
			if slope < 0.35 and drop > 8.0:
				break
			z += 1.5
		if pts.size() < 4:
			continue
		var length := 0.0
		for i in range(1, pts.size()):
			length += pts[i].distance_to(pts[i - 1])
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var acc := 0.0
		for i in pts.size():
			if i > 0:
				acc += pts[i].distance_to(pts[i - 1])
			var v := acc / length
			var w := lerpf(float(f[3]), float(f[4]), pow(v, 0.7)) * 0.5
			for side: float in [-1.0, 1.0]:
				st.set_uv(Vector2(0.5 + side * 0.5, v))
				st.set_normal(Vector3(0, 0.2, 1).normalized())
				st.add_vertex(pts[i] + Vector3(side * w, 0.0, 0.0))
		for i in pts.size() - 1:
			var a := i * 2
			st.add_index(a)
			st.add_index(a + 2)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(a + 2)
			st.add_index(a + 3)
		var mi := MeshInstance3D.new()
		mi.name = "CrownsFall%d" % made
		mi.mesh = st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = FALL
		mat.set_shader_parameter("fall_len", length)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta(&"far_detail", true)
		mi.add_to_group(Groups.CULL_SKIP)
		host.add_child(mi)
		# spray where it lands
		var foot: Vector3 = pts[pts.size() - 1]
		for k in 3:
			var sp := MeshInstance3D.new()
			sp.name = "FallSpray%d" % k
			var q := QuadMesh.new()
			q.size = Vector2(14.0 - k * 3.0, 11.0 - k * 2.0)
			q.center_offset = Vector3(0.0, q.size.y * 0.42, 0.0)
			var sm := ShaderMaterial.new()
			sm.shader = SPRAY
			q.material = sm
			sp.mesh = q
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sp.set_instance_shader_parameter("seed", float(k) * 3.7)
			sp.set_meta(&"far_detail", true)
			sp.add_to_group(Groups.CULL_SKIP)
			host.add_child(sp)
			sp.position = foot + Vector3((k - 1) * 3.0, -1.5 + k * 0.8, 1.5 + k * 1.5)
		made += 1
	return made

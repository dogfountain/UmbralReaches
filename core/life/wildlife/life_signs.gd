extends Node3D
## Signs of life and death in the dark (docs/living_realm.md): what the night shows you from afar before you are
## there. Built by life_director.gd after its rosters; "LifeSigns" under it. Most of it costs no script time:
##   carrion       a packhorse dead by a far track, ravens on it and round it pecking (crows, life_birds.gd: they
##                 lift and wheel when you come, and settle again when you go), more of them wheeling high above
##   kettles       ravens wheeling high over the dead and over the hollowed's camps out in the wild: a sign, seen
##                 against the sky from a long way off, that something lies there (orbit.gdshader, a crow's body)
##   marsh lights  pale flames over the meres and the Nave's water, the barrow lights over the Kings' Barrows, the
##                 Lanternwood's cold lights among its trunks: only ever seen from afar (marsh_light.gdshader)
##   eyeshine      a pair of eyes at a wood's edge, the lantern caught in them; they blink, look away, shift, and
##                 are gone when you come close or a hollowed thing does (eyeshine.gdshader)
##   howls         far off on the high ground something howls, and another answers from somewhere else
## The Gloom tide puts the lights and eyes out and stills the howls; a hollowed thing near a pair of eyes or a field
## of lights puts those out (checked twice a second, only for what is near the camera).

const LifeKit := preload("res://core/life/wildlife/life_kit.gd")
const LifePlace := preload("res://core/life/wildlife/life_place.gd")
const Birds := preload("res://core/life/wildlife/life_birds.gd")
const Beasts := preload("res://core/life/wildlife/life_beasts.gd")
const Reaches := preload("res://core/life/wildlife/life_reaches.gd")
const ScapeSynth := preload("res://core/life/wildlife/scape_synth.gd")
const HorseRig := preload("res://core/world/mount/horse_rig.gd")
const HorseDB := preload("res://core/world/mount/horse_db.gd")
const RL := preload("res://core/world/realm/realm_land.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const MARSH_SH := preload("res://core/life/wildlife/marsh_light.gdshader")
const EYES_SH := preload("res://core/life/wildlife/eyeshine.gdshader")
const SEED := 23417

## Where the dead lie: [region, near, breed]. Each is searched for 6-22 m off a way (seen from it), on open
## flat ground clear of camps, fires and sites.
const CARRION := [
	["greyfell", Vector2(-306.0, -40.0), "garron"],         # fell_track, below the keep's crag: a packhorse down
	["kingsbarrows", Vector2(-308.0, 176.0), "palfrey"],   # barrow_track, on the ridge's south shoulder
	["cairns", Vector2(296.0, 252.0), "garron"],           # cairn_track climbing onto the heath
	["bellfall", Vector2(314.0, 96.0), "draught"],         # bellfall_way before the crater
	["siege", Vector2(-198.0, 124.0), "draught"],          # the Siege Lines: the old battle's ground
	["southwood", Vector2(168.0, 292.0), "fenpony"],       # where arches_way goes into the dark wood
	["arches", Vector2(34.0, 330.0), "garron"],            # the valley under the aqueduct
]

## Raven kettles over landmarks (as well as over every carrion site and the wild's camps): [centre, height over ground].
const KETTLES := [
	[RealmReaches.CRATER_C, 20.0],                          # the fallen bell
	[Vector2(-345.0, 152.0), 16.0],                         # the King's Barrow, its door open
	[Vector2(-318.0, -108.0), 26.0],                        # the Broken Keep
	[Vector2(327.0, 324.0), 26.0],                          # the Cairn Tower
]

## Lights: [region, kind, how many fields]. marsh: over the region's water; barrow: round its place slots; wood:
## among its deepest trees.
const LIGHTS := [
	["reedmere", "marsh", 4], ["nave", "marsh", 3], ["mere", "marsh", 2], ["stillwater", "marsh", 1],
	["kingsbarrows", "barrow", 3], ["barrows", "barrow", 1], ["lanternwood", "wood", 4],
]
const LIGHT_LOOK := {
	"marsh": [Color(0.55, 0.95, 0.8), 1.6, 0.22],
	"barrow": [Color(0.62, 0.78, 1.0), 1.5, 0.2],
	"wood": [Color(0.42, 0.85, 1.0), 1.45, 0.19],
}

## Woods where eyes watch the ways: [region, clusters].
const EYES := [["lanternwood", 3], ["southwood", 4], ["thornwood", 2], ["oak", 1], ["holds", 1], ["sorrow", 1], ["kingsbarrows", 1], ["cairns", 1]]

var director                             ## life_director.gd (untyped: its own methods are called)
var carrion: Array = []                ## {at: Vector3, region, birds: Node3D}
var kettles: Array[MultiMeshInstance3D] = []
var fields: Array[MultiMeshInstance3D] = []
var eyes: Array[MultiMeshInstance3D] = []
var howls := 0                          ## calls made (tests)
var quiet := false                      ## tests: no howls of themselves
var _rng := RandomNumberGenerator.new()
var _kettle_mat: ShaderMaterial
var _marsh_mats := {}
var _eye_mat: ShaderMaterial
var _t := 0.0
var _howl_t := 0.0
var _answer: Array = []                 ## [seconds left, Vector3 at, pitch]
var _howlers: Array[AudioStreamPlayer3D] = []
var _hi := 0
var _tide := false


func setup(dir: Node3D, root: Node, space: PhysicsDirectSpaceState3D, add: Callable) -> void:
	name = "LifeSigns"
	var t0 := Time.get_ticks_msec()
	director = dir
	_rng.seed = SEED
	_howl_t = _rng.randf_range(40.0, 90.0)
	add_to_group(&"life_census")
	_carrion(root, space, add)
	_kettles(space)
	_lights()
	_eyes()
	for i in 3:
		var a := AudioStreamPlayer3D.new()
		a.bus = &"AmbOut" if AudioServer.get_bus_index("AmbOut") >= 0 else &"Ambience"
		a.unit_size = 34.0
		a.max_distance = 480.0
		a.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		a.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		a.panning_strength = 0.9
		add_child(a)
		_howlers.append(a)
	if Events.has_signal("gloom_tide"):
		Events.gloom_tide.connect(_on_tide)
	print("LIFE signs in %d ms: %d carrion, %d kettles, %d light fields, %d eye pairs" % [Time.get_ticks_msec() - t0, carrion.size(), kettles.size(), fields.size(), eyes.size()])
	for c: Dictionary in carrion:
		print("LIFE carrion %s at %s" % [c.region, c.at])


# --- carrion -----------------------------------------------------------------------------------------

func _carrion(root: Node, space: PhysicsDirectSpaceState3D, add: Callable) -> void:
	var camps := Reaches.keep_camps()
	var fires := Reaches.keep_fires(root)
	var i := 0
	for e: Array in CARRION:
		var rid := String(e[0])
		var near: Vector2 = e[1]
		var spot := Vector2.INF
		var max_cover := 0.45 if RealmLayout.biome_at(near.x, near.y) == "oldforest" else 0.18
		for k in 260:
			var spread := 30.0 if k < 160 else 52.0         # camps moved off the landmarks crowd some tracks: look further along them
			var q := near + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
			var pd := RealmLayout.path_dist(q)
			if pd < 4.0 or pd > (12.0 if k < 160 else 20.0) or not _carrion_ground(q) or String(RealmLayout.region_at(q.x, q.y).get("id", "")) != rid:
				continue
			if Flora.cover_at(q.x, q.y) > max_cover or not _flat(q, 2.6, 0.45):
				continue
			var ok := true
			for c: Vector2 in camps:
				if c.distance_to(q) < 22.0:
					ok = false
			for f: Vector2 in fires:
				if f.distance_to(q) < 10.0:
					ok = false
			if ok:
				spot = q
				break
		if spot == Vector2.INF:
			continue
		var gy := LifePlace.ground(space, spot.x, spot.y)
		# the body lies along the way, on its side, its legs out stiff toward it
		var tang := _path_dir(spot)
		var yaw := atan2(-tang.x, -tang.y) + _rng.randf_range(-0.5, 0.5)
		var holder := Node3D.new()
		holder.name = "Carrion_%s" % rid
		add_child(holder)
		holder.global_position = Vector3(spot.x, gy, spot.y)
		var body := HorseRig.new()
		var breed := String(e[2])
		body.setup(breed, HorseDB.BREEDS.get(breed, HorseDB.BREEDS["garron"]))
		holder.add_child(body)
		body.pose(0.0, 0.0, 1.0, 0.016)
		if body.skel != null:
			var li := body.skel.find_bone("lantern")
			if li >= 0:
				body.skel.set_bone_pose_scale(li, Vector3.ONE * 0.001)      # nobody's lantern burns on a dead horse
		var roll := Basis(Vector3.FORWARD, deg_to_rad(84.0 + _rng.randf_range(-6.0, 6.0)))
		body.basis = Basis(Vector3.UP, yaw) * roll
		body.position = Vector3(0, 0.34, 0)
		if body.mesh_inst != null:
			body.mesh_inst.visibility_range_end = 90.0
			body.mesh_inst.visibility_range_end_margin = 8.0
		# ravens on the flank and round it, facing in
		var perches: Array = []
		var flank := holder.global_position + Vector3(0, 0.62, 0)
		for k in 2:
			var along := Vector3(-tang.x, 0, -tang.y).rotated(Vector3.UP, _rng.randf_range(-0.3, 0.3)) * (0.2 + 0.35 * float(k)) * (1.0 if k == 0 else -1.0)
			perches.append([flank + along, _rng.randf_range(-PI, PI)])
		for k in 7:
			var a := TAU * float(k) / 7.0 + _rng.randf_range(-0.3, 0.3)
			var q2 := spot + Vector2(cos(a), sin(a)) * _rng.randf_range(1.3, 3.2)
			if RL.in_water(q2.x, q2.y):
				continue
			var y2 := LifePlace.ground(space, q2.x, q2.y)
			var to := Vector3(spot.x - q2.x, 0, spot.y - q2.y)
			perches.append([Vector3(q2.x, y2, q2.y), Birds.yaw_to(to) + _rng.randf_range(-0.6, 0.6)])
		var g := Birds.new()
		g.name = "CrowsCarrion_%s" % rid
		g.setup("crow", perches, mini(5, perches.size() - 2), SEED + 131 * i)
		add.call(g)
		# a fox at it, nosing at the carcass between the ravens (it bolts when you come, like any fox, and comes back)
		var fq := spot + Vector2(cos(yaw), -sin(yaw)) * 1.9
		if LifePlace.open_ground(fq.x, fq.y) and not RL.in_water(fq.x, fq.y):
			var fox := Beasts.new()
			fox.name = "FoxCarrion_%s" % rid
			fox.setup("fox", [Vector3(fq.x, LifePlace.ground(space, fq.x, fq.y), fq.y)] as Array[Vector3], SEED + 977 * i)
			add.call(fox)
		var tr: Variant = director.get("tracks")
		if tr != null:
			for k in 5:
				tr.print_at(Vector3(spot.x + _rng.randf_range(-2.2, 2.2), 0, spot.y + _rng.randf_range(-2.2, 2.2)), _rng.randf_range(-PI, PI), 3, INF)
		# the grass round it trampled and picked over (the secrets module flushes the queue after its own sites)
		var kit: Variant = load("res://core/life/secrets/kit.gd")
		kit.clear_flora(null, [Vector3(spot.x, spot.y, 3.6)])
		carrion.append({"at": holder.global_position, "region": rid, "birds": g})
		i += 1


## Ground a carcass can lie on: in bounds, dry, off every site and raid floor (a fell's crag and a wood's floor are
## fine: the open-ground test for walkers refuses both).
func _carrion_ground(q: Vector2) -> bool:
	if not RealmLayout.BOUNDS.grow(-8.0).has_point(q) or RL.in_water(q.x, q.y) or RL.in_water(q.x + 2.0, q.y) or RL.in_water(q.x - 2.0, q.y):
		return false
	if not WorldLanes.site_at(q, 3.5).is_empty():
		return false
	for rd: Dictionary in RealmLayout.RAIDS:
		if q.distance_to(rd.c) < float(rd.r) + 6.0:
			return false
	return RealmLayout.biome_at(q.x, q.y) != "ash"


func _flat(q: Vector2, r: float, dh: float) -> bool:
	var h := RL.height_at(q.x, q.y)
	for k in 6:
		var a := TAU * float(k) / 6.0
		if absf(RL.height_at(q.x + cos(a) * r, q.y + sin(a) * r) - h) > dh:
			return false
	return true


## The nearest way's direction at p (unit, xz).
func _path_dir(p: Vector2) -> Vector2:
	var best := Vector2.RIGHT
	var bd := INF
	for path: Dictionary in RealmLayout.PATHS:
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var ab: Vector2 = (pts[i + 1] as Vector2) - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a + ab * t)
			if d < bd and ab.length() > 0.01:
				bd = d
				best = ab.normalized()
	return best


# --- kettles -----------------------------------------------------------------------------------------

func _kettle_material() -> ShaderMaterial:
	if _kettle_mat != null:
		return _kettle_mat
	var m := ShaderMaterial.new()
	m.shader = LifeKit.ORBIT_SH
	m.set_shader_parameter("detail_tex", LifeKit.detail_tex())
	m.set_shader_parameter("detail_scale", 3.0)
	m.set_shader_parameter("detail", 0.35)
	var rig: Dictionary = LifeKit.RIG["crow"]
	m.set_shader_parameter("wing_hinge", rig.wing_hinge)
	m.set_shader_parameter("flap_hz", 1.9)
	m.set_shader_parameter("wing_amp", 0.32)
	m.set_shader_parameter("jink", 0.015)
	m.set_shader_parameter("ellipse", 0.82)
	m.set_shader_parameter("bank", 0.42)
	m.set_shader_parameter("roughness", 0.55)
	m.set_shader_parameter("rim_col", Color(0.5, 0.6, 0.95))
	m.set_shader_parameter("rim_amount", 0.35)
	m.set_shader_parameter("size_mul", 2.4)          # a raven's 1.2 m span (the crow mesh is a small crow)
	_kettle_mat = m
	return m


## Ravens wheeling: over each carrion site, each landmark in KETTLES, and each camp out in the wild (beyond the old
## Realm, not in a town): the world shows where the dead and the hollowed are before you are there.
func _kettles(_space: PhysicsDirectSpaceState3D) -> void:
	var at: Array = []
	for c: Dictionary in carrion:
		var p: Vector3 = c.at
		at.append([Vector2(p.x, p.z), 15.0, 3])
	for e: Array in KETTLES:
		at.append([e[0], float(e[1]), 3])
	for c2: Dictionary in EnemySpawner.REALM_CAMPS:
		var cp: Vector3 = c2.at
		var q := Vector2(cp.x, cp.z)
		if RealmLayout.OLD_BOUNDS.has_point(q) or int(RealmLayout.region_at(q.x, q.y).get("tier", 2)) < 2:
			continue
		var near := false
		for o: Array in at:
			if (o[0] as Vector2).distance_to(q) < 40.0:
				near = true
		if not near:
			at.append([q, 18.0, 2])
	for e: Array in at:
		var c: Vector2 = e[0]
		var n: int = int(e[2]) + _rng.randi_range(0, 1)
		var mmi := LifeKit.group("crow", n)
		mmi.name = "Kettle"
		mmi.material_override = _kettle_material()
		var r := _rng.randf_range(8.0, 12.0)
		for k in n:
			mmi.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-3, 3))))
			var sp := _rng.randf_range(0.18, 0.3) * (1.0 if k % 2 == 0 or _rng.randf() < 0.7 else -1.0)
			mmi.multimesh.set_instance_custom_data(k, Color(r * _rng.randf_range(0.6, 1.1), sp, _rng.randf_range(1.0, 2.5), _rng.randf_range(0.0, TAU)))
		mmi.multimesh.custom_aabb = AABB(Vector3(-r * 1.6 - 4, -6, -r * 1.6 - 4), Vector3(r * 3.2 + 8, 12, r * 3.2 + 8))
		mmi.visibility_range_end = 230.0
		mmi.visibility_range_end_margin = 20.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		mmi.global_position = Vector3(c.x, RL.height_at(c.x, c.y) + float(e[1]), c.y)
		kettles.append(mmi)


# --- lights ------------------------------------------------------------------------------------------

func _light_material(kind: String) -> ShaderMaterial:
	if _marsh_mats.has(kind):
		return _marsh_mats[kind]
	var m := ShaderMaterial.new()
	m.shader = MARSH_SH
	var look: Array = LIGHT_LOOK[kind]
	m.set_shader_parameter("glow_col", look[0])
	m.set_shader_parameter("energy", look[1])
	m.set_shader_parameter("size", look[2])
	_marsh_mats[kind] = m
	return m


func _lights() -> void:
	var pools: Array[Dictionary] = Reaches.new_pools if not Reaches.new_pools.is_empty() else LifePlace.pools(true)
	for e: Array in LIGHTS:
		var rid := String(e[0])
		var kind := String(e[1])
		var want := int(e[2])
		var reg := Reaches._region(rid)
		if reg.is_empty():
			continue
		var centres: Array[Vector2] = []
		match kind:
			"marsh":
				for p: Dictionary in pools:
					var pc: Vector2 = p.center
					if int(p.n) >= 4 and String(RealmLayout.region_at(pc.x, pc.y).get("id", "")) == rid:
						centres.append(pc)
			"barrow":
				for sl: Dictionary in RealmLayout.SLOTS.get(rid, []):
					if String(sl.kind).begins_with("poi") or String(sl.kind) == "camp":
						centres.append((sl.at as Vector2) + Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12)))
				if centres.is_empty():
					centres.append(Reaches._bbox(reg).get_center())
			"wood":
				var bb := Reaches._bbox(reg)
				for k in 80:
					var q := Vector2(_rng.randf_range(bb.position.x, bb.end.x), _rng.randf_range(bb.position.y, bb.end.y))
					if Flora.cover_at(q.x, q.y) > 0.45 and RealmLayout.path_dist(q) > 8.0 and String(RealmLayout.region_at(q.x, q.y).get("id", "")) == rid:
						centres.append(q)
		var made := 0
		var placed: Array[Vector2] = []
		for c in centres:
			if made >= want:
				break
			var spaced := true
			for o in placed:
				if o.distance_to(c) < 30.0:
					spaced = false
			if not spaced:
				continue
			_light_field(c, kind)
			placed.append(c)
			made += 1


func _light_field(c: Vector2, kind: String) -> void:
	var n := _rng.randi_range(4, 7) if kind != "wood" else _rng.randi_range(5, 9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = LifeKit.mesh("firefly")
	mm.instance_count = n
	var spread := 11.0 if kind == "marsh" else 9.0
	var gy := RL.height_at(c.x, c.y)
	for k in n:
		var q := Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		var y := RL.water_y_at(c.x + q.x, c.y + q.y) if kind == "marsh" and RL.in_water(c.x + q.x, c.y + q.y) else RL.height_at(c.x + q.x, c.y + q.y)
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY, Vector3(q.x, y - gy, q.y)))
		# they hang over the reeds and the heather (the grass is knee-high: lower, they are lost in it)
		mm.set_instance_custom_data(k, Color(_rng.randf_range(1.5, 4.5), _rng.randf_range(0.05, 0.14), _rng.randf_range(1.3, 2.6) if kind != "wood" else _rng.randf_range(1.2, 3.2), _rng.randf_range(0.0, TAU)))
	mm.custom_aabb = AABB(Vector3(-spread - 6, -3, -spread - 6), Vector3(spread * 2 + 12, 8, spread * 2 + 12))
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # never moves (umbral-donts: Static MultiMeshes)
	mmi.name = "Lights_" + kind
	mmi.multimesh = mm
	mmi.material_override = _light_material(kind)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 180.0
	mmi.visibility_range_end_margin = 10.0
	mmi.add_to_group(Groups.CULL_SKIP)
	mmi.set_meta("chunked", true)
	mmi.set_meta("site_owned", true)
	add_child(mmi)
	mmi.global_position = Vector3(c.x, gy, c.y)
	fields.append(mmi)


# --- eyes --------------------------------------------------------------------------------------------

func _eyes() -> void:
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = EYES_SH
	for e: Array in EYES:
		var rid := String(e[0])
		var reg := Reaches._region(rid)
		if reg.is_empty():
			continue
		var bb := Reaches._bbox(reg)
		var made := 0
		var placed: Array[Vector2] = []
		for k in 220:
			if made >= int(e[1]):
				break
			var q := Vector2(_rng.randf_range(bb.position.x, bb.end.x), _rng.randf_range(bb.position.y, bb.end.y))
			var pd := RealmLayout.path_dist(q)
			if pd < 14.0 or pd > 34.0 or Flora.cover_at(q.x, q.y) < 0.3 or RL.in_water(q.x, q.y) or String(RealmLayout.region_at(q.x, q.y).get("id", "")) != rid:
				continue
			if not WorldLanes.site_at(q, 2.0).is_empty():
				continue
			var spaced := true
			for o in placed:
				if o.distance_to(q) < 40.0:
					spaced = false
			if not spaced:
				continue
			var n := _rng.randi_range(1, 2)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = LifeKit.mesh("firefly")
			mm.instance_count = n
			for j in n:
				var o2 := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-2.5, 2.5))
				var h := RL.height_at(q.x + o2.x, q.y + o2.y) - RL.height_at(q.x, q.y) + _rng.randf_range(0.28, 0.5)
				mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, Vector3(o2.x, h, o2.y)))
				mm.set_instance_custom_data(j, Color(_rng.randf(), _rng.randf_range(7.0, 16.0), 1.0 if _rng.randf() < 0.25 else 0.0, _rng.randf_range(0.3, 1.2)))
			mm.custom_aabb = AABB(Vector3(-5, -1, -5), Vector3(10, 3, 10))
			var mmi := MultiMeshInstance3D.new()
			mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF   # never moves (umbral-donts: Static MultiMeshes)
			mmi.name = "Eyes"
			mmi.multimesh = mm
			mmi.material_override = _eye_mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 70.0
			mmi.add_to_group(Groups.CULL_SKIP)
			mmi.set_meta("chunked", true)
			add_child(mmi)
			mmi.global_position = Vector3(q.x, RL.height_at(q.x, q.y), q.y)
			eyes.append(mmi)
			placed.append(q)
			made += 1


# --- the frame ---------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t -= dt
	if _t <= 0.0:
		_t = 0.5
		_danger()
	_howl_step(dt)


## A hollowed thing within 18 m of a pair of eyes or a field of lights puts it out (only those within 90 m of the
## camera are looked at; the director keeps the near enemies' positions).
func _danger() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var foes: Array[Vector3] = director.near_enemies() if director != null else []
	for set_i in 2:
		var arr: Array = eyes if set_i == 0 else fields
		var param := &"pair_on" if set_i == 0 else &"field_on"
		for m: MultiMeshInstance3D in arr:
			var mp := m.global_position
			if mp.distance_squared_to(cp) > 8100.0 and set_i == 0:
				continue
			if mp.distance_squared_to(cp) > 40000.0:
				continue
			var on := 1.0
			for f: Vector3 in foes:
				if f.distance_squared_to(mp) < 324.0:
					on = 0.0
					break
			if float(m.get_meta(&"on", 1.0)) != on:
				m.set_meta(&"on", on)
				m.set_instance_shader_parameter(param, on)


func _on_tide(active: bool) -> void:
	_tide = active
	var act := 0.0 if active else 1.0
	for m: ShaderMaterial in _marsh_mats.values():
		m.set_shader_parameter("activity", act)
	if _eye_mat != null:
		_eye_mat.set_shader_parameter("activity", act)
	if _kettle_mat != null:
		_kettle_mat.set_shader_parameter("activity", 0.4 if active else 1.0)


# --- howls -------------------------------------------------------------------------------------------

## Out in the wild (tier 2 and 3 ground, not a town), every minute or two: a howl far off on high ground, and an
## answer from another bearing a few seconds later (sometimes a third). Not in the tide, a boss fight or hard rain.
func _howl_step(dt: float) -> void:
	for i in range(_answer.size() - 1, -1, -1):
		var a: Array = _answer[i]
		a[0] = float(a[0]) - dt
		if float(a[0]) <= 0.0:
			_howl_at(a[1] as Vector3, float(a[2]))
			_answer.remove_at(i)
	_howl_t -= dt
	if _howl_t > 0.0:
		return
	_howl_t = _rng.randf_range(55.0, 140.0)
	if quiet or _tide or Player.boss_fight_active(get_tree()):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lp := cam.global_position
	var reg := RealmLayout.region_at(lp.x, lp.z)
	if int(reg.get("tier", 1)) < 2:
		return
	var wx: Variant = director.get("weather") if director != null else null
	if wx != null and float((wx.get("state") as Dictionary).get("rain", 0.0)) > 0.6:
		return
	call_howl(lp)


## Start a howl and its answers round `lp` now (tests, the debug menu).
func call_howl(lp: Vector3) -> void:
	var b0 := _rng.randf_range(0.0, TAU)
	var first := _high_point(lp, b0)
	_howl_at(first, _rng.randf_range(0.92, 1.04))
	var b1 := b0 + (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(1.1, 2.4)
	_answer.append([_rng.randf_range(2.8, 5.5), _high_point(lp, b1), _rng.randf_range(0.95, 1.1)])
	if _rng.randf() < 0.35:
		_answer.append([_rng.randf_range(6.5, 9.0), _high_point(lp, b0 + _rng.randf_range(-0.5, 0.5)), _rng.randf_range(0.88, 1.0)])


## The highest ground on a bearing from lp, 140-230 m out (it may be beyond the Realm's edge: the Crowns, the fells).
func _high_point(lp: Vector3, bearing: float) -> Vector3:
	var best := Vector3.ZERO
	var by := -INF
	for k in 5:
		var d := 140.0 + 22.0 * float(k)
		var a := bearing + _rng.randf_range(-0.25, 0.25)
		var x := lp.x + cos(a) * d
		var z := lp.z + sin(a) * d
		var y := RealmLayout.macro_height(x, z) if not RealmLayout.BOUNDS.has_point(Vector2(x, z)) else RL.height_at(x, z)
		if y > by:
			by = y
			best = Vector3(x, y + 4.0, z)
	return best


func _howl_at(at: Vector3, pitch: float) -> void:
	var a := _howlers[_hi]
	_hi = (_hi + 1) % _howlers.size()
	a.stream = ScapeSynth.stream("howl")
	a.global_position = at
	a.pitch_scale = pitch
	a.volume_db = _rng.randf_range(-3.0, 0.0)
	a.play()
	howls += 1


# --- census ------------------------------------------------------------------------------------------

func census() -> Dictionary:
	var out := {}
	var add := func(p: Vector3, k: String, n: int) -> void:
		var rid := String(RealmLayout.region_at(p.x, p.z).get("id", "?"))
		if not out.has(rid):
			out[rid] = {}
		(out[rid] as Dictionary)[k] = int((out[rid] as Dictionary).get(k, 0)) + n
	for c: Dictionary in carrion:
		add.call(c.at as Vector3, "carrion", 1)
	for m in kettles:
		add.call(m.global_position, "kettle_ravens", m.multimesh.instance_count)
	for m in fields:
		add.call(m.global_position, "lights", m.multimesh.instance_count)
	for m in eyes:
		add.call(m.global_position, "eyes", m.multimesh.instance_count)
	return out

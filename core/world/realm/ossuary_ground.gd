extends RefCounted
## The Ossuary's own ground (docs/far_reaches.md, "The Ossuary's own ground"). The charnel house was a pit cut
## into the Waiting Field's slope with a 14 m lane to its door; this gives it a country of its own on the surface,
## north-west of the pit, where the Order's bearers brought the dead down from the road:
##   the Lych Cross     where the Lych Way leaves the Pilgrims' Road, between its milestone and its lamp
##   the Lych Way       RealmLayout path "lych_way": coffin stones on its verge, each with a verse of the Bearers'
##                      Count, then a hollow way walled with niches of skulls and grave candles (z 96..124)
##   the lych gate      on oss_lane past south_track, its bell in the gable (it tolls when anyone passes under)
##   the Bearers' Yard  the Lantern of the Dead on a stepped base over its terrace, the bearers' table at its foot,
##                      heaps of the uncounted; the Pilgrims' Landing and the bone bridge beyond
##   the Sorting Ground on the pit's west rim: slabs, bones heaped by kind, the sorters' slate
## The Lantern burns cold (the Abbot's count-light: its own flame, a cold light, a beacon on the compass and the
## horizon) until the Bone Abbot falls; then it goes dark. Hero meshes: tools/blender/oss_ground.py
## (art/models/oss_ground.glb); skulls, bones and grave candles are the Ossuary's own (OssKit).
## Hooked by RealmPois.REACH_POIS: static reserve(root) before the stamp and the flora, build(holder) after.
## `-- --no-oss-ground` leaves it out (A/B).

const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const Data := preload("res://core/world/realm/oss_ground_data.gd")
const SKit := preload("res://core/life/secrets/kit.gd")
const GLB := "res://art/models/oss_ground.glb"
const Beacon := preload("res://core/world/realm/landmark_beacon.gd")
const Abbey := preload("res://world/areas/ossuary/oss_abbey.gd")

const LANTERN_C := Vector2(-53.0, 142.5)        ## the Lantern of the Dead (RealmLayout.SLOTS "ossuary")
const SORT_C := Vector2(-72.0, 161.0)           ## the sorting ground on the pit's west rim (its flattest ground)
const CROSS_C := Vector2(-71.6, 67.0)           ## the Lych Cross, beside the way's head
const HOLLOW := Vector2(45.5, 67.5)             ## the walled hollow way: arc length along lych_way (z ~101 .. ~123; the orchard watch's stakes stand clear of it)
const WALL_D := 2.15                            ## a niche wall's face from the way's centreline
const STONES := [14.0, 25.0, 36.0]              ## the coffin stones' arc lengths (before the hollow way; the third by the orchard watch)
const GATE_S := 74.0                            ## the lych gate on lych_way (arc length): the last of it before south_track
const COLD := Color(0.62, 0.8, 1.0)             ## the count-light
const VIS := 160.0                              ## the kit's small parts end here
const LS := 1.2                                 ## the Lantern stands at 1.2 of its modelled size (28 m: it clears the field's yews and cypresses)

static var spots := {}                          ## name -> {at: Vector3, yaw} (reserve)
static var built: Array[String] = []


static func off() -> bool:
	return "--no-oss-ground" in OS.get_cmdline_user_args()


# =================================================================================================
# reserve (before the stamp and the flora)
# =================================================================================================

static func reserve(root: Node) -> void:
	spots.clear()
	if off():
		return
	var space := (root as Node3D).get_world_3d().direct_space_state
	# the Charnel Abbey stands on the pit's south bank (oss_abbey.gd): the trees keep off it, from the tower to the gable
	var fp := Abbey.footprint(0.0)
	var az := fp.position.y
	while az <= fp.end.y + 4.0:
		Flora.tree_clear.append([OssFrame.w2(Vector2(fp.position.x + fp.size.x * 0.5, az)), 11.0])
		az += 8.0
	# the Lantern: a level round terrace at the slope's middle (cut and filled), trees kept off the yard
	var ly := _ground_med(space, LANTERN_C, 2.4)
	WorldLanes.register_terrace("poi_oss_lantern", LANTERN_C, 3.2 * LS + 0.5, ly)
	Flora.tree_clear.append([LANTERN_C, 9.0])
	var ld := Vector2(-42.0, 134.5) - LANTERN_C                     # the door looks at the way in (the lych gate, south_track)
	spots["lantern"] = {"at": Vector3(LANTERN_C.x, ly, LANTERN_C.y), "yaw": atan2(-ld.x, -ld.y)}
	# the lych gate: on the Lych Way's last stretch, short of south_track and the Pilgrims' Landing's deck, a level
	# floor under it; its front (the bell's gable, the beam's writing) looks back up the way at the bearers
	var way0 := LK.path_pts("lych_way")
	if way0.size() >= 2:
		var a := LK.along(way0, GATE_S)
		var gc: Vector2 = a[0]
		var gd: Vector2 = a[1]
		var gy := _ground_med(space, gc, 1.6)
		WorldLanes.register_terrace("poi_oss_lych_gate", gc, 3.1, gy)
		Flora.tree_clear.append([gc, 5.0])
		spots["gate"] = {"at": Vector3(gc.x, gy, gc.y), "yaw": atan2(gd.x, gd.y)}
	# the Lych Cross at the way's head
	var cy := _ground_med(space, CROSS_C, 0.8)
	WorldLanes.register_site("poi_oss_lych_cross", Rect2(CROSS_C - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), cy + 0.05, cy - 0.1)
	Flora.tree_clear.append([CROSS_C, 3.0])
	spots["cross"] = {"at": Vector3(CROSS_C.x, cy, CROSS_C.y), "yaw": PI * 0.5}
	# the coffin stones on the way's verge, alternate sides
	var way := LK.path_pts("lych_way")
	for i in STONES.size():
		var a2 := LK.along(way, float(STONES[i]))
		var t: Vector2 = a2[1]
		var side := 1.0 if i % 2 == 0 else -1.0
		var q: Vector2 = (a2[0] as Vector2) + Vector2(-t.y, t.x) * side * 3.0
		var y := _ground_med(space, q, 0.7)
		var r := Rect2(q - Vector2(1.4, 1.4), Vector2(2.8, 2.8))
		WorldLanes.register_site("poi_oss_coffin_%d" % i, r, y + 0.05, y - 0.15)
		spots["stone_%d" % i] = {"at": Vector3(q.x, y, q.y), "yaw": atan2(t.x, t.y) + PI * 0.5, "side": side}
	# the hollow way: the walls' band kept clear of trees and props
	var band: Array = []
	var s := HOLLOW.x - 1.0
	while s <= HOLLOW.y + 1.0:
		band.append(LK.along(way, s)[0])
		s += 2.0
	WorldLanes.register_lane("oss_lych_walls", band, WALL_D + 1.4)
	for q2: Vector2 in band:
		Flora.tree_clear.append([q2, WALL_D + 2.4])
	# the sorting ground: a cut pad on the west rim
	var sy := _ground_med(space, SORT_C, 2.0)
	WorldLanes.register_site("poi_oss_sorting", Rect2(SORT_C - Vector2(4.0, 5.0), Vector2(8.0, 10.0)), sy + 0.05, sy - 0.1)
	Flora.tree_clear.append([SORT_C, 7.0])
	spots["sorting"] = {"at": Vector3(SORT_C.x, sy, SORT_C.y), "yaw": PI * 0.5}
	print("REALM_POI ossuary ground reserved %s" % [spots.keys()])


static func _ground_med(space: PhysicsDirectSpaceState3D, p: Vector2, r := 1.5) -> float:
	var hs: Array[float] = []
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		hs.append(RealmLayout.ground(space, p.x + o.x, p.y + o.y))
	hs.sort()
	return hs[2]


# =================================================================================================
# build (after the flora)
# =================================================================================================

static func build(holder: Node3D) -> void:
	built.clear()
	if off() or spots.is_empty():
		return
	var t0 := Time.get_ticks_msec()
	var space := holder.get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "OssuaryGround"
	holder.add_child(host)
	var k := OssKit.new()                       # the bones, the skulls, the grave candles (the Ossuary's own)
	k.keep_lanes = false
	k.candle_lights = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 41213
	_lantern_place(host, k, rng, space)
	_gate(host, k, rng)
	_cross(host, k, rng)
	_stones(host, k, rng)
	_hollow(host, k, rng, space)
	_sorting(host, k, rng, space)
	_ground_bones(k, rng, space)
	var props := _world_node(host, "Charnel")
	props.set_meta("site", "oss_ground")
	k.commit(props, "CharnelBody")
	WorldLanes.own(props)                       # placed on purpose: the scatter cull must not thin the niches and the heaps
	_weather(props)
	_places(host)
	print("REALM_POI ossuary ground built %s in %d ms (%d skulls, %d bones, %d candles)" % [built, Time.get_ticks_msec() - t0,
		k.skull_count(), k.bone_count(), k.candle_count()])


static func _world_node(host: Node3D, n: String) -> Node3D:
	var h := Node3D.new()
	h.name = n
	host.add_child(h)
	h.global_transform = Transform3D.IDENTITY
	return h


## Out in the weather the bones are not the crypt's: greyed, dirtier, the rim of light on them gone dull.
static func _weather(props: Node3D) -> void:
	var src := OssKit.mat("bone") as StandardMaterial3D
	if src == null:
		return
	var bm := src.duplicate() as StandardMaterial3D        # one per build (no static: it would outlive the renderer)
	bm.albedo_color = Color(0.72, 0.69, 0.62)
	bm.rim = 0.12
	bm.roughness = 0.92
	for c in props.get_children():
		if c is MultiMeshInstance3D and (String(c.name).begins_with("Skulls") or String(c.name).begins_with("Bones")):
			(c as MultiMeshInstance3D).material_override = bm


static func _put(parent: Node3D, part: String, xf: Transform3D, vis := Vector2(0.0, VIS), shadow := true) -> MeshInstance3D:
	return Kit.put(parent, GLB, part, xf, vis, shadow)


static func _box_shape(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _cyl(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c


## A warm little light over a cluster of grave candles (the candles' own flames are emissive; a few of these let the
## stone round them take the light).
static func _candle_light(parent: Node3D, at: Vector3, e := 0.9, r := 4.2) -> void:
	var l := OmniLight3D.new()
	l.name = "CandleLight"
	l.light_color = Color(1.0, 0.7, 0.38)
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.5
	l.light_specular = 0.25
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 26.0
	l.distance_fade_length = 8.0
	l.set_meta(&"light_class", &"lamp")
	l.set_meta(&"base", {"e": e, "r": r, "a": 1.5})
	parent.add_child(l)
	l.global_position = at


# --- the Lantern of the Dead --------------------------------------------------------------------

static func _lantern_place(host: Node3D, k: OssKit, rng: RandomNumberGenerator, _space: PhysicsDirectSpaceState3D) -> void:
	var s: Dictionary = spots["lantern"]
	var at: Vector3 = s.at
	var b := Basis(Vector3.UP, float(s.yaw)).scaled(Vector3.ONE * LS)
	var xf := Transform3D(b, at)
	var h := _poi(host, "oss_lantern", "The Lantern of the Dead", "it burns for the count, not for you", at, 16.0)
	var lan := _world_node(h, "Lantern")
	_put(lan, "Lantern", xf, Vector2.ZERO, true)
	_put(lan, "LanternLamp", xf, Vector2.ZERO, false)
	var flame := _put(lan, "LanternFlame", xf, Vector2.ZERO, false)
	if flame:
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.82, 0.93, 1.0)
		fm.emission_enabled = true
		fm.emission = COLD
		fm.emission_energy_multiplier = 2.4
		flame.material_override = fm
		flame.name = "CountFlame"
	var lamp_y := float(Data.LANTERN.lamp_y) * LS
	var lt := OmniLight3D.new()                   # the count-light in the lantern's bays (cold, no shadows)
	lt.name = "CountLight"
	lt.light_color = COLD
	lt.light_energy = 1.8
	lt.omni_range = 7.5
	lt.omni_attenuation = 1.2
	lt.shadow_enabled = false
	lt.light_specular = 0.2
	lt.distance_fade_enabled = true
	lt.distance_fade_begin = 120.0
	lt.distance_fade_length = 30.0
	lt.set_meta(&"light_class", &"lamp")
	lt.set_meta(&"base", {"e": 1.8, "r": 7.5, "a": 1.2})
	lan.add_child(lt)
	lt.global_position = at + Vector3.UP * (lamp_y + 0.3)
	var halo := MeshInstance3D.new()             # the count-light seen through the bays from the yard (the beacon takes it from 22 m)
	halo.name = "CountHalo"
	var qm := QuadMesh.new()
	qm.size = Vector2(3.4, 3.4)
	halo.mesh = qm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.albedo_texture = Beacon._spark()
	hm.albedo_color = Color(COLD.r, COLD.g, COLD.b, 0.8)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lan.add_child(halo)
	halo.global_position = at + Vector3.UP * (lamp_y + 0.35)
	# collision: the steps, the base, the shaft
	var col := []
	var st_h := float(Data.LANTERN.step_h) * LS
	for i in 3:
		col.append([_cyl((3.1 - 0.5 * float(i)) * LS, st_h + 0.7), Transform3D(Basis.IDENTITY, at + Vector3.UP * (st_h * float(i + 1) - (st_h + 0.7) * 0.5))])
	col.append([_cyl(1.62 * LS, 2.4 * LS), Transform3D(Basis.IDENTITY, at + Vector3.UP * ((1.02 + 1.2) * LS))])
	col.append([_cyl(0.98 * LS, 12.4 * LS), Transform3D(Basis.IDENTITY, at + Vector3.UP * (9.4 * LS))])
	col.append([_cyl(1.25 * LS, 7.0 * LS), Transform3D(Basis.IDENTITY, at + Vector3.UP * (18.8 * LS))])
	Kit.body(lan, "LanternBody", col)
	# its far read: the silhouette from 110 m, and the count-light on the horizon and the compass
	var far := Kit.mesh(GLB, "LanternFar")
	if far:
		FarDetail.register(lan, far, xf, 110.0)
	var wf: Variant = load("res://core/world/realm/realm_wayfinding.gd")
	var bn: Variant = wf.beacon(host, at, "bone_abbot", COLD, 0.0, 0.3, lamp_y + 0.2, true, 0.0)
	if bn is Node:
		(bn as Node).name = "Beacon_oss_lantern"
		(bn as Node).set("strength", 0.85)
		(bn as Node).set_meta("poi", "oss_lantern")
	if Travel.bosses_slain.has("bone_abbot"):
		_douse(lan, false)
	else:
		Events.boss_slain.connect(func(id: String) -> void:
			if id == "bone_abbot" and is_instance_valid(lan):
				_douse(lan, true))
	# the bearers' table at the foot, facing the gate; candles on it and on the steps
	var tb := Basis(Vector3.UP, float(s.yaw))
	var tq := at + tb * Vector3(0.0, 0.0, -(float(Data.LANTERN.base_r) * LS + 1.1))
	var ty := RealmLayout.ground(_space, tq.x, tq.z)
	var txf := Transform3D(tb, Vector3(tq.x, ty, tq.z))
	_put(h, "LanternTable", txf, Vector2(0.0, 120.0))
	Kit.body(h, "TableBody", [[_box_shape(Vector3(2.1, 1.0, 0.95)), txf * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0))]])
	k.candle_cluster(txf * Vector3(0.55, 1.0, 0.1), 5, 0.22, rng)
	k.candle_cluster(txf * Vector3(-0.6, 1.0, -0.15), 3, 0.15, rng)
	k.skull(txf * Vector3(0.0, 1.0, 0.0), float(s.yaw) + PI, 1.0, 0)
	P._lore(h, "oss_g_table", txf * Vector3(0.0, 1.05, -0.2), txf * Vector3(0.0, 1.0, 0.0))
	_candle_light(h, txf * Vector3(0.0, 1.5, -0.4), 0.8, 4.0)
	for i in 7:
		var a := float(s.yaw) + PI + (float(i) - 3.0) * 0.32
		var r := (2.75 - 0.5 * float(i % 2)) * LS
		var y := st_h * (1.0 if i % 2 == 0 else 2.0)
		k.candle_cluster(at + Vector3(sin(a) * r, y, cos(a) * r), 2 + i % 3, 0.12, rng)
	# the plaque over the keeper's door
	var door: Array = Data.LANTERN.door
	P._lore(h, "oss_g_lantern", xf * Vector3(0.0, float(door[1]) + 0.9, float(door[2]) - 0.9), xf * Vector3(0.0, float(door[1]) + 1.9, float(door[2]) - 0.05))
	# the uncounted, heaped against the base on its sides and at its back (the door and the table kept clear)
	var hb := Basis(Vector3.UP, float(s.yaw))
	for i in 3:
		var th: float = [1.75, -1.75, PI][i]
		var c := at + hb * (Vector3(sin(th), 0.0, -cos(th)) * (3.2 * LS + 1.4))
		c.y = RealmLayout.ground(_space, c.x, c.z)
		_heap(k, rng, c, 1.1 + 0.25 * float(i % 2), 0.75)
	built.append("lantern")


## The count stops: the flame goes out, the cold light with it (the beacon goes on its own).
static func _douse(lan: Node3D, animate: bool) -> void:
	var fl := lan.find_child("CountFlame", true, false) as Node3D
	var lt := lan.find_child("CountLight", true, false) as OmniLight3D
	var ha := lan.find_child("CountHalo", true, false) as Node3D
	if not animate:
		for n: Node3D in [fl, lt, ha]:
			if n:
				n.visible = false
		return
	if ha:
		ha.visible = false
	var tw := lan.create_tween().set_parallel(true)
	if fl:
		tw.tween_property(fl, "scale", Vector3(0.6, 0.02, 0.6), 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if lt:
		tw.tween_property(lt, "light_energy", 0.0, 2.4)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(fl):
			fl.visible = false
		if is_instance_valid(lt):
			lt.visible = false)


# --- the lych gate ------------------------------------------------------------------------------

static func _gate(host: Node3D, k: OssKit, rng: RandomNumberGenerator) -> void:
	if not spots.has("gate"):
		return
	var s: Dictionary = spots["gate"]
	var at: Vector3 = s.at
	var b := Basis(Vector3.UP, float(s.yaw))
	var xf := Transform3D(b, at)
	var g: Dictionary = Data.GATE
	var h := _world_node(host, "LychGate")
	h.set_meta("site", "poi_oss_lych_gate")
	_put(h, "LychGate", xf, Vector2(0.0, 150.0))
	_put(h, "LychBell", xf, Vector2(0.0, 90.0), false)
	var wx := float(g.wall_x)
	var wh := float(g.wall_h)
	var gl := float(g.l)
	var col := []
	for sx: float in [-1.0, 1.0]:
		col.append([_box_shape(Vector3(0.62, wh + 0.5, gl + 0.12)), xf * Transform3D(Basis.IDENTITY, Vector3(sx * wx, (wh - 0.45) * 0.5, 0.0))])
		for z: float in [-gl * 0.5 + 0.22, 0.0, gl * 0.5 - 0.22]:
			col.append([_box_shape(Vector3(0.22, 1.9, 0.22)), xf * Transform3D(Basis.IDENTITY, Vector3(sx * wx, wh + 1.05, z))])
	# the roof: a slab the wanderer can stand on, not fall through
	col.append([_box_shape(Vector3(2.0 * float(g.eave), 0.3, 2.0 * float(g.overhang))), xf * Transform3D(Basis.IDENTITY, Vector3(0.0, float(g.top) + 0.35, 0.0))])
	Kit.body(h, "GateBody", col)
	# grave candles along the coping, a skull with a stub on it
	for sx: float in [-1.0, 1.0]:
		for z: float in [-1.3, 0.4, 1.5]:
			if rng.randf() < 0.75:
				k.candle_cluster(xf * Vector3(sx * wx, wh + 0.11, z), 2 + rng.randi() % 3, 0.14, rng)
	k.skull(xf * Vector3(-wx, wh + 0.11, -0.5), float(s.yaw) + PI * 0.5, 1.0, 1)
	k.candle_cluster(xf * Vector3(-wx, wh + 0.31, -0.5), 1, 0.01, rng)
	P._lore(h, "oss_g_gate", xf * Vector3(0.0, 1.5, -float(g.l) * 0.5 - 0.6), xf * Vector3(0.0, float(g.top), -float(g.l) * 0.5 + 0.1))
	_candle_light(h, xf * Vector3(0.0, 1.9, 0.0), 0.9, 4.6)
	# the bell tolls when anyone passes under (once a minute at most)
	var area := Area3D.new()
	area.name = "UnderTheBell"
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	cs.shape = _box_shape(Vector3(float(g.w) - 0.2, 2.4, 1.2))
	area.add_child(cs)
	h.add_child(area)
	area.global_transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2, 0.0))
	var last := [-100.0]
	var bell_at := xf * Vector3(0.0, float(g.top) + 0.95, -gl * 0.5 + 0.22)
	area.body_entered.connect(func(body: Node3D) -> void:
		if not body.is_in_group(Groups.PLAYER):
			return
		var now := Time.get_ticks_msec() * 0.001
		if now - float(last[0]) < 60.0:
			return
		last[0] = now
		SKit.play("bell_treble", bell_at, -9.0, 0.82))
	built.append("gate")


# --- the Lych Cross, the coffin stones ------------------------------------------------------------

static func _cross(host: Node3D, k: OssKit, rng: RandomNumberGenerator) -> void:
	var s: Dictionary = spots["cross"]
	var at: Vector3 = s.at
	var xf := Transform3D(Basis(Vector3.UP, float(s.yaw)), at)
	var h := _world_node(host, "LychCross")
	h.set_meta("site", "poi_oss_lych_cross")
	_put(h, "LychCross", xf, Vector2(0.0, 130.0))
	Kit.body(h, "CrossBody", [[_box_shape(Vector3(1.6, 0.9, 1.6)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0))],
		[_box_shape(Vector3(0.32, 3.6, 0.32)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 2.4, 0))]])
	k.candle_cluster(xf * Vector3(0.38, 0.76, -0.1), 3, 0.12, rng)
	k.candle_cluster(xf * Vector3(-0.45, 0.46, 0.4), 2, 0.1, rng)
	P._lore(h, "oss_g_cross", xf * Vector3(0.0, 1.0, -1.1), xf * Vector3(0.0, 1.6, -0.17))
	built.append("cross")


static func _stones(host: Node3D, k: OssKit, rng: RandomNumberGenerator) -> void:
	var h := _world_node(host, "CoffinStones")
	for i in STONES.size():
		var s: Dictionary = spots["stone_%d" % i]
		var at: Vector3 = s.at
		var xf := Transform3D(Basis(Vector3.UP, float(s.yaw)), at + Vector3.UP * 0.05)
		_put(h, "CoffinStone" if i != 1 else "CoffinStoneB", xf, Vector2(0.0, 120.0))
		Kit.body(h, "StoneBody_%d" % i, [[_box_shape(Vector3(2.3, 0.75, 0.9)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0))]])
		k.candle_cluster(xf * Vector3(0.65, 0.27, 0.05), 3 + i, 0.16, rng)
		if i == 2:
			k.skull(xf * Vector3(-0.5, 0.27, 0.0), float(s.yaw) - PI * 0.5, 1.0, 0)
		var side := float(s.side)
		P._lore(h, "oss_g_stone_%d" % (i + 1), xf * Vector3(0.0, 0.6, side * 0.9), xf * Vector3(0.0, 0.3, 0.0))
	# a bearer's grave across the way from the third stone, the stone over him turned face up
	var way := LK.path_pts("lych_way")
	var a3 := LK.along(way, float(STONES[2]))
	var t3: Vector2 = a3[1]
	var wq: Vector2 = a3[0]
	var s3: Dictionary = spots["stone_2"]
	var gq := wq + Vector2(-t3.y, t3.x) * (-float(s3.side)) * 3.4 + t3 * 1.2
	var g3 := Vector3(gq.x, 0.0, gq.y)
	var to := wq - gq
	var lk: Variant = LK.begin(host, "BearerGrave", 991)
	var sp: PhysicsDirectSpaceState3D = lk.space
	var face: Vector3 = lk.headstone(Vector3(g3.x, RealmLayout.ground(sp, g3.x, g3.z), g3.z), atan2(-to.x, -to.y), 1, 0.85, Vector2(0.12, 0.05), "lore_tstone", true)
	lk.scrap("oss_g_grave", face + Vector3(to.x, 0.0, to.y).normalized() * 0.6)
	lk.finish()
	built.append("stones")


# --- the hollow way ------------------------------------------------------------------------------

## The walled stretch of the Lych Way: niche walls on both sides (tall in the middle, low at the mouths), a pier at
## every joint, skulls stacked in the niches, a few grave candles, a bearer's page in one.
static func _hollow(host: Node3D, k: OssKit, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> void:
	var way := LK.path_pts("lych_way")
	if way.size() < 2:
		return
	var h := _world_node(host, "HollowWay")
	h.set_meta("site", "oss_lych_walls")
	var nw: Dictionary = Data.NICHE_WALL
	var seg := float(nw.l)
	var pier := 0.92
	var col := []
	var lit: Array[Vector3] = []                  # niches with candles (a few of them get a light)
	var page_done := false
	for side: float in [-1.0, 1.0]:
		var s := HOLLOW.x
		var idx := 0
		while s + seg <= HOLLOW.y + 0.01:
			var mid := s + seg * 0.5
			var a := LK.along(way, mid)
			var t: Vector2 = a[1]
			var n := Vector2(-t.y, t.x) * side
			var q: Vector2 = (a[0] as Vector2) + n * (WALL_D + float(nw.t) * 0.5)
			# the wall's own frame: x along the way, its face (-z) to the lane
			var zax := Vector3(n.x, 0.0, n.y)
			var xax := Vector3(t.x, 0.0, t.y) * side
			var bas := Basis(xax, Vector3.UP, zax)
			var y := _wall_y(space, q, t)
			var xf := Transform3D(bas, Vector3(q.x, y, q.y))
			var low := s < HOLLOW.x + seg * 0.9 or s + seg > HOLLOW.y - seg * 0.9
			var part := "NicheWallLow" if low else "NicheWall"
			_put(h, part, xf, Vector2(0.0, 110.0))
			var wh := float(nw.h_low) if low else float(nw.h)
			col.append([_box_shape(Vector3(seg, wh + 0.5, float(nw.t))), xf * Transform3D(Basis.IDENTITY, Vector3(0, wh * 0.5 - 0.25, 0))])
			var cells: Array = Data.NICHE_CELLS_LOW if low else Data.NICHE_CELLS
			for ci in cells.size():
				var c: Array = cells[ci]
				var floor_p := xf * Vector3(float(c[0]), float(c[1]), float(c[2]) - 0.1)       # forward, where the light reaches
				var into := -zax
				var yaw := atan2(into.x, into.z)
				var roll := rng.randf()
				if not page_done and side > 0.0 and idx == 3 and ci == 2:
					page_done = true
					P._lore(h, "oss_g_niche", floor_p + into * 0.9 + Vector3.UP * 0.2, floor_p + Vector3.UP * 0.15)
					k.candle_cluster(floor_p + xax * 0.18, 2, 0.06, rng)
					continue
				if roll < 0.7:
					# two or three skulls side by side, a third laid on them
					var nsk := 2 + rng.randi() % 2
					for j in nsk:
						var o := xax * ((float(j) - (float(nsk) - 1.0) * 0.5) * 0.19)
						k.skull(floor_p + o + into * rng.randf_range(-0.04, 0.04), yaw + PI + rng.randf_range(-0.3, 0.3), rng.randf_range(0.95, 1.1), 1)
					if rng.randf() < 0.45:
						k.skull(floor_p + Vector3.UP * 0.17 + xax * rng.randf_range(-0.08, 0.08), yaw + PI + rng.randf_range(-0.5, 0.5), 1.0, 1)
				else:
					# long bones laid lengthwise, a skull at their end
					for j in 4:
						var bb := Basis(Vector3.UP, atan2(xax.x, xax.z)) * Basis(Vector3.RIGHT, 0.0)
						k.bone(floor_p + Vector3.UP * (0.03 + 0.04 * float(j % 2)) + zax * (-0.05 + 0.05 * float(j)), bb, 0, false)
					k.skull(floor_p + xax * 0.2 + Vector3.UP * 0.08, yaw + PI, 1.0, 1)
				if rng.randf() < 0.55:
					k.candle_cluster(floor_p - zax * 0.1 + xax * (0.22 if rng.randf() < 0.5 else -0.22), 1 + rng.randi() % 2, 0.04, rng)
					lit.append(floor_p)
			# the pier after this section
			if s + seg + pier <= HOLLOW.y + 0.01:
				var pa := LK.along(way, s + seg + pier * 0.5)
				var pt: Vector2 = pa[1]
				var pn := Vector2(-pt.y, pt.x) * side
				var pq: Vector2 = (pa[0] as Vector2) + pn * (WALL_D + 0.36)
				var py := RealmLayout.ground(space, pq.x, pq.y)
				var pxf := Transform3D(Basis(Vector3.UP, atan2(pt.x, pt.y)), Vector3(pq.x, py, pq.y))
				_put(h, "NichePier", pxf, Vector2(0.0, 110.0))
				col.append([_box_shape(Vector3(0.92, 3.3, 0.92)), pxf * Transform3D(Basis.IDENTITY, Vector3(0, 1.15, 0))])
				if rng.randf() < 0.5:
					k.candle_cluster(pxf * Vector3(0.0, 3.0, 0.0), 2, 0.1, rng)
			s += seg + pier
			idx += 1
	Kit.body(h, "HollowBody", col)
	# a few of the candle-lit niches light the stone round them (and the skulls in them): one every ~7 m, alternate sides
	var kept: Array[Vector3] = []
	for q3: Vector3 in lit:
		var near := false
		for o3: Vector3 in kept:
			if o3.distance_to(q3) < 6.5:
				near = true
				break
		if not near and kept.size() < 4:
			kept.append(q3)
			_candle_light(h, q3 + Vector3.UP * 0.35, 0.65, 3.6)
	built.append("hollow")


## A wall's footing: the lower of the ground under its two ends at the face (the foot goes 0.5 m under).
static func _wall_y(space: PhysicsDirectSpaceState3D, q: Vector2, t: Vector2) -> float:
	var a := RealmLayout.ground(space, q.x - t.x * 1.8, q.y - t.y * 1.8)
	var b := RealmLayout.ground(space, q.x + t.x * 1.8, q.y + t.y * 1.8)
	var c := RealmLayout.ground(space, q.x, q.y)
	return minf(minf(a, b), c) + 0.02


# --- the sorting ground, the heaps, the scatter ------------------------------------------------------

static func _sorting(host: Node3D, k: OssKit, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> void:
	var s: Dictionary = spots["sorting"]
	var at: Vector3 = s.at
	var b := Basis(Vector3.UP, float(s.yaw))
	var h := _poi(host, "oss_sorting", "The Sorting Ground", "skulls to the gallery, long bones to the piers", at, 9.0)
	# two slabs the sorters worked at, the heaps sorted by kind beside them
	for i in 2:
		var q := at + b * Vector3(-1.4 + 2.8 * float(i), 0.0, 0.6)
		q.y = RealmLayout.ground(space, q.x, q.z)
		var xf := Transform3D(b * Basis(Vector3.UP, 0.12 * float(i)), q + Vector3.UP * 0.05)
		_put(h, "CoffinStoneB" if i == 0 else "CoffinStone", xf, Vector2(0.0, 110.0))
		Kit.body(h, "SlabBody_%d" % i, [[_box_shape(Vector3(2.3, 0.75, 0.9)), xf]])
		for j in 4:
			k.bone(xf * Vector3(-0.6 + 0.35 * float(j), 0.29, 0.1 * float(j % 2)), Basis(Vector3.UP, float(s.yaw) + rng.randf_range(-0.2, 0.2)), j % 3, false)
		k.skull(xf * Vector3(0.7, 0.27, 0.0), float(s.yaw) + rng.randf_range(-1.0, 1.0), 1.0, 0)
		k.candle_cluster(xf * Vector3(0.95, 0.27, -0.2), 2, 0.1, rng)
	var c1 := at + b * Vector3(-3.0, 0.0, -2.6)
	c1.y = RealmLayout.ground(space, c1.x, c1.z)
	_heap(k, rng, c1, 1.2, 0.85, 1.0)          # skulls
	var c2 := at + b * Vector3(2.8, 0.0, -2.8)
	c2.y = RealmLayout.ground(space, c2.x, c2.z)
	_heap(k, rng, c2, 1.25, 0.6, 0.0)          # long bones
	P._lore(h, "oss_g_sorting", at + b * Vector3(1.4, 0.75, 1.5), at + b * Vector3(1.4, 0.35, 0.6))
	P._lore(h, "oss_g_rule", at + b * Vector3(-1.4, 0.75, 1.5), at + b * Vector3(-1.4, 0.35, 0.6))
	_candle_light(h, at + Vector3.UP * 1.4, 0.7, 4.5)
	built.append("sorting")


## A heap of the uncounted at `c` (its ground point): skulls and long bones in a low dome. `skulls` is the share of
## skulls (the rest are long bones).
static func _heap(k: OssKit, rng: RandomNumberGenerator, c: Vector3, r: float, h: float, skulls := 0.55) -> void:
	var n := int(70.0 * r * r)
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r
		var top := h * (1.0 - (d / r) * (d / r))
		var y := top * rng.randf_range(0.55, 1.0)
		var p := c + Vector3(cos(a) * d, y, sin(a) * d)
		if rng.randf() < skulls:
			k.skull(p, rng.randf() * TAU, rng.randf_range(0.9, 1.1), rng.randi() % 2, rng.randf_range(-0.6, 0.6))
		else:
			var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5))
			k.bone(p, bb, 0 if rng.randf() < 0.7 else 2, false)
	k.collider(c + Vector3.UP * h * 0.3, Vector3(r * 1.5, h * 0.6, r * 1.5))
	if rng.randf() < 0.7:
		k.candle_cluster(c + Vector3(0.0, h + 0.02, 0.0), 2 + rng.randi() % 2, 0.1, rng)


## Bones in the turf: thin along the open way, thicker in the hollow and the yard, never on the walk itself.
static func _ground_bones(k: OssKit, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> void:
	var way := LK.path_pts("lych_way")
	var total := 0.0
	for i in way.size() - 1:
		total += (way[i] as Vector2).distance_to(way[i + 1])
	var s := 4.0
	while s < total:
		var a := LK.along(way, s)
		var t: Vector2 = a[1]
		var dense := 1.0 if s > HOLLOW.x - 4.0 else 0.35
		for side: float in [-1.0, 1.0]:
			if rng.randf() > 0.55 * dense:
				continue
			var off := rng.randf_range(1.5, 1.95) if (s > HOLLOW.x and s < HOLLOW.y) else rng.randf_range(1.7, 4.5)
			var q: Vector2 = (a[0] as Vector2) + Vector2(-t.y, t.x) * side * off + t * rng.randf_range(-0.8, 0.8)
			_turf_bone(k, rng, space, q)
		s += 1.4
	# the yard round the lantern
	for i in 60:
		var a2 := rng.randf() * TAU
		var d := rng.randf_range(3.9, 9.0)
		var q := LANTERN_C + Vector2(cos(a2), sin(a2)) * d
		if RealmLayout.path_dist(q) < 1.0:
			continue
		_turf_bone(k, rng, space, q)


static func _turf_bone(k: OssKit, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, q: Vector2) -> void:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, 60.0, q.y), Vector3(q.x, -40.0, q.y), 1))
	if hit.is_empty() or not String((hit.collider as Node).name).begins_with("Terrain"):
		return
	var p: Vector3 = hit.position
	var nrm: Vector3 = hit.normal
	if nrm.y < 0.8:
		return
	if rng.randf() < 0.3:
		k.skull(p + Vector3.UP * 0.05, rng.randf() * TAU, rng.randf_range(0.9, 1.05), 1, rng.randf_range(-0.4, 0.4))
	else:
		var bb := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
		k.bone(p + Vector3.UP * 0.02, bb, rng.randi() % 3, false)


# --- places (the discovery's named spots) --------------------------------------------------------------

static func _poi(parent: Node3D, id: String, title: String, line: String, at: Vector3, radius: float) -> Node3D:
	var h := _world_node(parent, "Poi_" + id)
	h.set_meta("site", "poi_" + id)
	h.add_to_group(P.GROUP_POI)
	h.set_meta("poi", id)
	h.set_meta("title", title)
	h.set_meta("line", line)
	h.set_meta("region", "ossuary")
	h.set_meta("centre", at)
	h.set_meta("radius", radius)
	h.set_meta("approach", at + Vector3(10.0, 0.0, -14.0))
	h.set_meta("r37", true)                    # not one of the four valley places world_poi_test counts
	return h


## The Lych Way and the yard as named spots (the lantern and the sorting ground are their own, above).
static func _places(host: Node3D) -> void:
	var way := LK.path_pts("lych_way")
	if way.size() < 2:
		return
	var a := LK.along(way, (HOLLOW.x + HOLLOW.y) * 0.5)
	var q: Vector2 = a[0]
	_poi(host, "oss_lych_way", "The Lych Way", "the bearers' road to the count", Vector3(q.x, 0.0, q.y), 20.0)
	if spots.has("gate"):
		_poi(host, "oss_lych_gate", "The Lych Gate", "it tolls for whoever passes under", spots["gate"].at, 6.0)

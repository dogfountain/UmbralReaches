extends RefCounted
## THE CHARNEL ABBEY (the redesign, Luke 21 Nov: "the ossuary makes no sense and has no presence"). The Order of the Count's
## church stands on the quarry's south bank, behind its lip, and is the Ossuary's skyline: a buttressed north wall of
## eight bays with two tiers of lit lancets, a slate roof, a gable end with the great rose and the charnel door, stair
## turrets, and the bell tower (46 m: belfry, lantern and spire, every pane lit). It reads from the field, the roads and
## the downs at night as the one great lit building in the south; the tiers (ossuary.gd) hang below it in the pit, and its
## buttresses and its tally (over the Counting Door's bay) belong to the same work.
##
## Hero meshes: tools/blender/oss_abbey.py -> art/models/oss_abbey.glb (+ core/world/realm/oss_abbey_data.gd). Built in the
## Ossuary's own (local) coordinates, as a child of the Ossuary (its frame turns it into the world), once the Realm's ground
## is in: each pair of bays stands on the slope at its own height (the church steps down the bank to the east), on a stone
## foundation to the ground. Static: one MultiMesh per module, off physics interpolation, in CULL_SKIP (a landmark never
## ends); collision is boxes (the church is a closed shell: no door opens on the bank).
##
##   x (local)   the front face stands at FRONT_X (the downs_track runs 5.5 m in front of it: 41 local); the back wall at +DEPTH
##   z (local)   the tower at the north end (z -35), eight bays south-east to the gable at z -91 (world: tower west, gable east)

const Data := preload("res://core/world/realm/oss_abbey_data.gd")
const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const RealmLand := preload("res://core/world/realm/realm_land.gd")
const GLB := "res://art/models/oss_abbey.glb"

const FRONT_X := 46.5                         ## the north wall's front face (local x)
const TOWER_Z := -35.0
const BAY_N := 8
const Z_N := -39.8                            ## where the bays begin (the tower's south face)
const TALLY_BAY := 6                          ## the bay over the Counting Door: its lancet bricked, the Count's tally cut in it
const FOUNDATION := 7.0                       ## how far the stone foundation goes under a module's base

static var built := false
static var base_y := PackedFloat32Array()     ## per bay: its base (local y)
static var tower_base := 0.0
static var tower_top := 0.0                    ## local y of the spire's tip
static var rects: Array[Rect2] = []            ## the church's footprint in local xz (tests, keep-outs)


## Local xz the church fills (north wall front to back face, tower to gable), grown by `pad`.
static func footprint(pad := 0.0) -> Rect2:
	var z_s := Z_N - float(BAY_N) * float(Data.BAY.w) - 0.2
	return Rect2(FRONT_X - 3.0 - pad, z_s - pad, 3.0 + float(Data.BAY.depth) + 2.0 * pad, (TOWER_Z + 5.2) - z_s + 2.0 * pad)


static func part(nm: String) -> ArrayMesh:
	return Kit.parts(GLB).get(nm) as ArrayMesh


## The Order's pier (oss_abbey.py OssPier*): a footing at `base`, a shaft of 4 m lengths (the last stretched to fit) and a
## capital whose top is at `top`, `w` wide (modelled 2 m). Appended to the kit's stone, so it takes the tiers' own material.
static func pier(k: OssKit, base: Vector3, top: float, w: float) -> void:
	var foot := part("OssPierFoot")
	var shaft := part("OssPierShaft")
	var cap := part("OssPierCap")
	if foot == null or shaft == null or cap == null:
		return
	var s := w / float(Data.PIER.w)
	var fh: float = Data.PIER.foot
	var ch: float = Data.PIER.cap
	var y0 := base.y
	var len := top - ch - (y0 + fh)
	if len < 0.5:
		return
	var seg: float = Data.PIER.seg
	var n := maxi(1, ceili(len / seg - 0.05))
	var sy := len / (float(n) * seg)
	k.append_mesh("stone", foot, Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), Vector3(base.x, y0, base.z)))
	for i in n:
		k.append_mesh("stone", shaft, Transform3D(Basis.from_scale(Vector3(s, sy, s)), Vector3(base.x, y0 + fh + float(i) * seg * sy, base.z)))
	k.append_mesh("stone", cap, Transform3D(Basis.from_scale(Vector3(s, 1.0, s)), Vector3(base.x, top - ch, base.z)))


## The terrain's own height (local y) under local (x, z): a ray down through every collider that is not the terrain (a prop, a
## tree's trunk, a roof) to the Terrain body; RealmLayout.ground falls back to the macro shape there, which was 10 m under the bank.
static func _gy(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var wp := OssFrame.w(Vector3(x, 0.0, z))
	var q := PhysicsRayQueryParameters3D.create(Vector3(wp.x + 0.0037, 220.0, wp.z + 0.0029), Vector3(wp.x + 0.0037, -120.0, wp.z + 0.0029), Layers.WORLD | Layers.PROPS)
	var skip: Array[RID] = []
	var seen: PackedStringArray = []
	for i in 60:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y - OssFrame.ORIGIN.y
		seen.append(String((hit.collider as Node).name))
		skip.append(hit.rid)
	print("OSSUARY abbey: no terrain under (%.1f, %.1f); passed %s" % [x, z, seen.slice(0, 6)])
	return RealmLand.height_at(wp.x, wp.z) - OssFrame.ORIGIN.y


## The terrain's height (local y) under the church's middle by a ray down to the Terrain body, NAN until that is in. The ground
## there moves after the Realm is done (the stamps, the settle), so the caller waits for it to hold still.
static func ground_probe(space: PhysicsDirectSpaceState3D) -> float:
	var wp := OssFrame.w(Vector3(FRONT_X + 1.0, 0.0, Z_N - 20.0))
	var q := PhysicsRayQueryParameters3D.create(Vector3(wp.x, 220.0, wp.z), Vector3(wp.x, -120.0, wp.z), Layers.WORLD | Layers.PROPS)
	var skip: Array[RID] = []
	for i in 10:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return NAN
		if String((hit.collider as Node).name).begins_with("Terrain"):
			return (hit.position as Vector3).y
		skip.append(hit.rid)
	return NAN


## Build the abbey under `area` (the Ossuary). The Realm's ground must be in (the caller waits for it).
static func build(area: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	if built and is_instance_valid(area.get_node_or_null("Abbey")):
		return
	var t0 := Time.get_ticks_msec()
	var bw: float = Data.BAY.w
	var T: float = Data.BAY.t
	var wall_h: float = Data.BAY.wall_h
	var depth: float = Data.BAY.depth
	var parts := Kit.parts(GLB)
	if parts.is_empty():
		push_warning("OssAbbey: %s is not imported" % GLB)
		return
	var host := Node3D.new()
	host.name = "Abbey"
	host.set_meta("site", "oss_abbey")
	area.add_child(host)
	# the ground the bays stand on: a base per pair of bays (the church steps down the bank), never rising to the south
	base_y.resize(BAY_N)
	var prev := INF
	for g in range(BAY_N >> 1):
		var s := 0.0
		for j in 2:
			var zc := Z_N - bw * (float(g * 2 + j) + 0.5)
			s += (_gy(space, FRONT_X + 0.5, zc) + _gy(space, FRONT_X + 0.5, zc - 2.4) + _gy(space, FRONT_X + 0.5, zc + 2.4)) / 6.0
		var b := snappedf(s / 2.0 - 0.5, 0.5)
		b = minf(b, prev)
		prev = b
		for j in 2:
			base_y[g * 2 + j] = b
	tower_base = snappedf(_gy(space, FRONT_X + depth * 0.5, TOWER_Z) - 0.5, 0.5)
	tower_base = maxf(tower_base, base_y[0])
	base_y[0] = tower_base                    # the tower and the first pair stand level (the tower's plinth runs along them)
	base_y[1] = tower_base
	var bases: PackedFloat32Array = base_y
	var xf_bay := func(i: int, back: bool) -> Transform3D:
		var zc := Z_N - bw * (float(i) + 0.5)
		if back:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(FRONT_X + depth - T * 0.5, bases[i], zc))
		return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(FRONT_X + T * 0.5, bases[i], zc))
	var lists := {"AbbeyBay": [], "AbbeyBayBlind": [], "AbbeyButtress": [], "AbbeyRoof": [], "AbbeyGable": [], "AbbeyTurret": [], "AbbeyTower": []}
	for i in BAY_N:
		(lists["AbbeyBayBlind" if i == TALLY_BAY else "AbbeyBay"] as Array).append(xf_bay.call(i, false))
		(lists["AbbeyBayBlind"] as Array).append(xf_bay.call(i, true))        # the back wall: blind, the bank's side
		var rt: Transform3D = xf_bay.call(i, false)
		rt.origin.y += wall_h
		(lists["AbbeyRoof"] as Array).append(rt)
	for i in range(1, BAY_N):                                            # buttresses at the seams between bays
		var zs := Z_N - bw * float(i)
		var by := maxf(base_y[i], base_y[i - 1])
		(lists["AbbeyButtress"] as Array).append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(FRONT_X + T * 0.5, by, zs)))
	var z_end := Z_N - bw * float(BAY_N)
	var last := base_y[BAY_N - 1]
	(lists["AbbeyGable"] as Array).append(Transform3D(Basis.IDENTITY, Vector3(FRONT_X + depth * 0.5, last, z_end + T * 0.5)))
	for cx: float in [FRONT_X - 0.9, FRONT_X + depth + 0.9]:                 # the stair turrets at the gable's corners
		(lists["AbbeyTurret"] as Array).append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, last, z_end + 1.2)))
	(lists["AbbeyTower"] as Array).append(Transform3D(Basis.IDENTITY, Vector3(FRONT_X + depth * 0.5, tower_base, TOWER_Z)))
	tower_top = tower_base + float(Data.TOWER.top)
	var draws := 0
	for nm: String in lists:
		var xfs: Array = lists[nm]
		var mesh: Mesh = parts.get(nm)
		if mesh == null or xfs.is_empty():
			continue
		draws += _multimesh(host, nm, mesh, xfs)
	# stone foundations under the modules (the terrain hides all but where the slope falls away), and the collision
	var shapes: Array = []
	var fk := OssKit.new()
	fk.keep_lanes = false
	fk.candle_lights = false
	var i0 := 0
	while i0 < BAY_N:
		var i1 := i0
		while i1 + 1 < BAY_N and is_equal_approx(base_y[i1 + 1], base_y[i0]):
			i1 += 1
		var z_a := Z_N - bw * float(i0)
		var z_b := Z_N - bw * float(i1 + 1)
		var by: float = base_y[i0]
		fk.block("stone_big", Vector3(FRONT_X - 1.0, by - FOUNDATION, z_b - 0.3), Vector3(FRONT_X + depth + 0.3, by + 0.05, z_a + 0.3), false, 0.8)
		# front and back walls
		shapes.append([Vector3(FRONT_X - 0.1, by - 2.0, z_b), Vector3(FRONT_X + T + 0.1, by + wall_h, z_a)])
		shapes.append([Vector3(FRONT_X + depth - T - 0.1, by - 2.0, z_b), Vector3(FRONT_X + depth + 0.1, by + wall_h, z_a)])
		shapes.append([Vector3(FRONT_X, by + wall_h, z_b), Vector3(FRONT_X + depth, by + wall_h + 1.4, z_a)])        # the merlons: a lid keeps the walkers' eyes honest
		# a firewall where the next group steps down: the lower roof abuts it
		if i1 + 1 < BAY_N:
			var dy: float = base_y[i0] - base_y[i1 + 1]
			if dy > 0.01:
				fk.block("stone", Vector3(FRONT_X + 0.2, base_y[i1 + 1] + wall_h - 0.3, z_b - 0.5), Vector3(FRONT_X + depth - 0.2, by + wall_h + float(Data.BAY.ridge) + 0.2, z_b + 0.5), false, 0.9)
		i0 = i1 + 1
	# buttresses (collision) and the gable, the tower, the turrets
	for xf: Transform3D in lists["AbbeyButtress"]:
		shapes.append([Vector3(FRONT_X - 2.7, xf.origin.y, xf.origin.z - 0.95), Vector3(FRONT_X + 0.2, xf.origin.y + wall_h + 1.0, xf.origin.z + 0.95)])
	shapes.append([Vector3(FRONT_X, last - 2.0, z_end), Vector3(FRONT_X + depth, last + wall_h + 1.0, z_end + T)])
	var th := depth * 0.5
	shapes.append([Vector3(FRONT_X + depth * 0.5 - th - 1.3, tower_base - FOUNDATION, TOWER_Z - th - 1.3), Vector3(FRONT_X + depth * 0.5 + th + 1.3, tower_base + 3.2, TOWER_Z + th + 1.3)])
	shapes.append([Vector3(FRONT_X + depth * 0.5 - th - 0.4, tower_base, TOWER_Z - th - 0.4), Vector3(FRONT_X + depth * 0.5 + th + 0.4, tower_base + 30.0, TOWER_Z + th + 0.4)])
	for xf: Transform3D in lists["AbbeyTurret"]:
		shapes.append([xf.origin + Vector3(-1.9, -1.0, -1.9), xf.origin + Vector3(1.9, 20.0, 1.9)])
	var body := StaticBody3D.new()
	body.name = "AbbeyBody"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	host.add_child(body)
	for sh: Array in shapes:
		var lo: Vector3 = sh[0]
		var hi: Vector3 = sh[1]
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = hi - lo
		cs.shape = bs
		cs.position = (lo + hi) * 0.5
		body.add_child(cs)
	draws += fk.commit(host, "AbbeyFoundations")
	for c in host.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).add_to_group(Groups.CULL_SKIP)
	built = true
	rects = [footprint()]
	var wr := OssFrame.wrect(footprint(1.0))
	var near: PackedStringArray = []
	for st: Dictionary in WorldLanes.sites:
		if (st.rect as Rect2).intersects(wr):
			near.append(String(st.name))
	if not near.is_empty():
		print("OSSUARY abbey: sites inside its footprint: %s" % [near])
	print("OSSUARY abbey built in %d ms: %d bays on %s, tower %.1f..%.1f (local y), %d draws, %d boxes" % [
		Time.get_ticks_msec() - t0, BAY_N, str(base_y), tower_base, tower_top, draws, shapes.size()])


## One MultiMesh for every instance of a module (the glb's lit panes get the kit's glow shader), off physics interpolation.
static func _multimesh(host: Node3D, nm: String, mesh: Mesh, xfs: Array) -> int:
	var m := mesh.duplicate() as ArrayMesh
	for s in m.get_surface_count():
		var sm := m.surface_get_material(s)
		if sm != null and String(sm.resource_name).to_lower().contains("glow"):
			m.surface_set_material(s, OssKit.mat("glow"))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	var box := AABB()
	var first := true
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		mm.set_instance_transform(i, t)
		var bb := t * m.get_aabb()
		box = bb if first else box.merge(bb)
		first = false
	var mmi := MultiMeshInstance3D.new()
	mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mmi.name = nm
	mmi.multimesh = mm
	mmi.custom_aabb = box.grow(2.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF          # (the moon's cascades never see the abbey: it is lit by its windows)
	host.add_child(mmi)
	return m.get_surface_count()

extends RefCounted
## The South pass (docs/r37_expansion.md): the doubled Realm's southern ground and the old Realm's wall.
##
##   March Wall   the old Realm's boundary, a curtain wall that follows the land (RealmMarch.WALL_WEST /
##                _EAST, a polyline per side) from the Crowns' foot (z -112) to the south edge: a kit of
##                segments (three states of ruin), towers at its bends and every ~50 m on the straight, two
##                GATEHOUSES where the Pilgrims' Road crosses (RealmLayout.MARCH_GATES; the gate leaves hang
##                broken, the road runs clear), BREACHES wherever a track crosses the line or a camp, a site or
##                a slot stands in its way (the wall never blocks a way), spurs out to towers on knolls, and
##                one long fall (MARCH_RUINS: stubs and rubble, no barrier).
##                Detail meshes with LODs and a far silhouette mesh (visibility ranges, never a hard cut).
##   Southern Downs  the shepherds' hut and fold (the shepherd's camp is village_cast OUTPOSTS "dunstan")
##   Grandmother Oak  a 40 m hollow dead oak (Blender: trunk, roots, limbs, a stair in the trunk): the
##                door at its foot, a timber stair spiralling up inside, three limb doors, a walk out along
##                each limb, a crown deck; the Root-Wife (Elites "root_wife") lairs in the roots
##   Well of Echoes  the sinkhole's descent: a ledge path (cut stone slabs hung from the pit wall) spiralling
##                down to a landing and a cave mouth, through the waterfall, to the pool; the Answerer
##                (Elites "well_answer") keeps the landing
## Everything is placed by ground raycast at build time (the terrain, wherever the Foundation put it).
## Built by realm_pois.gd: reserve() from its reserve (before the stamp and the flora), build() from its
## build (after the flora). Meshes come from the Blender kits (south_marches_kit.gd); the numbers they were
## made with, from south_marches_kit_data.gd (written by tools/blender/r37_south.py). No class_name.

const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const PropModels := preload("res://core/world/realm/prop_models.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/south_marches_kit.gd")
const OakMound := preload("res://core/world/realm/oak_mound.gd")
const OakHollowGlow := preload("res://core/world/realm/oak_hollow_glow.gd")
const Data := preload("res://core/world/realm/south_marches_kit_data.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const Parts := preload("res://core/world/realm/march_wall_parts.gd")
const FALL_SHADER := preload("res://core/world/realm/well_waterfall.gdshader")

const OAK_C := Vector2(-70.0, 206.0)
const WALL_Z0 := -112.0
const WALL_Z1 := 242.0
const WALL_VIS := Vector2(0.0, 130.0)      ## the detail meshes fade out here (FarDetail.register: the far silhouette takes over)
const FAR_END := 130.0
const POI_IDS := ["r37s_hut", "r37s_oak", "r37s_well", "r37s_gate_w", "r37s_gate_e"]

## id -> {title, line, region, half}
const POIS := {
	"r37s_hut": {"title": "The Shepherd's Fold", "line": "the flock walked north and did not come back", "region": "downs", "half": Vector2(9.0, 9.0)},
	"r37s_oak": {"title": "The Grandmother Oak", "line": "the Rooted's first fire was carried out of it", "region": "oak", "half": Vector2(11.0, 11.0)},
	"r37s_well": {"title": "The Descent", "line": "count the echoes, if you can", "region": "well", "half": Vector2(21.0, 21.0)},
	"r37s_gate_w": {"title": "The West March Gate", "line": "the Order's wall, and the road through it", "region": "road", "half": Vector2(11.0, 6.0)},
	"r37s_gate_e": {"title": "The East March Gate", "line": "the Order's wall, and the road through it", "region": "road", "half": Vector2(11.0, 6.0)},
}

## id -> offset (xz) of the side a visitor comes from
const APPROACH := {"r37s_oak": Vector2(0.0, -20.0), "r37s_hut": Vector2(0.0, -20.0), "r37s_well": Vector2(-30.0, -12.0),
	"r37s_gate_w": Vector2(34.0, 4.0), "r37s_gate_e": Vector2(-34.0, 4.0)}

## Chests: [tier, ItemDB ids -> amount]
const LOOT := {
	"r37s_oak_limb": ["iron", {"grave_ash": 14, "relic_fragment": 1}],
	"r37s_fold": ["wood", {"grave_ash": 9, "ash_bloom": 1}],
	"r37s_gate_w": ["wood", {"grave_ash": 8, "grave_iron": 1}],
	"r37s_gate_e": ["wood", {"grave_ash": 8, "grave_iron": 1}],
	"r37s_well_landing": ["reliquary", {"grave_ash": 18, "relic_fragment": 2}],
}

static var spots := {}                  ## id -> {at: Vector3, yaw, rect, ...} (reserve)
static var built: Array[String] = []
static var breaches := {}               ## side (-1 / +1) -> Array[float] (z of each breach's centre)
static var gate_z := {}                 ## side -> z
static var well := {}                   ## the Well's measured numbers (build): rim_y, floor_y, landing, ...
static var oak := {}                    ## the Oak's measured numbers (build): xf, crown, tips


# =================================================================================================
# reserve (RealmBosses via RealmPois.reserve, before the stamp and the flora)
# =================================================================================================

static func reserve(root: Node) -> void:
	spots.clear()
	TerrainStamp.mounds.clear()
	breaches.clear()
	gate_z.clear()
	Parts.reset()
	for a in OS.get_cmdline_user_args():
		if a == "--no-r37-south":
			return
	var space := (root as Node3D).get_world_3d().direct_space_state
	# --- the Grandmother Oak: a level round under the trunk and its roots' first reach, trees kept away
	var oy := _ground_med(space, OAK_C)
	Flora.tree_clear.append([OAK_C, 24.0])
	var land := func(x: float, z: float) -> float: return RealmLayout.ground(space, x, z)
	OakMound.queue(Kit.mesh(Kit.OAK, "Roots"), OAK_C, oy, float(Data.OAK_DOOR.a), land)
	spots["r37s_oak"] = {"at": Vector3(OAK_C.x, oy, OAK_C.y), "yaw": 0.0, "rect": Rect2(OAK_C - Vector2(11, 11), Vector2(22, 22))}
	# the doorway's approach kept clear of scatter: two fallen boughs lay across it 3.6 m out and the way in was shut (zone fit)
	var door_out := Vector2(sin(float(Data.OAK_DOOR.a)), cos(float(Data.OAK_DOOR.a)))
	WorldLanes.register_lane("oak_door_way", [OAK_C + door_out * 22.0, OAK_C + door_out * 5.0], 2.6)
	# --- the shepherds' hut and fold: the fold's round first (a terrace), the hut beside it
	var fold_pref := Vector2(12.0, 207.0)
	# the Charnel Abbey stands on the pit's south bank (oss_abbey.gd): the fold and the hut keep off its ground
	var abbey: Array[Rect2] = []
	for ab: Dictionary in preload("res://world/areas/ossuary/oss_abbey.gd").site_rects():
		abbey.append((ab.rect as Rect2).grow(3.0))
	var off_abbey := func(q: Vector2, half: Vector2) -> bool:
		var rc := Rect2(q - half, half * 2.0)
		for r: Rect2 in abbey:
			if r.intersects(rc):
				return false
		return true
	var fq := LK.search_spot(space, fold_pref, 24.0, Vector2(9.0, 9.0), 1.5, 2.4, [], 2.0, func(q: Vector2) -> bool: return off_abbey.call(q, Vector2(9.0, 9.0)))
	if fq == Vector2.INF:
		fq = fold_pref
	var fy := _ground_med(space, fq)
	spots["r37s_fold"] = {"at": Vector3(fq.x, fy, fq.y), "yaw": 0.0, "rect": Rect2(fq - Vector2(9, 9), Vector2(18, 18))}
	var hut_pref := fq + Vector2(-14.0, -2.0)
	var hq := LK.search_spot(space, hut_pref, 26.0, Vector2(5.5, 5.0), 1.5, 1.6, [], 2.0, func(q: Vector2) -> bool: return off_abbey.call(q, Vector2(5.5, 5.0)))
	if hq == Vector2.INF:
		hq = hut_pref
	var rect := Rect2(hq - Vector2(5.5, 5.0), Vector2(11.0, 10.0))
	var lo := INF
	for ix in 3:
		for iz in 3:
			lo = minf(lo, RealmLayout.ground(space, rect.position.x + rect.size.x * ix * 0.5, rect.position.y + rect.size.y * iz * 0.5))
	WorldLanes.register_site("poi_r37s_hut", rect, lo + 0.05, lo)
	spots["r37s_hut"] = {"at": Vector3(hq.x, lo, hq.y), "yaw": PI, "rect": rect}
	# --- the Well: trees kept off the rim and the approach; the gate, the spillway and the echo stone's
	# footprints are claimed where they will stand (the rim is ~WELL_R from the centre)
	Flora.tree_clear.append([RealmLayout.WELL_C, RealmLayout.WELL_R + 14.0])
	var wc := RealmLayout.WELL_C
	for pair: Array in [["gate", -1.8, 3.0, Vector2(4.5, 4.5)], ["spill", PI * 0.5, 9.0, Vector2(6.0, 8.0)], ["echo", -2.3, 5.0, Vector2(2.0, 2.0)]]:
		var a: float = pair[1]
		var q: Vector2 = wc + Vector2(sin(a), cos(a)) * (RealmLayout.WELL_R + float(pair[2]))
		var half: Vector2 = pair[3]
		var r2 := Rect2(q - half, half * 2.0)
		var y2 := _ground_med(space, q)
		WorldLanes.register_site("poi_r37s_well_" + String(pair[0]), r2, y2 + 0.05, y2)
	spots["r37s_well"] = {"at": Vector3(wc.x, _ground_med(space, wc), wc.y), "yaw": 0.0, "rect": Rect2(wc - Vector2(26, 26), Vector2(52, 52))}
	# --- the wall: two lanes keep the flora and the props off the line
	for side in [-1, 1]:
		WorldLanes.register_lane("r37s_wall_%d" % side, (RealmMarch.WALL_WEST if side < 0 else RealmMarch.WALL_EAST) as Array, 2.6)
	if Pilot.on():         # Weirford's face of the wall: the ground of its stair and of its lean-to is clear of trees
		Flora.tree_clear.append([Vector2(-163.0, 43.0), 11.0])
		Flora.tree_clear.append([Vector2(-159.5, 87.0), 8.0])
	print("REALM_POI r37 south reserved %s" % [spots.keys()])


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
	if "--no-r37-south" in OS.get_cmdline_user_args():
		return
	var t0 := Time.get_ticks_msec()
	var space := holder.get_world_3d().direct_space_state
	var host := Node3D.new()
	host.name = "R37South"
	holder.add_child(host)
	_wall(host, space)
	_hut(host, space)
	_oak(host, space)
	_well(host, space)
	print("REALM_POI r37 south built %s in %d ms (breaches %s, gates %s)" % [built, Time.get_ticks_msec() - t0, breaches, gate_z])


static func _poi(parent: Node3D, id: String, at: Vector3, radius := 0.0) -> Node3D:
	var d: Dictionary = POIS[id]
	var h := Node3D.new()
	h.name = "Poi_" + id
	h.set_meta("site", "poi_" + id)
	parent.add_child(h)
	h.global_position = at
	h.add_to_group(P.GROUP_POI)
	h.set_meta("poi", id)
	h.set_meta("title", d.title)
	h.set_meta("line", d.line)
	h.set_meta("region", d.region)
	h.set_meta("centre", at)
	h.set_meta("radius", radius if radius > 0.0 else (d.half as Vector2).length() + 4.0)
	h.set_meta("r37", true)
	var ap: Vector2 = APPROACH.get(id, Vector2(0.0, -20.0))        # where a visitor comes from (the screenshots look from here)
	h.set_meta("approach", at + Vector3(ap.x, 0.0, ap.y))
	built.append(id)
	return h


static func _chest(host: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	c.set("big", lerpf(1.0, Pilot.PROP, Pilot.weight(at.x, at.z)))
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


## A child of `host` that stands at the world's origin whatever the host's own place. These places' nodes stand AT
## their place, and a kit's geometry is in world space: committed straight under one it was drawn (and collided) at
## twice the place's position -- the steles stood out past the Realm's edge, their readings alone where they belonged.
static func _world_node(host: Node3D, n: String) -> Node3D:
	var hold := Node3D.new()
	hold.name = n
	host.add_child(hold)
	hold.global_transform = Transform3D.IDENTITY
	return hold


## A little carved stone with a reading: a slab on a footing, text in LoreDB (poi_r37s_*).
static func _stele(host: Node3D, space: PhysicsDirectSpaceState3D, id: String, at: Vector2, yaw: float, h := 1.3) -> void:
	LK.ensure_mats()
	var g := RealmLayout.ground(space, at.x, at.y)
	var o := Vector3(at.x, g, at.y)
	var b := Basis(Vector3.UP, yaw)
	var k := OssKit.new()
	k.keep_lanes = false
	k.collider(o + b * Vector3(0, 0.12, 0), Vector3(0.9, 0.3, 0.6), b)
	k.collider(o + b * Vector3(0, 0.3 + h * 0.5, 0), Vector3(0.62, h, 0.2), b)
	var hold := _world_node(host, "Stele_" + id)
	k.commit(hold, "SteleBody")
	var pm := PropModels.new()            # a round-headed or a gabled slab in a rough footing, the Open Door over its lettered field
	pm.add("ruin_marker.glb", Transform3D(b.scaled(Vector3(1.0, (0.34 + h) / 1.64, 1.0)), o), "SteleB" if hash(id) % 2 == 1 else "SteleA")
	pm.commit(hold, "Stele")
	var face := o + b * Vector3(0, 0.3 + h * 0.55, -0.12)
	P._lore(host, id, o + b * Vector3(0.0, 0.9, -0.55), face)


# =================================================================================================
# THE MARCH WALL
# =================================================================================================

static func _wall(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var wh := Node3D.new()
	wh.name = "MarchWall"
	host.add_child(wh)
	var gzs := {}
	for gv: Vector2 in RealmLayout.MARCH_GATES:
		gzs[-1 if gv.x < 0.0 else 1] = gv.y
	for side in [-1, 1]:
		_wall_side(wh, space, side, float(gzs.get(side, 67.0)))


# --- the line: one polyline per side, walked by arc length u -------------------------------------

static func line_of(side: int) -> Dictionary:
	var src: Array = RealmMarch.WALL_WEST if side < 0 else RealmMarch.WALL_EAST
	var p := PackedVector2Array()
	var s := PackedFloat64Array()
	var acc := 0.0
	for i in src.size():
		var v: Vector2 = src[i]
		if i > 0:
			acc += v.distance_to(p[i - 1])
		p.append(v)
		s.append(acc)
	return {"p": p, "s": s, "len": acc}


static func _at(line: Dictionary, u: float) -> Vector2:
	var p: PackedVector2Array = line.p
	var s: PackedFloat64Array = line.s
	var i := s.size() - 2
	for k in s.size() - 1:
		if u <= s[k + 1]:
			i = k
			break
	return p[i].lerp(p[i + 1], clampf((u - s[i]) / maxf(s[i + 1] - s[i], 0.001), 0.0, 1.0))


## Arc length at which the line reaches z (it only ever runs south).
static func _u_of_z(line: Dictionary, z: float) -> float:
	var p: PackedVector2Array = line.p
	var s: PackedFloat64Array = line.s
	for i in p.size() - 1:
		if z <= p[i + 1].y:
			return lerpf(s[i], s[i + 1], clampf((z - p[i].y) / maxf(p[i + 1].y - p[i].y, 0.001), 0.0, 1.0))
	return line.len


## The yaw that puts a part's local +Z on the outer face of a chord a -> b (local X then runs along the wall).
static func _yaw_of(side: int, a: Vector2, b: Vector2) -> float:
	var t := (b - a).normalized()
	var n := Vector2(t.y, -t.x) if side > 0 else Vector2(-t.y, t.x)
	return atan2(n.x, n.y)


## Where the wall must open (z): tracks that cross the line, camps, sites and slots on it, and the openings
## the layout names -- never near a gate, the fallen stretch or a spur's root.
static func _breach_zs(side: int, gz: float) -> Array[float]:
	var out: Array[float] = []
	var add := func(z: float) -> void:
		if z < WALL_Z0 + 18.0 or z > WALL_Z1 - 12.0 or absf(z - gz) < 30.0:
			return
		for rn: Array in RealmMarch.RUINS:
			if int(rn[0]) == side and z > float(rn[1]) - 16.0 and z < float(rn[2]) + 16.0:
				return
		for sp: Dictionary in RealmMarch.SPURS:
			if int(sp.side) == side and absf(z - float((sp.base as Vector2).y)) < 18.0:
				return
		for e: float in out:
			if absf(e - z) < 22.0:
				return
		out.append(z)
	var fs := float(side)
	for path: Dictionary in RealmLayout.PATHS:
		if String(path.id) == "road":
			continue
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if a.x * fs < 100.0 and b.x * fs < 100.0:
				continue
			var fa := (a.x - RealmMarch.wall_x(side, a.y)) * fs
			var fb := (b.x - RealmMarch.wall_x(side, b.y)) * fs
			if fa * fb < 0.0:
				var lo := 0.0
				var hi := 1.0
				for _k in 12:
					var mid := (lo + hi) * 0.5
					var q := a.lerp(b, mid)
					if (q.x - RealmMarch.wall_x(side, q.y)) * fs * fa > 0.0:
						lo = mid
					else:
						hi = mid
				add.call(a.lerp(b, lo).y)
	for oz: Array in RealmMarch.OPENINGS:
		if int(oz[0]) == side:
			add.call(float(oz[1]))
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var cp: Vector3 = c.at
		if cp.x * fs > 0.0 and RealmMarch.wall_dist(Vector2(cp.x, cp.z)) < 10.0:
			add.call(cp.z)
	for s: Dictionary in WorldLanes.sites:
		var sn := String(s.name)
		if sn.begins_with("poi_r37s") or sn.begins_with("r37s"):
			continue
		var r: Rect2 = s.rect
		if r.size.x > 0.0 and r.size.y > 0.0 and r.size.y < 36.0 and (r.position.x * fs > 100.0 or r.end.x * fs > 100.0):
			var gr := r.grow(7.0)
			var zz := r.position.y
			while zz <= r.end.y:
				if gr.has_point(Vector2(RealmMarch.wall_x(side, zz), zz)):
					add.call(r.get_center().y)
					break
				zz += 3.0
	for slot_list: Variant in RealmLayout.SLOTS.values():
		for sl: Dictionary in slot_list:
			var q: Vector2 = sl.at
			if q.x * fs > 0.0 and RealmMarch.wall_dist(q) < 9.0:
				add.call(q.y)
	out.sort()
	return out


static func _wall_side(wh: Node3D, space: PhysicsDirectSpaceState3D, side: int, gz: float) -> void:
	var line := line_of(side)
	var total: float = line.len
	var pv: PackedVector2Array = line.p
	var sv: PackedFloat64Array = line.s
	var feats: Array[Dictionary] = []
	gate_z[side] = gz
	feats.append({"u": _u_of_z(line, gz), "half": Parts.GATE_HALF * Pilot.wall_k(side, gz), "kind": "gate"})
	for rn: Array in RealmMarch.RUINS:
		if int(rn[0]) == side:
			var u0 := _u_of_z(line, float(rn[1]))
			var u1 := _u_of_z(line, float(rn[2]))
			feats.append({"u": (u0 + u1) * 0.5, "half": (u1 - u0) * 0.5, "kind": "ruin"})
	var spurs: Array[Dictionary] = []
	for sp: Dictionary in RealmMarch.SPURS:
		if int(sp.side) == side:
			spurs.append(sp)
			feats.append({"u": _u_of_z(line, float((sp.base as Vector2).y)), "half": Parts.TOWER_HALF, "kind": "tower"})
	var bz := _breach_zs(side, gz)
	breaches[side] = bz
	for z: float in bz:
		feats.append({"u": _u_of_z(line, z), "half": 13.4, "kind": "breach"})
	# towers: the ends, the bends, and a filler wherever a straight run goes over ~60 m
	var cand: Array[float] = []
	var prev := NAN
	for i in pv.size():
		var turn := 0.0
		if i > 0 and i < pv.size() - 1:
			turn = absf((pv[i] - pv[i - 1]).angle_to(pv[i + 1] - pv[i]))
		var end := i == 0 or i == pv.size() - 1
		if end or (turn > deg_to_rad(14.0) and (is_nan(prev) or sv[i] - prev >= 24.0)):
			while not is_nan(prev) and sv[i] - prev > 62.0:
				prev += 46.0
				cand.append(prev)
			cand.append(sv[i])
			prev = sv[i]
	var tn := 0
	for tu: float in cand:
		var ok := true
		for f: Dictionary in feats:
			if absf(float(f.u) - tu) < float(f.half) + 6.0 + Parts.TOWER_HALF - 3.9:
				ok = false
		if ok:
			feats.append({"u": tu, "half": Parts.TOWER_HALF, "kind": "tower_ruin" if tn % 3 == 1 or tu > total - 8.0 else "tower"})
			tn += 1
	feats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.u) < float(b.u))
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 37101 + side
	var cur := 0.0
	var n_seg := 0
	for f: Dictionary in feats:
		var lo := float(f.u) - float(f.half)
		if lo < cur - 0.6:
			continue
		n_seg += _fill(wh, space, shapes, line, side, cur, lo, rng)
		var c := _at(line, float(f.u))
		var yaw := _yaw_of(side, _at(line, float(f.u) - 4.0), _at(line, float(f.u) + 4.0))
		match String(f.kind):
			"gate":
				_gatehouse(wh, space, shapes, c, yaw, side)
			"breach":
				_breach(wh, space, shapes, line, side, float(f.u), rng)
			"ruin":
				_ruin(wh, space, shapes, line, side, float(f.u) - float(f.half), float(f.u) + float(f.half), rng)
			_:
				_tower(wh, space, shapes, c, yaw, String(f.kind) == "tower_ruin")
		cur = float(f.u) + float(f.half)
	n_seg += _fill(wh, space, shapes, line, side, cur, total, rng)
	for sp: Dictionary in spurs:
		n_seg += _spur(wh, space, shapes, sp.base, sp.tip, rng)
	Kit.body(wh, "MarchWallBody_%d" % side, shapes)
	print("R37S wall side %d: %d segments, %d features, breaches at %s, gate at z %.1f" % [side, n_seg, feats.size(), bz, gz])


## A kit part's far silhouette under `host` (core/world/far_detail.gd): drawn from `end` m out to the horizon.
static func _far(host: Node3D, path: String, part: String, xf: Transform3D, end := FAR_END, fade_host := false) -> void:
	var m := Kit.mesh(path, part)
	if m != null:
		FarDetail.register(host, m, host.global_transform.affine_inverse() * xf, end, null, fade_host)


## The wall's footing along the chord a -> b: the mean ground, held within reach of the lowest point.
static func _base_y(space: PhysicsDirectSpaceState3D, a: Vector2, b: Vector2) -> float:
	var t := (b - a).normalized()
	var perp := Vector2(t.y, -t.x)
	var s := 0.0
	var n := 0
	var lo := INF
	for iz in 5:
		var q := a.lerp(b, float(iz) / 4.0)
		for ox: float in [-1.6, 0.0, 1.6]:
			var g := RealmLayout.ground(space, q.x + perp.x * ox, q.y + perp.y * ox)
			s += g
			n += 1
			lo = minf(lo, g)
	return clampf(s / float(n) - 0.2, lo - 0.1, lo + 1.6)


## One plain segment a -> b (yaw puts local +Z on the outer face), scaled to fit.
static func _put_seg(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, a: Vector2, b: Vector2, yaw: float, rng: RandomNumberGenerator) -> void:
	var sl := a.distance_to(b)
	var mid := (a + b) * 0.5
	var by := _base_y(space, a, b)
	var side := -1 if mid.x < 0.0 else 1
	var r := rng.randf()
	var part := "WallSeg_A" if r < 0.3 else ("WallSeg_E" if r < 0.6 else ("WallSeg_B" if r < 0.85 else "WallSeg_C"))
	var stair := Parts.wants_stair(side, mid, sl)               # Weirford's face: one bay is the stair bay, one has the shed at its foot
	if stair:
		part = "WallSeg_D"
	var k := Pilot.wall_k(side, mid.y)       # the scale pilot: taller and thicker towards the west gate
	var sx := sl / float(Data.WALL_LEN)
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, k, k)), Vector3(mid.x, by, mid.y))
	Kit.put(wh, Kit.WALL, part, xf, WALL_VIS, true, "Seg_%d_%d" % [int(mid.x), int(mid.y)])
	_far(wh, Kit.WALL, "WallFar", xf)
	shapes.append_array(Parts.seg_shapes(mid, by, yaw, sl, k))
	if stair:
		Parts.town_stair(wh, shapes, mid, by, yaw, k, WALL_VIS)
	elif Parts.wants_shed(side, mid, sl):
		Parts.town_shed(wh, shapes, space, mid + Vector2(sin(yaw), cos(yaw)) * 1.5 * k, yaw, k, WALL_VIS)


## Plain segments along the line between arc lengths a and b, split at its bends, each scaled to fit. Returns how many.
static func _fill(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, line: Dictionary, side: int, a: float, b: float, rng: RandomNumberGenerator) -> int:
	if b - a < 1.2:
		return 0
	var sv: PackedFloat64Array = line.s
	var cuts: Array[float] = [a]
	for sx: float in sv:
		if sx > a + 1.0 and sx < b - 1.0:
			cuts.append(sx)
	cuts.append(b)
	var made := 0
	for k in cuts.size() - 1:
		var c0 := cuts[k]
		var len := cuts[k + 1] - c0
		if len < 0.8:
			continue
		var n := maxi(1, roundi(len / 12.0))
		for i in n:
			var pa := _at(line, c0 + len * float(i) / float(n))
			var pb := _at(line, c0 + len * float(i + 1) / float(n))
			_put_seg(wh, space, shapes, pa, pb, _yaw_of(side, pa, pb), rng)
			made += 1
	return made


static func _tower(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, c: Vector2, yaw: float, ruin: bool) -> void:
	var by := _base_y(space, c + Vector2(0.0, -3.6), c + Vector2(0.0, 3.6))
	Parts.tower(wh, shapes, c, yaw, by, ruin, WALL_VIS, FAR_END)


static func _gatehouse(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, c: Vector2, yaw: float, side: int) -> void:
	var x := c.x
	var z := c.y
	var by := RealmLayout.ground(space, x, z) - 0.1
	var k := Pilot.wall_k(side, z)                # the scale pilot's west gate: the model, its colliders and what stands by it
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * k), Vector3(x, by, z))
	var id := "r37s_gate_w" if side < 0 else "r37s_gate_e"
	var h := _poi(wh, id, Vector3(x, by, z))
	Kit.put(h, Kit.WALL, "Gatehouse", xf, WALL_VIS, true, "Gatehouse")
	_far(h, Kit.WALL, "GateFar", xf, FAR_END, true)
	var px := float(Data.GATE_PX) * k
	var td := float(Data.GATE_TD) * k
	var b := Basis(Vector3.UP, yaw)
	shapes.append_array(Parts.gate_shapes(Vector3(x, by, z), yaw, k))
	# a plaque on the old Realm's side of the passage, beside the south tower, and a box at the north tower's foot
	var inside := -(b * Vector3(0, 0, 1))          # towards the old Realm (local -Z)
	var pq := Vector2(x + inside.x * (td * 0.5 + 1.8), z + px + 1.2)
	_stele(h, space, "poi_r37s_gate_w" if side < 0 else "poi_r37s_gate_e", pq, atan2(inside.x, inside.z) + PI, 1.5)
	var cp := Vector3(x + inside.x * (td * 0.5 + 1.2), 0.0, z - px - 0.5)
	cp.y = RealmLayout.ground(space, cp.x, cp.z) + 0.02
	_chest(h, id, cp, yaw)
	h.set_meta("r37_gate", true)


## One broken end of the wall at arc length u: the stub and its collision. `toward` is +1 when the gap
## lies at greater u than the stub, -1 when at smaller u.
static func _stub(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, line: Dictionary, side: int, u: float, toward: int) -> void:
	var c := _at(line, u)
	var pa := _at(line, u - 3.2)
	var pb := _at(line, u + 3.2)
	var by := _base_y(space, pa, pb)
	var yaw := _yaw_of(side, pa, pb)
	# the stub's gap end is local +X; local +X runs with +u on the west wall and against it on the east one
	var mirror: bool = (toward > 0) != (side < 0)
	var sc := Vector3(-1.0 if mirror else 1.0, 1.0, 1.0)
	var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sc), Vector3(c.x, by, c.y))
	Kit.put(wh, Kit.WALL, "BreachStub", xf, WALL_VIS, true, "Stub_%d_%d" % [int(c.x), int(c.y)])
	shapes.append_array(Parts.stub_shapes(xf, by, Basis(Vector3.UP, yaw)))


static func _breach(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, line: Dictionary, side: int, u: float, rng: RandomNumberGenerator) -> void:
	_stub(wh, space, shapes, line, side, u - 10.2, 1)
	_stub(wh, space, shapes, line, side, u + 10.2, -1)
	# the rubble the wall left in the gap: low enough to walk over, never a wall
	var c := _at(line, u)
	var gy := RealmLayout.ground(space, c.x, c.y)
	Kit.put(wh, Kit.WALL, "Rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x, gy - 0.1, c.y)), WALL_VIS, false, "Rubble_%d_%d" % [side, int(c.y)])


## The long fall: a stub at each end, between them heaps of rubble and low fallen lengths, nothing that bars the way.
static func _ruin(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, line: Dictionary, side: int, u0: float, u1: float, rng: RandomNumberGenerator) -> void:
	_stub(wh, space, shapes, line, side, u0 + 3.6, 1)
	_stub(wh, space, shapes, line, side, u1 - 3.6, -1)
	var u := u0 + 9.0
	var k := 0
	while u < u1 - 9.0:
		var c := _at(line, u)
		var n := (_at(line, u + 2.0) - _at(line, u - 2.0)).normalized()
		var perp := Vector2(n.y, -n.x)
		var q := c + perp * rng.randf_range(-1.8, 1.8)
		var gy := RealmLayout.ground(space, q.x, q.y)
		var sc := rng.randf_range(0.9, 1.5)
		Kit.put(wh, Kit.WALL, "Rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.7, 1.1), sc)), Vector3(q.x, gy - 0.12, q.y)), WALL_VIS, false, "Fall_%d_%d" % [side, k])
		# every third heap has a length of the wall lying in it, low, walk-through
		if k % 3 == 1:
			var pa := _at(line, u - 4.0)
			var pb := _at(line, u + 4.0)
			var by := _base_y(space, pa, pb)
			var yaw := _yaw_of(side, pa, pb) + rng.randf_range(-0.35, 0.35)
			var flip := -0.8 if k % 2 == 0 else 0.8
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(flip, 0.32, 0.9)), Vector3(c.x, by - 0.2, c.y))
			Kit.put(wh, Kit.WALL, "BreachStub", xf, WALL_VIS, false, "Fallen_%d_%d" % [side, k])
		u += rng.randf_range(6.5, 9.5)
		k += 1


## A spur: the wall runs out from `base` (on the line) to a tower at `tip`, on a knoll. Returns segments.
static func _spur(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, base: Vector2, tip: Vector2, rng: RandomNumberGenerator) -> int:
	var d := (tip - base).normalized()
	var a := base + d * Parts.TOWER_HALF
	var b := tip - d * 4.2
	var yaw := atan2(-d.y, d.x)
	var n := maxi(1, roundi(a.distance_to(b) / 12.0))
	for i in n:
		_put_seg(wh, space, shapes, a.lerp(b, float(i) / float(n)), a.lerp(b, float(i + 1) / float(n)), yaw, rng)
	_tower(wh, space, shapes, tip, yaw, false)
	return n


# =================================================================================================
# THE SHEPHERDS' HUT AND FOLD
# =================================================================================================

static func _hut(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	if not spots.has("r37s_hut") or not spots.has("r37s_fold"):
		return
	var hs: Dictionary = spots["r37s_hut"]
	var fs: Dictionary = spots["r37s_fold"]
	var h := _poi(host, "r37s_hut", hs.at)
	var ho: Vector3 = hs.at
	var fo: Vector3 = fs.at
	# the hut: dry stone and thatch, the door on its +Z (towards the fold's gate and the track)
	var hxf := Transform3D(Basis(Vector3.UP, float(hs.yaw)), Vector3(ho.x, ho.y + 0.05, ho.z))
	Kit.put(h, Kit.HUT, "Hut", hxf, Vector2(0.0, 120.0), true, "Hut")
	var hb := Basis(Vector3.UP, float(hs.yaw))
	var w := float(Data.HUT_W)
	var d := float(Data.HUT_D)
	Kit.body(h, "HutBody", [
		[Kit.box(Vector3(w, 3.2, d)), Transform3D(hb, hxf * Vector3(0, 1.4, 0))],
		[Kit.box(Vector3(1.2, 6.0, 1.2)), Transform3D(hb, hxf * Vector3(w * 0.5 + 0.12, 3.0, -0.4))]])
	# the fold: a ring of dry-stone wall (a gap on the north for the gate), the pieces following the ground
	var r := 7.2
	var n := 11
	var step := TAU / float(n)
	var shapes: Array = []
	for i in n:
		var a := step * (float(i) + 0.5)                      # 0 = +x... the gap faces north (-z): angle -pi/2
		if absf(wrapf(a + PI * 0.5, -PI, PI)) < step * 0.6:
			continue
		var p := Vector3(fo.x + cos(a) * r, 0.0, fo.z + sin(a) * r)
		p.y = RealmLayout.ground(space, p.x, p.z) - 0.1
		var yaw := -a + PI * 0.5
		var part := "FoldWallB" if (i == 3 or i == 8) else "FoldWall"
		var xf := Transform3D(Basis(Vector3.UP, yaw), p)
		Kit.put(h, Kit.HUT, part, xf, Vector2(0.0, 110.0), true, "Fold_%d" % i)
		if part == "FoldWall":
			shapes.append([Kit.box(Vector3(4.0, 3.0, 0.8)), Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.4, 0))])
	Kit.body(h, "FoldBody", shapes)
	# inside: hurdles leaned along a pen, a trough, a rack, the shearing bench; a bell on its post at the gate
	var rng := RandomNumberGenerator.new()
	rng.seed = 37201
	var inner := [["Trough", Vector2(-2.6, -1.2), 0.3], ["Rack", Vector2(2.4, 1.0), 1.57], ["Bench", Vector2(0.4, 3.0), 0.2], ["Hurdle", Vector2(-1.0, 1.6), 0.4],
		["Hurdle", Vector2(-2.7, 1.8), 1.2], ["Hurdle", Vector2(1.8, -2.6), -0.4], ["Hurdle", Vector2(0.4, -3.2), 0.1]]
	for it: Array in inner:
		var q: Vector2 = it[1]
		var gp := Vector3(fo.x + q.x, 0.0, fo.z + q.y)
		gp.y = RealmLayout.ground(space, gp.x, gp.z)
		Kit.put(h, Kit.HUT, String(it[0]), Transform3D(Basis(Vector3.UP, float(it[2])), gp), Vector2(0.0, 80.0), false, "Fold" + String(it[0]))
	var bp := Vector3(fo.x + 1.2, 0.0, fo.z - r - 0.9)
	bp.y = RealmLayout.ground(space, bp.x, bp.z)
	Kit.put(h, Kit.HUT, "BellPost", Transform3D(Basis(Vector3.UP, 0.3), bp), Vector2(0.0, 80.0), false, "BellPost")
	_chest(h, "r37s_fold", Vector3(ho.x + 3.4, RealmLayout.ground(space, ho.x + 3.4, ho.z - 3.6) + 0.02, ho.z - 3.6), 0.4)
	_stele(h, space, "poi_r37s_fold", Vector2(fo.x - 2.0, fo.z - r - 2.3), PI, 1.1)
	_stele(h, space, "poi_r37s_hut", Vector2(ho.x - 3.4, ho.z + 3.6), PI * 0.7, 0.9)
	h.set_meta("fold_centre", fo)


# =================================================================================================
# THE GRANDMOTHER OAK
# =================================================================================================

static func _oak(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	if not spots.has("r37s_oak"):
		return
	var s: Dictionary = spots["r37s_oak"]
	var at: Vector3 = s.at
	var h := _poi(host, "r37s_oak", at, 28.0)
	var xf := Transform3D(Basis(Vector3.UP, float(s.yaw)), at)
	for part: String in ["Trunk", "Roots", "Limbs", "Crown", "Stair", "Litter"]:
		Kit.put(h, Kit.OAK, part, xf, Vector2.ZERO, true)
	_far(h, Kit.OAK, "OakFar", xf, 120.0, true)
	OakHollowGlow.build(h, xf)
	var shapes: Array = []
	for part: String in ["TrunkCol", "StairCol", "RailCol", "LimbCol", "DeckCol"]:
		var sh := Kit.trimesh(Kit.OAK, part)
		if sh != null:
			shapes.append([sh, xf])
	Kit.body(h, "OakBody", shapes)
	var limbs: Array = Data.OAK_LIMBS
	var tips: Array[Vector3] = []
	for lm: Dictionary in limbs:
		var walk: Array = lm.walk
		var last: Array = walk[walk.size() - 1]
		var tip: Vector3 = xf * Vector3(float(last[0]), float(last[1]), float(last[2]))
		tips.append(tip)
		var inward := (Vector2(at.x, at.z) - Vector2(tip.x, tip.z)).normalized()
		var drop := tip.y - RealmLayout.ground(space, tip.x, tip.z)
		P._perch(h, tip + Vector3.UP * 0.2, Vector3(-inward.x, 0.0, -inward.y), drop)
	# a chest on the last limb's walk, a few metres in from its tip
	var lw: Array = (limbs[limbs.size() - 1] as Dictionary).walk
	var cw: Array = lw[maxi(lw.size() - 3, 0)]
	_chest(h, "r37s_oak_limb", xf * Vector3(float(cw[0]), float(cw[1]) + 0.02, float(cw[2])), float(s.yaw))
	# the crown deck: the top of the stair, where the secret is (site_south_marches.gd)
	var st: Dictionary = Data.OAK_STAIR
	var a_end: float = float(st.a_end)
	var top_y: float = float(st.top)
	var crown_local := Vector3(sin(a_end + 1.6) * 2.4, top_y, cos(a_end + 1.6) * 2.4)
	var crown := xf * crown_local
	h.set_meta("crown", crown)
	h.set_meta("limb_tips", tips)
	h.set_meta("oak_xf", xf)
	P._perch(h, crown + Vector3.UP * 0.1, Vector3(sin(a_end + 3.0), 0.0, cos(a_end + 3.0)), top_y)
	# lore: carved in the heartwood inside the door, and on the crown deck
	_stele_local(h, "poi_r37s_oak_heart", xf * Vector3(2.9, 0.0, -1.2), at.y, float(s.yaw) + PI * 0.5)
	oak = {"xf": xf, "crown": crown, "tips": tips, "door": xf * Vector3(sin(float(Data.OAK_DOOR.a)) * 6.4, 0.0, cos(float(Data.OAK_DOOR.a)) * 6.4)}
	# the beacon: a faint column, so the oak reads from the downs' far side
	var wf: Variant = load("res://core/world/realm/realm_wayfinding.gd")
	var bn: Variant = wf.beacon(host, at, "", Color(0.42, 0.5, 0.34), 40.0, 0.3, 24.0, false, 90.0)
	if bn is Node:
		(bn as Node).name = "Beacon_r37s_oak"
		(bn as Node).set_meta("poi", "r37s_oak")


## A stone inside a built thing: no ground ray (the floor is the caller's y).
static func _stele_local(host: Node3D, id: String, at: Vector3, y: float, yaw: float) -> void:
	LK.ensure_mats()
	var b := Basis(Vector3.UP, yaw)
	var o := Vector3(at.x, y, at.z)
	var k := OssKit.new()
	k.keep_lanes = false
	k.collider(o + b * Vector3(0, 0.75, 0), Vector3(0.55, 1.3, 0.18), b)
	var hold := _world_node(host, "Stele_" + id)
	k.commit(hold, "SteleBody")
	var pm := PropModels.new()
	pm.add("ruin_marker.glb", Transform3D(b.scaled(Vector3(0.9, 0.86, 0.9)), o), "SteleB" if hash(id) % 2 == 1 else "SteleA")
	pm.commit(hold, "Stele")
	P._lore(host, id, o + b * Vector3(0.0, 0.95, -0.5), o + b * Vector3(0, 0.95, -0.1))


# =================================================================================================
# THE WELL OF ECHOES
# =================================================================================================

## The pit wall's radius at height y along angle a: where the ground (rising with radius) reaches y.
static func _wall_r(space: PhysicsDirectSpaceState3D, c: Vector2, a: float, y: float, r_max: float) -> float:
	# Walk out from the pit to the first radius where the ground reaches y, then bisect inside that
	# step. (A bisection over the whole run slid out to r_max wherever the rim was lower than the
	# ring's mean height: the descent gate and the ledge's first slabs hung 4 m over the downs.)
	# Where the rim never reaches y on this bearing, the crest of the rim is the wall.
	var step := 0.5
	var crest_r := 0.5
	var crest_g := -INF
	var r := 4.0
	while r <= r_max:
		var g := RealmLayout.ground(space, c.x + sin(a) * r, c.y + cos(a) * r)
		if g >= y:
			var lo := r - step
			var hi := r
			for i in 8:
				var m := (lo + hi) * 0.5
				if RealmLayout.ground(space, c.x + sin(a) * m, c.y + cos(a) * m) < y:
					lo = m
				else:
					hi = m
			return (lo + hi) * 0.5
		if r <= RealmLayout.WELL_R + 6.0 and g > crest_g:
			crest_g = g
			crest_r = r
		r += step
	return crest_r


static func _well(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var wc := RealmLayout.WELL_C
	var R := RealmLayout.WELL_R
	# the rim's height (a ring just outside) and the floor (the middle)
	var rim_y := 0.0
	for i in 12:
		var a := TAU * float(i) / 12.0
		rim_y += RealmLayout.ground(space, wc.x + sin(a) * (R + 3.0), wc.y + cos(a) * (R + 3.0))
	rim_y /= 12.0
	var floor_y := RealmLayout.ground(space, wc.x, wc.y)
	var depth := rim_y - floor_y
	var h := _poi(host, "r37s_well", Vector3(wc.x, rim_y, wc.y), R + 10.0)
	well = {"rim_y": rim_y, "floor_y": floor_y, "depth": depth}
	if depth < 7.0:
		print("R37S well: the pit is not there yet (rim %.1f, floor %.1f): no ledge built" % [rim_y, floor_y])
		return
	var r_max := R + 16.0
	# the path: linear in angle from the rim to the landing at the cave
	var th0 := -1.8
	var th_cave := th0 + 7.0
	var land_y := RealmLayout.WELL_POOL_Y + 1.0
	var n_slab := 0
	var sweep := th_cave - th0
	var th := th0
	var shapes: Array = []
	var landing_every := 9
	var k := 0
	var fall_th := PI * 0.5                              # where the waterfall comes down (east)
	var listener := Vector3.INF
	while th < th_cave - 0.001 and k < 80:
		var y := lerpf(rim_y - 0.15, land_y, (th - th0) / sweep)
		var rw := _wall_r(space, wc, th, y, r_max)
		var rc := rw - 1.45
		var dth := 2.7 / maxf(rc, 4.0)
		var y_mid := lerpf(rim_y - 0.15, land_y, (th + dth * 0.5 - th0) / sweep)
		var radial := Vector3(sin(th + dth * 0.5), 0.0, cos(th + dth * 0.5))
		var tangent := Vector3(cos(th + dth * 0.5), 0.0, -sin(th + dth * 0.5))
		var y_next := lerpf(rim_y - 0.15, land_y, (th + dth - th0) / sweep)
		var slope := (y_mid - y_next) / (2.7)
		var zv := (tangent - Vector3.UP * (slope * 1.0 + 0.0)).normalized()
		var xv := -radial
		var yv := zv.cross(xv).normalized()
		var bs := Basis(xv, yv, zv).orthonormalized()
		var pos := Vector3(wc.x + radial.x * rc, y_mid, wc.y + radial.z * rc)
		var cross_fall := absf(wrapf(th + dth * 0.5 - fall_th, -PI, PI)) < 0.22
		var is_landing := (k % landing_every == landing_every - 1) or cross_fall and listener == Vector3.INF
		if is_landing and th + dth < th_cave - 0.4:
			Kit.put(h, Kit.WELL, "LedgeLanding", Transform3D(bs, pos), Vector2(0.0, 150.0), true, "Landing_%d" % k)
			shapes.append([Kit.box(Vector3(4.4, 0.7, 4.2)), Transform3D(bs, pos - bs.y * 0.3)])
			if cross_fall and listener == Vector3.INF:
				listener = pos + bs.y * 0.05 - bs.x * (-1.2)
				well["listener"] = pos
				well["listener_basis"] = bs
		else:
			Kit.put(h, Kit.WELL, "LedgeSlab" if k % 2 == 0 else "LedgeSlabOpen", Transform3D(bs, pos), Vector2(0.0, 150.0), true, "Slab_%d" % k)
			shapes.append([Kit.box(Vector3(2.7, 0.6, 3.1)), Transform3D(bs, pos - bs.y * 0.28)])
		if k % 2 == 1:
			var gnd := RealmLayout.ground(space, pos.x, pos.z)
			if pos.y - gnd > 1.0:
				Kit.put(h, Kit.WELL, "Corbel", Transform3D(Basis(bs.x, Vector3.UP, bs.z).orthonormalized(), pos + Vector3(0, -0.2, 0) + bs.x * -0.5), Vector2(0.0, 90.0), false, "Corbel_%d" % k)
		n_slab += 1
		th += dth * 0.96
		k += 1
	# the landing and the cave: where the ledge ends, the floor the Answerer keeps
	var rl := _wall_r(space, wc, th_cave, land_y + 2.0, r_max)
	var r_land := clampf(rl - 3.6, 5.0, 9.8)
	var lr := Vector3(sin(th_cave), 0.0, cos(th_cave))
	var lt := Vector3(cos(th_cave), 0.0, -sin(th_cave))
	var land_pos := Vector3(wc.x + lr.x * r_land, land_y, wc.y + lr.z * r_land)
	var lb := Basis(-lr, Vector3.UP, lt).orthonormalized()
	Kit.put(h, Kit.WELL, "LedgeLanding", Transform3D(lb.scaled(Vector3(1.5, 1.0, 1.5)), land_pos), Vector2(0.0, 150.0), true, "CaveLanding")
	shapes.append([Kit.box(Vector3(6.6, 0.7, 6.3)), Transform3D(lb, land_pos - Vector3(0, 0.3, 0))])
	for po: Vector2 in [Vector2(-2.6, -2.4), Vector2(2.4, -2.5), Vector2(-2.5, 2.3), Vector2(2.6, 2.4)]:
		var pp := land_pos + lb * Vector3(po.x, -3.2, po.y)
		Kit.put(h, Kit.WELL, "Pier", Transform3D(Basis(Vector3.UP, 0.0), Vector3(pp.x, land_y - 4.9, pp.z)), Vector2(0.0, 100.0), false, "Pier")
	var cave_pos := Vector3(wc.x + lr.x * (rl + 0.7), land_y - 0.05, wc.y + lr.z * (rl + 0.7))
	var cb := Basis(Vector3(-cos(th_cave), 0.0, sin(th_cave)), Vector3.UP, -lr).orthonormalized()
	Kit.put(h, Kit.WELL, "CaveMouth", Transform3D(cb, cave_pos), Vector2(0.0, 150.0), true, "CaveMouth")
	_chest(h, "r37s_well_landing", land_pos + lb * Vector3(0.0, 0.05, 1.8), th_cave)       # the landing's top is 0.05 over its origin
	Kit.body(h, "LedgeBody", shapes)
	well["landing"] = land_pos
	well["cave"] = cave_pos
	well["th_cave"] = th_cave
	well["slabs"] = n_slab
	# the descent gate at the rim, the echo stone, the spillway and the fall
	print("R37S well: rim %.1f floor %.1f, %d slabs, landing %s" % [rim_y, floor_y, n_slab, land_pos.snapped(Vector3.ONE * 0.1)])
	_gate(h, space, wc, th0, rim_y, r_max)
	_echo_stone(h, space, wc, R)
	_spillway_and_fall(h, space, wc, R, rim_y, floor_y, r_max, fall_th)
	var wf: Variant = load("res://core/world/realm/realm_wayfinding.gd")
	var bn: Variant = wf.beacon(host, Vector3(wc.x, rim_y, wc.y), "", Color(0.34, 0.5, 0.6), 30.0, 0.3, 12.0, false, 80.0)
	if bn is Node:
		(bn as Node).name = "Beacon_r37s_well"
		(bn as Node).set_meta("poi", "r37s_well")


static func _gate(h: Node3D, space: PhysicsDirectSpaceState3D, wc: Vector2, th0: float, rim_y: float, r_max: float) -> void:
	var rw := _wall_r(space, wc, th0 - 0.03, rim_y - 0.2, r_max)
	var rc := rw - 1.45
	var radial := Vector3(sin(th0 - 0.12), 0.0, cos(th0 - 0.12))
	var tangent := Vector3(cos(th0 - 0.12), 0.0, -sin(th0 - 0.12))
	var p := Vector3(wc.x + radial.x * (rc + 0.3), rim_y - 0.05, wc.y + radial.z * (rc + 0.3))
	var b := Basis(-radial, Vector3.UP, tangent).orthonormalized()
	Kit.put(h, Kit.WELL, "DescentGate", Transform3D(b, p + b.x * -0.9), Vector2(0.0, 150.0), true, "DescentGate")
	var sh := Kit.box(Vector3(1.4, 5.0, 1.4))
	Kit.body(h, "GateBody", [[sh, Transform3D(b, p + b.x * (-0.9 - 1.9) + Vector3(0, 2.2, 0))], [sh, Transform3D(b, p + b.x * (-0.9 + 1.9) + Vector3(0, 2.2, 0))]])
	h.set_meta("gate", p)
	# a lamp hook's worth of life: the way down is lit by nothing. A stone beside it says so.
	_stele(h, space, "poi_r37s_well_gate", Vector2(p.x, p.z) + Vector2(-tangent.x, -tangent.z) * 4.0 - Vector2(radial.x, radial.z) * -1.0, atan2(tangent.x, tangent.z), 1.1)


static func _echo_stone(h: Node3D, space: PhysicsDirectSpaceState3D, wc: Vector2, R: float) -> void:
	var a := -2.3
	var q := wc + Vector2(sin(a), cos(a)) * (R + 5.0)
	var g := RealmLayout.ground(space, q.x, q.y)
	var yaw := atan2(-sin(a), -cos(a))                 # facing the pit's centre
	Kit.put(h, Kit.WELL, "EchoStone", Transform3D(Basis(Vector3.UP, yaw + PI), Vector3(q.x, g, q.y)), Vector2(0.0, 90.0), true, "EchoStone")
	Kit.body(h, "EchoBody", [[Kit.box(Vector3(1.5, 3.0, 1.2)), Transform3D(Basis(Vector3.UP, yaw), Vector3(q.x, g + 1.4, q.y))]])
	var b := Basis(Vector3.UP, yaw)
	P._lore(h, "poi_r37s_well_echo", Vector3(q.x, g, q.y) + b * Vector3(0.0, 1.3, 0.9), Vector3(q.x, g + 1.9, q.y) + b * Vector3(0, 0, 0.3))
	h.set_meta("echo_stone", Vector3(q.x, g, q.y))


static func _spillway_and_fall(h: Node3D, space: PhysicsDirectSpaceState3D, wc: Vector2, R: float, rim_y: float, floor_y: float, r_max: float, th: float) -> void:
	var radial := Vector3(sin(th), 0.0, cos(th))
	var tangent := Vector3(cos(th), 0.0, -sin(th))
	var rw := _wall_r(space, wc, th, rim_y - 0.4, r_max)
	var lip_r := rw + 0.9
	var sp_y := RealmLayout.ground(space, wc.x + radial.x * (lip_r + 4.0), wc.y + radial.z * (lip_r + 4.0))
	sp_y = maxf(sp_y, rim_y) - 0.3
	var centre := Vector3(wc.x + radial.x * (lip_r + 4.2), sp_y, wc.y + radial.z * (lip_r + 4.2))
	# the sluice flows toward the pit: kit +Z is downstream
	var b := Basis(-tangent, Vector3.UP, -radial).orthonormalized()
	Kit.put(h, Kit.WELL, "Spillway", Transform3D(b, centre), Vector2(0.0, 150.0), true, "Spillway")
	var wsh := Kit.box(Vector3(1.0, 1.4, 9.0))
	Kit.body(h, "SpillBody", [[wsh, Transform3D(b, centre + b.x * 2.0 + Vector3(0, 0.3, 0))], [wsh, Transform3D(b, centre - b.x * 2.0 + Vector3(0, 0.3, 0))]])
	# the sheet: samples down the pit wall from the lip to just above the pool, hugging the wall
	var lip := Vector3(wc.x + radial.x * lip_r, sp_y + 0.05, wc.y + radial.z * lip_r)
	var foot_y := RealmLayout.WELL_POOL_Y + 0.3
	var rows := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 1.55
	var pts: Array[Vector3] = []
	var total := 0.0
	for i in rows + 1:
		var t := float(i) / float(rows)
		var y := lerpf(lip.y, foot_y, t)
		var rr := _wall_r(space, wc, th, y, r_max) - 0.12 if i > 0 else lip_r - 0.1
		pts.append(Vector3(wc.x + radial.x * rr, y, wc.y + radial.z * rr))
	for i in rows:
		total += pts[i].distance_to(pts[i + 1])
	var acc := 0.0
	for i in rows:
		var v0 := acc / total
		acc += pts[i].distance_to(pts[i + 1])
		var v1 := acc / total
		var l0 := pts[i] - tangent * hw
		var r0 := pts[i] + tangent * hw
		var l1 := pts[i + 1] - tangent * hw
		var r1 := pts[i + 1] + tangent * hw
		var nrm := (-radial).normalized()
		for q: Array in [[l0, Vector2(0, v0)], [r0, Vector2(1, v0)], [r1, Vector2(1, v1)], [l0, Vector2(0, v0)], [r1, Vector2(1, v1)], [l1, Vector2(0, v1)]]:
			st.set_normal(nrm)
			st.set_uv(q[1])
			st.add_vertex(q[0])
	var mi := MeshInstance3D.new()
	mi.name = "Waterfall"
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = FALL_SHADER
	sm.set_shader_parameter(&"fall_len", total)
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_to_group(Groups.CULL_SKIP)
	mi.visibility_range_end = 120.0
	mi.visibility_range_end_margin = 14.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	mi.extra_cull_margin = 8.0
	h.add_child(mi)
	# spray where it lands and where it crosses the ledge; the roar of it
	var foot := pts[rows] + Vector3(0, 0.2, 0) - radial * 0.4
	var mist := Vfx.emitter(Color(0.7, 0.8, 0.9, 0.5), {"count": 26, "life": 2.6, "speed": Vector2(0.3, 1.0), "size": 1.4, "gravity": 0.2, "radius": 1.6, "additive": false, "spread": 60.0, "dir": Vector3.UP, "damping": 0.3})
	if mist:
		mist.name = "FallMist"
		h.add_child(mist)
		mist.global_position = foot
		mist.visibility_range_end = 70.0
		mist.emitting = true
	var snd := AudioStreamPlayer3D.new()
	snd.name = "FallRoar"
	snd.stream = _rush()
	snd.volume_db = -6.0
	snd.unit_size = 9.0
	snd.max_distance = 70.0
	snd.autoplay = true
	h.add_child(snd)
	snd.global_position = Vector3(pts[rows / 2].x, pts[rows / 2].y, pts[rows / 2].z)
	h.set_meta("fall_foot", foot)
	h.set_meta("fall_lip", lip)
	h.set_meta("fall_len", total)


## A loop of filtered noise: the rush of a fall. 1.6 s at 22.05 kHz, seamless (the ends crossfade).
static func _rush() -> AudioStreamWAV:
	var n := 35280
	var fade := 3000
	var rng := RandomNumberGenerator.new()
	rng.seed = 37301
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n + fade:
		var w := rng.randf_range(-1.0, 1.0)
		lp1 += (w - lp1) * 0.18
		lp2 += (lp1 - lp2) * 0.35
		raw[i] = lp1 * 0.6 + lp2 * 0.7
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var v := raw[i]
		if i < fade:
			var t := float(i) / float(fade)
			v = raw[i] * t + raw[n + i] * (1.0 - t)
		pcm.encode_s16(i * 2, clampi(int(v * 9000.0), -32000, 32000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

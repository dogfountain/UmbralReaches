extends RefCounted
## The South pass (docs/r37_expansion.md): the doubled Realm's southern ground and the old Realm's wall.
##
##   March Wall   the old Realm's boundary, a curtain wall along x = -155 and x = +155 from the Crowns'
##                foot (z -110) to the south edge: a kit of segments (three states of ruin), towers every
##                ~48 m, two GATEHOUSES where the Pilgrims' Road crosses (RealmLayout.MARCH_GATES; the
##                gate leaves hang broken, the road runs clear), and BREACHES wherever a track crosses the
##                line or a camp, a site or a slot stands in its way (the wall never blocks a way).
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
## build (after the flora). Meshes come from the Blender kits (r37_south_kit.gd); the numbers they were
## made with, from r37_south_data.gd (written by tools/blender/r37_south.py). No class_name.

const P := preload("res://core/world/realm/realm_pois.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/r37_south_kit.gd")
const Data := preload("res://core/world/realm/r37_south_data.gd")
const FALL_SHADER := preload("res://core/world/realm/r37_south_fall.gdshader")

const OAK_C := Vector2(-70.0, 206.0)
const WALL_Z0 := -110.0
const WALL_Z1 := 242.0
const WALL_VIS := Vector2(0.0, 130.0)      ## the detail meshes fade out here (FarDetail.register: the far silhouette takes over)
const FAR_END := 130.0
const POI_IDS := ["r37s_hut", "r37s_oak", "r37s_well", "r37s_gate_w", "r37s_gate_e"]

## id -> {title, line, region, half}
const POIS := {
	"r37s_hut": {"title": "The Shepherd's Fold", "line": "the flock walked north and did not come back", "region": "downs", "half": Vector2(9.0, 9.0)},
	"r37s_oak": {"title": "The Grandmother Oak", "line": "the first fire was carried out of it", "region": "oak", "half": Vector2(11.0, 11.0)},
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
	breaches.clear()
	gate_z.clear()
	for a in OS.get_cmdline_user_args():
		if a == "--no-r37-south":
			return
	var space := (root as Node3D).get_world_3d().direct_space_state
	# --- the Grandmother Oak: a level round under the trunk and its roots' first reach, trees kept away
	var oy := _ground_med(space, OAK_C)
	Flora.tree_clear.append([OAK_C, 24.0])
	spots["r37s_oak"] = {"at": Vector3(OAK_C.x, oy, OAK_C.y), "yaw": 0.0, "rect": Rect2(OAK_C - Vector2(11, 11), Vector2(22, 22))}
	# --- the shepherds' hut and fold: the fold's round first (a terrace), the hut beside it
	var fold_pref := Vector2(12.0, 207.0)
	var fq := LK.search_spot(space, fold_pref, 14.0, Vector2(9.0, 9.0), 1.5, 2.4, [], 2.0)
	if fq == Vector2.INF:
		fq = fold_pref
	var fy := _ground_med(space, fq)
	spots["r37s_fold"] = {"at": Vector3(fq.x, fy, fq.y), "yaw": 0.0, "rect": Rect2(fq - Vector2(9, 9), Vector2(18, 18))}
	var hut_pref := fq + Vector2(-14.0, -2.0)
	var hq := LK.search_spot(space, hut_pref, 12.0, Vector2(5.5, 5.0), 1.5, 1.6, [], 2.0)
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
		var x := float(side) * RealmLayout.MARCH_WALL_X
		WorldLanes.register_lane("r37s_wall_%d" % side, [Vector2(x, WALL_Z0), Vector2(x, WALL_Z1)], 2.6)
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
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


## A little carved stone with a reading: a slab on a footing, text in LoreDB (poi_r37s_*).
static func _stele(host: Node3D, space: PhysicsDirectSpaceState3D, id: String, at: Vector2, yaw: float, h := 1.3) -> void:
	LK.ensure_mats()
	var g := RealmLayout.ground(space, at.x, at.y)
	var o := Vector3(at.x, g, at.y)
	var b := Basis(Vector3.UP, yaw)
	var k := OssKit.new()
	k.keep_lanes = false
	k.box("lore_tstone", o + b * Vector3(0, 0.12, 0), Vector3(0.9, 0.3, 0.6), b, true, 0.85)
	k.box("lore_tstone", o + b * Vector3(0, 0.3 + h * 0.5, 0), Vector3(0.62, h, 0.2), b, true, 0.92)
	k.box("lore_tstone", o + b * Vector3(0, 0.3 + h + 0.04, 0), Vector3(0.7, 0.1, 0.26), b, false, 0.8)
	k.commit(host, "Stele_" + id)
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


## Every place along the line (z) where the wall must open: tracks that cross it, camps, sites, slots.
static func _breach_zs(side: int, gz: float) -> Array[float]:
	var x := float(side) * RealmLayout.MARCH_WALL_X
	var out: Array[float] = []
	var add := func(z: float) -> void:
		if z < WALL_Z0 + 18.0 or z > WALL_Z1 - 12.0 or absf(z - gz) < 30.0:
			return
		for e: float in out:
			if absf(e - z) < 22.0:
				return
		out.append(z)
	for path: Dictionary in RealmLayout.PATHS:
		if String(path.id) == "road":
			continue
		var pts: Array = path.pts
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if (a.x - x) * (b.x - x) < 0.0:
				add.call(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	for c: Dictionary in EnemySpawner.REALM_CAMPS:
		var cp: Vector3 = c.at
		if absf(cp.x - x) < 10.0:
			add.call(cp.z)
	for s: Dictionary in WorldLanes.sites:
		var sn := String(s.name)
		if sn.begins_with("poi_r37s") or sn.begins_with("r37s"):
			continue
		var r: Rect2 = s.rect
		if r.size.y < 36.0 and r.position.x < x + 7.0 and r.end.x > x - 7.0 and (r.position.x * float(side) > 100.0 or r.end.x * float(side) > 100.0):
			add.call(r.get_center().y)
	for slot_list: Variant in RealmLayout.SLOTS.values():
		for sl: Dictionary in slot_list:
			var q: Vector2 = sl.at
			if absf(q.x - x) < 9.0:
				add.call(q.y)
	out.sort()
	return out


static func _wall_side(wh: Node3D, space: PhysicsDirectSpaceState3D, side: int, gz: float) -> void:
	var x := float(side) * RealmLayout.MARCH_WALL_X
	var yaw := float(side) * PI * 0.5                      # local +Z (the outer face) looks away from the old Realm
	var feats: Array[Dictionary] = []
	gate_z[side] = gz
	feats.append({"z": gz, "half": 10.4, "kind": "gate"})
	var bz := _breach_zs(side, gz)
	breaches[side] = bz
	for z: float in bz:
		feats.append({"z": z, "half": 13.8, "kind": "breach"})
	# towers: the ends and every ~48 m, clear of gates and breaches
	var tz := WALL_Z0 + 4.0
	var tn := 0
	while tz < WALL_Z1:
		var ok := true
		for f: Dictionary in feats:
			if absf(float(f.z) - tz) < float(f.half) + 6.0:
				ok = false
		if ok:
			feats.append({"z": tz, "half": 3.9, "kind": "tower_ruin" if tn % 3 == 1 or tz > WALL_Z1 - 8.0 else "tower"})
		tz += 48.0 if tz < WALL_Z1 - 50.0 else 24.0
		tn += 1
	feats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.z) < float(b.z))
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 37101 + side
	var cur := WALL_Z0
	var n_seg := 0
	for f: Dictionary in feats:
		var lo := float(f.z) - float(f.half)
		if lo < cur - 0.6:
			continue
		n_seg += _fill(wh, space, shapes, x, yaw, side, cur, lo, rng)
		match String(f.kind):
			"gate":
				_gatehouse(wh, space, shapes, x, yaw, side, float(f.z))
			"breach":
				_breach(wh, space, shapes, x, yaw, side, float(f.z), rng)
			_:
				_tower(wh, space, shapes, x, yaw, float(f.z), String(f.kind) == "tower_ruin")
		cur = float(f.z) + float(f.half)
	n_seg += _fill(wh, space, shapes, x, yaw, side, cur, WALL_Z1, rng)
	Kit.body(wh, "MarchWallBody_%d" % side, shapes)
	print("R37S wall side %d: %d segments, %d features, breaches at %s, gate at z %.1f" % [side, n_seg, feats.size(), bz, gz])


## A kit part's far silhouette under `host` (core/world/far_detail.gd): drawn from `end` m out to the horizon.
static func _far(host: Node3D, path: String, part: String, xf: Transform3D, end := FAR_END, fade_host := false) -> void:
	var m := Kit.mesh(path, part)
	if m != null:
		FarDetail.register(host, m, host.global_transform.affine_inverse() * xf, end, null, fade_host)


static func _base_y(space: PhysicsDirectSpaceState3D, x: float, z0: float, z1: float) -> float:
	var s := 0.0
	var n := 0
	var lo := INF
	for iz in 5:
		for ox: float in [-1.6, 0.0, 1.6]:
			var g := RealmLayout.ground(space, x + ox, lerpf(z0, z1, float(iz) / 4.0))
			s += g
			n += 1
			lo = minf(lo, g)
	return clampf(s / float(n) - 0.2, lo - 0.1, lo + 1.6)


## Plain segments between z a and b, each scaled to fit. Returns how many.
static func _fill(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, x: float, yaw: float, side: int, a: float, b: float, rng: RandomNumberGenerator) -> int:
	var len := b - a
	if len < 1.2:
		return 0
	var n := maxi(1, roundi(len / 12.0))
	var sl := len / float(n)
	var sx := sl / float(Data.WALL_LEN)
	for i in n:
		var z0 := a + sl * float(i)
		var z := z0 + sl * 0.5
		var by := _base_y(space, x, z0, z0 + sl)
		var r := rng.randf()
		var part := "WallSeg_A" if r < 0.6 else ("WallSeg_B" if r < 0.85 else "WallSeg_C")
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, 1.0, 1.0)), Vector3(x, by, z))
		Kit.put(wh, Kit.WALL, part, xf, WALL_VIS, true, "Seg_%d_%d" % [side, int(z)])
		_far(wh, Kit.WALL, "WallFar", xf)
		shapes.append([Kit.box(Vector3(sl + 0.3, 10.4, 2.7)), Transform3D(Basis(Vector3.UP, yaw), Vector3(x, by + 2.1, z))])
	return n


static func _tower(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, x: float, yaw: float, z: float, ruin: bool) -> void:
	var by := _base_y(space, x, z - 3.6, z + 3.6)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, by, z))
	Kit.put(wh, Kit.WALL, "TowerRuin" if ruin else "Tower", xf, WALL_VIS, true, "Tower_%d" % int(z))
	_far(wh, Kit.WALL, "TowerFar", xf)
	var h := 9.2 if ruin else float(Data.TOWER_H) + 0.6
	shapes.append([Kit.box(Vector3(float(Data.TOWER_S) * 0.98, h + 3.0, float(Data.TOWER_S) * 0.98)), Transform3D(Basis(Vector3.UP, yaw), Vector3(x, by + (h - 3.0) * 0.5, z))])


static func _gatehouse(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, x: float, yaw: float, side: int, z: float) -> void:
	var by := RealmLayout.ground(space, x, z) - 0.1
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, by, z))
	var id := "r37s_gate_w" if side < 0 else "r37s_gate_e"
	var h := _poi(wh, id, Vector3(x, by, z))
	Kit.put(h, Kit.WALL, "Gatehouse", xf, WALL_VIS, true, "Gatehouse")
	_far(h, Kit.WALL, "GateFar", xf, FAR_END, true)
	var px := float(Data.GATE_PX)
	var tw := float(Data.GATE_TW)
	var td := float(Data.GATE_TD)
	var gh := float(Data.GATE_H)
	var b := Basis(Vector3.UP, yaw)
	for sx: float in [-1.0, 1.0]:
		shapes.append([Kit.box(Vector3(tw * 0.98, gh + 3.0, td * 0.98)), Transform3D(b, xf * Vector3(sx * px, (gh - 3.0) * 0.5, 0.0))])
	# the room over the arch (the passage is clear to 7.8 m: the arch's crown)
	shapes.append([Kit.box(Vector3(float(Data.GATE_PW) + 1.0, 5.0, td * 0.9)), Transform3D(b, xf * Vector3(0.0, 10.4, 0.0))])
	# a plaque on the old Realm's side of the passage, beside the south tower, and a box at the north tower's foot
	var inside := -(b * Vector3(0, 0, 1))          # towards the old Realm (local -Z)
	var pq := Vector2(x + inside.x * (td * 0.5 + 1.8), z + px + 1.2)
	_stele(h, space, "poi_r37s_gate_w" if side < 0 else "poi_r37s_gate_e", pq, atan2(inside.x, inside.z) + PI, 1.5)
	var cp := Vector3(x + inside.x * (td * 0.5 + 1.2), 0.0, z - px - 0.5)
	cp.y = RealmLayout.ground(space, cp.x, cp.z) + 0.02
	_chest(h, id, cp, yaw)
	h.set_meta("r37_gate", true)


static func _breach(wh: Node3D, space: PhysicsDirectSpaceState3D, shapes: Array, x: float, yaw: float, side: int, z: float, rng: RandomNumberGenerator) -> void:
	var off := 10.2
	for s: int in [-1, 1]:
		var zz := z + float(s) * off
		var by := _base_y(space, x, zz - 3.2, zz + 3.2)
		# the stub's gap end is local +X; local +X is world -z on the east wall and +z on the west one
		var plus_z := side < 0
		var mirror: bool = (s < 0) != plus_z          # north stub (s<0) needs +X -> +z, south stub needs -z
		var sc := Vector3(-1.0 if mirror else 1.0, 1.0, 1.0)
		var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(sc), Vector3(x, by, zz))
		Kit.put(wh, Kit.WALL, "BreachStub", xf, WALL_VIS, true, "Stub_%d_%d" % [side, int(zz)])
		var rb := Basis(Vector3.UP, yaw)
		var ctr := func(lx: float) -> Vector3: return xf * Vector3(lx, 0.0, 0.0)
		for seg: Array in [[-2.9, 1.5, 6.4], [-1.0, 2.3, 5.4], [0.7, 1.8, 3.4], [2.1, 1.2, 1.8]]:
			var c: Vector3 = ctr.call(float(seg[0]))
			var hh := float(seg[2])
			shapes.append([Kit.box(Vector3(float(seg[1]), hh + 3.0, 2.6)), Transform3D(rb, Vector3(c.x, by + (hh - 3.0) * 0.5, c.z))])
	# the rubble the wall left in the gap: low enough to walk over, never a wall
	var gy := RealmLayout.ground(space, x, z)
	Kit.put(wh, Kit.WALL, "Rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, gy - 0.1, z)), WALL_VIS, false, "Rubble_%d_%d" % [side, int(z)])


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
	for part: String in ["Trunk", "Roots", "Limbs", "Crown", "Stair"]:
		Kit.put(h, Kit.OAK, part, xf, Vector2.ZERO, true)
	_far(h, Kit.OAK, "OakFar", xf, 120.0, true)
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
	# the crown deck: the top of the stair, where the secret is (site_r37_south.gd)
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
	var bn: Variant = wf.beacon(host, at, "", Color(0.42, 0.5, 0.34), 40.0, 0.3, 24.0)
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
	k.box("lore_tstone", o + b * Vector3(0, 0.1, 0), Vector3(0.9, 0.2, 0.55), b, false, 0.8)
	k.box("lore_tstone", o + b * Vector3(0, 0.75, 0), Vector3(0.55, 1.3, 0.18), b, true, 0.92)
	k.commit(host, "Stele_" + id)
	P._lore(host, id, o + b * Vector3(0.0, 0.95, -0.5), o + b * Vector3(0, 0.95, -0.1))


# =================================================================================================
# THE WELL OF ECHOES
# =================================================================================================

## The pit wall's radius at height y along angle a: where the ground (rising with radius) reaches y.
static func _wall_r(space: PhysicsDirectSpaceState3D, c: Vector2, a: float, y: float, r_max: float) -> float:
	var lo := 0.5
	var hi := r_max
	for i in 14:
		var m := (lo + hi) * 0.5
		var g := RealmLayout.ground(space, c.x + sin(a) * m, c.y + cos(a) * m)
		if g < y:
			lo = m
		else:
			hi = m
	return (lo + hi) * 0.5


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
	_chest(h, "r37s_well_landing", land_pos + lb * Vector3(0.0, 0.37, 1.8), th_cave)
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
	var bn: Variant = wf.beacon(host, Vector3(wc.x, rim_y, wc.y), "", Color(0.34, 0.5, 0.6), 30.0, 0.3, 12.0)
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

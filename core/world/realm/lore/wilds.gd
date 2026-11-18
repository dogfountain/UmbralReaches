extends RefCounted
## The Thornwood's scattered ruins: the abbey's boundary wall with its boundary stone where the west
## way breaks through, old-tongue tablets of the Rooted, a saint pulled down face-first into the
## moss, outlying standing stones, a woodcutter's ruined hut, broken field walls. All kept well off
## Thorn Henge (c (-72, -18) r 16 + its terrace), the paths and every registered site. Then the
## Ninth Company's camp, grave and ring (scenes.gd).

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Cottage := preload("res://core/world/realm/lore/cottage.gd")
const LA := preload("res://core/world/realm/lore/lore_assets.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
## The Song of the Ring: four verses on stones round the henge hill, one per quarter.
const SONG := [
	["tw_song_1", [Vector2(-56.0, 10.0), Vector2(-64.0, 12.0), Vector2(-84.0, 9.0), Vector2(-68.0, 12.0), Vector2(-90.0, 6.0), Vector2(-60.0, 14.0)]],
	["tw_song_2", [Vector2(-104.0, -22.0), Vector2(-100.0, -26.0), Vector2(-102.0, -30.0), Vector2(-103.0, -14.0)]],
	["tw_song_3", [Vector2(-88.0, -46.0), Vector2(-84.0, -50.0), Vector2(-92.0, -42.0), Vector2(-80.0, -48.0)]],
	["tw_song_4", [Vector2(-56.0, -44.0), Vector2(-60.0, -48.0), Vector2(-66.0, -53.0), Vector2(-58.0, -52.0), Vector2(-76.0, -54.0), Vector2(-52.0, -40.0)]],
]
const HENGE_KEEP := 64.0   # the raid floor (RealmLayout.RAIDS henge, r 49.6 since 18 Nov) and its fill skirt


static func ok_henge(q: Vector2, r := 0.0) -> bool:
	return q.distance_to(RealmLayout.HENGE_C) > HENGE_KEEP + r


## r34 layout: the henge moved and its hill grew a raid floor; a stone that stood on the old hill is
## carried straight out from the Ring to the hill's foot, past the floor's skirt (the verse still faces away).
static func off_henge(q: Vector2, r := 0.0) -> Vector2:
	var d := q - RealmLayout.HENGE_C
	var raid := RealmLayout.raid("henge")
	var need := maxf(HENGE_KEEP + r + 1.0, float(raid.get("r", 0.0)) + float(raid.get("fall", 0.0)) + 3.0 + r)   # past the hill's skirt
	if d.length() >= need:
		return q
	return RealmLayout.HENGE_C + (d.normalized() if d.length() > 0.1 else Vector2.RIGHT) * need


## r34 layout: off_henge(q) and, when q had to move, the same spot swung round the hill and a little
## further out (the foot of the hill is busier than the old hillside was: the Charcoal Hollow, the wall).
static func off_henge_cands(q: Vector2, r := 0.0) -> Array:
	var q0 := off_henge(q, r)
	if q0 == q:
		return [q]
	var out := [q0]
	var d := q0 - RealmLayout.HENGE_C
	for k: float in [0.0, 6.0]:
		for a: float in [0.0, 0.22, -0.22, 0.45, -0.45]:
			if k == 0.0 and a == 0.0:
				continue
			out.append(RealmLayout.HENGE_C + d.rotated(a).normalized() * (d.length() + k))
	return out


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "ThornwoodRuins", 4040)
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	# --- the abbey bounds: a long broken wall, a gap where the west way passes ------------------
	# (18 Nov: from (-61, 31)..(-53.5, 4.5), on the henge's 1.6x floor; map audit: (-56, 58)..(-48, 36) lay across the
	# Singing Stones and never placed, everything round the chapel yard is the sexton's ground and Perrin's camp, and the
	# meadow west of meadow_way is the henge hill's skirt. Now in the old rift's meadow east of meadow_way, open ground)
	var wa := Vector2(-3.0, -30.0)
	var wb := Vector2(9.0, -42.0)
	var r := Rect2(wa, Vector2.ZERO).expand(wb).grow(0.8)
	if LK.clear_of(r, 0.6):
		L.site("tw_bounds", r, L.g(r.get_center().x, r.get_center().y))
		L.drystone(Vector3(wa.x, 0, wa.y), Vector3(wb.x, 0, wb.y), 1.3, 0.5, "lore_moss")
		var bs: Vector3 = L.gv(wb.x + 1.6, wb.y - 0.6)
		var bfp: Vector3 = L.waystone(bs, atan2(-(1.0), -(-0.4)), 1.2, "lore_moss")
		L.scrap("tw_boundary", bfp, bfp + Vector3.UP * 0.25)
	else:
		print("REALM_LORE skip abbey bounds")
		PlacementLog.skip("lore", "tw_bounds", Vector3(wa.x, 0, wa.y), "not clear")
	# --- the abbey woodsmen's camp: felled oaks, stumps, a cold fire, the foreman's notice ---------
	# (r34: placed before the tablets and the songs, which the moved henge pushed out onto its ground)
	_woodsmen(L)
	# --- old-tongue tablets ----------------------------------------------------------------------
	for t: Array in [[Vector2(-97.0, 8.0), "tw_climbs"], [Vector2(-47.0, -36.0), "tw_ring"], [Vector2(-96.0, -47.0), "tw_heart"]]:
		var q: Vector2 = off_henge(t[0], 1.4)
		for qc: Vector2 in off_henge_cands(t[0], 1.4):      # r34: the first clear one round the hill
			if LK.clear_of(Rect2(qc - Vector2(1.4, 1.4), Vector2(2.8, 2.8)), 0.5):
				q = qc
				break
		if not ok_henge(q):
			continue
		var at: Vector3 = L.gv(q.x, q.y)
		if not L.spot(String(t[1]), at, 1.4, 0.5):
			continue
		var to_h := RealmLayout.HENGE_C - q
		var yaw := atan2(-to_h.x, -to_h.y) + PI          # the carved face turns from the Ring
		var fp: Vector3 = L.rune_stone(at, yaw, rng.randf_range(1.5, 1.9))
		for j in 3:
			L.stone(L.p, at + Basis(Vector3.UP, rng.randf() * TAU) * Vector3(rng.randf_range(0.7, 1.1), 0, 0), Vector3(0.4, 0.3, 0.35) * rng.randf_range(0.7, 1.3), "lore_moss", false, 0.4)
		L.scrap(String(t[1]), fp, fp + Vector3.UP * 0.6)
	# --- the fallen saint ----------------------------------------------------------------------
	var fs := Vector2(-50.0, -84.0)           # (18 Nov: from (-88, 24), on the henge's 1.6x floor)
	var fsv: Vector3 = L.gv(fs.x, fs.y)
	if L.spot("tw_saint", fsv, 2.2, 0.5):
		var pq: Vector3 = L.gv(fsv.x + 1.6, fsv.z + 0.3)
		k.box("lore_tstone", pq + Vector3.UP * 0.1, Vector3(1.0, 0.9, 0.9), Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, 0.12), true, 0.75)   # its plinth
		k.box("lore_tstone", pq + Vector3(0.15, 0.6, 0.0), Vector3(1.1, 0.12, 1.0), Basis(Vector3.UP, 0.3) * Basis(Vector3.BACK, 0.12), false, 0.85)
		var sq: Vector3 = L.gv(fsv.x - 0.4, fsv.z - 0.2)
		L.fallen_saint(sq + Vector3.DOWN * 0.08, -1.9, 0, true)
		L.rubble(k, fsv + Vector3(1.9, 0, 1.0), 1.0, 7, "lore_tstone", false)
		L.scrap("tw_saint", fsv + Vector3(0.6, 0.3, 1.6))
	# --- outlying standing stones of the Rooted ------------------------------------------------
	for q2v: Vector2 in [Vector2(-99.0, -22.0), Vector2(-69.0, -50.0), Vector2(-43.0, -4.0)]:
		var q2 := off_henge(q2v, 1.0)
		if not ok_henge(q2):
			continue
		var at2: Vector3 = L.gv(q2.x, q2.y)
		if not L.spot("tw_menhir_%d" % int(q2v.x), at2, 1.0, 0.5):
			continue
		var h := rng.randf_range(2.6, 3.6)
		var xf2 := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)), at2 + Vector3.DOWN * 0.15)
		if LK.rk():
			L.rock(LK.rk().call("slab", rng.randi(), Vector3(1.1, h, 0.7), "mossy", 0.35, false), xf2, true)
		else:
			var cm := CreatureMesh.new(rng.randi())
			cm.tube(PackedVector3Array([Vector3(0, -0.6, 0), Vector3(0, h * 0.4, 0), Vector3(0.06, h * 0.8, 0), Vector3(0.02, h, 0)]), PackedFloat32Array([0.55, 0.5, 0.42, 0.14]), 9, Color(1, 1, 1), 0.0, 0.14, 0.0, Vector2(1.0, 0.6))
			LK.organic(k, "lore_moss", cm.commit(), xf2, true)
	# --- the woodcutter's hut --------------------------------------------------------------------
	var hc := Vector2(-104.0, 46.0)          # (map audit: from (-101, 38), on the henge hill's 1.6x skirt's fall: the hut stood level with its high side and tw_cutter floated 3.5 m)
	var hr := Rect2(hc - Vector2(4.0, 4.0), Vector2(8.0, 8.0))
	if LK.clear_of(hr, 0.6):
		var hut: Dictionary = Cottage.build(L, "tw_hut", hc, 4.6, 3.8, 0.4, "ruin", "thatch")
		var hx: Transform3D = hut.xf
		var stump := hx * Vector3(1.0, 0, -3.4)
		stump.y = L.g(stump.x, stump.z)
		var cm2 := CreatureMesh.new(44)
		cm2.tube(PackedVector3Array([Vector3(0, -0.1, 0), Vector3(0, 0.45, 0), Vector3(0, 0.55, 0)]), PackedFloat32Array([0.42, 0.36, 0.35]), 11, Color(0.75, 0.65, 0.55), 0.0, 0.18)
		LK.organic(k, "lore_beam", cm2.commit(), Transform3D(Basis.IDENTITY, stump), true)
		k.box("iron", stump + Vector3(0.05, 0.62, 0), Vector3(0.05, 0.16, 0.24), Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.4), false, 0.7)
		k.box("lore_beam", stump + Vector3(0.05, 0.85, 0.12), Vector3(0.05, 0.6, 0.05), Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.4), false, 0.7)
		var notch := hx * Vector3(-1.2, 1.3, -1.9 - 0.02)
		for j in 4:
			L.p.box("lore_rune" if j < 3 else "lore_cold", notch + hx.basis * Vector3(-0.2 + 0.1 * float(j), 0, -0.01), Vector3(0.025, 0.22, 0.01), hx.basis * Basis(Vector3.BACK, 0.0 if j < 3 else 0.785), false, 0.6)
		L.scrap("tw_cutter", hx * Vector3(-1.2, 0.3, -2.8))
	else:
		print("REALM_LORE skip woodcutter's hut")
		PlacementLog.skip("lore", "woodcutters_hut", Vector3.ZERO, "not clear")
	# --- the Song of the Ring -----------------------------------------------------------------------
	for sv: Array in SONG:
		var cands: Array = []
		for q3v: Vector2 in sv[1]:
			for q3: Vector2 in off_henge_cands(q3v, 2.5):
				if ok_henge(q3, 2.0) and not q3 in cands:
					cands.append(q3)
		var sa: Vector3 = L.spot_any(String(sv[0]), cands, 1.4, 0.5)
		if sa == Vector3.INF:
			continue
		var to_h3 := RealmLayout.HENGE_C - Vector2(sa.x, sa.z)
		var yaw3 := atan2(-to_h3.x, -to_h3.y) + PI
		var fp3: Vector3 = L.rune_stone(sa, yaw3, rng.randf_range(1.7, 2.1))
		if String(sv[0]) == "tw_song_4":
			# the Order's hand over the chiselled verse
			L.panel(fp3 + Basis(Vector3.UP, yaw3) * Vector3(0, 0.55, 0.0), Basis(Vector3.UP, yaw3) * Vector3(0, 0, -1), 0.42, 0.24, LA.C_TEXT)
		for j3 in 2:
			L.stone(L.p, sa + Basis(Vector3.UP, rng.randf() * TAU) * Vector3(rng.randf_range(0.8, 1.2), 0, 0), Vector3(0.35, 0.25, 0.3) * rng.randf_range(0.7, 1.3), "lore_moss", false, 0.4)
		L.scrap(String(sv[0]), fp3, fp3 + Vector3.UP * 0.6)
	# --- broken field walls deep in the wood ---------------------------------------------------
	for wl: Array in [[Vector2(-104, -8), Vector2(-92, 2)], [Vector2(-90, -60), Vector2(-74, -64)], [Vector2(-54, -50), Vector2(-40, -58)], [Vector2(-84, 40), Vector2(-96, 44)]]:
		var a: Vector2 = wl[0]
		var b: Vector2 = wl[1]
		if not ok_henge(a) or not ok_henge(b):
			continue
		var rr := Rect2(a, Vector2.ZERO).expand(b).grow(0.7)
		if not LK.clear_of(rr, 0.6):
			print("REALM_LORE skip thornwood wall ", a)
			PlacementLog.skip("lore", "tw_wall_%d_%d" % [int(a.x), int(a.y)], Vector3(a.x, 0, a.y), "not clear")
			continue
		L.site("tw_wall_%d_%d" % [int(a.x), int(a.y)], rr, L.g(rr.get_center().x, rr.get_center().y))
		L.drystone(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), 1.1, 0.6, "lore_moss", L.p)
	L.finish()
	L.note("Thornwood ruins", Vector3(-80, 0, 0))
	# r28: the Ninth Company's three places, deeper in the wood (scenes.gd)
	if not "--no-r28-secrets" in OS.get_cmdline_user_args():     # A/B switch for perf measurements
		(load("res://core/world/realm/lore/scenes.gd") as GDScript).call("build", parent)


static func _woodsmen(L: RefCounted) -> void:
	var k: OssKit = L.k
	var p: OssKit = L.p
	var rng: RandomNumberGenerator = L.rng
	var c := Vector2.INF
	for q: Vector2 in [Vector2(-76.0, 22.0), Vector2(-80.0, 13.0), Vector2(-68.0, 20.0), Vector2(-92.0, 12.0), Vector2(-104.0, 16.0), Vector2(-112.0, 4.0),
			Vector2(-118.0, 40.0), Vector2(-130.0, 52.0), Vector2(-112.0, 72.0)]:   # r34: two more, west of the moved henge; 18 Nov: three past its 1.6x skirt
		var r := Rect2(q - Vector2(4.5, 4.5), Vector2(9.0, 9.0))
		if ok_henge(q, 5.0) and LK.clear_of(r, 0.6):
			c = q
			break
	if c == Vector2.INF:
		print("REALM_LORE skip the woodsmen's camp")
		PlacementLog.skip("lore", "woodsmens_camp", Vector3(-76, 0, 22), "no clear spot")
		return
	var rr := Rect2(c - Vector2(4.5, 4.5), Vector2(9.0, 9.0))
	var gr: Vector2 = L.g_range(rr)
	L.site("tw_woodsmen", rr, gr.x)
	# two felled oaks, trimmed, lying side by side on skids
	for i in 2:
		var o := Vector3(c.x - 1.0 + float(i) * 1.6, 0, c.y + 1.6)
		o.y = L.g(o.x, o.z)
		var yaw := 0.3 + float(i) * 0.12
		var lb := Basis(Vector3.UP, yaw)
		var trunk: ArrayMesh = LK.pooled("felled_oak%d" % i, func() -> ArrayMesh:
			var cm := CreatureMesh.new(70 + i)
			cm.tube(PackedVector3Array([Vector3(0, 0, -3.2), Vector3(0, 0.03, -1.0), Vector3(0, 0.0, 1.2), Vector3(0, -0.02, 3.0)]), PackedFloat32Array([0.5, 0.46, 0.42, 0.36]), 12, Color(0.7, 0.62, 0.55), 0.0, 0.12)
			cm.blob(Vector3(0, 0, -3.21), Vector3(0.48, 0.48, 0.02), Basis.IDENTITY, Color(1.25, 1.1, 0.85), 0.0, 0.0, 0.0, 2, 12)   # the pale cut face
			return cm.commit())
		LK.organic(k, "lore_beam", trunk, Transform3D(lb, o + Vector3.UP * (0.42 + 0.12)), true)
		for z in [-1.8, 1.8]:
			k.box("lore_beam", o + lb * Vector3(0, 0.06, float(z)), Vector3(1.0, 0.14, 0.16), lb * Basis(Vector3.UP, PI * 0.5 + 0.0), false, 0.6)
	# stumps, one with an axe left in it, chips about
	for j in 4:
		var sq := Vector3(c.x + rng.randf_range(-3.6, 3.6), 0, c.y - 2.2 + rng.randf_range(-1.6, 1.0))
		sq.y = L.g(sq.x, sq.z)
		var stump: ArrayMesh = LK.pooled("stump%d" % (j % 2), func() -> ArrayMesh:
			var cm := CreatureMesh.new(60 + j % 2)
			cm.tube(PackedVector3Array([Vector3(0, -0.15, 0), Vector3(0, 0.3, 0), Vector3(0, 0.5, 0)]), PackedFloat32Array([0.55, 0.46, 0.44]), 12, Color(0.72, 0.62, 0.52), 0.0, 0.18)
			cm.blob(Vector3(0, 0.5, 0), Vector3(0.43, 0.02, 0.43), Basis.IDENTITY, Color(1.2, 1.05, 0.8), 0.0, 0.0, 0.0, 2, 12)
			for rt in 4:
				var a := TAU * float(rt) / 4.0 + 0.4
				cm.tube(PackedVector3Array([Vector3(cos(a) * 0.35, 0.15, sin(a) * 0.35), Vector3(cos(a) * 0.75, -0.05, sin(a) * 0.75), Vector3(cos(a) * 1.0, -0.15, sin(a) * 1.0)]), PackedFloat32Array([0.16, 0.09, 0.04]), 6, Color(0.7, 0.6, 0.5), 0.0, 0.2)
			return cm.commit())
		LK.organic(k, "lore_beam", stump, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), sq), true)
		if j == 0:
			k.box("iron", sq + Vector3(0.05, 0.6, 0), Vector3(0.05, 0.18, 0.26), Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.4), false, 0.7)
			k.box("lore_beam", sq + Vector3(0.05, 0.88, 0.14), Vector3(0.05, 0.65, 0.05), Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, 0.4), false, 0.7)
	# a two-man saw on a sawhorse, a cold fire ring
	var sh := Vector3(c.x + 2.8, 0, c.y + 3.2)
	sh.y = L.g(sh.x, sh.z)
	for e: float in [-0.5, 0.5]:
		for sgn: float in [-1.0, 1.0]:
			p.box("lore_beam", sh + Vector3(e, 0.4, sgn * 0.18), Vector3(0.07, 0.9, 0.07), Basis(Vector3.RIGHT, -sgn * 0.35), false, 0.6)
	p.box("lore_beam", sh + Vector3(0, 0.78, 0), Vector3(1.3, 0.1, 0.1), Basis.IDENTITY, true, 0.65)
	p.box("iron", sh + Vector3(0.1, 0.86, 0.0), Vector3(1.5, 0.12, 0.012), Basis(Vector3.UP, 0.1), false, 0.75)
	var fr := Vector3(c.x - 2.6, 0, c.y - 0.6)
	fr.y = L.g(fr.x, fr.z)
	for i2 in 8:
		var a2 := TAU * float(i2) / 8.0
		L.stone(p, fr + Vector3(cos(a2) * 0.6, 0.05, sin(a2) * 0.6), Vector3(0.24, 0.16, 0.2), "lore_rock", false, 0.3)
	p.box("lore_char", fr + Vector3.UP * 0.03, Vector3(0.7, 0.05, 0.6), Basis(Vector3.UP, 0.4), false, 0.5)
	# the foreman's notice on two posts
	var nb := Vector3(c.x + 0.4, 0, c.y - 3.4)
	nb.y = L.g(nb.x, nb.z)
	var to := Vector2(c.x, c.y + 8.0) - Vector2(nb.x, nb.z)
	var b := Basis(Vector3.UP, atan2(-to.x, -to.y) + PI)
	for sgn2: float in [-1.0, 1.0]:
		k.box("lore_beam", nb + b * Vector3(sgn2 * 0.6, 0.85, 0), Vector3(0.12, 1.9, 0.12), b, true, 0.65)
	k.box("lore_beam", nb + b * Vector3(0, 1.35, 0), Vector3(1.3, 0.7, 0.05), b, true, 0.6)
	L.page(nb + b * Vector3(-0.15, 1.38, -0.035), b * Vector3(0, 0, -1), 0.15)
	L.page(nb + b * Vector3(0.3, 1.32, -0.035), b * Vector3(0, 0, -1), 0.25)
	L.scrap("tw_axe", nb + b * Vector3(0, 0.3, -1.0), nb + b * Vector3(0, 1.35, -0.1))
	L.note("The Woodsmen's Camp", Vector3(c.x, gr.x, c.y))


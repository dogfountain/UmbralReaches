extends RefCounted
## The Barrow Field (RealmLayout.BARROWS_C) and the Hollow Fen's drowned graves.
## Barrows: long earthen mounds ringed with kerb stones, a stone passage mouth on each (three-stone
## portal, capstone), sealed: a slab barred with iron and the Abbot's sigil; the oldest one is the
## Rooted's, its mouth carved with the old tongue. A few toppled standing stones, a waymark at the
## head of the fen descent. Fen graves: leaning markers sunk to their shoulders, three stones laid
## on each (eyes, mouth, heart); Corvin's lamp-post; Wenna's last page.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const LA := preload("res://core/world/realm/lore/lore_assets.gd")
const Cottage := preload("res://core/world/realm/lore/cottage.gd")
const RealmLand_WATER := -0.9           ## RealmLand.WATER_Y (fen pool surface)

## [centre, length (along yaw), width, height, yaw (mouth faces local -z), lore id or ""]
const MOUNDS := [
	[Vector2(95.0, -47.0), 13.0, 7.5, 2.6, 1.5708, "br_seal"],
	[Vector2(88.0, -58.0), 10.0, 6.5, 2.2, 0.9, "br_rooted"],
	[Vector2(99.0, -66.0), 8.0, 5.5, 1.9, 1.2, "br_broken"],
]


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "BarrowField", 8080)
	var seal_light := Vector3.INF
	for m: Array in MOUNDS:
		var lp := _barrow(L, m[0], float(m[1]), float(m[2]), float(m[3]), float(m[4]), String(m[5]))
		if String(m[5]) == "br_seal":
			seal_light = lp
	# toppled standing stones
	for q: Vector2 in [Vector2(64.0, -30.0), Vector2(91.0, -27.0), Vector2(78.0, -64.0)]:
		var at: Vector3 = L.gv(q.x, q.y)
		if not L.spot("br_stone_%d" % int(q.x), at, 1.8, 0.5):
			continue
		var lie := Basis(Vector3.UP, L.rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5 - 0.12)
		if LK.rk():
			L.rock(LK.rk().call("slab", L.rng.randi(), Vector3(1.0, 2.9, 0.6), "mossy", 0.3, false), Transform3D(lie, at + Vector3.UP * 0.05), true)
		else:
			var cm := CreatureMesh.new(L.rng.randi())
			cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1.2, 0), Vector3(0.05, 2.4, 0), Vector3(0, 2.9, 0)]), PackedFloat32Array([0.45, 0.42, 0.34, 0.1]), 8, Color(1, 1, 1), 0.0, 0.14, 0.0, Vector2(1.0, 0.55))
			LK.organic(L.k, "lore_moss", cm.commit(), Transform3D(lie, at + Vector3.UP * 0.12), true)
	var standing: Vector3 = L.gv(69.0, -63.0)
	if L.spot("br_menhir", standing, 1.0, 0.5):
		L.rune_stone(standing, 0.8, 2.2)
	# the waymark at the head of the descent
	var wm := Vector2(76.0, -48.5)
	var wv: Vector3 = L.gv(wm.x, wm.y)
	if L.spot("br_waymark", wv, 0.8, 0.2):
		var d := Vector2(70.0, -45.0) - wm
		var fp2: Vector3 = L.waystone(wv, atan2(-d.x, -d.y) + 0.5, 1.3, "lore_moss")
		L.scrap("br_descent", fp2, fp2 + Vector3.UP * 0.25)
	if seal_light != Vector3.INF:
		L.light("SealedBarrow", seal_light, Color(0.5, 0.75, 1.0), 0.7, 5.0)
	_lodge(L)
	# leaves of the Tally down the fen descent, and Wenna's last page at the crypt's door
	var desc_len := 0.0
	var dp: Array = LK.path_pts("fen_descent")
	for i in dp.size() - 1:
		desc_len += (dp[i] as Vector2).distance_to(dp[i + 1])
	var plan := {"br_tally_3": [14.0, 18.0, 10.0, 22.0], "br_tally_4": [26.0, 30.0, 23.0, 33.0]}
	var jn9: Array = []
	var sj := desc_len - 5.0
	while sj > desc_len - 22.0:
		jn9.append(sj)
		sj -= 2.0
	plan["jn_9"] = jn9
	for tid: String in ["br_tally_3", "br_tally_4", "jn_9"]:
		var cands: Array = []
		for sv: float in plan[tid]:
			for off: float in [3.3, 4.3, 5.5]:
				for sd: float in [1.0, -1.0]:
					cands.append(LK.beside_path("fen_descent", sv, sd, off))
		var td := [tid]
		var ta: Vector3 = L.spot_any(tid, cands, 0.8, 0.4, 1.2)
		if ta == Vector3.INF:
			continue
		var ty: float = (L.rng as RandomNumberGenerator).randf() * TAU
		var tb := Basis(Vector3.UP, ty)
		if String(td[0]) == "jn_9":
			L.stone(L.k, ta, Vector3(0.8, 0.35, 0.6), "lore_rock", true, 0.3)
			L.page(ta + Vector3.UP * 0.15, Vector3(0.03, 1, 0).normalized())
			L.k.candle_cluster(ta + tb * Vector3(0.45, 0.0, 0.3), 1, 0.02, L.rng)
			L.scrap("jn_9", ta + tb * Vector3(0, 0.35, -0.9), ta + Vector3.UP * 0.2)
		else:
			# a post with the leaf nailed to it, a heap of counting pebbles at its foot
			L.p.box("lore_beam", ta + Vector3.UP * 0.6, Vector3(0.14, 1.6, 0.14), tb * Basis(Vector3.BACK, 0.08), true, 0.65)
			L.page(ta + tb * Vector3(0, 1.0, -0.075), tb * Vector3(0, 0, -1), 0.15)
			L.cairn(L.p, ta + tb * Vector3(0.4, 0, -0.3), 0.3)
			L.scrap(String(td[0]), ta + tb * Vector3(0, 0.3, -0.9), ta + tb * Vector3(0, 1.0, -0.1))
	L.finish()
	L.note("The Barrow Field", Vector3(78, 0, -42))
	_fen(parent)


## Returns where a light in front of the mouth would go (Vector3.INF when no spot was found).
static func _barrow(L: RefCounted, c: Vector2, ln: float, wd: float, ht: float, yaw: float, lore_id: String) -> Vector3:
	var k: OssKit = L.k
	var rng: RandomNumberGenerator = L.rng
	var b := Basis(Vector3.UP, yaw)
	var ext := Vector2(absf(b.x.x) * wd + absf(b.z.x) * ln, absf(b.x.z) * wd + absf(b.z.z) * ln) * 0.5 + Vector2(1.6, 1.6)
	# find dry, clear ground near the planned centre (the fen pools move with the land's noise)
	var found := false
	var r := Rect2()
	for ring in 6:
		for k2 in maxi(1, ring * 6):
			var a := TAU * float(k2) / float(maxi(1, ring * 6))
			var cc := c + Vector2(cos(a), sin(a)) * float(ring) * 3.0
			var rr := Rect2(cc - ext, ext * 2.0)
			if RealmLayout.BOUNDS.grow(-3.0).encloses(rr) and LK.clear_of(rr, 0.8) and (L.g_range(rr.grow(-1.0)) as Vector2).x > RealmLand_WATER + 0.25:
				r = rr
				c = cc
				found = true
				break
		if found:
			break
	if not found:
		print("REALM_LORE skip barrow at ", c)
		return Vector3.INF
	var gr: Vector2 = L.g_range(r.grow(-1.6))
	L.site("barrow_%d_%d" % [int(c.x), int(c.y)], r, gr.x)
	var at := Vector3(c.x, gr.x, c.y)
	# the mound: a squat lumpy ellipsoid, a third of it below grade
	var cm := CreatureMesh.new(rng.randi())
	cm.blob(Vector3.ZERO, Vector3(wd * 0.5, ht * 1.35, ln * 0.5), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.08, 0.0, 10, 18)
	LK.organic(k, "lore_earth", cm.commit(), Transform3D(b, at + Vector3.DOWN * (ht * 0.35)), true)
	# kerb ring
	var n := int((ln + wd) * 0.9)
	for i in n:
		var a := TAU * float(i) / float(n)
		var q := Vector3(sin(a) * (wd * 0.5 + 0.3), 0, cos(a) * (ln * 0.5 + 0.3))
		if absf(a - PI) < 0.35:
			continue                       # leave the mouth's forecourt open
		var w := at + b * q
		w.y = L.g(w.x, w.z)
		if rng.randf() < 0.2:
			continue
		L.stone(L.p, w, Vector3(rng.randf_range(0.4, 0.7), rng.randf_range(0.35, 0.7), rng.randf_range(0.3, 0.5)), "lore_moss", false, 0.35)
	# the passage mouth (three-stone portal) on local -z, cut into the mound's flank
	var mouth := at + b * Vector3(0, 0, -ln * 0.5 + 0.6)
	mouth.y = L.g(mouth.x, mouth.z)
	var old := lore_id == "br_rooted"
	var key := "lore_moss" if old else "lore_tstone"
	for s: float in [-1.0, 1.0]:
		k.box(key, mouth + b * Vector3(s * 0.85, 0.75, 0), Vector3(0.45, 2.1, 0.6), b * Basis(Vector3.BACK, -s * 0.05), true, 0.85)
	k.box(key, mouth + b * Vector3(0, 1.85, 0.05), Vector3(2.4, 0.5, 0.95), b, true, 0.8)
	# forecourt flags and a dark passage beyond the seal
	k.box("dark", mouth + b * Vector3(0, 0.8, 0.45), Vector3(1.3, 1.8, 0.4), b, false, 0.12)
	if lore_id == "br_broken":
		# broken from inside: the slab thrown down face first, the bars bent outward
		k.box("lore_tstone", mouth + b * Vector3(0.2, 0.12, -1.3), Vector3(1.3, 0.22, 1.8), b * Basis(Vector3.UP, 0.25) * Basis(Vector3.BACK, 0.06), true, 0.9)
		for j in 3:
			var yy := 0.35 + 0.5 * float(j)
			var bend := b * Basis(Vector3.RIGHT, -0.5 - 0.25 * float(j)) * Basis(Vector3.UP, (float(j) - 1.0) * 0.3)
			k.box("iron", mouth + b * Vector3(-0.55, yy, -0.2) + bend * Vector3(0.45, 0, 0), Vector3(0.9, 0.07, 0.05), bend, false, 0.55)
			k.box("iron", mouth + b * Vector3(0.55, yy + 0.1, -0.25) + bend * Vector3(-0.4, 0, 0), Vector3(0.8, 0.07, 0.05), bend * Basis(Vector3.UP, 0.4), false, 0.55)
		k.box("dark", mouth + b * Vector3(0, 0.8, 0.12), Vector3(1.3, 1.8, 0.1), b, false, 0.05)
		L.panel(mouth + b * Vector3(0, 1.85, -0.49), -b.z, 0.6, 0.4, LA.C_SIGIL)
		# Wenna's seventh page, weighted with a kerb stone by the forecourt
		var wp := mouth + b * Vector3(1.5, 0, -1.6)
		wp.y = L.g(wp.x, wp.z)
		L.stone(L.k, wp, Vector3(0.7, 0.28, 0.55), "lore_rock", true, 0.3)
		L.page(wp + Vector3.UP * 0.13, Vector3(0.05, 1, 0).normalized())
		L.scrap("jn_7", wp + b * Vector3(0.2, 0.35, -0.9), wp + Vector3.UP * 0.15)
	elif not old:
		# sealed: a slab with iron bars and the Abbot's sigil (a ring and an upright bar)
		k.box("lore_tstone", mouth + b * Vector3(0, 0.75, 0.08), Vector3(1.3, 1.8, 0.22), b, true, 0.95)
		for yy: float in [0.35, 0.85, 1.35]:
			k.box("iron", mouth + b * Vector3(0, yy, -0.06), Vector3(1.9, 0.08, 0.05), b, false, 0.6)
		k.box("iron", mouth + b * Vector3(0, 0.85, -0.07), Vector3(0.06, 1.3, 0.05), b, false, 0.6)
		var ring := CreatureMesh.new(5)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for i in 13:
			var a2 := TAU * float(i) / 12.0
			pts.append(Vector3(cos(a2) * 0.28, sin(a2) * 0.28, 0))
			rad.append(0.025)
		ring.tube(pts, rad, 5, Color(0.7, 0.68, 0.7), 0.0, 0.0)
		LK.organic(k, "iron", ring.commit(), Transform3D(b, mouth + b * Vector3(0, 1.0, -0.09)))
		k.box("lore_cold", mouth + b * Vector3(0, 1.0, -0.1), Vector3(0.1, 0.1, 0.01), b * Basis(Vector3.BACK, PI * 0.25), false, 0.45)
		L.panel(mouth + b * Vector3(0, 1.85, -0.49), -b.z, 0.6, 0.4, LA.C_SIGIL)
		L.letters(mouth + b * Vector3(0, 1.62, -0.48), b * Vector3(0, 0, -1), 1.0, 1)
	else:
		# the Rooted's mouth: open, a carved threshold stone across it, spirals of the old tongue
		k.box(key, mouth + b * Vector3(0, 0.2, -0.3), Vector3(1.6, 0.4, 0.4), b, true, 0.85)
		for i in 6:
			var a3 := float(i) * 1.1
			L.p.box("lore_cold", mouth + b * Vector3(-0.85 + 0.02 * float(i % 2), 0.6 + 0.2 * float(i), -0.31), Vector3(0.18, 0.016, 0.01), b * Basis(Vector3.BACK, a3), false, 0.5)
			L.p.box("lore_cold", mouth + b * Vector3(0.85, 0.6 + 0.2 * float(i), -0.31), Vector3(0.18, 0.016, 0.01), b * Basis(Vector3.BACK, -a3), false, 0.5)
		L.rubble(k, mouth + b * Vector3(1.6, 0, -0.8), 0.9, 6, key, false)
	if lore_id != "":
		L.scrap(lore_id, mouth + b * Vector3(0, 0.3, -1.4) + (b * Vector3(-0.9, 0, 0) if lore_id == "br_broken" else Vector3.ZERO), mouth + Vector3.UP * 1.6)
	return mouth + b * Vector3(0, 1.1, -1.3)


static func _fen(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "DrownedGraves", 9090)
	var rng: RandomNumberGenerator = L.rng
	# [centre, count, lore ids for the first markers]
	var clusters := [
		[Vector2(55.0, 22.0), 7, ["fen_stones", "jn_6"]],
		[Vector2(92.0, 8.0), 8, ["fen_marta", "fen_corvin", "fen_rite"]],
		[Vector2(70.0, -4.0), 6, ["fen_noname"]],
		[Vector2(60.0, -30.0), 5, ["jn_8"]],
	]
	for cl: Array in clusters:
		var c: Vector2 = cl[0]
		var r := Rect2(c - Vector2(5.0, 5.0), Vector2(10.0, 10.0))
		if not LK.clear_of(r, 0.8):
			r = Rect2(c - Vector2(3.5, 3.5), Vector2(7.0, 7.0))
			if not LK.clear_of(r, 0.5):
				print("REALM_LORE skip fen cluster ", c)
				continue
		var gr: Vector2 = L.g_range(r)
		L.site("fen_graves_%d_%d" % [int(c.x), int(c.y)], r, gr.x)
		var ids: Array = cl[2]
		for i in int(cl[1]):
			var id := String(ids[i]) if i < ids.size() else ""
			var q := c
			var at := Vector3.ZERO
			for tries in 10:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.5, r.size.x * 0.5 - 1.0)
				q = c + Vector2(cos(a), sin(a)) * d
				at = L.gv(q.x, q.y)
				# readable ones stand on dry ground; the rest may lean out of the shallows
				if at.y > RealmLand_WATER + (0.12 if id != "" else -0.25):
					break
			var yaw := rng.randf() * TAU
			if id == "jn_6":
				# Wenna's last page, on a flat stone by the water, held down by a pebble
				L.stone(L.k, at, Vector3(0.9, 0.3, 0.7), "lore_rock", true, 0.3)
				L.page(at + Vector3.UP * 0.12, Vector3(0.05, 1, 0).normalized())
				L.stone(L.p, at + Vector3(0.05, 0.18, 0.05), Vector3(0.12, 0.08, 0.1), "lore_rock", false, 0.1)
				L.scrap(id, at + Vector3(0, 0.4, -0.7))
				continue
			if id == "fen_corvin":
				var lc: Vector3 = L.lamp_post(at, yaw, false)
				L.light("CorvinsLamp", lc, Color(0.45, 0.85, 0.8), 0.8, 5.0)
				L.p.box("lore_cold", lc, Vector3(0.14, 0.22, 0.14), Basis(Vector3.UP, yaw), false, 0.9)
				L.scrap(id, at + Basis(Vector3.UP, yaw) * Vector3(0, 0.4, -0.8), lc)
				continue
			if id == "fen_rite":
				# a second post, its lamp long gone, the rite scratched down its face
				var yb := Basis(Vector3.UP, yaw)
				L.lamp_post(at, yaw, false)
				L.panel(at + yb * Vector3(0, 1.2, -0.07), yb * Vector3(0, 0, -1), 0.11, 0.5, LA.C_RUNES, false)
				L.scrap(id, at + yb * Vector3(0, 0.4, -0.9), at + Vector3.UP * 1.2)
				continue
			if id == "jn_8":
				# her mother's stone: three stones laid, the heart-stone rolled away, small prints north
				var yb2 := Basis(Vector3.UP, yaw)
				var fp8: Vector3 = L.headstone(at, yaw, 0, 0.9, Vector2(0.06, -0.04), "lore_tstone", true)
				L.letters(fp8, yb2 * Vector3(0, 0, -1), 0.28, 3)
				for j in 2:
					var sq2 := at + yb2 * Vector3(0.0, 0.0, -0.6 - 0.42 * float(j))
					sq2.y = L.g(sq2.x, sq2.z)
					L.stone(L.p, sq2, Vector3(0.3, 0.2, 0.26), "lore_rock", false, 0.3)
				var rolled := at + yb2 * Vector3(0.9, 0.0, -1.7)
				rolled.y = L.g(rolled.x, rolled.z)
				L.stone(L.p, rolled, Vector3(0.32, 0.22, 0.28), "lore_rock", false, 0.2)
				for f in 6:
					var fq := at + yb2 * Vector3(0.6 + 0.12 * float(f % 2), 0.0, -2.2 - 0.38 * float(f))
					fq.y = L.g(fq.x, fq.z) + 0.012
					L.p.box("dark", fq, Vector3(0.08, 0.02, 0.17), yb2, false, 0.25)
				L.page(at + yb2 * Vector3(-0.5, 0.03, -0.9), Vector3.UP, 0.4)
				L.scrap(id, at + yb2 * Vector3(-0.6, 0.4, -1.7), at + yb2 * Vector3(-0.5, 0.05, -0.9))
				continue
			# a marker sunk to its shoulders and leaning hard
			var sink := rng.randf_range(0.25, 0.55) if id == "" else 0.08
			var lean := Vector2(rng.randf_range(-0.45, 0.45), rng.randf_range(-0.35, 0.35))
			var style := [4, 0, 2, 4, 3][i % 5] as int
			var fp: Vector3 = L.headstone(at + Vector3.DOWN * sink, yaw, style, rng.randf_range(0.7, 1.1), lean, "lore_moss" if style == 4 else "lore_tstone", false)
			# the three stones: eyes, mouth, heart
			for j in 3:
				var sq := at + Basis(Vector3.UP, yaw) * Vector3(rng.randf_range(-0.15, 0.15), 0.0, -0.5 - 0.42 * float(j))
				sq.y = L.g(sq.x, sq.z)
				L.stone(L.p, sq, Vector3(0.3, 0.2, 0.26) * rng.randf_range(0.8, 1.2), "lore_rock", false, 0.3)
			if id != "":
				L.letters(fp, Basis(Vector3.UP, yaw) * Vector3(0, 0, -1), 0.25, 3)
				L.scrap(id, at + Basis(Vector3.UP, yaw) * Vector3(0, 0.4, -1.8), fp)
	L.finish()
	_east_way(L)
	L.note("The Drowned Graves", Vector3(75, 0, 0))


## The lay brothers' lodge: a roofless stone hut where Brother Lisle kept the Tally. A lectern
## inside with the first leaf, a desk by the door with the second, a candle that was left lit.
static func _lodge(L: RefCounted) -> void:
	var c := Vector2.INF
	var tries: Array[Vector2] = []
	for rad: float in [16.0, 21.0, 26.0]:
		for ai in 12:
			var a := TAU * float(ai) / 12.0 + rad * 0.1
			tries.append(RealmLayout.BARROWS_C + Vector2(cos(a), sin(a)) * rad)
	for q: Vector2 in tries:
		var r := Rect2(q - Vector2(3.6, 3.6), Vector2(7.2, 7.2))
		if not RealmLayout.BOUNDS.grow(-4.0).encloses(r) or q.distance_to(Vector2(60.0, -30.0)) < 13.0:
			continue                   # (60, -30) is a drowned-graves cluster, built after us
		var grr: Vector2 = L.g_range(r)
		if LK.clear_of(r, 0.8) and grr.x > RealmLand_WATER + 0.05 and grr.y - grr.x < 1.3:
			c = q
			break
	if c == Vector2.INF:
		var why := {}
		for q2: Vector2 in tries:
			var w := LK.blocker(Rect2(q2 - Vector2(3.6, 3.6), Vector2(7.2, 7.2)), 0.8)
			why[w] = int(why.get(w, 0)) + 1
		print("REALM_LORE skip the lay brothers' lodge ", why)
		return
	var to := RealmLayout.BARROWS_C - c
	var hut: Dictionary = Cottage.build(L, "br_lodge", c, 4.6, 3.6, atan2(-to.x, -to.y), "ruin", "slate")
	var hx: Transform3D = hut.xf
	var lp: Vector3 = L.lectern(hx * Vector3(0.6, 0, 0.4), hx.basis.get_euler().y + PI, "lore_tstone")
	L.scrap("br_tally_1", hx * Vector3(0.6, 0.3, -0.5), lp + Vector3.UP * 0.1)
	var dk := hx * Vector3(-1.4, 0, -2.9)
	dk.y = L.g(dk.x, dk.z)
	L.k.box("lore_tstone", dk + Vector3.UP * 0.4, Vector3(1.0, 0.8, 0.6), hx.basis, true, 0.85)
	L.k.box("lore_tstone", dk + Vector3.UP * 0.84, Vector3(1.2, 0.08, 0.7), hx.basis, true, 0.8)
	L.page(dk + hx.basis * Vector3(-0.2, 0.89, 0.0), Vector3.UP, 0.3)
	L.page(dk + hx.basis * Vector3(0.15, 0.885, 0.05), Vector3.UP, 0.5)
	L.k.candle_cluster(dk + Vector3.UP * 0.88 + hx.basis * Vector3(0.42, 0, 0.1), 2, 0.06, L.rng)
	L.scrap("br_tally_2", dk + hx.basis * Vector3(0, 0.3, -0.95), dk + Vector3.UP * 0.9)
	L.light("LodgeCandle", dk + Vector3.UP * 1.3, Color(1.0, 0.58, 0.28), 0.4, 3.5)
	L.note("The Lay Brothers' Lodge", Vector3(c.x, 0, c.y))




## Along the east way (the lay brothers' road from the village to the mounds): their waystone at
## the bend into the fen, and a pilgrim's cloak spread flat where its owner walked out of it.
static func _east_way(L: RefCounted) -> void:
	var wcands: Array = []
	for s0: float in [45.0, 49.0, 41.0, 53.0]:
		for sd: float in [1.0, -1.0]:
			wcands.append(LK.beside_path("east_way", s0, sd, 3.6))
	var wa: Vector3 = L.spot_any("fen_brothers_way", wcands, 0.9, 0.4)
	if wa != Vector3.INF:
		var pc: Vector2 = LK.along(LK.path_pts("east_way"), 47.0)[0]
		var d := pc - Vector2(wa.x, wa.z)
		var fpw: Vector3 = L.waystone(wa, atan2(-d.x, -d.y), 1.4, "lore_moss")
		L.scrap("fen_brothers", fpw, fpw + Vector3.UP * 0.25)
	var ccands: Array = []
	for s1: float in [24.0, 28.0, 20.0, 32.0, 14.0, 36.0, 40.0, 60.0, 66.0]:
		for sd2: float in [-1.0, 1.0]:
			ccands.append(LK.beside_path("east_way", s1, sd2, 3.5))
			ccands.append(LK.beside_path("east_way", s1, sd2, 4.6))
	var ca: Vector3 = L.spot_any("fen_cloak", ccands, 0.9, 0.45, 1.3)
	if ca != Vector3.INF:
		var yb := Basis(Vector3.UP, L.rng.randf() * TAU)
		var cm := CreatureMesh.new(66)
		cm.blob(Vector3.ZERO, Vector3(0.7, 0.04, 0.9), Basis.IDENTITY, Color(0.35, 0.32, 0.36), 0.0, 0.3, 0.0, 5, 12)
		cm.blob(Vector3(0, 0.03, -0.75), Vector3(0.22, 0.06, 0.16), Basis.IDENTITY, Color(0.32, 0.29, 0.33), 0.0, 0.3, 0.0, 4, 8)   # the hood
		LK.organic(L.p, "lore_cloth", cm.commit(), Transform3D(yb, ca + Vector3.UP * 0.02))
		L.p.box("lore_beam", ca + yb * Vector3(0.9, 0.04, 0.2), Vector3(0.05, 0.05, 1.6), yb * Basis(Vector3.UP, 0.3), false, 0.65)
		var bowl: ArrayMesh = LK.pooled("bowl", func() -> ArrayMesh:
			var bm := CreatureMesh.new(15)
			bm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.05, 0), Vector3(0, 0.08, 0)]), PackedFloat32Array([0.05, 0.1, 0.11]), 10, Color(0.6, 0.5, 0.4), 0.0, 0.04)
			return bm.commit())
		LK.organic(L.p, "wood", bowl, Transform3D(yb, ca + yb * Vector3(-0.7, 0.0, 0.5)))
		L.scrap("fen_pilgrim", ca + yb * Vector3(0, 0.35, -1.3), ca + Vector3.UP * 0.1)


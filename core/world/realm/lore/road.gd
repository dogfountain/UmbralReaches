extends RefCounted
## The Pilgrims' Road (RealmLayout PATHS "road"): the West and East Gates of the Reaches where the
## pilgrims came in, waystones counting the miles to the Stair, pilgrims' graves and cairns, a
## roadside shrine to the Mother of the Open Sky, a broken cart, old road lamps, and dry-stone
## field walls across the heath. Everything stands off the carved road (path_dist) and its sites.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const OFF := 3.7          ## waystone offset from the road's centreline (road half width 2.2)


static func face(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


## [centre point, unit tangent (west -> east)] of the road at world x.
static func road_at(x: float) -> Array:
	var pts: Array = LK.path_pts("road")
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if x >= minf(a.x, b.x) and x <= maxf(a.x, b.x) and absf(b.x - a.x) > 0.01:
			var t := (x - a.x) / (b.x - a.x)
			return [a.lerp(b, t), (b - a).normalized() * signf(b.x - a.x)]
	return [pts[0], Vector2.RIGHT]


## A point beside the road at x, `side` +1 south / -1 north, `off` from the centreline.
static func beside(x: float, side: float, off := OFF) -> Vector2:
	var r := road_at(x)
	var t: Vector2 = r[1]
	var n := Vector2(-t.y, t.x)
	if n.y < 0.0:
		n = -n
	return (r[0] as Vector2) + n * side * off


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "PilgrimsRoad", 6060)
	var rng: RandomNumberGenerator = L.rng
	# --- gates ------------------------------------------------------------------------------------
	# r34 layout: the gates stand 10 m inside the world's west and east edges (the road runs on to them)
	var gx := RealmLayout.BOUNDS.end.x - 10.0
	_gate(L, -gx, "rd_gate_w", "road_gate_w")
	_gate(L, gx, "rd_gate_e", "road_gate_e")
	# Wenna's first page, on a pilgrim's abandoned pack by the West Gate
	var pk := beside(-gx + 5.0, 1.0, 4.6)
	var pkv: Vector3 = L.gv(pk.x, pk.y)
	if L.spot("rd_pack", pkv, 0.8):
		var cm := CreatureMesh.new(61)
		cm.blob(Vector3.ZERO, Vector3(0.3, 0.22, 0.24), Basis.IDENTITY, Color(0.6, 0.5, 0.4), 0.0, 0.25, 0.0, 6, 9)
		cm.tube(PackedVector3Array([Vector3(-0.15, 0.15, -0.2), Vector3(0, 0.32, -0.25), Vector3(0.15, 0.15, -0.2)]), PackedFloat32Array([0.025, 0.025, 0.025]), 5, Color(0.4, 0.3, 0.25), 0.0, 0.0)
		LK.organic(L.p, "lore_cloth", cm.commit(), Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.BACK, 0.4), pkv + Vector3.UP * 0.15))
		L.p.box("lore_beam", pkv + Vector3(0.5, 0.6, 0.1), Vector3(0.05, 1.5, 0.05), Basis(Vector3.BACK, 0.5), false, 0.7)     # a staff leaning
		L.page(pkv + Vector3(-0.35, 0.03, 0.25), Vector3.UP)
		L.scrap("jn_1", pkv + Vector3(-0.3, 0.3, -0.4))
	# --- waystones ----------------------------------------------------------------------------
	var ways := [[-88.0, -1.0, "rd_way_12"], [-56.0, 1.0, "rd_way_9"], [-27.0, -1.0, "rd_way_6"], [-16.0, 1.0, "rd_way_3"],
		[64.0, -1.0, "rd_way_e8"], [88.0, 1.0, "rd_way_e11"]]
	for w: Array in ways:
		var q := beside(float(w[0]), float(w[1]))
		var at: Vector3 = L.gv(q.x, q.y)
		if not L.spot("rd_" + String(w[2]), at, 0.9, 0.2):
			continue
		var rc: Vector2 = road_at(float(w[0]))[0]
		var fp: Vector3 = L.waystone(at, face(q, rc), 1.55)
		L.scrap(String(w[2]), fp, fp + Vector3.UP * 0.25)
	# plain milestones between them (no text: rhythm)
	for x: float in [-72.0, -42.0, 30.0, 50.0, 76.0]:
		var side := 1.0 if int(x) % 2 == 0 else -1.0
		var q2 := beside(x, side, 3.4)
		var at2: Vector3 = L.gv(q2.x, q2.y)
		if L.spot("rd_mile_%d" % int(x), at2, 0.6, 0.2):
			var b := Basis(Vector3.UP, face(q2, road_at(x)[0]))
			L.k.box("lore_tstone", at2 + Vector3.UP * 0.3, Vector3(0.42, 1.2, 0.34), b * Basis(Vector3.BACK, rng.randf_range(-0.1, 0.1)), true)
			LK.half_disc(L.k, "lore_tstone", Transform3D(b, at2 + Vector3.UP * 0.9), 0.21, 0.0, 0.34, 6, false)
			L.cairn(L.p, at2 + b * Vector3(0.4, 0, -0.3), 0.3)
	# --- the Hierarch's edicts, on steles inside each gate ------------------------------------------
	for ed: Array in [["rd_edict_1", -gx + 6.5, -1.0], ["rd_edict_2", gx - 6.5, 1.0]]:
		var cands: Array = []
		for dx: float in [0.0, 2.5, -2.5, 5.0]:
			for off: float in [4.4, 5.4]:
				cands.append(beside(float(ed[1]) + dx, float(ed[2]), off))
		var sa: Vector3 = L.spot_any(String(ed[0]), cands, 0.9, 0.3)
		if sa != Vector3.INF:
			var fpe: Vector3 = L.stele(sa, face(Vector2(sa.x, sa.z), road_at(sa.x)[0]), 2.1)
			L.scrap(String(ed[0]), Vector3(sa.x, sa.y, sa.z) + (Vector3(fpe.x, sa.y, fpe.z) - sa).normalized() * 1.3 + Vector3.UP * 0.3, fpe + Vector3.UP * 0.5)
	# --- road lamps (cold, some fallen) -------------------------------------------------------
	for x3: float in [-80.0, -64.0, -48.0, 58.0, 82.0]:
		var side3 := -1.0 if int(x3) % 3 == 0 else 1.0
		var q3 := beside(x3, side3, 3.3)
		var at3: Vector3 = L.gv(q3.x, q3.y)
		if not L.spot("rd_lamp_%d" % int(x3), at3, 0.7, 0.2):
			continue
		var yaw3 := face(q3, road_at(x3)[0])
		if rng.randf() < 0.35:
			L.p.box("lore_beam", at3 + Basis(Vector3.UP, yaw3 + 1.4) * Vector3(0, 0.08, -1.3), Vector3(0.13, 0.13, 2.6), Basis(Vector3.UP, yaw3 + 1.4), false, 0.7)
			L.p.box("lore_beam", at3 + Vector3.UP * 0.25, Vector3(0.16, 0.5, 0.16), Basis(Vector3.BACK, 0.2), true, 0.6)
		else:
			var lc: Vector3 = L.lamp_post(at3, yaw3, false)
			if not "rd_lamp" in LK.scraps:
				L.scrap("rd_lamp", at3 + Basis(Vector3.UP, yaw3) * Vector3(0, 0.3, -1.0), lc)
	# --- pilgrim graves --------------------------------------------------------------------------
	_graves_west(L)
	_cobb(L)
	# cairn graves scattered along the verge: a heap of stones and a stick cross
	for x4: float in [-92.0, -68.0, -34.0, 22.0, 70.0, 95.0]:
		var q4 := beside(x4 + 2.0, 1.0 if int(x4) % 4 == 0 else -1.0, 5.6)
		var at4: Vector3 = L.gv(q4.x, q4.y)
		if not L.spot("rd_cairn_%d" % int(x4), at4, 1.2):
			continue
		_cairn_grave(L, at4, rng.randf() * TAU)
	# --- roadside shrine, broken cart ------------------------------------------------------------
	_shrine(L, beside(-35.0, 1.0, 7.0))
	_cart(L, beside(72.0, 1.0, 6.2))
	# --- dry-stone field walls across the heath ---------------------------------------------------
	for wall: Array in [[Vector2(-98, 77), Vector2(-86, 76)], [Vector2(-62, 70), Vector2(-46, 73.5)], [Vector2(-28, 64), Vector2(-24, 77)],
			[Vector2(12, 70), Vector2(36, 75)], [Vector2(54, 74), Vector2(84, 76)]]:
		var a: Vector2 = wall[0]
		var b2: Vector2 = wall[1]
		var r := Rect2(a, Vector2.ZERO).expand(b2).grow(0.6)
		if not LK.clear_of(r, 0.8):
			print("REALM_LORE skip field wall ", a, b2)
			continue
		L.site("rd_wall_%d_%d" % [int(a.x), int(a.y)], r, L.g(r.get_center().x, r.get_center().y))
		L.drystone(Vector3(a.x, 0, a.y), Vector3(b2.x, 0, b2.y), 1.0, 0.45, "lore_moss", L.p)
	L.finish()
	L.note("The Pilgrims' Road", Vector3(0, 0, 64))


## A gate of the Reaches: two square pillars either side of the road, a fallen lintel, wall stubs.
static func _gate(L: RefCounted, x: float, lore_id: String, site_name: String) -> void:
	var k: OssKit = L.k
	var r := road_at(x)
	var c: Vector2 = r[0]
	var t: Vector2 = r[1]
	var n := Vector2(-t.y, t.x)
	if n.y < 0.0:
		n = -n
	var yaw := atan2(-t.x, -t.y)           # pillar frame: local z along the road
	var b := Basis(Vector3.UP, yaw)
	for side: float in [-1.0, 1.0]:
		var pc := c + n * side * 4.7
		var gr: Vector2 = L.g_range(Rect2(pc - Vector2(1.0, 1.0), Vector2(2.0, 2.0)))
		var at := Vector3(pc.x, gr.x, pc.y)
		L.site("%s_%s" % [site_name, "s" if side > 0.0 else "n"], Rect2(pc - Vector2(1.15, 1.15), Vector2(2.3, 2.3)), gr.x)
		var h := 5.2 if side < 0.0 else 3.6
		k.box("lore_ashlar", at + Vector3.UP * 0.2, Vector3(1.9, 0.9, 1.9), b, true, 0.82)
		k.box("lore_ashlar", at + Vector3.UP * (0.6 + h * 0.5), Vector3(1.4, h, 1.4), b, true)
		k.box("lore_ashlar", at + Vector3.UP * 1.1, Vector3(1.55, 0.18, 1.55), b, false, 0.85)
		if side < 0.0:
			k.box("lore_ashlar", at + Vector3.UP * (0.6 + h + 0.12), Vector3(1.6, 0.24, 1.6), b, true, 0.85)
			# the arch springer, reaching over the road and broken off
			k.box("lore_ashlar", at + Vector3.UP * (0.6 + h - 0.4) + Vector3(-n.x, 0, -n.y) * -0.95, Vector3(0.9, 0.8, 1.1), Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.0), true, 0.92)
			k.pinnacle("lore_ashlar", at + Vector3.UP * (0.6 + h + 0.24), 0.7, 0.6, 1.0)
		else:
			L.rubble(k, at + Vector3(n.x, 0, n.y) * 1.6, 1.6, 16, "lore_ashlar", true)
			# the plaque on the road face of the standing stump
			var pl := at + Vector3.UP * 1.9 + Vector3(-n.x, 0, -n.y) * 0.72
			var pb := Basis(Vector3.UP, atan2(n.x, n.y))
			k.box("lore_tstone", pl, Vector3(0.8, 0.55, 0.06), pb, false, 1.05)
			L.letters(pl + Vector3(-n.x, 0, -n.y) * 0.035, Vector3(-n.x, 0, -n.y), 0.6, 4)
			L.scrap(lore_id, at + Vector3(-n.x, 0, -n.y) * 1.6 + Vector3.UP * 0.4)
		# a wall stub running out from each pillar
		var w0 := pc + n * side * 1.0
		var w1 := pc + n * side * 7.5 + t * (side * 0.8)
		L.drystone(Vector3(w0.x, 0, w0.y), Vector3(w1.x, 0, w1.y), 1.6, 0.55, "lore_ashlar")
		L.site("%s_wall_%s" % [site_name, "s" if side > 0.0 else "n"], Rect2(w0, Vector2.ZERO).expand(w1).grow(0.7), gr.x)
	# the fallen lintel lies along the verge
	var fl := c + n * 7.0 + t * -3.2
	var fy: float = L.g(fl.x, fl.y)
	k.box("lore_ashlar", Vector3(fl.x, fy + 0.3, fl.y), Vector3(0.9, 0.7, 4.4), Basis(Vector3.UP, yaw + 0.25) * Basis(Vector3.BACK, 0.12), true, 0.9)
	L.site(site_name + "_lintel", Rect2(fl - Vector2(2.4, 2.4), Vector2(4.8, 4.8)), fy)
	L.note("Gate " + site_name, Vector3(c.x, 0, c.y))


static func _cairn_grave(L: RefCounted, at: Vector3, yaw: float) -> void:
	var cm := CreatureMesh.new(L.rng.randi())
	cm.blob(Vector3.ZERO, Vector3(0.5, 0.18, 0.95), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.2, 0.0, 6, 10)
	LK.organic(L.p, "lore_earth", cm.commit(), Transform3D(Basis(Vector3.UP, yaw), at + Vector3.DOWN * 0.04))
	for i in 9:
		var q := at + Basis(Vector3.UP, yaw) * Vector3(L.rng.randf_range(-0.35, 0.35), 0.12, L.rng.randf_range(-0.7, 0.7))
		L.stone(L.p, q, Vector3.ONE * L.rng.randf_range(0.16, 0.3), "lore_rock", false, 0.2)
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, L.rng.randf_range(-0.2, 0.2))
	var head := at + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.95)
	L.p.box("lore_beam", head + Vector3.UP * 0.4, Vector3(0.06, 1.0, 0.06), b, true, 0.6)
	L.p.box("lore_beam", head + Vector3.UP * 0.65, Vector3(0.45, 0.05, 0.05), b, false, 0.6)


static func _graves_west(L: RefCounted) -> void:
	var c := beside(-80.0, 1.0, 9.5)
	var r := Rect2(c - Vector2(4.0, 2.5), Vector2(8.0, 5.0))
	if not LK.clear_of(r, 0.8):
		print("REALM_LORE skip west graves")
		return
	var gr: Vector2 = L.g_range(r)
	L.site("rd_graves_w", r, gr.x)
	var rc: Vector2 = road_at(-80.0)[0]
	for i in 5:
		var q := Vector2(c.x - 3.0 + float(i) * 1.5, c.y + L.rng.randf_range(-0.4, 0.4))
		var at: Vector3 = L.gv(q.x, q.y)
		if i == 2:
			# the pilgrim with the stone pillow: a long low slab and a rounded stone at its head
			var yaw := face(q, rc)
			var b := Basis(Vector3.UP, yaw)
			L.k.box("lore_tstone", at + Vector3.UP * 0.08 + b * Vector3(0, 0, 0.4), Vector3(0.7, 0.28, 1.9), b, true, 0.85)
			L.stone(L.k, at + b * Vector3(0, 0.25, -0.7), Vector3(0.6, 0.38, 0.4), "lore_tstone", true, 0.1)
			L.letters(at + Vector3.UP * 0.23 + b * Vector3(0, 0, 0.4), Vector3.UP, 0.4, 3)
			L.scrap("rd_grave_stone", at + b * Vector3(0, 0.3, -1.4))
		else:
			L.headstone(at, face(q, rc) + L.rng.randf_range(-0.2, 0.2), [4, 3, 0, 4, 1][i], L.rng.randf_range(0.55, 0.85), Vector2(L.rng.randf_range(-0.15, 0.25), L.rng.randf_range(-0.15, 0.15)), "lore_tstone", true)


static func _cobb(L: RefCounted) -> void:
	var c := beside(46.0, 1.0, 8.0)
	var r := Rect2(c - Vector2(2.2, 2.0), Vector2(4.4, 4.0))
	if not LK.clear_of(r, 0.8):
		print("REALM_LORE skip cobb graves")
		return
	var gr: Vector2 = L.g_range(r)
	L.site("rd_graves_cobb", r, gr.x)
	var rc: Vector2 = road_at(46.0)[0]
	var yaw := face(c, rc)
	var b := Basis(Vector3.UP, yaw)
	var fp: Vector3 = L.headstone(L.gv(c.x - b.x.x * 0.7, c.y - b.x.z * 0.7), yaw, 0, 1.0, Vector2(0.05, 0.08), "lore_tstone", true)
	L.headstone(L.gv(c.x + b.x.x * 0.7, c.y + b.x.z * 0.7), yaw, 0, 0.95, Vector2(0.02, -0.1), "lore_tstone", true)
	L.letters(fp, b * Vector3(0, 0, -1), 0.3, 3)
	L.scrap("rd_grave_cobb", L.gv(c.x, c.y) + b * Vector3(0, 0.3, -1.0))


static func _shrine(L: RefCounted, c: Vector2) -> void:
	var k: OssKit = L.k
	var r := Rect2(c - Vector2(1.8, 1.8), Vector2(3.6, 3.6))
	if not LK.clear_of(r, 0.6):
		print("REALM_LORE skip road shrine")
		return
	var gr: Vector2 = L.g_range(r)
	var at := Vector3(c.x, gr.x, c.y)
	L.site("rd_shrine", r, gr.x)
	var yaw := face(c, road_at(c.x)[0])
	var b := Basis(Vector3.UP, yaw)
	k.box("lore_tstone", at + Vector3.UP * 0.05, Vector3(2.4, 0.5, 1.9), b, true, 0.8)
	k.box("lore_tstone", at + b * Vector3(0, 1.5, 0.6), Vector3(1.8, 2.6, 0.35), b, true, 0.95)
	for s: float in [-1.0, 1.0]:
		k.box("lore_tstone", at + b * Vector3(s * 0.85, 1.4, 0.2), Vector3(0.25, 2.4, 0.9), b, true, 0.9)
	LK.half_disc(k, "lore_tstone", Transform3D(b, at + b * Vector3(0, 2.75, 0.2)), 1.1, 0.0, 1.0, 9, true, 0.85)
	# the Mother of the Open Sky, arms gone, her face cut away; a bowl of rainwater at her feet
	L.saint(at + Vector3.UP * 0.3 + b * Vector3(0, 0, 0.25), yaw, 2, 0.3, 0.75)
	k.candle_cluster(at + Vector3.UP * 0.3 + b * Vector3(-0.6, 0, -0.5), 4, 0.15, L.rng)
	k.candle_cluster(at + Vector3.UP * 0.3 + b * Vector3(0.62, 0, -0.45), 2, 0.1, L.rng)
	var pl := at + b * Vector3(0, 0.65, -0.96)
	k.box("lore_tstone", pl, Vector3(0.9, 0.3, 0.05), b, false, 1.05)
	L.letters(pl + b * Vector3(0, 0, -0.03), b * Vector3(0, 0, -1), 0.7, 2)
	L.scrap("rd_shrine", at + b * Vector3(0.0, 0.3, -1.6))
	# Wenna's second page, weighed down by a stone on the step
	L.page(at + b * Vector3(0.7, 0.32, -0.75), Vector3.UP)
	L.stone(L.p, at + b * Vector3(0.75, 0.36, -0.7), Vector3(0.12, 0.08, 0.1), "lore_rock", false, 0.1)
	L.scrap("jn_2", at + b * Vector3(1.4, 0.3, -1.0))
	L.light("RoadShrine", at + Vector3.UP * 0.9 + b * Vector3(0, 0, -0.9), Color(1.0, 0.6, 0.3), 0.6, 4.0)
	L.cairn(L.p, at + b * Vector3(-1.4, 0, -0.6), 0.5)


static func _cart(L: RefCounted, c: Vector2) -> void:
	var r := Rect2(c - Vector2(2.6, 2.6), Vector2(5.2, 5.2))
	if not LK.clear_of(r, 0.6):
		print("REALM_LORE skip cart")
		return
	var at: Vector3 = L.gv(c.x, c.y)
	L.site("rd_cart", r, at.y)
	var tail: Vector3 = L.cart(at, -1.2, true, "sacks")
	# spilled sacks and a split barrel on the ground
	for i in 3:
		var q := at + Basis(Vector3.UP, -1.2) * Vector3(L.rng.randf_range(-1.4, 1.4), 0, 1.8 + float(i) * 0.4)
		q.y = L.g(q.x, q.z) + 0.12
		var cm := CreatureMesh.new(L.rng.randi())
		cm.blob(Vector3.ZERO, Vector3(0.28, 0.16, 0.38), Basis.IDENTITY, Color(0.75, 0.66, 0.52), 0.0, 0.25, 0.0, 5, 8)
		LK.organic(L.p, "lore_cloth", cm.commit(), Transform3D(Basis(Vector3.UP, L.rng.randf() * TAU), q))
	var bq := at + Basis(Vector3.UP, -1.2) * Vector3(-1.6, 0, 0.6)
	L.barrel(L.p, Vector3(bq.x, L.g(bq.x, bq.z), bq.z), 0.9, true, 0.8)
	L.letters(tail + Basis(Vector3.UP, -1.2) * Vector3(0, 0, 0.05), Basis(Vector3.UP, -1.2) * Vector3(0, 0, 1), 0.7, 2, "lore_paper")
	L.scrap("rd_cart", tail + Basis(Vector3.UP, -1.2) * Vector3(0, -0.5, 0.8))

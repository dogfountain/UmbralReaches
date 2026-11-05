extends RefCounted
## The Glimmer Glade's Shrine of the Lost: a round stone floor beside the west way, a lone stone
## doorframe with its door left open ("we kept the door open"), heaps of candles and small
## offerings (bundles, bowls, a child's shoe, ribbons on stakes), and a ring of carved name-stones.
## A cold light for the glimmers and the warm candles.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const C := Vector2(-45.5, 17.5)


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "ShrineOfTheLost", 7070)
	var k: OssKit = L.k
	var p: OssKit = L.p
	var rng: RandomNumberGenerator = L.rng
	var r := Rect2(C - Vector2(4.6, 4.6), Vector2(9.2, 9.2))
	if not LK.clear_of(r, 0.6):
		print("REALM_LORE glade shrine spot not clear: ", C, " path ", RealmLayout.path_dist(C))
	var gr: Vector2 = L.g_range(Rect2(C - Vector2(2.6, 2.6), Vector2(5.2, 5.2)))
	var fy := lerpf(gr.x, gr.y, 0.6) + 0.15         # a low step on the uphill side, a plinth on the downhill
	L.site("glade_shrine", r, fy)
	var at := Vector3(C.x, fy, C.y)
	var to_path := Vector2(-40.0, 12.0) - C
	var yaw := atan2(-to_path.x, -to_path.y)       # the door faces the west way
	var b := Basis(Vector3.UP, yaw)
	# round floor: a ring of kerb stones and flags, two steps
	var n := 16
	for i in n:
		var a := TAU * float(i) / float(n)
		var kq := at + Vector3(cos(a) * 2.5, 0, sin(a) * 2.5)
		var kb: float = L.g(kq.x, kq.z) - 0.4           # every kerb stone reaches below the ground under it
		k.box("lore_tstone", Vector3(kq.x, (fy + kb) * 0.5, kq.z), Vector3(0.95, fy - kb, 0.5), Basis(Vector3.UP, -a + PI * 0.5), true, rng.randf_range(0.78, 0.92))
	var fl := CreatureMesh.new(71)
	var deep := fy - gr.x + 0.5
	fl.tube(PackedVector3Array([Vector3(0, -deep, 0), Vector3(0, 0.0, 0)]), PackedFloat32Array([2.4, 2.4]), 24, Color(0.85, 0.85, 0.85), 0.0, 0.0, 0.0, Vector2.ONE)
	LK.organic(k, "lore_tstone", fl.commit(), Transform3D(Basis.IDENTITY, at + Vector3.DOWN * 0.04), true)
	k.foundation("lore_tstone", Vector2(C.x - 1.8, C.y - 1.8), Vector2(C.x + 1.8, C.y + 1.8), fy - 0.06, gr.x)
	# the lone doorframe: jambs, lintel, a sill; the door stands open on its hinges
	var dc := at + b * Vector3(0, 0, 0.4)
	for s: float in [-1.0, 1.0]:
		k.box("lore_tstone", dc + b * Vector3(s * 0.75, 1.25, 0), Vector3(0.4, 2.5, 0.45), b, true, 0.95)
	k.box("lore_tstone", dc + b * Vector3(0, 2.62, 0), Vector3(2.1, 0.34, 0.55), b, true, 0.9)
	LK.half_disc(k, "lore_tstone", Transform3D(b, dc + b * Vector3(0, 2.79, 0)), 1.05, 0.0, 0.5, 2, false, 0.85)
	k.box("lore_tstone", dc + b * Vector3(0, 0.05, 0), Vector3(1.6, 0.1, 0.55), b, false, 0.8)
	var leaf := b * Basis(Vector3.UP, 1.9)
	var hinge := dc + b * Vector3(-0.55, 0, 0.05)
	k.box("lore_beam", hinge + leaf * Vector3(0.53, 1.15, 0), Vector3(1.06, 2.2, 0.08), leaf, true, 0.62)
	for yy: float in [0.45, 1.85]:
		k.box("iron", hinge + leaf * Vector3(0.45, yy, -0.05), Vector3(0.9, 0.06, 0.02), leaf, false, 0.7)
	# candles: on the sill, at the jambs, round the floor
	k.candle_cluster(dc + b * Vector3(0, 0.1, -0.05), 6, 0.35, rng)
	for s2: float in [-1.0, 1.0]:
		k.candle_cluster(dc + b * Vector3(s2 * 1.15, 0.0, -0.4), 5, 0.25, rng)
	for i in 5:
		var a2 := yaw + PI * 0.5 + (float(i) - 2.0) * 0.55
		k.candle_cluster(at + Vector3(sin(a2) * -1.7, 0.0, cos(a2) * -1.7), 3, 0.15, rng)
	# offerings: cloth bundles, bowls, a small shoe, ribbons on stakes
	for i in 7:
		var a3 := rng.randf() * TAU
		var q := at + Vector3(cos(a3) * rng.randf_range(0.9, 1.9), 0.06, sin(a3) * rng.randf_range(0.9, 1.9))
		var cm := CreatureMesh.new(rng.randi())
		var col := [Color(0.7, 0.25, 0.22), Color(0.55, 0.5, 0.42), Color(0.35, 0.4, 0.55), Color(0.75, 0.68, 0.5)][i % 4] as Color
		if i % 3 == 0:
			cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.07, 0), Vector3(0, 0.1, 0)]), PackedFloat32Array([0.06, 0.11, 0.12]), 10, Color(0.8, 0.7, 0.6), 0.0, 0.05)
			LK.organic(p, "lore_tstone", cm.commit(), Transform3D(Basis.IDENTITY, q))
		elif i == 4:
			cm.blob(Vector3.ZERO, Vector3(0.05, 0.045, 0.1), Basis.IDENTITY, Color(0.45, 0.3, 0.22), 0.0, 0.1, 0.0, 4, 8)
			cm.blob(Vector3(0, 0.05, 0.05), Vector3(0.04, 0.04, 0.04), Basis.IDENTITY, Color(0.45, 0.3, 0.22), 0.0, 0.1, 0.0, 4, 6)
			cm.blob(Vector3(0, 0.03, -0.09), Vector3(0.03, 0.02, 0.012), Basis.IDENTITY, Color(0.85, 0.15, 0.12), 0.0, 0.0, 0.0, 3, 5)   # red thread at the heel
			LK.organic(p, "lore_cloth", cm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
			var outw := Vector3(q.x - at.x, 0, q.z - at.z).normalized()
			L.scrap("gl_shoe", q + outw * 0.7 + Vector3.UP * 0.25, q)
		else:
			cm.blob(Vector3.ZERO, Vector3(0.14, 0.1, 0.12), Basis.IDENTITY, col, 0.0, 0.3, 0.0, 5, 8)
			cm.tube(PackedVector3Array([Vector3(0, 0.08, 0), Vector3(0, 0.16, 0), Vector3(0.02, 0.2, 0)]), PackedFloat32Array([0.05, 0.03, 0.04]), 6, col, 0.0, 0.2)
			LK.organic(p, "lore_cloth", cm.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
	for i in 4:
		var a4 := yaw + PI + (float(i) - 1.5) * 0.7
		var sp := at + Vector3(sin(a4) * -2.2, 0, cos(a4) * -2.2)
		sp.y = L.g(sp.x, sp.z)
		var sb := Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15))
		p.box("lore_beam", sp + Vector3.UP * 0.7, Vector3(0.05, 1.7, 0.05), sb, false, 0.6)
		if i == 0:
			var outr := Vector3(sp.x - at.x, 0, sp.z - at.z).normalized()
			L.scrap("gl_ribbons", sp + outr * 0.9 + Vector3.UP * 0.3, sp + Vector3.UP * 1.3)
		for j in 3:
			var rc := [Color(0.75, 0.22, 0.2), Color(0.85, 0.82, 0.7), Color(0.3, 0.38, 0.6)][j] as Color
			var cm2 := CreatureMesh.new(rng.randi())
			cm2.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0.12, -0.25, 0.02), Vector3(0.2, -0.55, 0.06)]), PackedFloat32Array([0.025, 0.02, 0.012]), 4, rc, 0.0, 0.0, 0.0, Vector2(1.0, 0.25))
			LK.organic(p, "lore_cloth", cm2.commit(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), sp + Vector3.UP * (1.35 - 0.12 * float(j))))
	var pl := dc + b * Vector3(-0.75, 1.3, -0.24)
	k.box("lore_tstone", pl, Vector3(0.3, 0.42, 0.04), b, false, 1.08)
	L.letters(pl + b * Vector3(0, 0, -0.025), b * Vector3(0, 0, -1), 0.22, 4)
	L.scrap("gl_shrine", dc + b * Vector3(0, 0.3, -1.4))
	# Wenna's fifth page, tucked under a bowl on the floor
	L.page(at + b * Vector3(1.2, 0.03, -0.9), Vector3.UP)
	L.scrap("jn_5", at + b * Vector3(1.4, 0.3, -1.3))
	# the ring of name-stones
	var ids := ["gl_names", "", "gl_glimmers", "", "gl_hollow", ""]
	for i in ids.size():
		var a5 := yaw + PI * 0.5 + TAU * float(i) / float(ids.size()) + 0.3
		var q5 := Vector2(C.x + sin(a5) * -3.7, C.y + cos(a5) * -3.7)
		var at5: Vector3 = L.gv(q5.x, q5.y)
		var face_yaw := atan2(-(C.x - q5.x), -(C.y - q5.y))
		if String(ids[i]) != "":
			var fp: Vector3 = L.headstone(at5, face_yaw, 0, rng.randf_range(0.8, 1.0), Vector2(rng.randf_range(-0.08, 0.12), rng.randf_range(-0.08, 0.08)), "lore_tstone", false)
			L.letters(fp, Basis(Vector3.UP, face_yaw) * Vector3(0, 0, -1), 0.3, 4)
			L.scrap(ids[i], fp + Basis(Vector3.UP, face_yaw) * Vector3(0, -0.3, -0.6), fp)
		else:
			L.rune_stone(at5, face_yaw, rng.randf_range(0.9, 1.3))
	L.light("ShrineOfTheLost", at + Vector3.UP * 1.4 + b * Vector3(0, 0, -0.6), Color(0.55, 0.85, 1.0), 0.9, 7.0)
	L.finish()
	L.note("Shrine of the Lost", at)

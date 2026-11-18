extends RefCounted
## Hearthward: the last kindled village round the spawn brazier (0, 0, 33) and the Kindled Keg
## (built before us; never touched). Cottages gone quiet (Maud's still has a candle), the Harrows'
## ruin, a burned barn, Edda's forge across the road, the well, gardens, the noticeboard, the
## hearth shrine with the only saint that still has a face, the green's benches and hearthstone.
## Keeps 10 m clear round the brazier and off the tavern, its porch path and every Realm path.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Cottage := preload("res://core/world/realm/lore/cottage.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")
const Square := preload("res://core/world/realm/lore/hearthward_square.gd")
const Pieces := preload("res://core/world/realm/lore/hearthward_pieces.gd")
const BRAZIER := Vector2(0.0, 33.0)


static func face(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(-d.x, -d.y)


static func build(parent: Node) -> void:
	var L: RefCounted = LK.begin(parent, "Hearthward", 3301)
	var k: OssKit = L.k
	var p: OssKit = L.p
	# --- cottages -------------------------------------------------------------------------------
	var maud: Dictionary = Cottage.build(L, "hw_maud", Pilot.hw_at("hw_maud", Vector2(-17.0, 42.0)), 6.6, 5.0, face(Vector2(-17, 42), BRAZIER), "lit", "thatch", "lore_plaster")
	var harrow: Dictionary = Cottage.build(L, "hw_harrow", Pilot.hw_at("hw_harrow", Vector2(-19.0, 13.0)), 6.2, 4.8, face(Vector2(-19, 13), BRAZIER) + 0.2, "ruin", "slate")
	var reed: Dictionary = Cottage.build(L, "hw_reed", Vector2(22.0, 42.0), 6.4, 5.0, 0.0, "dark", "slate")
	var barn: Dictionary = Cottage.build(L, "hw_cobb", Vector2(-33.0, 37.5), 7.0, 5.4, PI * 0.5 + 0.15, "burned", "thatch")
	var south: Dictionary = Cottage.build(L, "hw_south", Pilot.hw_at("hw_south", Vector2(-15.0, 64.0)), 6.0, 4.8, face(Vector2(-15, 64), Vector2(-10, 55)), "dark", "thatch", "lore_plaster")
	# Maud's door plaque and the window spill
	var mx: Transform3D = maud.xf           # at the pilot's scale: a point in the cottage's own metres comes out where it is built
	var mxb := mx.basis.orthonormalized()
	var plaque: Vector3 = mx * Vector3(-3.3 + 6.6 * 0.36 + 0.95, 1.5, -2.5 - 0.03)
	k.box("lore_beam", plaque, Vector3(0.36, 0.26, 0.03), mxb, false, 0.8)
	L.letters(plaque + mxb.z * -0.02, mxb.z * -1.0, 0.26, 3)
	L.scrap("hw_maud", mx * Vector3(-3.3 + 6.6 * 0.36 + 0.9, 0.2, -3.3), plaque)
	# her letters to Hobb: one on the windowsill under the candle, one at the garden gate, one
	# on the chopping block at the back door
	var sill := mx * Vector3(-3.3 + 6.6 * 0.72 + 0.12, 0.99, -2.5 - 0.16)
	L.page(sill, mxb * Vector3(0, 1, -0.25).normalized(), 0.3)
	L.scrap("hw_maud_1", mx * Vector3(-3.3 + 6.6 * 0.72 + 0.2, 0.25, -3.6), sill)
	var back := mx * Vector3(0.4, 0.0, 3.25)
	back.y = L.g(back.x, back.z)
	var blk: ArrayMesh = LK.pooled("chop_block", func() -> ArrayMesh:
		var cm := CreatureMesh.new(12)
		cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.42, 0), Vector3(0, 0.5, 0)]), PackedFloat32Array([0.3, 0.27, 0.26]), 11, Color(0.75, 0.66, 0.56), 0.0, 0.15)
		return cm.commit())
	LK.organic(p, "lore_beam", blk, Transform3D(Basis.IDENTITY, back), true)
	p.box("iron", back + Vector3(0.05, 0.6, 0.02), Vector3(0.04, 0.14, 0.22), mxb * Basis(Vector3.RIGHT, 0.5), false, 0.7)
	L.page(back + Vector3(-0.08, 0.51, 0.0), Vector3.UP, 0.5)
	L.scrap("hw_maud_3", back + mxb * Vector3(0, 0.25, 0.9), back + Vector3.UP * 0.5)
	L.light("MaudWindow", mx * Vector3(-3.3 + 6.6 * 0.72, 1.4, -3.3), Color(1.0, 0.58, 0.26), 0.55, 4.5)
	k.candle_cluster(mx * Vector3(-3.3 + 6.6 * 0.72, 0.95, -2.5 + 0.38), 1, 0.02, L.rng)
	# the Harrows' chalked lintel + Wenna's page on their cold hearth
	var hx: Transform3D = harrow.xf
	L.scrap("hw_harrow", hx * Vector3(-3.1 + 6.2 * 0.36, 0.3, -3.1), hx * Vector3(-3.1 + 6.2 * 0.36, 2.2, -2.4))
	L.page(hx * Vector3(3.1 - 0.5 - 0.62, 1.02, 2.4 * 0.25 + 0.2), hx.basis.orthonormalized() * Vector3(-0.2, 1.0, 0).normalized())
	L.scrap("jn_4", hx * Vector3(1.9, 0.4, 0.6))
	# the well, notice board, shrine and forge are modelled pieces at the village's scale (hearthward_pieces.gd) when
	# the pilot is on; the old code-built ones when it is off
	var pieces: RefCounted = Pieces.begin(L) if Pilot.on() else null
	# --- the well ---------------------------------------------------------------------------------
	if pieces:
		pieces.well(Vector2(-10.0, 48.5))
	else:
		_well(L, Vector2(-10.0, 48.5))
	# --- gardens ------------------------------------------------------------------------------
	var gw := Pilot.on()                       # the bean garden stands west of the wider house (the pilot off: where it was)
	var gr_w := Rect2(-35.0, 44.6, 6.0, 5.0) if gw else Rect2(-27.5, 44.5, 6.0, 5.0)
	L.garden(gr_w, 1, true)
	# Maud's second letter, tied to the gate post of the bean garden
	var gp: Vector3 = L.gv(gr_w.end.x, gr_w.position.y + 1.75)
	p.box("lore_beam", gp + Vector3.UP * 0.6, Vector3(0.13, 1.4, 0.13), Basis.IDENTITY, true, 0.7)
	L.page(gp + Vector3(0.075, 0.95, 0.0), Vector3.RIGHT, 0.2)
	L.scrap("hw_maud_2", gp + Vector3(0.9, 0.25, 0.4), gp + Vector3(0.08, 0.95, 0))
	L.site("hw_garden_w", gr_w, L.g(gr_w.get_center().x, gr_w.get_center().y))
	var gr_e := Rect2(29.5, 44.0, 5.5, 5.0) if gw else Rect2(27.0, 43.5, 5.5, 5.0)
	L.garden(gr_e, 3)
	L.site("hw_garden_e", gr_e, L.g(gr_e.get_center().x, gr_e.get_center().y))
	# (map audit: off west_way and the henge stair's foot, which moved here with the 1.6x floor)
	var gr_n := Rect2(-23.5, -1.5, 5.0, 4.5) if gw else Rect2(-27.5, 6.0, 5.0, 4.5)
	L.garden(gr_n, 0)
	L.site("hw_garden_n", gr_n, L.g(gr_n.get_center().x, gr_n.get_center().y))
	# Ewan Reed's grave in the east garden's corner
	var gq := Vector2(33.6, 48.0) if gw else Vector2(31.6, 47.6)
	var tg: Vector3 = L.gv(gq.x, gq.y)
	var face_pt: Vector3 = L.headstone(tg, face(gq, Vector2(25, 42)), 1, 0.85, Vector2(0.08, -0.05), "lore_tstone", true)
	L.scrap("hw_reed", face_pt)
	# --- Edda's forge across the road ------------------------------------------------------------
	if pieces:
		pieces.forge(Vector2(11.0, 60.0))
	else:
		_forge(L, Vector2(11.0, 60.0))
	# --- noticeboard, shrine, green -----------------------------------------------------------
	var nb := Pilot.hw_xz(Vector2(-5.5, 45.5))       # in front of the gate's wall, where the road arrives (scale_pilot.gd HW_POINTS)
	if pieces:
		pieces.notice(nb, face(nb, BRAZIER), ["hw_notice_keep", "hw_notice_lost", "hw_notice_stair"])
		pieces.shrine(Vector2(-8.5, 19.5), face(Vector2(-8.5, 19.5), BRAZIER))
	else:
		_noticeboard(L, nb, face(nb, BRAZIER))
		_shrine(L, Vector2(-8.5, 19.5), face(Vector2(-8.5, 19.5), BRAZIER))
	var b1 := Vector2(-8.2, 37.4) if gw else Vector2(-11.6, 36.0)     # off the stalls' front
	L.bench(L.gv(b1.x, b1.y), face(b1, BRAZIER) + PI)
	L.bench(L.gv(8.6, 41.6), face(Vector2(8.6, 41.6), BRAZIER) + PI)
	var hs: Vector3 = L.gv(6.2, 22.4)
	var hb := Basis(Vector3.UP, face(Vector2(6.2, 22.4), BRAZIER))
	k.box("lore_tstone", hs + Vector3.UP * 0.12, Vector3(1.3, 0.5, 0.9), hb, true, 0.85)
	k.box("lore_tstone", hs + Vector3.UP * 0.42, Vector3(1.1, 0.12, 0.7), hb * Basis(Vector3.RIGHT, -0.25), true, 0.95)
	k.box("lore_char", hs + Vector3.UP * 0.5 + hb * Vector3(0, 0, 0.1), Vector3(0.5, 0.03, 0.3), hb * Basis(Vector3.RIGHT, -0.25), false, 0.5)
	L.letters(hs + Vector3.UP * 0.47 + hb * Vector3(0, 0.01, -0.12), hb * Vector3(0, 0.97, 0.25).normalized(), 0.6, 3)
	L.site("hw_hearthstone", Rect2(5.2, 21.4, 2.0, 2.0), hs.y)
	L.scrap("hw_green", hs + hb * Vector3(0, 0.3, -0.6))
	# the pilgrims' stone by north_lane (it points the long way east, to the Stair)
	var sf: Vector3 = L.gv(4.6, 6.0)
	var sfb := Basis(Vector3.UP, -PI * 0.5)
	k.box("lore_tstone", sf + Vector3.UP * 0.5, Vector3(1.6, 1.4, 0.7), sfb * Basis(Vector3.BACK, 0.08), true, 0.9)
	k.box("lore_tstone", sf + Vector3.UP * 1.25, Vector3(1.8, 0.16, 0.85), sfb * Basis(Vector3.BACK, 0.08), false, 0.8)
	k.box("dark", sf + Vector3(-0.36, 0.6, 0), Vector3(0.02, 0.6, 1.1), Basis.IDENTITY, false, 0.5)
	L.letters(sf + Vector3(-0.38, 0.62, 0), Vector3.LEFT, 0.95, 4)
	L.site("hw_stairfoot", Rect2(3.6, 4.8, 2.0, 2.4), sf.y)
	L.scrap("hw_stair_foot", sf + Vector3(-1.0, 0.3, 0))
	# the Wrights' scratched door (south cottage) and Cobb's burned barn
	var sx: Transform3D = south.xf
	L.scrap("hw_wright", (south.door as Vector3) + Vector3.UP * 0.3, sx * Vector3(-3.0 + 6.0 * 0.36, 0.7, -2.45))
	var bxf: Transform3D = barn.xf
	L.scrap("hw_cobb_barn", (barn.door as Vector3) + bxf.basis.orthonormalized() * Vector3(0.6, 0.3, 0.0), bxf * Vector3(-3.5 + 7.0 * 0.36, 1.2, -2.6))
	# --- yard clutter ---------------------------------------------------------------------------
	var bx: Transform3D = barn.xf
	L.cart(bx * Vector3(-1.0, 0, -5.2) + Vector3.UP * (L.g((bx * Vector3(-1.0, 0, -5.2)).x, (bx * Vector3(-1.0, 0, -5.2)).z) - bx.origin.y), bx.basis.orthonormalized().get_euler().y + 0.4, true, "")
	for q: Vector3 in [Vector3(1.2, 0, 3.5), Vector3(2.0, 0, 3.5), Vector3(1.6, 0, 4.1)]:       # behind the house: the lane to the garden runs down its east side
		var w: Vector3 = (reed.xf as Transform3D) * q
		L.barrel(p, Vector3(w.x, L.g(w.x, w.z), w.z), 1.2)
	var rw: Vector3 = (reed.xf as Transform3D) * Vector3(-0.9, 0, 3.5)
	L.crate(p, Vector3(rw.x, L.g(rw.x, rw.z), rw.z), 0.6, 0.3)
	var sw: Vector3 = (south.xf as Transform3D) * Vector3(-4.0, 0, 0.5)
	_woodpile(L, Vector3(sw.x, L.g(sw.x, sw.z), sw.z), (south.xf as Transform3D).basis.orthonormalized().get_euler().y)
	if pieces:
		pieces.finish()
	if Pilot.on():
		Square.build(L)                           # the square's market, cross, gate and yards (hearthward_square.gd)
	var draws: int = L.finish()
	L.note("Hearthward", Vector3(0, 0, 38))
	print("REALM_LORE hearthward draws %d" % draws)


static func _well(L: RefCounted, c: Vector2) -> void:
	var k: OssKit = L.k
	var gr: Vector2 = L.g_range(Rect2(c - Vector2(1.4, 1.4), Vector2(2.8, 2.8)))
	var y := gr.x
	L.site("hw_well", Rect2(c - Vector2(1.6, 1.6), Vector2(3.2, 3.2)), y)
	var at := Vector3(c.x, y, c.y)
	var n := 14
	for i in n:
		var a := TAU * float(i) / float(n)
		var q := at + Vector3(cos(a) * 0.95, 0, sin(a) * 0.95)
		for course in 3:
			var off := 0.5 * TAU / float(n) * float(course % 2)
			var qa := at + Vector3(cos(a + off) * 0.95, 0.15 + 0.27 * float(course) - 0.3, sin(a + off) * 0.95)
			k.box("lore_tstone", qa + Vector3.UP * 0.15, Vector3(0.36, 0.26, 0.42), Basis(Vector3.UP, -(a + off)), true, L.rng.randf_range(0.8, 1.0))
		k.box("lore_tstone", q + Vector3.UP * 0.62, Vector3(0.48, 0.1, 0.5), Basis(Vector3.UP, -a), false, 0.9)
	k.box("dark", at + Vector3.UP * 0.1, Vector3(1.4, 0.05, 1.4), Basis(Vector3.UP, 0.4), false, 0.15)
	for s: float in [-1.0, 1.0]:
		k.box("lore_beam", at + Vector3(s * 1.05, 1.0, 0), Vector3(0.14, 2.1, 0.14), Basis.IDENTITY, true, 0.75)
	k.box("lore_beam", at + Vector3(0, 1.3, 0), Vector3(2.0, 0.16, 0.16), Basis.IDENTITY, false, 0.7)   # windlass
	k.box("lore_beam", at + Vector3(1.2, 1.3, 0.18), Vector3(0.05, 0.05, 0.4), Basis.IDENTITY, false, 0.6)
	# little roof
	for s2: float in [-1.0, 1.0]:
		var e := Vector3(0, 1.95, s2 * 0.9)
		var r := Vector3(0, 2.45, 0)
		var a2 := at + e + Vector3(-1.35, 0, 0)
		var b2 := at + e + Vector3(1.35, 0, 0)
		var c2 := at + r + Vector3(1.35, 0, 0)
		var d2 := at + r + Vector3(-1.35, 0, 0)
		k.quad("lore_tslate", a2, b2, c2, d2, Vector3(0, 0.87, s2 * 0.5), false)
		k.quad("lore_beam", a2 + Vector3.DOWN * 0.08, b2 + Vector3.DOWN * 0.08, c2 + Vector3.DOWN * 0.08, d2 + Vector3.DOWN * 0.08, Vector3(0, -0.87, -s2 * 0.5), false, 0.5)
	# rope and bucket
	k.box("lore_beam", at + Vector3(0.1, 0.95, 0), Vector3(0.02, 0.7, 0.02), Basis.IDENTITY, false, 0.6)
	var cm := CreatureMesh.new(5)
	cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.28, 0)]), PackedFloat32Array([0.13, 0.16]), 10, Color(0.8, 0.7, 0.6), 0.0, 0.0)
	LK.organic(L.p, "wood", cm.commit(), Transform3D(Basis.IDENTITY, at + Vector3(0.1, 0.62, 0.0)))
	var pl := at + Vector3(0, 0.55, -1.05)
	k.box("lore_tstone", pl, Vector3(0.5, 0.3, 0.06), Basis.IDENTITY, false, 0.75)
	L.letters(pl + Vector3(0, 0, -0.035), Vector3.FORWARD, 0.36, 3)
	L.scrap("hw_well", at + Vector3(0, 0.3, -1.4))


static func _forge(L: RefCounted, c: Vector2) -> void:
	var k: OssKit = L.k
	var p: OssKit = L.p
	var r := Rect2(c - Vector2(3.4, 2.6), Vector2(6.8, 5.2))
	var gr: Vector2 = L.g_range(r)
	var fy := gr.y + 0.1
	L.site("hw_forge", r, fy, fy - 0.25)
	var b := Basis.IDENTITY                   # open side faces north (-z), to the road
	var o := Vector3(c.x, fy, c.y)
	var xf := Transform3D(b, o)
	k.box("lore_tstone", o + Vector3.DOWN * ((fy - gr.x + 0.4) * 0.5), Vector3(6.6, fy - gr.x + 0.4, 5.0), b, true, 0.8)   # stone floor plinth
	# back wall (south) of rubble stone, low side walls
	k.box("lore_tstone", xf * Vector3(0, 1.1, 2.25), Vector3(6.4, 2.2, 0.5), b, true)
	for s: float in [-1.0, 1.0]:
		k.box("lore_tstone", xf * Vector3(s * 3.0, 0.6, 1.0), Vector3(0.45, 1.2, 2.6), b, true, 0.92)
	# posts and a lean-to roof sloping back
	for s2: float in [-1.0, 1.0]:
		k.box("lore_beam", xf * Vector3(s2 * 3.0, 1.3, -2.2), Vector3(0.2, 2.6, 0.2), b, true, 0.75)
	k.box("lore_beam", xf * Vector3(0, 2.62, -2.2), Vector3(6.6, 0.2, 0.22), b, false, 0.7)
	var ra := xf * Vector3(-3.4, 2.75, -2.7)
	var rb := xf * Vector3(3.4, 2.75, -2.7)
	var rc := xf * Vector3(3.4, 2.3, 2.6)
	var rd := xf * Vector3(-3.4, 2.3, 2.6)
	var up := b * Vector3(0, 1, 0.085).normalized()
	k.quad("lore_tslate", ra, rb, rc, rd, up, true)
	k.quad("lore_beam", ra + Vector3.DOWN * 0.1, rb + Vector3.DOWN * 0.1, rc + Vector3.DOWN * 0.1, rd + Vector3.DOWN * 0.1, -up, false, 0.45)
	for i in 5:
		var t := (float(i) + 0.5) / 5.5
		var q0 := ra.lerp(rd, t)
		var q1 := rb.lerp(rc, t)
		k.box("lore_tslate", (q0 + q1) * 0.5 + up * 0.02, Vector3(6.8, 0.035, 0.9), b * Basis(Vector3.RIGHT, 0.085), false, 0.85)
	# the forge hearth against the back wall, hood and chimney
	var fh := xf * Vector3(-1.4, 0, 1.4)
	k.box("lore_tstone", fh + Vector3.UP * 0.45, Vector3(1.8, 0.9, 1.3), b, true, 0.85)
	k.box("lore_char", fh + Vector3.UP * 0.92, Vector3(1.2, 0.06, 0.8), b, false, 0.4)
	k.box("lore_ember", fh + Vector3.UP * 0.94 + b * Vector3(0, 0, 0.1), Vector3(0.5, 0.04, 0.35), b * Basis(Vector3.UP, 0.4), false, 0.55)
	for s3: float in [-1.0, 1.0]:
		k.box("lore_tstone", fh + b * Vector3(s3 * 0.8, 1.6, 0.3), Vector3(0.25, 1.4, 0.6), b, true, 0.85)
	k.box("lore_tstone", fh + b * Vector3(0, 2.15, 0.25), Vector3(1.9, 0.5, 0.8), b, true, 0.8)
	k.box("lore_tstone", fh + b * Vector3(0, 3.0, 0.45), Vector3(0.8, 1.6, 0.7), b, true, 0.9)
	# bellows (leather wedge on a frame)
	var bl := xf * Vector3(-2.7, 0.7, 1.3)
	var cm := CreatureMesh.new(9)
	cm.blob(Vector3.ZERO, Vector3(0.28, 0.12, 0.45), Basis.IDENTITY, Color(0.45, 0.32, 0.25), 0.0, 0.15, 0.0, 5, 8)
	LK.organic(p, "lore_cloth", cm.commit(), Transform3D(b * Basis(Vector3.RIGHT, 0.2), bl))
	p.box("lore_beam", bl + Vector3.DOWN * 0.35, Vector3(0.5, 0.7, 0.7), b, true, 0.7)
	# anvil on a stump, quench trough, grindstone
	var an := xf * Vector3(0.8, 0, 0.2)
	var stump := CreatureMesh.new(10)
	stump.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0.62, 0)]), PackedFloat32Array([0.34, 0.28, 0.27]), 10, Color(0.7, 0.62, 0.55), 0.0, 0.15)
	LK.organic(k, "lore_beam", stump.commit(), Transform3D(Basis.IDENTITY, an), true)
	k.box("iron", an + Vector3.UP * 0.7, Vector3(0.22, 0.16, 0.5), b, false, 0.6)
	k.box("iron", an + Vector3.UP * 0.82, Vector3(0.26, 0.1, 0.6), b, false, 0.75)
	k.box("iron", an + b * Vector3(0, 0.84, -0.4), Vector3(0.14, 0.06, 0.25), b * Basis(Vector3.RIGHT, 0.15), false, 0.75)   # horn
	p.box("iron", an + b * Vector3(0.08, 0.9, 0.1), Vector3(0.05, 0.05, 0.35), b * Basis(Vector3.UP, 0.4), false, 0.5)   # hammer
	p.box("lore_beam", an + b * Vector3(0.12, 0.9, 0.3), Vector3(0.12, 0.08, 0.08), b * Basis(Vector3.UP, 0.4), false, 0.6)
	var tr := xf * Vector3(2.2, 0, 0.9)
	k.box("lore_tstone", tr + Vector3.UP * 0.32, Vector3(0.7, 0.64, 1.5), b, true, 0.85)
	k.box("dark", tr + Vector3.UP * 0.6, Vector3(0.5, 0.04, 1.3), b, false, 0.25)
	var gs := xf * Vector3(2.4, 0, -1.2)
	for s4: float in [-1.0, 1.0]:
		p.box("lore_beam", gs + b * Vector3(s4 * 0.18, 0.4, 0), Vector3(0.08, 0.8, 0.08), b, true, 0.7)
	var wheel := CreatureMesh.new(11)
	wheel.tube(PackedVector3Array([Vector3(-0.07, 0, 0), Vector3(0.07, 0, 0)]), PackedFloat32Array([0.36, 0.36]), 14, Color(0.9, 0.88, 0.85), 0.0, 0.02, 0.0, Vector2.ONE)
	LK.organic(p, "lore_tstone", wheel.commit(), Transform3D(b, gs + Vector3.UP * 0.62))
	# tools on the back wall, a plaque
	for i in 4:
		p.box("iron", xf * Vector3(1.0 + 0.3 * float(i), 1.5, 1.98), Vector3(0.04, 0.6 - 0.08 * float(i), 0.03), b, false, 0.55)
	var pl := an + b * Vector3(0, 0.35, -0.3)
	p.box("iron", pl, Vector3(0.3, 0.2, 0.02), b * Basis(Vector3.RIGHT, 0.1), false, 0.8)
	L.letters(pl + b * Vector3(0, 0, -0.015), b * Vector3(0, 0, -1), 0.22, 2)
	L.scrap("hw_forge", an + b * Vector3(0, 0.3, -0.9))
	L.light("ForgeEmbers", fh + Vector3.UP * 1.25 + b * Vector3(0, 0, -0.5), Color(1.0, 0.42, 0.14), 0.7, 4.0)
	# (the forge's hand cart is the modelled one now: hearthward_square.gd)
	L.barrel(p, xf * Vector3(2.9, 0, -1.9), 0.9)


static func _noticeboard(L: RefCounted, c: Vector2, yaw: float) -> void:
	var p: OssKit = L.p
	var k: OssKit = L.k
	var at: Vector3 = L.gv(c.x, c.y)
	var b := Basis(Vector3.UP, yaw)
	L.site("hw_notice", Rect2(c - Vector2(1.3, 1.3), Vector2(2.6, 2.6)), at.y)
	for s: float in [-1.0, 1.0]:
		k.box("lore_beam", at + b * Vector3(s * 0.85, 1.0, 0), Vector3(0.14, 2.3, 0.14), b, true, 0.75)
	k.box("lore_beam", at + b * Vector3(0, 1.45, 0), Vector3(1.7, 1.05, 0.06), b, true, 0.65)
	for s2: float in [-1.0, 1.0]:
		k.quad("lore_tslate", at + b * Vector3(-1.05, 2.1, s2 * 0.4), at + b * Vector3(1.05, 2.1, s2 * 0.4), at + b * Vector3(1.05, 2.35, 0), at + b * Vector3(-1.05, 2.35, 0), b * Vector3(0, 0.85, s2 * 0.53), false)
	var ids := ["hw_notice_keep", "hw_notice_lost", "hw_notice_stair"]
	for i in 3:
		var q := at + b * Vector3(-0.55 + 0.55 * float(i), 1.48 + 0.08 * float(i % 2), -0.045)
		L.page(q, b * Vector3(0, 0, -1), 0.12)
		L.scrap(ids[i], at + b * Vector3(-0.9 + 0.9 * float(i), 0.4, -0.8))
	# a scrap of red hood cloth pinned beside the LOST notice
	p.box("lore_cloth", at + b * Vector3(0.2, 1.2, -0.05), Vector3(0.12, 0.2, 0.01), b * Basis(Vector3.BACK, 0.3), false, 0.0 + 0.6)


static func _shrine(L: RefCounted, c: Vector2, yaw: float) -> void:
	var k: OssKit = L.k
	var at: Vector3 = L.gv(c.x, c.y)
	var b := Basis(Vector3.UP, yaw)
	L.site("hw_shrine", Rect2(c - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), at.y)
	# stepped base, a gabled stone niche behind the saint
	k.box("lore_tstone", at + Vector3.UP * 0.0, Vector3(2.6, 0.5, 2.2), b, true, 0.8)
	k.box("lore_tstone", at + Vector3.UP * 0.3, Vector3(2.0, 0.2, 1.7), b, true, 0.88)
	var back := at + b * Vector3(0, 0, 0.75)
	k.box("lore_tstone", back + Vector3.UP * 1.6, Vector3(1.7, 2.6, 0.3), b, true)
	for s: float in [-1.0, 1.0]:
		k.box("lore_tstone", at + b * Vector3(s * 0.8, 1.6, 0.35), Vector3(0.24, 2.6, 0.9), b, true, 0.9)
	LK.half_disc(k, "lore_tstone", Transform3D(b, at + b * Vector3(0, 2.9, 0.35)), 1.0, 0.0, 1.0, 2, true, 0.85)
	var front: Vector3 = L.saint(at + Vector3.UP * 0.4 + b * Vector3(0, 0, 0.2), yaw, 0, 0.35, 0.82)
	# the bowl's coals still warm, candles, a plaque
	k.box("lore_ember", at + Vector3.UP * (0.4 + 0.35 + 1.17 * 0.82) + b * Vector3(0, 0, 0.2 - 0.33 * 0.82), Vector3(0.14, 0.03, 0.14), b, false, 0.6)
	k.candle_cluster(at + Vector3.UP * 0.4 + b * Vector3(-0.65, 0, -0.55), 3, 0.14, L.rng)
	k.candle_cluster(at + Vector3.UP * 0.4 + b * Vector3(0.65, 0, -0.55), 2, 0.12, L.rng)
	L.letters(front + b * Vector3(0, 0, -0.02), b * Vector3(0, 0, -1), 0.5, 3)
	L.scrap("hw_shrine", at + b * Vector3(0, 0.4, -1.4))


static func _woodpile(L: RefCounted, at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for row in 3:
		for i in 6 - row:
			var q := at + b * Vector3(-0.5 + 0.2 * float(i) + 0.1 * float(row), 0.1 + 0.17 * float(row), 0)
			var cm := CreatureMesh.new(L.rng.randi())
			cm.tube(PackedVector3Array([Vector3(0, 0, -0.45), Vector3(0, 0, 0.45)]), PackedFloat32Array([0.09, 0.09]), 7, Color(0.75, 0.65, 0.55), 0.0, 0.15)
			LK.organic(L.p, "lore_beam", cm.commit(), Transform3D(b * Basis(Vector3.BACK, L.rng.randf() * TAU), q))
	LK.col_box(L.p, at + b * Vector3(0, 0.3, 0), Vector3(1.3, 0.6, 0.9), b)

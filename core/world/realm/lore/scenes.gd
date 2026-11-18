extends RefCounted
## r28 (agent D): three places that tell one story without a word of narration, the Ninth
## Company's, deep in the Thornwood (built by wilds.gd after its ruins):
##   THE LAST CAMP     a cold fire ring, bedrolls (one still occupied), a lean-to fallen in, a
##                     pilgrim token hammered flat on the fire-stones; the company's first letter
##   ALDO'S GRAVE      a long mound under an arching oak root, a spade left standing, candles burnt
##                     to stubs; his name cut in the root; the second letter under a stone
##   THE NINTH RING    nine stones round a burnt circle; the third letter on the hearth-stone. The
##                     ninth stone's offering is a secret (core/life/secrets/site_company.gd): it
##                     shows itself once all three letters are read.
## Texts: lore_more.gd (series "company"). Each place registers its site and stays off the paths.

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Kit := preload("res://core/life/secrets/kit.gd")
const PlacementLog := preload("res://core/world/realm/placement_log.gd")
const SELF := "res://core/world/realm/lore/scenes.gd"

## Where each place would like to be (the nearest clear, level ground is searched from there): the
## camp in the wood south of the rift's rim, the grave a little deeper, the ring deep in the north.
const CAMP := Vector2(-46.0, -38.0)
const GRAVE := Vector2(-56.0, -54.0)
const RING := Vector2(-90.0, -58.0)
const HENGE_KEEP := 64.0   # the raid floor (RealmLayout.RAIDS henge, r 49.6 since 18 Nov) and its fill skirt

## Where the ring's ninth stone and its offering stand (site_company reads it), or {} if unplaced.
static var ring := {}
static var placed := {}


static func build(parent: Node) -> void:
	ring.clear()
	placed.clear()
	var L: RefCounted = LK.begin(parent, "NinthCompany", 9090)
	var c: Vector3 = _spot(L, "nc_camp", CAMP, 3.2, 0.8, 1.2)
	if c != Vector3.INF:
		_camp(L, c)
		placed["camp"] = c
	var g: Vector3 = _spot(L, "nc_grave", GRAVE, 2.4, 0.8, 1.0)
	if g != Vector3.INF:
		_grave(L, g)
		placed["grave"] = g
	var r: Vector3 = _spot(L, "nc_ring", RING, 4.2, 0.8, 1.9)
	if r != Vector3.INF:
		_ring(L, r)
		placed["ring"] = r
	L.finish()
	L.note("The Ninth Company", c if c != Vector3.INF else Vector3.ZERO)
	print("REALM_LORE ninth company: camp %s grave %s ring %s" % [c, g, r])


## The nearest clear, level spot to `prefer` (LoreKit.search_spot: off the paths and every site,
## this module's own earlier claim excepted), registered as a site. Its ground point, or INF.
static func _spot(L: RefCounted, n: String, prefer: Vector2, half: float, margin: float, max_rise: float) -> Vector3:
	var keep := func(q: Vector2) -> bool:
		return q.distance_to(RealmLayout.HENGE_C) > HENGE_KEEP + half and RealmLayout.region_at(q.x, q.y).get("id", "") in ["thornwood", "glade", "crags"]
	var q := LK.search_spot(L.space, prefer, 40.0, Vector2(half, half), margin, max_rise, [n], 3.0, keep)
	if q == Vector2.INF:
		print("REALM_LORE %s: no clear spot near %s" % [n, prefer])
		PlacementLog.skip("lore", n, Vector3(prefer.x, 0, prefer.y), "no clear spot")
		return Vector3.INF
	L.site(n, Rect2(q.x - half, q.y - half, half * 2.0, half * 2.0), L.g(q.x, q.y))
	return L.gv(q.x, q.y)


# --- the last camp --------------------------------------------------------------------------------

static func _camp(L: RefCounted, c: Vector3) -> void:
	var k: OssKit = L.k
	var p: OssKit = L.p
	var rng: RandomNumberGenerator = L.rng
	# the fire ring: blackened stones round char and ash, a pot tipped on its side
	for i in 9:
		var a := TAU * float(i) / 9.0 + rng.randf() * 0.2
		var q := Vector3(c.x + cos(a) * 0.62, 0, c.z + sin(a) * 0.62)
		q.y = L.g(q.x, q.z)
		L.stone(p, q, Vector3(0.3, 0.22, 0.26), "lore_rock", false, 0.3)
	k.box("lore_char", c + Vector3(0, 0.02, 0), Vector3(0.95, 0.04, 0.95), Basis(Vector3.UP, 0.4), false, 0.4)
	for i in 4:
		k.box("lore_char", c + Vector3(rng.randf_range(-0.25, 0.25), 0.08, rng.randf_range(-0.25, 0.25)), Vector3(0.55, 0.09, 0.1), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, 0.15), false, 0.5)
	p.box("iron", c + Vector3(0.75, 0.16, 0.3), Vector3(0.36, 0.3, 0.36), Basis(Vector3.BACK, 1.3), false, 0.6)
	# the flattened token, laid on the fire-stones: the first thing you read
	var tok := c + Vector3(-0.66, L.g(c.x - 0.66, c.z) - c.y + 0.24, 0.1)
	p.box("lore_bronze", tok, Vector3(0.12, 0.012, 0.16), Basis(Vector3.UP, 0.6), false, 1.0)
	L.scrap("nc_camp_token", tok + Vector3(-0.4, 0.2, 0.3), tok)
	# three bedrolls round the fire; the third is still occupied
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.5
		var at := Vector3(c.x + cos(a) * 1.9, 0, c.z + sin(a) * 1.9)
		at.y = L.g(at.x, at.z)
		var b := Basis(Vector3.UP, -a + PI * 0.5 + rng.randf_range(-0.2, 0.2))
		k.box("lore_cloth", at + Vector3.UP * 0.07, Vector3(0.75, 0.12, 1.85), b, false, 1.35)
		k.box("lore_cloth", at + b * Vector3(0, 0.12, -0.75), Vector3(0.62, 0.14, 0.3), b, false, 1.5)       # rolled head
		if i == 2:
			# a skull on the roll, ribs and long bones under a cloak drawn up to the chin
			var head := at + b * Vector3(0, 0.25, -0.72)
			k.skull(head, atan2(b.z.x, b.z.z) + PI, 1.0, 1, -0.5)
			k.box("lore_cloth", at + b * Vector3(0, 0.2, 0.15), Vector3(0.6, 0.12, 1.25), b * Basis(Vector3.RIGHT, 0.04), false, 0.9)
			for j in 3:
				k.bone(at + b * Vector3(rng.randf_range(-0.2, 0.2), 0.16, 0.7 + 0.1 * float(j)), b * Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), 0, false)
		if i == 0:
			# the company's first letter, folded on the empty roll
			var lp := at + b * Vector3(0.1, 0.15, 0.3)
			L.page(lp, Vector3.UP, 0.4)
			L.scrap("nc_company_1", lp + Vector3.UP * 0.2, lp)
	# a lean-to, fallen in: two poles and a slack sheet
	var lt := c + Basis(Vector3.UP, -2.2) * Vector3(0, 0, 2.6)
	lt.y = L.g(lt.x, lt.z)
	var lb := Basis(Vector3.UP, -2.2 + PI)
	k.box("lore_beam", lt + lb * Vector3(-0.9, 0.55, 0), Vector3(0.08, 1.3, 0.08), lb * Basis(Vector3.BACK, 0.5), true, 0.7)
	k.box("lore_beam", lt + lb * Vector3(0.9, 0.3, 0.1), Vector3(0.08, 1.3, 0.08), lb * Basis(Vector3.BACK, -1.1), false, 0.7)
	k.box("lore_cloth", lt + lb * Vector3(0, 0.35, 0.3), Vector3(2.0, 0.04, 1.4), lb * Basis(Vector3.RIGHT, 0.45), false, 0.7)
	# packs, a pilgrim's staff with its bell, candles burnt out
	k.box("lore_cloth", c + Vector3(1.4, L.g(c.x + 1.4, c.z - 1.3) - c.y + 0.22, -1.3), Vector3(0.45, 0.45, 0.32), Basis(Vector3.UP, 0.9), true, 0.7)
	k.box("lore_beam", c + Vector3(-1.6, L.g(c.x - 1.6, c.z - 1.0) - c.y + 0.05, -1.0), Vector3(0.05, 0.05, 1.7), Basis(Vector3.UP, 0.3), false, 0.8)
	L.cairn(p, Vector3(c.x - 2.6, L.g(c.x - 2.6, c.z + 1.2), c.z + 1.2), 0.45)


# --- Aldo's grave -------------------------------------------------------------------------------

static func _grave(L: RefCounted, g: Vector3) -> void:
	var k: OssKit = L.k
	var p: OssKit = L.p
	var rng: RandomNumberGenerator = L.rng
	# laid facing the Stair: the mound's head toward the summit
	var to_stair := Vector2(0.0 - g.x, -90.0 - g.z).normalized()
	var yaw := atan2(to_stair.x, to_stair.y)
	var b := Basis(Vector3.UP, yaw)
	var mound: ArrayMesh = Kit.cached_mesh("nc_mound", func() -> ArrayMesh:
		var cm := CreatureMesh.new(4141)
		cm.blob(Vector3.ZERO, Vector3(0.6, 0.32, 1.15), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.25, 0.0, 6, 10)
		return cm.commit(), false, SELF)
	LK.organic(k, "lore_earth", mound, Transform3D(b, g + Vector3.DOWN * 0.02), false)
	LK.col_box(k, g + Vector3.UP * 0.1, Vector3(1.1, 0.35, 2.1), b)
	# edged with field stones the way the Rooted edged theirs, a sprig of oak on the breast
	for i in 12:
		var t := float(i) / 12.0 * TAU
		var e := g + b * Vector3(cos(t) * 0.75, 0, sin(t) * 1.3)
		e.y = L.g(e.x, e.z)
		L.stone(p, e, Vector3(0.26, 0.18, 0.22), "lore_rock", false, 0.3)
	k.box("lore_leaf", g + b * Vector3(0, 0.36, 0.2), Vector3(0.3, 0.04, 0.5), b * Basis(Vector3.UP, 0.4), false, 1.3)
	# the oak root arching over the head of it: a thick gnarled tube out of the ground and back in
	var root: ArrayMesh = Kit.cached_mesh("nc_root", func() -> ArrayMesh:
		var cm := CreatureMesh.new(4242)
		var pts := PackedVector3Array()
		var rad := PackedFloat32Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector3(lerpf(-1.5, 1.6, t), sin(t * PI) * 1.25 - 0.25, sin(t * 7.0) * 0.12))
			rad.append(lerpf(0.26, 0.14, t) * (1.0 + 0.15 * sin(t * 11.0)))
		cm.tube(pts, rad, 9, Color(1, 1, 1), 0.3, 0.08)
		cm.tube(PackedVector3Array([Vector3(-1.0, 0.4, 0.0), Vector3(-0.8, 0.1, 0.5), Vector3(-0.5, -0.2, 0.75)]), PackedFloat32Array([0.11, 0.08, 0.05]), 6, Color(0.9, 0.9, 0.9), 0.3, 0.05)
		return cm.commit(), false, SELF)
	var rhead := g + b * Vector3(0, 0, 1.35)
	if not OssKit._mats.has("sc_bark"):
		OssKit._mats["sc_bark"] = Kit.mat("bark")
	LK.organic(k, "sc_bark", root, Transform3D(b, rhead), false)
	LK.col_box(k, rhead + b * Vector3(-1.25, 0.45, 0), Vector3(0.45, 0.9, 0.45), b)
	LK.col_box(k, rhead + b * Vector3(1.3, 0.4, 0), Vector3(0.4, 0.8, 0.4), b)
	# the name in the root (a cut panel, faintly lit)
	var face := rhead + b * Vector3(0.0, 1.02, -0.22)
	L.panel(face, -b.z, 0.5, 0.18, 0)
	L.scrap("nc_burial_root", g + b * Vector3(0.9, 0.3, 0.9), face)
	# a spade left standing, candles burnt to stubs at the foot, the second letter under a stone
	var sp := g + b * Vector3(0.75, 0, -0.6)
	sp.y = L.g(sp.x, sp.z)
	k.box("lore_beam", sp + Vector3.UP * 0.62, Vector3(0.05, 1.05, 0.05), b * Basis(Vector3.RIGHT, 0.12), false, 0.75)
	k.box("iron", sp + Vector3.UP * 0.05, Vector3(0.22, 0.28, 0.03), b * Basis(Vector3.RIGHT, 0.12), false, 0.6)
	k.box("lore_beam", sp + Vector3.UP * 1.14, Vector3(0.2, 0.04, 0.04), b, false, 0.7)
	var foot := g + b * Vector3(0, 0, -1.3)
	foot.y = L.g(foot.x, foot.z)
	p.candle_cluster(foot, 5, 0.22, rng)
	var lp := g + b * Vector3(-0.85, 0, -0.9)
	lp.y = L.g(lp.x, lp.z) + 0.04
	L.page(lp, Vector3.UP, 0.5)
	L.stone(p, lp + b * Vector3(0.12, 0.05, 0.1), Vector3(0.22, 0.14, 0.2), "lore_rock", false, 0.2)
	L.scrap("nc_company_2", lp + Vector3.UP * 0.25, lp)


# --- the ninth ring --------------------------------------------------------------------------------

static func _ring(L: RefCounted, c: Vector3) -> void:
	var k: OssKit = L.k
	var p: OssKit = L.p
	var rng: RandomNumberGenerator = L.rng
	var rr := 3.6
	for i in 9:
		var a := TAU * float(i) / 9.0 - PI * 0.5        # i = 0 is north: the ninth, last stone
		var q := Vector3(c.x + cos(a) * rr, 0, c.z + sin(a) * rr)
		q.y = L.g(q.x, q.z)
		var ninth := i == 0
		var size := Vector3(0.75, 1.9, 0.55) if ninth else Vector3(0.5, rng.randf_range(1.0, 1.5), 0.42)
		var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.BACK, rng.randf_range(-0.06, 0.06))
		var shaft: ArrayMesh = Kit.cached_mesh("nc_menhir%d" % (i % 3), func() -> ArrayMesh:
			var cm := CreatureMesh.new(5150 + i % 3)
			cm.blob(Vector3(0, 0.5, 0), Vector3(0.5, 0.55, 0.5), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.18, 0.0, 7, 9)
			return cm.commit(), false, SELF)
		LK.organic(k, "lore_moss", shaft, Transform3D(b.scaled(size), q + Vector3.DOWN * 0.2), false)
		LK.col_box(k, q + Vector3.UP * size.y * 0.45, Vector3(size.x * 0.8, size.y * 0.9, size.z * 0.8), b)
		# a name scratched off each (a pale scar on the inner face)
		var inner := Vector3(c.x - q.x, 0, c.z - q.z).normalized()
		k.box("lore_tstone", q + inner * (size.z * 0.42) + Vector3.UP * size.y * 0.55, Vector3(0.22, 0.12, 0.02), Basis(Vector3.UP, atan2(inner.x, inner.z)), false, 1.2)
		if ninth:
			ring = {"at": q, "inner": inner, "size": size}
		elif i % 2 == 0:
			p.candle_cluster(q + inner * 0.55, 3, 0.12, rng)
	# the burnt circle and its hearth-stone; tokens melted into the ash
	var ash := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(4.2, 4.2)
	quad.orientation = PlaneMesh.FACE_Y
	ash.mesh = quad
	ash.material_override = Kit.shader_mat("scorch")
	ash.set_instance_shader_parameter(&"tint", Color(1.0, 0.45, 0.18))
	ash.set_instance_shader_parameter(&"glow", 0.25)
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ash.visibility_range_end = LK.PROP_RANGE
	(L.holder as Node3D).add_child(ash)
	ash.global_position = c + Vector3.UP * 0.04
	var hs := c + Vector3(0.3, 0, 0.4)
	hs.y = L.g(hs.x, hs.z)
	k.box("lore_tstone", hs + Vector3.UP * 0.12, Vector3(0.9, 0.24, 0.6), Basis(Vector3.UP, 0.4), true, 0.9)
	var face: Vector3 = hs + Vector3.UP * 0.25
	L.panel(face, Vector3.UP, 0.6, 0.35, 0)
	L.scrap("nc_ring_ash", hs + Vector3(0.0, 0.3, -0.7), face)
	for i in 7:
		var q2 := c + Vector3(rng.randf_range(-1.3, 1.3), 0, rng.randf_range(-1.3, 1.3))
		p.box("lore_bronze", Vector3(q2.x, L.g(q2.x, q2.z) + 0.02, q2.z), Vector3(0.1, 0.012, 0.12), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2)), false, 0.5)
	var lp := c + Vector3(-1.0, 0, -0.6)
	lp.y = L.g(lp.x, lp.z) + 0.04
	L.page(lp, Vector3.UP, 0.6)
	L.scrap("nc_company_3", lp + Vector3.UP * 0.25, lp)

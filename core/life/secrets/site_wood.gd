extends RefCounted
## The west and the edges (secrets):
##   oak    THE HOLLOW OAK (deep Thornwood): a giant hollow oak, its mouth choked with living thorn
##          that will not part while the Thornwarden keeps the wood. When it falls the thorn withers
##          and the oak can be entered: the Rooted's offering inside. Elite: the Thorn-Wild (a leaper).
##   cist   ANSEL'S CIST (behind the Chapel of the First Kindling): five kneeling stones carved with
##          the road's mile numbers (XII, IX, VII, V, III). Ansel's mark: kneel at twelve, at seven,
##          at three. Then the cist under the cairn opens.
##   pell   PELL'S DEN (the rift rim's south slope): a hiding place under stones; a red hood, a slate.
##   cairn  HOBB'S CAIRN (the Crowns): a cut stair up the mountain's foot to a pilgrim's cairn
##          looking back over the valley.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")

const OAK := Vector2(-140.0, -80.0)   # past the henge hill's skirt (18 Nov: (-124, -62) was on the 1.6x raid floor; r34: (-100, -42))
const CIST := Vector2(-103.0, 59.5)          # (18 Nov: the cist and its stones moved (-6, +14) off the henge hill's 1.6x skirt)
const KNEEL := [["XII", Vector2(-104.0, 68.0)], ["IX", Vector2(-108.5, 61.5)], ["VII", Vector2(-100.0, 51.0)], ["V", Vector2(-96.0, 44.5)], ["III", Vector2(-91.0, 43.5)]]
const ANSEL := ["XII", "VII", "III"]
const PELL := Vector2(-16.0, 2.5)
const CAIRN := Vector2(-70.0, -122.0)

static var _knelt: Array[String] = []


static func build(root: Node, host: Node3D) -> void:
	# a fresh build is a cold one: puzzle progress that is not the save does not outlive its night
	_knelt.clear()
	var sp := Kit.space(root)
	var node := Node3D.new()
	node.name = "Wood"
	node.set_meta("site", "secrets_wood")
	host.add_child(node)
	_oak(root, node, sp)
	_cist(root, node, sp)
	_pell(root, node, sp)
	_cairn(root, node, sp)


# --- the hollow oak ----------------------------------------------------------------------------------

static func _oak(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	Kit.clear_flora(root, [Vector3(OAK.x, OAK.y, 6.5), Vector3(OAK.x + 6.0, OAK.y, 3.5)])
	var node := Node3D.new()
	node.name = "HollowOak"
	parent.add_child(node)
	var g := Kit.low(sp, OAK, 2.6)
	var o := Vector3(OAK.x, g, OAK.y)
	Kit.site(root, "secrets_oak", Rect2(OAK.x - 4.5, OAK.y - 4.5, 9.0, 9.0), g)
	const N := 14
	const MOUTH := 0.0               # the opening faces +x (east, toward the henge)
	var mesh := Kit.cached_mesh("hollow_oak_4", func() -> ArrayMesh:
		var cm := CreatureMesh.new(41)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in N:
			var a := TAU * float(i) / float(N)
			if absf(wrapf(a - MOUTH, -PI, PI)) < 0.55:
				continue
			var h := rng.randf_range(6.5, 10.5) * (0.75 if absf(wrapf(a - MOUTH, -PI, PI)) < 0.9 else 1.0)
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			for q in 7:
				var t := float(q) / 6.0
				var r := lerpf(2.35, 1.75, sqrt(t)) + sin(t * 5.0 + float(i)) * 0.12
				var aa := a + sin(t * 3.0 + float(i) * 1.7) * 0.05
				pts.append(Vector3(cos(aa) * r, -0.5 + t * h, sin(aa) * r))
				rad.append(lerpf(0.72, 0.36, t) * (0.6 if q == 6 else 1.0))
			cm.tube(pts, rad, 7, Color(0.85, 0.82, 0.8), 0.0, 0.2)
		# the lips of the mouth: thicker, rounded ridges
		for s: float in [-1.0, 1.0]:
			var a2 := MOUTH + s * 0.58
			var pts2 := PackedVector3Array()
			var rad2 := PackedFloat32Array()
			for q in 6:
				var t2 := float(q) / 5.0
				pts2.append(Vector3(cos(a2) * lerpf(2.4, 1.9, t2), -0.4 + t2 * 4.8, sin(a2) * lerpf(2.4, 1.9, t2)))
				rad2.append(lerpf(0.5, 0.36, t2))
			cm.tube(pts2, rad2, 7, Color(0.8, 0.78, 0.76), 0.0, 0.18)
		# lintel over the mouth (the trunk closes above it)
		var arc := PackedVector3Array()
		var arr := PackedFloat32Array()
		for q in 7:
			var t3 := float(q) / 6.0
			var a3 := MOUTH - 0.62 + t3 * 1.24
			arc.append(Vector3(cos(a3) * 2.1, 2.7 + sin(t3 * PI) * 0.5, sin(a3) * 2.1))
			arr.append(0.55)
		cm.tube(arc, arr, 7, Color(0.8, 0.78, 0.76), 0.0, 0.2)
		# roots
		for i in 11:
			var a4 := TAU * (float(i) + 0.3) / 11.0
			if absf(wrapf(a4 - MOUTH, -PI, PI)) < 0.45:
				continue
			var len := rng.randf_range(2.5, 4.5)
			var pts3 := PackedVector3Array()
			var rad3 := PackedFloat32Array()
			for q in 6:
				var t4 := float(q) / 5.0
				var r4 := 2.0 + t4 * len
				pts3.append(Vector3(cos(a4 + t4 * 0.2) * r4, 0.7 * (1.0 - t4) - t4 * 0.45, sin(a4 + t4 * 0.2) * r4))
				rad3.append(lerpf(0.6, 0.1, t4))
			cm.tube(pts3, rad3, 6, Color(0.8, 0.78, 0.76), 0.0, 0.25)
		# two dead limbs from the broken crown
		for s2: float in [1.0, -1.0]:
			var a5 := PI + s2 * 1.2
			var base := Vector3(cos(a5) * 1.8, 8.0, sin(a5) * 1.8)
			var pts4 := PackedVector3Array([base, base + Vector3(cos(a5) * 1.6, 1.4, sin(a5) * 1.6), base + Vector3(cos(a5) * 3.4, 1.9, sin(a5) * 3.0 + 0.6), base + Vector3(cos(a5) * 4.6, 1.6, sin(a5) * 4.2 + 1.0)])
			cm.tube(pts4, PackedFloat32Array([0.45, 0.32, 0.18, 0.05]), 6, Color(0.75, 0.73, 0.72), 0.0, 0.15)
		# leaf litter floor inside
		cm.blob(Vector3(0, -0.15, 0), Vector3(1.8, 0.22, 1.8), Basis.IDENTITY, Color(0.32, 0.24, 0.16), 0.0, 0.2, 0.0, 4, 12)
		return cm.commit(), true)
	var tree := Kit.mi(node, mesh, Kit.mat("bark"), Transform3D(Basis.IDENTITY, o), 0.0)
	tree.name = "Oak"
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	node.add_child(body)
	body.global_position = o
	for i in N:
		var a := TAU * float(i) / float(N)
		if absf(wrapf(a - MOUTH, -PI, PI)) < 0.55:
			continue
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.62
		cy.height = 5.0
		cs.shape = cy
		cs.position = Vector3(cos(a) * 2.15, 2.4, sin(a) * 2.15)
		body.add_child(cs)
	for s3: float in [-1.0, 1.0]:        # the mouth's lips
		var lcs := CollisionShape3D.new()
		var lcy := CylinderShape3D.new()
		lcy.radius = 0.4
		lcy.height = 5.0
		lcs.shape = lcy
		lcs.position = Vector3(cos(MOUTH + s3 * 0.58) * 2.2, 2.4, sin(MOUTH + s3 * 0.58) * 2.2)
		body.add_child(lcs)
	# the thorn in its mouth
	var thorn := Kit.cached_mesh("oak_thorn_2", func() -> ArrayMesh:
		var cm2 := CreatureMesh.new(17)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 99
		for i in 34:
			var z0 := rng2.randf_range(-0.9, 0.9)
			var pts5 := PackedVector3Array()
			var rad5 := PackedFloat32Array()
			for q in 5:
				var t5 := float(q) / 4.0
				pts5.append(Vector3(rng2.randf_range(-0.4, 0.4), t5 * rng2.randf_range(1.6, 3.0), z0 + sin(t5 * 6.0 + float(i)) * 0.5))
				rad5.append(lerpf(0.07, 0.02, t5))
			cm2.tube(pts5, rad5, 5, Color(0.2, 0.09, 0.07), 0.0, 0.25)
			for q2 in 3:
				var b := pts5[q2 + 1]
				cm2.claw(b, Vector3(rng2.randf_range(-1, 1), rng2.randf_range(-0.2, 0.6), rng2.randf_range(-1, 1)).normalized(), 0.12, 0.025, Vector3.ZERO, Color(0.3, 0.12, 0.08))
		return cm2.commit())
	var mouth := o + Vector3(2.05, 0.0, 0.0)
	var thorn_mi := Kit.mi(node, thorn, Kit.mat("thorn"), Transform3D(Basis.IDENTITY, mouth), 70.0)
	thorn_mi.name = "Thorn"
	var thorn_body := Kit.box_body(node, mouth + Vector3.UP * 1.4, Vector3(0.8, 2.8, 2.0))
	# inside: the Rooted's offering
	var bowl := o + Vector3(-1.0, 0.0, 0.0)
	var bowl_rock := RockKit.boulder(7, Vector3(0.9, 0.5, 0.8), "mossy")
	RockKit.spawn(node, bowl_rock, Transform3D(Basis.IDENTITY, bowl), false, 40.0)
	Kit.box_body(node, bowl + Vector3.UP * 0.25, Vector3(0.8, 0.5, 0.7))
	var seeds := Kit.mi(node, _sphere(0.12), Kit.mat("bronze"), Transform3D(Basis.IDENTITY, bowl + Vector3(0, 0.55, 0)), 30.0)
	seeds.name = "SeedStone"
	State.cache(node, "oak", bowl + Vector3(0.3, 0.6, 0), "the Rooted's offering", func(_a: bool) -> void: seeds.visible = false,
		func() -> bool: return State.has("open", "oak"))
	var carve := State.reading(node, "sc_oak", o + Vector3(-0.6, 1.5, 1.3))
	var sync := func(animate: bool) -> void:
		var open := Travel.bosses_slain.has("thornwarden") or State.has("open", "oak")   # once open, stays (NG+ too)
		if open:
			State.mark("open", "oak", false)
		Kit.set_body(thorn_body, not open)
		carve.set("enabled", open)
		thorn_mi.material_override = Kit.mat("thorn_dead" if open else "thorn")
		var to := Vector3(1.0, 0.18, 1.0) if open else Vector3.ONE
		if animate and open:
			Kit.fx_dust(mouth + Vector3.UP * 1.0, Color(0.35, 0.3, 0.25, 0.8), 30)
			thorn_mi.create_tween().tween_property(thorn_mi, "scale", to, 4.0).set_trans(Tween.TRANS_SINE)
		else:
			thorn_mi.scale = to
	var shut := Kit.touch(node, mouth + Vector3(0.6, 1.2, 0), "", func(_by: Node) -> void:
		State.toast("The thorn is alive in the oak's mouth. It knows whose wood this is."), 2.2)
	shut.set("prompt_fn", func() -> String: return "" if Travel.bosses_slain.has("thornwarden") or State.has("open", "oak") else "Part the thorn")
	State.elite({"id": "thorn_wild", "kind": "leaper", "title": "The Thorn-Wild", "at": o + Vector3(7.0, 0.3, 2.0),
		"when": func() -> bool: return Travel.bosses_slain.has("thornwarden")})
	State.register({"id": "oak", "name": "The Hollow Oak", "at": o + Vector3(3.0, 0, 0), "r": 7.0, "node": node, "sync": sync,
		# r34 layout: the oak moved west of the henge's hill (its raid floor): walked in from west_track
		"route": {"from": Vector3(-118.0, 0.0, -76.0), "pts": _v3([Vector2(-116, -67), Vector2(OAK.x + 5.0, OAK.y), Vector2(OAK.x + 2.6, OAK.y)])},
		"goal": Vector3(OAK.x + 2.6, g, OAK.y), "inside": Vector3(OAK.x - 0.3, g, OAK.y), "door": thorn_body})


# --- Ansel's cist and the kneeling stones -------------------------------------------------------------

static func _cist(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var node := Node3D.new()
	node.name = "Cist"
	parent.add_child(node)
	var cp := Kit.free_spot(sp, CIST, 2.2)
	var discs: Array = [Vector3(cp.x, cp.y, 3.6)]
	var spots := []
	for kn: Array in KNEEL:
		var p := Kit.free_spot(sp, kn[1], 1.4)
		spots.append(p)
		discs.append(Vector3(p.x, p.y, 1.8))
	Kit.clear_flora(root, discs)
	var g := Kit.low(sp, cp, 1.3)
	Kit.site(root, "secrets_cist", Rect2(cp.x - 2.0, cp.y - 2.0, 4.0, 4.0), g)
	var k := OssKit.new()
	k.keep_lanes = false
	var c := Vector3(cp.x, g, cp.y)
	# the cist: a stone box sunk in the ground, a rough cairn behind it, a marker slab
	for s: float in [-1.0, 1.0]:
		k.box("stone", c + Vector3(s * 0.75, 0.2, 0), Vector3(0.16, 0.7, 1.0), Basis.IDENTITY, true, 0.8)
		k.box("stone", c + Vector3(0, 0.2, s * 0.5), Vector3(1.6, 0.7, 0.14), Basis.IDENTITY, true, 0.8)
	k.box("dark", c + Vector3(0, 0.0, 0), Vector3(1.4, 0.1, 0.9), Basis.IDENTITY, false, 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in 9:
		var a := rng.randf_range(-1.0, 1.0)
		k.box("stone", c + Vector3(-1.5 + rng.randf_range(-0.3, 0.3), 0.2 + 0.25 * float(i % 3), a * 0.7), Vector3(0.5, 0.35, 0.45), Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0)), i < 3, 0.75)
	k.box("stone", c + Vector3(-1.1, 0.7, 1.1), Vector3(0.5, 1.4, 0.16), Basis(Vector3.UP, 0.5), true, 0.9)
	k.box("dark", c + Vector3(-1.04, 1.0, 1.18), Vector3(0.12, 0.3, 0.04), Basis(Vector3.UP, 0.5), false)
	k.box("dark", c + Vector3(-1.04, 1.08, 1.18), Vector3(0.24, 0.05, 0.04), Basis(Vector3.UP, 0.5), false)   # the chisel's cross
	# the kneeling stones
	var embers := {}
	for i in KNEEL.size():
		var num: String = KNEEL[i][0]
		var p2: Vector2 = spots[i]
		var gy := Kit.gy(sp, p2.x, p2.y)
		var face := Vector3(c.x - p2.x, 0, c.z - p2.y).normalized()
		var side := face.cross(Vector3.UP).normalized()
		var bas := Basis(side, Vector3.UP, face)
		var st := Vector3(p2.x, gy, p2.y)
		k.box("stone", st + Vector3.UP * 0.4, Vector3(0.55, 0.9, 0.26), bas, true, 0.88)
		k.box("stone", st + Vector3.UP * 0.86, Vector3(0.62, 0.14, 0.32), bas, true, 0.8)
		k.box("stone", st + face * 0.62 + Vector3.UP * 0.05, Vector3(0.7, 0.12, 0.5), bas, false, 0.7)   # the kneeling slab
		_numeral(k, num, st + Vector3.UP * 0.5 + face * 0.135, bas)
		var em := Kit.mi(node, _quad(0.16), Kit.mat("ember_off"), Transform3D(bas, st + Vector3.UP * 0.74 + face * 0.14), 40.0, false)
		embers[num] = em
		Kit.touch(node, st + face * 0.6 + Vector3.UP * 0.6, "Kneel at the stone marked %s" % num, func(_by: Node) -> void: _kneel(num, embers, st), 1.8)
	k.commit(node, "CistBody")
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = 90.0
	var lid := Kit.mi(node, _box(Vector3(1.6, 0.16, 1.1)), OssKit.mat("stone"), Transform3D(Basis.IDENTITY, c + Vector3.UP * 0.63), 80.0)
	lid.name = "CistLid"
	var lid_body := Kit.box_body(node, c + Vector3.UP * 0.63, Vector3(1.6, 0.16, 1.1))
	var tin := Kit.mi(node, _box(Vector3(0.36, 0.14, 0.24)), OssKit.mat("iron"), Transform3D(Basis(Vector3.UP, 0.4), c + Vector3.UP * 0.12), 30.0)
	State.reading(node, "sc_ansel_way", c + Vector3(-1.1, 1.3, 1.1))
	var inner := State.reading(node, "sc_ansel_cist", c + Vector3(0.3, 0.4, 0.0))
	State.cache(node, "cist", c + Vector3(-0.3, 0.4, 0), "Ansel's tin", func(_a: bool) -> void: tin.visible = false,
		func() -> bool: return State.has("solved", "cist"))
	var sync := func(animate: bool) -> void:
		var open := State.has("solved", "cist")
		inner.set("enabled", open)
		lid_body.collision_layer = 0 if open else Layers.WORLD
		var to := Transform3D(Basis(Vector3.FORWARD, 0.28), c + Vector3(0.95, 0.42, 0.25)) if open else Transform3D(Basis.IDENTITY, c + Vector3.UP * 0.63)
		if animate and open:
			Kit.play("grind", c, 0.0, 1.3)
			lid.create_tween().tween_property(lid, "global_transform", to, 1.8).set_trans(Tween.TRANS_SINE)
		else:
			lid.global_transform = to
		for num2: String in embers:
			(embers[num2] as MeshInstance3D).material_override = Kit.mat("ember" if (open and num2 in ANSEL) or (not open and num2 in _knelt) else "ember_off")
	var route_pts: Array[Vector3] = [Vector3(-72, 0, 60), Vector3(-86, 0, 61.5), Vector3(-96, 0, 58.5)]
	var sx: Vector2 = spots[0]
	route_pts.append(Vector3(sx.x + 1.2, 0, sx.y + 0.8))
	route_pts.append(Vector3(cp.x + 1.4, 0, cp.y + 1.0))
	State.register({"id": "cist", "name": "Ansel's Cist", "at": c, "r": 6.0, "node": node, "sync": sync, "kneel": spots, "embers": embers,
		"route": {"from": Vector3(-60.0, 0.0, 58.0), "pts": route_pts}, "goal": Vector3(cp.x + 1.4, g, cp.y + 1.0)})


static func _kneel(num: String, embers: Dictionary, at: Vector3) -> void:
	if State.has("solved", "cist"):
		return
	_knelt.append(num)
	var want: String = ANSEL[_knelt.size() - 1]
	if num != want:
		_knelt.clear()
		Kit.play("clank", at, -12.0, 0.6)
		State.toast("The stone is cold under your knees.")
		State.refresh(false)
		return
	Kit.play("hum", at, -8.0, 0.9 + 0.1 * float(_knelt.size()))
	Kit.fx_sparks(at + Vector3.UP * 0.75, Color(1.3, 0.6, 0.25))
	if _knelt.size() < ANSEL.size():
		State.refresh(false)
		return
	_knelt.clear()
	State.mark("solved", "cist")
	State.toast("Twelve, seven, three. Behind the chapel a stone lid shifts.")
	State.banner("as he knelt", "Ansel's Cist")
	State.refresh(true)


static func _numeral(k: OssKit, num: String, at: Vector3, b: Basis) -> void:
	var glyphs := num.split("")
	var w := 0.11
	var x0 := -float(glyphs.size() - 1) * w * 0.5
	for i in glyphs.size():
		var p := at + b.x * (x0 + w * float(i))
		match glyphs[i]:
			"I":
				k.box("dark", p, Vector3(0.025, 0.2, 0.02), b, false)
			"V":
				k.box("dark", p + b.x * -0.025, Vector3(0.022, 0.21, 0.02), b.rotated(b.z, -0.25), false)
				k.box("dark", p + b.x * 0.025, Vector3(0.022, 0.21, 0.02), b.rotated(b.z, 0.25), false)
			"X":
				k.box("dark", p, Vector3(0.022, 0.23, 0.02), b.rotated(b.z, 0.5), false)
				k.box("dark", p, Vector3(0.022, 0.23, 0.02), b.rotated(b.z, -0.5), false)


# --- Pell's den ---------------------------------------------------------------------------------------

static func _pell(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var node := Node3D.new()
	node.name = "PellsDen"
	parent.add_child(node)
	var p := PELL                    # its own spot: the trees there are cleared (a free-spot search let a tree push it 4 m into its own walk)
	Kit.clear_flora(root, [Vector3(p.x, p.y, 2.6)])
	var g := Kit.gy(sp, p.x, p.y)
	var c := Vector3(p.x, g, p.y)
	Kit.site(root, "secrets_pell", Rect2(p.x - 1.8, p.y - 1.8, 3.6, 3.6), g)
	# two leaning boulders and a slab roof: a child-sized hollow
	RockKit.spawn(node, RockKit.boulder(3, Vector3(1.6, 1.1, 1.2), "granite"), Transform3D(Basis(Vector3.UP, 0.4).rotated(Vector3.FORWARD, 0.25), c + Vector3(-0.9, -0.1, 0)), false, 60.0)
	RockKit.spawn(node, RockKit.boulder(5, Vector3(1.4, 1.0, 1.3), "granite"), Transform3D(Basis(Vector3.UP, 2.1).rotated(Vector3.FORWARD, -0.2), c + Vector3(0.9, -0.1, 0.1)), false, 60.0)
	RockKit.spawn(node, RockKit.slab(8, Vector3(2.4, 0.3, 1.4), "mossy", 0.1), Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, 0.1), c + Vector3(0, 1.05, 0.65)), false, 60.0)
	for s4: float in [-1.0, 1.0]:              # simple collision: the two boulders
		Kit.box_body(node, c + Vector3(s4 * 1.0, 0.45, 0.0), Vector3(1.2, 0.95, 1.1))
	# the hood: a fold of red cloth; the slate leaning by it
	var hood := Kit.cached_mesh("pell_hood", func() -> ArrayMesh:
		var cm := CreatureMesh.new(3)
		cm.blob(Vector3.ZERO, Vector3(0.22, 0.07, 0.17), Basis(Vector3.UP, 0.3), Color.WHITE, 0.0, 0.25, 0.0, 6, 10)
		cm.blob(Vector3(0.12, 0.05, 0.05), Vector3(0.1, 0.08, 0.09), Basis.IDENTITY, Color.WHITE, 0.0, 0.3, 0.0, 6, 10)
		return cm.commit())
	Kit.mi(node, hood, Kit.mat("cloth_red"), Transform3D(Basis.IDENTITY, c + Vector3(0.0, 0.07, -0.1)), 30.0)
	Kit.mi(node, _box(Vector3(0.32, 0.24, 0.02)), OssKit.mat("slate"), Transform3D(Basis(Vector3.RIGHT, -0.3), c + Vector3(0.3, 0.13, 0.2)), 30.0)
	Kit.glint(node, c + Vector3(0, 0.5, -0.1), Color(1.0, 0.4, 0.35), 0.22, 18.0)
	State.reading(node, "sc_pell", c + Vector3(0.3, 0.3, 0.2), "Read")
	State.cache(node, "pell", c + Vector3(0.0, 0.3, -0.1), "the bundle under the hood", func(_a: bool) -> void: pass)
	State.register({"id": "pell", "name": "Pell's Den", "at": c, "r": 4.0, "node": node,
		"route": {"from": Vector3(-4.0, 0.0, 14.0), "pts": _v3([Vector2(p.x + 3.0, p.y + 2.5), Vector2(p.x + 0.4, p.y - 1.4)])},
		"goal": Vector3(p.x + 0.4, g, p.y - 1.4)})


# --- Hobb's cairn ----------------------------------------------------------------------------------

static func _cairn(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var node := Node3D.new()
	node.name = "HobbsCairn"
	parent.add_child(node)
	var top2 := CAIRN
	Kit.clear_flora(root, [Vector3(top2.x, top2.y + 4.0, 6.0)])
	var k := OssKit.new()
	k.keep_lanes = false
	var ty := Kit.gy(sp, top2.x, top2.y) + 0.1
	# a cut stair down the mountain's foot (south), seated on the slope
	var dir := Vector2(0, 1)
	var p := top2 + dir * 1.6
	var y := ty
	var steps: Array = []
	for i in 40:
		var hi := -INF
		for o: float in [-0.7, 0.0, 0.7]:
			for q: float in [0.0, 0.25, 0.5]:
				hi = maxf(hi, Kit.gy(sp, p.x + o, p.y + q))
		var ny := maxf(y - 0.34, hi + 0.06)
		steps.append([p + dir * 0.25, ny])
		y = ny
		p += dir * 0.5
		if y - Kit.gy(sp, p.x, p.y) < 0.1 and i > 4:
			break
	for i in steps.size():
		var c2: Vector2 = steps[i][0]
		var sy: float = steps[i][1]
		var gl := minf(Kit.gy(sp, c2.x - 0.7, c2.y), Kit.gy(sp, c2.x + 0.7, c2.y))
		k.box("stone", Vector3(c2.x, (sy + gl - 0.5) * 0.5, c2.y), Vector3(1.4, sy - gl + 0.5, 0.53), Basis.IDENTITY, true, 0.84 if i % 2 == 0 else 0.94)
	# the terrace (level with the top step) and the cairn
	ty = steps[0][1]
	var tg := minf(Kit.gy(sp, top2.x - 1.5, top2.y - 1.5), Kit.gy(sp, top2.x + 1.5, top2.y + 1.5))
	k.block("stone", Vector3(top2.x - 1.6, tg - 0.5, top2.y - 1.6), Vector3(top2.x + 1.6, ty, top2.y + 1.6), true, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var cc := Vector3(top2.x - 0.5, ty, top2.y - 0.1)
	for j in 7:
		var s := 0.8 - 0.09 * float(j)
		k.box("stone", cc + Vector3(rng.randf_range(-0.05, 0.05), 0.15 + 0.26 * float(j), rng.randf_range(-0.05, 0.05)), Vector3(s, 0.28, s * 0.85), Basis(Vector3.UP, rng.randf() * TAU), j < 2, rng.randf_range(0.75, 0.95))
	k.box("slate", cc + Vector3(0, 2.0, 0), Vector3(0.36, 0.06, 0.26), Basis(Vector3.UP, 0.3), false)
	k.commit(node, "CairnBody")
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = 120.0
	Kit.site(root, "secrets_cairn", Rect2(top2.x - 2.0, top2.y - 2.0, 4.0, 4.0 + float(steps.size()) * 0.5), ty)
	State.reading(node, "sc_hobb", cc + Vector3(0.5, 1.2, 0.6))
	State.cache(node, "cairn", cc + Vector3(0.7, 0.4, 0.4), "the pilgrim's bundle under the cairn", func(_a: bool) -> void: pass)
	var foot: Vector2 = steps[steps.size() - 1][0]
	State.register({"id": "cairn", "name": "Hobb's Cairn", "at": Vector3(top2.x, ty, top2.y), "r": 4.0, "node": node,
		"route": {"from": Vector3(-62.0, 0.0, -98.0), "pts": _v3([Vector2(foot.x, foot.y + 1.6), foot, Vector2(top2.x, top2.y + 1.2)])},
		"goal": Vector3(top2.x, ty, top2.y + 1.2)})


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _quad(s: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return q


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _v3(a: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector2 in a:
		out.append(Vector3(v.x, 0, v.y))
	return out

extends RefCounted
## The Hollow Fen (secrets):
##   barrow   THE UPTURNED BARROW (east of the Barrow Field): an earth long-barrow with a stone
##            passage, its door sealed "until the bells ring up again". It grinds open when the
##            Fallen Bells are rung (site_rim); inside, a face-up burial and a reliquary. Elite:
##            the Barrow-Warden (an ossuant) rises in the forecourt once the door is open.
##   crypt    CORVIN'S DROWNED CRYPT (the east pool): a mausoleum standing in black water, five
##            lamp posts round it carved eye, mouth, heart, hand, crown. Corvin's rite (on the post by
##            the door): light the eyes, the mouth, the heart, and no others. The grate rises and the
##            candles inside light. Elite: the Weighted (a husk) wades up once the grate is open.
##   postern  THE LAY BROTHERS' STAIR: a stair down the abbey ridge's fen face, barred on the fen
##            side by a postern gate. Lift the bar from below and the ridge walk (crest -> the south
##            nose -> Hearthward) becomes a shortcut between the Ossuary's threshold and the village.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const RockKit := preload("res://core/world/realm/rock_kit.gd")

const BARROW := Vector2(101.6, -45.0)       ## passage mouth is at BARROW.x - 3.8, facing -x
const CRYPT := Vector2(100.0, 12.0)
const LAMPS := [["eye", "an eye", 200.0], ["mouth", "a mouth", 128.0], ["heart", "a heart", 56.0], ["hand", "a hand", -16.0], ["crown", "a crown", -88.0]]
const RITE := ["eye", "mouth", "heart"]
const POSTERN_TOP := Vector2(35.3, -32.6)
const POSTERN_DIR := Vector2(8.0, -16.0)
const CREST := [Vector2(31.0, 1.4), Vector2(32.0, -3.0), Vector2(33.4, -8.0), Vector2(34.6, -12.4), Vector2(35.0, -16.0), Vector2(35.0, -24.0), Vector2(35.1, -29.0)]

static var lit := {}


static func build(root: Node, host: Node3D) -> void:
	var sp := Kit.space(root)
	var node := Node3D.new()
	node.name = "Fen"
	node.set_meta("site", "secrets_fen")
	host.add_child(node)
	_barrow(root, node, sp)
	_crypt(root, node, sp)
	_postern(root, node, sp)


# --- the upturned barrow ------------------------------------------------------------------------------

static func _barrow(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	Kit.clear_flora(root, [Vector3(BARROW.x + 0.5, BARROW.y, 7.5), Vector3(BARROW.x - 6.5, BARROW.y, 4.0)])
	var node := Node3D.new()
	node.name = "Barrow"
	parent.add_child(node)
	var g := Kit.low(sp, BARROW, 4.0) + 0.02
	var x0 := BARROW.x - 3.8           # passage mouth
	var x1 := BARROW.x + 1.2           # chamber starts
	var x2 := BARROW.x + 4.2           # chamber back
	var z := BARROW.y
	# +-4.6 m covers the kerb stones (4.2); +-5 swallowed the Barrow Field camp at (101, -50) (skipped)
	Kit.site(root, "secrets_barrow", Rect2(x0 - 3.0, z - 4.6, x2 - x0 + 4.0, 9.2), g)
	var k := OssKit.new()
	k.keep_lanes = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# passage: drystone walls and capstones
	k.block("floor", Vector3(x0 - 0.2, g - 0.4, z - 0.85), Vector3(x2, g + 0.06, z + 0.85), true, 0.85)
	for s: float in [-1.0, 1.0]:
		var xx := x0
		while xx < x1:
			var w := rng.randf_range(0.7, 1.1)
			k.box("stone", Vector3(xx + w * 0.5, g + 1.0, z + s * 1.0), Vector3(w, 2.0, 0.4), Basis.IDENTITY, true, rng.randf_range(0.75, 0.95))
			xx += w
	var xx2 := x0 - 0.2
	while xx2 < x1:
		var w2 := rng.randf_range(0.8, 1.2)
		k.box("stone", Vector3(xx2 + w2 * 0.5, g + 2.18, z), Vector3(w2 - 0.04, 0.36, 2.6), Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)), true, rng.randf_range(0.7, 0.9))
		xx2 += w2
	# chamber: four walls, a corbelled roof
	k.block("floor", Vector3(x1, g - 0.4, z - 1.6), Vector3(x2, g + 0.06, z + 1.6), true, 0.82)
	for s: float in [-1.0, 1.0]:
		k.box("stone", Vector3((x1 + x2) * 0.5, g + 1.2, z + s * 1.75), Vector3(x2 - x1 + 0.4, 2.4, 0.4), Basis.IDENTITY, true, 0.85)
		k.box("stone", Vector3(x1, g + 1.2, z + s * 1.35), Vector3(0.4, 2.4, 0.5), Basis.IDENTITY, true, 0.8)
	k.box("stone", Vector3(x2 + 0.2, g + 1.2, z), Vector3(0.4, 2.4, 3.9), Basis.IDENTITY, true, 0.8)
	for i in 3:
		var inset := 0.3 * float(i)
		k.box("stone", Vector3((x1 + x2) * 0.5, g + 2.5 + 0.28 * float(i), z), Vector3(x2 - x1 + 0.6 - inset * 2.0, 0.3, 3.9 - inset * 2.0), Basis.IDENTITY, true, 0.72 + 0.06 * float(i))
	# the bier and the face-up dead
	var bier := Vector3((x1 + x2) * 0.5 + 0.2, g, z)
	k.box("stone", bier + Vector3(0, 0.35, 0), Vector3(2.1, 0.7, 0.9), Basis.IDENTITY, true, 0.9)
	k.skull(bier + Vector3(-0.85, 0.78, 0), PI * 0.5, 1.0, 0, -PI * 0.5)
	for i in 6:
		k.bone(bier + Vector3(-0.5 + 0.18 * float(i), 0.74, (0.12 if i % 2 == 0 else -0.12)), Basis(Vector3.UP, PI * 0.5).rotated(Vector3.RIGHT, PI * 0.5), 1, false)
	k.bone(bier + Vector3(0.45, 0.74, 0.12), Basis(Vector3.FORWARD, PI * 0.5), 0, false)
	k.bone(bier + Vector3(0.45, 0.74, -0.12), Basis(Vector3.FORWARD, PI * 0.5), 0, false)
	k.candle_cluster(Vector3(x2 - 0.25, g + 0.06, z + 1.25), 4, 0.2, rng)
	k.candle_cluster(Vector3(x2 - 0.25, g + 0.06, z - 1.25), 3, 0.2, rng)
	# facade: a drystone revetment across the mound's face, the trilithon, the forecourt kerb
	for s: float in [-1.0, 1.0]:
		k.box("stone", Vector3(x0 - 0.1, g + 1.15, z + s * 1.0), Vector3(0.6, 2.3, 0.55), Basis.IDENTITY, true, 0.95)
		for j in 4:
			var zz := z + s * (1.6 + 0.85 * float(j))
			var hh := 1.9 - 0.32 * float(j)
			k.box("stone", Vector3(x0 + 0.1 + 0.3 * float(j), g + hh * 0.5, zz), Vector3(0.6, hh, 0.85), Basis(Vector3.UP, s * 0.25 * float(j)), true, rng.randf_range(0.72, 0.9))
	k.box("stone", Vector3(x0 - 0.1, g + 2.45, z), Vector3(0.7, 0.45, 3.0), Basis.IDENTITY, true, 0.9)
	k.commit(node, "BarrowBody")
	for c in node.get_children():
		if c is GeometryInstance3D and (c as GeometryInstance3D).visibility_range_end == 0.0:
			(c as GeometryInstance3D).visibility_range_end = 110.0
	# kerb: standing slabs in an arc round the forecourt
	for i in 7:
		var a := lerpf(-1.1, 1.1, float(i) / 6.0)
		var p := Vector2(x0 - 1.2 - 3.4 * cos(a) + 3.4, z + 4.2 * sin(a))
		if absf(p.y - z) < 1.6:
			continue
		var gy := Kit.gy(sp, p.x, p.y)
		var slab := RockKit.slab(i + 31, Vector3(0.9, rng.randf_range(1.1, 1.8), 0.32), "mossy", 0.2)
		var sh := rng.randf_range(1.1, 1.8)
		RockKit.spawn(node, slab, Transform3D(Basis(Vector3.UP, a + PI * 0.5), Vector3(p.x, gy - 0.1, p.y)), false, 90.0)
		Kit.box_body(node, Vector3(p.x, gy + sh * 0.5, p.y), Vector3(0.85, sh, 0.32), Basis(Vector3.UP, a + PI * 0.5))
	# the mound itself (earth, turfed), and its collision (outside the stone)
	var mound := Kit.cached_mesh("barrow_mound_3", func() -> ArrayMesh:
		var cm := CreatureMesh.new(5)
		cm.blob(Vector3.ZERO, Vector3(5.8, 3.7, 4.4), Basis.IDENTITY, Color(1, 1, 1), 0.0, 0.07, 0.0, 14, 24)
		return cm.commit())
	var mmi := Kit.mi(node, mound, Kit.mat("earth"), Transform3D(Basis.IDENTITY, Vector3(BARROW.x + 1.1, g - 0.65, z)), 140.0)
	mmi.name = "Mound"
	for s: float in [-1.0, 1.0]:
		Kit.box_body(node, Vector3((x0 + x2) * 0.5 + 0.9, g + 1.3, z + s * 3.25), Vector3(x2 - x0 + 2.0, 2.6, 2.6))
	Kit.box_body(node, Vector3(x2 + 1.6, g + 1.3, z), Vector3(2.4, 2.6, 4.0))
	# the door: a slab that sinks into the ground when the bells ring up
	var door := Kit.mi(node, _box(Vector3(0.28, 2.1, 1.7)), OssKit.mat("stone"), Transform3D(Basis.IDENTITY, Vector3(x0 - 0.35, g + 1.05, z)), 90.0)
	door.name = "BarrowDoor"
	var door_body := Kit.box_body(node, Vector3(x0 - 0.35, g + 1.05, z), Vector3(0.3, 2.2, 1.8))
	var sync := func(animate: bool) -> void:
		var open := State.has("solved", "bells")
		if open and State.mark("open", "barrow", false):
			pass
		Kit.set_body(door_body, not open)
		var to := Vector3(x0 - 0.35, g + 1.05 - (2.25 if open else 0.0), z)
		if animate and open and door.global_position.distance_to(to) > 0.1:
			Kit.play("grind", to, 2.0)
			var tw := door.create_tween()
			tw.tween_property(door, "global_position", to, 3.2).set_trans(Tween.TRANS_SINE)
			Kit.fx_dust(to + Vector3.UP * 1.0, Color(0.42, 0.4, 0.36, 0.8), 40)
		else:
			door.global_position = to
		door.visible = not open or animate
	State.reading(node, "sc_barrow_door", Vector3(x0 - 0.75, g + 1.6, z + 1.25))
	State.reading(node, "sc_barrow", bier + Vector3(0.0, 0.9, -0.6))
	var reliq := bier + Vector3(0.8, 0.7, 0)
	var rb := Kit.mi(node, _box(Vector3(0.4, 0.3, 0.3)), Kit.mat("bronze"), Transform3D(Basis(Vector3.UP, 0.3), reliq + Vector3.UP * 0.15), 40.0)
	rb.name = "Reliquary"
	State.cache(node, "barrow", reliq + Vector3.UP * 0.2, "the reliquary", func(_a: bool) -> void:
		rb.scale = Vector3(1, 0.4, 1), func() -> bool: return State.has("solved", "bells"))
	State.elite({"id": "barrow_warden", "kind": "ossuant", "title": "The Barrow-Warden", "at": Vector3(x0 - 6.0, g + 0.3, z),
		"when": func() -> bool: return State.has("solved", "bells")})
	State.register({"id": "barrow", "name": "The Upturned Barrow", "at": Vector3(x0, g, z), "r": 7.0, "node": node, "sync": sync,
		"route": {"from": Vector3(78.0, 0.0, -42.0), "pts": _v3([Vector2(84, -42), Vector2(92, -45), Vector2(x0 - 3.0, z), Vector2(x0 + 0.6, z), Vector2(x1 + 0.4, z)])},
		"goal": Vector3(x1 + 0.4, g, z), "door": door_body})


# --- Corvin's drowned crypt ---------------------------------------------------------------------------

static func _crypt(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	Kit.clear_flora(root, [Vector3(CRYPT.x, CRYPT.y, 9.0)])
	var node := Node3D.new()
	node.name = "Crypt"
	parent.add_child(node)
	var gb := Kit.low(sp, CRYPT, 4.0)
	var fy := -0.5                       # floor: a hand above the black water (WATER_Y -0.9)
	var c := Vector3(CRYPT.x, fy, CRYPT.y)
	Kit.site(root, "secrets_crypt", Rect2(CRYPT.x - 7.5, CRYPT.y - 7.5, 15.0, 15.0), fy)
	var k := OssKit.new()
	k.keep_lanes = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	# plinth and its steps up out of the water (west)
	k.block("stone", Vector3(c.x - 2.8, gb - 0.6, c.z - 3.2), Vector3(c.x + 2.8, fy, c.z + 3.2), true, 0.78)
	for i in 3:
		var sy := fy - 0.14 * float(i + 1)
		k.box("stone", Vector3(c.x - 3.05 - 0.38 * float(i), (sy + gb - 0.6) * 0.5, c.z), Vector3(0.4, sy - gb + 0.6, 2.2), Basis.IDENTITY, true, 0.8 + 0.05 * float(i))
	# walls (door in the west gable), buttresses, gable roof of slate
	var hx := 1.9
	var hz := 2.4
	var wh := 2.9
	for s: float in [-1.0, 1.0]:
		k.box("stone", Vector3(c.x, fy + wh * 0.5, c.z + s * hz), Vector3(hx * 2.0 + 0.4, wh, 0.4), Basis.IDENTITY, true, 0.86)
		k.box("stone", Vector3(c.x + s * 1.2, fy + 0.9, c.z + s * 0.0 + hz + 0.3), Vector3(0.5, 1.8, 0.4), Basis.IDENTITY, true, 0.8)
		k.box("stone", Vector3(c.x + s * 1.2, fy + 0.9, c.z - hz - 0.3), Vector3(0.5, 1.8, 0.4), Basis.IDENTITY, true, 0.8)
	k.box("stone", Vector3(c.x + hx, fy + wh * 0.5, c.z), Vector3(0.4, wh, hz * 2.0), Basis.IDENTITY, true, 0.84)
	k.arch_panel("stone", Vector3(c.x - hx, fy, c.z), Vector3(0, 0, 1), 1.3, 1.5, wh, 0.4, 0.95, 0.75)
	var rise := 1.5
	for s: float in [-1.0, 1.0]:
		var a := Vector3(c.x - hx - 0.3, fy + wh, c.z + s * (hz + 0.35))
		var b := Vector3(c.x + hx + 0.3, fy + wh, c.z + s * (hz + 0.35))
		var ridge_a := Vector3(c.x - hx - 0.3, fy + wh + rise, c.z)
		var ridge_b := Vector3(c.x + hx + 0.3, fy + wh + rise, c.z)
		var mid := (a + b + ridge_a + ridge_b) * 0.25
		var slope := atan2(rise, hz + 0.35)
		k.box("slate", mid + Vector3.UP * 0.08, Vector3(hx * 2.0 + 0.6, 0.14, sqrt(rise * rise + (hz + 0.35) * (hz + 0.35))), Basis(Vector3.RIGHT, s * slope), true, 0.9)
	for s: float in [-1.0, 1.0]:      # gable triangles
		var gx := c.x + s * hx
		k.quad("stone", Vector3(gx, fy + wh, c.z - hz), Vector3(gx, fy + wh, c.z + hz), Vector3(gx, fy + wh + rise - 0.05, c.z), Vector3(gx, fy + wh + rise - 0.05, c.z), Vector3(s, 0, 0))
	k.box("stone", Vector3(c.x - hx - 0.05, fy + wh + rise + 0.35, c.z), Vector3(0.2, 0.7, 0.14), Basis.IDENTITY, false, 0.9)     # finial: the open door
	# inside: a shelf, Corvin's niche
	k.box("stone", Vector3(c.x + hx - 0.45, fy + 0.5, c.z), Vector3(0.6, 1.0, 2.6), Basis.IDENTITY, true, 0.8)
	k.commit(node, "CryptBody")
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = 130.0
	# candles: their own node, lit once the rite is done
	var cn := Node3D.new()
	cn.name = "Candles"
	node.add_child(cn)
	var ck := OssKit.new()
	ck.keep_lanes = false
	ck.candle_cluster(Vector3(c.x + hx - 0.45, fy + 1.0, c.z + 0.8), 5, 0.25, rng)
	ck.candle_cluster(Vector3(c.x + hx - 0.45, fy + 1.0, c.z - 0.8), 4, 0.22, rng)
	ck.candle_cluster(Vector3(c.x - 0.6, fy, c.z + 1.8), 4, 0.25, rng)
	ck.candle_cluster(Vector3(c.x - 0.6, fy, c.z - 1.8), 3, 0.25, rng)
	ck.commit(cn, "CandleBody")
	var light := Kit.omni(node, Vector3(c.x + 0.6, fy + 1.6, c.z), Color(1.0, 0.62, 0.3), 1.3, 7.0)
	# the grate (iron bars) in the doorway
	var grate := Node3D.new()
	grate.name = "Grate"
	node.add_child(grate)
	var gk := OssKit.new()
	gk.keep_lanes = false
	for i in 7:
		var zz := c.z - 0.6 + 0.2 * float(i)
		gk.box("iron", Vector3(c.x - hx - 0.05, fy + 1.15, zz), Vector3(0.06, 2.3, 0.06), Basis.IDENTITY, false)
	for yy: float in [0.3, 1.2, 2.1]:
		gk.box("iron", Vector3(c.x - hx - 0.05, fy + yy, c.z), Vector3(0.08, 0.07, 1.36), Basis.IDENTITY, false)
	gk.commit(grate, "GrateUnused")
	var grate_body := Kit.box_body(node, Vector3(c.x - hx - 0.05, fy + 1.3, c.z), Vector3(0.3, 2.6, 1.5))
	# the five lamps standing in the water
	var lamps := {}
	for l: Array in LAMPS:
		var a := deg_to_rad(float(l[2]))
		var p := Vector2(c.x + cos(a) * 6.0, c.z + sin(a) * 6.0)
		var pg := Kit.gy(sp, p.x, p.y)
		var post := OssKit.new()
		post.keep_lanes = false
		var facing := Vector3(c.x - p.x, 0, c.z - p.y).normalized()
		var side := facing.cross(Vector3.UP).normalized()
		var bas := Basis(side, Vector3.UP, facing)
		var base := Vector3(p.x, pg, p.y)
		post.box("stone", base + Vector3.UP * 0.95, Vector3(0.42, 1.9, 0.42), bas, true, 0.85)
		post.box("stone", base + Vector3.UP * 1.98, Vector3(0.58, 0.16, 0.58), bas, true, 0.8)
		post.box("iron", base + Vector3.UP * 2.08, Vector3(0.36, 0.04, 0.36), bas, false)
		for q in 4:
			var o := Vector3(0.15 if q % 2 == 0 else -0.15, 0, 0.15 if q < 2 else -0.15)
			post.box("iron", base + Vector3.UP * 2.3 + bas * o, Vector3(0.03, 0.42, 0.03), bas, false)
		post.box("iron", base + Vector3.UP * 2.54, Vector3(0.38, 0.05, 0.38), bas, false)
		_emblem(post, String(l[0]), base + Vector3.UP * 1.45 + facing * 0.22, bas)
		var pn := Node3D.new()
		pn.name = "Lamp_" + String(l[0])
		node.add_child(pn)
		post.commit(pn, "LampBody")
		var glass := Kit.mi(pn, _box(Vector3(0.24, 0.32, 0.24)), Kit.mat("lamp_dark"), Transform3D(bas, base + Vector3.UP * 2.3), 90.0, false)
		var flame := QuadMesh.new()
		flame.size = Vector2(0.12, 0.26)
		var fl := Kit.mi(pn, flame, OssKit.mat("flame"), Transform3D(Basis.IDENTITY, base + Vector3.UP * 2.32), 90.0, false)
		fl.visible = false
		var id: String = l[0]
		lamps[id] = [glass, fl]
		var t := Kit.touch(pn, base + Vector3.UP * 1.2, "", func(_by: Node) -> void: _toggle(id, lamps, base), 2.3)
		t.set("prompt_fn", func() -> String:
			if State.has("solved", "rite"):
				return ""
			return ("Snuff the lamp carved with %s" if lit.has(id) else "Light the lamp carved with %s") % String(l[1]))
	State.reading(node, "sc_rite", Vector3(c.x - hx - 0.6, fy + 1.0, c.z - 1.2))
	State.reading(node, "sc_corvin", Vector3(c.x + hx - 0.6, fy + 1.4, c.z - 0.2))
	var lamp_c := Vector3(c.x + hx - 0.5, fy + 1.0, c.z)
	var lamp_mi := Kit.mi(node, _box(Vector3(0.22, 0.34, 0.22)), Kit.mat("lamp_glass"), Transform3D(Basis.IDENTITY, lamp_c + Vector3.UP * 0.17), 50.0, false)
	lamp_mi.name = "CorvinsLamp"
	State.cache(node, "crypt", lamp_c + Vector3.UP * 0.2, "Corvin's lamp", func(_a: bool) -> void: lamp_mi.visible = false,
		func() -> bool: return State.has("solved", "rite"))
	var sync := func(animate: bool) -> void:
		var done := State.has("solved", "rite")
		if done:
			for r: String in RITE:
				lit[r] = true
			State.mark("open", "crypt", false)
		for id2: String in lamps:
			var on := lit.has(id2)
			(lamps[id2][0] as MeshInstance3D).material_override = Kit.mat("lamp_glass" if on else "lamp_dark")
			(lamps[id2][1] as MeshInstance3D).visible = on
		cn.visible = done
		light.visible = done
		Kit.set_body(grate_body, not done)
		var gy := 2.4 if done else 0.0
		if animate and done and grate.position.y < 2.0:
			Kit.play("grind", c, 0.0, 1.4)
			grate.create_tween().tween_property(grate, "position:y", gy, 2.4).set_trans(Tween.TRANS_SINE)
		else:
			grate.position.y = gy
	State.elite({"id": "the_weighted", "kind": "husk", "title": "The Weighted", "at": Vector3(c.x - 8.0, gb + 0.2, c.z + 3.0),
		"when": func() -> bool: return State.has("solved", "rite")})
	State.register({"id": "crypt", "name": "Corvin's Drowned Crypt", "at": c, "r": 9.0, "node": node, "sync": sync, "lamps": lamps,
		"route": {"from": Vector3(86.0, 0.0, 22.0), "pts": _v3([Vector2(91, 17), Vector2(c.x - 5.0, c.z), Vector2(c.x - 3.4, c.z), Vector2(c.x - hx - 0.6, c.z)])},
		"goal": Vector3(c.x - hx - 0.6, fy, c.z), "inside": Vector3(c.x + 0.4, fy, c.z), "door": grate_body})


static func _toggle(id: String, lamps: Dictionary, at: Vector3) -> void:
	if State.has("solved", "rite"):
		return
	if lit.has(id):
		lit.erase(id)
		Kit.play("clank", at, -10.0, 1.6)
	elif not RITE.has(id):
		Kit.play("clank", at, -10.0, 1.6)
		State.toast("The rite names three lamps. This one goes out.")
		State.refresh(false)
		return
	else:
		lit[id] = true
		Kit.play("hum", at, -8.0, 1.3)
		Kit.fx_sparks(at + Vector3.UP * 2.3, Color(1.4, 0.7, 0.3))
	var want := {}
	for r: String in RITE:
		want[r] = true
	if lit.size() == want.size() and lit.keys().all(func(k: String) -> bool: return want.has(k)):
		State.mark("solved", "rite")
		State.toast("Eyes, mouth, heart. The water stills, and the grate lifts.")
		State.banner("the rite is kept", "Corvin's Drowned Crypt")
		State.refresh(true)
	else:
		State.refresh(false)


## A small carving on a lamp post (iron-dark inlay).
static func _emblem(k: OssKit, kind: String, at: Vector3, b: Basis) -> void:
	var x := b.x
	var y := b.y
	var d := Basis(x, y, b.z)
	match kind:
		"eye":
			k.box("dark", at + y * 0.04, Vector3(0.26, 0.03, 0.03), d.rotated(b.z, 0.25), false)
			k.box("dark", at - y * 0.04, Vector3(0.26, 0.03, 0.03), d.rotated(b.z, -0.25), false)
			k.box("dark", at, Vector3(0.07, 0.07, 0.03), d, false)
		"mouth":
			k.box("dark", at, Vector3(0.24, 0.04, 0.03), d, false)
			for i in 4:
				k.box("dark", at + x * (-0.09 + 0.06 * float(i)) + y * 0.04, Vector3(0.025, 0.05, 0.03), d, false)
		"heart":
			k.box("dark", at + x * 0.05, Vector3(0.05, 0.2, 0.03), d.rotated(b.z, 0.6), false)
			k.box("dark", at - x * 0.05, Vector3(0.05, 0.2, 0.03), d.rotated(b.z, -0.6), false)
		"hand":
			k.box("dark", at - y * 0.05, Vector3(0.14, 0.1, 0.03), d, false)
			for i in 4:
				k.box("dark", at + x * (-0.05 + 0.033 * float(i)) + y * 0.06, Vector3(0.02, 0.11, 0.03), d, false)
		"crown":
			k.box("dark", at - y * 0.05, Vector3(0.22, 0.04, 0.03), d, false)
			for i in 3:
				k.box("dark", at + x * (-0.08 + 0.08 * float(i)) + y * 0.02, Vector3(0.03, 0.1, 0.03), d, false)


# --- the lay brothers' stair and postern ---------------------------------------------------------------

static func _postern(root: Node, parent: Node3D, sp: PhysicsDirectSpaceState3D) -> void:
	var node := Node3D.new()
	node.name = "Postern"
	parent.add_child(node)
	var dir := Vector3(POSTERN_DIR.x, 0, POSTERN_DIR.y).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var discs: Array = []
	for i in 9:
		discs.append(Vector3(POSTERN_TOP.x + dir.x * 2.5 * float(i), POSTERN_TOP.y + dir.z * 2.5 * float(i), 2.4))
	for p: Vector2 in CREST:
		discs.append(Vector3(p.x, p.y, 2.2))
	for i in CREST.size() - 1:
		var m: Vector2 = (CREST[i] + CREST[i + 1]) * 0.5
		discs.append(Vector3(m.x, m.y, 2.2))
	Kit.clear_flora(root, discs)
	var k := OssKit.new()
	k.keep_lanes = false
	var top := Vector3(POSTERN_TOP.x, Kit.gy(sp, POSTERN_TOP.x, POSTERN_TOP.y) + 0.06, POSTERN_TOP.y)
	var y := top.y
	var p := Vector2(top.x, top.z)
	var tread := 0.46
	var steps: Array = []
	var d2 := Vector2(dir.x, dir.z)
	var s2 := Vector2(side.x, side.z)
	for i in 70:
		var hi := -INF
		var reach := 0.75 if y > 3.0 else 0.3      # the foot is cut into the bank's high side
		for o: float in [-reach, 0.0, reach]:
			for q: float in [0.0, tread * 0.5, tread]:
				var sp2 := p + s2 * o + d2 * q
				hi = maxf(hi, Kit.gy(sp, sp2.x, sp2.y))
		var ny := maxf(y - 0.41, hi + 0.06)
		steps.append([p + d2 * (tread * 0.5), ny])
		y = ny
		p += d2 * tread
		var gnext := Kit.gy(sp, p.x, p.y)
		if i > 8 and (y - gnext < 0.12 or RealmLayout.path_dist(p) < 3.0):
			break
	var sb := Basis(side, Vector3.UP, dir)
	var gate_i := -1
	for i in steps.size():
		var c2: Vector2 = steps[i][0]
		var sy: float = steps[i][1]
		var gl := minf(Kit.gy(sp, c2.x + side.x * 0.8, c2.y + side.z * 0.8), Kit.gy(sp, c2.x - side.x * 0.8, c2.y - side.z * 0.8))
		k.box("stone", Vector3(c2.x, (sy + gl - 0.5) * 0.5, c2.y), Vector3(1.5, sy - gl + 0.5, tread + 0.03), sb, true, 0.84 if i % 2 == 0 else 0.94)
		if gate_i < 0 and sy < 4.2:
			gate_i = i
	if gate_i < 0:
		gate_i = steps.size() - 1
	# the postern: two piers and a lintel across the stair, wing walls into the bank both sides
	var gc2: Vector2 = steps[gate_i][0]
	var gy: float = steps[gate_i][1]
	var gc := Vector3(gc2.x, gy, gc2.y)
	Kit.site(root, "secrets_postern", Rect2(gc.x - 2.6, gc.z - 2.6, 5.2, 5.2), gy)
	for s: float in [-1.0, 1.0]:
		k.box("stone", gc + side * (s * 1.05) + Vector3.UP * 1.4, Vector3(0.6, 3.4, 0.7), sb, true, 0.9)
		var wing_out := gc + side * (s * 2.6)
		var wg := Kit.gy(sp, wing_out.x, wing_out.z)
		var wtop := maxf(gy + 2.6, wg + 2.0)
		var wbot := minf(wg, gy) - 0.6
		var wc := gc + side * (s * 2.35)
		k.box("stone", Vector3(wc.x, (wtop + wbot) * 0.5, wc.z), Vector3(2.4, wtop - wbot, 0.6), sb, true, 0.82)
	k.box("stone", gc + Vector3.UP * 3.15, Vector3(2.8, 0.5, 0.8), sb, true, 0.85)
	# the crest walk itself: a flagged causeway with kerbs from the nose to the stair head
	var line: Array = []
	for i in range(3, CREST.size()):
		line.append(CREST[i])
	line.append(POSTERN_TOP + Vector2(-0.1, 0.6))
	var slabs := Kit.causeway(sp, k, node, line, 1.9, 3)
	# the ridge's south nose: a cut stair from the causeway's first flag down to the rift rim
	var nose_top: Vector2 = CREST[3]
	Kit.stair_down(sp, k, Vector3(nose_top.x, Kit.causeway_start(slabs), nose_top.y), Vector2(31.2, 0.8) - nose_top, 0.5, 1.6)
	# cairns along the crest walk, and a marker at its foot by the rift rim
	for i in range(1, CREST.size() - 1, 2):
		var cp: Vector2 = CREST[i] + Vector2(2.4, 0.0)
		var cg := Kit.gy(sp, cp.x, cp.y)
		for j in 4:
			k.box("stone", Vector3(cp.x, cg + 0.18 + 0.28 * float(j), cp.y), Vector3(0.6 - 0.1 * float(j), 0.3, 0.5 - 0.08 * float(j)), Basis(Vector3.UP, float(j) * 0.7 + float(i)), j == 0, 0.8)
	k.commit(node, "PosternBody")
	for ch in node.get_children():
		if ch is GeometryInstance3D and (ch as GeometryInstance3D).visibility_range_end == 0.0:
			(ch as GeometryInstance3D).visibility_range_end = 120.0
	var gate := Node3D.new()
	gate.name = "Gate"
	node.add_child(gate)
	gate.global_transform = Transform3D(sb, gc + side * -0.75)       # hinged at the left pier
	var gk := OssKit.new()
	gk.keep_lanes = false
	for i in 7:
		gk.box("iron", Vector3(0.12 + 0.22 * float(i), 1.25, 0), Vector3(0.06, 2.5, 0.06), Basis.IDENTITY, false)
	for yy: float in [0.2, 1.3, 2.4]:
		gk.box("iron", Vector3(0.75, yy, 0), Vector3(1.5, 0.08, 0.07), Basis.IDENTITY, false)
	gk.box("wood", Vector3(0.75, 1.3, 0.22), Vector3(1.9, 0.16, 0.14), Basis.IDENTITY, false)      # the bar (fen side)
	var tmp := Node3D.new()
	gate.add_child(tmp)
	gk.commit(tmp, "GateUnused")
	var gate_body := Kit.box_body(node, gc + Vector3.UP * 1.3, Vector3(1.6, 2.6, 0.3), sb)
	var sync := func(animate: bool) -> void:
		var open := State.has("open", "postern")
		Kit.set_body(gate_body, not open)
		var rot := Basis(sb.y, -1.75) * sb if open else sb
		if animate and open:
			Kit.play("creak", gc, 0.0, 0.8)
			gate.create_tween().tween_property(gate, "basis", rot, 1.6).set_trans(Tween.TRANS_SINE)
		else:
			gate.basis = rot
	var bar := Kit.touch(node, gc + dir * 0.9 + Vector3.UP * 1.2, "", func(by: Node) -> void:
		if State.has("open", "postern"):
			return
		var from := (by as Node3D).global_position if by is Node3D else gc + dir
		if (from - gc).dot(dir) < 0.0:
			State.toast("Barred from the other side.")
			Kit.play("clank", gc, -6.0, 0.7)
			return
		State.mark("open", "postern")
		State.toast("The bar lifts. The gate swings in on the ridge stair.")
		State.banner("a way opens", "The Lay Brothers' Stair")
		State.refresh(true), 2.4)
	bar.name = "PosternBar"
	bar.set("prompt_fn", func() -> String:
		if State.has("open", "postern"):
			return ""
		var pl := bar.get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D if bar.is_inside_tree() else null
		if pl and (pl.global_position - gc).dot(dir) < 0.0:
			return "Try the postern gate"
		return "Lift the postern bar")
	# the upper side also gets a prompt (the touch reaches through the bars)
	var upper := Kit.touch(node, gc - dir * 0.9 + Vector3.UP * 1.2, "", func(_by: Node) -> void:
		if not State.has("open", "postern"):
			State.toast("Barred from the other side.")
			Kit.play("clank", gc, -6.0, 0.7), 2.0)
	upper.name = "PosternUpper"
	upper.set("prompt_fn", func() -> String: return "" if State.has("open", "postern") else "Try the postern gate")
	State.reading(node, "sc_postern", gc + dir * 1.1 + side * 1.3 + Vector3.UP * 1.4)
	var foot2: Vector2 = steps[steps.size() - 1][0]
	var crest_pts: Array[Vector3] = []
	for cp2: Vector2 in CREST:
		crest_pts.append(Vector3(cp2.x, 0, cp2.y))
	var stair_pts: Array[Vector3] = [Vector3(top.x, 0, top.z)]
	for i in range(4, steps.size(), 5):
		var sc: Vector2 = steps[i][0]
		stair_pts.append(Vector3(sc.x, 0, sc.y))
	stair_pts.append(Vector3(foot2.x + dir.x, 0, foot2.y + dir.z))
	State.register({"id": "postern", "name": "The Lay Brothers' Stair", "at": gc, "r": 5.0, "node": node, "sync": sync,
		"route": {"from": Vector3(foot2.x + dir.x * 4.0, 0.0, foot2.y + dir.z * 4.0), "pts": [Vector3(foot2.x + dir.x * 1.2, 0, foot2.y + dir.z * 1.2), Vector3(gc.x + dir.x * 1.0, 0, gc.z + dir.z * 1.0)]},
		"goal": Vector3(gc.x + dir.x * 1.0, gy, gc.z + dir.z * 1.0), "crest": crest_pts, "stair": stair_pts, "door": gate_body, "gate": gc, "dir": dir})


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _v3(a: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v: Vector2 in a:
		out.append(Vector3(v.x, 0, v.y))
	return out

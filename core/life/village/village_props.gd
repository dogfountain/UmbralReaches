extends RefCounted
## Hearthward's working props and the restorations (village system; no class_name). Built with
## OssKit and the lore materials (LoreKit.ensure_mats) so they sit in the village's own stone, beam
## and slate; small organic meshes (stumps, logs, wheels, mounds) go through GenCache.
##   lamps        posts with an iron bracket and a lantern; glass + halo per lamp take an instance
##                uniform `lit`, which the lamplighter's round raises (no light per lamp)
##   cart         the ash-wife's handcart: ash bins, oil jars, a rope coil, a lamp on a pole (1 light)
##   hermit       Wyck's camp in the Thornwood: fire pit (flames, 1 light), lean-to, log seat, bird graves
##   sexton       Abel's open grave beside the Kindlers' Yard: pit, spoil heap, a lantern on a stake (1 light)
##   block        Col's chopping block and split logs
##   forge        a flare light on Edda's forge that the hammer pulses (1 light)
##   restorations the Wrights' and Reeds' windows and smoke, the Reeds' new slates and a ladder, the
##                well's boards (until it is reopened) and its new rope and bucket, the Harrows' new
##                rafters, then their thatch
## Restoration overlays have no collision (they can appear while someone walks past).

const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const LA := preload("res://core/world/realm/lore/lore_assets.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const DwarfMeshG := preload("res://core/npc/dwarf_mesh.gd")
const DwarfLookG := preload("res://core/npc/dwarf_look.gd")
const SELF := "res://core/life/village/village_props.gd"
const GLASS := preload("res://core/life/village/lamp_glass.gdshader")
const HALO := preload("res://core/life/village/lamp_halo.gdshader")
const LANTERN_H := 2.35            ## lantern centre over the ground
const H := 2.6                     ## cottage eaves (cottage.gd)

## The cottages as hearthward.gd builds them: site, centre, w, d, yaw, roof.
const COTTAGES := {
	"south": {"site": "hw_south", "c": Vector2(-15.0, 64.0), "w": 6.0, "d": 4.8, "face": Vector2(-10.0, 55.0), "add": 0.0, "roof": "thatch"},
	"reed": {"site": "hw_reed", "c": Vector2(22.0, 42.0), "w": 6.4, "d": 5.0, "yaw": 0.0, "roof": "slate"},
	"harrow": {"site": "hw_harrow", "c": Vector2(-19.0, 13.0), "w": 6.2, "d": 4.8, "face": Vector2(0.0, 33.0), "add": 0.2, "roof": "slate"},
}

static var _glass_mat: ShaderMaterial
static var _halo_mat: ShaderMaterial
static var _pool := {}


## Drop the engine resources held in static vars (called when the night is torn down): statics
## outlive the renderer at quit ("RID allocations leaked at exit"). Rebuilt on next use.
static func release() -> void:
	_glass_mat = null
	_halo_mat = null
	_pool.clear()


static func _mesh(key: String, fn: Callable) -> ArrayMesh:
	if _pool.has(key):
		return _pool[key]
	var full := "village_prop|" + key
	var m := GenCache.load_mesh(full, SELF)
	if m == null:
		m = fn.call()
		GenCache.save_mesh(full, SELF, m)
	_pool[key] = m
	return m


static func ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


static func light(parent: Node3D, n: String, at: Vector3, col: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.light_color = col
	l.light_energy = e                     # authored energies stand; *2 washed cottages orange
	l.omni_range = r * 1.05
	l.shadow_enabled = false
	l.set_meta(&"light_class", &"realm")
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	parent.add_child(l)
	l.global_position = at
	return l


static func _commit(k: OssKit, parent: Node3D, body := "Body", far := 95.0) -> void:
	k.commit(parent, body)
	for c in parent.get_children():
		if c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			g.visibility_range_end = far
			g.visibility_range_end_margin = 14.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			g.extra_cull_margin = maxf(g.extra_cull_margin, 3.0)


static func holder(parent: Node, n: String) -> Node3D:
	var h := Node3D.new()
	h.name = n
	parent.add_child(h)
	return h


# --- lamps ------------------------------------------------------------------------------------------

## Lamp posts; each lantern hangs on a bracket toward its lighting spot. Returns {id: {pos, glass, halo}}.
static func lamps(parent: Node, space: PhysicsDirectSpaceState3D, defs: Array, spots: Dictionary) -> Dictionary:
	LK.ensure_mats()
	if _glass_mat == null:
		_glass_mat = ShaderMaterial.new()
		_glass_mat.shader = GLASS
		_halo_mat = ShaderMaterial.new()
		_halo_mat.shader = HALO
	var h := holder(parent, "Lamps")
	var k := OssKit.new()
	k.keep_lanes = false
	var out := {}
	var glass_mesh := CylinderMesh.new()
	glass_mesh.top_radius = 0.075
	glass_mesh.bottom_radius = 0.085
	glass_mesh.height = 0.22
	glass_mesh.radial_segments = 6
	glass_mesh.rings = 1
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(0.9, 0.9)
	var i := 0
	for d: Dictionary in defs:
		var p: Vector2 = d.post
		var gy := ground(space, p.x, p.y)
		var spot: Vector2 = spots.get(String(d.spot), p + Vector2(1, 0))
		var to := (spot - p).normalized() if spot.distance_to(p) > 0.1 else Vector2(1, 0)
		var b := Basis(Vector3.UP, atan2(-to.x, -to.y))
		var base := Vector3(p.x, gy, p.y)
		var b45 := Basis(Vector3.UP, PI * 0.25) * b
		k.box("lore_tstone", base + Vector3.UP * 0.06, Vector3(0.5, 0.12, 0.5), b, true, 0.8)           # a stepped plinth
		k.box("lore_tstone", base + Vector3.UP * 0.2, Vector3(0.36, 0.2, 0.36), b, true, 0.9)
		k.box("lore_tstone", base + Vector3.UP * 0.32, Vector3(0.42, 0.05, 0.42), b, false, 1.0)
		k.box("lamp_wood", base + Vector3.UP * 1.4, Vector3(0.13, 2.4, 0.13), b, true, 0.7)             # an octagonal post
		k.box("lamp_wood", base + Vector3.UP * 1.4, Vector3(0.13, 2.4, 0.13), b45, false, 0.62)
		for by: float in [0.75, 1.6, 2.4]:
			k.box("lamp_iron", base + Vector3.UP * by, Vector3(0.18, 0.045, 0.18), b, false, 0.65)           # iron bands
			k.box("lamp_iron", base + Vector3.UP * by, Vector3(0.18, 0.045, 0.18), b45, false, 0.6)
		k.box("lamp_wood", base + Vector3.UP * 2.64, Vector3(0.2, 0.07, 0.2), b, false, 0.7)             # a cap, a finial
		k.box("lamp_iron", base + Vector3.UP * 2.74, Vector3(0.07, 0.07, 0.07), b45, false, 0.75)
		var arm := Vector3(to.x, 0, to.y) * 0.5
		var af := Basis.looking_at(Vector3(to.x, 0, to.y), Vector3.UP)
		k.box("lamp_iron", base + Vector3.UP * 2.55 + arm * 0.5, Vector3(0.04, 0.04, 0.55), af, false, 0.7)
		var br0 := base + Vector3.UP * 2.1                                                              # a diagonal brace under the arm
		var br1 := base + Vector3.UP * 2.53 + arm * 0.8
		k.box("lamp_iron", (br0 + br1) * 0.5, Vector3(0.028, 0.028, br0.distance_to(br1)), Basis.looking_at((br1 - br0).normalized(), Vector3.UP), false, 0.65)
		var lc := base + Vector3.UP * LANTERN_H + arm
		# r36: the lantern hangs from the arm's hook (0.25 above its centre) and swings in the wind
		var hook := lc + Vector3.UP * 0.25
		k.box("lamp_iron", hook + Vector3.DOWN * 0.005, Vector3(0.015, 0.06, 0.015), b, false, 0.6)
		var sw := Sway.hang(h, hook, atan2(-to.x, -to.y), 0.035, 2.1 + 0.25 * float(i % 3), 1.0)
		var kc := OssKit.new()
		kc.keep_lanes = false
		var lo := Vector3.DOWN * 0.25                        # the lantern's centre in the hook's space
		kc.box("lamp_iron", lo + Vector3.UP * 0.15, Vector3(0.2, 0.05, 0.2), Basis.IDENTITY, false, 0.6)
		kc.box("lamp_iron", lo + Vector3.UP * 0.2, Vector3(0.1, 0.06, 0.1), Basis.IDENTITY, false, 0.6)
		kc.box("lamp_iron", lo + Vector3.UP * 0.245, Vector3(0.14, 0.03, 0.14), Basis(Vector3.UP, 0.78), false, 0.65)      # a stepped hat and finial
		kc.box("lamp_iron", lo + Vector3.UP * 0.28, Vector3(0.07, 0.03, 0.07), Basis.IDENTITY, false, 0.65)
		kc.box("lamp_iron", lo + Vector3.DOWN * 0.165, Vector3(0.1, 0.03, 0.1), Basis(Vector3.UP, 0.78), false, 0.6)
		kc.box("lamp_iron", lo + Vector3.DOWN * 0.13, Vector3(0.19, 0.04, 0.19), Basis.IDENTITY, false, 0.6)
		for c in 4:
			var o := Vector3(0.085 * (1.0 if c % 2 == 0 else -1.0), 0, 0.085 * (1.0 if c < 2 else -1.0))
			kc.box("lamp_iron", lo + o, Vector3(0.02, 0.27, 0.02), Basis.IDENTITY, false, 0.6)
		sw.take(kc, 90.0)
		var g := MeshInstance3D.new()
		g.name = "Glass_" + String(d.id)
		g.mesh = glass_mesh
		g.material_override = _glass_mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 90.0
		sw.add_child(g)
		g.position = lo
		g.set_instance_shader_parameter("seed", float(i) * 0.37)
		var hl := MeshInstance3D.new()
		hl.name = "Halo_" + String(d.id)
		hl.mesh = halo_mesh
		hl.material_override = _halo_mat
		hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hl.visibility_range_end = 90.0
		sw.add_child(hl)
		hl.position = lo
		hl.set_instance_shader_parameter("seed", float(i) * 0.37)
		out[String(d.id)] = {"pos": lc, "glass": g, "halo": hl, "lit": 0.0, "want": 0.0, "fuel": 0.0}
		i += 1
	_commit(k, h, "LampBody", 90.0)
	return out


static func set_lit(lamp: Dictionary, v: float) -> void:
	(lamp.glass as GeometryInstance3D).set_instance_shader_parameter("lit", v)
	(lamp.halo as GeometryInstance3D).set_instance_shader_parameter("lit", v)
	(lamp.halo as Node3D).visible = v > 0.01


static func _coil() -> ArrayMesh:
	return _mesh("rope_coil", func() -> ArrayMesh:
		var cm := CreatureMesh.new(24)
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for q in 40:
			var a := float(q) * 0.5
			pts.append(Vector3(cos(a) * 0.14, float(q) * 0.0025, sin(a) * 0.14))
			rr.append(0.018)
		cm.tube(pts, rr, 6, Color(0.66, 0.56, 0.4), 0.0, 0.05)
		return cm.commit())


# --- the ash-wife's cart --------------------------------------------------------------------------

static func cart(parent: Node, space: PhysicsDirectSpaceState3D, at: Vector2, yaw: float) -> Dictionary:
	LK.ensure_mats()
	var h := holder(parent, "AshCart")
	var k := OssKit.new()
	k.keep_lanes = false
	var gy := ground(space, at.x, at.y)
	var b := Basis(Vector3.UP, yaw)
	var o := Vector3(at.x, gy, at.y)
	var bed := o + Vector3.UP * 0.72
	k.box("lore_beam", bed, Vector3(1.5, 0.08, 0.9), b, true, 0.8)
	for s: float in [-1.0, 1.0]:
		k.box("lore_beam", bed + b * Vector3(0, 0.16, s * 0.43), Vector3(1.5, 0.3, 0.05), b, false, 0.7)
		k.box("lore_beam", bed + b * Vector3(s * 0.73, 0.16, 0), Vector3(0.05, 0.3, 0.9), b, false, 0.7)
		k.box("lore_beam", bed + b * Vector3(0.95, -0.02, s * 0.36), Vector3(0.9, 0.06, 0.06), b, false, 0.65)   # shafts
		k.box("lore_beam", bed + b * Vector3(-0.68, -0.38, s * 0.38), Vector3(0.07, 0.72, 0.07), b, false, 0.65)  # legs
	var wheel := _mesh("cart_wheel", func() -> ArrayMesh:
		var cm := CreatureMesh.new(21)
		cm.tube(PackedVector3Array([Vector3(0, 0, -0.04), Vector3(0, 0, 0.04)]), PackedFloat32Array([0.42, 0.42]), 18, Color(0.62, 0.5, 0.4), 0.0, 0.03)
		cm.tube(PackedVector3Array([Vector3(0, 0, -0.08), Vector3(0, 0, 0.08)]), PackedFloat32Array([0.08, 0.08]), 10, Color(0.5, 0.4, 0.32), 0.0, 0.02)
		return cm.commit())
	for s2: float in [-1.0, 1.0]:
		LK.organic(k, "lore_beam", wheel, Transform3D(b, o + b * Vector3(0.25, 0.42, s2 * 0.53)))
	k.box("iron", o + b * Vector3(0.25, 0.42, 0), Vector3(0.05, 0.05, 1.12), b, false, 0.5)
	# ash in three bins (grey heaps), jars of oil, a rope coil, a sack
	var heap := _mesh("ash_heap", func() -> ArrayMesh:
		var cm := CreatureMesh.new(22)
		cm.blob(Vector3.ZERO, Vector3(0.2, 0.1, 0.18), Basis.IDENTITY, Color(0.62, 0.6, 0.62), 0.0, 0.25, 0.0, 6, 10)
		return cm.commit())
	for j in 3:
		var bc := bed + b * Vector3(-0.45 + 0.42 * float(j), 0.1, -0.12)
		k.box("lore_beam", bc + Vector3.UP * 0.06, Vector3(0.36, 0.16, 0.36), b, false, 0.55)
		LK.organic(k, "lore_rock", heap, Transform3D(b, bc + Vector3.UP * 0.15))
	var jar := _mesh("oil_jar", func() -> ArrayMesh:
		var cm := CreatureMesh.new(23)
		cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 0.22, 0), Vector3(0, 0.27, 0)]), PackedFloat32Array([0.07, 0.09, 0.05, 0.035]), 10, Color(0.56, 0.38, 0.28), 0.0, 0.05)
		return cm.commit())
	for j2 in 3:
		LK.organic(k, "lore_rock", jar, Transform3D(b, bed + b * Vector3(-0.4 + 0.2 * float(j2), 0.04, 0.24)))
	var coil := _coil()
	LK.organic(k, "lore_beam", coil, Transform3D(b, bed + b * Vector3(0.45, 0.04, 0.2)))
	# the lamp on a pole at the back corner
	var pole := bed + b * Vector3(-0.72, 0.0, 0.42)
	k.box("lore_beam", pole + Vector3.UP * 0.75, Vector3(0.05, 1.5, 0.05), b, false, 0.6)
	k.box("iron", pole + Vector3.UP * 1.5 + b * Vector3(0.12, 0, 0), Vector3(0.25, 0.03, 0.03), b, false, 0.6)
	var lamp := pole + Vector3.UP * 1.36 + b * Vector3(0.24, 0, 0)
	k.box("iron", lamp + Vector3.UP * 0.1, Vector3(0.14, 0.04, 0.14), b, false, 0.6)
	k.box("glow", lamp, Vector3(0.1, 0.15, 0.1), b, false, 0.8)
	_commit(k, h, "CartBody")
	var l := light(h, "CartLamp", lamp + Vector3.UP * 0.05, Color(1.0, 0.6, 0.3), 0.6, 4.0)
	return {"anchor": bed + Vector3.UP * 0.12, "light": l}


# --- Wyck's camp --------------------------------------------------------------------------------

static func hermit(parent: Node, space: PhysicsDirectSpaceState3D, c: Vector2) -> Dictionary:
	LK.ensure_mats()
	var h := holder(parent, "HermitCamp")
	var k := OssKit.new()
	k.keep_lanes = false
	var f := Vector3(c.x, ground(space, c.x, c.y), c.y)
	# fire pit: a ring of stones, crossed logs, embers
	var stone := _mesh("pit_stone", func() -> ArrayMesh:
		var cm := CreatureMesh.new(31)
		cm.blob(Vector3.ZERO, Vector3(0.13, 0.09, 0.11), Basis.IDENTITY, Color(0.8, 0.78, 0.74), 0.0, 0.2, 0.0, 6, 9)
		return cm.commit())
	for i in 9:
		var a := TAU * float(i) / 9.0
		LK.organic(k, "lore_rock", stone, Transform3D(Basis(Vector3.UP, a * 1.7), f + Vector3(cos(a) * 0.48, 0.03, sin(a) * 0.48)))
	var log_m := _mesh("camp_log", func() -> ArrayMesh:
		var cm := CreatureMesh.new(32)
		cm.tube(PackedVector3Array([Vector3(-0.35, 0, 0), Vector3(0.35, 0, 0)]), PackedFloat32Array([0.06, 0.055]), 8, Color(0.7, 0.6, 0.5), 0.0, 0.15)
		return cm.commit())
	for j in 3:
		var a2 := float(j) * 1.05
		LK.organic(k, "lore_beam", log_m, Transform3D(Basis(Vector3.UP, a2) * Basis(Vector3.BACK, 0.25), f + Vector3.UP * 0.1))
	k.box("lore_ember", f + Vector3.UP * 0.04, Vector3(0.4, 0.04, 0.4), Basis(Vector3.UP, 0.3), false, 0.7)
	k.box("lore_char", f + Vector3.UP * 0.02, Vector3(0.7, 0.03, 0.7), Basis(Vector3.UP, 0.8), false, 0.5)
	# log seat east of the fire
	var seat := f + Vector3(1.5, 0, 0.3)
	seat.y = ground(space, seat.x, seat.z)
	var seat_m := _mesh("seat_log", func() -> ArrayMesh:
		var cm := CreatureMesh.new(33)
		cm.tube(PackedVector3Array([Vector3(0, 0, -0.7), Vector3(0, 0.02, 0), Vector3(0, 0, 0.7)]), PackedFloat32Array([0.19, 0.2, 0.18]), 10, Color(0.68, 0.6, 0.52), 0.0, 0.15)
		return cm.commit())
	LK.organic(k, "lore_beam", seat_m, Transform3D(Basis(Vector3.UP, 0.15), seat + Vector3.UP * 0.17))
	# lean-to: two forked posts, a ridge pole, branches and a hide
	var lt := f + Vector3(-1.6, 0, -1.5)
	lt.y = ground(space, lt.x, lt.z)
	var lb := Basis(Vector3.UP, 0.6)
	for s: float in [-1.0, 1.0]:
		k.box("lore_beam", lt + lb * Vector3(s * 0.9, 0.7, 0.4), Vector3(0.08, 1.4, 0.08), lb, false, 0.6)
	k.box("lore_beam", lt + lb * Vector3(0, 1.38, 0.4), Vector3(2.0, 0.08, 0.08), lb, false, 0.6)
	for i2 in 7:
		var x := -0.9 + 0.3 * float(i2)
		k.box("lore_beam", lt + lb * Vector3(x, 0.72, -0.25), Vector3(0.05, 0.05, 1.6), lb * Basis(Vector3.RIGHT, 1.0), false, 0.55)
	# the hide over it: a two-sided sagging skin with ragged edges in the NPC hide material (it was a
	# one-sided quad of dark cloth that rendered black from the camp side)
	var hide_m := _mesh("lean_hide", func() -> ArrayMesh:
		var mb: Variant = DwarfMeshG.new(35)
		var grid: Array[Vector3] = []
		var cols := 12
		var rows := 9
		var top := Vector3(0, 1.38, 0.38)
		var bot := Vector3(0, 0.06, -0.86)
		var dn := Vector3(0, -0.68, 0.73)
		for r in rows + 1:
			var v := float(r) / float(rows)
			for ci in cols + 1:
				var u := float(ci) / float(cols) * 2.0 - 1.0
				var p := top.lerp(bot, v) + Vector3(u * (1.04 + 0.05 * sin(v * 9.0 + u * 3.0)), 0, 0)
				p += dn * (0.09 * sin(PI * v) * (1.0 - 0.45 * u * u) + 0.012 * sin(u * 17.0 + v * 5.0))
				if r == rows:
					p += Vector3(0, 0.03 * sin(u * 11.0), 0)
				grid.append(p)
		mb.sheet(grid, cols, rows, Color(0.64, 0.5, 0.36), DwarfMeshG.MAT_LEATHER, 0.01, Vector3(0, 0.7, -0.7))
		return mb.commit_static())
	var hide := MeshInstance3D.new()
	hide.name = "Hide"
	hide.mesh = hide_m
	hide.material_override = DwarfLookG.material()
	hide.visibility_range_end = 70.0
	h.add_child(hide)
	hide.global_transform = Transform3D(lb, lt)
	# bird graves: small mounds, a feather stuck in each
	var g := f + Vector3(-2.2, 0, 1.6)
	g.y = ground(space, g.x, g.z)
	var mound := _mesh("bird_mound", func() -> ArrayMesh:
		var cm := CreatureMesh.new(34)
		cm.blob(Vector3.ZERO, Vector3(0.16, 0.06, 0.11), Basis.IDENTITY, Color(0.5, 0.42, 0.34), 0.0, 0.3, 0.0, 5, 9)
		return cm.commit())
	for m in 3:
		var mp := g + Vector3(0.38 * float(m) - 0.38, 0.0, 0.15 * float(m % 2))
		mp.y = ground(space, mp.x, mp.z)
		LK.organic(k, "lore_soil", mound, Transform3D(Basis(Vector3.UP, float(m)), mp))
		k.box("lore_paper", mp + Vector3(0.0, 0.14, 0.0), Vector3(0.012, 0.18, 0.04), Basis(Vector3.BACK, 0.2 * float(m - 1)), false, 0.7)
	_commit(k, h, "CampBody")
	var flame := Vfx.emitter(Color(1.0, 0.55, 0.2), {"count": 18, "life": 0.7, "speed": Vector2(0.3, 0.9), "size": 0.16, "gravity": 1.4, "radius": 0.14, "spread": 12.0, "dir": Vector3.UP, "scale_var": 0.5})
	if flame:
		flame.name = "Flames"
		h.add_child(flame)
		flame.global_position = f + Vector3.UP * 0.12
		flame.emitting = true
	var smoke := Vfx.emitter(Color(0.3, 0.3, 0.33, 0.3), {"count": 8, "life": 4.0, "speed": Vector2(0.2, 0.45), "size": 0.45, "gravity": -0.1, "radius": 0.1, "additive": false, "spread": 14.0})
	if smoke:
		smoke.name = "Smoke"
		h.add_child(smoke)
		smoke.global_position = f + Vector3.UP * 0.7
		smoke.emitting = true
	var l := light(h, "CampFire", f + Vector3.UP * 0.55, Color(1.0, 0.52, 0.2), 0.72, 5.0)
	return {"fire": f, "seat": seat, "grave": g, "light": l}


# --- r34: the outposts (a giver's fire in each new region) ------------------------------------------

## A small camp at `c`: the hermit's fire pit and log seat (same cached meshes), a lantern on a
## stake, and the region's dressing (`style`): turf stacked at the Holds, a squared block to dress
## at the quarry (returns "block"), a windbreak of moor stones, a cracked mould at the Founder's
## Pits, a grafting trestle in the orchard, candles on a stone at the Waiting Field, an upturned
## punt at the mere. One merged body, one omni (the fire), faded at 70 m like the hermit's.
static func outpost(parent: Node, space: PhysicsDirectSpaceState3D, c: Vector2, style: String) -> Dictionary:
	LK.ensure_mats()
	var h := holder(parent, "Outpost_" + style)
	var k := OssKit.new()
	k.keep_lanes = false
	var f := Vector3(c.x, ground(space, c.x, c.y), c.y)
	var stone := _mesh("pit_stone", func() -> ArrayMesh:
		var cm := CreatureMesh.new(31)
		cm.blob(Vector3.ZERO, Vector3(0.13, 0.09, 0.11), Basis.IDENTITY, Color(0.8, 0.78, 0.74), 0.0, 0.2, 0.0, 6, 9)
		return cm.commit())
	for i in 8:
		var a := TAU * float(i) / 8.0
		var sp := f + Vector3(cos(a) * 0.46, 0.0, sin(a) * 0.46)
		sp.y = ground(space, sp.x, sp.z) + 0.03
		LK.organic(k, "lore_rock", stone, Transform3D(Basis(Vector3.UP, a * 1.7), sp))
	var log_m := _mesh("camp_log", func() -> ArrayMesh:
		var cm := CreatureMesh.new(32)
		cm.tube(PackedVector3Array([Vector3(-0.35, 0, 0), Vector3(0.35, 0, 0)]), PackedFloat32Array([0.06, 0.055]), 8, Color(0.7, 0.6, 0.5), 0.0, 0.15)
		return cm.commit())
	for j in 3:
		LK.organic(k, "lore_beam", log_m, Transform3D(Basis(Vector3.UP, float(j) * 1.05) * Basis(Vector3.BACK, 0.25), f + Vector3.UP * 0.1))
	k.box("lore_ember", f + Vector3.UP * 0.04, Vector3(0.38, 0.04, 0.38), Basis(Vector3.UP, 0.3), false, 0.7)
	k.box("lore_char", f + Vector3.UP * 0.02, Vector3(0.7, 0.03, 0.7), Basis(Vector3.UP, 0.8), false, 0.5)
	var seat := f + Vector3(1.5, 0, 0.3)
	seat.y = ground(space, seat.x, seat.z)
	var seat_m := _mesh("seat_log", func() -> ArrayMesh:
		var cm := CreatureMesh.new(33)
		cm.tube(PackedVector3Array([Vector3(0, 0, -0.7), Vector3(0, 0.02, 0), Vector3(0, 0, 0.7)]), PackedFloat32Array([0.19, 0.2, 0.18]), 10, Color(0.68, 0.6, 0.52), 0.0, 0.15)
		return cm.commit())
	LK.organic(k, "lore_beam", seat_m, Transform3D(Basis(Vector3.UP, 0.15), seat + Vector3.UP * 0.17))
	# a lantern on a stake behind the fire (unlit glass at the Lanternless Moor)
	var st := f + Vector3(-1.1, 0, -1.2)
	st.y = ground(space, st.x, st.z)
	k.box("lore_beam", st + Vector3.UP * 0.75, Vector3(0.07, 1.5, 0.07), Basis(Vector3.BACK, 0.05), false, 0.6)
	k.box("iron", st + Vector3(0.0, 1.47, 0.0), Vector3(0.15, 0.04, 0.15), Basis.IDENTITY, false, 0.6)
	k.box("glow" if style != "moor" else "dark", st + Vector3(0.0, 1.35, 0.0), Vector3(0.11, 0.17, 0.11), Basis.IDENTITY, false, 0.8)
	k.box("iron", st + Vector3(0.0, 1.24, 0.0), Vector3(0.15, 0.03, 0.15), Basis.IDENTITY, false, 0.6)
	var out := {"fire": f, "seat": seat}
	var g := func(x: float, z: float) -> Vector3: return Vector3(f.x + x, ground(space, f.x + x, f.z + z), f.z + z)
	match style:
		"holds":
			# cut turves stacked to dry, grass side down (the Rooted's way)
			var tb: Vector3 = g.call(-2.3, -0.4)
			for i in 6:
				var tbb := Basis(Vector3.UP, 0.25 + 0.08 * float(i % 2))
				k.box("lore_earth", tb + tbb * Vector3(float(i % 3) * 0.42 - 0.42, 0.1 + 0.18 * floorf(float(i) / 3.0), 0.0), Vector3(0.4, 0.16, 0.28), tbb, false, 0.7)
			k.box("lore_moss", tb + Vector3(0.0, 0.46, 0.0), Vector3(1.2, 0.04, 0.3), Basis(Vector3.UP, 0.29), false, 0.55)
		"quarry":
			# a squared block on two skids, to be dressed (Jory works it: the "block" anchor)
			var bk: Vector3 = g.call(-1.9, 3.05)
			k.box("lore_ashlar", bk + Vector3.UP * 0.36, Vector3(0.95, 0.56, 0.62), Basis(Vector3.UP, 0.1), false, 0.95)
			for s2: float in [-0.3, 0.3]:
				k.box("lore_beam", bk + Vector3(s2, 0.04, 0.0), Vector3(0.1, 0.08, 0.9), Basis(Vector3.UP, 0.1), false, 0.6)
			k.box("lore_rubble", bk + Vector3(0.7, 0.05, 0.4), Vector3(0.5, 0.1, 0.4), Basis(Vector3.UP, 0.7), false, 0.8)
			out["block"] = bk + Vector3.UP * 0.62
		"moor":
			# a windbreak of moor stones on the windward side
			for i in 7:
				var a := -0.9 + 0.3 * float(i)
				var wp: Vector3 = g.call(cos(a + PI) * 1.4, sin(a + PI) * 1.4)
				k.box("lore_rock", wp + Vector3.UP * 0.22, Vector3(0.42, 0.44 - 0.04 * float(i % 3), 0.24), Basis(Vector3.UP, -(a + PI)), false, 0.7)
		"foundry":
			# a cracked bell mould on its side, and a pig of cold bronze
			var mp: Vector3 = g.call(-2.2, 0.6)
			for i in 6:
				var a := float(i) * 0.5
				var mb := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.25)
				k.box("lore_plaster", mp + Vector3(0, 0.32, 0) + mb * Vector3(0, 0, -0.36), Vector3(0.24, 0.6, 0.07), mb, false, 0.6)
			k.box("lore_bronze", mp + Vector3(0.6, 0.06, 0.6), Vector3(0.5, 0.12, 0.16), Basis(Vector3.UP, 0.4), false, 0.8)
		"orchard":
			# a grafting trestle: a plank on two crossed legs, a knife, a bundle of scions
			var tp: Vector3 = g.call(-2.2, 0.5)
			var tb2 := Basis(Vector3.UP, 0.5)
			k.box("lore_beam", tp + tb2 * Vector3(0, 0.72, 0), Vector3(1.3, 0.05, 0.36), tb2, false, 0.7)
			for s3: float in [-0.5, 0.5]:
				k.box("lore_beam", tp + tb2 * Vector3(s3, 0.36, 0), Vector3(0.06, 0.72, 0.3), tb2, false, 0.55)
			for i in 5:
				k.box("lore_char", tp + tb2 * Vector3(-0.3 + 0.03 * float(i), 0.77, -0.05 + 0.025 * float(i)), Vector3(0.02, 0.02, 0.5), tb2 * Basis(Vector3.UP, 0.05 * float(i)), false, 0.8)
			k.box("lore_moss", tp + tb2 * Vector3(0.35, 0.77, 0.0), Vector3(0.12, 0.05, 0.1), tb2, false, 1.0)
		"necropolis":
			# candles on a fallen headstone, all set facing the mountain
			var hp: Vector3 = g.call(-2.0, 0.3)
			k.box("lore_tstone", hp + Vector3.UP * 0.1, Vector3(0.62, 0.2, 0.9), Basis(Vector3.UP, 0.2), false, 0.8)
			for i in 4:
				k.box("lore_plaster", hp + Vector3(-0.18 + 0.12 * float(i), 0.26, -0.2 + 0.1 * float(i % 2)), Vector3(0.04, 0.12, 0.04), Basis.IDENTITY, false, 1.0)
				k.box("glow", hp + Vector3(-0.18 + 0.12 * float(i), 0.34, -0.2 + 0.1 * float(i % 2)), Vector3(0.02, 0.03, 0.02), Basis.IDENTITY, false, 1.0)
		"mere":
			# an upturned punt drawn up out of the wet, and a mooring post
			var bp: Vector3 = g.call(-2.6, 0.2)
			var bb := Basis(Vector3.UP, 0.4)
			k.box("lore_beam", bp + bb * Vector3(0, 0.36, 0), Vector3(0.9, 0.05, 2.6), bb, false, 0.55)
			for s4: float in [-1.0, 1.0]:
				k.box("lore_beam", bp + bb * Vector3(s4 * 0.44, 0.18, 0), Vector3(0.05, 0.34, 2.5), bb, false, 0.5)
			k.box("lore_beam", bp + bb * Vector3(0, 0.18, 1.28), Vector3(0.84, 0.34, 0.05), bb, false, 0.5)
			var post: Vector3 = g.call(-0.6, 2.4)
			k.box("lore_beam", post + Vector3.UP * 0.55, Vector3(0.12, 1.1, 0.12), Basis(Vector3.BACK, 0.12), false, 0.55)
		# --- south marches ---
		"downs":
			# a hurdle leaned on two stakes, a feed-sack and a coil of rope: a shepherd's camp
			var dp: Vector3 = g.call(-2.2, 0.4)
			var db := Basis(Vector3.UP, 0.3)
			k.box("lore_beam", dp + db * Vector3(0, 0.55, 0), Vector3(1.6, 0.9, 0.05), db * Basis(Vector3.RIGHT, -0.18), false, 0.6)
			for s6: float in [-0.7, 0.7]:
				k.box("lore_beam", dp + db * Vector3(s6, 0.4, 0.2), Vector3(0.06, 0.8, 0.06), db, false, 0.6)
			k.box("lore_plaster", dp + db * Vector3(1.3, 0.14, 0.7), Vector3(0.5, 0.3, 0.35), db, false, 0.7)
			k.box("lore_beam", dp + db * Vector3(-1.2, 0.06, 0.9), Vector3(0.5, 0.1, 0.5), db * Basis(Vector3.UP, 0.7), false, 0.5)
	_commit(k, h, "OutpostBody")
	var flame := Vfx.emitter(Color(1.0, 0.55, 0.2), {"count": 16, "life": 0.7, "speed": Vector2(0.3, 0.9), "size": 0.15, "gravity": 1.4, "radius": 0.13, "spread": 12.0, "dir": Vector3.UP, "scale_var": 0.5})
	if flame:
		flame.name = "Flames"
		h.add_child(flame)
		flame.global_position = f + Vector3.UP * 0.12
		flame.visibility_range_end = 70.0
		flame.emitting = true
	var smoke := Vfx.emitter(Color(0.3, 0.3, 0.33, 0.3), {"count": 6, "life": 3.5, "speed": Vector2(0.2, 0.45), "size": 0.42, "gravity": -0.1, "radius": 0.1, "additive": false, "spread": 14.0})
	if smoke:
		smoke.name = "Smoke"
		h.add_child(smoke)
		smoke.global_position = f + Vector3.UP * 0.7
		smoke.visibility_range_end = 70.0
		smoke.emitting = true
	var l := light(h, "OutpostFire", f + Vector3.UP * 0.55, Color(1.0, 0.52, 0.2), 0.7, 5.8)
	# a camp fire is light the gloom will not cross: ordinary foes slink off it (not a rest, not a
	# checkpoint: LightGrid's "mirror" kind), so the giver is not stood in the middle of a fight
	LightGrid.register(l, 5.5, LightGrid.MIRROR)
	l.tree_exiting.connect(func() -> void: LightGrid.unregister(l))
	out["light"] = l
	return out


# --- Abel's grave -------------------------------------------------------------------------------

static func sexton(parent: Node, space: PhysicsDirectSpaceState3D, pit: Vector2, yaw: float) -> Dictionary:
	LK.ensure_mats()
	var h := holder(parent, "SextonDig")
	var k := OssKit.new()
	k.keep_lanes = false
	var gy := ground(space, pit.x, pit.y)
	var b := Basis(Vector3.UP, yaw)
	var o := Vector3(pit.x, gy, pit.y)
	k.box("dark", o + Vector3.UP * 0.015, Vector3(0.85, 0.02, 1.85), b, false, 0.12)
	for s: float in [-1.0, 1.0]:
		k.box("lore_soil", o + b * Vector3(s * 0.5, 0.05, 0), Vector3(0.18, 0.12, 2.05), b * Basis(Vector3.FORWARD, s * 0.25), false, 0.6)
		k.box("lore_soil", o + b * Vector3(0, 0.05, s * 1.0), Vector3(1.0, 0.12, 0.18), b * Basis(Vector3.RIGHT, -s * 0.25), false, 0.6)
	var spoil := _mesh("spoil_heap", func() -> ArrayMesh:
		var cm := CreatureMesh.new(41)
		cm.blob(Vector3.ZERO, Vector3(0.55, 0.32, 0.95), Basis.IDENTITY, Color(0.46, 0.38, 0.3), 0.0, 0.22, 0.0, 7, 12)
		cm.blob(Vector3(0.2, 0.1, 0.4), Vector3(0.3, 0.22, 0.35), Basis.IDENTITY, Color(0.42, 0.35, 0.28), 0.0, 0.25, 0.0, 6, 10)
		return cm.commit())
	var heap_at := o + b * Vector3(1.3, -0.08, 0.1)
	LK.organic(k, "lore_soil", spoil, Transform3D(b, heap_at))
	# a lantern on a stake at the head of the grave
	var st := o + b * Vector3(-0.75, 0, -1.2)
	st.y = ground(space, st.x, st.z)
	k.box("lore_beam", st + Vector3.UP * 0.6, Vector3(0.06, 1.2, 0.06), Basis(Vector3.BACK, 0.06), false, 0.6)
	k.box("iron", st + Vector3(0.0, 1.22, 0.0), Vector3(0.14, 0.04, 0.14), b, false, 0.6)
	k.box("glow", st + Vector3(0.0, 1.1, 0.0), Vector3(0.1, 0.16, 0.1), b, false, 0.8)
	k.box("iron", st + Vector3(0.0, 1.0, 0.0), Vector3(0.14, 0.03, 0.14), b, false, 0.6)
	_commit(k, h, "DigBody")
	var l := light(h, "GraveLantern", st + Vector3(0, 1.15, 0), Color(1.0, 0.58, 0.28), 0.45, 4.4)
	return {"pit": o, "heap": heap_at + Vector3.UP * 0.3, "light": l}


# --- Col's chopping block ---------------------------------------------------------------------------

static func block(parent: Node, space: PhysicsDirectSpaceState3D, at: Vector2) -> Vector3:
	LK.ensure_mats()
	var h := holder(parent, "ChopBlock")
	var k := OssKit.new()
	k.keep_lanes = false
	var p := Vector3(at.x, ground(space, at.x, at.y), at.y)
	var stump := _mesh("chop_stump", func() -> ArrayMesh:
		var cm := CreatureMesh.new(51)
		cm.tube(PackedVector3Array([Vector3(0, -0.05, 0), Vector3(0, 0.36, 0), Vector3(0, 0.45, 0)]), PackedFloat32Array([0.3, 0.26, 0.25]), 11, Color(0.75, 0.66, 0.56), 0.0, 0.15)
		return cm.commit())
	LK.organic(k, "lore_beam", stump, Transform3D(Basis.IDENTITY, p))
	var split := _mesh("split_log", func() -> ArrayMesh:
		var cm := CreatureMesh.new(52)
		cm.tube(PackedVector3Array([Vector3(0, 0, -0.22), Vector3(0, 0, 0.22)]), PackedFloat32Array([0.07, 0.07]), 6, Color(0.78, 0.68, 0.56), 0.0, 0.12, 0.0, Vector2(1.0, 0.6))
		return cm.commit())
	for i in 6:
		var a := float(i) * 1.1
		var q := p + Vector3(cos(a) * (0.55 + 0.1 * float(i % 2)), 0.05, sin(a) * 0.5 + 0.35)
		q.y = ground(space, q.x, q.z) + 0.05
		LK.organic(k, "lore_beam", split, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.3 * float(i % 3)), q))
	_commit(k, h, "BlockBody")
	return p + Vector3.UP * 0.46


# --- the forge's flare --------------------------------------------------------------------------

static func forge_flare(parent: Node, at: Vector3) -> OmniLight3D:
	# a coal-orange, not red: red-shifted light on skin falls under the grade's warm band (magenta)
	var l := light(parent as Node3D, "ForgeFlare", at, Color(1.0, 0.7, 0.42), 0.0, 5.0)
	l.visible = false
	return l


# --- the cottages -----------------------------------------------------------------------------------

static func site_y(n: String, fallback := 0.0) -> float:
	for s in WorldLanes.sites:
		if String(s.name) == n:
			return float(s.floor_y)
	return fallback


static func cottage_xf(id: String) -> Transform3D:
	var c: Dictionary = COTTAGES[id]
	var ctr: Vector2 = c.c
	var yaw := float(c.get("yaw", 0.0))
	if c.has("face"):
		var d: Vector2 = (c.face as Vector2) - ctr
		yaw = atan2(-d.x, -d.y) + float(c.get("add", 0.0))
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(ctr.x, site_y(String(c.site)), ctr.y))


## Lit panes over the shutters of a dark cottage, with an iron cross in front, and chimney smoke.
## Each pane also throws a warm gobo shaft and a short spill omni onto the yard (the glass alone
## was a flat card; the trail is what reads as light leaving the house).
static func windows(parent: Node, id: String, smoke := true) -> Node3D:
	LK.ensure_mats()
	var h := holder(parent, "Lit_" + id)
	var k := OssKit.new()
	k.keep_lanes = false
	var c: Dictionary = COTTAGES[id]
	var w := float(c.w)
	var d := float(c.d)
	var xf := cottage_xf(id)
	var hw := w * 0.5
	var hd := d * 0.5
	# [centre (local, on the outer face), outward normal (local), along (local)]
	var panes := [
		[Vector3(-hw + w * 0.72, 0, -hd), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(hw - w * 0.3, 0, hd), Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		[Vector3(hw - w * 0.7, 0, hd), Vector3(0, 0, 1), Vector3(-1, 0, 0)],
		[Vector3(-hw, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)],
	]
	var warm := Color(1.0, 0.58, 0.24)
	var pi := 0
	for p: Array in panes:
		var nrm: Vector3 = p[1]
		var along: Vector3 = p[2]
		var ctr: Vector3 = (p[0] as Vector3) + Vector3.UP * 1.4 - nrm * 0.08
		# four mullioned panes instead of one flat glow card
		var half_a := along * 0.4
		var half_h := Vector3.UP * 0.45
		var mid_a := along * 0.02
		var mid_h := Vector3.UP * 0.02
		var panes4: Array = [
			[ctr - half_a * 0.5 - half_h * 0.5 - mid_a - mid_h, 0.38, 0.42],
			[ctr + half_a * 0.5 - half_h * 0.5 + mid_a - mid_h, 0.38, 0.42],
			[ctr - half_a * 0.5 + half_h * 0.5 - mid_a + mid_h, 0.38, 0.42],
			[ctr + half_a * 0.5 + half_h * 0.5 + mid_a + mid_h, 0.38, 0.42],
		]
		for pane: Array in panes4:
			var pc: Vector3 = pane[0]
			var pw: float = pane[1]
			var ph: float = pane[2]
			var a := xf * (pc - along * pw * 0.5 - Vector3.UP * ph * 0.5)
			var b := xf * (pc + along * pw * 0.5 - Vector3.UP * ph * 0.5)
			var cc := xf * (pc + along * pw * 0.5 + Vector3.UP * ph * 0.5)
			var dd := xf * (pc - along * pw * 0.5 + Vector3.UP * ph * 0.5)
			k.quad("glow", a, b, cc, dd, xf.basis * nrm, false, 0.11)
		var wb := xf.basis * Basis(along, Vector3.UP, along.cross(Vector3.UP))
		k.box("iron", xf * (ctr + nrm * 0.03), Vector3(0.04, 0.92, 0.04), wb, false, 0.5)
		k.box("iron", xf * (ctr + nrm * 0.03 + Vector3.UP * 0.05), Vector3(0.82, 0.04, 0.04), wb, false, 0.5)
		k.box("iron", xf * (ctr + nrm * 0.03), Vector3(0.82, 0.04, 0.04), wb, false, 0.45)   # crossbar
		var world_ctr: Vector3 = xf * ctr
		var out: Vector3 = (xf.basis * nrm).normalized()
		Interiors.shaft(h, "WindowTrail_%d" % pi, world_ctr - out * 0.05, out + Vector3(0.0, -0.55, 0.0), warm, 0.55, 8.0, 14.0)
		light(h, "WindowSpill_%d" % pi, world_ctr - out * 0.7, warm, 0.32, 4.2)
		pi += 1
	_commit(k, h, "LitBody", 120.0)
	if smoke:
		var gable_h := H + d * 0.5 * 0.95
		var cht := gable_h + (1.5 if String(c.roof) != "slate" else 1.0)
		var s := Vfx.emitter(Color(0.32, 0.32, 0.36, 0.35), {"count": 10, "life": 4.5, "speed": Vector2(0.25, 0.5), "size": 0.55, "gravity": -0.12, "radius": 0.1, "additive": false, "spread": 12.0})
		if s:
			s.name = "ChimneySmoke"
			h.add_child(s)
			s.global_position = xf * Vector3(hw - 0.35, cht + 0.5, hd * 0.25)
			s.emitting = true
	return h


## New slates patched into the Reeds' roof, and the ladder still leaning on the front.
static func reed_roof(parent: Node, space: PhysicsDirectSpaceState3D) -> Node3D:
	LK.ensure_mats()
	var h := holder(parent, "ReedRoof")
	var k := OssKit.new()
	k.keep_lanes = false
	var c: Dictionary = COTTAGES.reed
	var w := float(c.w)
	var d := float(c.d)
	var hd := d * 0.5
	var xf := cottage_xf("reed")
	var ridge := H + hd * 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for s: float in [-1.0, 1.0]:
		var eave := Vector3(0, H - 0.45 * (ridge - H) / hd, s * (hd + 0.45))
		var top := Vector3(0, ridge, 0)
		var dv := (top - eave).normalized()
		var out := Vector3(0, absf(dv.z), -dv.y * s).normalized()
		var rb := xf.basis * Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out)).orthonormalized()
		for i in 9:
			var t := rng.randf_range(0.15, 0.85)
			var x := rng.randf_range(-w * 0.42, w * 0.42)
			var p := eave.lerp(top, t) + Vector3(x, 0, 0) + out * 0.09
			k.box("lore_tslate", xf * p, Vector3(0.42, 0.025, 0.3), rb * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05)), false, rng.randf_range(1.05, 1.25))
	# ladder: two rails and rungs from the ground to the eave, on the front wall
	var foot := xf * Vector3(w * 0.15, 0, -hd - 0.95)
	foot.y = ground(space, foot.x, foot.z)
	var topp := xf * Vector3(w * 0.15, H + 0.1, -hd - 0.12)
	var dir := (topp - foot)
	var lb := Basis.looking_at(dir.normalized(), Vector3.UP)
	for s2: float in [-1.0, 1.0]:
		k.box("lore_beam", (foot + topp) * 0.5 + xf.basis * Vector3(s2 * 0.22, 0, 0), Vector3(0.06, 0.06, dir.length()), lb, false, 0.65)
	var n := int(dir.length() / 0.3)
	for r in n:
		k.box("lore_beam", foot + dir * (float(r) + 0.6) / float(n + 0.4), Vector3(0.44, 0.04, 0.04), lb, false, 0.6)
	_commit(k, h, "RoofBody", 120.0)
	return h


## The well: boards across its mouth while it is fouled; a new rope, a full bucket, water when it is
## drawn again. Returns {shut, open} (the director shows one).
static func well(parent: Node, space: PhysicsDirectSpaceState3D, c: Vector2) -> Dictionary:
	LK.ensure_mats()
	var y := site_y("hw_well", ground(space, c.x, c.y))
	var at := Vector3(c.x, y, c.y)
	var shut := holder(parent, "WellShut")
	var k := OssKit.new()
	k.keep_lanes = false
	for i in 5:
		var z := -0.8 + 0.4 * float(i)
		k.box("lore_beam", at + Vector3(0.02 * float(i % 2), 0.72, z), Vector3(2.15, 0.06, 0.32), Basis(Vector3.UP, 0.04 * float(i - 2)), false, 0.5 + 0.06 * float(i % 3))
	k.box("lore_beam", at + Vector3(-0.6, 0.77, 0), Vector3(0.1, 0.05, 1.9), Basis.IDENTITY, false, 0.45)
	k.box("lore_beam", at + Vector3(0.6, 0.77, 0), Vector3(0.1, 0.05, 1.9), Basis.IDENTITY, false, 0.45)
	k.box("lore_char", at + Vector3(0.2, 0.8, -0.2), Vector3(0.5, 0.02, 0.06), Basis(Vector3.UP, 0.7), false, 0.6)
	_commit(k, shut, "ShutBody")
	var opened := holder(parent, "WellOpen")
	var k2 := OssKit.new()
	k2.keep_lanes = false
	var bucket := _mesh("full_bucket", func() -> ArrayMesh:
		var cm := CreatureMesh.new(61)
		cm.tube(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.26, 0)]), PackedFloat32Array([0.12, 0.15]), 12, Color(0.62, 0.5, 0.4), 0.0, 0.02)
		return cm.commit())
	LK.organic(k2, "lore_beam", bucket, Transform3D(Basis.IDENTITY, at + Vector3(0.55, 0.68, -0.98)))
	k2.box("dark", at + Vector3(0.55, 0.93, -0.98), Vector3(0.24, 0.01, 0.24), Basis(Vector3.UP, 0.785), false, 0.35)
	var coil := _coil()
	LK.organic(k2, "lore_beam", coil, Transform3D(Basis.IDENTITY, at + Vector3(-0.5, 0.68, -1.0)))
	k2.box("lore_beam", at + Vector3(0.1, 0.95, 0), Vector3(0.025, 0.75, 0.025), Basis.IDENTITY, false, 0.9)
	k2.box("lore_tslate", at + Vector3(0, 0.12, 0), Vector3(1.3, 0.01, 1.3), Basis(Vector3.UP, 0.2), false, 0.5)
	_commit(k2, opened, "OpenBody")
	return {"shut": shut, "open": opened}


## The Harrows' new frame: corner posts to the eaves, wall plates, rafter pairs, a ridge, scaffold.
static func harrow_frame(parent: Node) -> Node3D:
	LK.ensure_mats()
	var h := holder(parent, "HarrowFrame")
	var k := OssKit.new()
	k.keep_lanes = false
	var c: Dictionary = COTTAGES.harrow
	var w := float(c.w)
	var d := float(c.d)
	var hw := w * 0.5
	var hd := d * 0.5
	var xf := cottage_xf("harrow")
	var ridge := H + hd * 0.95
	var b := xf.basis
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.box("lore_beam", xf * Vector3(sx * (hw - 0.25), H * 0.5, sz * (hd - 0.25)), Vector3(0.2, H, 0.2), b, false, 0.8)
	for sz2: float in [-1.0, 1.0]:
		k.box("lore_beam", xf * Vector3(0, H + 0.08, sz2 * (hd - 0.25)), Vector3(w + 0.2, 0.16, 0.18), b, false, 0.78)
	k.box("lore_beam", xf * Vector3(0, ridge, 0), Vector3(w + 0.5, 0.16, 0.16), b, false, 0.8)
	var n := 6
	for i in n:
		var x := lerpf(-hw + 0.2, hw - 0.2, float(i) / float(n - 1))
		for sz3: float in [-1.0, 1.0]:
			var a := Vector3(x, H + 0.1, sz3 * (hd + 0.3))
			var t := Vector3(x, ridge, 0)
			var dv := t - a
			k.box("lore_beam", xf * ((a + t) * 0.5), Vector3(0.1, 0.12, dv.length()), b * Basis.looking_at(dv.normalized(), Vector3.UP), false, 0.82)
	# scaffold along the front: two poles, a plank, a lashed brace
	for sx2: float in [-1.0, 1.0]:
		k.box("lore_beam", xf * Vector3(sx2 * 1.6, 1.1, -hd - 0.8), Vector3(0.09, 2.2, 0.09), b, false, 0.65)
	k.box("lore_beam", xf * Vector3(0, 1.45, -hd - 0.65), Vector3(3.6, 0.06, 0.4), b, false, 0.7)
	k.box("lore_beam", xf * Vector3(0, 0.9, -hd - 0.82), Vector3(3.3, 0.07, 0.07), b * Basis(Vector3.BACK, 0.35), false, 0.6)
	_commit(k, h, "FrameBody", 120.0)
	return h


## Thatch on the new frame, boarded gables, a lit window glow from the hearth inside.
static func harrow_roof(parent: Node) -> Node3D:
	LK.ensure_mats()
	var h := holder(parent, "HarrowRoof")
	var c: Dictionary = COTTAGES.harrow
	var w := float(c.w)
	var d := float(c.d)
	var hw := w * 0.5
	var hd := d * 0.5
	var xf := cottage_xf("harrow")
	var ridge := H + hd * 0.95
	var t: Dictionary = LA.thatch_roof(w, d, H, ridge, 77)
	for key: String in ["thatch", "under"]:
		var mi := MeshInstance3D.new()
		mi.name = "Thatch_" + key
		mi.mesh = t[key]
		mi.material_override = OssKit.mat("lore_thatch_uv")
		h.add_child(mi)
		mi.global_transform = xf
	var k := OssKit.new()
	k.keep_lanes = false
	for sx: float in [-1.0, 1.0]:
		var gx := sx * hw
		var o := xf.basis * Vector3(sx, 0, 0)
		k.quad("lore_beam", xf * Vector3(gx, H, -hd), xf * Vector3(gx, H, hd), xf * Vector3(gx, ridge, 0), xf * Vector3(gx, ridge, 0), o, false, 0.7)
		k.quad("lore_beam", xf * Vector3(gx - sx * 0.05, H, -hd), xf * Vector3(gx - sx * 0.05, H, hd), xf * Vector3(gx - sx * 0.05, ridge, 0), xf * Vector3(gx - sx * 0.05, ridge, 0), -o, false, 0.5)
	# the hearth inside glows through the broken walls
	k.box("lore_ember", xf * Vector3(hw - 0.9, 0.15, hd * 0.25), Vector3(0.5, 0.05, 0.6), xf.basis, false, 0.9)
	_commit(k, h, "RoofBody", 120.0)
	var fl := Vfx.emitter(Color(1.0, 0.55, 0.2), {"count": 10, "life": 0.6, "speed": Vector2(0.2, 0.6), "size": 0.12, "gravity": 1.2, "radius": 0.15, "spread": 10.0})
	if fl:
		fl.name = "HearthFlames"
		h.add_child(fl)
		fl.global_position = xf * Vector3(hw - 0.9, 0.2, hd * 0.25)
		fl.emitting = true
	return h

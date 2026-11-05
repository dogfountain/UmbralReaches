class_name ThornHenge
extends Node3D
## The Thorn Henge: a pagan stone circle on a terrace cut into the western hill, reached by a
## pilgrim stair across the hill face. Outer ring of leaning menhirs inside a bramble hedge, a
## trilithon gate at the stair head (the seal), an inner horseshoe of five stones, a fallen
## capstone altar and a rune circle. The Thornwarden's arena. Built before the terrain stamp so
## its terrace, flight and gate are registered first (placement order).

static var C := Vector3(-42.0, 8.0, 1.0)   ## terrace centre; y = the terraced plateau there
const R := 13.0                             ## terrace radius
const RING := 10.5                          ## menhir ring
const HEDGE := 12.2
const HEDGE_GAP := 0.32                     ## half-angle of the hedge's mouth (realm), where the seal stands
static var FOOT := Vector2(-20.0, 22.0)     ## stair foot (xz); its y comes from the ground
## Under the Realm (docs/REALM_PLAN.md) the henge stands on its own hill at RealmLayout.HENGE_C and
## the stair starts where west_way ends; `use_realm()` (RealmBosses) switches these before build.
static var realm := false
## The built stair, for walk tests: [foot, landing start, landing end, head, inside the gate].
static var stair_pts: Array[Vector3] = []


static func use_realm() -> void:
	realm = true
	C = Vector3(RealmLayout.HENGE_C.x, 8.0, RealmLayout.HENGE_C.y)
	FOOT = RealmLayout.HENGE_STAIR_FOOT

var _rng := RandomNumberGenerator.new()


static func build(root: Node) -> ThornHenge:
	if root.get_node_or_null("ThornHenge") != null:
		return null
	var h := ThornHenge.new()
	h.name = "ThornHenge"
	h.set_meta("site", "henge")
	root.add_child(h)
	h._build(root)
	return h


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -40, z), Layers.WORLD))
	return (hit.position as Vector3).y if hit else 0.0


func _build(root: Node) -> void:
	_rng.seed = 4407
	var space := get_world_3d().direct_space_state
	# the floor sits at the plateau's own level (median ground over the inner terrace)
	var hs: Array[float] = []
	for i in 7:
		for j in 7:
			var gx := C.x + (float(i) - 3.0) * R * 0.18
			var gz := C.z + (float(j) - 3.0) * R * 0.18
			hs.append(_ground(space, gx, gz))
	hs.sort()
	C.y = snappedf(hs[hs.size() / 2], 0.25)
	var to_foot := (FOOT - Vector2(C.x, C.z)).normalized()
	# the foot is set into the ground (lowest ground round it, less a little) so the first riser is
	# never higher than an easy step from wherever you walk up to it
	var fg := INF
	for o: Vector2 in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5)]:
		fg = minf(fg, _ground(space, FOOT.x + o.x, FOOT.y + o.y))
	var foot := Vector3(FOOT.x, fg - 0.12, FOOT.y)
	if realm:
		to_foot = _realm_head_dir(space, foot)                         # the head swings round the hill
	var gate2 := Vector2(C.x, C.z) + to_foot * R                    # stair head on the terrace edge
	var head := Vector3(gate2.x, C.y, gate2.y)
	var dir3 := Vector3(foot.x - head.x, 0, foot.z - head.z).normalized() if realm else Vector3(to_foot.x, 0, to_foot.y)   # downhill along the flight
	var run := Vector2(head.x - foot.x, head.z - foot.z).length()
	var mid_land := 2.6
	var land_c := foot.lerp(head, 0.5)
	var land_a := land_c + dir3 * (mid_land * 0.5)
	var land_b := land_c - dir3 * (mid_land * 0.5)
	land_a.y = land_c.y
	land_b.y = land_c.y
	# ground under the terrace and flight before anything moves it (retaining wall + stair bases)
	var gmin := INF
	for i in 36:
		var a := TAU * float(i) / 36.0
		gmin = minf(gmin, _ground(space, C.x + cos(a) * R, C.z + sin(a) * R))
	var flight_min := INF
	for i in 13:
		var p := foot.lerp(head, float(i) / 12.0)
		flight_min = minf(flight_min, _ground(space, p.x, p.z))
	WorldLanes.register_terrace("henge", Vector2(C.x, C.z), R + 0.4, C.y)
	# realm: the land's grid is ~3.3 m, so the cut is registered wider than the 3.9 m flight or the
	# ground between grid points bulges back over the treads
	WorldLanes.register_flight("henge_stair", foot, head, 3.4 if realm else 1.9)
	if realm:
		# the terrace's fill blends 4 m outward and would lift the ground back over the flight where
		# the flight itself had nothing to cut: pin the ground under it with small level discs
		var pins := ceili(run / 1.6)
		for i in pins + 1:
			var pp := foot.lerp(head, float(i) / float(pins))
			var py := land_c.y if absf(Vector2(pp.x - land_c.x, pp.z - land_c.z).length()) < mid_land * 0.5 else pp.y
			WorldLanes.register_terrace("henge_stair_pin%d" % i, Vector2(pp.x, pp.z), 2.4, maxf(py - 0.5, foot.y))   # never below the foot: its first riser stays a step
	if realm:
		WorldLanes.register_lane("henge_way", [Vector2(-52.0, -2.0), Vector2(foot.x, foot.z)], 1.2)
	else:
		WorldLanes.register_lane("henge_way", [Vector2(-6.0, 18.0), Vector2(foot.x + 1.5, foot.z + 0.5), Vector2(foot.x, foot.z)], 1.2)
	WorldLanes.register_portal("henge_gate", head - dir3 * 0.2, dir3, 2.3, 3.6)
	var k := OssKit.new()
	k.keep_lanes = false
	# --- pilgrim stair: two flights and a landing, solid down to the hill --------------------
	var n1 := Metrics.steps_for(land_a.y - foot.y)
	var n2 := Metrics.steps_for(head.y - land_b.y)
	k.stairs("stone", foot, land_a, 3.9, n1, flight_min - Metrics.FOUNDATION_BURY)
	k.stairs("stone", land_b, head, 3.9, n2, flight_min - Metrics.FOUNDATION_BURY)
	var side := dir3.cross(Vector3.UP).normalized()
	var lb := Basis(side, Vector3.UP, dir3)
	k.box("stone", (land_a + land_b) * 0.5 + Vector3.DOWN * ((land_c.y - flight_min + 0.6) * 0.5), Vector3(3.9, land_c.y - flight_min + 0.6, mid_land + 0.04), lb, true, 0.92)
	for s: float in [-1.0, 1.0]:                                     # low cheek walls with copings
		for seg: Array in [[foot, land_a], [land_b, head]]:
			var a: Vector3 = seg[0]
			var b: Vector3 = seg[1]
			var f := (b - a).normalized()
			var u := side.cross(f).normalized()
			if u.y < 0.0:
				u = -u
			k.box("stone", (a + b) * 0.5 + side * (s * 1.7) + u * 0.4, Vector3(0.4, 0.8, a.distance_to(b) + 0.3), Basis(side, u, f), true, 0.85)
		k.pinnacle("stone", foot + side * (s * 1.7) - dir3 * -0.2, 0.55, 1.2, 0.5)
	# --- terrace: retaining wall where the hill was filled ----------------------------------
	for i in 48:
		var a0 := TAU * float(i) / 48.0
		var a1 := TAU * float(i + 1) / 48.0
		var p0 := Vector3(C.x + cos(a0) * R, 0, C.z + sin(a0) * R)
		var p1 := Vector3(C.x + cos(a1) * R, 0, C.z + sin(a1) * R)
		var mid := (p0 + p1) * 0.5
		if absf(angle_difference((a0 + a1) * 0.5, atan2(to_foot.y, to_foot.x))) < (0.27 if realm else 0.2):
			continue                                                   # the stair arrives here
		var g := _ground(space, mid.x, mid.z)
		if g > C.y - 0.3:
			continue                                                   # cut side: the hill is the wall
		var bot := minf(g, gmin) - 0.6
		var out := Vector3(mid.x - C.x, 0, mid.z - C.z).normalized()
		var bas := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
		var len := p0.distance_to(p1) + 0.12
		k.box("stone", Vector3(mid.x, (bot + C.y + 0.35) * 0.5, mid.z) + out * 0.25, Vector3(len, C.y + 0.35 - bot, 0.7), bas, true, 0.84)
		k.box("stone", Vector3(mid.x, C.y + 0.42, mid.z) + out * 0.3, Vector3(len, 0.16, 0.86), bas, true, 0.95)
	k.block("floor", Vector3(C.x - 0.01, C.y - 0.02, C.z - 0.01), Vector3(C.x + 0.01, C.y, C.z + 0.01), false)   # (keeps the floor material loaded)
	# --- the stones -------------------------------------------------------------------------
	var gate_a := atan2(to_foot.y, to_foot.x)
	# the ring and the horseshoe are the hub's own weathered menhirs (model, stone, moss skirt),
	# so the henge belongs to the same world as the stone fields below; set facing the altar
	var stones: Array = []
	for i in 22:
		var a := TAU * float(i) / 22.0 + gate_a
		if i == 0:
			continue                                                   # the gate gap
		stones.append([Vector3(C.x + cos(a) * RING, C.y - 0.45, C.z + sin(a) * RING), _rng.randf_range(4.0, 5.8)])
	for i in 7:
		var a := gate_a + PI + (float(i) - 3.0) * 0.42
		stones.append([Vector3(C.x + cos(a) * 5.4, C.y - 0.45, C.z + sin(a) * 5.4), _rng.randf_range(3.0, 3.8)])
	var hub_stone: Material = null
	for mi in root.find_children("Stone", "MeshInstance3D", true, false):
		if String((mi as Node).get_parent().name) == "SM_Menhir":
			hub_stone = (mi as MeshInstance3D).material_override
			if hub_stone == null and (mi as MeshInstance3D).mesh:
				hub_stone = (mi as MeshInstance3D).mesh.surface_get_material(0)
			break
	for st: Array in stones:
		DressedProps._place_menhir(self, st[0], 0.0, float(st[1]), hub_stone if hub_stone else OssKit.mat("rock"), C, true)
	# trilithon gate: two uprights and a lintel across the stair head
	var gp := Vector3(C.x + cos(gate_a) * RING, C.y, C.z + sin(gate_a) * RING)
	var gout := Vector3(cos(gate_a), 0, sin(gate_a))
	var gside := gout.cross(Vector3.UP).normalized()
	var gb := Basis(gside, Vector3.UP, gout)
	if realm:
		# the Realm's weathered stone (RockKit), not the glowing hub-stair stone
		var rk := load("res://core/world/realm/rock_kit.gd")
		for s: float in [-1.0, 1.0]:
			rk.spawn(self, rk.slab(4411 + int(s), Vector3(1.3, 5.6, 1.0), "granite", 0.06), Transform3D(gb, gp + gside * (s * 2.25) + Vector3.DOWN * 0.3), true, 90.0)
		rk.spawn(self, rk.slab(4415, Vector3(6.0, 0.9, 1.2), "granite", 0.02), Transform3D(gb, gp + Vector3.UP * 5.15), true, 90.0)
		rk.spawn(self, rk.boulder(4417, Vector3(3.8, 0.7, 1.9), "mossy"), Transform3D(Basis(Vector3.UP, gate_a + 0.3) * Basis(Vector3.FORWARD, 0.08), C + Vector3.DOWN * 0.1), true, 70.0)
	else:
		for s: float in [-1.0, 1.0]:
			k.box("hub", gp + gside * (s * 2.25) + Vector3.UP * 2.5, Vector3(1.3, 5.8, 1.0), gb, true, 0.92)
		k.box("hub", gp + Vector3.UP * 5.6, Vector3(6.0, 0.9, 1.2), gb, true, 0.85)
		# inner horseshoe, capstone altar, rune circle
		k.box("hub", C + Vector3(0, 0.3, 0), Vector3(3.8, 0.6, 1.9), Basis(Vector3.UP, gate_a + 0.3) * Basis(Vector3.FORWARD, 0.08), true, 0.75)
	# --- bramble hedge round the ring (solid), with the gate gap ------------------------------
	var hedge_body := StaticBody3D.new()
	hedge_body.name = "HedgeBody"
	hedge_body.collision_layer = Layers.WORLD
	add_child(hedge_body)
	var cm := CreatureMesh.new(77)
	var segs := 72
	for i in segs:
		var a0 := gate_a + TAU * (float(i) + 0.5) / float(segs)
		if absf(wrapf(a0 - gate_a, -PI, PI)) < HEDGE_GAP * (1.0 if realm else 0.62):   # realm: the stair arrives slantwise
			continue
		var p := Vector3(C.x + cos(a0) * HEDGE, C.y, C.z + sin(a0) * HEDGE)
		for j in 5:
			var pts := PackedVector3Array()
			var rad := PackedFloat32Array()
			var o := Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.4, 0.4))
			for q in 5:
				var t := float(q) / 4.0
				pts.append(p + o + Vector3(sin(t * 6.0 + float(j)) * 0.35, t * _rng.randf_range(2.4, 3.4), cos(t * 5.0 + float(i)) * 0.3))
				rad.append(lerpf(0.09, 0.025, t))
			cm.tube(pts, rad, 5, Color(0.16, 0.09, 0.07), 0.0, 0.25, 0.0, Vector2.ONE, 0.4)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		# r30: 5.6 m (it was 4.2: a double jump and a ledge grab took the wanderer over and out of a fight)
		bs.size = Vector3(TAU * HEDGE / float(segs) + 0.1, 5.6, 0.9)
		cs.shape = bs
		cs.transform = Transform3D(Basis(Vector3.UP, -a0 + PI * 0.5), p + Vector3.UP * 2.8)
		hedge_body.add_child(cs)
	var hm := MeshInstance3D.new()
	hm.name = "Brambles"
	hm.mesh = OssKit.with_lods(cm.commit())
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.95
	bm.emission_enabled = true
	bm.emission = Color(0.4, 0.04, 0.06)
	bm.emission_energy_multiplier = 0.12
	hm.material_override = bm
	add_child(hm)
	var rest := land_c + side * 3.4
	if realm and _ground(space, land_c.x - side.x * 3.4, land_c.z - side.z * 3.4) < _ground(space, rest.x, rest.z):
		rest = land_c - side * 3.4                                     # the rest on the downhill side
	k.block("stone", rest + Vector3(-1.3, flight_min - 0.6 - rest.y, -1.3), rest + Vector3(1.3, 0.0, 1.3), true, 0.9)
	k.commit(self, "HengeBody")
	# rune circle on the floor: a faint torus, and a cold light over the altar
	var rune := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.4
	tm.outer_radius = 3.55
	rune.mesh = tm
	rune.scale = Vector3(1, 0.05, 1)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.9, 0.25, 0.3)
	rune.material_override = rm
	add_child(rune)
	rune.global_position = C + Vector3.UP * 0.03
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.35, 0.5)
	l.light_energy = 1.2
	l.omni_range = 18.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = C + Vector3.UP * 3.5
	LightPolicy.apply_fade(l)
	# --- the seal and the arena ---------------------------------------------------------------
	# r30: the seal closes the hedge's mouth, not the trilithon: between the menhirs and out through the
	# hedge gap was a way out of the fight, and the trilithon seal stood inside the arena's radius
	var gap := HEDGE_GAP * (1.0 if realm else 0.62)
	var mouth := C + gout * HEDGE * cos(gap) + Vector3.UP * 0.0
	mouth.y = C.y
	var seal := WardSeal.make(self, "henge", mouth, gout, 2.0 * HEDGE * sin(gap) + 0.6, 4.6, "thorn", "The thorn seal")
	var arena := BossArena.make(self, "thornwarden", "The Thornwarden", C, R - 0.6, Thornwarden, C + gside * 4.5 + Vector3.UP * 0.1)
	arena.gate = seal
	arena.subtitle = "what the Rooted asked to stand"
	arena.on_slain = func(fresh: bool) -> void:
		if fresh:
			Events.toast.emit("The thorns wither. The heart is still beating in your hand.")
	# the Rooted's last word to their keeper, cut at the hedge's mouth beside the seal (r30 story)
	var keeper_side := gout.cross(Vector3.UP).normalized()
	var cut: Node3D = (load("res://core/world/realm/lore/lore_more.gd") as GDScript).call("place", self, "bs_henge_keeper", Vector3.ZERO)
	cut.global_position = mouth + keeper_side * (HEDGE * sin(gap) + 1.0) + gout * 0.8 + Vector3.UP * 0.4
	# a fire at the stair head, outside the gate: the checkpoint before the fight
	# the pilgrims' rest: a fire on its own platform off the mid landing (the checkpoint before the
	# henge, and outside the arena so a fall never resets you inside the fight)
	_fire(rest, gate_a)
	stair_pts = [foot, land_a, land_b, head, C + Vector3(cos(gate_a), 0, sin(gate_a)) * (RING - 3.0)]
	print("HENGE built at %s, stair %d+%d steps over %.1f m, foot y %.2f" % [C, n1, n2, run, foot.y])


## Realm: the foot is fixed (west_way's end) and close under the hill, so a radial stair would be
## far too steep. Swing the head round the terrace edge until the flight is long enough for easy
## risers (two flights, ~0.56 m treads, a 2.6 m landing), on whichever side the hill face is
## smoothest under it. Returns the unit xz direction from C to the head.
func _realm_head_dir(space: PhysicsDirectSpaceState3D, foot: Vector3) -> Vector2:
	var c2 := Vector2(C.x, C.z)
	var f2 := Vector2(foot.x, foot.z)
	var d := c2.distance_to(f2)
	var radial := (f2 - c2) / d
	var steps := Metrics.steps_for(C.y - foot.y)
	var need := float(steps) * 0.56 + 2.6
	if d - R >= need:
		return radial
	var phi := acos(clampf((d * d + R * R - need * need) / (2.0 * d * R), -1.0, 1.0))
	phi = minf(phi, acos(R / d) - 0.06)                               # never cut across the terrace
	var best := radial
	var best_err := INF
	for s: float in [-1.0, 1.0]:
		var dir := radial.rotated(phi * s)
		var hd := c2 + dir * R
		var err := 0.0
		for i in 9:
			var t := float(i + 1) / 10.0
			var p := f2.lerp(hd, t)
			err += absf(_ground(space, p.x, p.y) - lerpf(foot.y, C.y, t))
		if err < best_err:
			best_err = err
			best = dir
	return best


func _fire(at: Vector3, yaw: float) -> void:
	var src: Brazier = null
	for node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if node is Brazier:
			src = node as Brazier
			break
	if src == null:
		return
	var b := src.duplicate() as Brazier
	b.name = "HengeFire"
	b.start_lit = false
	add_child(b)
	b.global_position = at
	b.rotation.y = yaw
	if b.lit:
		b._set_lit(false, false)

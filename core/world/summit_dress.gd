class_name SummitDress
extends RefCounted
## Cathedral-scale mossy summit monument + orb mage. Runtime only.

const Chains := preload("res://core/story/quest_chains.gd")
const PLATFORM := "res://art/models/mossy_platform.glb"
const PILLAR := "res://art/models/summit_pillar.glb"
const MOSS_DIFF := "res://art/textures/import/rock_moss_diff.jpg"
const MOSS_NOR := "res://art/textures/import/rock_moss_nor.jpg"
const Check := preload("res://core/debug/check.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")

## Existing summit disc ~r=5.4 at z=-73.5. Seat cathedral behind it so the
## climb stays clear; approach stairs face +Z onto that disc.
const PLATFORM_RADIUS := 12.0
const SUMMIT := Vector3(0.0, 24.5, -83.5)
const TOP_DECK_Y := 2.85


## Remove the triangles of `mi` whose centre falls inside `box` (holder space): a real gap in the
## visible rail, and (since collision is built from the same mesh afterwards) in its collision.
static func _cut_gate(mi: MeshInstance3D, holder: Node3D, box: AABB) -> void:
	var to_h := holder.global_transform.affine_inverse() * mi.global_transform
	var src := mi.mesh
	var out := ArrayMesh.new()
	var removed := 0
	for si in src.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(src, si)
		var arrays := st.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var c := to_h * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
			if box.has_point(c):
				removed += 1
				continue
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	if removed > 0:
		mi.mesh = out
		print("SUMMIT_DRESS gate cut in %s: %d tris" % [mi.name, removed])


static func dress(root: Node) -> void:
	if root == null or root.has_meta("summit_dressed"):
		return
	if Check.res(PLATFORM, PackedScene) == null:
		push_error("SUMMIT_DRESS missing platform glb")
		return
	root.set_meta("summit_dressed", true)
	var holder := Node3D.new()
	holder.name = "SummitAltar"
	root.add_child(holder)
	holder.global_position = SUMMIT

	var tp := Time.get_ticks_usec()
	var platform := Check.attach_glb(holder, PLATFORM, "MossyPlatform")
	if platform == null:
		return
	platform.position = Vector3.ZERO
	Realm.prof_add("summit: load platform", tp)
	tp = Time.get_ticks_usec()
	_paint_platform(platform)
	_approach_stairs(holder, platform)
	Realm.prof_add("summit: paint + approach", tp)
	tp = Time.get_ticks_usec()
	_extended_dais(holder, platform)
	Realm.prof_add("summit: dais", tp)
	tp = Time.get_ticks_usec()
	_solidify_from_meshes(holder, platform)
	Realm.prof_add("summit: collision", tp)
	tp = Time.get_ticks_usec()

	# The monument: a carved stone mage on a rune pedestal, facing the stair (+Z).
	var statue := MageStatue.new()
	statue.name = "MageStatue"
	holder.add_child(statue)
	statue.position = Vector3(0.0, TOP_DECK_Y, 0.0)
	statue.rotation.y = PI

	Realm.prof_add("summit: statue", tp)
	tp = Time.get_ticks_usec()
	# Outer cathedral pillars on the mid terrace only — top dais already has the ref rail.
	if Check.res(PILLAR, PackedScene) != null:
		var spots := [
			Vector3(-7.2, 2.05, -6.8),
			Vector3(7.2, 2.05, -6.8),
		]
		for i in spots.size():
			var pillar := Check.attach_glb(holder, PILLAR, "SummitPillar%d" % i)
			if pillar == null:
				continue
			pillar.position = spots[i]
			pillar.rotation.y = fposmod(float(i) * 1.3 + 0.5, TAU)
			pillar.scale = Vector3.ONE * 0.85
			_paint_pillar(pillar)

	Realm.prof_add("summit: pillars", tp)
	tp = Time.get_ticks_usec()
	# (The hanging moss cards stood up off the tiers like stray grass blades; removed.)

	# the summit ward across the head of the hub stair, and the Ascended Warden's arena on the dais
	var bosses: Array[String] = ["thornwarden", "bone_abbot"]
	var ward := WardSeal.make(holder, "summit", Vector3(0.0, 25.2, -70.9), Vector3.BACK, 5.8, 3.6, "light", "The summit ward", bosses)
	ward.requires_bells = Chains.BELLS_NEEDED     # r36 Act II: the door opens to a peal
	var dais := SUMMIT + Vector3(DAIS_C.x, TOP_DECK_Y, DAIS_C.y)
	var arena := BossArena.make(holder, "ascended_warden", "The Ascended Warden", dais, DAIS_R - 0.5, AscendedWarden, dais + Vector3(0, 0.1, 3.5))   # he rises on the near side of the dais: at -6 m he stood 32 m from the pull and read as a small figure in the bubble
	arena.ceiling = 14.0
	arena.max_rise = 0.5                       # the raid deck is one flat paved floor
	# r34 raids: the room the fight changes (pylons, broken edges, the falling sky, its light)
	var raid: Node3D = SummitRaid.build(holder, dais, DAIS_R, holder.global_basis)
	arena.room = raid
	arena.requires_bosses = bosses
	arena.requires_bells = Chains.BELLS_NEEDED
	# r30: the ward at the Crossing's head stays the progression seal (33 m back, past the leash); the
	# fight shuts a veil across the dais mouth instead, 1.5 m behind the wanderer
	var m0: Vector3 = mouth[0]
	var m1: Vector3 = mouth[1]
	var chord := m1 - m0
	var inward := Vector3(-chord.z, 0.0, chord.x).normalized()
	if inward.dot(Vector3(DAIS_C.x, 0.0, DAIS_C.y) - (m0 + m1) * 0.5) < 0.0:
		inward = -inward
	var veil_at := holder.to_global((m0 + m1) * 0.5 + inward * 0.25)
	veil_at.y = SUMMIT.y + TOP_DECK_Y
	arena.gate = WardSeal.make_arena_gate(holder, "warden_mouth", veil_at, inward, Vector2(chord.x, chord.z).length() + 0.5, 3.6, "light")
	arena.subtitle = "the one who holds the door"
	arena.phase_titles = {3: "Aurel, Hierarch"}      # r30 story: he lets go with one hand, and the bar names him
	# r30 story: the ward's carved reason, a pilgrim's tally on the last step, and the dais stone
	var lore_more := load("res://core/world/realm/lore/lore_more.gd") as GDScript
	lore_more.call("place", holder, "bs_ward", Vector3(1.9, 25.6, -70.3))
	lore_more.call("place", holder, "bs_last_step", Vector3(-1.7, 25.6, -69.4))
	lore_more.call("place", holder, "bs_dais", SUMMIT + Vector3(DAIS_C.x, TOP_DECK_Y + 0.25, DAIS_C.y + DAIS_R + 0.9))
	# the "where do I go" for the whole map: a pale column from above the dais into the vortex eye
	Wayfinding.beacon(holder, dais, "ascended_warden", Color(1.0, 0.86, 0.62), 170.0, 1.1, 9.0, true)
	arena.on_slain = func(_fresh: bool) -> void:
		if is_instance_valid(raid):
			raid.call("set_mood", "won")
		# (no toast here: story.gd stages the Warden's fall as one beat; the seal's text is in the satchel)
	# r30: a fire at the stair head, outside the arena (a fall there sent you back down the whole climb)
	_summit_fire.call_deferred(holder)
	Realm.prof_add("summit: ward + arena", tp)
	print("SUMMIT_DRESS cathedral platform r=%.1f at %s, fighting dais r=%.1f at %s" % [PLATFORM_RADIUS, SUMMIT, DAIS_R, dais])


## The approach used to be an invisible ramp through solid tier faces: you walked up through
## 0.5-0.9 m of stone. Cut the corridor out of the monument and moss and build a real flight
## there: eight steps of dressed stone with stepped cheek walls (they close the cut edges and stop
## you walking off the side) and newel pinnacles at the foot. Collision is the kit's ramp under
## the treads, so it matches what you see to within half a riser.
const STAIR_FOOT := Vector3(0.0, 0.7, 12.35)     ## holder space: the hub stair's top landing
const STAIR_HEAD := Vector3(0.0, TOP_DECK_Y, 6.4)
const STAIR_HALF_W := 2.75
const CORRIDOR := AABB(Vector3(-2.95, 0.74, 6.4), Vector3(5.9, 3.6, 7.2))


static func _approach_stairs(holder: Node3D, platform: Node) -> void:
	var inv := holder.global_transform.affine_inverse()
	for node in platform.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		if n == "StoneMonument" or n == "MossCarpet":
			_cut_gate(mi, holder, CORRIDOR)
		elif n.begins_with("MossRock"):
			var bb := inv * mi.global_transform * mi.get_aabb()
			if bb.intersects(CORRIDOR.grow(0.2)):
				mi.visible = false
	var kit := OssKit.new()
	var steps := Metrics.steps_for(STAIR_HEAD.y - STAIR_FOOT.y)
	kit.stairs("stone", STAIR_FOOT, STAIR_HEAD, STAIR_HALF_W * 2.0, steps)
	var tread := (STAIR_FOOT.z - STAIR_HEAD.z) / float(steps)
	var rise := (STAIR_HEAD.y - STAIR_FOOT.y) / float(steps)
	for side: float in [-1.0, 1.0]:
		var x0 := side * STAIR_HALF_W
		var x1 := side * (STAIR_HALF_W + 0.48)
		for i in steps:
			var z0 := STAIR_FOOT.z - tread * float(i)
			var top := STAIR_FOOT.y + rise * float(i + 1) + 0.5
			kit.block("stone", Vector3(minf(x0, x1), STAIR_FOOT.y - 0.4, z0 - tread - 0.01), Vector3(maxf(x0, x1), top, z0 + 0.01))
			kit.box("stone", Vector3((x0 + x1) * 0.5, top + 0.06, z0 - tread * 0.5), Vector3(0.62, 0.12, tread + 0.04), Basis.IDENTITY, true, 0.86)
		kit.pinnacle("stone", Vector3(side * (STAIR_HALF_W + 0.24), STAIR_FOOT.y, STAIR_FOOT.z + 0.1), 0.62, STAIR_FOOT.y * 0.0 + 1.7, 0.55)
	var host := Node3D.new()
	host.name = "ApproachStairs"
	holder.add_child(host)
	kit.commit(host, "StairsBody")


## The Warden's fighting floor. r34 raids: the great deck of the raid floor (RealmLayout.RAIDS "summit":
## centre (0, -118), r 28, at the top deck's height), built behind the platform out over the chasm and
## against the Crowns' cirque. Its front edge meets the platform's top deck at the rear opening (the
## mouth, where the veil shuts on the pull); a coped parapet runs round the rest, broken open on the
## east and west where the deck hangs over the chasm (SummitRaid.EDGE_ANGLES: the Gale blows you
## there); piers carry it down to the ground. The back rail and moss rocks it covers are removed
## (before _solidify_from_meshes, so their collision goes too); the lift jetty route keeps clear.
const DAIS_C := Vector2(0.0, -34.5)          ## holder xz (world (0, -118)); front edge at z -6.5, just behind the deck
const DAIS_R := 28.0
const DAIS_THICK := 1.0
const DAIS_GAP := 3.2                        ## half width of the opening onto the top deck
const SCREEN_H := 2.5                        ## rim wall height where it borders the platform (GRAB_MAX 2.25)
const SummitRaid := preload("res://core/world/summit_raid.gd")
static var mouth: Array[Vector3] = [Vector3(-3.8, TOP_DECK_Y, -7.2), Vector3(3.8, TOP_DECK_Y, -7.2)]   ## holder: the opening's two ends
const JUNCTION := AABB(Vector3(-3.3, 1.8, -7.6), Vector3(6.6, 3.0, 2.0))   ## deck -> dais, cleared


static func _in_dais(p: Vector3, grow := 0.0) -> bool:
	return Vector2(p.x, p.z).distance_to(DAIS_C) <= DAIS_R + grow


## Is the rim segment at holder angle `a` (0 = east, PI/2 = south) one of the broken edges?
static func _edge_gap(a: float) -> bool:
	for deg: float in SummitRaid.EDGE_ANGLES:
		if absf(rad_to_deg(angle_difference(a, deg_to_rad(deg)))) < SummitRaid.EDGE_HALF:
			return true
	return false


static func _extended_dais(holder: Node3D, platform: Node) -> void:
	var inv := holder.global_transform.affine_inverse()
	for node in platform.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		if n.begins_with("StoneRail"):
			_cut_dais(mi, holder)
		elif n.begins_with("MossRock"):
			var bb := inv * mi.global_transform * mi.get_aabb()
			if _in_dais(bb.get_center(), 0.6) or bb.intersects(JUNCTION):
				mi.visible = false
	var k := OssKit.new()
	k.keep_lanes = false
	var top := TOP_DECK_Y
	var bot := top - DAIS_THICK
	var segs := 72
	# a raid floor that reads from the air: a rose of inlaid slate bands and eight spokes
	var rings: Array[float] = [0.0, 3.2, 3.6, 10.6, 11.0, 16.6, 17.0, 23.4, 23.8, 26.9, DAIS_R]
	var ring_keys: Array[String] = ["floor", "slate", "floor", "slate", "floor", "slate", "floor", "slate", "floor", "stone"]
	var c := Vector3(DAIS_C.x, 0, DAIS_C.y)
	for s in segs:
		var a0 := TAU * float(s) / float(segs)
		var a1 := TAU * float(s + 1) / float(segs)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var spoke := s % 9 == 0
		for ri in rings.size() - 1:
			var r0: float = rings[ri]
			var r1: float = rings[ri + 1]
			var key := ring_keys[ri]
			if spoke and key == "floor" and ri > 0:
				key = "slate"
			k.quad(key, c + d0 * r0 + Vector3.UP * top, c + d0 * r1 + Vector3.UP * top, c + d1 * r1 + Vector3.UP * top, c + d1 * r0 + Vector3.UP * top, Vector3.UP, true, 0.92 if s % 2 == 0 else 1.0)
		# rim face and soffit
		var o0 := c + d0 * DAIS_R
		var o1 := c + d1 * DAIS_R
		k.quad("stone", o0 + Vector3.UP * bot, o1 + Vector3.UP * bot, o1 + Vector3.UP * top, o0 + Vector3.UP * top, (d0 + d1) * 0.5, true, 0.86)
		k.quad("stone", c + Vector3.UP * bot, o0 + Vector3.UP * bot, o1 + Vector3.UP * bot, c + Vector3.UP * bot, Vector3.DOWN, false, 0.7)
	# the step from the deck: a slab over the rear opening, flush with both floors
	k.block("floor", Vector3(-DAIS_GAP, top - 0.3, -7.4), Vector3(DAIS_GAP, top, -6.2), true, 0.95)
	# parapet: coped wall round the edge, open onto the deck, at the lift jetty and at the broken edges
	var space := holder.get_world_3d().direct_space_state
	var wall_r := DAIS_R - 0.3
	var at := func(a: float) -> Vector3: return Vector3(DAIS_C.x + cos(a) * wall_r, top, DAIS_C.y + sin(a) * wall_r)
	var opening: Array[bool] = []
	var broken: Array[bool] = []
	var mouth_ends: Array[Vector3] = []
	for s in segs:
		var am := TAU * (float(s) + 0.5) / float(segs)
		var mid: Vector3 = at.call(am)
		opening.append(absf(mid.x) < DAIS_GAP + 0.6 and mid.z > DAIS_C.y)       # (the Ossuary's lift jetty left the rail is whole)
		broken.append(_edge_gap(am))
	var piers := 0
	for s in segs:
		var a0 := TAU * float(s) / float(segs)
		var a1 := TAU * float(s + 1) / float(segs)
		var p0: Vector3 = at.call(a0)
		var p1: Vector3 = at.call(a1)
		var mid := (p0 + p1) * 0.5
		var open := opening[s] or broken[s]
		if open != (opening[s - 1] or broken[s - 1]):
			k.pinnacle("stone", p0, 0.62, 1.5 + (SCREEN_H - 0.9 if Vector2(p0.x, p0.z).length() < PLATFORM_RADIUS + 0.5 else 0.0), 0.55)       # where the wall stops or starts again
		if opening[s] and mid.z > DAIS_C.y:
			mouth_ends.append(p0)
			mouth_ends.append(p1)
		if not open:
			var out := Vector3(mid.x - DAIS_C.x, 0, mid.z - DAIS_C.y).normalized()
			var bas := Basis(out.cross(Vector3.UP).normalized(), Vector3.UP, out)
			var len := p0.distance_to(p1) + 0.1
			# where the rim borders the platform's mid terrace (not the chasm) it is a screen wall
			# above the hands' reach, so the mouth veil is the only way out of the fight
			var wh := SCREEN_H if Vector2(mid.x, mid.z).length() < PLATFORM_RADIUS + 0.5 else 0.9
			k.box("stone", mid + Vector3.UP * (wh * 0.5), Vector3(len, wh, 0.45), bas, true, 0.88)
			k.box("stone", mid + Vector3.UP * (wh + 0.07), Vector3(len + 0.04, 0.14, 0.62), bas, true, 0.97)
		# piers down to the ground: under every fourth rim segment and on an inner ring, clear of the
		# platform (anything the ray meets that is not the terrain): none on a roof
		for ring: float in [DAIS_R - 1.4, 15.0]:
			if (ring > 20.0 and s % 4 != 1) or (ring < 20.0 and s % 9 != 4):
				continue
			var am2 := (a0 + a1) * 0.5
			var foot := Vector3(DAIS_C.x + cos(am2) * ring, bot, DAIS_C.y + sin(am2) * ring)
			if Vector2(foot.x, foot.z).length() < PLATFORM_RADIUS + 1.0:
				continue
			var w := holder.global_transform * foot
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(w + Vector3.DOWN * 0.2, w + Vector3.DOWN * 120.0, Layers.WORLD))
			if hit.is_empty() or not String((hit.collider as Node).name).contains("Terrain"):
				continue
			var gy: float = (inv * (hit.position as Vector3)).y - 1.0
			if bot - gy < 2.5:
				continue                                  # the cut ground of the cirque: the deck sits on it
			var out2 := Vector3(foot.x - DAIS_C.x, 0, foot.z - DAIS_C.y).normalized()
			var bas2 := Basis(out2.cross(Vector3.UP).normalized(), Vector3.UP, out2)
			var thick := 2.0 if ring > 20.0 else 2.6
			k.box("stone", Vector3(foot.x, (bot + gy) * 0.5, foot.z), Vector3(thick, bot - gy, thick + 0.6), bas2, true, 0.8)
			k.box("stone", foot + Vector3.UP * -0.35, Vector3(thick + 0.5, 0.7, thick + 1.2), bas2, true, 0.9)    # corbel under the deck
			piers += 1
	var host := Node3D.new()
	host.name = "ExtendedDais"
	host.set_meta("site", "summit_dais")
	holder.add_child(host)
	k.commit(host, "DaisBody")
	var wc := holder.global_transform * Vector3(DAIS_C.x, 0, DAIS_C.y)
	# sites are rects: register the square inside the disc (the square round it would take in the
	# rails)
	var half := DAIS_R * 0.7
	WorldLanes.register_site("summit_dais", Rect2(wc.x - half, wc.z - half, half * 2.0, half * 2.0), holder.global_position.y + top, NAN, true)
	# the mouth: the chord across the opening onto the deck
	if mouth_ends.size() >= 2:
		var lo := mouth_ends[0]
		var hi := mouth_ends[0]
		for e in mouth_ends:
			if e.x < lo.x: lo = e
			if e.x > hi.x: hi = e
		mouth = [lo, hi]
	print("SUMMIT_DRESS raid deck r=%.1f, %d piers, mouth %s" % [DAIS_R, piers, mouth])


## Drop the back rail's triangles that the dais covers (and those across the deck -> dais step).
static func _cut_dais(mi: MeshInstance3D, holder: Node3D) -> void:
	var to_h := holder.global_transform.affine_inverse() * mi.global_transform
	var src := mi.mesh
	var out := ArrayMesh.new()
	var removed := 0
	for si in src.get_surface_count():
		var st := SurfaceTool.new()
		st.create_from(src, si)
		var arrays := st.commit_to_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(verts.size())
			for i in verts.size():
				idx[i] = i
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var c := to_h * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
			if _in_dais(c, 0.3) or JUNCTION.has_point(c):
				removed += 1
				continue
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, src.surface_get_material(si))
	if removed > 0:
		mi.mesh = out
		print("SUMMIT_DRESS dais cut in %s: %d tris" % [mi.name, removed])


## Collision from the visible meshes: trimesh for the stone monument and its rails, simplified
## convex hulls for every moss rock (you used to walk straight through them).
static func _solidify_from_meshes(holder: Node3D, platform: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "MonumentBody"
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var inv := holder.global_transform.affine_inverse()
	var rocks := 0
	for node in platform.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name)
		var shape: Shape3D = null
		if n == "StoneMonument" or n == "MossCarpet":
			# the approach corridor was already cut out of these meshes by _approach_stairs, so the
			# collision is exactly what you see; the moss carpet is the real walking surface (it sits
			# 0.16 m proud of the stone, and you used to sink into it)
			shape = mi.mesh.create_trimesh_shape()
		elif n.begins_with("StoneRail") or n == "StoneDaisRail":
			shape = mi.mesh.create_trimesh_shape()
		elif n.begins_with("MossRock"):
			if not mi.visible:
				continue
			shape = GenCache.convex_shape(mi.mesh, PLATFORM)   # 120 simplified hulls were 1.3 s a load
			rocks += 1
		if shape == null:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = inv * mi.global_transform
		body.add_child(cs)
	print("SUMMIT_DRESS collision from meshes: monument+rails trimesh, %d rock hulls" % rocks)


static func _moss_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.72, 0.38)
	var diff := Check.res(MOSS_DIFF, Texture2D) as Texture2D
	var nor := Check.res(MOSS_NOR, Texture2D) as Texture2D
	if diff:
		m.albedo_texture = diff
	if nor:
		m.normal_enabled = true
		m.normal_scale = 1.4
		m.normal_texture = nor
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.14 # x0.35: tuned at the old 0.4 moon (1.5 since 13 Nov)
	m.rim_tint = 0.35
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return m


static func _stone_material() -> Material:
	# Dressed limestone shared with the Ossuary (was the cyan-seamed cobble stone).
	var s := StandardMaterial3D.new()
	var t := "res://art/textures/oss_ashlar"
	s.albedo_texture = load(t + "_albedo.png")
	s.normal_enabled = true
	s.normal_texture = load(t + "_normal.png")
	s.roughness_texture = load(t + "_rough.png")
	s.ao_enabled = true
	s.ao_texture = load(t + "_ao.png")
	s.albedo_color = Color(0.74, 0.76, 0.84)
	s.uv1_triplanar = true
	s.uv1_world_triplanar = true
	s.uv1_triplanar_sharpness = 4.0
	s.uv1_scale = Vector3.ONE * 0.3
	s.rim_enabled = true
	s.rim = 0.09 # x0.35: tuned at the old 0.4 moon (1.5 since 13 Nov)
	s.rim_tint = 0.4
	return s


## The glb stores every copy of a moss rock as its own mesh with the same bytes. Point every copy at the
## first one (same picture, one upload, one collision hull per stone instead of per copy).
static var _rock_meshes: Dictionary = {}


static func _share_meshes(model: Node) -> void:
	for node in model.find_children("MossRock*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var base := String(mi.name).get_slice("..", 0).trim_suffix(".")
		var key := "%s|%d|%s" % [base, mi.mesh.surface_get_array_len(0), str(mi.mesh.get_aabb().size)]
		if _rock_meshes.has(key):
			mi.mesh = _rock_meshes[key]
		else:
			_rock_meshes[key] = mi.mesh


static func _paint_platform(model: Node) -> void:
	_share_meshes(model)
	var moss := _moss_material()
	var stone := _stone_material()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name).to_lower()
		if n.contains("moss"):
			mi.material_override = moss
		elif n.contains("cobble"):
			var cobble := StandardMaterial3D.new()
			# Let the mossy albedo speak — light cool tint only.
			cobble.albedo_color = Color(0.85, 0.95, 0.92)
			var ctex := Check.res("res://art/textures/cobble_ring.png", Texture2D) as Texture2D
			var cn := Check.res("res://art/textures/cobble_ring_n.png", Texture2D) as Texture2D
			if ctex:
				cobble.albedo_texture = ctex
			if cn:
				cobble.normal_enabled = true
				cobble.normal_scale = 1.85
				cobble.normal_texture = cn
			cobble.roughness = 0.7
			cobble.metallic = 0.0
			cobble.normal_scale = 1.2
			cobble.albedo_color = Color(0.62, 0.66, 0.72)
			cobble.rim_enabled = true
			cobble.rim = 0.07 # x0.35: tuned at the old 0.4 moon (1.5 since 13 Nov)
			cobble.rim_tint = 0.3
			cobble.uv1_triplanar = true
			cobble.uv1_world_triplanar = true
			cobble.uv1_scale = Vector3(0.18, 0.18, 0.18)
			mi.material_override = cobble
		elif stone:
			mi.material_override = stone
		mi.visibility_range_end = 0.0
		mi.ignore_occlusion_culling = true
		mi.extra_cull_margin = 8.0
		if n.contains("mossrock"):
			mi.lod_bias = 0.3          # 120 one-metre rocks at 8-10k tris each: simpler LODs sooner
			# their shadow pass was ~730k of the summit's 1.4 M prims; they sit on the stone tiers,
			# where the platform's own shadow already darkens them
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _paint_pillar(model: Node) -> void:
	_share_meshes(model)
	var moss := _moss_material()
	var stone := _stone_material()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var n := String(mi.name).to_lower()
		if n.contains("moss"):
			mi.material_override = moss
		elif stone:
			mi.material_override = stone
		mi.visibility_range_end = 0.0
		mi.ignore_occlusion_culling = true
		if n.contains("mossrock"):
			mi.lod_bias = 0.3


## The checkpoint before the Warden: a copy of a village brazier, unlit, beside the summit stair head
## and well outside the dais (the arena resets at DAIS_R + 6 m; this stands about 25 m from its centre).
static func _summit_fire(holder: Node3D) -> void:
	if not is_instance_valid(holder) or holder.get_node_or_null("SummitFire") != null:
		return
	var src: Brazier = null
	for node in holder.get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if node is Brazier:
			src = node as Brazier
			break
	if src == null:
		return
	var at := holder.to_global(STAIR_HEAD + Vector3(3.2, 0.0, -1.6))
	var hit := holder.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0, Layers.WORLD))
	if not hit.is_empty():
		at = hit.position
	var b := src.duplicate() as Brazier
	b.name = "SummitFire"
	b.start_lit = false
	holder.add_child(b)
	b.global_position = at
	if b.lit:
		b._set_lit(false, false)
	print("SUMMIT_DRESS checkpoint fire at %s" % at.snapped(Vector3.ONE * 0.1))

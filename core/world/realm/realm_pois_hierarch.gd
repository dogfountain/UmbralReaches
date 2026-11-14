extends RefCounted
## The Fallen Hierarch (docs/r37_expansion.md), and where he fell from.
##
## The Order's colossus did not fall alone: the Marches pulled him off his plinth in the north-west and hauled
## him down the valley to the Siege Lines, so that every engine and every earthwork there faces him. He lies on
## his back at the middle of the lines, the Speaking Crown's room in his split skull, and his plinth stands
## empty in the valley he left, his two stone feet still on it.
##
##   hierarch_statue   the colossus (r37_statue.glb) in the Siege Lines: the skull's floor is the boss's room
##   hierarch_hand     the open hand, palm up: steps up to it, a chest on the palm
##   hierarch_plinth   the empty plinth, feet still on it, in the old valley (r37_plinth.glb)
## Built by realm_pois_west_marches.gd (reserve / build hooks). No class_name: preload by path.

const Wayfinding := preload("res://core/world/realm/realm_wayfinding.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")
const LK := preload("res://core/world/realm/lore/lore_kit.gd")
const Chest := preload("res://core/world/realm/loot_chest.gd")
const Flora := preload("res://core/world/realm/realm_flora.gd")
const Kit := preload("res://core/world/realm/west_marches_kit.gd")
const Raid := preload("res://core/world/hierarch_raid.gd")
const Pilot := preload("res://core/world/realm/scale_pilot.gd")

## The skull's centre is the raid floor (RealmLayout RAIDS "hierarch"); the body lies away from it along BODY_DIR
## (xz), the model's +X. The mouth faces the way the siege track arrives.
const HEAD_C := Vector2(-206.0, 148.0)
const BODY_DIR := Vector2(0.2, 0.98)
const FLOOR_Y := 0.8
const PALM_Y := 3.95                                   ## the palm's top in the world, measured (a flat 7 m: zz/quests_r38_test.gd); the model's 2.7 below was 0.6 under it
const STAIR_X := -4.7                                  ## the palm's stair stands this far out from its centre (statue frame, x), on the open side
const STAIR_Z0 := 1.6                                  ## and starts here, climbing toward -z
const HAND_LOCAL := Vector3(38.0, 2.7, 37.5)          ## the palm's top, model frame in Godot axes (x along the body, z = -Blender y)
## The empty plinth, in the valley he was taken from (it faces south, the way he went).
const PLINTH_C := Vector2(-214.0, -104.0)
const PLINTH_Y := 0.2                  ## the model's z 0: the valley floor under it (its foundation is sunk 1.5 m; the ramp's foot, 2.8 m up, lands on the saddle to the south)
const PLINTH_YAW := 0.0
## The haul's logs, left lying south of the ramp's foot (offset from the plinth's centre: x, z, yaw), a few kicked aside.
## They stop short of the Sorrow's spring (z -56), where the furrow runs into water.
const ROLLERS := [Vector3(0.0, 41.5, 0.03), Vector3(1.5, 46.0, -0.09), Vector3(-13.0, 35.0, 0.5), Vector3(11.0, 33.0, 1.15), Vector3(-6.0, 50.0, 0.12)]

const LOOT := {
	"hierarch_hand": ["iron", {"grave_ash": 16, "relic_fragment": 1}],
	"hierarch_crown": ["reliquary", {"grave_ash": 28, "relic_fragment": 2, "ember_shard": 2}],
}


static func body_yaw() -> float:
	return atan2(-BODY_DIR.y, BODY_DIR.x)


static func _bx(ctr: Vector2, half: Vector2) -> Rect2:
	return Rect2(ctr - half, half * 2.0)


static func _g(space: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	return RealmLayout.ground(space, x, z)


static func _hi(space: PhysicsDirectSpaceState3D, rc: Rect2) -> float:
	var hi := -INF
	for ix in 4:
		for iz in 4:
			hi = maxf(hi, _g(space, rc.position.x + rc.size.x * ix / 3.0, rc.position.y + rc.size.y * iz / 3.0))
	return hi


static func _lo(space: PhysicsDirectSpaceState3D, rc: Rect2) -> float:
	var lo := INF
	for ix in 4:
		for iz in 4:
			lo = minf(lo, _g(space, rc.position.x + rc.size.x * ix / 3.0, rc.position.y + rc.size.y * iz / 3.0))
	return lo


## The palm's xz in the world.
static func hand_xz() -> Vector2:
	var w := Basis(Vector3.UP, body_yaw()) * Vector3(HAND_LOCAL.x, 0.0, HAND_LOCAL.z)
	return HEAD_C + Vector2(w.x, w.z)


## The palm's top in the world, and a spot on it clear of the chest (the lamp of "A Lamp for the Palm" is set here, standing
## in the hand; `slot` 0 is the set-down point, 1 the lantern that stays).
static func palm_pos(slot := 0) -> Vector3:
	var hx := hand_xz()
	var b := Basis(Vector3.UP, body_yaw())
	return Vector3(hx.x, PALM_Y, hx.y) + b * Vector3(0.0, 0.0, -0.9 - 0.35 * float(slot))


## A point in the statue's own frame (x along the body, z lateral, as the model's Godot axes) in the world xz.
static func local_xz(x: float, z: float) -> Vector2:
	var w := Basis(Vector3.UP, body_yaw()) * Vector3(x, 0.0, z)
	return HEAD_C + Vector2(w.x, w.z)


static func _chest(host: Node3D, id: String, at: Vector3, yaw: float) -> Node3D:
	var c: Node3D = Chest.new()
	c.name = "Chest_" + id
	c.set("chest_id", id)
	var l: Array = LOOT.get(id, ["wood", {"grave_ash": 6}])
	c.set("tier", l[0])
	c.set("loot", (l[1] as Dictionary).duplicate())
	c.set("big", lerpf(1.0, Pilot.PROP, Pilot.weight(at.x, at.z)))
	host.add_child(c)
	c.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return c


static func _lore(host: Node3D, id: String, at: Vector3, mark := Vector3.INF) -> void:
	var s := Inscription.make(id)
	host.add_child(s)
	s.global_position = at
	s.set("mark", mark if mark != Vector3.INF else at)


static func _kit() -> Pilot.SKit:
	LK.ensure_mats()
	var k := Pilot.SKit.new()
	k.keep_lanes = false
	return k


# --- reserve (before the stamp and the flora) ---------------------------------------------------

static func reserve(space: PhysicsDirectSpaceState3D) -> void:
	# the statue's body and arm lie on the land as it is, levelled to its highest corner: nothing grows on them
	var dir := BODY_DIR.normalized()
	for i in 5:
		var c := HEAD_C + dir * (28.0 + 7.5 * float(i))
		var rc := _bx(c, Vector2(11.0, 11.0))
		WorldLanes.register_site("r37w_body_%d" % i, rc, _hi(space, rc), _hi(space, rc) + 1.0)
	var hand := hand_xz()
	var arm := _bx((HEAD_C + dir * 40.0 + hand) * 0.5, Vector2(18.0, 18.0))
	WorldLanes.register_site("r37w_arm", arm, _hi(space, arm), _hi(space, arm) + 1.0)
	# the palm stands on a level pad, its steps built from the pad's edge
	WorldLanes.register_site("r37w_hand_pad", _bx(hand, Vector2(13.0, 12.0)), FLOOR_Y, FLOOR_Y - 0.1)
	Flora.tree_clear.append([HEAD_C + dir * 30.0, 34.0])
	# the empty plinth and the furrow south of it (the ramp, the rollers): claimed, the ground left as it is
	# (cut_y far above it: the site keeps the flora and the dress off and cuts nothing)
	WorldLanes.register_site("r37w_plinth", _bx(PLINTH_C, Vector2(21.0, 19.0)), PLINTH_Y, 60.0)
	WorldLanes.register_site("r37w_plinth_haul", Rect2(PLINTH_C.x - 9.0, PLINTH_C.y + 19.0, 18.0, 62.0), PLINTH_Y, 60.0)
	Flora.tree_clear.append([PLINTH_C, 28.0])
	Flora.tree_clear.append([PLINTH_C + Vector2(0.0, 50.0), 24.0])


# --- the colossus -------------------------------------------------------------------------------------

## The statue, the Speaking Crown's arena and room, the beacon, the tines, the lore plaque. Returns the arena.
static func statue(host: Node3D, space: PhysicsDirectSpaceState3D) -> BossArena:
	var yaw := body_yaw()
	var origin := Vector3(HEAD_C.x, FLOOR_Y - 0.15, HEAD_C.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), origin)
	# the near model (the engine's own mesh LODs) fades out where the far mesh takes over
	var near := Kit.place(host, "r37_statue.glb", xf)
	if near:
		near.name = "Statue"
		# the far mesh (r37_statue_far.glb, ~1.6k triangles) from 160 m out to the horizon; the near model fades out there
		var far_ps := Kit.scene("r37_statue_far.glb")
		if far_ps:
			var far_root := far_ps.instantiate() as Node3D
			for mi in far_root.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				if m.mesh != null:
					FarDetail.register(near, m.mesh, Transform3D.IDENTITY, 160.0, null, false)
			far_root.free()
		FarDetail.near_ends(near, 160.0, 30.0)
	# the arena: the floor inside the skull; its mouth is the gate toward the siege track
	var c := Vector3(HEAD_C.x, FLOOR_Y, HEAD_C.y)
	var raid := RealmLayout.raid("hierarch")
	var gate2: Vector2 = raid.gate
	var out := (gate2 - HEAD_C).normalized()
	var mouth := c + Vector3(out.x, 0.0, out.y) * 21.0
	mouth.y = _g(space, mouth.x, mouth.z)
	var room: Node3D = Raid.new()
	room.name = "HierarchRoom"
	host.add_child(room)
	room.global_position = c
	room.set("centre", c)
	room.set("radius", 20.0)
	var spawn := c + Vector3(out.x, 0.0, out.y) * 4.5 + Vector3.UP * 0.1   # rises on the entry axis, in sight of the mouth (was behind the centre, 26 m off)
	var ar: BossArena = BossArena.make(host, "r37_hierarch", "The Speaking Crown", c, 20.0, HierarchVoice, spawn)
	ar.room = room
	ar.ceiling = 26.0
	ar.subtitle = "the Hierarch's voice, kept in his head"
	var gate := WardSeal.make_arena_gate(host, "hierarch", mouth, Vector3(-out.x, 0.0, -out.y), 12.0, 6.0, "light")
	ar.gate = gate
	ar.on_slain = func(fresh: bool) -> void:
		if fresh:
			Events.toast.emit("The horn goes quiet. The skull is only stone.")
		var sp := RealmLayout.ground(host.get_world_3d().direct_space_state, c.x + out.x * 3.0, c.z + out.y * 3.0)
		if host.get_node_or_null("Chest_hierarch_crown") == null:
			_chest(host, "hierarch_crown", Vector3(c.x + out.x * 3.0, sp, c.z + out.y * 3.0), 0.0)
	# a pale column out of the skull (the boss beacon, gone when he falls): the hills round the lines hide the
	# statue's feet from the road, so its top reads over them at night
	var bn: Variant = Wayfinding.beacon(host, c, "r37_hierarch", Color(0.66, 0.76, 0.92), 78.0, 0.45, 20.0, false, 280.0)
	if bn is Node:
		(bn as Node).name = "Beacon_r37_hierarch"
	# cover on the floor: three fallen tines (stone slabs on edge), solid, so the Echo's feet and the
	# Toll's gaps have something to be read against; the mouth's inside edge is lit by the horn's ember
	var k := _kit()
	for i in 3:
		var a := TAU * (float(i) + 0.4) / 3.0
		var p := c + Vector3(cos(a), 0.0, sin(a)) * 12.0
		# on the room's own floor, sunk 0.3 m so the tilt lifts no corner (a ground ray met the shell above it: they hung
		# about a metre up)
		var bb := Basis(Vector3.UP, a + 0.4) * Basis(Vector3.FORWARD, 0.18)
		k.box("ruin", Vector3(p.x, FLOOR_Y + 2.4 - 0.3, p.z), Vector3(1.8, 4.8, 1.2), bb, true, 0.9)
	k.commit(host, "CrownTines")
	var lp := Vector3(HEAD_C.x + out.x * 24.5, FLOOR_Y + 1.1, HEAD_C.y + out.y * 24.5)
	_lore(host, "r37w_statue", Vector3(lp.x, _g(space, lp.x, lp.z) + 1.1, lp.z + 2.5), lp)
	host.set_meta("approach", mouth)
	host.set_meta("boss", "r37_hierarch")
	return ar


static func hand(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var hx := hand_xz()
	var palm := Vector3(hx.x, PALM_Y, hx.y)
	host.set_meta("centre", palm)
	var k := _kit()
	var b := Basis(Vector3.UP, body_yaw())
	# a stair of fallen blocks up the palm's open (west) side, 0.55 m a tread (the thumb stands to the south of it, a pit under the edge), each at most 0.45 m above the last (a walk, no
	# jump), from the ground beside the hand to a tread level with the palm's edge (the palm is a 7 m flat, measured at
	# PALM_Y: the stair that went in from the finger side ran under the fingers)
	var foot := palm + b * Vector3(STAIR_X, 0.0, STAIR_Z0)
	var g0 := _g(space, foot.x, foot.z)
	var top := palm.y - 0.15
	var n := clampi(ceili((top - g0) / 0.42), 1, 16)
	for i in n:
		var ty := g0 + (top - g0) * float(i + 1) / float(n)
		var c := palm + b * Vector3(STAIR_X + 0.6, 0.0, STAIR_Z0 - 0.55 * float(i))
		var base := g0 - 1.3
		k.box("ruin", Vector3(c.x, (ty + base) * 0.5, c.z), Vector3(2.4, ty - base, 0.6), b, true, 0.85)
	k.commit(host, "HandSteps")
	_chest(host, "hierarch_hand", palm + b * Vector3(0.0, 0.1, 0.4), body_yaw())
	_lore(host, "r37w_hand", palm + b * Vector3(-1.5, 0.9, -1.2), palm + b * Vector3(-1.5, 0.9, -1.2))
	host.set_meta("approach", Vector3(foot.x, g0, foot.z))


# --- the empty plinth ---------------------------------------------------------------------------------

static func plinth(host: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var at := Vector3(PLINTH_C.x, PLINTH_Y, PLINTH_C.y)
	var pl := Kit.place(host, "r37_plinth.glb", Transform3D(Basis(Vector3.UP, PLINTH_YAW), at))
	if pl:
		pl.name = "Plinth"
		FarDetail.register(pl, FarDetail.hull(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 14.0, 40.0)), 0.1, Color(0.2, 0.2, 0.19)), Transform3D.IDENTITY, 150.0)
	# the rollers: logs lying across the furrow, each resting on its two ends, a few kicked askew
	var rng := RandomNumberGenerator.new()
	rng.seed = 37011
	for rl: Vector3 in ROLLERS:
		var c := PLINTH_C + Vector2(rl.x + rng.randf_range(-0.4, 0.4), rl.y)
		var yaw := rl.z
		var ax := Vector2(cos(yaw), -sin(yaw))
		var e0 := _g(space, c.x - ax.x * 3.4, c.y - ax.y * 3.4)
		var e1 := _g(space, c.x + ax.x * 3.4, c.y + ax.y * 3.4)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), atan2(e1 - e0, 6.8))
		Kit.place(host, "r37_roller.glb", Transform3D(b, Vector3(c.x, (e0 + e1) * 0.5 + 0.34, c.y)), {"pick": "Roller", "range_end": 200.0})
	var lp := Vector3(PLINTH_C.x + 11.0, 0.0, PLINTH_C.y + 30.0)
	lp.y = _g(space, lp.x, lp.z) + 1.1
	_lore(host, "r37w_plinth", lp, lp)
	host.set_meta("centre", at)
	host.set_meta("approach", Vector3(PLINTH_C.x, _g(space, PLINTH_C.x, PLINTH_C.y + 40.0), PLINTH_C.y + 40.0))

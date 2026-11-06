extends RefCounted
## Lights others keep: a pilgrim asleep by a banked fire on the Downs, the ferryman's lamp on the Sorrow, a
## hunter's shuttered lantern in the Thornwood, a window lit in a ruin that has no business with anyone in it.
## Pre-lit, few, and each one a small story. Like every lamp they are comfort, not safety: no LightGrid, no
## rest, no checkpoint (lamp.gd). Built by lamp_places.gd (which hands over its `place` Callable: a
## lamp ray-placed like the wanderer's own).

const Kit := preload("res://core/life/secrets/kit.gd")
const Land := preload("res://core/world/realm/realm_land.gd")
const Inscription := preload("res://core/world/realm/lore/inscription.gd")

const CLOTH := Color(0.2, 0.17, 0.13)
const ROBE := Color(0.13, 0.1, 0.085)
const WOOD := Color(0.2, 0.15, 0.1)
const IRON := Color(0.1, 0.095, 0.09)
const STONE := Color(0.15, 0.145, 0.135)

static var kept := 0


static func build(host: Node3D, root: Node, space: PhysicsDirectSpaceState3D, place: Callable) -> void:
	kept = 0
	var k := Node3D.new()
	k.name = "Kept"
	host.add_child(k)
	_camp(k, root, space, place)
	_ferry(k, root, space, place)
	_hide(k, root, space, place)
	_window(k, root, place)
	print("LAMPS kept: %d lights others keep" % kept)


## A static merged mesh (one draw) at a transform.
static func _mesh(parent: Node3D, b: Lamp.LampBuilder, at: Vector3, yaw: float, nm: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = b.commit()
	mi.material_override = Lamp._mat("body")
	mi.visibility_range_end = 120.0
	mi.visibility_range_end_margin = 10.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	return mi


static func _clear(root: Node, at: Vector2, r: float) -> void:
	Kit.clear_flora(root, [Vector3(at.x, at.y, r)])
	Kit.flush_flora(root)


static func _note(parent: Node3D, at: Vector3, prompt: String, line: String) -> void:
	Kit.touch(parent, at, prompt, func(_by: Node) -> void: Events.toast.emit(line), 2.2)


## Read-and-keep texts (lamp_texts.gd) carried by a small board at `at`.
static func _page(parent: Node3D, id: String, at: Vector3) -> void:
	var s := Inscription.make(id)
	parent.add_child(s)
	s.global_position = at
	s.set("mark", at)


# --- the Downs: a pilgrim asleep ---------------------------------------------------------------------------

static func _camp(parent: Node3D, root: Node, space: PhysicsDirectSpaceState3D, place: Callable) -> void:
	var want := Vector2(-96.0, 181.0)
	var c: Vector2 = Kit.free_spot(space, want, 5.0)
	var y := RealmLayout.ground(space, c.x, c.y)
	_clear(root, c, 5.5)
	var yaw := 0.9
	var fire: Lamp = place.call({"id": "downs_camp_fire", "look": "camp", "x": c.x, "z": c.y, "kept": true, "face": yaw, "on_path": true})
	if fire == null:
		return
	kept += 1
	var b := Lamp.LampBuilder.new()
	# the bedroll on the lee side, the sleeper in it, the pack and the staff
	b.box(Vector3(2.1, 0.06, 0.2), Vector3(0.9, 0.12, 2.1), Basis.IDENTITY, CLOTH)
	b.box(Vector3(2.1, 0.22, 0.4), Vector3(0.56, 0.24, 1.3), Basis(Vector3.UP, 0.05), ROBE)
	b.box(Vector3(2.1, 0.3, -0.55), Vector3(0.3, 0.26, 0.3), Basis.IDENTITY, Color(0.16, 0.12, 0.1))
	b.box(Vector3(2.1, 0.22, 1.12), Vector3(0.34, 0.14, 0.28), Basis.IDENTITY, IRON)
	b.box(Vector3(3.0, 0.2, -0.5), Vector3(0.5, 0.38, 0.32), Basis(Vector3.UP, 0.4), CLOTH * 0.8)
	b.bar(Vector3(1.4, 0.05, 1.4), Vector3(1.6, 0.05, -1.5), 0.05, WOOD)
	b.box(Vector3(0.9, 0.04, -1.0), Vector3(0.22, 0.06, 0.22), Basis.IDENTITY, IRON)       # a tin cup
	b.box(Vector3(1.0, 0.03, -1.0), Vector3(0.28, 0.02, 0.2), Basis(Vector3.UP, 0.7), Color(0.55, 0.5, 0.4))    # a page, folded
	var at := Vector3(c.x, y, c.y)
	_mesh(parent, b, at, yaw, "Pilgrim")
	var tr := Transform3D(Basis(Vector3.UP, yaw), at)
	_note(parent, tr * Vector3(2.1, 0.5, 0.4), "Look in on the sleeper", "Asleep with his boots on. Someone has banked the fire for him; it is not him. He says a name, over and over: Weirford.")
	_page(parent, "lamp_pilgrim", tr * Vector3(1.0, 0.25, -1.0))


# --- the Sorrow: the ferryman's lamp ------------------------------------------------------------------------

static func _ferry(parent: Node3D, root: Node, space: PhysicsDirectSpaceState3D, place: Callable) -> void:
	# the west bank of the Sorrow at the boat-maker's (the river runs down the valley): walk east from the
	# boats until the first wet ground, and stand on the last dry
	var z := 14.0
	var bank := Vector2(INF, z)
	var x := -236.0
	while x < -190.0:
		if Land.in_water(x, z):
			bank = Vector2(x - 1.8, z)
			break
		x += 0.5
	if bank.x == INF:
		return
	var lamp: Lamp = place.call({"id": "ferry_lamp", "look": "post", "x": bank.x, "z": bank.y, "kept": true, "face": PI * 0.5, "on_path": true})
	if lamp == null:
		return
	kept += 1
	var wy := Land.water_y_at(bank.x + 3.0, z)
	var b := Lamp.LampBuilder.new()
	# a skiff drawn up half on the bank, a pole and a coil of rope
	b.box(Vector3(0, 0.0, 0), Vector3(0.9, 0.1, 3.0), Basis.IDENTITY, WOOD)
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.46, 0.2, 0), Vector3(0.08, 0.36, 3.0), Basis(Vector3.FORWARD, sx * -0.18), WOOD * 0.9)
	b.box(Vector3(0, 0.18, 1.55), Vector3(0.7, 0.34, 0.16), Basis(Vector3.RIGHT, 0.3), WOOD * 0.85)
	b.box(Vector3(0, 0.18, -1.55), Vector3(0.7, 0.34, 0.16), Basis(Vector3.RIGHT, -0.3), WOOD * 0.85)
	b.box(Vector3(0, 0.12, -0.3), Vector3(0.8, 0.05, 0.28), Basis.IDENTITY, WOOD)
	b.bar(Vector3(-0.2, 0.2, 0.8), Vector3(0.9, 1.9, 0.8), 0.06, WOOD)
	_mesh(parent, b, Vector3(bank.x + 2.4, wy - 0.12, bank.y + 0.5), PI * 0.5 + 0.1, "Skiff")
	_note(parent, Vector3(bank.x + 0.5, RealmLayout.ground(space, bank.x, bank.y) + 1.0, bank.y), "Hold the lamp to the water",
		"The oil is full and the wick is new. Whoever keeps this expects a crossing, and has no fare in mind.")


# --- the Thornwood: a hunter's hide -------------------------------------------------------------------------

static func _hide(parent: Node3D, root: Node, space: PhysicsDirectSpaceState3D, place: Callable) -> void:
	var c: Vector2 = Kit.free_spot(space, Vector2(-144.0, -28.0), 4.0)
	var y := RealmLayout.ground(space, c.x, c.y)
	_clear(root, c, 4.0)
	var yaw := 2.2
	print("LAMPS kept: hunter's hide at (%.1f, %.1f)" % [c.x, c.y])
	var b := Lamp.LampBuilder.new()
	# a lean-to of poles and boughs against a fallen trunk, a skin on the ground, a crate for the lantern
	b.bar(Vector3(-1.4, 0.0, 0.9), Vector3(-1.4, 1.9, 0.9), 0.1, WOOD)
	b.bar(Vector3(1.4, 0.0, 0.9), Vector3(1.4, 1.9, 0.9), 0.1, WOOD)
	b.bar(Vector3(-1.4, 1.9, 0.9), Vector3(1.4, 1.9, 0.9), 0.1, WOOD)
	for i in 7:
		var x := -1.35 + float(i) * 0.45
		b.bar(Vector3(x, 1.95, 0.95), Vector3(x * 1.08, 0.1, -1.3), 0.09, Color(0.1, 0.13, 0.08) if i % 2 == 0 else Color(0.08, 0.1, 0.07))
	b.box(Vector3(0, 0.03, -0.2), Vector3(1.8, 0.05, 1.6), Basis(Vector3.UP, 0.2), Color(0.18, 0.13, 0.1))
	b.box(Vector3(0.7, 0.18, 0.7), Vector3(0.45, 0.36, 0.4), Basis(Vector3.UP, 0.3), WOOD)
	_mesh(parent, b, Vector3(c.x, y, c.y), yaw, "HuntersHide")
	var tr := Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))
	var lp := tr * Vector3(0.7, 0.36, 0.7)
	var lamp: Lamp = place.call({"id": "hunter_lantern", "look": "shutter", "x": lp.x, "z": lp.z, "y": lp.y, "kept": true, "face": yaw + 0.3, "on_path": true})
	if lamp != null:
		kept += 1
	_note(parent, tr * Vector3(0.7, 0.6, 0.7), "Touch the lantern", "Still warm. The shutter is open a finger's width, toward the path. Someone out in the trees has been counting who goes by.")


# --- the Cinder Orchard: a window lit in the press-house ----------------------------------------------------

static func _window(parent: Node3D, _root: Node, place: Callable) -> void:
	# the press-house's west gable (the loft is behind it): mount on the nearest outer face from the west
	var lamp: Lamp = place.call({"id": "press_window", "look": "window", "x": -140.0, "z": 132.0, "mode": "wall", "y": 4.1, "dir": Vector2(1, 0), "reach": 9.0, "kept": true})
	if lamp == null:
		return
	kept += 1
	var n := lamp.global_basis * Vector3(0, 0, 1)
	var b := Lamp.LampBuilder.new()
	b.bar(Vector3(0, 0.0, 0), Vector3(0, 1.5, 0), 0.07, WOOD)
	b.box(Vector3(0, 1.3, 0.0), Vector3(0.5, 0.42, 0.04), Basis.IDENTITY, WOOD * 1.2)
	var ground := RealmLayout.ground(lamp.get_world_3d().direct_space_state, lamp.global_position.x + n.x * 2.4, lamp.global_position.z + n.z * 2.4)
	var at := Vector3(lamp.global_position.x + n.x * 2.4, ground, lamp.global_position.z + n.z * 2.4)
	_mesh(parent, b, at, atan2(n.x, n.z), "NoticeStake")
	_page(parent, "lamp_window", at + Vector3(0, 1.3, 0) + n * 0.1)

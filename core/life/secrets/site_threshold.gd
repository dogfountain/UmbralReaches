extends RefCounted
## THE PILGRIMS' CHAPEL (the Pilgrims' Threshold, core/world/realm/rift/chapel.gd): a small chapel cut into the rift's west wall
## at the foot of the pilgrims' stair, the last cool stone before the crossing. Reached by the Cinder Way's Descent and the branch
## along the wall from its Foot. The pilgrims' reliquary (the ascension's offering) and a page cut into the kneeling stone.
## The ids stay `last_landing` / `sc_landing` (the texts and the reward live in pages.gd under them); only the
## display name is the chapel's. State: secrets' own (looted.last_landing, found.last_landing).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const WestKit := preload("res://core/world/realm/west_marches_kit.gd")


static func build(root: Node, host: Node3D) -> void:
	var marker := root.get_node_or_null("RealmRift/Threshold/ChapelMarker") as Node3D
	if marker == null:
		print("SECRETS pilgrims' chapel: no chapel (the rift module is off)")
		return
	var floor_at: Vector3 = marker.get_meta("floor")
	var b: Basis = marker.get_meta("basis")
	var chest_at: Vector3 = marker.get_meta("chest_at")
	var stone_at: Vector3 = marker.get_meta("stone_at")
	var node := Node3D.new()
	node.name = "PilgrimsChapel"
	node.set_meta("site", "secrets_landing")
	host.add_child(node)
	# the reliquary: the iron-bound chest modelled for the Sky Chain's wardens (art/models/wonders/sky_chain_chest.glb),
	# on the floor before the kneeling stone; its lid is its own node, hinged at the back
	var ps := load("res://art/models/wonders/sky_chain_chest.glb") as PackedScene
	var chest := ps.instantiate() as Node3D if ps != null else Node3D.new()
	node.add_child(chest)
	chest.global_transform = Transform3D(b.scaled(Vector3.ONE * 0.8), chest_at)
	var lid: Node3D = null
	for n in chest.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var set_name := String(mi.name).get_slice("__", 1).get_slice("_", 0).get_slice(".", 0)
		if set_name in ["timber", "iron"]:
			mi.material_override = WestKit.mat(set_name)
		if String(mi.name).contains("Lid"):
			lid = mi
	var lid_rest := lid.transform if lid != null else Transform3D.IDENTITY
	var opened := func(_animate: bool) -> void:
		if lid != null:
			lid.transform = Transform3D(lid_rest.basis * Basis(Vector3.RIGHT, -1.15), lid_rest.origin)
	State.cache(node, "last_landing", chest_at + Vector3.UP * 0.4, "the pilgrims' reliquary", opened)
	State.reading(node, "sc_landing", stone_at, "Read the kneeling stone")
	Kit.glint(node, chest_at + Vector3.UP * 0.75, Color(0.75, 0.62, 1.0), 0.3, 40.0)
	State.register({"id": "last_landing", "name": "The Pilgrims' Chapel", "at": floor_at + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"foot": floor_at,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "last_landing"):
				opened.call(animate)})
	print("SECRETS pilgrims' chapel at %s" % floor_at.snapped(Vector3.ONE * 0.1))

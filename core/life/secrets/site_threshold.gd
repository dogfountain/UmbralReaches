extends RefCounted
## THE PILGRIMS' CHAPEL (the Pilgrims' Threshold, core/world/realm/rift/chapel.gd): a small chapel built against the
## rift's west wall at the starfall, its doorway under the falling light. Reached by the west terraces and the jetty
## off the lowest walk. The pilgrims' reliquary (the ascension's offering) and a page cut into the kneeling stone.
## The ids stay `last_landing` / `sc_landing` (the texts and the reward live in pages.gd under them); only the
## display name is the chapel's. State: secrets' own (looted.last_landing, found.last_landing).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")


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
	# the reliquary: a small iron-bound chest on the floor before the kneeling stone
	var chest := BoxMesh.new()
	chest.size = Vector3(0.62, 0.4, 0.42)
	var lid := BoxMesh.new()
	lid.size = Vector3(0.66, 0.1, 0.46)
	var box := Kit.mi(node, chest, OssKit.mat("iron"), Transform3D(b, chest_at + Vector3.UP * 0.2), 90.0)
	var cap := Kit.mi(node, lid, OssKit.mat("iron"), Transform3D(b, chest_at + Vector3.UP * 0.45), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(b * Basis(Vector3.RIGHT, -1.1), chest_at + Vector3.UP * 0.5 + b.z * 0.2)
	State.cache(node, "last_landing", chest_at + Vector3.UP * 0.4, "the pilgrims' reliquary", opened)
	State.reading(node, "sc_landing", stone_at, "Read the kneeling stone")
	Kit.glint(node, chest_at + Vector3.UP * 0.75, Color(0.75, 0.62, 1.0), 0.3, 40.0)
	State.register({"id": "last_landing", "name": "The Pilgrims' Chapel", "at": floor_at + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"foot": floor_at,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "last_landing"):
				opened.call(animate)})
	print("SECRETS pilgrims' chapel at %s" % floor_at.snapped(Vector3.ONE * 0.1))

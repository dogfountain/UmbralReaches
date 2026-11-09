extends RefCounted
## THE LAST LANDING (the Pilgrims' Threshold, core/world/realm/rift/threshold.gd): the Broken Stair's top, a
## landing held in the air over the meeting of the starwater and the fire. Climbed from the third tower of
## the crossing by jumping the breaks between the stair's flights (the last needs the second jump), or glided
## to from the Spindle's turn. The pilgrims' reliquary (the ascension's offering) and a page cut in stone.
## State: secrets' own (looted.last_landing, found.last_landing). Texts and reward: pages.gd.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")


static func build(root: Node, host: Node3D) -> void:
	var landing := root.get_node_or_null("RealmRift/Threshold/StairLanding") as Node3D
	if landing == null:
		print("SECRETS last landing: no landing (the rift module is off)")
		return
	var top: Vector3 = landing.get_meta("top")
	var b: Basis = landing.get_meta("basis")
	var node := Node3D.new()
	node.name = "LastLanding"
	node.set_meta("site", "secrets_landing")
	host.add_child(node)
	# the reliquary: a small iron-bound chest on the slab, beside the kneeling stone
	var at := top + b.x * 0.95 - b.z * 0.55
	var chest := BoxMesh.new()
	chest.size = Vector3(0.62, 0.4, 0.42)
	var lid := BoxMesh.new()
	lid.size = Vector3(0.66, 0.1, 0.46)
	var box := Kit.mi(node, chest, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.2), 90.0)
	var cap := Kit.mi(node, lid, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.45), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(b * Basis(Vector3.RIGHT, -1.1), at + Vector3.UP * 0.5 + b.z * 0.2)
	State.cache(node, "last_landing", at + Vector3.UP * 0.4, "the pilgrims' reliquary", opened)
	State.reading(node, "sc_landing", top - b.z * 1.15 + Vector3.UP * 0.75, "Read the stone")
	Kit.glint(node, at + Vector3.UP * 0.75, Color(0.75, 0.62, 1.0), 0.3, 40.0)
	State.register({"id": "last_landing", "name": "The Last Landing", "at": top + Vector3.UP * 0.5, "r": 2.6, "node": node,
		"climb_only": true, "foot": top,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "last_landing"):
				opened.call(animate)})
	print("SECRETS last landing at %s (%.1f m over the pool)" % [top.snapped(Vector3.ONE * 0.1), top.y + 15.5])

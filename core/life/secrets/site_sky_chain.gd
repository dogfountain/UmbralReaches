extends RefCounted
## THE WARDENS' TALLY (the Sky Chain, core/world/realm/wonders/sky_chain.gd): at the bitter end, where the first link is
## shackled to the pylon, the chain-wardens cut their count on a standing stone and kept a strongbox of what the
## pilgrims left. Reached by the anchor's stair (a long climb up the south wall to the deck). A page cut in the tally
## stone, and the wardens' box. State: secrets' own (looted.sky_chain, found.sky_chain).
##
## Its page and reward live in pages.gd (sc_sky_chain / sky_chain).

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")
const WestKit := preload("res://core/world/realm/r37_west_kit.gd")

const NAME := "The Wardens' Tally"


static func build(root: Node, host: Node3D) -> void:
	var mark := root.get_node_or_null("RealmSkyChain/ChainTop") as Node3D
	if mark == null:
		print("SECRETS sky chain: no tally (the wonder is off)")
		return
	var top: Vector3 = mark.get_meta("top")
	var b: Basis = mark.get_meta("basis")
	var node := Node3D.new()
	node.name = "WardensTally"
	node.set_meta("site", "secrets_sky_chain")
	host.add_child(node)
	# the wardens' box: the modelled iron-bound chest (tools/blender/wonder_sky_chain.py), beside the lodge door; its lid is
	# its own node, hinged at the back
	var at := top + b.x * 2.4 + b.z * 0.2
	var ps := load("res://art/models/wonders/sky_chain_chest.glb") as PackedScene
	var chest := ps.instantiate() as Node3D if ps != null else Node3D.new()
	node.add_child(chest)
	chest.global_transform = Transform3D(b, at)
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
	State.cache(node, "sky_chain", at + Vector3.UP * 0.5, "the wardens' box", opened)
	State.reading(node, "sc_sky_chain", top + Vector3(0.0, 1.0, 0.55), "Read the tally stone")
	Kit.glint(node, at + Vector3.UP * 0.9, Color(0.75, 0.62, 1.0), 0.3, 40.0)
	State.register({"id": "sky_chain", "name": NAME, "at": top + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"climb_only": true, "foot": top,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "sky_chain"):
				opened.call(animate)})
	print("SECRETS sky chain tally at %s (deck %.1f)" % [top.snapped(Vector3.ONE * 0.1), top.y])

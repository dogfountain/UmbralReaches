extends RefCounted
## THE WARDENS' TALLY (the Sky Chain, core/world/realm/wonders/sky_chain.gd): at the bitter end, where the first link is
## shackled to the pylon, the chain-wardens cut their count on a standing stone and kept a strongbox of what the
## pilgrims left. Reached by the anchor's stair (a long climb up the south wall to the deck). A page cut in the tally
## stone, and the wardens' box. State: secrets' own (looted.sky_chain, found.sky_chain).
##
## For the lead (secrets.gd / pages.gd are not edited here):
##   secrets.gd   const SiteSkyChain := preload("res://core/life/secrets/site_sky_chain.gd") and call SiteSkyChain.build(root, host)
##                where SiteThreshold.build is called
##   pages.gd     SITES["sky_chain"] = {"name": SiteSkyChain.NAME, "region": "crags"}
##                TEXTS["sc_sky_chain"] = SiteSkyChain.PAGE
##                REWARDS["sky_chain"] = SiteSkyChain.REWARD

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const NAME := "The Wardens' Tally"
const PAGE := {"title": "Cut into the tally stone", "kind": "carved stone",
	"text": "One thousand and nine links, forged in the Pits and hauled up hand over hand. We count them every dusk from the ring to the sky, and every dusk it comes out one short. The Hierarch says the sky is taking one back. I say the sky is not taking. I say the chain is getting longer. Pilgrims leave their names in the box. Take what helps."}
const REWARD := {"relic_fragment": 1, "grave_ash": 35, "grave_iron": 1}


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
	# the wardens' box: an iron-bound chest east of the tally stone, on the walk
	var at := top + b.x * 2.4 + b.z * 0.2
	var chest := BoxMesh.new()
	chest.size = Vector3(0.9, 0.55, 0.55)
	var lid := BoxMesh.new()
	lid.size = Vector3(0.96, 0.14, 0.6)
	var box := Kit.mi(node, chest, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.28), 90.0)
	var cap := Kit.mi(node, lid, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.62), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(b * Basis(Vector3.RIGHT, -1.1), at + Vector3.UP * 0.7 + b.z * 0.28)
	State.cache(node, "sky_chain", at + Vector3.UP * 0.5, "the wardens' box", opened)
	State.reading(node, "sc_sky_chain", top + Vector3(0.0, 1.0, 0.55), "Read the tally stone")
	Kit.glint(node, at + Vector3.UP * 0.9, Color(0.75, 0.62, 1.0), 0.3, 40.0)
	State.register({"id": "sky_chain", "name": NAME, "at": top + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"climb_only": true, "foot": top,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "sky_chain"):
				opened.call(animate)})
	print("SECRETS sky chain tally at %s (deck %.1f)" % [top.snapped(Vector3.ONE * 0.1), top.y])

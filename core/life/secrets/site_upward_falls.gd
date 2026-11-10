extends RefCounted
## THE UPWARD FALLS' CREST (core/world/realm/wonders/upward_falls.gd): the top of the Order's weir over the Sorrow,
## where the river stands up out of its bowl. Reached by jumping up the weir's seven broad steps (each 0.55 m, the
## river running up them with you), from the pond on the north. The hydrographers' cache (their survey, the
## Order's last unread report) sits at the crest's east end and a plaque is cut into the coping at the west.
## Stand in the spray (within 4 m of the crest's middle) and the place is found.
## State: secrets' own (looted.upward_falls, found.upward_falls, pages.sc_upward_falls).
##
## For the lead (wiring, after merging):
##   secrets.gd   call this file's build(root, host) from the site list (like site_threshold.gd)
##   pages.gd     NAME / PAGE / REWARD below: SITES["upward_falls"] = NAME, TEXTS["sc_upward_falls"] = PAGE,
##                REWARDS["upward_falls"] = REWARD
##   quest        quest_chains_upward_falls.gd reads `secret:found:upward_falls`

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const NAME := {"name": "The Upward Falls' Crest", "region": "sorrow"}
const PAGE := {"title": "Cut into the crest's coping", "kind": "carved stone",
	"text": "SURVEY OF THE SORROW, ninth year of the lift. The water climbs the steps at four paces a breath and does not tire. We were to carry it to the abbey. It does not want the abbey. Last night I stood where the sheet leaves the bowl and put my hand in it, and it did not wet me. It went up through my fingers like a held note. The Order will want this written as a success. I have written it as a staircase."}
const REWARD := {"relic_fragment": 2, "grave_ash": 36, "ember_shard": 1}


static func release() -> void:
	pass


static func build(root: Node, host: Node3D) -> void:
	var mark := root.get_node_or_null("UpwardFalls/DeckTop") as Node3D
	if mark == null:
		print("SECRETS upward falls: no wonder (the wonders are off)")
		return
	var top: Vector3 = mark.get_meta("top")
	var basin: Vector3 = mark.get_meta("basin")
	var chest_at: Vector3 = mark.get_meta("chest")
	var plaque_at: Vector3 = mark.get_meta("plaque")
	var foot: Vector3 = mark.get_meta("stair_foot")
	var node := Node3D.new()
	node.name = "UpwardFallsDeck"
	node.set_meta("site", "secrets_upward_falls")
	host.add_child(node)
	# the hydrographers' cache: a small iron-bound survey case at the crest's east end
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.7, 0.36, 0.46)
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.74, 0.08, 0.5)
	var at := chest_at + Vector3.UP * 0.0
	var box := Kit.mi(node, case_mesh, OssKit.mat("iron"), Transform3D(Basis(Vector3.UP, -0.2), at + Vector3.UP * 0.18), 90.0)
	var cap := Kit.mi(node, lid_mesh, OssKit.mat("iron"), Transform3D(Basis(Vector3.UP, -0.2), at + Vector3.UP * 0.4), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(Basis(Vector3.UP, -0.2) * Basis(Vector3.RIGHT, -1.1), at + Vector3.UP * 0.44 + Vector3(0.0, 0.0, 0.2))
	State.cache(node, "upward_falls", at + Vector3.UP * 0.4, "the hydrographers' cache", opened)
	State.reading(node, "sc_upward_falls", plaque_at + Vector3.UP * 0.8, "Read the coping")
	Kit.glint(node, at + Vector3.UP * 0.75, Color(0.62, 0.84, 1.0), 0.3, 40.0)
	box.name = "SurveyCase"
	State.register({"id": "upward_falls", "name": "The Upward Falls' Crest", "at": top + Vector3.UP * 0.5, "r": 4.2, "node": node,
		"climb_only": true, "foot": foot,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "upward_falls"):
				opened.call(animate)})
	print("SECRETS upward falls deck at %s (basin %s, stair foot %s)" % [top.snapped(Vector3.ONE * 0.1), basin.snapped(Vector3.ONE * 0.1), foot.snapped(Vector3.ONE * 0.1)])

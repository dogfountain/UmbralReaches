extends RefCounted
## THE FALLEN STAR (the Star-Fall Crater, core/world/realm/wonders/star_crater.gd, in the White Pans): a spiral of
## fused-glass slabs climbs from the crater floor to a platform under the star's heart (climb-only: no path
## leads there but the slabs). On the platform the Order's surveyors left a brass case and a slate; the
## last of them climbed, and did not come down.
## State: secrets' own (looted.star_crater, pages.sc_star). The lead wires this file into secrets.gd and pages.gd:
##   SECRETS     "star_crater": {"name": STAR_NAME, "region": "saltpans"}
##   TEXTS       "sc_star": STAR_PAGE
##   REWARDS     "star_crater": STAR_REWARD

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const STAR_NAME := "The Fallen Star"
const STAR_REWARD := {"relic_fragment": 1, "grave_ash": 35, "ember_shard": 1}
const STAR_PAGE := {"title": "The surveyors' slate", "kind": "slate",
	"text": "Fall at the first turning. Glass to a depth of eleven spans; the heart keeps its height as the sky keeps its. Warm on the north face. We leaned a ladder to it and the ladder came down glass. Brother Ostric says it is a Wound. Under it, scratched later: I climbed. It is not a wound. It is a window, and whatever is on the other side is not angry. Leave the case. Take it."}


static func build(root: Node, host: Node3D) -> void:
	var mark := root.get_node_or_null("StarCrater/HeartPlatform") as Node3D
	if mark == null:
		print("SECRETS star crater: no crater (the wonders are off)")
		return
	var top: Vector3 = mark.get_meta("top")
	var heart: Vector3 = mark.get_meta("heart")
	var node := Node3D.new()
	node.name = "StarCrater"
	node.set_meta("site", "secrets_star_crater")
	host.add_child(node)
	# the surveyors' case: an iron-cornered box on the platform, its lid warped by the heat
	var at := top + Vector3(1.0, 0.0, 0.9) * 1.1
	var chest := BoxMesh.new()
	chest.size = Vector3(0.7, 0.36, 0.44)
	var lid := BoxMesh.new()
	lid.size = Vector3(0.74, 0.1, 0.48)
	var b := Basis(Vector3.UP, 0.5)
	var box := Kit.mi(node, chest, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.18), 90.0)
	var cap := Kit.mi(node, lid, OssKit.mat("iron"), Transform3D(b, at + Vector3.UP * 0.41), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(b * Basis(Vector3.RIGHT, -1.0), at + Vector3.UP * 0.46 + b.z * 0.2)
	State.cache(node, "star_crater", at + Vector3.UP * 0.4, "the surveyors' case", opened)
	var slate_at := top + Vector3(-0.9, 0.0, 1.5)
	State.reading(node, "sc_star", slate_at + Vector3.UP * 0.7, "Read the slate")
	var slate := BoxMesh.new()
	slate.size = Vector3(0.5, 0.7, 0.08)
	Kit.mi(node, slate, OssKit.mat("iron"), Transform3D(Basis(Vector3.UP, -0.4) * Basis(Vector3.RIGHT, -0.12), slate_at + Vector3.UP * 0.35), 90.0)
	Kit.glint(node, at + Vector3.UP * 0.7, Color(0.7, 0.9, 1.0), 0.3, 40.0)
	State.register({"id": "star_crater", "name": STAR_NAME, "at": top + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"climb_only": true, "foot": top,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "star_crater"):
				opened.call(animate)})
	print("SECRETS star crater at %s (heart %.1f m over the platform)" % [top.snapped(Vector3.ONE * 0.1), heart.y - top.y])

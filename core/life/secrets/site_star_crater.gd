extends RefCounted
## THE FALLEN STAR (the Star-Fall Crater, core/world/realm/wonders/star_crater.gd, in the White Pans): a spiral of
## fused-glass slabs climbs from the crater floor to a platform under the star's heart (climb-only: no path
## leads there but the slabs). On the platform the Order's surveyors left their survey case (iron-bound oak, a
## star-glass in its lid: art/models/wonders/star_crater_case.glb, tools/blender/wonder_star_crater.py) and a slate;
## the last of them climbed, and did not come down.
## State: secrets' own (looted.star_crater, pages.sc_star); its name, page and reward live in pages.gd.

const Kit := preload("res://core/life/secrets/kit.gd")
const State := preload("res://core/life/secrets/state.gd")

const CASE := "res://art/models/wonders/star_crater_case.glb"
const CASE_D := 0.42                  ## the case's depth and height (the lid hinges on the back top edge)
const CASE_H := 0.30

const STAR_NAME := "The Fallen Star"


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
	# the surveyors' case, its lid on its hinge; the slate propped beside it
	var parts := _parts()
	var at := top + Vector3(1.0, 0.0, 0.9) * 1.1
	var b := Basis(Vector3.UP, 0.5)
	Kit.mi(node, parts.get("case_body"), null, Transform3D(b, at), 90.0)
	var hinge := at + b * Vector3(0.0, CASE_H, -CASE_D * 0.5)
	var cap := Kit.mi(node, parts.get("case_lid"), null, Transform3D(b, hinge), 90.0)
	var opened := func(_animate: bool) -> void:
		cap.transform = Transform3D(b * Basis(Vector3.RIGHT, -1.85), hinge)
	State.cache(node, "star_crater", at + Vector3.UP * 0.4, "the surveyors' case", opened)
	var slate_at := top + Vector3(-0.9, 0.0, 1.5)
	State.reading(node, "sc_star", slate_at + Vector3.UP * 0.7, "Read the slate")
	Kit.mi(node, parts.get("case_slate"), null, Transform3D(Basis(Vector3.UP, -0.4 + PI) * Basis(Vector3.RIGHT, 0.12), slate_at), 90.0)
	Kit.glint(node, at + Vector3.UP * 0.7, Color(0.7, 0.9, 1.0), 0.3, 40.0)
	# the star-glass's own cold light on the case's face and the slate (the star lights only their tops)
	Kit.omni(node, at + b * Vector3(0.0, 0.75, 0.9), Color(0.72, 0.8, 1.0), 0.55, 3.2)
	State.register({"id": "star_crater", "name": STAR_NAME, "at": top + Vector3.UP * 0.5, "r": 3.2, "node": node,
		"climb_only": true, "foot": top,
		"sync": func(animate: bool) -> void:
			if State.has("looted", "star_crater"):
				opened.call(animate)})
	print("SECRETS star crater at %s (heart %.1f m over the platform)" % [top.snapped(Vector3.ONE * 0.1), heart.y - top.y])


## The case's meshes by name (the Blender export: case_body, case_lid, case_slate), their own materials.
static func _parts() -> Dictionary:
	var out := {}
	var ps := load(CASE) as PackedScene
	if ps == null:
		return out
	var scene := ps.instantiate()
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		out[String(n.name)] = (n as MeshInstance3D).mesh
	scene.free()
	return out

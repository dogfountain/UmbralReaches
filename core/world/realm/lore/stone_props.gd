extends RefCounted
## The lore stones as in-house models (tools/blender/props_stones.py -> art/models/props/lore_*.glb): waystone, stele,
## headstones, cairn, lectern, tablet. Each glb is a set of mesh nodes named `<Part>__<set>` (stone / ashlar / timber /
## iron), a convex hull (`-convcolonly`, imported as a StaticBody3D) and empties `TextPoint` (where the inscription
## sits; local -Z is outward) and `DoorPoint`. Models are small and numerous, so LoreKit batches them: one
## MultiMesh per (model, set) per area cell, never a node per stone. No class_name: preload by path.

const WestKit := preload("res://core/world/realm/west_marches_kit.gd")
const DIR := "res://art/models/props/"

static var _info := {}


static func release() -> void:
	_info.clear()


## The finer PBR material of a set for small props (west_marches_kit.prop_mat).
static func mat(set_name: String) -> StandardMaterial3D:
	return WestKit.prop_mat(set_name)


## {parts: [{set, mesh, name}], points: PackedVector3Array (convex hull), text: Vector3, door: Vector3 (INF if none)}
static func info(file: String) -> Dictionary:
	if _info.has(file):
		return _info[file]
	var d := {"parts": [], "points": PackedVector3Array(), "text": Vector3.ZERO, "door": Vector3.INF}
	var ps := load(DIR + file) as PackedScene
	if ps == null:
		push_error("StoneProps: no " + file)
		_info[file] = d
		return d
	var root := ps.instantiate() as Node3D
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var bits := String(mi.name).split("__")
		if bits.size() >= 2 and mi.mesh != null:
			(d.parts as Array).append({"set": bits[bits.size() - 1], "mesh": mi.mesh, "name": bits[0]})
	for n in root.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is ConvexPolygonShape3D:
			d.points = (cs.shape as ConvexPolygonShape3D).points
	var tp := root.find_child("TextPoint", true, false) as Node3D
	if tp != null:
		d.text = tp.position
	var dp := root.find_child("DoorPoint", true, false) as Node3D
	if dp != null:
		d.door = dp.position
	root.free()
	_info[file] = d
	return d


## Dress an instanced glb in place (a standalone model): each `<Part>__<set>` mesh gets its set's material.
static func dress(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var bits := String(mi.name).split("__")
		if bits.size() >= 2:
			mi.material_override = mat(bits[bits.size() - 1])

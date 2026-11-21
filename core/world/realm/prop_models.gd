extends RefCounted
## Modelled set pieces for the places the kits build (tools/blender/props_ruins.py, props_works.py ->
## art/models/props/): a builder adds parts of a glb at world transforms and commits them as ONE mesh per
## material set, so a place that was a handful of kit surfaces is still a handful of draws. Parts are
## `<Part>__<set>` meshes (metric box UVs, vertex tone) dressed with the tiling PBR sets. The collision is
## not here: the builder keeps the boxes it always had (OssKit.collider), so nothing walkable or blocking
## moves. Load by path (no class_name):
##   const PropModels := preload("res://core/world/realm/prop_models.gd")

const GroundSeat := preload("res://core/world/realm/ground_seat.gd")
const StoneProps := preload("res://core/world/realm/lore/stone_props.gd")
const WestKit := preload("res://core/world/realm/west_marches_kit.gd")

var big := false                 ## building-size texel density (WestKit.mat) instead of the props' finer one
var _st := {}                    ## set -> SurfaceTool


## The box of a whole model (every part): a builder scales a crate or a barrel to the size it wants.
static func size_of(file: String) -> Vector3:
	var box := AABB()
	var first := true
	for p: Dictionary in (StoneProps.info(file).parts as Array):
		var a := (p.mesh as Mesh).get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box.size


## A part into a kit's own surface `key` instead (turf walls in the kit's world-triplanar earth: no seams with the ground).
static func kit_add(k: OssKit, key: String, file: String, xf: Transform3D, part: String) -> void:
	for p: Dictionary in (StoneProps.info(file).parts as Array):
		if String(p.name) == part:
			k.append_mesh(key, p.mesh as ArrayMesh, xf)


## Add `part` of `file` (every part when "") at `xf` (world; the host stands at the origin like a kit's).
func add(file: String, xf: Transform3D, part := "") -> void:
	if part == "":
		xf = GroundSeat.seat_file(GroundSeat.fast_fn(), file, xf, 0.5)      # r39: a whole model's footing on the ground (a part is placed by its builder, in a set)
	var found := false
	for p: Dictionary in (StoneProps.info(file).parts as Array):
		if part != "" and String(p.name) != part:
			continue
		found = true
		var key := String(p.set)
		if not _st.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_st[key] = st
		(_st[key] as SurfaceTool).append_from(p.mesh as Mesh, 0, xf)
	if not found:
		push_warning("PropModels: no part %s in %s" % [part, file])


## One MeshInstance3D per set under `parent` (named `<node_name>_<set>`). `lods` gives each mesh a LOD chain (a
## building seen from across a valley draws a fraction of its triangles). Returns them.
func commit(parent: Node3D, node_name: String, shadows := true, lods := false) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for key: String in _st:
		var mi := MeshInstance3D.new()
		mi.name = "%s_%s" % [node_name, key]
		var m := (_st[key] as SurfaceTool).commit()
		mi.mesh = OssKit.with_lods(m) if lods else m
		mi.material_override = WestKit.lit_mat(key) if big else StoneProps.mat(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		out.append(mi)
	_st.clear()
	return out

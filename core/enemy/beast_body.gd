extends Node3D
## A four-legged boss body in the villagers' style (17 Nov: bosses "simple like the villager"): DwarfMesh primitives
## (lofts, tubes, lumpy blobs) soft-skinned to a beast's skeleton, the same shader and detail maps as Hearthward's
## people (DwarfLook), cached through GenCache. A body script extends this and overrides `_layout()` (the rests) and
## `_body_v(mb)` (the mesh), and fills `glints` and `muzzle_at`. Posed by core/enemy/beast_rig.gd.
## No class_name (project rule): const BeastBody := preload("res://core/enemy/beast_body.gd")

const DMesh := preload("res://core/npc/dwarf_mesh.gd")
const DwarfLook := preload("res://core/npc/dwarf_look.gd")
const GenCache := preload("res://core/world/realm/gen_cache.gd")
const BONES := ["root", "hips", "spine", "chest", "neck", "head", "jaw", "tail1", "tail2", "tail3",
	"fl_up", "fl_lo", "fr_up", "fr_lo", "bl_up", "bl_lo", "br_up", "br_lo"]
const PARENT := [-1, 0, 1, 2, 3, 4, 5, 1, 7, 8, 3, 10, 3, 12, 1, 14, 1, 16]
const B_ROOT := 0
const B_HIPS := 1
const B_SPINE := 2
const B_CHEST := 3
const B_NECK := 4
const B_HEAD := 5
const B_JAW := 6
const B_TAIL := 7
const B_LEG := 10            ## legs: fl, fr, bl, br; each [upper, lower] from B_LEG + 2 * i
const HOLLOW := Color(0.02, 0.015, 0.016)
const EMBER := Color(1.0, 0.5, 0.15)

var rests: Array[Vector3] = []
## Each leg's foot at rest: fl, fr, bl, br.
var feet: Array[Vector3] = []
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
## Glowing points: [bone, rest point, radius, colour]. Spells leave from `muzzle_at` ([bone, rest point]).
var glints: Array = []
var muzzle_at: Array = []
var k := 1.0                 ## the boss rig reads it (body size)


func made(opts: Dictionary) -> Node3D:
	name = "Body"
	_layout()
	var path: String = (get_script() as Script).resource_path
	var key := "beast|%s|%d|%d|%d" % [path.get_file(), int(opts.get("seed", 1)), GenCache.salt(path), GenCache.salt("res://core/enemy/beast_body.gd")]
	var mesh: ArrayMesh = GenCache.load_mesh(key, path)
	if mesh == null:
		var mb: Variant = DMesh.new(int(opts.get("seed", 1)))
		_body_v(mb)
		mb.bake_ao()
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mb.arrays(), [], {}, null, "beast")
		im.generate_lods(25.0, 60.0, [])
		mesh = im.get_mesh()
		GenCache.save_mesh(key, path, mesh)
	mesh.surface_set_material(0, DwarfLook.material_boss())           # (a great one: no emissive edges, dwarf_look.gd)
	_assemble(mesh)
	return self


func _layout() -> void:
	pass


func _body_v(_mb: Variant) -> void:
	pass


func _assemble(mesh: ArrayMesh) -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	for i in BONES.size():
		skeleton.add_bone(BONES[i])
		if PARENT[i] >= 0:
			skeleton.set_bone_parent(i, PARENT[i])
	for i in BONES.size():
		var parent_at: Vector3 = rests[PARENT[i]] if PARENT[i] >= 0 else Vector3.ZERO
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, rests[i] - parent_at))
	skeleton.reset_bone_poses()
	var skin := Skin.new()
	for i in BONES.size():
		skin.add_named_bind(BONES[i], skeleton.get_bone_global_rest(i).affine_inverse())
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	mesh_instance.skin = skin
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh_instance.extra_cull_margin = 1.0


## A rest point carried by bone b under the skeleton's current pose (skeleton space).
func carry(b: int, rest_point: Vector3) -> Vector3:
	var gp := skeleton.get_bone_global_pose(b)
	return gp.origin + gp.basis * (rest_point - rests[b])


static func _pf(a: Array, m := 1.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v: float in a:
		out.append(v * m)
	return out


static func _rep(v: float, n: int) -> Array:
	var a := []
	for i in n:
		a.append(v)
	return a

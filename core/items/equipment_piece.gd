class_name EquipmentPiece
extends Resource
## Data-only description of one wearable/holdable item (clothing, armor, an accessory). An
## EquipmentPiece is attached to a skeleton socket by CharacterRig.equip() -- it never knows which
## character it's on, so the same instance can be reused across both sides of a symmetric body, or
## duplicate()'d and tweaked (color, size, offset) to make a variant with no code changes.
##
## Covers the common case -- one primitive mesh -- directly via build(). An item that needs bespoke,
## compound geometry (a staff, a lantern) subclasses this and overrides build() entirely; see
## StaffPiece / LanternPiece.

enum Shape { CYLINDER, SPHERE, CAPSULE }

@export var node_name := "Piece"
@export var shape: Shape = Shape.CYLINDER
@export var radius_top := 0.1          ## cylinder top radius, or sphere/capsule radius
@export var radius_bottom := 0.1       ## cylinder bottom radius (ignored for sphere/capsule)
@export var height := 0.2
@export var radial_segments := 12
@export var rings := 1                 ## cylinder rings / sphere rings (ignored for capsule)
@export var offset := Vector3.ZERO
@export var rotation_deg := Vector3.ZERO
@export var cast_shadow := true
@export var color := Color("#211634")
@export var roughness := 0.85
@export var metallic := 0.0
@export var glow := false              ## unshaded emissive material instead of a lit one


## Builds this piece's geometry as a child of `socket` (a Node3D already in the rig's scene tree)
## and returns the root node, which the caller (CharacterRig.equip/unequip) owns and frees.
func build(socket: Node3D) -> Node3D:
	var mat: Material = ProcMesh.glow_mat(color) if glow else ProcMesh.std_mat(color, roughness, metallic)
	var m: Mesh
	match shape:
		Shape.SPHERE:
			m = ProcMesh.sphere(radius_top, height, radial_segments, maxi(rings, 3))
		Shape.CAPSULE:
			m = ProcMesh.capsule(radius_top, height)
		_:
			m = ProcMesh.cyl(radius_top, radius_bottom, height, radial_segments, rings)
	var rot := Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z))
	return ProcMesh.mesh(socket, node_name, m, mat, offset, rot, cast_shadow)

extends Interactable
## r33 world: the ember-post beside every brazier, where the Ember Road (fire_road.gd) is taken: a
## wrought-iron post on a stone footing with a hanging cage. While its fire is lit the cage holds a
## coal and lets off a thin thread of sparks (the road is awake); cold, it is dark iron. Use it at a
## lit fire to fly to another lit fire (WoW's flight master, as a thing of the fire). Made by
## Brazier._ready as its child "EmberPost"; it seats itself on the ground beside the fire a few times
## while the Realm settles the land, then stops processing. Load by path (no class_name).

const FireRoad := preload("res://core/world/fire_road.gd")
const OFFSET := Vector3(-2.3, 0.0, 0.4)  ## brazier-local: to its side, off the respawn spot (+z)
## r34 layout: fires whose side is somebody's road. Hearthward's fire (the spawn Sanctuary) has the
## villagers' walking nodes on all four sides (village_cast.gd brazier_w/e/n/s, 2.3 m out): the post at
## OFFSET stood on brazier_w and cut the green_w edge (zz/village_test). Its post goes to the north-west
## diagonal, 2.4 m clear of the respawn spot and every walking node and edge.
const SEAT_OFFSETS := {"Sanctuary": Vector3(-2.3, 0.0, 2.6)}
const IRON := Color(0.09, 0.085, 0.09)
const STONE := Color(0.32, 0.3, 0.28)

var brazier: Brazier
var _coal_mat: StandardMaterial3D
var _sparks: GPUParticles3D
var _was_lit := false
var _seat_t := 0.0
var _seats := 0


func _ready() -> void:
	add_to_group(Groups.INTERACTABLE)
	position = SEAT_OFFSETS.get(String(brazier.name), OFFSET) if brazier != null else OFFSET
	_build()
	_apply(brazier != null and brazier.lit)


func interact_reach() -> float:
	return 1.4


func can_interact() -> bool:
	return brazier != null and is_instance_valid(brazier) and brazier.lit


func interact_text() -> String:
	return "[%s]  The Ember Road  ·  travel to another fire" % Interactable.prompt_key()


func interact_feel() -> StringName:
	return &"cast"


func interact(_by: Node) -> void:
	if can_interact():
		FireRoad.open(brazier)


func _process(delta: float) -> void:
	var on := brazier != null and is_instance_valid(brazier) and brazier.lit
	if on != _was_lit:
		_apply(on)
	# seat on the ground: the Realm moves its fires after the terrain stamp (RealmBosses), so look
	# again every 2 s for the first minute
	_seat_t -= delta
	if _seat_t <= 0.0 and _seats < 30:
		_seat_t = 2.0
		_seats += 1
		_seat()


func _seat() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var p := global_position
	var excl: Array[RID] = []
	if brazier:                              # the fire's own body and this post's (both under the fire)
		for c in brazier.find_children("*", "CollisionObject3D", true, false):
			excl.append((c as CollisionObject3D).get_rid())
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 4.0, Layers.WORLD | Layers.PROPS, excl))
	if not hit.is_empty():
		global_position.y = (hit.position as Vector3).y - 0.05


func _apply(on: bool) -> void:
	_was_lit = on
	if _coal_mat:
		_coal_mat.emission_energy_multiplier = 1.6 if on else 0.0    # r37 cap (was 5.0)
		_coal_mat.albedo_color = Color(1.0, 0.55, 0.25) if on else Color(0.12, 0.1, 0.1)
	if _sparks:
		_sparks.emitting = on


func _build() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = IRON
	iron.metallic = 0.6
	iron.roughness = 0.55
	var stone := StandardMaterial3D.new()
	stone.albedo_color = STONE
	stone.roughness = 0.95
	# footing
	_mesh(_box(Vector3(0.6, 0.3, 0.6)), stone, Vector3(0, 0.1, 0))
	_mesh(_box(Vector3(0.42, 0.14, 0.42)), stone, Vector3(0, 0.3, 0))
	# the post, its collar, the arm and the hook
	_mesh(_cyl(0.055, 0.07, 2.3, 8), iron, Vector3(0, 1.45, 0))
	_mesh(_cyl(0.09, 0.09, 0.08, 8), iron, Vector3(0, 0.45, 0))
	_mesh(_cyl(0.08, 0.08, 0.06, 8), iron, Vector3(0, 2.2, 0))
	var arm := _mesh(_box(Vector3(0.72, 0.05, 0.05)), iron, Vector3(0.32, 2.5, 0))
	arm.rotation.z = 0.0
	var brace := _mesh(_box(Vector3(0.5, 0.04, 0.04)), iron, Vector3(0.2, 2.33, 0))
	brace.rotation.z = 0.62
	_mesh(_cyl(0.012, 0.012, 0.26, 4), iron, Vector3(0.62, 2.36, 0))
	# the cage: four bars between two rings, a coal in it
	var cage_y := 2.05
	_mesh(_cyl(0.13, 0.13, 0.03, 10), iron, Vector3(0.62, cage_y + 0.19, 0))
	_mesh(_cyl(0.1, 0.13, 0.04, 10), iron, Vector3(0.62, cage_y - 0.19, 0))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		_mesh(_cyl(0.012, 0.012, 0.38, 4), iron, Vector3(0.62 + cos(a) * 0.12, cage_y, sin(a) * 0.12))
	var cap := _mesh(_cyl(0.0, 0.15, 0.12, 10), iron, Vector3(0.62, cage_y + 0.27, 0))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_coal_mat = StandardMaterial3D.new()
	_coal_mat.emission_enabled = true
	_coal_mat.emission = Color(1.0, 0.45, 0.15)
	_coal_mat.roughness = 0.9
	var coal := SphereMesh.new()
	coal.radius = 0.075
	coal.height = 0.13
	coal.radial_segments = 8
	coal.rings = 4
	var ci := _mesh(coal, _coal_mat, Vector3(0.62, cage_y - 0.08, 0))
	ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks = Vfx.emitter(Color(3.0, 1.3, 0.4), {"count": 10, "life": 1.6, "speed": Vector2(0.15, 0.5), "size": 0.035,
		"gravity": 0.7, "spread": 25.0, "dir": Vector3.UP, "radius": 0.05, "turbulence": true})
	_sparks.position = Vector3(0.62, cage_y + 0.3, 0)
	add_child(_sparks)
	# a thin collider so the wanderer walks round it, not through
	var body := StaticBody3D.new()
	body.collision_layer = Layers.PROPS
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.22
	shape.height = 2.3
	cs.shape = shape
	cs.position = Vector3(0, 1.15, 0)
	body.add_child(cs)
	add_child(body)


func _mesh(m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.visibility_range_end = 70.0
	mi.add_to_group(Groups.CULL_SKIP)
	add_child(mi)
	return mi


static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

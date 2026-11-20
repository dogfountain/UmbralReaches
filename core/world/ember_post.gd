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
## The glade's fire stands beside west_way at the Thorn Henge stair's foot: its post at OFFSET stood on the road into the stair
## (zone fit), so it goes to the fire's other side.
const SEAT_OFFSETS := {"Sanctuary": Vector3(-2.3, 0.0, 2.6), "Shrine": Vector3(2.3, 0.0, -0.4)}

const Kit37 := preload("res://core/world/realm/west_marches_kit.gd")
static var _kit_cache := {}

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
	if brazier != null:
		brazier.lit_changed.connect(_on_lit)


## Its fire lit or put out (Brazier.lit_changed): once seated it stops processing and follows this alone.
func _on_lit(on: bool) -> void:
	if on != _was_lit:
		_apply(on)


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
	if _seats >= 30:
		set_process(false)                   # seated for good; the fire's lit_changed carries the rest
		return
	var on := brazier != null and is_instance_valid(brazier) and brazier.lit
	if on != _was_lit:
		_apply(on)
	# seat on the ground: the Realm moves its fires after the terrain stamp (RealmBosses), so look
	# again every 2 s for the first minute. While the Realm is still building it keeps its first seat:
	# a re-seat every 2 s of wall clock made the build depend on how fast it ran (the flora's cached
	# ground saw the post 3 cm higher after a slow build than a fast one, and was rebuilt)
	_seat_t -= delta
	if _seat_t <= 0.0 and _seats < 30:
		if _seats > 0 and _realm_building():
			return
		_seat_t = 2.0
		_seats += 1
		_seat()


## True while the night this post stands in is building its Realm (Realm.build marks its root "realm_built",
## then "realm_done").
func _realm_building() -> bool:
	var n := get_parent()
	while n != null:
		if n.has_meta(&"realm_built"):
			return not n.has_meta(&"realm_done")
		n = n.get_parent()
	return false


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
		_coal_mat.emission_energy_multiplier = 1.6 if on else 0.0    # emissive cap (was 5.0)
		_coal_mat.albedo_color = Color(1.0, 0.55, 0.25) if on else Color(0.12, 0.1, 0.1)
	if _sparks:
		_sparks.emitting = on


func _build() -> void:
	# the in-house model (tools/blender/props_lamps.py, ember_post.glb): footing, post, arm and cage (parts dressed with the tiling
	# PBR sets) and the coal as its own mesh "Flame", which keeps this post's own emissive material
	var kit := _kit()
	for part: Dictionary in kit.parts:
		var mi := _mesh(part.mesh, Kit37.mat(String(part.set)), Vector3.ZERO)
		mi.name = String(part.name)
	_coal_mat = StandardMaterial3D.new()
	_coal_mat.emission_enabled = true
	_coal_mat.emission = Color(1.0, 0.45, 0.15)
	_coal_mat.roughness = 0.9
	_coal_mat.vertex_color_use_as_albedo = true
	if kit.coal != null:
		var ci := _mesh(kit.coal, _coal_mat, Vector3.ZERO)
		ci.name = "Coal"
		ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks = Vfx.emitter(Color(3.0, 1.3, 0.4), {"count": 10, "life": 1.6, "speed": Vector2(0.15, 0.5), "size": 0.035,
		"gravity": 0.7, "spread": 25.0, "dir": Vector3.UP, "radius": 0.05, "turbulence": true})
	_sparks.position = Vector3(0.62, 2.35, 0)
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


## The shared meshes of ember_post.glb, read once: {parts: [{mesh, set, name}], coal: Mesh}.
static func _kit() -> Dictionary:
	if _kit_cache.is_empty():
		var out := {"parts": [], "coal": null}
		var ps := load("res://art/models/props/ember_post.glb") as PackedScene
		if ps != null:
			var root := ps.instantiate()
			for n in root.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				var nm := String(mi.name)
				if nm == "Flame":
					out.coal = mi.mesh
				elif nm.contains("__"):
					(out.parts as Array).append({"mesh": mi.mesh, "set": nm.get_slice("__", 1).get_slice(".", 0).get_slice("_", 0), "name": nm})
			root.free()
		_kit_cache = out
	return _kit_cache

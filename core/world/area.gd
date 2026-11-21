class_name Area
extends Node3D
## One streamable chunk of a zone (see AreaStreamer). Owns its geometry, lights, braziers and
## spawners; everything it registers globally (light zones) leaves with it when it is freed.
## Kindled braziers are remembered per area in Travel.area_lit, so streaming out and back in,
## hollowing, or travelling to another night never forgets a fire.

@export var area_id := ""
@export var title := ""
@export var subtitle := ""
## Benchmark stands for --perf-baseline: [{name, at: Vector3, yaw: float}]
var perf_points: Array[Dictionary] = []
var ambience := ""        ## Ambience bed key while the player is inside ambience_bounds (local)
var ambience_bounds := AABB()
var instant := false      ## set by the streamer on forced loads (respawn/continue): build in one go


## Yield a frame between build sections, unless the player is about to stand on this area.
func slice() -> void:
	if not instant:
		await get_tree().process_frame
var _announced := false


func _ready() -> void:
	if ambience != "":
		add_to_group(&"ambience_area")
	await build()            # a build may yield between sections (time-sliced; see Ossuary)
	_restore_kindles()
	Events.brazier_kindled.connect(_on_kindled)


## Override: create geometry, lights, braziers, spawners. Runs once when streamed in.
func build() -> void:
	pass


func key_of(b: Brazier) -> String:
	return "%s/%s" % [area_id, b.name]


func _restore_kindles() -> void:
	for node in find_children("*", "Brazier", true, false):
		var b := node as Brazier
		if Travel.area_lit.has(key_of(b)):
			b.kindle_quiet()


func _on_kindled(b: Node3D) -> void:
	if b is Brazier and is_ancestor_of(b):
		Travel.area_lit[key_of(b as Brazier)] = true


## Title card the first time the player steps inside `bounds` (local AABB). Call from _physics.
func announce_if_inside(p: Node3D, bounds: AABB) -> void:
	if _announced or p == null or title == "":
		return
	if is_inside_tree() and get_tree().get_first_node_in_group(&"fire_flight") != null:
		return                                   # the Ember Road's flight parks the wanderer at the far fire at once: the card plays on landing
	if bounds.has_point(to_local(p.global_position)):
		_announced = true
		Events.zone_entered.emit(title, subtitle)


## A brazier cloned from any brazier already in the tree (the hub's are fully dressed: GLB,
## flame, coals, light), placed at `at` facing `yaw`. Returns null where none exists to copy.
func make_brazier(b_name: String, at: Vector3, yaw := 0.0) -> Brazier:
	var src: Brazier = null
	for node in get_tree().get_nodes_in_group(Groups.INTERACTABLE):
		if node is Brazier and not is_ancestor_of(node):
			src = node as Brazier
			break
	if src == null:
		push_warning("Area.make_brazier: no template brazier in tree")
		return null
	var b := src.duplicate() as Brazier
	b.name = b_name
	b.start_lit = false
	add_child(b)
	b.global_position = at
	b.rotation.y = yaw
	if b.lit:
		b._set_lit(false, false)
	return b
